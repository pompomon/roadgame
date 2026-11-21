// PF prototype: the frames around a run's first free, from the page's load (P13b).
// Usage: node hitch.mjs '<json config>'
// config: {browsers:["chrome","firefox"], builds:{name:baseUrl}, size:[w,h,dpr], area, hour, extras:{label:[args]},
//          secs:12, seed:1, reps:2, out:"file.jsonl"}
// It records every requestAnimationFrame timestamp from the document's start, and the time of each PFSPIKE and
// PERF line, and gives the interval that holds each hide_row line, against the run's other intervals.
import fs from 'node:fs';
const { chromium, firefox } = await import(process.env.PLAYWRIGHT_MODULE ?? 'playwright');

const cfg = JSON.parse(process.argv[2]);
const secs = cfg.secs ?? 12, reps = cfg.reps ?? 2;
const out = cfg.out ?? '/tmp/perf-hitch.jsonl';

const INIT = `
(() => {
  window.__frames = []; window.__lines = [];
  const raf = window.requestAnimationFrame.bind(window);
  function tick(t) { window.__frames.push(t); raf(tick); }
  raf(tick);
  const log = console.log;
  console.log = function (...a) {
    const s = a.map(String).join(' ');
    if (s.startsWith('PFSPIKE') || s.startsWith('PERF ')) window.__lines.push([performance.now(), s]);
    return log.apply(this, a);
  };
})();`;

function q(s, p) { return s[Math.min(s.length - 1, Math.floor(p * s.length))]; }

async function launch(name) {
  if (name === 'chrome') {
    return chromium.launch({ executablePath: process.env.CHROME ?? '/usr/bin/google-chrome', headless: false,
      args: ['--autoplay-policy=no-user-gesture-required', '--enable-unsafe-swiftshader', '--disable-background-timer-throttling', '--disable-renderer-backgrounding', '--disable-backgrounding-occluded-windows'] });
  }
  return firefox.launch({ headless: false, firefoxUserPrefs: { 'media.autoplay.default': 0 } });
}

const [w, h, dpr] = cfg.size ?? [360, 640, 1];
for (const bname of cfg.browsers) {
  const browser = await launch(bname);
  for (let rep = 0; rep < reps; rep++) {
    for (const [label, extra] of Object.entries(cfg.extras ?? { none: [] })) {
      for (const [build, base] of Object.entries(cfg.builds)) {
        const ctx = await browser.newContext({ viewport: { width: w, height: h }, deviceScaleFactor: dpr });
        const page = await ctx.newPage();
        await page.addInitScript(INIT);
        let started = null;
        const startedP = new Promise((res) => { started = res; });
        page.on('console', (m) => { if (/^(OpenGL API|Godot Engine)/.test(m.text())) started(); });
        const args = ['--autopilot', `--seed=${cfg.seed ?? 1}`, `--area=${cfg.area ?? 'city'}`, `--hour=${cfg.hour ?? 7}`, ...extra];
        await page.goto(base + '?' + args.map((a) => 'arg=' + encodeURIComponent(a)).join('&'));
        await Promise.race([startedP, new Promise((r) => setTimeout(r, 60000).unref())]);
        const tStart = await page.evaluate(() => performance.now());
        await page.waitForTimeout(secs * 1000);
        const { frames, lines } = await page.evaluate(() => ({ frames: window.__frames, lines: window.__lines }));
        await ctx.close();
        const iv = [];
        for (let i = 1; i < frames.length; i++) if (frames[i] >= tStart) iv.push([frames[i - 1], frames[i] - frames[i - 1]]);
        // The interval that holds a line: from the last frame at or before it to the next frame.
        const holding = (t) => { let k = iv.findIndex(([s, d]) => s <= t && t < s + d); return k; };
        const hides = lines.filter(([, s]) => s.startsWith('PFSPIKE hide_row'));
        const marked = new Map();
        for (const [t, s] of hides) {
          const k = holding(t);
          if (k < 0) continue;
          const us = +(/us=(\d+)/.exec(s)[1]);
          const m = marked.get(k) ?? { at: +(iv[k][0] - tStart).toFixed(0), ms: +iv[k][1].toFixed(1), rows: 0, hide_ms: 0, firsts: [] };
          m.rows++; m.hide_ms = +(m.hide_ms + us / 1000).toFixed(1); m.firsts.push(+(/first=(-?\d+)/.exec(s)[1]));
          marked.set(k, m);
        }
        const others = iv.filter((_, k) => !marked.has(k)).map(([, d]) => d).sort((a, b) => a - b);
        // The first free's frames, and the slowest interval within 250 ms after its first hide line.
        const firstHide = hides.length ? hides[0][0] : null;
        const near = firstHide === null ? [] : iv.filter(([s, d]) => s + d > firstHide - 50 && s < firstHide + 250).map(([, d]) => d);
        const perfHide = lines.filter(([, s]) => s.startsWith('PERF ')).map(([t, s]) => {
          const m = / hide_row=([0-9.]+)\/([0-9.]+)/.exec(s);
          return m ? [+(t - tStart).toFixed(0), +m[2]] : null;
        }).filter((x) => x && x[1] > 0);
        const r = { browser: bname, rep, build, label, extra, size: `${w}x${h}@${dpr}`, area: cfg.area ?? 'city', hour: cfg.hour ?? 7,
          frames: iv.length, first_hide_s: firstHide === null ? null : +((firstHide - tStart) / 1000).toFixed(2),
          hide_frames: [...marked.values()], near_max_ms: near.length ? +Math.max(...near).toFixed(1) : null,
          others: { med: +q(others, 0.5).toFixed(1), p95: +q(others, 0.95).toFixed(1), p99: +q(others, 0.99).toFixed(1), max: +others[others.length - 1].toFixed(1) },
          perf_hide_worst: perfHide,
          perf_first_s: (() => { const l = lines.find(([, s]) => s.startsWith('PERF ')); return l ? +((l[0] - tStart) / 1000).toFixed(2) : null; })(),
          long: iv.filter(([, d]) => d > 1.5 * q(others, 0.5)).map(([s, d]) => [+(s - tStart).toFixed(0), +d.toFixed(1)]).slice(0, 40) };
        fs.appendFileSync(out, JSON.stringify(r) + '\n');
        console.log(`${bname} ${build} ${label} rep ${rep}: first hide ${r.first_hide_s}s; hide frames ${JSON.stringify(r.hide_frames.map((m) => [m.at, m.ms, m.rows, m.hide_ms]))}; near max ${r.near_max_ms}; others ${JSON.stringify(r.others)}; PERF hide worst ${JSON.stringify(perfHide)}; first PERF ${r.perf_first_s}s; long ${JSON.stringify(r.long)}`);
      }
    }
  }
  await browser.close();
}
