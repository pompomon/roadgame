import assert from 'node:assert/strict';
import { test } from 'node:test';
import { gameRate } from './measure.mjs';
import { eventRate, perfWindow } from './events.mjs';

test('game rates use frame counts and actual microseconds, not rounded fps', () => {
  const rate = gameRate(['PERF fps=49.9 n=50 us=1000200 med=20.0 p95=21 max=20.0 early=0 draws=29']);
  assert.ok(Math.abs(rate.fps - 49.99000199960008) < 1e-10);
  const combined = gameRate(['PERF fps=49.9 n=50 us=1000200', 'PERF fps=59.9 n=60 us=1001669']);
  assert.equal(combined.fps, 110 * 1000000 / 2001869);
  assert.throws(() => gameRate([]), /No complete PERF/);
  assert.throws(() => gameRate(['PERF fps=50.0']), /frame count or duration/);
});

test('a way in excludes a long PERF window that started before its boundary', () => {
  const lines = [{ at: 1005, us: 1010000, n: 50 }, { at: 2006, us: 1001000, n: 60 }];
  assert.deepEqual(perfWindow(lines, 0, 8000), [lines[1]]);
  assert.equal(gameRate(perfWindow(lines, 0, 8000)).fps, 60 * 1000000 / 1001000);
});

test('end rates count engine frames between ordered events', () => {
  assert.equal(eventRate({ at: 1000, frames: 20 }, { at: 2100, frames: 75 }).fps, 50);
  assert.throws(() => eventRate({ at: 2100, frames: 75 }, { at: 1000, frames: 20 }), /forward/);
});
