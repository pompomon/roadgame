"""The carry's rounding (SLIDE_PLAN.md §5.3): forward carries replayed in 32-bit floats, as Godot's
Vector2 holds `pos`. The car is moved by `pos += across * (now - was)`, or by the offset that
`_carried_offset` keeps, `pos += across * (offset + now - w)`. C1's centre is (c, c); the road heads
N and slides W, so u = cy - y and w = cx - x. The car is held straight, so its own moves across
round away, as they do in Godot."""
import struct

H = 0.2
R = 0.32
SPEEDS = (2.0, 3.2, 4.0, 5.5, 7.0)
PHASES = 16


def f32(x):
    return struct.unpack("f", struct.pack("f", x))[0]


def sigma(u):
    t = min(max((u + H) / (2 * H), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def drive(c, w0, speed, phase, kept):
    """The car's offset from the carried centreline after the band, and before it."""
    cx = cy = f32(c)
    x = f32(cx - w0)
    y = f32(cy + 0.5 - phase * speed / 60)
    start = cx - x
    dy = f32(f32(-speed) * f32(1 / 60))
    latched, offset = False, 0.0
    while cy - y < 0.6:
        fx, fy = x, y
        y = f32(y + dy)
        was, now = sigma(cy - fy), sigma(cy - y)
        w_from, w = cx - fx, cx - x
        if not latched and was in (0.0, 1.0) and now != was:
            latched, offset = True, w_from - was
        if latched:
            if kept:
                offset += w - w_from
                x = f32(x - f32(offset + now - w))
            else:
                x = f32(x - f32(now - was))
            if now in (0.0, 1.0):
                latched = False
    return cx - x - 1.0, start


def drives(c, offsets, speeds, kept):
    return [drive(c, w0, s, k / PHASES, kept) for w0 in offsets for s in speeds for k in range(PHASES)]


def main():
    edge = (-0.3199, -0.318, 0.318, 0.3199)
    n = len(edge) * len(SPEEDS) * PHASES
    print(f"C1's centre | carry | largest drift | drives of {n} that end off the road")
    for c in (-511.5, -1023.5):
        for kept, name in ((False, "across * (now - was)"), (True, "the kept offset")):
            ends = drives(c, edge, SPEEDS, kept)
            drift = max(abs(end - start) for end, start in ends)
            print(f"({c}, {c}) | {name} | {drift:.5f} | {sum(abs(end) > R for end, _ in ends)}")
    # Far out, past a power of 2, P tiles out, the kept offset may round once, by up to P * 2**-24.
    c, p = -8191.5, 8192
    for w0 in (0.318, 0.3198):
        ends = drives(c, (-w0, w0), SPEEDS, True)
        drift = max(abs(end - start) for end, start in ends)
        print(f"({c}, {c}) | the kept offset, |w0| = {w0} | {drift:.6f}, bound {p * 2 ** -24:.6f} | "
              f"{sum(abs(end) > R for end, _ in ends)} of {len(ends)}")
    # The far slide's test: each C1 from 256 to 511 tiles out, w0 = 0.3, at 2 and 7 tiles/s, so
    # that no coordinate reaches 512.
    fewest, old, kept = 2 * PHASES, 0.0, 0.0
    for i in range(255):
        c = -256.5 - i
        moved = [abs(end - start) for end, start in drives(c, (0.3,), (2.0, 7.0), False)]
        fewest = min(fewest, sum(m > 1e-6 for m in moved))
        old = max(old, max(moved))
        kept = max(kept, max(abs(end - start) for end, start in drives(c, (0.3,), (2.0, 7.0), True)))
    print(f"the test, C1 from -256.5 to -510.5: across * (now - was) drifts in {fewest} or more of "
          f"{2 * PHASES} drives, by up to {old:.5f}; the kept offset by up to {kept}")

if __name__ == "__main__":
    main()
