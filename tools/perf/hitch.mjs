// Raw page-frame intervals in E3's 7-12 s window, timed at the engine's first line.
// node hitch.mjs '{"browsers":["firefox"],"builds":{"before":"http://localhost:8000/"},
//   "size":[360,640,1],"reps":2,"out":"hitches.jsonl"}'
import fs from 'node:fs';
const { chromium, firefox } = await import(process.env.PLAYWRIGHT_MODULE ?? 'playwright');
const cfg = JSON.parse(process.argv[2]);
const win = cfg.window ?? [7, 12];
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
let failed = 0;
for (const name of cfg.browsers) {
  if (!['chrome', 'firefox'].includes(name)) throw new Error(`Unknown browser: ${name}`);
}
for (const name of cfg.browsers) {
  const browser = await (name === 'chrome'
    ? chromium.launch({ executablePath: process.env.CHROME ?? '/usr/bin/google-chrome', headless: false,
      args: ['--autoplay-policy=no-user-gesture-required', '--enable-unsafe-swiftshader',
        '--disable-background-timer-throttling', '--disable-renderer-backgrounding',
        '--disable-backgrounding-occluded-windows'] })
    : firefox.launch({ headless: false, firefoxUserPrefs: { 'media.autoplay.default': 0 } }));
  try {
    for (let rep = 0; rep < (cfg.reps ?? 2); rep++) {
      for (const [build, base] of Object.entries(cfg.builds)) {
        const [w, h, dpr = 1] = cfg.size ?? [360, 640, 1];
        const ctx = await browser.newContext({ viewport: { width: w, height: h }, deviceScaleFactor: dpr });
        try {
          const page = await ctx.newPage(), logs = [];
          await page.addInitScript(INIT);
          page.on('console', (m) => logs.push(`[${m.type()}] ${m.text()}`));
          page.on('pageerror', (error) => logs.push(`[pageerror] ${error.message}`));
          const args = ['--autopilot', '--fps', `--seed=${cfg.seed ?? 1}`,
            `--area=${cfg.area ?? 'city'}`, `--hour=${cfg.hour ?? 7}`];
          await page.goto(base + '?' + args.map((a) => 'arg=' + encodeURIComponent(a)).join('&'));
          await page.waitForFunction(() => window.__engineStart !== null, null, { timeout: 60000 });
          await page.waitForFunction((end) => performance.now() >= window.__engineStart + end * 1000,
            Math.max(cfg.secs ?? 12, win[1]) + 0.1, { timeout: 60000 });
          const { frames, start } = await page.evaluate(() => ({
            frames: window.__frames, start: window.__engineStart,
          }));
          const intervals = frames.slice(1).map((t, i) => [frames[i] - start, t - frames[i]]);
          const selected = intervals.filter(([t, ms]) => t >= win[0] * 1000 && t + ms <= win[1] * 1000);
          if (!selected.length) throw new Error(`${build}: no frames in E3's window`);
          const errs = logs.filter((line) => /^\[(error|pageerror)\]/.test(line) || /ERROR/.test(line));
          const r = { browser: name, build, rep, size: `${w}x${h}@${dpr}`, window: win,
            frames: selected.length, win_max_ms: Math.max(...selected.map(([, ms]) => ms)),
            win_over_25: selected.filter(([, ms]) => ms > 25), errs };
          fs.appendFileSync(cfg.out ?? '/tmp/perf-hitch.jsonl', JSON.stringify(r) + '\n');
          console.log(JSON.stringify(r));
          if (errs.length) failed++;
        } finally {
          await ctx.close();
        }
      }
    }
  } finally {
    await browser.close();
  }
}
if (failed) throw new Error(`${failed} hitch run(s) logged errors`);
