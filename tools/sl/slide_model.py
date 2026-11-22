"""A model of RoadGenerator's geometry with slides (SLIDE_PLAN.md P4), to back the plan's claims.

Mirrors road/road_generator.gd at e73f96d: the staircase, the kinds, the dead ends' free runs,
the schedules' set pieces and pit stops, and the finish. Not the tutorial (the City has no
slides). Its random numbers are Python's, so it checks shapes, not the game's seeds.
"""

import random
import sys

N, E, S, W = 0, 1, 2, 3
VEC = [(0, -1), (1, 0), (0, 1), (-1, 0)]


def left(h):
    return (h + 3) % 4


def right(h):
    return (h + 1) % 4


def opp(h):
    return (h + 2) % 4


def turn_for(n, h):
    return left(h) if n % 2 == 0 else right(h)


def add(c, h, k=1):
    return (c[0] + VEC[h][0] * k, c[1] + VEC[h][1] * k)


AREAS = {
    "city": dict(lo=2, hi=5, cross=0.4, side=0.0, decoy=0.0),
    "rural": dict(lo=3, hi=7, cross=0.25, side=0.15, decoy=0.1),
    "meadows": dict(lo=6, hi=12, cross=0.3, side=0.2, decoy=0.15),
    "village": dict(lo=4, hi=8, cross=0.35, side=0.2, decoy=0.15),
    "desert": dict(lo=6, hi=12, cross=0.3, side=0.3, decoy=0.15),
    "coast": dict(lo=20, hi=20, cross=0.3, side=0.0, decoy=0.0),
}
# (turn, area, set_piece_length, pit_stop)
PIER = dict(mirrored=False, finish=100, entries=[
    (0, "city", 0, False), (20, "rural", 6, True), (44, "meadows", 5, True),
    (68, "village", 0, False), (78, "desert", 0, True), (100, "coast", 0, False)])
HOME = dict(mirrored=True, finish=100, entries=[
    (0, "desert", 0, False), (22, "village", 0, True), (32, "meadows", 0, False),
    (56, "rural", 5, True), (80, "city", 6, True)])
MARGIN = 2


class Gen:
    def __init__(self, rng, schedule, chances, back_share, veto=True, endless_area=None):
        self.rng = rng
        self.slide_rng = random.Random(rng.random())
        self.sched = schedule
        self.chances = chances
        self.back_share = back_share
        self.veto = veto
        self.occ = {}
        self.overlaps = 0
        self.dropped = 0
        self.no_wrong = 0
        self.short_opp = 0  # opposite-turn dead ends under 2 tiles
        self.cut_straight_on = 0  # straight-on dead ends cut short
        self.slides = [0, 0]  # forward, backward
        self.vetoed = [0, 0]
        self.heading = W if schedule["mirrored"] else N
        self.parity = 1 if schedule["mirrored"] else 0
        self.area = endless_area or schedule["entries"][0][1]
        self.endless = endless_area is not None
        self.idx = 1
        self.turns = 0
        self.cursor = (0, 0)
        self.plan = []  # tiles still to lay: (kind, exits_out, heading_in)
        self.straight_left = 4
        self.sampled = False
        self.pit = False
        self.set_left = 0
        self.pending = None
        self.finishing = False
        self.path = []

    def claim(self, cell, what):
        if cell in self.occ:
            self.overlaps += 1
            return
        self.occ[cell] = what

    def sample(self):
        a = AREAS[self.area]
        self.sampled = True
        # The slide's stream: a fixed 3 draws per sampled straight (X11).
        self.rolls = (self.slide_rng.random(), self.slide_rng.random(), self.slide_rng.random())
        return self.rng.randint(a["lo"], a["hi"])

    def plan_straight(self, s):
        """At a straight's first tile: its tiles, with a slide or none."""
        h = self.heading
        tiles = [("S", h, h)] * s
        if not self.sampled or self.pit or self.finishing or s < 2 * MARGIN + 2:
            return tiles
        roll, side_roll, pos_roll = self.rolls
        if roll >= self.chances.get(self.area, 0.0):
            return tiles
        back = side_roll < self.back_share
        side = (E if h == N else S) if back else (W if h == N else N)
        p = MARGIN + int(pos_roll * (s - 2 * MARGIN - 1))
        c1 = add(self.cursor, h, p)
        c2 = add(c1, side)
        j = add(c2, h, s - p - 1)
        cells = [c1] + [add(c2, h, k) for k in range(0, s - p)]
        if back:
            cells += [add(j, side, 1), add(j, side, 2)]
        if self.veto and any(c in self.occ for c in cells):
            self.vetoed[back] += 1
            return tiles
        self.slides[back] += 1
        tiles = list(tiles)
        tiles[p] = ("C1", side, h)
        tiles[p + 1] = ("C2", h, side)
        return tiles

    def next_tile(self):
        if self.set_left > 0:
            self.lay(h_out=self.heading)
            self.set_left -= 1
            if self.set_left == 0:
                self.pit = False
                self.enter(self.pending)
            return
        if self.straight_left > 0 and not self.plan:
            self.plan = self.plan_straight(self.straight_left)
        if self.plan:
            kind, out, h_in = self.plan.pop(0)
            self.straight_left -= 1
            self.lay(h_out=out)
            if self.straight_left == 0:
                self.pit = False
                self.sampled = False
            return
        if self.finishing:
            self.lay(h_out=self.heading)
            return "done"
        self.junction()

    def lay(self, h_out):
        self.claim(self.cursor, "path")
        self.path.append(self.cursor)
        self.heading = h_out
        self.cursor = add(self.cursor, h_out)

    def free_run(self, cell, h, length):
        for k in range(1, length + 1):
            if add(cell, h, k) in self.occ:
                return k - 1
        return length

    def junction(self):
        a = AREAS[self.area]
        h = self.heading
        turn = turn_for(self.turns + self.parity, h)
        r = self.rng.random()
        kind = "T"
        if r < a["cross"]:
            kind = "X"
        elif r < a["cross"] + a["side"]:
            kind = "SIDE"
        elif r < a["cross"] + a["side"] + a["decoy"]:
            kind = "DECOY"
        cell = self.cursor
        self.claim(cell, "path")
        self.path.append(cell)
        wrong = []
        if kind != "SIDE":
            wrong.append(("opp", opp(turn)))
        if kind in ("X", "SIDE"):
            wrong.append(("on", h))
        branches = 0
        for what, ex in wrong:
            length = self.rng.randint(6, 9)
            fits = self.free_run(cell, ex, length)
            if fits == 0:
                self.dropped += 1
                continue
            if what == "opp" and fits < 2:
                self.short_opp += 1
            if what == "on" and fits < length:
                self.cut_straight_on += 1
            for k in range(1, fits + 1):
                self.claim(add(cell, ex, k), "dead")
            branches += 1
        if branches == 0:
            self.no_wrong += 1
        out = h if kind == "DECOY" else turn
        self.cursor = add(cell, out)
        if kind == "DECOY":
            self.straight_left = self.sample()
            return
        self.heading = turn
        self.turns += 1
        entry = self.due()
        if entry is None:
            self.straight_left = self.sample()
        elif entry[2] > 0:
            self.pending = entry[1]
            self.set_left = entry[2]
            self.pit = entry[3]
        else:
            self.enter(entry[1])
            self.pit = entry[3]
        self.finishing = self.finish_due()

    def due(self):
        if self.endless:
            return None
        es = self.sched["entries"]
        if self.idx >= len(es) or es[self.idx][0] > self.turns:
            return None
        self.idx += 1
        return es[self.idx - 1]

    def enter(self, area):
        self.area = area
        self.straight_left = self.sample()

    def finish_due(self):
        if self.endless or self.idx < len(self.sched["entries"]):
            return False
        return self.turns >= self.sched["finish"]


def run(schedule, seeds, chances, back_share, veto=True, endless_area=None, turns=300):
    totals = dict(overlaps=0, dropped=0, no_wrong=0, short_opp=0, cut_on=0, fwd=0, back=0,
                  vetoed_fwd=0, vetoed_back=0, runs_with_problem=0)
    for seed in range(seeds):
        g = Gen(random.Random(seed), schedule, chances, back_share, veto, endless_area)
        steps = 0
        while steps < 20000:
            steps += 1
            if g.next_tile() == "done" or (endless_area and g.turns >= turns):
                break
        problem = g.overlaps + g.dropped + g.no_wrong + g.short_opp + g.cut_straight_on
        totals["runs_with_problem"] += 1 if problem else 0
        for k, v in (("overlaps", g.overlaps), ("dropped", g.dropped), ("no_wrong", g.no_wrong),
                     ("short_opp", g.short_opp), ("cut_on", g.cut_straight_on),
                     ("fwd", g.slides[0]), ("back", g.slides[1]),
                     ("vetoed_fwd", g.vetoed[0]), ("vetoed_back", g.vetoed[1])):
            totals[k] += v
    return totals


if __name__ == "__main__":
    seeds = int(sys.argv[1]) if len(sys.argv) > 1 else 2000
    q5 = {"rural": 0.15, "meadows": 0.2, "village": 0.2, "desert": 0.25}
    every = {a: 1.0 for a in AREAS}
    for name, sched in (("pier", PIER), ("home", HOME)):
        print(name, "no slides     ", run(sched, seeds, {}, 0.5))
        print(name, "Q5, share 0.5 ", run(sched, seeds, q5, 0.5))
        print(name, "Q5, fwd only  ", run(sched, seeds, q5, 0.0))
        print(name, "every, 0.5    ", run(sched, seeds, every, 0.5))
        print(name, "every, back   ", run(sched, seeds, every, 1.0))
        print(name, "every, no veto", run(sched, seeds, every, 1.0, veto=False))
        print(name, "every, fwd, no veto", run(sched, seeds, every, 0.0, veto=False))
    for area in ("rural", "village", "desert"):
        print("endless", area, "every, 0.5", run(PIER, seeds // 4, every, 0.5, endless_area=area))
        print("endless", area, "back, no veto",
              run(PIER, seeds // 4, every, 1.0, veto=False, endless_area=area))
