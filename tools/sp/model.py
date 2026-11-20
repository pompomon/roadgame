#!/usr/bin/env python3
"""P2 (SPEEDUP_PLAN.md §6.5): a model of a run. Roads drawn as RoadGenerator draws them (the turns, the
decoys, each straight from its area's range, the set pieces, the start's 4 tiles and the finish),
and the car's speed moved toward CarSim.target_speed() at 60 Hz along each segment, as
_update_speed() does, braking hard to enter each junction's tile at junction_speed. No corners,
no dead ends, no set pieces' shapes."""
import math
import random

DT = 1.0 / 60.0
ACCEL = 2.0
BRAKE = 4.0
BASE = 4.0
GCAP = 7.0
STEER_RATE = 3.0


def corner(a):
    """The path that a turn saves: the car turns on a radius of junction_speed / STEER_RATE, so it
    drives a quarter circle where the tiles' centrelines meet at a right angle."""
    r = a["js"] / STEER_RATE
    return r * (2.0 - math.pi / 2.0)

SP_AREAS = {
    "city": dict(mn=2, mx=5, decoy=0.0, accel=0.5, bd=1.25, js=2.0),
    "rural": dict(mn=3, mx=7, decoy=0.1, accel=0.6, bd=1.25, js=2.2),
    "meadows": dict(mn=6, mx=12, decoy=0.15, accel=0.6, bd=1.25, js=2.2),
    "village": dict(mn=4, mx=8, decoy=0.15, accel=0.55, bd=1.25, js=2.0),
    "desert": dict(mn=6, mx=12, decoy=0.15, accel=0.7, bd=1.5, js=2.4),
    "coast": dict(mn=20, mx=20, decoy=0.0, accel=0.7, bd=1.5, js=2.4),
}


def areas_with(**changes):
    areas = {k: dict(v) for k, v in SP_AREAS.items()}
    for name, fields in changes.items():
        areas[name].update(fields)
    return areas


MAIN_AREAS = areas_with(
    meadows=dict(mn=3, mx=7), village=dict(mn=2, mx=5), desert=dict(mn=3, mx=8, decoy=0.2)
)
# (turn, area, set piece tiles); the finish's turn.
PIER = ([(0, "city", 0), (20, "rural", 6), (44, "meadows", 5), (68, "village", 0), (78, "desert", 0), (100, "coast", 0)], 100)
HOME = ([(0, "desert", 0), (22, "village", 0), (32, "meadows", 0), (56, "rural", 5), (80, "city", 6)], 100)
MAIN_PIER = ([(0, "city", 0), (34, "rural", 6), (100, "meadows", 5), (200, "village", 0), (220, "desert", 0), (280, "coast", 0)], 280)
MAIN_HOME = ([(0, "desert", 0), (60, "village", 0), (80, "meadows", 0), (180, "rural", 5), (246, "city", 6)], 280)
START_TILES = 4

_memo = {}


def seg(areas, parts, v0, d0, growth, finish, turn=False):
    """Time and final speed over a segment: from a junction tile's exit (or the start) along
    `parts`, [(tiles, area)], to the next junction tile's exit, or to the finish's first tile."""
    key = (parts, round(v0, 2), int(d0), growth, finish, turn, id(areas))
    hit = _memo.get(key)
    if hit is not None:
        return hit
    total = sum(p[0] for p in parts)
    end = total if finish else total + 0.5 - (corner(areas[parts[-1][1]]) if turn else 0.0)
    x = 0.0
    v = v0
    t = 0.0
    d = float(int(d0))
    i = 0
    edge = parts[0][0]
    a = areas[parts[0][1]]
    while x < end:
        while x >= edge and i + 1 < len(parts):
            i += 1
            edge += parts[i][0]
            a = areas[parts[i][1]]
        cap = min(GCAP, BASE + (d + x) * growth)
        target = min(cap, a["js"] + a["accel"] * x)
        to_turn = math.inf if finish else total - x
        braking = to_turn <= a["bd"]
        if braking:
            target = a["js"]
        rate = ACCEL if target > v else BRAKE
        if braking and v > target:
            room = to_turn - 0.5
            if room > 0.0:
                rate = max(rate, (v * v - target * target) / (2.0 * room))
            else:
                rate = math.inf
        if v < target:
            v = min(target, v + rate * DT)
        elif v > target:
            v = target if rate == math.inf else max(target, v - rate * DT)
        x += v * DT
        t += DT
    out = (t, v)
    _memo[key] = out
    return out


def run(rng, areas, road, growth, zones=None):
    sched, finish_turn = road
    area = sched[0][1]
    idx = 1
    turns = 0
    decoy = rng.random() < areas[area]["decoy"]
    t, v = seg(areas, ((START_TILES, area),), 0.0, 0.0, growth, False, not decoy)
    d = START_TILES + 0.5
    zone_t = {area: t} if zones is not None else None
    while True:
        a = areas[area]
        if decoy:
            parts = ((rng.randint(a["mn"], a["mx"]) + 0.5, area),)
        else:
            turns += 1
            if idx < len(sched) and sched[idx][0] <= turns:
                _, new, sp = sched[idx]
                idx += 1
                n = areas[new]
                tail = rng.randint(n["mn"], n["mx"]) + 0.5
                parts = ((sp, area), (tail, new)) if sp else ((tail, new),)
                area = new
            else:
                parts = ((rng.randint(a["mn"], a["mx"]) + 0.5, area),)
            if idx >= len(sched) and turns >= finish_turn:
                last = parts[-1]
                parts = parts[:-1] + ((last[0] - 0.5, last[1]),)
                dt, v = seg(areas, parts, v, d, growth, True)
                t += dt
                if zone_t is not None:
                    zone_t[area] = zone_t.get(area, 0.0) + dt
                    zones.append(zone_t)
                return t
        decoy = rng.random() < areas[area]["decoy"]
        dt, v = seg(areas, parts, v, d, growth, False, not decoy)
        t += dt
        d += sum(p[0] for p in parts) + 0.5
        if zone_t is not None:
            zone_t[area] = zone_t.get(area, 0.0) + dt


def pct(xs, p):
    xs = sorted(xs)
    k = (len(xs) - 1) * p
    f = int(k)
    c = min(f + 1, len(xs) - 1)
    return xs[f] + (xs[c] - xs[f]) * (k - f)


def summary(times):
    n = len(times)
    mean = sum(times) / n
    return (
        f"n {n} mean {mean:.2f} p95 {pct(times, .95):.1f} p99 {pct(times, .99):.1f}"
        f" p99.9 {pct(times, .999):.1f} max {max(times):.1f}"
        f" >270 {sum(x > 270 for x in times)} >280 {sum(x > 280 for x in times)}"
        f" >290 {sum(x > 290 for x in times)} >300 {sum(x > 300 for x in times)}"
    )


if __name__ == "__main__":
    import sys

    n = int(sys.argv[1]) if len(sys.argv) > 1 else 2000
    rng = random.Random(1)
    for label, areas, pier, home, growth in (
        ("main", MAIN_AREAS, MAIN_PIER, MAIN_HOME, 0.002),
        (
            "owner's turns, main's straights",
            areas_with(meadows=dict(mn=3, mx=7), village=dict(mn=2, mx=5), desert=dict(mn=3, mx=8)),
            PIER,
            HOME,
            0.0035,
        ),
        ("SP default", SP_AREAS, PIER, HOME, 0.0035),
        ("SP default at 0.002", SP_AREAS, PIER, HOME, 0.002),
        (
            "twice main's straights",
            areas_with(meadows=dict(mn=6, mx=14), village=dict(mn=4, mx=10), desert=dict(mn=6, mx=16)),
            PIER,
            HOME,
            0.0035,
        ),
    ):
        for road_label, road in (("pier", pier), ("home", home)):
            times = [run(rng, areas, road, growth) for _ in range(n)]
            print(f"{label:35s} {road_label}: {summary(times)}")
