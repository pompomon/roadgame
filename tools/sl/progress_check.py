"""Progress on a slide's corners (SLIDE_PLAN.md §5.4, N3): the nearer-half measure that
path_progress() uses on every tile (car_sim.gd:224-233, here with exit_heading() at line 229) against
the slide branch. Frame as carry_check's: u along H, w toward the side, C1 at (0, 0), C2 at (0, 1)."""
import math

from carry_check import smooth

SPEEDS = [0.5, 1, 2, 3, 4, 5, 6, 7]


# Tiles: cell -> (index, into, out), in the (u, w) frame.
TILES = {
    (-1, 0): (-1, (1, 0), (1, 0)),
    (0, 0): (0, (1, 0), (0, 1)),
    (0, 1): (1, (0, 1), (1, 0)),
    (1, 1): (2, (1, 0), (1, 0)),
}


def clamp(x, a, b):
    return max(a, min(b, x))


def nearer(cell, p):
    idx, i, o = TILES[cell]
    rel = (p[0] - cell[0], p[1] - cell[1])
    ti = clamp(rel[0] * i[0] + rel[1] * i[1], -0.5, 0.0)
    to = clamp(rel[0] * o[0] + rel[1] * o[1], 0.0, 0.5)
    di = (rel[0] - i[0] * ti) ** 2 + (rel[1] - i[1] * ti) ** 2
    do = (rel[0] - o[0] * to) ** 2 + (rel[1] - o[1] * to) ** 2
    return idx + (ti if di < do else to)


def slide(h, cell, p):
    idx = TILES[cell][0]
    if cell in ((0, 0), (0, 1)):
        return clamp(p[0], -0.5, 0.5) + smooth(h, p[0])
    return idx + (p[0] - cell[0])


def cell_of(p):
    return (math.floor(p[0] + 0.5), math.floor(p[1] + 0.5))


def progress(h):
    for w0 in (-0.3, 0.0, 0.3):
        p = (h, 1 + w0)
        print(f"h {h}: on C2 at u = h, w0 {w0:+.1f}: nearer {nearer((0, 1), p):.2f}, slide {slide(h, (0, 1), p):.2f}")
    # Unsteered drives: the worst fall of each formula, and the largest rise beyond the step's move.
    for name, f in (("nearer", lambda c, p: nearer(c, p)), ("slide", lambda c, p: slide(h, c, p))):
        fall = 0.0
        extra = 0.0
        for v in SPEEDS:
            for w0 in [i / 100 for i in range(-32, 33, 2)]:
                du = v / 60
                u, w = -1.4, w0
                cell = cell_of((u, w))
                last = f(cell, (u, w))
                while u < 1.4:
                    u2 = u + du
                    w2 = w + smooth(h, u2) - smooth(h, u)
                    u, w = u2, w2
                    c = cell_of((u, w))
                    if c in TILES:
                        cell = c
                    pr = f(cell, (u, w))
                    fall = min(fall, pr - last)
                    extra = max(extra, pr - last - du)
                    last = pr
        print(f"h {h}: {name}: worst fall {fall:+.3f}, largest rise beyond the step {extra:.3f}")
    # Steering across C2 at u = 0.1: w from 0.6 to 1.3.
    for name, f in (("nearer", lambda c, p: nearer(c, p)), ("slide", lambda c, p: slide(h, c, p))):
        vals = [f((0, 1), (0.1, 0.6 + i * 0.01)) for i in range(71)]
        print(f"h {h}: {name}: across C2 at u 0.1: from {vals[0]:.2f} to {vals[-1]:.2f}, "
              f"min {min(vals):.2f}, max {max(vals):.2f}")


if __name__ == "__main__":
    progress(0.2)
