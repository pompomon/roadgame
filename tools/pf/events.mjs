// PF prototype: measures the frames round a run's events in Web builds whose probe prints PFEVENT lines
// (autoload/pf_probe.gd), such as a legend's disaster after a missed turn, or the arrival at the pier.
// Usage: node events.mjs '<json config>'
// config: {browsers:["firefox"], builds:{name:baseUrl}, sizes:[[w,h,dpr]], variants:{name:[args]},
//          scenarios:[{name, args:[], from:"run_ended", secs:8, pre:4, before:"area coast"}], reps:1,
//          timeout:90, out:"file.jsonl"}
// Each run loads a build with a scenario's args and a variant's, waits for the event `from`, a PFEVENT
// line's text after "PFEVENT ", by its start, then `secs` more. It reports the page's frames over three
// windows: from the event to `secs` after it ("main"), the `pre` seconds before it, and with `before`,
// from that event's first line to `from`. Each window gives the rate, the median, P95, P99 and longest
// frame, and the slowest of its whole seconds from its start; "main" also the probe's slowest PERF line.
// PLAYWRIGHT_MODULE: Playwright's index.mjs, if `playwright` isn't importable; CHROME: Chrome's path.
import fs from 'node:fs';
const { chromium, firefox } = await import(process.env.PLAYWRIGHT_MODULE ?? 'playwright');

const cfg = JSON.parse(process.argv[2]);
const reps = cfg.reps ?? 1, timeout = (cfg.timeout ?? 90) * 1000;
const out = cfg.out ?? '/tmp/perf-events.jsonl';

// The page's frames, and the times of the probe's lines on the same clock.
const INIT = `
(() => {
  window.__frames = []; window.__events = []; window.__perf = [];
  function tick(t) { window.__frames.push(t); requestAnimationFrame(tick); }
  requestAnimationFrame(tick);
  const log = console.log;
  console.log = function (...a) {
    const s = String(a[0]);
    if (s.startsWith('PFEVENT ')) window.__events.push([performance.now(), s.slice(8)]);
    else if (s.startsWith('PERF ')) { const m = /fps=([0-9.]+).* p95=([0-9.]+)/.exec(s); if (m) window.__perf.push([performance.now(), +m[1], +m[2]]); }
    return log.apply(this, a);
  };
})();`;

function stats(frames, a, b) {
  const f = frames.filter((t) => t >= a && t <= b);
  if (f.length < 2) return { fps: 0, n: 0 };
  const iv = [];
  for (let i = 1; i < f.length; i++) iv.push(f[i] - f[i - 1]);
  const s = [...iv].sort((x, y) => x - y);
  const q = (p) => s[Math.min(s.length - 1, Math.floor(p * s.length))];
  let slowest = Infinity, at = -1;
  for (let k = 0; a + (k + 1) * 1000 <= b; k++) {
    const c = f.filter((t) => t >= a + k * 1000 && t < a + (k + 1) * 1000).length;
    if (c < slowest) { slowest = c; at = k; }
  }
  return { fps: +(iv.length / (f[f.length - 1] - f[0]) * 1000).toFixed(1), med_ms: +q(0.5).toFixed(1),
    p95_ms: +q(0.95).toFixed(1), p99_ms: +q(0.99).toFixed(1), max_ms: +s[s.length - 1].toFixed(1), n: iv.length,
    secs: +((b - a) / 1000).toFixed(2), slowest_s: slowest === Infinity ? null : slowest, slowest_at: at };
}

async function launch(name) {
  if (name === 'chrome') {
    return chromium.launch({ executablePath: process.env.CHROME ?? '/usr/bin/google-chrome', headless: false,
      args: ['--autoplay-policy=no-user-gesture-required', '--enable-unsafe-swiftshader', '--disable-background-timer-throttling', '--disable-renderer-backgrounding', '--disable-backgrounding-occluded-windows'] });
  }
  return firefox.launch({ headless: false, firefoxUserPrefs: { 'media.autoplay.default': 0, ...(cfg.firefoxPrefs ?? {}) } });
}

const variants = Object.entries(cfg.variants ?? { none: [] });
for (const bname of cfg.browsers) {
  const browser = await launch(bname);
  for (let rep = 0; rep < reps; rep++) {
    for (const sc of cfg.scenarios) {
      for (const [w, h, dpr] of cfg.sizes) {
        for (const [build, base] of Object.entries(cfg.builds)) {
          for (const [vname, vargs] of variants) {
            const tr = Date.now();
            const ctx = await browser.newContext({ viewport: { width: w, height: h }, deviceScaleFactor: dpr ?? 1 });
            const page = await ctx.newPage();
            await page.addInitScript(INIT);
            const logs = [];
            page.on('console', (m) => logs.push(`[${m.type()}] ${m.text()}`));
            page.on('pageerror', (e) => logs.push(`[pageerror] ${e.message}`));
            const args = [...sc.args, ...vargs];
            await page.goto(base + '?' + args.map((x) => 'arg=' + encodeURIComponent(x)).join('&'));
            const secs = sc.secs ?? 8, pre = sc.pre ?? 4, from = sc.from ?? 'run_ended';
            let timedOut = false;
            try {
              await page.waitForFunction((e) => window.__events.some(([, s]) => s.startsWith(e)), from, { polling: 250, timeout });
            } catch (e) { timedOut = true; }
            if (!timedOut) await page.waitForTimeout(secs * 1000 + 500);
            const { frames, events, perf } = await page.evaluate(() => ({ frames: window.__frames, events: window.__events, perf: window.__perf }));
            const t0 = frames[0] ?? 0;
            const at = (e) => events.find(([, s]) => s.startsWith(e))?.[0];
            const tf = at(from);
            const r = { browser: bname, rep, build, variant: vname, scenario: sc.name, size: `${w}x${h}@${dpr ?? 1}`, args, timedOut,
              events: events.map(([t, s]) => [+((t - t0) / 1000).toFixed(2), s]) };
            if (tf !== undefined) {
              r.main = stats(frames, tf, tf + secs * 1000);
              r.pre = stats(frames, tf - pre * 1000, tf);
              const lines = perf.filter(([t]) => t > tf && t <= tf + secs * 1000);
              r.perf_min_fps = lines.length ? Math.min(...lines.map(([, f]) => f)) : null;
              r.perf_max_p95 = lines.length ? Math.max(...lines.map(([, , p]) => p)) : null;
              const tb = sc.before ? at(sc.before) : undefined;
              if (tb !== undefined) r.before = stats(frames, tb, tf);
            }
            r.errs = logs.filter((l) => /^\[(error|pageerror)\]/.test(l) || /ERROR/.test(l)).slice(0, 5);
            r.warns = logs.filter((l) => /^\[warning\]/.test(l)).length;
            fs.appendFileSync(out, JSON.stringify(r) + '\n');
            const m = r.main ?? {};
            console.log(`${bname} ${build} ${vname} ${sc.name} ${r.size}: ${timedOut ? 'TIMED OUT ' : ''}main ${m.fps} fps p95 ${m.p95_ms} max ${m.max_ms} slowest ${m.slowest_s}@${m.slowest_at}s perf_min ${r.perf_min_fps}`
              + (r.pre ? ` | pre ${r.pre.fps}` : '') + (r.before ? ` | before ${r.before.fps} (${r.before.secs}s)` : '')
              + ` | ${r.events.map(([t, s]) => `${t}:${s}`).join(' ')} | errs ${r.errs.length} warns ${r.warns} | ${(Date.now() - tr) / 1000}s`);
            await ctx.close();
          }
        }
      }
    }
  }
  await browser.close();
}
