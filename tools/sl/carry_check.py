"""Chord check of the slide's carry, in the jog's frame: u along H, w toward the side.
C1 is the cell at (0, 0), C2 at (0, 1). A step moves u by v/60 and w by s(u_to) - s(u_from). A step
that enters the band in C1's cell is split at its edge, as CarSim.step() splits it. Each chord is
split at cell edges, and each part is tested against its cell's capsules (half-width 0.32), as
CarSim._follow_road does with RoadGeometry.on_road_spans."""
import math

R = 0.32
DT = 1.0 / 60.0
# Cell -> exits as unit vectors from its centre, in the (u, w) frame.
CELLS = {
    (-2, 0): [(-1, 0), (1, 0)],
    (-1, 0): [(-1, 0), (1, 0)],
    (0, 0): [(-1, 0), (0, 1)],   # C1: entry opp(H), exit side
    (0, 1): [(0, -1), (1, 0)],   # C2: entry opp(side), exit H
    (1, 1): [(-1, 0), (1, 0)],
    (2, 1): [(-1, 0), (1, 0)],
}


def smooth(h, u):
    t = min(max((u + h) / (2 * h), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def dist_seg(p, a, b):
    ax, ay = a; bx, by = b; px, py = p
    dx, dy = bx - ax, by - ay
    L = dx * dx + dy * dy
    t = 0.0 if L == 0 else max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / L))
    cx, cy = ax + t * dx, ay + t * dy
    return math.hypot(px - cx, py - cy)


def road_dist(p):
    cell = (math.floor(p[0] + 0.5), math.floor(p[1] + 0.5))
    exits = CELLS.get(cell)
    if not exits:
        return math.inf
    c = (float(cell[0]), float(cell[1]))
    return min(dist_seg(p, c, (c[0] + 0.5 * e[0], c[1] + 0.5 * e[1])) for e in exits)


def worst_on_chord(a, b, samples=120):
    worst = 0.0
    for i in range(samples + 1):
        t = i / samples
        p = (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
        worst = max(worst, road_dist(p))
    return worst


def drive(h, v, w0, phase):
    du = v * DT
    # Outside the carry's band the car drives straight along its lane, which is on the road for
    # |w0| <= 0.32, so only the steps from just before the band to just after it are checked.
    u = -h - du - phase * du
    w = w0
    worst = 0.0
    while u < h + du:
        u2 = u + du
        if u < -h < u2 and math.floor(w + 0.5) == 0:
            worst = max(worst, worst_on_chord((u, w), (-h, w)))
            u = -h
        w2 = w + smooth(h, u2) - smooth(h, u)
        worst = max(worst, worst_on_chord((u, w), (u2, w2)))
        u, w = u2, w2
    return worst


def worst(h, speeds, widths, phases=8):
    return max((drive(h, v, w0, k / phases), (v, w0, k / phases)) for v in speeds for w0 in widths
               for k in range(phases))


def main():
    speeds = [0.5, 1, 2, 3, 4, 5, 6, 7]
    lane = [i / 100 for i in range(-30, 31, 2)]
    # The least margin over |w0| <= 0.3, by h (SLIDE_PLAN.md §6.5's table).
    for h in (0.2, 0.25, 0.28, 0.3, 0.32, 0.35, 0.4):
        d, at = worst(h, speeds, lane)
        print(f"h {h:.2f}, |w0| <= 0.3: margin {R - d:+.4f} at v, w0, phase = {at}")
    # Near the lane's edge (X15). Section 5.3 proves h <= R - 7/60 keeps every chord on the road.
    for h in (0.2, 0.25, 0.3):
        for edge in (0.318, 0.32):
            d, at = worst(h, speeds, [-edge, edge], phases=16)
            print(f"h {h:.2f}, |w0| = {edge}: margin {R - d:+.4f} at v, w0, phase = {at}")


if __name__ == "__main__":
    main()
