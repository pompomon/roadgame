// PF prototype: measures the frames round a run's events in Web builds whose probe prints PFEVENT lines
// (autoload/pf_probe.gd), such as a legend's disaster after a missed turn, or the arrival at the pier.
// Usage: node events.mjs '<json config>'
// config: {browsers:["firefox"], builds:{name:baseUrl}, sizes:[[w,h,dpr]], variants:{name:[args]},
//          scenarios:[{name, args:[], from:"run_ended", secs:8, pre:4, before:"area coast", to:"game_over",
//          within:15, expect:["disaster_started ufo"]}] or a file of them, such as "tools/pf/ends.json", reps:1,
//          timeout:90, retries:1, out:"file.jsonl"}
// A browser is "firefox" or "chrome"; another name stops the script with 2.
// An event matches a PFEVENT line whose text after "PFEVENT " is the event, or starts with it and a space.
// Each run loads a build with a scenario's args and a variant's, waits for the event `from`, then `secs`
// more. It reports the page's frames over three windows: from the event to `secs` after it ("main"), the
// `pre` seconds before it, and with `before`, from that event's first line to `from`. Each window gives
// the rate, its frames over its whole time, so that a stall at an edge counts, the median, P95, P99 and
// longest frame, and the slowest of its whole seconds; "main" also the probe's slowest PERF line.
// With `to`, it waits for that event after `from`, and reports the frames between them
// ("end"), and the slowest of the probe's PERF lines whose 1 s windows lie wholly between them, those
// after the first that closes after `from`. `missing` lists the events of `expect` that the run didn't
// print, such as another legend's, and `to` if it didn't follow `from` within `within` seconds by their
// lines' times: such a run doesn't count, and the script exits 1 once all have run, as it does if a run
// timed out, logged an error or had a step that didn't answer. A step that doesn't answer, as when
// Firefox stops answering, starts the browser again and runs the run again, up to `retries` times; each
// attempt is written, the failed ones with `error`. Each wait has a deadline of its own, as Playwright's
// doesn't fire once the page stops answering while it polls; and a run whose wait timed out, or that
// logged an error, has failed even if a later step doesn't answer, so it doesn't run again.
// A browser that won't close is killed, and one that won't die stops the script with 1, as it could
// slow the runs after it.
// PLAYWRIGHT_MODULE: Playwright's index.mjs, if `playwright` isn't importable; CHROME: Chrome's path.
import fs from 'node:fs';
const { chromium, firefox } = await import(process.env.PLAYWRIGHT_MODULE ?? 'playwright');

const cfg = JSON.parse(process.argv[2]);
const reps = cfg.reps ?? 1, timeout = (cfg.timeout ?? 90) * 1000, retries = cfg.retries ?? 1;
const out = cfg.out ?? '/tmp/perf-events.jsonl';
const scenarios = typeof cfg.scenarios === 'string' ? JSON.parse(fs.readFileSync(cfg.scenarios, 'utf8')) : cfg.scenarios;
let failed = 0;
for (const n of cfg.browsers) {
  if (n !== 'firefox' && n !== 'chrome') {
    console.log(`unknown browser ${n}: firefox or chrome`);
    process.exit(2);
  }
}
const isErr = (l) => /^\[(error|pageerror)\]/.test(l) || /ERROR/.test(l);

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
  const f = frames.filter((t) => t > a && t <= b);
  if (f.length < 2) return { fps: 0, n: f.length };
  const iv = [];
  for (let i = 1; i < f.length; i++) iv.push(f[i] - f[i - 1]);
  const s = [...iv].sort((x, y) => x - y);
  const q = (p) => s[Math.min(s.length - 1, Math.floor(p * s.length))];
  let slowest = Infinity, at = -1;
  for (let k = 0; a + (k + 1) * 1000 <= b; k++) {
    const c = f.filter((t) => t > a + k * 1000 && t <= a + (k + 1) * 1000).length;
    if (c < slowest) { slowest = c; at = k; }
  }
  return { fps: +(f.length / (b - a) * 1000).toFixed(1), med_ms: +q(0.5).toFixed(1),
    p95_ms: +q(0.95).toFixed(1), p99_ms: +q(0.99).toFixed(1),
    max_ms: +Math.max(s[s.length - 1], f[0] - a, b - f[f.length - 1]).toFixed(1), n: f.length,
    secs: +((b - a) / 1000).toFixed(2), slowest_s: slowest === Infinity ? null : slowest, slowest_at: at };
}

// A server, so that a browser that won't close can be killed: a launched browser has no handle on its process.
async function launch(name) {
  const type = name === 'chrome' ? chromium : firefox;
  const server = await type.launchServer(name === 'chrome'
    ? { executablePath: process.env.CHROME ?? '/usr/bin/google-chrome', headless: false,
      args: ['--autoplay-policy=no-user-gesture-required', '--enable-unsafe-swiftshader', '--disable-background-timer-throttling', '--disable-renderer-backgrounding', '--disable-backgrounding-occluded-windows'] }
    : { headless: false, firefoxUserPrefs: { 'media.autoplay.default': 0, ...(cfg.firefoxPrefs ?? {}) } });
  try {
    return { server, browser: await within(type.connect(server.wsEndpoint()), 30000, 'connect') };
  } catch (e) {
    await closeOrKill({ server }, name);
    throw e;
  }
}

const variants = Object.entries(cfg.variants ?? { none: [] });
// A step that doesn't answer, as a page that never runs, fails its run instead of the script.
function within(p, ms, what) {
  let id;
  const late = new Promise((_, no) => { id = setTimeout(() => no(new Error(`${what}: no answer in ${ms / 1000} s`)), ms); });
  return Promise.race([p, late]).finally(() => clearTimeout(id));
}
async function closeOrKill(b, bname) {
  try {
    await within(b.server.close(), 30000, 'browser.close');
  } catch (e) {
    console.log(`${bname}: ${e.message}: killed`);
    try {
      await within(b.server.kill(), 30000, 'browser.kill');
    } catch (e2) {
      console.log(`${bname}: ${e2.message}: stopped`);
      process.exit(1);
    }
  }
}
const is = (s, e) => s === e || s.startsWith(e + ' ');

async function run(browser, bname, rep, sc, [w, h, dpr], build, base, vname, vargs, holder) {
  const tr = Date.now();
  const ctx = await within(browser.newContext({ viewport: { width: w, height: h }, deviceScaleFactor: dpr ?? 1 }), 30000, 'newContext');
  holder.ctx = ctx;
  const page = await within(ctx.newPage(), 30000, 'newPage');
  await within(page.addInitScript(INIT), 30000, 'addInitScript');
  const logs = [];
  holder.logs = logs;
  page.on('console', (m) => logs.push(`[${m.type()}] ${m.text()}`));
  page.on('pageerror', (e) => logs.push(`[pageerror] ${e.message}`));
  const args = [...sc.args, ...vargs];
  await within(page.goto(base + '?' + args.map((x) => 'arg=' + encodeURIComponent(x)).join('&')), 60000, 'goto');
  const secs = sc.secs ?? 8, pre = sc.pre ?? 4, from = sc.from ?? 'run_ended', toMs = (sc.within ?? 15) * 1000;
  let timedOut = false, late = false;
  // A TimeoutError is the page's answer; the deadline's error, a step that didn't answer.
  const wait = (p, ms) => within(p, ms + 15000, 'waitForFunction');
  try {
    await wait(page.waitForFunction((e) => window.__events.some(([, s]) => s === e || s.startsWith(e + ' ')), from, { polling: 250, timeout }), timeout);
  } catch (e) {
    if (e.name !== 'TimeoutError') throw e;
    timedOut = true;
  }
  if (!timedOut) await page.waitForTimeout(secs * 1000 + 500);
  if (!timedOut && sc.to) {
    try {
      await wait(page.waitForFunction(([f, t]) => {
        const m = (s, e) => s === e || s.startsWith(e + ' ');
        const i = window.__events.findIndex(([, s]) => m(s, f));
        return i >= 0 && window.__events.slice(i + 1).some(([, s]) => m(s, t));
      }, [from, sc.to], { polling: 250, timeout: toMs }), toMs);
    } catch (e) {
      if (e.name !== 'TimeoutError') throw e;
      late = true;
    }
  }
  let snap;
  try {
    snap = await within(page.evaluate(() => ({ frames: window.__frames, events: window.__events, perf: window.__perf })), 30000, 'evaluate');
  } catch (e) {
    e.failed = timedOut || late;
    throw e;
  }
  const { frames, events, perf } = snap;
  const t0 = frames[0] ?? 0;
  const idx = (e, i = 0) => events.findIndex(([, s], j) => j >= i && is(s, e));
  const fi = idx(from), tf = events[fi]?.[0];
  const r = { browser: bname, rep, build, variant: vname, scenario: sc.name, size: `${w}x${h}@${dpr ?? 1}`, args, timedOut,
    events: events.map(([t, s]) => [+((t - t0) / 1000).toFixed(2), s]) };
  let tt;
  if (fi >= 0) {
    r.main = stats(frames, tf, tf + secs * 1000);
    r.pre = stats(frames, tf - pre * 1000, tf);
    const lines = perf.filter(([t]) => t > tf && t <= tf + secs * 1000);
    r.perf_min_fps = lines.length ? Math.min(...lines.map(([, f]) => f)) : null;
    r.perf_max_p95 = lines.length ? Math.max(...lines.map(([, , p]) => p)) : null;
    const bi = sc.before ? idx(sc.before) : -1;
    if (bi >= 0) r.before = stats(frames, events[bi][0], tf);
    const ti = sc.to && !late ? idx(sc.to, fi + 1) : -1;
    if (ti >= 0) {
      tt = events[ti][0];
      r.end = stats(frames, tf, tt);
      const first = perf.findIndex(([t]) => t > tf);
      const el = first < 0 ? [] : perf.slice(first + 1).filter(([t]) => t <= tt);
      r.end_perf_min_fps = el.length ? Math.min(...el.map(([, f]) => f)) : null;
      r.end_perf_n = el.length;
      if (tt - tf > toMs) r.late = true;
    }
  }
  r.missing = [...(sc.expect ?? []).filter((e) => idx(e) < 0), ...(sc.to && (!(r.end?.n >= 2) || r.late) ? [sc.to] : [])];
  r.errs = logs.filter(isErr).slice(0, 5);
  r.warns = logs.filter((l) => /^\[warning\]/.test(l)).length;
  const m = r.main ?? {};
  r.log = `${bname} ${build} ${vname} ${sc.name} ${r.size}: ${timedOut ? 'TIMED OUT ' : ''}main ${m.fps} fps p95 ${m.p95_ms} max ${m.max_ms} slowest ${m.slowest_s}@${m.slowest_at}s perf_min ${r.perf_min_fps}`
    + (r.pre ? ` | pre ${r.pre.fps}` : '') + (r.before ? ` | before ${r.before.fps} (${r.before.secs}s)` : '')
    + (r.end ? ` | end ${r.end.fps} fps (${r.end.secs}s) slowest ${r.end.slowest_s} perf_min ${r.end_perf_min_fps}/${r.end_perf_n}` : '')
    + (r.missing.length ? ` | MISSING ${r.missing.join(', ')}` : '') + (r.late ? ' (LATE)' : '')
    + ` | ${r.events.map(([t, s]) => `${t}:${s}`).join(' ')} | errs ${r.errs.length} warns ${r.warns} | ${(Date.now() - tr) / 1000}s`;
  return r;
}

for (const bname of cfg.browsers) {
  let b = await launch(bname);
  for (let rep = 0; rep < reps; rep++) {
    for (const sc of scenarios) {
      for (const size of cfg.sizes) {
        for (const [build, base] of Object.entries(cfg.builds)) {
          for (const [vname, vargs] of variants) {
            for (let attempt = 0; ; attempt++) {
              const holder = {};
              let r;
              try {
                r = await run(b.browser, bname, rep, sc, size, build, base, vname, vargs, holder);
              } catch (e) {
                const errs = (holder.logs ?? []).filter(isErr).slice(0, 5);
                r = { browser: bname, rep, build, variant: vname, scenario: sc.name, size: `${size[0]}x${size[1]}@${size[2] ?? 1}`, error: String(e), failed: !!e.failed || errs.length > 0, errs, missing: [] };
                r.log = `${bname} ${build} ${vname} ${sc.name} ${r.size}: ERROR ${e.message}` + (errs.length ? ` | errs ${errs.length}` : '');
              }
              r.attempt = attempt;
              const again = !!r.error && !r.failed && attempt < retries;
              if (!again && (r.error || r.timedOut || r.missing.length || r.errs?.length)) failed++;
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
                await closeOrKill(b, bname);
                b = await launch(bname);
              }
              if (!again) break;
              console.log(`${bname}: the run runs again`);
            }
          }
        }
      }
    }
  }
  await closeOrKill(b, bname);
}
if (failed) {
  console.log(`FAILED: ${failed} run(s) timed out, missed their events, logged an error or had a step that didn't answer`);
  process.exitCode = 1;
}
