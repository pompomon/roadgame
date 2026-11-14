class_name Heading
## Grid directions. N is -y and W is -x. The correct path only heads N or W (plan.md §3.2).

enum { N, E, S, W }

const VEC: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const NAMES: Array[String] = ["N", "E", "S", "W"]
## Exits bitmask with all four headings.
const ALL := 0b1111


static func left(h: int) -> int:
	return (h + 3) % 4


static func right(h: int) -> int:
	return (h + 1) % 4


static func opposite(h: int) -> int:
	return (h + 2) % 4


## The heading that turn `turn_number` (0-based) takes from heading `h`: even turns go left, odd
## turns go right. It is the expected exit of the junction with that turn number, but not of a
## decoy before it, which shares the number (docs/ROADGEN.md R1).
static func turn_for(turn_number: int, h: int) -> int:
	return left(h) if turn_number % 2 == 0 else right(h)


## Bit of heading `h` in an exits bitmask.
static func bit(h: int) -> int:
	return 1 << h


## Heading of a step to a neighbouring cell, or -1 if `step` is not one.
static func from_vec(step: Vector2i) -> int:
	return VEC.find(step)
