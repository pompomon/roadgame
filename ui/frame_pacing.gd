class_name FramePacing
extends RefCounted
## The native limiter and Web refresh gate (docs/PERF.md §5.4).

const ENGINE_LIMIT := 2147483647
const GATE_JS := """
(function (cap, steps, calibration, percentile, gap, range, margin, hysteresis,
	shortRatio, shortMs) {
	if (window.__framePacing) { window.__framePacing.cap = cap; return; }
	if (!(cap > 0)) return;
	const g = { cap: cap, runner: null, last: -1, prev: -1, steps: [], idle: [], idled: false,
		refresh: 0, n: 0, skipped: 0, native: new Map(), next: -1 };
	window.__framePacing = g;
	const raf = window.requestAnimationFrame.bind(window);
	const caf = window.cancelAnimationFrame.bind(window);
	const sorted = function (a) { return a.slice().sort(function (x, y) { return x - y; }); };
	const refresh = function () {
		const s = sorted(g.steps);
		const q = s[Math.floor(s.length * percentile)];
		const short = s.filter(function (d) { return d < Math.max(shortRatio * q, q + shortMs); });
		let r = short[short.length >> 1];
		if (g.idle.length === calibration && sorted(g.idle)[calibration >> 1] < r / shortRatio)
			r = sorted(g.idle)[calibration >> 1];
		let from = 0, span = 0, best = r, most = -1;
		g.steps.forEach(function (d, i) { if (d > gap) from = i + 1; });
		if (g.steps.length - from < calibration) return r;
		for (let i = from; i < g.steps.length; i++) span += g.steps[i];
		for (let k = Math.ceil(span / r / (1 + range)); k <= Math.floor(span / r / (1 - range)); k++) {
			const w = 2 * Math.PI * k / span;
			let c = 1, sn = 0, t = 0;
			for (let i = from; i < g.steps.length; i++) {
				t += g.steps[i];
				c += Math.cos(w * t);
				sn += Math.sin(w * t);
			}
			if (c * c + sn * sn > most) { most = c * c + sn * sn; best = span / k; }
		}
		return best;
	};
	const fit = function (m) { return Math.max(1, Math.floor(m * 1000 / g.refresh / g.cap)); };
	window.requestAnimationFrame = function (cb) {
		if (g.runner === null) g.runner = cb;
		if (cb !== g.runner) return raf(cb);
		const handle = g.next--;
		const step = function (t) {
			if (t > g.prev) {
				if (g.prev >= 0) {
					g.steps.push(t - g.prev);
					if (g.steps.length > steps) g.steps.shift();
					if (g.idled) g.idle.push(t - g.prev);
					if (g.idle.length > calibration) g.idle.shift();
					g.refresh = refresh();
				}
				g.prev = t;
			}
			let skip = g.cap > 0 && g.idle.length < calibration && g.skipped < 2 * calibration;
			if (!skip && g.cap > 0 && g.steps.length >= steps) {
				if (g.n === 0) g.n = fit(margin);
				g.n = Math.min(Math.max(g.n, fit(margin / hysteresis)), fit(margin * hysteresis));
				skip = g.n > 1 && g.last >= 0 && t - g.last < (g.n - 0.5) * g.refresh;
			}
			g.idled = skip;
			if (skip) {
				g.skipped++;
				g.native.set(handle, raf(step));
				return;
			}
			g.native.delete(handle);
			g.last = t;
			cb(t);
		};
		g.native.set(handle, raf(step));
		return handle;
	};
	window.cancelAnimationFrame = function (id) {
		if (g.native.has(id)) { caf(g.native.get(id)); g.native.delete(id); return; }
		caf(id);
	};
})(%d, %d, %d, %f, %f, %f, %f, %f, %f, %f);
"""


static func cap(web: bool, android: bool, switch: String) -> int:
	if switch.is_valid_int():
		var wanted := switch.to_int()
		if wanted >= 0 and wanted <= ENGINE_LIMIT:
			return wanted
	if not switch.is_empty():
		push_error("FramePacing: fpscap must be a representable nonnegative integer")
	return Tuning.MAX_FPS if web or android else 0


static func apply(limit: int) -> void:
	if limit < 0 or limit > ENGINE_LIMIT:
		push_error("FramePacing: invalid frame cap")
		limit = 0
	if OS.has_feature("web"):
		Engine.max_fps = 0
		JavaScriptBridge.eval(gate_js(limit), true)
	else:
		Engine.max_fps = limit


static func gate_js(limit: int) -> String:
	return (
		GATE_JS
		% [
			limit,
			Tuning.GATE_STEPS,
			Tuning.GATE_CALIBRATION,
			Tuning.GATE_PERCENTILE,
			Tuning.GATE_GAP_MS,
			Tuning.GATE_RANGE,
			Tuning.GATE_MARGIN,
			Tuning.GATE_HYSTERESIS,
			Tuning.GATE_SHORT_RATIO,
			Tuning.GATE_SHORT_MS,
		]
	)
