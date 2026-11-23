// Run the shipping gate against a seeded browser/60 Hz physics simulation (PERF_PLAN.md §5.4).
import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

const script = fs.readFileSync(new URL('../../ui/frame_pacing.gd', import.meta.url), 'utf8');
const tuning = fs.readFileSync(new URL('../../config/tuning.gd', import.meta.url), 'utf8');
const template = /const GATE_JS := """([\s\S]*?)"""/.exec(script)[1];
const parameters = /GATE_JS\s*%\s*\[([^\]]+)\]/.exec(script)[1].split(',').map((s) => s.trim()).filter(Boolean);
const number = (name) => {
  const value = new RegExp(`^const ${name} := ([\\d._]+)$`, 'm').exec(tuning);
  assert.ok(value, `numeric tuning constant ${name}`);
  return Number(value[1].replaceAll('_', ''));
};
const defaultCap = number('MAX_FPS');
function gateSource(cap) {
  const values = parameters.map((p) => {
    if (p === 'limit') return cap;
    assert.match(p, /^Tuning\.GATE_[A-Z_]+$/);
    return number(p.slice('Tuning.'.length));
  });
  let index = 0;
  return template.replace(/%[df]/g, (format) => {
    const value = values[index++];
    assert.ok(Number.isFinite(value), 'each gate placeholder has a value');
    return format === '%f' ? value.toFixed(6) : String(Math.trunc(value));
  });
}

function rng(seed) {
  let s = seed >>> 0;
  return () => {
    s = (s + 0x6d2b79f5) >>> 0;
    let t = s;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function browser() {
  const pending = new Map();
  let next = 1;
  const window = {
    requestAnimationFrame: (cb) => { const id = next++; pending.set(id, cb); return id; },
    cancelAnimationFrame: (id) => { pending.delete(id); },
  };
  const tick = (t) => {
    const due = [...pending.values()];
    pending.clear();
    for (const cb of due) cb(t);
  };
  return { window, pending, tick };
}

function install(window, clock, cap = defaultCap) {
  new Function('window', 'performance', gateSource(cap))(window, { now: clock });
}

function simulate(sc, gated = true, cap = defaultCap) {
  const random = rng(1);
  const gauss = () => Math.sqrt(-2 * Math.log(random() + 1e-12)) * Math.cos(2 * Math.PI * random());
  const { window, pending } = browser();
  const hz = typeof sc.hz === 'function' ? sc.hz : () => sc.hz;
  const work = sc.workFactory ? sc.workFactory() : sc.work;
  const runs = [], clocks = [], pageRuns = [], cycles = [];
  let busy = 0, handle, cycle = 0, cancelled = false, cancelSkipped, changed = false;
  const runner = (t) => {
    runs.push(t); clocks.push(busy); cycles.push(cycle);
    busy += work(random, busy);
    handle = window.requestAnimationFrame(runner);
  };
  const page = (t) => { pageRuns.push(t); window.requestAnimationFrame(page); };
  if (sc.page) window.requestAnimationFrame(page);
  if (gated) install(window, () => busy, cap);
  handle = window.requestAnimationFrame(runner);
  let vsync = 0;
  while (vsync < sc.secs * 1000) {
    vsync += 1000 / hz(vsync / 1000);
    cycle++;
    if ((sc.gaps ?? []).some(([a, b]) => vsync >= a * 1000 && vsync < b * 1000)) continue;
    if (vsync < busy) continue;
    if (gated && sc.capChange && !changed && vsync >= sc.capChange.at * 1000) {
      install(window, () => busy, sc.capChange.to);
      changed = true;
    }
    if (sc.cancelAt !== undefined && !cancelled && vsync >= sc.cancelAt * 1000) {
      cancelSkipped = window.__framePacing?.idled;
      window.cancelAnimationFrame(handle);
      cancelled = true;
    }
    const raw = vsync + (sc.jitter ? sc.jitter * gauss() : 0);
    const timestamp = sc.clamp ? Math.floor(raw) : raw;
    busy = vsync + (sc.late ? sc.late * random() : 0);
    const due = [...pending.values()];
    pending.clear();
    for (const cb of due) { busy += 0.02; cb(timestamp); }
  }
  return { runs, clocks, pageRuns, cycles, cancelSkipped };
}

function rate(runs, from, to) {
  const inside = runs.filter((t) => t >= from * 1000 && t < to * 1000);
  return inside.length < 2 ? 0 : (inside.length - 1) * 1000 / (inside.at(-1) - inside[0]);
}

function offCadence(runs, from, to) {
  const intervals = [];
  for (let i = 1; i < runs.length; i++) {
    if (runs[i - 1] >= from * 1000 && runs[i] < to * 1000) intervals.push(runs[i] - runs[i - 1]);
  }
  const sorted = [...intervals].sort((a, b) => a - b), median = sorted[sorted.length >> 1];
  return intervals.filter((d) => Math.abs(d - median) > 2).length / (to - from);
}

function shown(clocks, from, to) {
  const step = (t) => Math.floor((t - 5.3) / (1000 / 60));
  let count = 0;
  for (let i = 1; i < clocks.length; i++) {
    if (clocks[i - 1] >= from * 1000 && clocks[i] < to * 1000 &&
        step(clocks[i]) !== step(clocks[i - 1])) count++;
  }
  return count / (to - from);
}

const uniform = (a, b) => (r) => a + (b - a) * r();
const normal = (mean, sd) => (r) => Math.max(0.1,
  mean + sd * Math.sqrt(-2 * Math.log(r() + 1e-12)) * Math.cos(2 * Math.PI * r()));
const mix = (parts) => (r) => {
  let u = r();
  for (const [p, fn] of parts) { if (u < p) return fn(r); u -= p; }
  return parts.at(-1)[1](r);
};
const light = normal(3, 0.5);
const target = (hz) => hz / Math.max(1, Math.floor(1.05 * hz / 60));
function check(name, scenario, from = 5, to = 20, paced = null, extra = null) {
  test(name, () => {
    const sc = { secs: 20, work: light, ...scenario };
    const actual = simulate(sc), free = simulate(sc, false);
    const fps = rate(actual.runs, from, to);
    if (paced !== null) {
      assert.ok(Math.abs(fps - target(paced)) <= 1, `${fps} FPS against ${target(paced)}`);
      const off = offCadence(actual.runs, from, to);
      assert.ok(off <= (sc.clamp ? 0.5 : 0.1), `${off} frames/s off cadence`);
    }
    if (to - from >= 5) {
      const minimum = Math.min(shown(free.clocks, from, to), fps) - 0.5;
      const steps = shown(actual.clocks, from, to);
      assert.ok(steps >= minimum, `${steps} shown physics steps/s against ${minimum}`);
    }
    if (extra) extra(actual, fps);
  });
}

for (const hz of [60, 75, 90, 120, 144, 165, 240]) {
  check(`light ${hz} Hz`, { hz }, 5, 20, hz);
  check(`light ${hz} Hz, jitter 0.3 ms`, { hz, jitter: 0.3 }, 5, 20, hz);
  check(`light ${hz} Hz, whole ms, jitter 0.5 ms`, { hz, jitter: 0.5, clamp: true }, 5, 20, hz);
}
for (const [hz, a, b, jitter = 0] of [
  [120, 6, 14], [120, 6, 14, 0.3], [165, 4, 9, 0.5], [120, 7.5, 15], [144, 6, 13],
  [120, 10, 20], [120, 14, 30], [120, 4, 20], [144, 4, 20], [60, 10, 30],
]) check(`${hz} Hz, work ${a}-${b} ms, jitter ${jitter}`, { hz, work: uniform(a, b), jitter });
check('120 Hz, work 10 ms, sd 2', { hz: 120, work: normal(10, 2) });
check('120 Hz, mixed 3-7, 10-15, 17-24 ms work', {
  hz: 120, work: mix([[0.4, uniform(3, 7)], [0.3, uniform(10, 15)], [0.3, uniform(17, 24)]]),
});
for (const p of [0.01, 0.02]) check(`120 Hz, City-like ${p * 100}% bursts`, {
  hz: 120, workFactory: () => {
    let burst = 0;
    return (r) => {
      if (burst > 0) { burst--; return uniform(18, 30)(r); }
      if (r() < p) { burst = Math.floor(r() * 3); return uniform(18, 30)(r); }
      return normal(9, 1.5)(r);
    };
  },
});
for (const hz of [120, 119.88]) check(`${hz} Hz, callbacks up to 2 ms late`, { hz, late: 2 }, 5, 20, hz);
check('120 Hz, 40 ms hitch about every 2 s', { hz: 120, work: mix([[1 / 240, () => 40], [1, light]]) });
for (const [fromHz, toHz] of [[120, 90], [90, 120]]) {
  const sc = { hz: (s) => s < 10 ? fromHz : toHz };
  check(`${fromHz} to ${toHz} Hz, first half second`, sc, 10, 10.5, null,
    (_, fps) => assert.ok(fps >= 57, `${fps} FPS against 57`));
  check(`${fromHz} to ${toHz} Hz, following 1.5 s`, sc, 10.5, 12, toHz);
  check(`${fromHz} to ${toHz} Hz, settled`, sc, 12, 20, toHz);
}
check('120 Hz, resumes after 5 s hidden', { hz: 120, gaps: [[10, 15]] }, 15, 15.5, 120);
check('120 Hz, another page chain is not gated', { hz: 120, page: true }, 5, 20, 120,
  (out) => assert.ok(rate(out.pageRuns, 5, 20) >= 119));
for (const [hz, work, name] of [[240, () => 9, '9 ms'], [240, normal(9, 0.3), '9 ms, sd 0.3'], [360, () => 7, '7 ms']]) {
  check(`${hz} Hz, multi-refresh work ${name}`, { hz, work }, 5, 20, hz);
}
check('240 Hz, work 20 ms to 5 s, then 9 ms', {
  hz: 240, work: (_, clock) => clock < 5000 ? 20 : 9,
}, 7, 20, 240);
for (const hz of [115, 170, 230]) check(`${hz} Hz near a boundary, jitter 0.3 ms`, { hz, jitter: 0.3 }, 5, 20, hz);
for (const clamp of [false, true]) check(`540 Hz, 1 ms work, ${clamp ? 'whole' : 'exact'} timestamps`, {
  hz: 540, work: () => 1, clamp,
}, 5, 20, 540, (out) => {
  for (let i = 1; i < out.runs.length; i++) {
    if (out.runs[i - 1] >= 5000 && out.runs[i] < 20000) assert.equal(out.cycles[i] - out.cycles[i - 1], 9);
  }
});

test('cancelling after both a run and a skip cancels the pending engine request', () => {
  const statuses = new Set();
  for (const cancelAt of [10, 10 + 1 / 120]) {
    const out = simulate({ hz: 120, secs: 12, work: () => 3, cancelAt, page: true });
    statuses.add(out.cancelSkipped);
    assert.equal(out.runs.filter((t) => t >= cancelAt * 1000).length, 0);
    assert.ok(rate(out.pageRuns, 10.1, 12) >= 119);
  }
  assert.deepEqual(statuses, new Set([false, true]), 'both cancellation positions were exercised');
});

test('an initial zero cap does not wrap either browser function', () => {
  const { window } = browser();
  const raf = window.requestAnimationFrame, caf = window.cancelAnimationFrame;
  install(window, () => 0, 0);
  assert.equal(window.requestAnimationFrame, raf);
  assert.equal(window.cancelAnimationFrame, caf);
  assert.equal(window.__framePacing, undefined);
});

test('a second install updates the existing cap rather than wrapping again', () => {
  const { window } = browser();
  install(window, () => 0);
  const gate = window.__framePacing, raf = window.requestAnimationFrame, caf = window.cancelAnimationFrame;
  install(window, () => 0, 30);
  assert.equal(window.__framePacing, gate);
  assert.equal(gate.cap, 30);
  assert.equal(window.requestAnimationFrame, raf);
  assert.equal(window.cancelAnimationFrame, caf);
});

test('non-default cap 30 paces the engine at both 60 and 120 Hz', () => {
  for (const hz of [60, 120]) {
    const out = simulate({ hz, secs: 20, work: () => 3 }, true, 30);
    const fps = rate(out.runs, 5, 20);
    assert.ok(Math.abs(fps - 30) <= 1, `${hz} Hz: ${fps} FPS against 30`);
    assert.ok(shown(out.clocks, 5, 20) >= fps - 0.5);
  }
});

test('a second install retargets a running 120 Hz gate from 60 to 30 FPS', () => {
  const out = simulate({ hz: 120, secs: 20, work: () => 3, capChange: { at: 10, to: 30 } });
  assert.ok(Math.abs(rate(out.runs, 5, 10) - 60) <= 1);
  assert.ok(Math.abs(rate(out.runs, 12, 20) - 30) <= 1);
});

test('a second install of zero lifts a running 120 Hz gate', () => {
  const out = simulate({ hz: 120, secs: 20, work: () => 3, capChange: { at: 10, to: 0 } });
  assert.ok(Math.abs(rate(out.runs, 5, 10) - 60) <= 1);
  assert.ok(Math.abs(rate(out.runs, 10.1, 20) - 120) <= 1);
});

test('setting zero during bootstrap immediately stops skipping', () => {
  const { window, tick } = browser();
  install(window, () => 0);
  let count = 0;
  const runner = () => { count++; window.requestAnimationFrame(runner); };
  window.requestAnimationFrame(runner);
  install(window, () => 0, 0);
  for (let i = 1; i <= 120; i++) tick(i * 1000 / 120);
  assert.equal(count, 120);
});
