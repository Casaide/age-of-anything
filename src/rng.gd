extends RefCounted
## Deterministic xorshift32. Same seed gives the same sequence on every machine.
## Never use randi()/randf() for anything that affects a race or the sim.

const MASK := 0xFFFFFFFF

var state: int


func _init(seed_value: int) -> void:
	state = seed_value & MASK
	if state == 0:
		state = 0x9E3779B9


## FNV-1a 32-bit over the UTF-8 bytes of a string.
static func hash_string(text: String) -> int:
	var h := 0x811C9DC5
	for b in text.to_utf8_buffer():
		h = h ^ b
		h = (h * 0x01000193) & MASK
	return h


func next_u32() -> int:
	var x := state
	x ^= (x << 13) & MASK
	x ^= x >> 17
	x ^= (x << 5) & MASK
	state = x & MASK
	return state


## Inclusive range.
func range_int(lo: int, hi: int) -> int:
	return lo + next_u32() % (hi - lo + 1)


func chance(percent: int) -> bool:
	return next_u32() % 100 < percent


func pick(items: Array):
	return items[next_u32() % items.size()]


func shuffled(items: Array) -> Array:
	var out := items.duplicate()
	for i in range(out.size() - 1, 0, -1):
		var j := next_u32() % (i + 1)
		var t = out[i]
		out[i] = out[j]
		out[j] = t
	return out
