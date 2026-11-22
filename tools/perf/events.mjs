// Time ends by EVENT frame counts, and ways in by complete PERF windows (PERF_PLAN.md E2).
// node events.mjs '{"browsers":["firefox"],"builds":{"main":"http://localhost:8000/"},
//   "sizes":[[360,640,2]],"scenarios":"tools/perf/ends.json","reps":2,"out":"ends.jsonl"}'
// Scenarios: {name,args,from:"run_ended",to:"game_over",expect:[],before,timeout:90,
//   windows:[{at:"area rural",pre:6,secs:2}]}. Exports must take ?arg=.
import fs from 'node:fs';
import { pathToFileURL } from 'node:url';
import { gameRate, parsePerf } from './measure.mjs';

export function perfWindow(perf, a, b) {
  return perf.filter((w) => w.at - w.us / 1000 >= a && w.at <= b);
}

export function eventRate(from, to) {
  const n = to.frames - from.frames, ms = to.at - from.at;
  if (n < 2 || ms <= 0) throw new Error('Events have no forward frame interval');
  return { fps: n * 1000 / ms, n, secs: ms / 1000 };
}

const INIT = `
(() => {
  window.__frames = []; window.__events = []; window.__perf = [];
  function tick(t) { window.__frames.push(t); requestAnimationFrame(tick); }
  requestAnimationFrame(tick);
  const log = console.log;
  console.log = function (...args) {
    const s = args.map(String).join(' '), at = performance.now();
    const event = /^EVENT (.*?) frames=(\\d+)$/.exec(s);
    if (event) window.__events.push({ at, text: event[1], frames: Number(event[2]) });
    if (s.startsWith('PERF ')) window.__perf.push({ at, line: s });
    return log.apply(this, args);
  };
})();`;

const matches = (s, event) => s === event || s.startsWith(event + ' ');
const isErr = (line) => /^\[(error|pageerror)\]/.test(line) || /ERROR/.test(line);

function within(promise, ms, what) {
  let timer;
  const deadline = new Promise((_, reject) => {
    timer = setTimeout(() => reject(new Error(`${what}: no answer in ${ms / 1000} s`)), ms);
  });
  return Promise.race([promise, deadline]).finally(() => clearTimeout(timer));
}

function pageStats(frames, a, b) {
  const f = frames.filter((t) => t > a && t <= b);
  if (f.length < 2) return { page_fps: 0, page_n: f.length };
  const intervals = f.slice(1).map((t, i) => t - f[i]).sort((x, y) => x - y);
  const q = (p) => intervals[Math.max(0, Math.ceil(p * intervals.length) - 1)];
  return { page_fps: f.length * 1000 / (b - a), page_n: f.length,
    med_ms: q(0.5), p95_ms: q(0.95),
    max_ms: Math.max(intervals.at(-1), f[0] - a, b - f.at(-1)) };
}

export async function main(cfg) {
  const { chromium, firefox } = await import(process.env.PLAYWRIGHT_MODULE ?? 'playwright');
  for (const name of cfg.browsers) {
    if (!['chrome', 'firefox'].includes(name)) throw new Error(`Unknown browser: ${name}`);
  }
  const scenarios = typeof cfg.scenarios === 'string'
    ? JSON.parse(fs.readFileSync(cfg.scenarios, 'utf8')) : cfg.scenarios;
  const out = cfg.out ?? '/tmp/perf-events.jsonl';
  let failed = 0;

  async function close(holder, name) {
    try {
      await within(holder.server.close(), 30000, 'browser.close');
    } catch (error) {
      console.error(`${name}: ${error.message}; killing this browser`);
      await within(holder.server.kill(), 30000, 'browser.kill');
    }
  }

  async function launch(name) {
    const type = name === 'chrome' ? chromium : firefox;
    const server = await type.launchServer(name === 'chrome'
      ? { executablePath: process.env.CHROME ?? '/usr/bin/google-chrome', headless: false,
        args: ['--autoplay-policy=no-user-gesture-required', '--enable-unsafe-swiftshader',
          '--disable-background-timer-throttling', '--disable-renderer-backgrounding',
          '--disable-backgrounding-occluded-windows'] }
      : { headless: false, firefoxUserPrefs: { 'media.autoplay.default': 0, ...(cfg.firefoxPrefs ?? {}) } });
    try {
      return { server, browser: await within(type.connect(server.wsEndpoint()), 30000, 'connect') };
    } catch (error) {
      await close({ server }, name);
      throw error;
    }
  }

  async function run(holder, sc, size, base) {
    const [w, h, dpr = 1] = size;
    holder.ctx = await within(holder.browser.newContext({
      viewport: { width: w, height: h }, deviceScaleFactor: dpr,
    }), 30000, 'newContext');
    const page = await within(holder.ctx.newPage(), 30000, 'newPage');
    await within(page.addInitScript(INIT), 30000, 'addInitScript');
    holder.logs = [];
    page.on('console', (m) => holder.logs.push(`[${m.type()}] ${m.text()}`));
    page.on('pageerror', (e) => holder.logs.push(`[pageerror] ${e.message}`));
    const args = [...sc.args, '--fps'];
    await within(page.goto(base + '?' + args.map((a) => 'arg=' + encodeURIComponent(a)).join('&')), 60000, 'goto');
    const from = sc.from ?? 'run_ended', secs = sc.secs ?? 8;
    const timeout = Math.max(cfg.timeout ?? 90, sc.timeout ?? 0) * 1000;
    const toMs = (sc.within ?? 15) * 1000;
    holder.failed = false;
    try {
      await within(page.waitForFunction((event) =>
        window.__events.some((e) => e.text === event || e.text.startsWith(event + ' ')),
      from, { polling: 250, timeout }), timeout + 15000, 'wait for start event');
    } catch (error) {
      holder.failed = error.name === 'TimeoutError';
      throw error;
    }
    await page.waitForTimeout(secs * 1000 + 500);
    if (sc.to) {
      try {
        await within(page.waitForFunction(([from, to]) => {
          const match = (s, e) => s === e || s.startsWith(e + ' ');
          const i = window.__events.findIndex((e) => match(e.text, from));
          return i >= 0 && window.__events.slice(i + 1).some((e) => match(e.text, to));
        }, [from, sc.to], { polling: 250, timeout: toMs }), toMs + 15000, 'wait for end event');
      } catch (error) {
        holder.failed = error.name === 'TimeoutError';
        throw error;
      }
    }
    const snap = await within(page.evaluate(() => ({
      frames: window.__frames, events: window.__events, perf: window.__perf,
    })), 30000, 'snapshot');
    const { frames, events } = snap;
    const perf = snap.perf.map((w) => ({ at: w.at, ...parsePerf(w.line) }));
    const index = (event, start = 0) => events.findIndex((e, i) => i >= start && matches(e.text, event));
    const fi = index(from), first = events[fi], missing = [];
    const r = { events, main: pageStats(frames, first.at, first.at + secs * 1000),
      pre: pageStats(frames, first.at - (sc.pre ?? 4) * 1000, first.at), windows: [] };
    if (sc.to) {
      const last = events[index(sc.to, fi + 1)];
      if (!last || last.at - first.at > toMs) missing.push(sc.to);
      else {
        const lines = perfWindow(perf, first.at, last.at);
        r.end = { ...pageStats(frames, first.at, last.at), ...eventRate(first, last) };
        r.end_perf_min_fps = lines.length ? Math.min(...lines.map((w) => w.fps)) : null;
        r.end_perf_n = lines.length;
      }
    }
    if (sc.before) {
      const bi = index(sc.before);
      if (bi < 0 || bi >= fi) missing.push(sc.before);
      else r.before = { ...pageStats(frames, events[bi].at, first.at), ...eventRate(events[bi], first) };
    }
    for (const window of sc.windows ?? []) {
      const event = events[index(window.at)];
      if (!event) { missing.push(window.at); continue; }
      const a = event.at - window.pre * 1000, b = event.at + window.secs * 1000;
      const lines = perfWindow(perf, a, b);
      if (a < frames[0] || b > frames.at(-1) || !lines.length) {
        missing.push(`${window.at}: no complete recorded window`);
        continue;
      }
      r.windows.push({ at: window.at, ...pageStats(frames, a, b), ...gameRate(lines),
        perf_min_fps: Math.min(...lines.map((w) => w.fps)),
        perf_max_p95: Math.max(...lines.map((w) => w.p95)), perf_n: lines.length });
    }
    missing.push(...(sc.expect ?? []).filter((event) => index(event) < 0));
    r.missing = missing;
    r.errs = holder.logs.filter(isErr);
    r.warns = holder.logs.filter((line) => /^\[warning\]/.test(line)).length;
    return r;
  }

  for (const bname of cfg.browsers) {
    let holder = await launch(bname);
    try {
      for (let rep = 0; rep < (cfg.reps ?? 1); rep++) {
        for (const sc of scenarios) {
          for (const size of cfg.sizes) {
            for (const [build, base] of Object.entries(cfg.builds)) {
              for (let attempt = 0; ; attempt++) {
                let r;
                try {
                  r = await run(holder, sc, size, base);
                } catch (error) {
                  const errs = (holder.logs ?? []).filter(isErr);
                  r = { error: String(error), failed: !!holder.failed || errs.length > 0, errs, missing: [] };
                }
                const again = !!r.error && !r.failed && attempt < (cfg.retries ?? 1);
                const record = { browser: bname, rep, build, scenario: sc.name,
                  size: `${size[0]}x${size[1]}@${size[2] ?? 1}`, attempt, ...r };
                fs.appendFileSync(out, JSON.stringify(record) + '\n');
                console.log(JSON.stringify(record));
                if (!again && (r.error || r.missing.length || r.errs.length)) failed++;
                let restart = !!r.error;
                try {
                  if (holder.ctx) await within(holder.ctx.close(), 30000, 'context.close');
                } catch (error) {
                  console.error(`${bname}: ${error.message}; restarting this browser`);
                  restart = true;
                }
                if (restart) {
                  await close(holder, bname);
                  holder = await launch(bname);
                }
                if (!again) break;
                console.error(`${bname}: retrying the unresponsive run`);
              }
            }
          }
        }
      }
    } finally {
      await close(holder, bname);
    }
  }
  if (failed) throw new Error(`${failed} run(s) missed their events, logged errors or did not answer`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await main(JSON.parse(process.argv[2]));
}
