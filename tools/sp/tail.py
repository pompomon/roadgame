import random, sys, time
import model as m
label = sys.argv[1]
n = int(sys.argv[2])
seed = int(sys.argv[3])
road = {"pier": m.PIER, "home": m.HOME}[label]
rng = random.Random(seed)
t0 = time.time()
ts = [m.run(rng, m.SP_AREAS, road, 0.0035) for _ in range(n)]
ts.sort()
def q(p):
    return ts[min(n - 1, int(p * n))]
over = {b: sum(1 for t in ts if t > b) for b in (270, 280, 290, 295, 300, 305, 310)}
print(label, "n", n, "mean %.2f" % (sum(ts) / n), "p95 %.1f p99 %.1f p99.9 %.1f p99.99 %.1f max %.1f" % (q(0.95), q(0.99), q(0.999), q(0.9999), ts[-1]), "over", over, "secs %.0f" % (time.time() - t0))
