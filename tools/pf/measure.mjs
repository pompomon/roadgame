// PF prototype: measures Web builds of the game in Chrome and Firefox, headed (under Xvfb).
// Usage: node measure.mjs '<json config>'
// config: {browsers:["chrome","firefox"], builds:{name:baseUrl}, sizes:[[w,h,dpr]], scenarios:[{area,hour,extra:[]}],
//          warm:6, secs:15, seed:1, reps:1, uncap:false, firefoxPrefs:{}, out:"file.jsonl"}
// Each build must be a Web export whose index.html takes ?arg= (docs/agents/checks.md §4).
// PLAYWRIGHT_MODULE: Playwright's index.mjs, if `playwright` isn't importable; CHROME: Chrome's path.
import fs from 'node:fs';
const { chromium, firefox } = await import(process.env.PLAYWRIGHT_MODULE ?? 'playwright');

const cfg = JSON.parse(process.argv[2]);
const warm = cfg.warm ?? 6, secs = cfg.secs ?? 15, reps = cfg.reps ?? 1;
const out = cfg.out ?? '/tmp/perf-results.jsonl';

const INIT = `
(() => {
  window.__frames = []; let rec = false;
  function tick(t) { if (rec) window.__frames.push(t); requestAnimationFrame(tick); }
  requestAnimationFrame(tick);
  window.__perfStart = () => { window.__frames = []; rec = true; };
  window.__perfStop = () => { rec = false; return window.__frames; };
})();`;

function stats(frames) {
  if (frames.length < 2) return { fps: 0 };
  const iv = [];
  for (let i = 1; i < frames.length; i++) iv.push(frames[i] - frames[i - 1]);
  const total = frames[frames.length - 1] - frames[0];
  const s = [...iv].sort((a, b) => a - b);
  const q = (p) => s[Math.min(s.length - 1, Math.floor(p * s.length))];
  return { fps: +(iv.length / total * 1000).toFixed(1), med_ms: +q(0.5).toFixed(1), p95_ms: +q(0.95).toFixed(1),
           p99_ms: +q(0.99).toFixed(1), max_ms: +s[s.length - 1].toFixed(1), n: iv.length };
}

async function launch(name) {
  if (name === 'chrome') {
    return chromium.launch({ executablePath: process.env.CHROME ?? '/usr/bin/google-chrome', headless: false,
      args: ['--autoplay-policy=no-user-gesture-required', '--enable-unsafe-swiftshader', '--disable-background-timer-throttling', '--disable-renderer-backgrounding', '--disable-backgrounding-occluded-windows', ...(cfg.uncap ? ['--disable-gpu-vsync', '--disable-frame-rate-limit'] : [])] });
  }
  return firefox.launch({ headless: false, firefoxUserPrefs: { 'media.autoplay.default': 0, ...(cfg.firefoxPrefs ?? {}) } });
}

const results = [];
for (const bname of cfg.browsers) {
  const tl = Date.now(); const browser = await launch(bname); console.log(`launched ${bname} in ${(Date.now()-tl)/1000}s`);
  for (let rep = 0; rep < reps; rep++) {
    for (const sc of cfg.scenarios) {
      for (const [w, h, dpr] of cfg.sizes) {
        for (const [build, base] of Object.entries(cfg.builds)) {
          const tr = Date.now();
          const ctx = await browser.newContext({ viewport: { width: w, height: h }, deviceScaleFactor: dpr ?? 1 });
          const page = await ctx.newPage();
          await page.addInitScript(INIT);
          const logs = [];
          let started = null;
          const startedP = new Promise((res) => { started = res; });
          page.on('console', (m) => { const t = m.text(); logs.push(`[${m.type()}] ${t}`); if (/^(OpenGL API|Godot Engine)/.test(t)) started(); });
          page.on('pageerror', (e) => logs.push(`[pageerror] ${e.message}`));
          const args = ['--autopilot', `--seed=${cfg.seed ?? 1}`];
          if (sc.area) args.push(`--area=${sc.area}`);
          if (sc.hour !== undefined) args.push(`--hour=${sc.hour}`);
          for (const a of (sc.extra ?? [])) args.push(a);
          const url = base + '?' + args.map((a) => 'arg=' + encodeURIComponent(a)).join('&');
          const t0 = Date.now();
          await page.goto(url);
          await Promise.race([startedP, new Promise((r) => setTimeout(r, 60000).unref())]);
          const loadS = (Date.now() - t0) / 1000;
          await page.waitForTimeout(warm * 1000);
          await page.evaluate(() => window.__perfStart());
          const logFrom = logs.length;
          await page.waitForTimeout(secs * 1000);
          const frames = await page.evaluate(() => window.__perfStop());
          const st = stats(frames);
          // The gate's state (autoload/pf_probe.gd): it paces only the engine's chain, so the page's own frames
          // above run at the screen's rate, and the game's rate is the PERF lines' fps.
          const gate = await page.evaluate(() => { const g = window.__pfGate; return g ? { cap: g.cap, skipped: g.skipped,
            refresh: +(g.refresh ?? 0).toFixed(3), steps: g.steps?.length, runner: !!g.runner } : null; });
          const gl = await page.evaluate(() => { try { const c = document.createElement('canvas'); const g = c.getContext('webgl2'); const e = g.getExtension('WEBGL_debug_renderer_info'); return e ? g.getParameter(e.UNMASKED_RENDERER_WEBGL) : g.getParameter(g.RENDERER); } catch (e) { return 'n/a ' + e; } });
          const perfLines = logs.slice(logFrom).filter((l) => l.includes('PERF '));
          const perf = {};
          const cnt = {};
          for (const l of perfLines) {
            for (const m of l.matchAll(/ ([a-z_0-9]+)=([0-9.]+)(?:\/([0-9.]+))?/g)) {
              perf[m[1]] = (perf[m[1]] ?? 0) + parseFloat(m[2]); cnt[m[1]] = (cnt[m[1]] ?? 0) + 1;
              if (m[3] !== undefined) { const k = m[1] + '_max'; perf[k] = Math.max(perf[k] ?? 0, parseFloat(m[3])); }
            }
          }
          for (const k of Object.keys(cnt)) perf[k] = +(perf[k] / cnt[k]).toFixed(2);
          const perfLast = perfLines.slice(-1)[0] ?? '';
          const errs = logs.filter((l) => /^\[(error|pageerror)\]/.test(l) || /ERROR/.test(l));
          // The browsers log WebGL's errors as warnings (docs/M2.md §5.7).
          const warns = logs.filter((l) => /^\[warning\]/.test(l));
          const dev = logs.find((l) => l.includes('OpenGL API')) ?? '';
          const r = { uncap: !!cfg.uncap, browser: bname, rep, build, area: sc.area, hour: sc.hour, extra: sc.extra ?? [], size: `${w}x${h}@${dpr ?? 1}`, load_s: loadS, ...st, perf, perfLast, gate, spikes: logs.map((l, i) => (i < logFrom ? 'pre ' : 'win ') + l).filter((l) => l.includes('PFSPIKE')).slice(0, 80), errs: errs.slice(0, 5), warns: warns.length, warn_samples: [...new Set(warns.map((l) => l.slice(0, 160)))].slice(0, 8), dev, gl };
          results.push(r);
          fs.appendFileSync(out, JSON.stringify(r) + '\n');
          console.log(`${bname} ${build} ${sc.area ?? '-'} h${sc.hour ?? '-'} ${(sc.extra ?? []).join(' ')} ${r.size}: ${st.fps} fps med ${st.med_ms} p95 ${st.p95_ms} p99 ${st.p99_ms} max ${st.max_ms} errs ${errs.length} warns ${warns.length}` + (gate ? ` gate ${JSON.stringify(gate)}` : '') + (perfLines.length ? `\n    ${perfLast}` : ''));
          const tcl = Date.now(); await ctx.close(); console.log(`  run ${(Date.now()-tr)/1000}s, close ${(Date.now()-tcl)/1000}s, load ${loadS}s`);
        }
      }
    }
  }
  const tc = Date.now(); await browser.close(); console.log(`closed in ${(Date.now()-tc)/1000}s`);
}
