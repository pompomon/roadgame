import assert from 'node:assert/strict';
import { test } from 'node:test';
import { capturePage as captureMeasure, gameRate } from './measure.mjs';
import { eventRate, perfWindow } from './events.mjs';
import { capturePage as captureHitch, frameIntervals } from './hitch.mjs';
import { close, isError, within } from './browser.mjs';

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

test('hitches that cross either window boundary retain their entire frame interval', () => {
  assert.deepEqual(frameIntervals([11990, 12060], 0, 7, 12), [[11990, 70]]);
  assert.deepEqual(frameIntervals([6990, 7050], 0, 7, 12), [[6990, 60]]);
  assert.deepEqual(frameIntervals([12000, 12060], 0, 7, 12), []);
  assert.deepEqual(frameIntervals([6940, 7000], 0, 7, 12), []);
});

test('WebGL error warnings fail while known software-rendering notes remain diagnostic', () => {
  for (const line of ['[warning] WebGL: INVALID_OPERATION: drawElements',
    '[warning] WebGL warning: INVALID_ENUM', '[warning] GL_INVALID_FRAMEBUFFER_OPERATION',
    '[error] failure', '[log] ERROR: failed invariant']) assert.ok(isError(line), line);
  for (const line of ['[warning] GPU stall due to ReadPixels',
    '[warning] CONTEXT_LOST_WEBGL', '[warning] WebAssembly try instruction is deprecated']) {
    assert.equal(isError(line), false, line);
  }
});

function fakePage(evaluate) {
  const listeners = new Map();
  return {
    on: (name, callback) => listeners.set(name, callback),
    addInitScript: async () => {}, goto: async () => {}, waitForFunction: async () => {},
    waitForTimeout: async () => {}, evaluate,
    warn: (text) => listeners.get('console')({ type: () => 'warning', text: () => text }),
  };
}

test('measurement and hitch snapshots have deadlines when the page stops answering', { timeout: 1000 }, async () => {
  let calls = 0;
  const measured = fakePage(() => ++calls === 1 ? Promise.resolve() : new Promise(() => {}));
  await assert.rejects(captureMeasure(measured, 'http://example.invalid/', 0, 0, 5), /PERF snapshot: no answer/);
  const hitched = fakePage(() => new Promise(() => {}));
  await assert.rejects(captureHitch(hitched, 'http://example.invalid/', 12, 5), /hitch snapshot: no answer/);
  await assert.rejects(within(new Promise(() => {}), 5, 'operation'), /operation: no answer/);
});

test('measurement and hitch captures reject WebGL warnings from the actual log path', async () => {
  let measured;
  measured = fakePage(async () => {
    measured.warn('WebGL: INVALID_OPERATION');
    return { frames: [0, 16], lines: [] };
  });
  await assert.rejects(captureMeasure(measured, 'http://example.invalid/', 0, 0, 5), /INVALID_OPERATION/);
  let hitched;
  hitched = fakePage(async () => {
    hitched.warn('WebGL warning: INVALID_ENUM');
    return { frames: [0, 16], start: 0 };
  });
  await assert.rejects(captureHitch(hitched, 'http://example.invalid/', 12, 5), /INVALID_ENUM/);
});

test('a stuck browser close is killed and kill failures are not hidden', { timeout: 1000 }, async () => {
  let killed = 0;
  const holder = { server: { close: () => new Promise(() => {}),
    kill: async () => { killed++; } } };
  await close(holder, 'test browser', 5);
  assert.equal(killed, 1);
  await close(holder, 'test browser', 5);
  assert.equal(killed, 1);
  await assert.rejects(close({ server: { close: async () => { throw new Error('close failed'); },
    kill: async () => { throw new Error('kill failed'); } } }, 'test browser', 5), /kill failed/);
});
