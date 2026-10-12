extends RefCounted
## Shots in flight (arrows, bolts, javelins, stones, darts): one record each, in the order they were
## loosed, in one flat int array (STRIDE ints a shot). A ranged attack doesn't land the tick it is
## loosed: it flies at the spot its target was at (led by its pace, rules shot_lead_pct) and lands
## there `flight` ticks later, hitting whoever's body is on the spot then (combat.gd _land). State:
## hashed with the rest of the World.

enum { LAND, TO, BY, OWNER, DAMAGE, SRC, UP, X, Y, STRIDE }

var data := PackedInt32Array()


func count() -> int:
	return data.size() / STRIDE


## Loose a shot: lands at tick `land` on (x, y), meant for `to` (a unit or building id), from `by`
## (owned by `owner`), `damage` against the target as aimed. `src`: the shooter's unit type index,
## or -1 - its building type for a tower. `up`: the shooter's height step over the target (-1 uphill).
func add(land: int, to: int, by: int, owner: int, damage: int, src: int, up: int, x: int, y: int) -> void:
	data.append_array(PackedInt32Array([land, to, by, owner, damage, src, up, x, y]))


## The shots landing at `tick`, taken out of the air (records in loosing order).
func take(tick: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var n := count()
	var keep := 0
	for k in n:
		var o := k * STRIDE
		if data[o + LAND] <= tick:
			out.append_array(data.slice(o, o + STRIDE))
		else:
			if keep != k:
				for f in STRIDE:
					data[keep * STRIDE + f] = data[o + f]
			keep += 1
	if keep != n:
		data.resize(keep * STRIDE)
	return out


## Damage on its way to each unit (by slot): volleys spread rather than pile on one about to fall.
func inbound(units) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(units.count())
	for k in count():
		var j: int = units.index_of(data[k * STRIDE + TO])
		if j >= 0:
			out[j] += data[k * STRIDE + DAMAGE]
	return out

