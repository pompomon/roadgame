// PF prototype: measures the frames round a run's events in Web builds whose probe prints PFEVENT lines
// (autoload/pf_probe.gd), such as a legend's disaster after a missed turn, or the arrival at the pier.
// Usage: node events.mjs '<json config>'
// config: {browsers:["firefox"], builds:{name:baseUrl}, sizes:[[w,h,dpr]], variants:{name:[args]},
//          scenarios:[{name, args:[], from:"run_ended", secs:8, pre:4, before:"area coast", to:"game_over",
//          expect:["disaster_started ufo"]}] or a file of them, such as "tools/pf/ends.json", reps:1,
//          timeout:90, out:"file.jsonl"}
// Each run loads a build with a scenario's args and a variant's, waits for the event `from`, a PFEVENT
// line's text after "PFEVENT ", by its start, then `secs` more. It reports the page's frames over three
// windows: from the event to `secs` after it ("main"), the `pre` seconds before it, and with `before`,
// from that event's first line to `from`. Each window gives the rate, the median, P95, P99 and longest
// frame, and the slowest of its whole seconds from its start; "main" also the probe's slowest PERF line.
// With `to`, it waits for that event after `from`, and reports the frames between them ("end"), and the
// slowest of the probe's PERF lines whose 1 s windows lie between them; `missing` lists the events of
// `expect`, and `to`, that the run didn't print, such as another legend's: such a run doesn't count,
// and the script exits 1 once all have run, as it does if a run timed out or a step didn't answer.
// PLAYWRIGHT_MODULE: Playwright's index.mjs, if `playwright` isn't importable; CHROME: Chrome's path.
import fs from 'node:fs';
const { chromium, firefox } = await import(process.env.PLAYWRIGHT_MODULE ?? 'playwright');

const cfg = JSON.parse(process.argv[2]);
const reps = cfg.reps ?? 1, timeout = (cfg.timeout ?? 90) * 1000;
const out = cfg.out ?? '/tmp/perf-events.jsonl';
const scenarios = typeof cfg.scenarios === 'string' ? JSON.parse(fs.readFileSync(cfg.scenarios, 'utf8')) : cfg.scenarios;
let failed = 0;

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
// A step that doesn't answer, as a page that never runs, fails its run instead of the script.
const within = (p, ms, what) => Promise.race([p, new Promise((_, no) => setTimeout(() => no(new Error(`${what}: no answer in ${ms / 1000} s`)), ms))]);

async function run(browser, bname, rep, sc, [w, h, dpr], build, base, vname, vargs, holder) {
  const tr = Date.now();
  const ctx = await within(browser.newContext({ viewport: { width: w, height: h }, deviceScaleFactor: dpr ?? 1 }), 30000, 'newContext');
  holder.ctx = ctx;
  const page = await within(ctx.newPage(), 30000, 'newPage');
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
  if (!timedOut && sc.to) {
    try {
      await page.waitForFunction((e) => window.__events.some(([, s]) => s.startsWith(e)), sc.to, { polling: 250, timeout: 15000 });
    } catch (e) { /* reported in `missing` */ }
  }
  const { frames, events, perf } = await within(page.evaluate(() => ({ frames: window.__frames, events: window.__events, perf: window.__perf })), 30000, 'evaluate');
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
    const tt = sc.to ? events.find(([t, s]) => t >= tf && s.startsWith(sc.to))?.[0] : undefined;
    if (tt !== undefined) {
      r.end = stats(frames, tf, tt);
      const el = perf.filter(([t]) => t >= tf + 1000 && t <= tt);
      r.end_perf_min_fps = el.length ? Math.min(...el.map(([, f]) => f)) : null;
      r.end_perf_n = el.length;
    }
  }
  r.missing = [...(sc.expect ?? []), ...(sc.to ? [sc.to] : [])].filter((e) => !events.some(([, s]) => s.startsWith(e)));
  r.errs = logs.filter((l) => /^\[(error|pageerror)\]/.test(l) || /ERROR/.test(l)).slice(0, 5);
  r.warns = logs.filter((l) => /^\[warning\]/.test(l)).length;
  const m = r.main ?? {};
  r.log = `${bname} ${build} ${vname} ${sc.name} ${r.size}: ${timedOut ? 'TIMED OUT ' : ''}main ${m.fps} fps p95 ${m.p95_ms} max ${m.max_ms} slowest ${m.slowest_s}@${m.slowest_at}s perf_min ${r.perf_min_fps}`
    + (r.pre ? ` | pre ${r.pre.fps}` : '') + (r.before ? ` | before ${r.before.fps} (${r.before.secs}s)` : '')
    + (r.end ? ` | end ${r.end.fps} fps (${r.end.secs}s) slowest ${r.end.slowest_s} perf_min ${r.end_perf_min_fps}/${r.end_perf_n}` : '')
    + (r.missing.length ? ` | MISSING ${r.missing.join(', ')}` : '')
    + ` | ${r.events.map(([t, s]) => `${t}:${s}`).join(' ')} | errs ${r.errs.length} warns ${r.warns} | ${(Date.now() - tr) / 1000}s`;
  return r;
}

for (const bname of cfg.browsers) {
  let browser = await launch(bname);
  for (let rep = 0; rep < reps; rep++) {
    for (const sc of scenarios) {
      for (const size of cfg.sizes) {
        for (const [build, base] of Object.entries(cfg.builds)) {
          for (const [vname, vargs] of variants) {
            const holder = {};
            let r;
            try {
              r = await run(browser, bname, rep, sc, size, build, base, vname, vargs, holder);
            } catch (e) {
              r = { browser: bname, rep, build, variant: vname, scenario: sc.name, size: `${size[0]}x${size[1]}@${size[2] ?? 1}`, error: String(e), missing: [] };
              r.log = `${bname} ${build} ${vname} ${sc.name} ${r.size}: ERROR ${e.message}`;
            }
            if (r.error || r.timedOut || r.missing.length) failed++;
            const { log, ...rec } = r;
            fs.appendFileSync(out, JSON.stringify(rec) + '\n');
            console.log(log);
            // A run whose step didn't answer, or whose page won't close, may have left the browser stuck.
            let restart = !!r.error;
            try {
              if (holder.ctx) await within(holder.ctx.close(), 30000, 'close');
            } catch (e) {
              console.log(`${bname}: ${e.message}`);
              restart = true;
            }
            if (restart) {
              console.log(`${bname}: the browser starts again`);
              await within(browser.close(), 30000, 'browser.close').catch(() => {});
              browser = await launch(bname);
            }
          }
        }
      }
    }
  }
  await browser.close();
}
if (failed) {
  console.log(`FAILED: ${failed} run(s) timed out, missed their events or had a step that didn't answer`);
  process.exitCode = 1;
}
