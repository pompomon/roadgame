#!/usr/bin/env python3
"""Analyse P1's CSVs: totals, per-area times and speeds, and the light (P3, P4)."""
import csv
import statistics as st
import sys
from collections import defaultdict

files = sys.argv[1:]
if not files:
    sys.exit("Usage: python3 analyze_p1.py p1_pier.csv p1_home.csv")
LONG_DAY = {"rural", "meadows", "desert"}


def pct(xs, p):
    xs = sorted(xs)
    k = (len(xs) - 1) * p
    f = int(k)
    c = min(f + 1, len(xs) - 1)
    return xs[f] + (xs[c] - xs[f]) * (k - f)


def light(hour):
    if hour >= 20 or hour < 4.5:
        return "night"
    if hour < 7:
        return "dawn"
    if hour < 17:
        return "day"
    return "dusk"


def night_secs(secs, day):
    total = 0.0
    k = 0
    while k * day < secs:
        a = k * day + 13 / 24 * day
        b = k * day + 21.5 / 24 * day
        total += max(0.0, min(secs, b) - a)
        k += 1
    return total


for path in files:
    zones = defaultdict(list)
    totals = []
    runs = defaultdict(list)
    with open(path) as f:
        for row in csv.DictReader(f, restkey="rest"):
            if row.get("end_cap") is None:
                continue
            if row["area"] == "TOTAL":
                if len(row.get("rest") or []) < 2:
                    continue
                totals.append(row)
            else:
                runs[int(row["seed"])].append(row)
    road = totals[0]["road"]
    print(f"===== {road}: {len(totals)} runs")
    secs = [float(t["secs"]) for t in totals]
    tiles = [float(t["tiles"]) for t in totals]
    arrived = sum(int(t["max_speed"]) for t in totals)
    bad = sum(int(t["end_cap"]) for t in totals)
    turns = {int(t["enter_turn"]) for t in totals}
    print(f"arrived {arrived}/{len(totals)}, bad {bad}, final turns {sorted(turns)}")
    print(
        f"time {min(secs):.2f}-{max(secs):.2f} mean {st.mean(secs):.2f} sd {st.stdev(secs):.2f}"
        f" p95 {pct(secs, .95):.2f} p99 {pct(secs, .99):.2f} p99.9 {pct(secs, .999):.2f}"
    )
    for bound in (260, 270, 280, 285, 290, 300):
        print(f"  over {bound}: {sum(s > bound for s in secs)}")
    order = sorted(totals, key=lambda t: -float(t["secs"]))
    print("  slowest:", [(int(t["seed"]), float(t["secs"])) for t in order[:8]])
    print("  fastest:", [(int(t["seed"]), float(t["secs"])) for t in order[-3:]])
    first10 = [float(t["secs"]) for t in totals if int(t["seed"]) < 10]
    print(f"  seeds 0-9: {min(first10):.2f}-{max(first10):.2f}", [round(x, 2) for x in first10])
    print(f"path tiles {min(tiles):.1f}-{max(tiles):.1f} mean {st.mean(tiles):.1f}")
    t49 = [float(t["rest"][0]) for t in totals if float(t["rest"][0]) > 0]
    t90 = [float(t["rest"][1]) for t in totals if float(t["rest"][1]) > 0]
    print(f"t at turn 49: {min(t49):.2f}-{max(t49):.2f}; turn 90: {min(t90):.2f}-{max(t90):.2f}")
    t49s1 = [float(t["rest"][0]) for t in totals if int(t["seed"]) == 1]
    t90s = [float(t["rest"][1]) for t in totals if int(t["seed"]) < 20]
    print(f"  seed 1 turn 49: {t49s1}; seeds 0-19 turn 90: {min(t90s):.2f}-{max(t90s):.2f}")
    # Per-area.
    caps_end = []
    cap7_area = defaultdict(int)
    night_share = []
    end_light = defaultdict(lambda: defaultdict(int))
    second = defaultdict(lambda: [0, 0, 0])
    shortest = {}
    night_len = defaultdict(list)
    city_hours = []
    other_hours = defaultdict(list)
    reached = defaultdict(lambda: defaultdict(int))
    done = {int(t["seed"]) for t in totals}
    for run_seed, rows in runs.items():
        if run_seed not in done:
            continue
        run_secs = sum(float(r["secs"]) for r in rows)
        run_night = 0.0
        hit7 = None
        for i, r in enumerate(rows):
            area = r["area"]
            s = float(r["secs"])
            n_turns = (
                int(rows[i + 1]["enter_turn"]) - int(r["enter_turn"]) if i + 1 < len(rows) else 0
            )
            zones[area].append((s, float(r["tiles"]), float(r["max_speed"]), n_turns, float(r["end_cap"])))
            if hit7 is None and float(r["end_cap"]) >= 6.9999:
                hit7 = area
            day = 60.0 if area in LONG_DAY else 120.0
            run_night += night_secs(s, day)
            if area in LONG_DAY:
                for d in (120.0, 90.0, 80.0, 60.0):
                    if s > 13 / 24 * d:
                        reached[area][d] += 1
                hour = (7 + 24 * s / day) % 24
                end_light[area][light(hour)] += 1
                if s > 60:
                    second[area][0] += 1
                if s > 85:
                    second[area][1] += 1
                if s > 92.5:
                    second[area][2] += 1
                if area not in shortest or s < shortest[area][0]:
                    shortest[area] = (s, run_seed)
                night_len[area].append(night_secs(s, day))
            elif area == "city":
                city_hours.append(7 + 24 * s / 120)
            else:
                other_hours[area].append(7 + 24 * s / 120)
        caps_end.append(float(rows[-1]["end_cap"]))
        cap7_area[hit7] += 1
        night_share.append(run_night / run_secs)
    print("area: n, secs min-max (mean), turns, s/turn, tiles/turn, mean speed, mean top, end cap range")
    for area, zs in zones.items():
        s = [z[0] for z in zs]
        t = [z[1] for z in zs]
        top = [z[2] for z in zs]
        nt = {z[3] for z in zs}
        cap = [z[4] for z in zs]
        tn = max(nt) if nt else 0
        per_turn = st.mean(s) / tn if tn else 0
        print(
            f"  {area:8s} {len(zs)} {min(s):.2f}-{max(s):.2f} ({st.mean(s):.2f}) turns {sorted(nt)}"
            f" {per_turn:.2f} s/turn, {st.mean(t) / tn if tn else 0:.2f} tiles/turn,"
            f" speed {st.mean(t) / st.mean(s):.2f}, top {st.mean(top):.2f},"
            f" cap {min(cap):.3f}-{max(cap):.3f}, tiles {min(t):.1f}-{max(t):.1f}"
        )
    print(f"end cap {min(caps_end):.3f}-{max(caps_end):.3f}; cap 7 first in: {dict(cap7_area)}")
    print(f"night share of a run: {st.mean(night_share) * 100:.1f}%")
    n = len(runs)
    print("P3 reached night by day length (120, 90, 80, 60):")
    allz = defaultdict(int)
    for area in ("rural", "meadows", "desert"):
        vals = [reached[area][d] for d in (120.0, 90.0, 80.0, 60.0)]
        for d in (120.0, 90.0, 80.0, 60.0):
            allz[d] += reached[area][d]
        print(f"  {area}: " + ", ".join(f"{v / n * 100:.1f}%" for v in vals))
    print("  all: " + ", ".join(f"{allz[d] / (3 * n) * 100:.1f}%" for d in (120.0, 90.0, 80.0, 60.0)))
    print("P4 end light (night, dawn, day, dusk); second morning/dusk/night; shortest; night len:")
    for area in ("rural", "meadows", "desert"):
        el = end_light[area]
        print(
            f"  {area}: "
            + ", ".join(f"{k} {el[k] / n * 100:.2f}% ({el[k]})" for k in ("night", "dawn", "day", "dusk"))
            + f"; >60 {second[area][0]}, >85 {second[area][1]}, >92.5 {second[area][2]};"
            f" shortest {shortest[area][0]:.2f} (seed {shortest[area][1]});"
            f" night {st.mean(night_len[area]):.1f} s mean, {min(night_len[area]):.2f}-{max(night_len[area]):.2f}"
        )
    print(f"  city end hours {min(city_hours):.2f}-{max(city_hours):.2f}")
    for area, hs in other_hours.items():
        print(f"  {area} end hours {min(hs):.2f}-{max(hs):.2f}")
