// Compare Web exports in headed Chrome/Firefox under Xvfb (PERF_PLAN.md E2, §6.5).
// node measure.mjs '{"browsers":["firefox"],"builds":{"main":"http://localhost:8000/"},
//   "sizes":[[360,640,2]],"scenarios":[{"area":"city","hour":7}],"reps":2,"out":"results.jsonl"}'
// Exports must take ?arg=. PLAYWRIGHT_MODULE and CHROME override the local browser tooling.
import fs from 'node:fs';
import { pathToFileURL } from 'node:url';

export function parsePerf(line) {
  const values = Object.fromEntries([...line.matchAll(/\b([a-z_0-9]+)=([0-9.]+)/g)]
    .map((m) => [m[1], Number(m[2])]));
  if (!Number.isSafeInteger(values.n) || values.n <= 0 || !Number.isSafeInteger(values.us) || values.us <= 0) {
    throw new Error(`PERF line lacks a positive frame count or duration: ${line}`);
  }
  return values;
}

export function gameRate(lines) {
  if (!lines.length) throw new Error('No complete PERF windows in the recording');
  const windows = lines.map((line) => typeof line === 'string' ? parsePerf(line) : line);
  const n = windows.reduce((sum, w) => sum + w.n, 0);
  const us = windows.reduce((sum, w) => sum + w.us, 0);
  return { fps: n * 1000000 / us, n, us };
}

const INIT = `
(() => {
  let rec = false, frames = [], lines = [];
  window.__engineStart = null;
  function tick(t) { if (rec) frames.push(t); requestAnimationFrame(tick); }
  requestAnimationFrame(tick);
  const log = console.log;
  console.log = function (...args) {
    const s = args.map(String).join(' ');
    if (window.__engineStart === null && /^(OpenGL API|Godot Engine)/.test(s)) window.__engineStart = performance.now();
    if (rec && s.startsWith('PERF ')) lines.push(s);
    return log.apply(this, args);
  };
  window.__perfStart = () => { frames = []; lines = []; rec = true; };
  window.__perfStop = () => { rec = false; return { frames, lines }; };
})();`;

function pageStats(frames) {
  if (frames.length < 2) throw new Error('No page frames in the recording');
  const intervals = frames.slice(1).map((t, i) => t - frames[i]);
  intervals.sort((a, b) => a - b);
  const rank = (p) => intervals[Math.max(0, Math.ceil(p * intervals.length) - 1)];
  return { page_fps: intervals.length * 1000 / (frames.at(-1) - frames[0]),
    med_ms: rank(0.5), p95_ms: rank(0.95), p99_ms: rank(0.99), max_ms: intervals.at(-1) };
}

export async function main(cfg) {
  const { chromium, firefox } = await import(process.env.PLAYWRIGHT_MODULE ?? 'playwright');
  const warm = cfg.warm ?? 6, secs = cfg.secs ?? 15, reps = cfg.reps ?? 1;
  const out = cfg.out ?? '/tmp/perf-results.jsonl';
  for (const name of cfg.browsers) {
    if (!['chrome', 'firefox'].includes(name)) throw new Error(`Unknown browser: ${name}`);
  }
  for (const bname of cfg.browsers) {
    const browser = await (bname === 'chrome'
      ? chromium.launch({ executablePath: process.env.CHROME ?? '/usr/bin/google-chrome', headless: false,
        args: ['--autoplay-policy=no-user-gesture-required', '--enable-unsafe-swiftshader',
          '--disable-background-timer-throttling', '--disable-renderer-backgrounding',
          '--disable-backgrounding-occluded-windows',
          ...(cfg.uncap ? ['--disable-gpu-vsync', '--disable-frame-rate-limit'] : [])] })
      : firefox.launch({ headless: false, firefoxUserPrefs: {
        'media.autoplay.default': 0, ...(cfg.firefoxPrefs ?? {}),
      } }));
    try {
      for (let rep = 0; rep < reps; rep++) {
        for (const sc of cfg.scenarios) {
          for (const [w, h, dpr = 1] of cfg.sizes) {
            for (const [build, base] of Object.entries(cfg.builds)) {
              const ctx = await browser.newContext({ viewport: { width: w, height: h }, deviceScaleFactor: dpr });
              try {
                const page = await ctx.newPage();
                await page.addInitScript(INIT);
                const logs = [];
                page.on('console', (m) => logs.push(`[${m.type()}] ${m.text()}`));
                page.on('pageerror', (e) => logs.push(`[pageerror] ${e.message}`));
                const args = ['--autopilot', '--fps', `--seed=${cfg.seed ?? 1}`];
                if (sc.area) args.push(`--area=${sc.area}`);
                if (sc.hour !== undefined) args.push(`--hour=${sc.hour}`);
                args.push(...(sc.extra ?? []));
                await page.goto(base + '?' + args.map((a) => 'arg=' + encodeURIComponent(a)).join('&'));
                await page.waitForFunction(() => window.__engineStart !== null, null, { timeout: 60000 });
                await page.waitForTimeout(warm * 1000);
                await page.evaluate(() => window.__perfStart());
                await page.waitForTimeout(secs * 1000);
                const { frames, lines } = await page.evaluate(() => window.__perfStop());
                // The first window opened before this record; the remaining windows are complete.
                const complete = lines.slice(1);
                const rate = gameRate(complete);
                const windows = complete.map(parsePerf);
                const perf = {};
                for (const key of Object.keys(windows[0])) {
                  perf[key] = windows.reduce((sum, win) => sum + win[key], 0) / windows.length;
                }
                const gate = await page.evaluate(() => {
                  const g = window.__framePacing;
                  return g ? { cap: g.cap, n: g.n, skipped: g.skipped, refresh: g.refresh,
                    steps: g.steps.length, runner: !!g.runner } : null;
                });
                const errs = logs.filter((l) => /^\[(error|pageerror)\]/.test(l) || /ERROR/.test(l));
                const warns = logs.filter((l) => /^\[warning\]/.test(l));
                const r = { browser: bname, rep, build, area: sc.area, hour: sc.hour,
                  extra: sc.extra ?? [], size: `${w}x${h}@${dpr}`, ...pageStats(frames), ...rate, perf,
                  early_per_s: windows.reduce((sum, win) => sum + win.early, 0) * 1000000 / rate.us,
                  perfLast: complete.at(-1), perfLines: complete, gate, errs, warns: warns.length,
                  warn_samples: [...new Set(warns)].slice(0, 8),
                  dev: logs.find((l) => l.includes('OpenGL API')) ?? '' };
                fs.appendFileSync(out, JSON.stringify(r) + '\n');
                console.log(`${bname} ${build} ${sc.area} h${sc.hour} ${r.size}: ${r.fps.toFixed(3)} game fps; `
                  + `${r.page_fps.toFixed(2)} page fps; p95 ${r.p95_ms.toFixed(2)} ms; errors ${errs.length}; warnings ${warns.length}`);
                if (errs.length) throw new Error(`${build} logged errors: ${errs.join('\n')}`);
              } finally {
                await ctx.close();
              }
            }
          }
        }
      }
    } finally {
      await browser.close();
    }
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await main(JSON.parse(process.argv[2]));
}
