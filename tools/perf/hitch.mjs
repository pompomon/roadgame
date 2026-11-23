// Raw page-frame intervals overlapping E3's 7-12 s window, timed at the engine's first line.
// node hitch.mjs '{"browsers":["firefox"],"builds":{"before":"http://localhost:8000/"},
//   "size":[360,640,1],"reps":2,"out":"hitches.jsonl"}'
import fs from 'node:fs';
import { pathToFileURL } from 'node:url';
import { close, isError, launch, within } from './browser.mjs';

const INIT = `
(() => {
  window.__frames = []; window.__engineStart = null;
  function tick(t) { window.__frames.push(t); requestAnimationFrame(tick); }
  requestAnimationFrame(tick);
  const log = console.log;
  console.log = function (...args) {
    if (window.__engineStart === null && /^(OpenGL API|Godot Engine)/.test(String(args[0]))) window.__engineStart = performance.now();
    return log.apply(this, args);
  };
})();`;

export function frameIntervals(frames, start, from, to) {
  const intervals = frames.slice(1).map((t, i) => [frames[i] - start, t - frames[i]]);
  return intervals.filter(([t, ms]) => t < to * 1000 && t + ms > from * 1000);
}

export async function capturePage(page, url, end, timeoutMs = 30000) {
  const logs = [];
  page.on('console', (m) => logs.push(`[${m.type()}] ${m.text()}`));
  page.on('pageerror', (error) => logs.push(`[pageerror] ${error.message}`));
  await within(page.addInitScript(INIT), timeoutMs, 'addInitScript');
  await within(page.goto(url), 60000, 'page.goto');
  await within(page.waitForFunction(() => window.__engineStart !== null, null, { timeout: 60000 }),
    75000, 'engine start');
  await within(page.waitForFunction((end) => {
    const frames = window.__frames;
    return frames.length > 0 && frames[frames.length - 1] > window.__engineStart + end * 1000;
  }, end, { timeout: 60000 }), 75000, 'hitch closing frame');
  const data = await within(page.evaluate(() => ({
    frames: window.__frames, start: window.__engineStart,
  })), timeoutMs, 'hitch snapshot');
  const errs = logs.filter(isError);
  if (errs.length) throw new Error(`Web export logged errors: ${errs.join('\n')}`);
  return data;
}

export async function main(cfg) {
  const win = cfg.window ?? [7, 12];
  for (const name of cfg.browsers) {
    if (!['chrome', 'firefox'].includes(name)) throw new Error(`Unknown browser: ${name}`);
  }
  for (const name of cfg.browsers) {
    const holder = await launch(name, cfg);
    try {
      for (let rep = 0; rep < (cfg.reps ?? 2); rep++) {
        for (const [build, base] of Object.entries(cfg.builds)) {
          const [w, h, dpr = 1] = cfg.size ?? [360, 640, 1];
          const ctx = await within(holder.browser.newContext({
            viewport: { width: w, height: h }, deviceScaleFactor: dpr,
          }), 30000, 'newContext');
          try {
            const page = await within(ctx.newPage(), 30000, 'newPage');
            const args = ['--autopilot', '--fps', `--seed=${cfg.seed ?? 1}`,
              `--area=${cfg.area ?? 'city'}`, `--hour=${cfg.hour ?? 7}`];
            const url = base + '?' + args.map((a) => 'arg=' + encodeURIComponent(a)).join('&');
            const { frames, start } = await capturePage(page, url, Math.max(cfg.secs ?? 12, win[1]));
            const selected = frameIntervals(frames, start, win[0], win[1]);
            if (!selected.length) throw new Error(`${build}: no frames in E3's window`);
            const r = { browser: name, build, rep, size: `${w}x${h}@${dpr}`, window: win,
              frames: selected.length, win_max_ms: Math.max(...selected.map(([, ms]) => ms)),
              win_over_25: selected.filter(([, ms]) => ms > 25), errs: [] };
            fs.appendFileSync(cfg.out ?? '/tmp/perf-hitch.jsonl', JSON.stringify(r) + '\n');
            console.log(JSON.stringify(r));
          } finally {
            await within(ctx.close(), 30000, 'context.close');
          }
        }
      }
    } finally {
      await close(holder, name);
    }
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await main(JSON.parse(process.argv[2]));
}
