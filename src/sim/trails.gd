extends RefCounted
## Worn trails (milestone 15): no road building; where units walk often the ground wears into
## a trail, and where nobody walks it grows back. A byte per cell (w.wear): every few ticks
## each walking unit (flyers don't count) wears its cell a little, and every so often every
## cell grows back a little (rules.trails). A cell worn to `trail` is a trail: the view draws
## it, and, behind a rules switch (speed_pct, 0 by default), walkers on it are faster.
## Deterministic (integers, unit order), so it's sim state and hashed.

const SimMap := preload("res://src/sim/sim_map.gd")


static func setup(w) -> void:
	var t: Dictionary = w.rules.get("trails", {})
	w.trail_cfg = {"every": int(t.get("every", 10)), "add": int(t.get("add", 1)), "max": mini(int(t.get("max", 120)), 255),
		"decay_every": int(t.get("decay_every", 100)), "decay": int(t.get("decay", 1)), "trail": int(t.get("trail", 30)),
		"speed_pct": int(t.get("speed_pct", 0))}
	w.wear = PackedByteArray()
	w.wear.resize(w.map.width * w.map.height)


static func tick(w) -> void:
	var cfg: Dictionary = w.trail_cfg
	var wear: PackedByteArray = w.wear
	if w.tick % int(cfg.every) == 0:
		var u = w.units
		var add: int = cfg.add
		var top: int = cfg.max
		for i in u.count():
			if u.moving[i] == 1 and u.mclass[i] != SimMap.FLYING:
				var c: int = w.map.cell_of(u.x[i], u.y[i])
				wear[c] = mini(wear[c] + add, top)
	# Growing back, spread over the ticks: each row once every decay_every ticks (no spike).
	var every: int = cfg.decay_every
	var d: int = cfg.decay
	var wd: int = w.map.width
	for y in range(w.tick % every, w.map.height, every):
		for c in range(y * wd, y * wd + wd):
			if wear[c] > 0:
				wear[c] = maxi(wear[c] - d, 0)
	w.wear = wear


## Percent speed for a walker on this cell: 100, or more on a trail (when the rule is on).
static func speed_pct(w, cell: int) -> int:
	var pct: int = w.trail_cfg.speed_pct
	if pct == 0 or w.wear[cell] < int(w.trail_cfg.trail):
		return 100
	return 100 + pct
