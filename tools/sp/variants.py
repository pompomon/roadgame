import random, sys
import model as m

def roads(c, r, me, v, d):
    pier = ([(0, "city", 0), (c, "rural", 6), (c + r, "meadows", 5), (c + r + me, "village", 0),
             (c + r + me + v, "desert", 0), (c + r + me + v + d, "coast", 0)], c + r + me + v + d)
    home = ([(0, "desert", 0), (d, "village", 0), (d + v, "meadows", 0), (d + v + me, "rural", 5),
             (d + v + me + r, "city", 6)], c + r + me + v + d)
    return pier, home

OWNER = (20, 24, 24, 10, 22)
CASES = {
    "V0 owner": (OWNER, m.SP_AREAS, 0.0035),
    "V1 meadows 22": ((20, 24, 22, 10, 22), m.SP_AREAS, 0.0035),
    "V2 meadows 20": ((20, 24, 20, 10, 22), m.SP_AREAS, 0.0035),
    "V3 desert 20": ((20, 24, 24, 10, 20), m.SP_AREAS, 0.0035),
    "V4 meadows 22 desert 20": ((20, 24, 22, 10, 20), m.SP_AREAS, 0.0035),
    "V5 meadows straights 6-10": (OWNER, m.areas_with(meadows=dict(mn=6, mx=10)), 0.0035),
    "V6 meadows+desert 6-11": (OWNER, m.areas_with(meadows=dict(mn=6, mx=11), desert=dict(mn=6, mx=11)), 0.0035),
    "V7 meadows+desert 6-10": (OWNER, m.areas_with(meadows=dict(mn=6, mx=10), desert=dict(mn=6, mx=10)), 0.0035),
    "V8 growth 0.005": (OWNER, m.SP_AREAS, 0.005),
    "V9 meadows decoys 0.1": (OWNER, m.areas_with(meadows=dict(decoy=0.1)), 0.0035),
    "V10 0.002 (old growth)": (OWNER, m.SP_AREAS, 0.002),
}
n = int(sys.argv[1])
which = sys.argv[2:] or list(CASES)
for name in which:
    turns, areas, growth = CASES[name]
    pier, home = roads(*turns)
    out = []
    for label, road, seed in (("pier", pier, 1), ("home", home, 2)):
        rng = random.Random(seed)
        ts = sorted(m.run(rng, areas, road, growth) for _ in range(n))
        q = lambda p: ts[min(n - 1, int(p * n))]
        out.append("%s mean %.1f p99.9 %.1f p99.99 %.1f max %.1f >300 %d" % (
            label, sum(ts) / n, q(0.999), q(0.9999), ts[-1], sum(1 for t in ts if t > 300)))
    print("%-28s | %s" % (name, " | ".join(out)), flush=True)
