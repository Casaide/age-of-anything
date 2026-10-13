extends RefCounted
## Integer maths for the sim. No floats anywhere in src/sim/: positions are
## milli-tiles, angles are 0..255 (a full turn), trig results are scaled by ONE.

const ONE := 1024
const ANGLES := 256
const MASK := 0xFFFFFFFF
const FNV_PRIME := 0x01000193
const FNV_START := 0x811C9DC5

## sin(2*pi*i/256) * 1024, rounded. Generated offline; never computed at runtime.
const SIN := [
	0, 25, 50, 75, 100, 125, 150, 175, 200, 224, 249, 273, 297, 321, 345, 369,
	392, 415, 438, 460, 483, 505, 526, 548, 569, 590, 610, 630, 650, 669, 688, 706,
	724, 742, 759, 775, 792, 807, 822, 837, 851, 865, 878, 891, 903, 915, 926, 936,
	946, 955, 964, 972, 980, 987, 993, 999, 1004, 1009, 1013, 1016, 1019, 1021, 1023, 1024,
	1024, 1024, 1023, 1021, 1019, 1016, 1013, 1009, 1004, 999, 993, 987, 980, 972, 964, 955,
	946, 936, 926, 915, 903, 891, 878, 865, 851, 837, 822, 807, 792, 775, 759, 742,
	724, 706, 688, 669, 650, 630, 610, 590, 569, 548, 526, 505, 483, 460, 438, 415,
	392, 369, 345, 321, 297, 273, 249, 224, 200, 175, 150, 125, 100, 75, 50, 25,
	0, -25, -50, -75, -100, -125, -150, -175, -200, -224, -249, -273, -297, -321, -345, -369,
	-392, -415, -438, -460, -483, -505, -526, -548, -569, -590, -610, -630, -650, -669, -688, -706,
	-724, -742, -759, -775, -792, -807, -822, -837, -851, -865, -878, -891, -903, -915, -926, -936,
	-946, -955, -964, -972, -980, -987, -993, -999, -1004, -1009, -1013, -1016, -1019, -1021, -1023, -1024,
	-1024, -1024, -1023, -1021, -1019, -1016, -1013, -1009, -1004, -999, -993, -987, -980, -972, -964, -955,
	-946, -936, -926, -915, -903, -891, -878, -865, -851, -837, -822, -807, -792, -775, -759, -742,
	-724, -706, -688, -669, -650, -630, -610, -590, -569, -548, -526, -505, -483, -460, -438, -415,
	-392, -369, -345, -321, -297, -273, -249, -224, -200, -175, -150, -125, -100, -75, -50, -25,
]


static func sin_a(angle: int) -> int:
	return SIN[angle & 255]


static func cos_a(angle: int) -> int:
	return SIN[(angle + 64) & 255]


## Floor of the square root, for n >= 0.
## Newton's steps from a power of two at or above the root (its half bit length, found in five
## halvings): about half the steps of starting from n. (A constant assert message: a formatted
## one is built on every call, and this runs thousands of times a tick.)
static func isqrt(n: int) -> int:
	assert(n >= 0, "isqrt of a negative number")
	if n < 2:
		return n
	var m := n
	var b := 1
	if m >= 1 << 32:
		m >>= 32
		b += 16
	if m >= 1 << 16:
		m >>= 16
		b += 8
	if m >= 1 << 8:
		m >>= 8
		b += 4
	if m >= 1 << 4:
		m >>= 4
		b += 2
	if m >= 1 << 2:
		b += 1
	var x := 1 << b   # n < 4^b, so the root is under x
	var y := (x + n / x) >> 1
	while y < x:
		x = y
		y = (x + n / x) >> 1
	return x


static func dist2(ax: int, ay: int, bx: int, by: int) -> int:
	var dx := bx - ax
	var dy := by - ay
	return dx * dx + dy * dy


## FNV-1a style mix of a 64-bit int (low and high words) into a 32-bit hash.
static func mix(h: int, v: int) -> int:
	h = ((h ^ (v & MASK)) * FNV_PRIME) & MASK
	return ((h ^ ((v >> 32) & MASK)) * FNV_PRIME) & MASK
