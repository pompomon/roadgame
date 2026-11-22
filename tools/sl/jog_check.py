"""The jog's numbers by h (SLIDE_PLAN.md §5.3 and §5.7.3): the carry's steepest slope, the longest
carried step, its frames, where a carried car crosses into C2, and how far a backward slide takes
the car down the screen below its C1's entry edge. Uses carry_check's model."""
import math

from carry_check import R, smooth

CAP = 7.0
ROW_PX = 32


def main():
    us = [i / 10000 - 0.5 for i in range(10001)]
    for h in (0.2, 0.25, 0.3):
        slope = 1.5 / (2 * h)
        print(f"h {h:.2f}: slope {slope:.2f} ({math.degrees(math.atan(slope)):.0f} deg); "
              f"carried step <= {CAP / 60 * (1 + slope):.3f}; frames at 7, 5.5, 2 tiles/s: "
              f"{2 * h / 7 * 60:.1f}, {2 * h / 5.5 * 60:.1f}, {2 * h / 2 * 60:.1f}")
        # Where w = w0 + s(u) passes 0.5, into C2, over |w0| <= R.
        cross = [next(u for u in us if w0 + smooth(h, u) > 0.5) for w0 in (-R, R)]
        print(f"   enters C2 between u = {min(cross):+.3f} and {max(cross):+.3f}")
        # A backward slide's screen row is r + u - s(u), and the car entered C1 at u = -0.5.
        dip = -0.5 - min(u - smooth(h, u) for u in us)
        print(f"   backward dip below C1's entry: {dip:.3f} rows = {dip * ROW_PX:.1f} px")
    print(f"every chord stays on the road for h <= R - cap/60 = {R - CAP / 60:.4f}")


if __name__ == "__main__":
    main()
