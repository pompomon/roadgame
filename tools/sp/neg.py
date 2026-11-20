"""Runs SP's negative cases in a worktree: one change, the suite, the failures, then a restore.

Usage: python3 neg.py <worktree> <xdg dir> <out dir> N1 N2 ...
It runs `git checkout -- .` in the worktree after each case. "As on main" is as at ec6f54d.
"""
import os
import re
import subprocess
import sys

WT, XDG, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
CASES = sys.argv[4:]
os.makedirs(OUT, exist_ok=True)


def sub(path, old, new, count=1):
    p = os.path.join(WT, path)
    with open(p) as f:
        text = f.read()
    if text.count(old) < 1:
        raise SystemExit(f"{path}: {old!r} not found")
    text = text.replace(old, new, count)
    with open(p, "w") as f:
        f.write(text)


def from_main(path):
    text = subprocess.run(["git", "show", f"ec6f54d:{path}"], cwd=WT, check=True,
                          capture_output=True, text=True).stdout
    with open(os.path.join(WT, path), "w") as f:
        f.write(text)


def n1():
    from_main("areas/schedule.tres")
    from_main("areas/schedule_home.tres")


def n2():
    sub("areas/meadows.tres", "min_straight = 6\nmax_straight = 12", "min_straight = 3\nmax_straight = 7")


def n3():
    for area in ("rural", "meadows", "desert"):
        sub(f"areas/{area}.tres", "day_seconds = 60.0\n", "")


def n4():
    sub("ui/hud.tscn", "anchor_top = 0.3\nanchor_right = 1.0\nanchor_bottom = 0.7",
        "anchor_top = 0.1\nanchor_right = 1.0\nanchor_bottom = 0.9")


def n5():
    sub("areas/village.tres", "min_straight = 4\nmax_straight = 8\n", "")


def n6():
    sub("areas/desert.tres", "min_straight = 6\nmax_straight = 12", "min_straight = 3\nmax_straight = 8")


def n7():
    sub("areas/rural.tres", "day_seconds = 60.0", "day_seconds = 55.0")


def n8():
    from_main("areas/schedule_home.tres")


def n9():
    sub("tests/sim/test_drive_to_the_end.gd", "const SLOWEST_SECONDS := 310.0",
        "const SLOWEST_SECONDS := 300.0")


def n10():
    sub("tests/sim/test_drive_to_the_end.gd", "\t_damage = 0\n",
        "\t_damage = 0\n\tsim._drive_off_road(1.0, sim.area)\n")


def n11():
    sub("areas/desert.tres", "min_straight = 6\nmax_straight = 12\nside_road_chance = 0.3\ndecoy_chance = 0.15",
        "min_straight = 6\nmax_straight = 14\nside_road_chance = 0.25\ndecoy_chance = 0.2")


def n12():
    sub("config/tuning.gd", "const TOP_SPEED_GROWTH := 0.0035", "const TOP_SPEED_GROWTH := 0.002")


SELECT = {"N7": "test_area_schedule"}


def summary(log):
    lines = [re.sub(r"\x1b\[[0-9;]*m", "", l) for l in log.splitlines()]
    start = next((k for k, l in enumerate(lines) if "Run Summary" in l), None)
    fails = {}
    cur = test = None
    if start is not None:
        for l in lines[start:]:
            if l.startswith("res://"):
                cur = l.strip().replace("res://tests/", "")
                continue
            m = re.match(r"^- (test_\w+)", l)
            if m and cur:
                test = m.group(1)
                fails.setdefault(cur, {}).setdefault(test, [])
                continue
            m = re.match(r"^\s+\[Failed\]:\s*(.*)$", l)
            if m and cur and test:
                fails[cur][test].append(m.group(1).strip())
    counts = {k: v for k, v in (re.match(r"^(Tests|Passing Tests|Failing Tests|Asserts|Time)\s+(.*)$", l).groups()
                                for l in lines if re.match(r"^(Tests|Passing Tests|Failing Tests|Asserts|Time)\s", l))}
    return fails, counts


for case in CASES:
    globals()[case.lower()]()
    diff = subprocess.run(["git", "diff", "--stat"], cwd=WT, capture_output=True, text=True).stdout
    env = dict(os.environ, XDG_DATA_HOME=XDG)
    args = ["tools/ci/run_tests.sh"] + ([f"-gselect={SELECT[case]}"] if case in SELECT else [])
    try:
        run = subprocess.run(args, cwd=WT, env=env, capture_output=True, text=True, timeout=900)
        log, code = run.stdout + run.stderr, run.returncode
    except subprocess.TimeoutExpired as e:
        log, code = (e.stdout or b"").decode() if isinstance(e.stdout, bytes) else (e.stdout or ""), "timeout"
    with open(f"{OUT}/{case}.log", "w") as f:
        f.write(log)
    fails, counts = summary(log)
    with open(f"{OUT}/{case}.txt", "w") as f:
        f.write(f"{case} exit {code}\n{diff}\n{counts}\n")
        n = 0
        for script, tests in fails.items():
            for test, msgs in tests.items():
                n += 1
                f.write(f"  {script} {test}: {len(msgs)} failed asserts\n")
                for msg in msgs[:4]:
                    f.write(f"      {msg[:220]}\n")
        f.write(f"{n} failing tests\n")
    subprocess.run(["git", "checkout", "-q", "--", "."], cwd=WT, check=True)
    left = subprocess.run(["git", "status", "--porcelain"], cwd=WT, capture_output=True, text=True).stdout
    print(f"{case} exit {code}, {sum(len(t) for t in fails.values())} failing tests, restored: {left.strip() or 'clean'}",
          flush=True)
