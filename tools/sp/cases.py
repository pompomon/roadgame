import random, sys
import model as m
from variants import roads, OWNER

def stats(ts):
    n = len(ts); ts = sorted(ts)
    q = lambda p: ts[min(n - 1, int(p * n))]
    return "mean %.1f p95 %.1f p99 %.1f p99.9 %.1f max %.1f >300 %d" % (
        sum(ts) / n, q(0.95), q(0.99), q(0.999), ts[-1], sum(1 for t in ts if t > 300))

N = int(sys.argv[1])
pier, home = roads(*OWNER)
MAINSTR = m.areas_with(meadows=dict(mn=3, mx=7), village=dict(mn=2, mx=5), desert=dict(mn=3, mx=8))
TWICE = m.areas_with(meadows=dict(mn=6, mx=14), village=dict(mn=4, mx=10), desert=dict(mn=6, mx=16))
Q14 = m.areas_with(desert=dict(decoy=0.2))
CASES = [
    ("main", m.MAIN_AREAS, m.MAIN_PIER, m.MAIN_HOME, 0.002),
    ("owner turns, main straights", MAINSTR, pier, home, 0.0035),
    ("SP (owner)", m.SP_AREAS, pier, home, 0.0035),
    ("twice main straights (Q3 alt)", TWICE, pier, home, 0.0035),
    ("desert decoys 0.2 (Q14 alt)", Q14, pier, home, 0.0035),
]
for name, areas, p, h, g in CASES:
    out = []
    for label, road, seed in (("pier", p, 1), ("home", h, 2)):
        rng = random.Random(seed)
        out.append(label + " " + stats([m.run(rng, areas, road, g) for _ in range(N)]))
    print("%-32s | %s" % (name, " | ".join(out)), flush=True)
# Q2's alternatives: the Road Home with the Desert's 60 turns first
q2a = ([(0, "desert", 0), (60, "village", 0), (70, "meadows", 0), (94, "rural", 5), (118, "city", 6)], 138)
q2b = ([(0, "desert", 0), (60, "city", 6)], 80)
for name, road in (("Q2 alt: desert 60 + the rest", q2a), ("Q2 alt: desert 60 + city 20", q2b)):
    rng = random.Random(3)
    ts = []
    d = []
    for _ in range(N):
        zl = []
        ts.append(m.run(rng, m.SP_AREAS, road, 0.0035, zl))
        d.append(zl[0]["desert"])
    print("%-32s | %s | desert mean %.1f" % (name, stats(ts), sum(d) / len(d)), flush=True)
