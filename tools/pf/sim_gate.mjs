// PF prototype: the Web's frame gate against a simulated browser (P17). Usage: node sim_gate.mjs
// B is the probe's GATE_JS (autoload/pf_probe.gd), which PERF_PLAN.md §5.4 proposes; B0 is the same before the plan's
// second review, at a08cbe9, read with git; A is the first gate, at c5bfd9f; limiter is Godot's own on the Web
// (max_fps; platform/web/web_main.cpp :80-103 in 4.7.2).
// The browser runs the callbacks pending at each vsync once the main thread is free, with the vsync's time, plus
// jitter if asked; the game's callback keeps the main thread busy for its work, and asks for the next frame, as
// Emscripten's runner does.
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

const here = path.dirname(new URL(import.meta.url).pathname);
const probe = fs.readFileSync(path.join(here, '../../autoload/pf_probe.gd'), 'utf8');
const gateOf = (gd) => /const GATE_JS := """([\s\S]*?)"""/.exec(gd)[1];
export const GATE_B = gateOf(probe);
export const GATE_B0 = gateOf(execFileSync('git', ['show', 'a08cbe9:autoload/pf_probe.gd'], { cwd: here, encoding: 'utf8' }));
export const GATE_A = `
(function (cap) {
	if (window.__pfGate) { window.__pfGate.cap = cap; return; }
	const g = { cap: cap, last: new WeakMap(), deltas: [], prev: -1, refresh: 0, skipped: 0 };
	window.__pfGate = g;
	const raf = window.requestAnimationFrame.bind(window);
	window.requestAnimationFrame = function (cb) {
		const step = function (t) {
			if (t > g.prev) {
				if (g.prev >= 0 && t - g.prev >= 4) {
					g.deltas.push(t - g.prev);
					if (g.deltas.length > 120) g.deltas.shift();
					g.refresh = Math.min.apply(null, g.deltas);
				}
				g.prev = t;
			}
			const last = g.last.get(cb);
			if (g.cap > 0 && g.refresh > 0 && g.deltas.length >= 8 && last !== undefined) {
				const n = Math.max(1, Math.floor(1.02 * 1000 / g.refresh / g.cap));
				if (t - last < (n - 0.5) * g.refresh) { g.skipped++; raf(step); return; }
			}
			g.last.set(cb, t);
			cb(t);
		};
		return raf(step);
	};
})(%d);
`;

// A seeded generator, so that each run is the same.
function rng(seed) {
  let s = seed >>> 0;
  return () => { s = (s + 0x6d2b79f5) >>> 0; let t = s; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
}

// sc: {hz: number | (t) => hz, secs, work: (r, clock ms) => ms, jitter (ms), clamp (timestamps floored to whole ms, as
//      Firefox's are), late (callbacks begin up to this many ms after their vsync, whose time they still get),
//      gaps: [[from, to]], page (a second chain), cancelAt (s)}. gate: 'none', 'limiter', 'A', 'B', 'B0' or
//      a gate's JS. Returns the game's run times, in ms: their rAF timestamps, and the clock as each began.
export function simulate(sc, gate, cap = 60, seed = 1) {
  const r = rng(seed);
  const gauss = () => Math.sqrt(-2 * Math.log(r() + 1e-12)) * Math.cos(2 * Math.PI * r());
  const pending = new Map();
  let nextId = 1;
  const win = {
    requestAnimationFrame: (cb) => { const id = nextId++; pending.set(id, cb); return id; },
    cancelAnimationFrame: (id) => { pending.delete(id); },
  };
  const hz = typeof sc.hz === 'function' ? sc.hz : () => sc.hz;
  const runs = [], pageRuns = [], clocks = [];
  let busy = 0, handle = null, target = 0;
  const runner = (t) => {
    // Godot's limiter reads the clock in the callback: it skips the frame until its target, which then moves on by
    // a whole 1/cap s, or to now once it lags by over a second.
    if (gate === 'limiter') {
      if (busy < target) { handle = win.requestAnimationFrame(runner); return; }
      if (busy - target > 1000) target = busy;
      target += Math.floor(1e6 / cap) / 1000;
    }
    runs.push(t); clocks.push(busy); busy += sc.work(r, busy); handle = win.requestAnimationFrame(runner);
  };
  const pageTick = (t) => { pageRuns.push(t); win.requestAnimationFrame(pageTick); };
  // The engine's first frame installs the gate, and its scheduler then asks for the next frame.
  const first = () => {
    const code = { A: GATE_A, B: GATE_B, B0: GATE_B0 }[gate] ?? gate;
    if (gate !== 'none' && gate !== 'limiter') new Function('window', 'performance', code.replace('%d', String(cap)))(win, { now: () => busy });
    handle = win.requestAnimationFrame(runner);
  };
  if (sc.page) win.requestAnimationFrame(pageTick);
  first();
  let v = 0, cancelled = false;
  const end = sc.secs * 1000;
  while (v < end) {
    v += 1000 / hz(v / 1000);
    if ((sc.gaps ?? []).some(([a, b]) => v >= a * 1000 && v < b * 1000)) continue;
    if (v < busy) continue;
    if (sc.cancelAt !== undefined && !cancelled && v >= sc.cancelAt * 1000) { win.cancelAnimationFrame(handle); cancelled = true; }
    const raw = v + (sc.jitter ? sc.jitter * gauss() : 0);
    const t = sc.clamp ? Math.floor(raw) : raw;
    busy = v + (sc.late ? sc.late * r() : 0);
    const due = [...pending.entries()];
    pending.clear();
    for (const [, cb] of due) { busy += 0.02; cb(t); }
  }
  return { runs, pageRuns, clocks, gate: win.__pfGate };
}

export function rate(runs, from, to) {
  const inside = runs.filter((t) => t >= from * 1000 && t < to * 1000);
  return inside.length < 2 ? 0 : (inside.length - 1) * 1000 / (inside[inside.length - 1] - inside[0]);
}

// Frames a second whose interval isn't the median's, over a window: the pacing's misses.
export function offCadence(runs, from, to) {
  const iv = [];
  for (let i = 1; i < runs.length; i++) if (runs[i - 1] >= from * 1000 && runs[i] < to * 1000) iv.push(runs[i] - runs[i - 1]);
  const s = [...iv].sort((a, b) => a - b), med = s[s.length >> 1];
  return iv.filter((d) => Math.abs(d - med) > 2).length / (to - from);
}

// The game's 60 Hz steps that its frames show a second: a frame shows a new one if one fell due on the engine's clock
// since the frame before, as the game moves only in its physics steps. The steps fall 5.3 ms off the vsyncs of 60, 120
// and 240 Hz, as Godot's jitter fix keeps them clear of the frames.
export function shown(clocks, from, to) {
  const step = (t) => Math.floor((t - 5.3) / (1000 / 60));
  let n = 0;
  for (let i = 1; i < clocks.length; i++) if (clocks[i - 1] >= from * 1000 && clocks[i] < to * 1000 && step(clocks[i]) !== step(clocks[i - 1])) n++;
  return n / (to - from);
}

const uniform = (a, b) => (r) => a + (b - a) * r();
const normal = (m, sd) => (r) => Math.max(0.1, m + sd * Math.sqrt(-2 * Math.log(r() + 1e-12)) * Math.cos(2 * Math.PI * r()));
const mix = (parts) => (r) => { let u = r(); for (const [p, f] of parts) { if (u < p) return f(r); u -= p; } return parts[parts.length - 1][1](r); };

if (import.meta.url === `file://${process.argv[1]}`) {
  const light = normal(3, 0.5);
  const rows = [];
  const row = (name, sc, from, to, extra = {}) => {
    const out = { name };
    for (const gate of ['none', 'limiter', 'A', 'B0', 'B']) {
      const { runs, pageRuns, clocks } = simulate(sc, gate);
      out[gate] = +rate(runs, from, to).toFixed(1);
      out[gate + '_off'] = +offCadence(runs, from, to).toFixed(1);
      out[gate + '_shown'] = +shown(clocks, from, to).toFixed(1);
      if (sc.page) out[gate + '_page'] = +rate(pageRuns, from, to).toFixed(1);
      if (sc.cancelAt !== undefined) out[gate + '_after_cancel'] = runs.filter((t) => t > sc.cancelAt * 1000 + 50).length;
    }
    rows.push({ ...out, secs: to - from, ...extra });
  };
  for (const hz of [60, 75, 90, 120, 144, 165, 240]) {
    row(`light ${hz} Hz`, { hz, secs: 20, work: light }, 5, 20);
    row(`light ${hz} Hz, jitter 0.3 ms`, { hz, secs: 20, work: light, jitter: 0.3 }, 5, 20);
    row(`light ${hz} Hz, whole ms, jitter 0.5 ms`, { hz, secs: 20, work: light, jitter: 0.5, clamp: true }, 5, 20);
  }
  row('120 Hz, work 6-14 ms', { hz: 120, secs: 20, work: uniform(6, 14) }, 5, 20);
  row('120 Hz, work 6-14 ms, jitter 0.3 ms', { hz: 120, secs: 20, work: uniform(6, 14), jitter: 0.3 }, 5, 20);
  row('165 Hz, work 4-9 ms, jitter 0.5 ms', { hz: 165, secs: 20, work: uniform(4, 9), jitter: 0.5 }, 5, 20);
  row('120 Hz, work 7.5-15 ms', { hz: 120, secs: 20, work: uniform(7.5, 15) }, 5, 20);
  row('120 Hz, work 10 ms, sd 2', { hz: 120, secs: 20, work: normal(10, 2) }, 5, 20);
  row('144 Hz, work 6-13 ms', { hz: 144, secs: 20, work: uniform(6, 13) }, 5, 20);
  row('120 Hz, work 10-20 ms', { hz: 120, secs: 20, work: uniform(10, 20) }, 5, 20);
  row('120 Hz, work 14-30 ms', { hz: 120, secs: 20, work: uniform(14, 30) }, 5, 20);
  row('120 Hz, work 4-20 ms', { hz: 120, secs: 20, work: uniform(4, 20) }, 5, 20);
  row('120 Hz, 40% 3-7 ms, 30% 10-15, 30% 17-24', { hz: 120, secs: 20, work: mix([[0.4, uniform(3, 7)], [0.3, uniform(10, 15)], [0.3, uniform(17, 24)]]) }, 5, 20);
  row('144 Hz, work 4-20 ms', { hz: 144, secs: 20, work: uniform(4, 20) }, 5, 20);
  row('60 Hz, work 10-30 ms', { hz: 60, secs: 20, work: uniform(10, 30) }, 5, 20);
  // The City by day at 120 Hz: about 9 ms a frame, with runs of 1-3 frames of 18-30 ms, 1 or 2 in a 100.
  for (const p of [0.01, 0.02]) {
    let burst = 0;
    const city = (r) => {
      if (burst > 0) { burst--; return uniform(18, 30)(r); }
      if (r() < p) { burst = Math.floor(r() * 3); return uniform(18, 30)(r); }
      return normal(9, 1.5)(r);
    };
    row(`120 Hz, City-like, ${p * 100}% bursts`, { hz: 120, secs: 20, work: city }, 5, 20);
  }
  row('120 Hz, callbacks up to 2 ms late', { hz: 120, secs: 20, work: light, late: 2 }, 5, 20);
  row('119.88 Hz, callbacks up to 2 ms late', { hz: 119.88, secs: 20, work: light, late: 2 }, 5, 20);
  row('light, hitch of 40 ms each 2 s', { hz: 120, secs: 20, work: mix([[1 / 240, () => 40], [1, light]]) }, 5, 20);
  const sw = { hz: (s) => (s < 10 ? 120 : 90), secs: 20, work: light };
  row('120 to 90 Hz at 10 s: 10-10.5 s', sw, 10, 10.5);
  row('120 to 90 Hz at 10 s: 10.5-12 s', sw, 10.5, 12);
  row('120 to 90 Hz at 10 s: 12-20 s', sw, 12, 20);
  row('90 to 120 Hz at 10 s: 10-10.5 s', { ...sw, hz: (s) => (s < 10 ? 90 : 120) }, 10, 10.5);
  row('90 to 120 Hz at 10 s: 10.5-12 s', { ...sw, hz: (s) => (s < 10 ? 90 : 120) }, 10.5, 12);
  row('90 to 120 Hz at 10 s: 12-20 s', { ...sw, hz: (s) => (s < 10 ? 90 : 120) }, 12, 20);
  row('120 Hz, hidden 10-15 s: 15-15.5 s', { hz: 120, secs: 20, work: light, gaps: [[10, 15]] }, 15, 15.5);
  row('120 Hz, a page chain beside the game', { hz: 120, secs: 20, work: light, page: true }, 5, 20);
  row('120 Hz, the game cancels at 10 s', { hz: 120, secs: 20, work: light, cancelAt: 10 }, 5, 10);
  // The second review (PERF_PLAN.md §4.4): frames that each take 2 or more refreshes from the start, or after a slow
  // phase, which B0 took for the screen's; and rates near a boundary of n, where B0's n flipped with the jitter.
  row('240 Hz, work 9 ms', { hz: 240, secs: 20, work: () => 9 }, 5, 20);
  row('240 Hz, work 9 ms, sd 0.3', { hz: 240, secs: 20, work: normal(9, 0.3) }, 5, 20);
  row('360 Hz, work 7 ms', { hz: 360, secs: 20, work: () => 7 }, 5, 20);
  row('240 Hz, work 20 ms to 5 s, then 9 ms: 7-20 s', { hz: 240, secs: 20, work: (r, c) => (c < 5000 ? 20 : 9) }, 7, 20);
  for (const hz of [115, 170, 230]) row(`${hz} Hz, jitter 0.3 ms`, { hz, secs: 20, work: light, jitter: 0.3 }, 5, 20);
  console.log(JSON.stringify(rows, null, 0).replace(/\},\{/g, '},\n{'));
  // PERF_PLAN.md §5.4's criteria for gate B (P17). At each rate of its table, exact or with 0.3 ms of jitter, and in
  // the second review's rows, B draws the screen's rate over n = max(1, floor(1.05 * hz / 60)) within 1 fps, with at
  // most 0.1 frames a second off the cadence; with whole-ms timestamps, at most 0.5. Over each window of 5 s or more,
  // it shows as many of the game's steps a second as no gate does, or one a frame if it draws fewer, less 0.5 at most.
  const paced = rows.filter((r) => /^(light [\d.]+ Hz(, jitter 0\.3 ms|, whole ms, jitter 0\.5 ms)?|(240|360) Hz, work .*|(115|170|230) Hz, jitter 0\.3 ms)$/.test(r.name));
  const bad = [];
  for (const r of paced) {
    const hz = parseFloat(/([\d.]+) Hz/.exec(r.name)[1]);
    const fps = hz / Math.max(1, Math.floor((1.05 * hz) / 60));
    if (Math.abs(r.B - fps) > 1 || r.B_off > (r.name.includes('whole ms') ? 0.5 : 0.1)) bad.push(`${r.name}: ${r.B} fps against ${fps}, ${r.B_off} frames a second off the cadence`);
  }
  for (const r of rows) {
    const steps = Math.min(r.none_shown, r.B);
    if (r.secs >= 5 && r.B_shown < steps - 0.5) bad.push(`${r.name}: shows ${r.B_shown} steps a second against ${steps}`);
  }
  for (const b of bad) console.error(`gate B: ${b}`);
  process.exitCode = paced.length === 28 && bad.length === 0 ? 0 : 1;
}
