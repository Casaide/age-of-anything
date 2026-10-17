extends RefCounted
## The creature kit (Dominic, 2026-10-13: "start the creature kit and concept sheet tool, bear first").
## A creature as a parametric skeleton in data instead of a hand-built model: a quadruped (spine from
## the shoulders to the hips, neck, head, tail; each leg shoulder/elbow/wrist/paw or hip/knee/hock/paw)
## or a biped (hips, a leaning torso, shoulders/elbows/hands, hip/knee/ankle/foot), each foot
## plantigrade (the sole flat on the ground: bears) or digitigrade (up on the toes, the hock high: cats)
## by its bones and angles. From the numbers it makes:
##   - the body: torso volumes (chest, waist, rump, hump... as blobs, or a modelled mesh over the same
##     skeleton), neck, tail, tack, a biped's arms posed for its hold (unit_models.arm_pose);
##   - each leg in every pose: standing, the steps of the walk ("leg@w<i>_<n>"), the idle poses
##     ("@sit1"...), by two-bone IK from where the paw or foot goes;
##   - the head (skull, cheeks, muzzle, nose, eyes, brow, ears) on its socket;
##   - the sockets (head, seat, girth, hands, torso, back, wings), the hips (anchors, turned by
##     unit_models.leg_basis at bake time) and the fitting data (torso_fit for worn armour);
##   - the part's data for parts.json (complete()): sockets and anchors in 2D, cut legs (and the head
##     on four legs), the posed walk, idle poses and gait, so data anchors are the model's hips by
##     construction.
## Kits live in data/creature_kit.json ("kits": {name: params}); a kit can extend another ("base").
## A part with "kit": "<name>" is completed from it: in data/parts.json by DataLib on load (the bears,
## 2026-10-17), in a staged data file by stage() (tests and sheets: data/later/*.json).
## Coordinates: part units, x forward, y up, z towards the near side; the ground is y = 0.

const DataLib := preload("res://src/data_lib.gd")
const Identity := preload("res://src/identity.gd")

static var kits := {}       # kit name -> its parameters (bases merged in)
static var part_kit := {}   # part id -> [kit name, role]: "body", "head", "leg", "hind"
static var _staged := {}    # data files staged into a lib (by the lib's instance id)

const INK := Color("#2a1a12")


# ------------------------------------------------------------------ data

## Stage a data file (data/creature_kit.json's comparison cats, data/later/*.json) into a DataLib: its
## kits, its parts (kit bodies completed, their heads and legs made), creatures, skins and lexicon
## words, and any concept model files it names ("models": gear modelled for the staged creatures).
## Tests and sheets only (the game's own kit parts, the bears, DataLib completes on load).
static func stage(lib, path: String) -> void:
	var key := "%d|%s" % [lib.get_instance_id(), path]
	if _staged.has(key):
		return
	_staged[key] = true
	var d: Dictionary = DataLib.load_json(path)
	var all: Dictionary = d.get("kits", {})
	for name in all:
		register(name, _resolved(name, all))
	for p in d.get("parts", []):
		var q: Dictionary = p.duplicate(true)
		if q.has("kit"):
			for extra in complete(q):
				if not lib.parts.has(extra.id):
					lib.parts[extra.id] = extra
		lib.parts[q.id] = q
	for id in d.get("creatures", {}):
		lib.creatures[id] = d.creatures[id]
		Identity.files().creatures[id] = d.creatures[id]   # (a race's bonuses come from creatures.json on disk: a staged race's from here)
	for s in d.get("skins", {}):
		lib.palettes.skins[s] = d.skins[s]
	for w in d.get("words", {}):
		lib.lexicon[w] = d.words[w]
	var UnitModels = load("res://scenes/art_pixel/unit_models.gd")
	for m in d.get("models", []):
		if not UnitModels.extra.any(func(e): return e.get_script().resource_path == m):
			UnitModels.extra.append(load(m).new())


## A kit with its base merged under it (deep: a variant changes only what it names).
## A kit can also take its head from another kit ("head_of"), changing only what its own "head" names:
## a mount carries the head of the creature on two legs, pitched down (bears, round B2).
static func _resolved(name: String, all: Dictionary) -> Dictionary:
	var k: Dictionary = all[name] if all.has(name) else kits[name]
	var out: Dictionary = k.duplicate(true)
	if k.has("base"):
		out = _merge(_resolved(k.base, all), k)
		out.erase("base")
	if k.has("head_of"):
		out.head = _merge(_resolved(k.head_of, all).head, k.get("head", {}))
		out.erase("head_of")
	return out


static func _merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate(true)
	for key in b:
		if out.has(key) and out[key] is Dictionary and b[key] is Dictionary:
			out[key] = _merge(out[key], b[key])
		else:
			out[key] = b[key].duplicate(true) if (b[key] is Dictionary or b[key] is Array) else b[key]
	return out


## Every kit of a data file (bases and head_of resolved): DataLib does this for data/creature_kit.json.
static func register_all(all: Dictionary) -> void:
	for name in all:
		register(name, _resolved(name, all))


static func register(name: String, k: Dictionary) -> void:
	kits[name] = k
	part_kit[k.parts.body] = [name, "body"]
	if k.has("head"):
		part_kit[k.parts.head] = [name, "head"]
	part_kit[k.parts.leg] = [name, "leg"]
	if k.parts.has("hind"):
		part_kit[k.parts.hind] = [name, "hind"]


static func has_part(id: String) -> bool:
	return part_kit.has(id)


static func quad(k: Dictionary) -> bool:
	return k.posture == "quadruped"


static func idle(k: Dictionary) -> Array:
	return k.get("sit", {}).get("order", []) if quad(k) else k.get("idle", {}).keys()


## Fill in a kit body part's data from its skeleton (as parts.json would hold it), and return the
## head and leg parts it needs.
static func complete(part: Dictionary) -> Array:
	var k: Dictionary = kits[part.kit]
	var sk := skeleton(k, "")
	var sc := float(k.get("scale", 1.0))
	part.cut = ["legs", "head"] if quad(k) else ["legs"]
	part.sockets = {}
	for s in sk.sockets:
		if s != "sit":
			part.sockets[s] = _v2(sk.sockets[s] * sc)
	var anchors := []
	for a in sk.anchors:
		anchors.append([snappedf(a[0].x * sc, 0.1), snappedf(-a[0].y * sc, 0.1), snappedf(float(a[1]), 0.01), int(a[2]), 0, bool(a[4])])
	var legs := {"part": k.parts.leg, "anchors": anchors, "poses": int(k.walk.steps),
		"gait": k.walk.get("gait", {"swing": 0.0}), "stance": k.get("stance", {})}
	if k.parts.has("hind"):
		legs.hind = k.parts.hind
	part.legs = legs
	part.idle_poses = idle(k)
	part.torso_scale = [1.3, 1.0] if quad(k) else [0.9, 1.1]
	var vol: Dictionary = k.body.get("chest", {"at": [0, 15], "r": [6, 6, 5]})
	part.shapes = [{"t": "ellipse", "c": [vol.at[0], -vol.at[1]], "r": [vol.r[0], vol.r[1]], "ch": "skin"}]
	var out := []
	if k.has("head"):
		out.append({"id": k.parts.head, "slot": "head", "sockets": {"top": _v2(_v3(k.head.top))}, "tags": [], "stats": {}, "points": 0,
			"shapes": [{"t": "circle", "c": [0, -4], "r": 4, "ch": "skin"}]})
	for leg in [k.parts.leg, k.parts.get("hind", "")]:
		if leg != "":
			out.append({"id": leg, "slot": "leg", "tags": [], "stats": {}, "points": 0,
				"shapes": [{"t": "poly", "p": [[-1.5, 0], [1.5, 0], [1.5, 10], [-1.5, 10]], "ch": "skin"}]})
	return out


static func _v2(v: Vector3) -> Array:
	return [snappedf(v.x, 0.1), snappedf(-v.y, 0.1)]


static func _v3(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]) if a.size() > 2 else 0.0)


static func _p2(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


# ------------------------------------------------------------------ skeleton

## The body's joints and sockets in a pose ("" standing, an idle pose), before the kit's scale:
## {"sockets": {...}, "anchors": [[hip, phase, side, flip, hind]], "xf": the pose's transform}.
static func skeleton(k: Dictionary, pose: String) -> Dictionary:
	return _quad_skeleton(k, pose) if quad(k) else _biped_skeleton(k, pose)


## Quadruped: the shoulder and hip joints on the spine, legs leg_z either side; a sitting pose
## pitches the body nose-up about its hips and lowers them.
static func _quad_skeleton(k: Dictionary, pose: String) -> Dictionary:
	var xf := sit_xf(k, pose)
	var sh := _v3(k.shoulder)
	var hip := _v3(k.hip)
	var s: Dictionary = k.get("sockets", {})
	var seat_x: float = float(s.get("seat_x", lerpf(hip.x, sh.x, 0.4)))
	var seat := _v3(s.seat) if s.has("seat") else Vector3(seat_x, top_at(k, seat_x) + float(k.get("tack", {}).get("saddle", 1.0)), 0)
	var mid_y := (top_at(k, seat.x) + bottom_at(k, seat.x)) * 0.5
	var half := half_width_at(k, seat.x) + 0.4
	var hr: Array = s.get("hand", [3.0, mid_y - seat.y])
	var hz: float = float(hr[2]) if hr.size() > 2 else half
	var sockets := {
		"head": _v3(k.neck.to) + head_lift(k, pose),
		"seat": seat,
		"girth": _v3(s.girth) if s.has("girth") else Vector3(seat.x, bottom_at(k, seat.x) + 1.0, 0),
		"hand_r": seat + Vector3(float(hr[0]), float(hr[1]), hz),
		"hand_l": seat + Vector3(float(hr[0]) - 1.0, float(hr[1]), -hz),
		"torso": _v3(s.torso) if s.has("torso") else Vector3(0, seat.y - 5.0, 0),
		"back": _v3(s.back) if s.has("back") else seat + Vector3(-7, -1.5, 0),
		"wings": _v3(s.wings) if s.has("wings") else seat + Vector3(7, -1.5, 0),
	}
	for n in sockets:
		sockets[n] = xf * sockets[n]
	# Four beats: near hind, near fore, far hind, far fore (the anchor phases set the footfall order).
	var z := Vector3(0, 0, float(k.leg_z))
	var ph: Array = k.walk.get("phases", [1.5, 0.0, 0.5, 1.0])   # fore near, hind near, fore far, hind far (x PI)
	var anchors := [[xf * (sh + z), PI * float(ph[0]), 1, 0, false], [xf * (hip + z), PI * float(ph[1]), 1, 0, true],
		[xf * (sh - z), PI * float(ph[2]), -1, 0, false], [xf * (hip - z), PI * float(ph[3]), -1, 0, true]]
	return {"sockets": sockets, "anchors": anchors, "xf": xf}


## How far a sitting pose raises the head on its neck (in the body's frame): a mount that carries its
## head low walking lifts it as it sits up (`sit.poses.<pose>.head`, [dx, dy]).
static func head_lift(k: Dictionary, pose: String) -> Vector3:
	var sp: Dictionary = k.get("sit", {}).get("poses", {}).get(pose, {})
	return _v3(sp.get("head", [0.0, 0.0]))


## How a sitting pose places the body: pitched up about the hips and lowered (identity standing).
static func sit_xf(k: Dictionary, pose: String) -> Transform3D:
	var sp: Dictionary = k.get("sit", {}).get("poses", {}).get(pose, {})
	if sp.is_empty():
		return Transform3D.IDENTITY
	var hip := _v3(k.hip)
	var at := Vector3(hip.x, float(sp.hip_y), 0)
	return Transform3D(Basis(Vector3(0, 0, 1), deg_to_rad(float(sp.pitch))), at) * Transform3D(Basis.IDENTITY, -hip)


## Biped: the hips at the pelvis, the torso leaning forward about them by `lean` degrees (the
## torso's volumes, shoulders, neck and head socket are given upright and turned with it).
static func _biped_skeleton(k: Dictionary, pose: String) -> Dictionary:
	var hip := _v3(k.hip)
	var s: Dictionary = k.get("sockets", {})
	var chest: Dictionary = k.body.chest
	var fit := torso_fit(k)
	var sockets := {
		"head": lean(k, _v3(k.neck.to)),
		"hand_r": _v3(k.arm.hand),
		"hand_l": _v3(k.arm.hand_l),
		# The armour's middle (generic armour is built round (1.5, 0.5)) over the chest's.
		"torso": lean(k, _v3(chest.at)) - Basis(Vector3(0, 0, 1), deg_to_rad(-float(k.get("lean", 0.0)))) * Vector3(1.5 * fit.x, 0.5 * fit.y, 0),
		"back": lean(k, _v3(s.back)) if s.has("back") else lean(k, _v3(chest.at) + Vector3(-float(chest.r[0]) - 0.2, 1.5, 0)),
		"sit": hip + Vector3(0, -1.0, 0),
	}
	for n in s:   # more sockets: "drape" (a hero's cape or pelt), or one named for a part ("cape.cloth"): where it hangs clear of a broad back
		if n != "back":
			sockets[n] = lean(k, _v3(s[n]))
	var leg_hip := hip + Vector3(float(k.leg.get("hip_dx", 0.0)), 0, 0)
	var z := Vector3(0, 0, float(k.leg_z))
	var anchors := [[leg_hip - z, 0.0, -1, 0, false], [leg_hip + z, PI, 1, 0, false]]
	return {"sockets": sockets, "anchors": anchors, "xf": Transform3D.IDENTITY}


## A point given upright, turned with the torso's lean about the hips.
static func lean(k: Dictionary, p: Vector3) -> Vector3:
	var hip := _v3(k.hip)
	return hip + Basis(Vector3(0, 0, 1), deg_to_rad(-float(k.get("lean", 0.0)))) * (p - hip)


## Worn armour (built round radii 8.8, 8.2, 10.4) scaled to sit just over the chest.
static func torso_fit(k: Dictionary) -> Vector3:
	var r: Array = k.body.chest.r
	var pad: float = float(k.get("armour_pad", 0.6))
	return Vector3((float(r[0]) + pad) / 8.8, (float(r[1]) + pad) / 8.2, (float(r[2]) + pad) / 10.4)


## The torso's volumes: [centre, radii, material, rotation (deg about z)], upright for a biped.
static func volumes(k: Dictionary) -> Array:
	var out := []
	for name in ["rump", "waist", "belly", "chest", "pelvis", "hump"]:
		if k.body.get(name) != null:
			var v: Dictionary = k.body[name]
			out.append([_v3(v.at), _v3(v.r), v.get("mat", "fur"), float(v.get("rot", 0.0)), name])
	return out


## The top, bottom and half-width of the body's volumes at x (standing, unscaled).
static func top_at(k: Dictionary, x: float) -> float:
	var y := -INF
	for v in volumes(k):
		var u: float = (x - v[0].x) / v[1].x
		if absf(u) < 1.0:
			y = maxf(y, v[0].y + v[1].y * sqrt(1.0 - u * u))
	return y


static func bottom_at(k: Dictionary, x: float) -> float:
	var y := INF
	for v in volumes(k):
		var u: float = (x - v[0].x) / v[1].x
		if absf(u) < 1.0:
			y = minf(y, v[0].y - v[1].y * sqrt(1.0 - u * u))
	return y


static func half_width_at(k: Dictionary, x: float) -> float:
	var w := 0.0
	for v in volumes(k):
		var u: float = (x - v[0].x) / v[1].x
		if absf(u) < 1.0:
			w = maxf(w, v[1].z * sqrt(1.0 - u * u))
	return w


# ------------------------------------------------------------------ legs

## Where a leg's joints are in a pose (the hip or shoulder at the origin, up +y, part units).
static func leg_joints(k: Dictionary, role: String, pose: String) -> Dictionary:
	return _quad_joints(k, role == "hind", pose) if quad(k) else _biped_joints(k, pose)


## A step's place in the walk: [i, n] from "w<i>_<n>", or [] for a pose that isn't a step.
static func _step(pose: String) -> Array:
	if not pose.begins_with("w") or not "_" in pose:
		return []
	var nums := pose.substr(1).split("_")
	return [int(nums[0]), int(nums[1])]


## Four legs (generalises the cat's, D-124): the paw moves back along the ground while it's down
## (`stance` of the cycle) and lifts forward, curled, the rest; the lower bone (hind: metatarsus to
## the hock; fore: pastern to the wrist) leans by `tilt` (degrees from upright: a digitigrade hock
## stands high, a plantigrade sole lies nearly flat), and the upper two bones follow by IK, the knee
## bending forward and the elbow back.
static func _quad_joints(k: Dictionary, hind: bool, pose: String) -> Dictionary:
	var L: Dictionary = k.hind if hind else k.fore
	var b: Array = L.bones
	var w: Dictionary = k.walk
	var pad := float(k.get("pad", 0.75))
	var h: float = float(k.hip[1]) if hind else float(k.shoulder[1])
	var x0 := float(L.x)
	var x := x0
	var tilt := float(L.tilt)
	var lift := 0.0
	var down := 0.0
	var st := _step(pose)
	var sit: Dictionary = k.get("sit", {}).get("poses", {}).get(pose, {})
	if not st.is_empty():
		var p := float(st[0]) / float(st[1])
		var stance := float(w.stance)
		var wt: Array = L.walk_tilt
		if p < stance:
			var s := p / stance
			x = x0 + float(w.stride) * (0.5 - s)
			tilt = lerpf(float(wt[0]), float(wt[1]), s)
			down = sin(s * PI)
		else:
			var q := (p - stance) / (1.0 - stance)
			x = x0 + float(w.stride) * (smoothstep(0.0, 1.0, q) - 0.5)
			lift = float(w.lift) * sin(q * PI)
			tilt = lerpf(float(wt[1]), float(wt[0]), q) + float(L.swing_tilt) * sin(q * PI)
	elif not sit.is_empty():
		var xf := sit_xf(k, pose)
		h = float(sit.hip_y) if hind else (xf * _v3(k.shoulder)).y
		if hind:
			if sit.has("fold"):   # folded flat: the hock on the ground, the paw forward under the knee
				var f: Dictionary = sit.fold
				var hk := Vector2(float(f.hock[0]), -h + float(f.hock[1]))
				var pw := Vector2(float(f.paw), -h + pad)
				return {"hock": hk, "paw": pw, "knee": _ik(Vector2.ZERO, hk, float(b[0]), float(b[1]), 1.0), "toe": Vector2.RIGHT, "out": float(f.out)}
			x = float(sit.hind[0])
			tilt = float(sit.hind[1])
		else:
			x = float(k.sit.fore[0])
			tilt = float(k.sit.fore[1])
	var paw := Vector2(x, -h + pad + lift)
	var r := deg_to_rad(tilt)
	if hind:
		var hock := paw + Vector2(-sin(r), cos(r)) * float(b[2])
		var reach: float = float(b[0]) + float(b[1]) - 0.05
		if hock.length() > reach:   # out of reach: the paw comes up off the ground a little
			var fix := hock.normalized() * reach - hock
			hock += fix
			paw += fix
		return {"hock": hock, "paw": paw, "knee": _ik(Vector2.ZERO, hock, float(b[0]), float(b[1]), 1.0),
			"toe": Vector2(cos(r * 0.5), -sin(r * 0.5)) if lift > 0.0 else Vector2.RIGHT}
	var wrist := paw + Vector2(sin(r), cos(r)) * float(b[2])
	var reach2: float = float(b[0]) + float(b[1]) - 0.05
	if wrist.length() > reach2:
		var fix2 := wrist.normalized() * reach2 - wrist
		wrist += fix2
		paw += fix2
	var scap0 := _p2(L.get("scapula", [-1.4, 5.6]))
	var scap := scap0 + Vector2(-0.25 * (x - x0), 0.9 * down)
	if not sit.is_empty():
		scap = (scap0 * 0.8).rotated(deg_to_rad(float(sit.pitch)) * 0.6)   # settled
	var toe := Vector2.RIGHT
	if lift > 0.0:   # a lifted paw curls back under the wrist
		toe = (paw - wrist).normalized().rotated(PI * 0.5)
		if toe.x < -0.2:
			toe = Vector2.RIGHT
	return {"wrist": wrist, "paw": paw, "elbow": _ik(Vector2.ZERO, wrist, float(b[0]), float(b[1]), -1.0), "scapula": scap, "toe": toe}


## Two legs: the foot flat on the ground under the hip (plantigrade), moved back along the ground
## while it's down, the heel rising onto the toes at the end of the stance (toe-off), then lifted
## forward; the knee bends forward by IK. Idle poses move the foot (`idle`: forward, out to its side).
static func _biped_joints(k: Dictionary, pose: String) -> Dictionary:
	var L: Dictionary = k.leg
	var w: Dictionary = k.walk
	var h := float(k.hip[1])
	var pad := float(k.get("pad", 0.8))
	var foot := float(L.foot)
	var heel_back := float(L.heel)
	var ankle_h := float(L.ankle)
	var x := float(L.x)
	var lift := 0.0
	var pitch := 0.0   # degrees the heel is up, about the toe
	var out := 0.0
	var st := _step(pose)
	if not st.is_empty():
		var p := float(st[0]) / float(st[1])
		var stance := float(w.stance)
		var toe_off := float(w.get("toe_off", 25.0))
		if p < stance:
			var s := p / stance
			x += float(w.stride) * (0.5 - s)
			pitch = toe_off * clampf((s - 0.65) / 0.35, 0.0, 1.0)
		else:
			var q := (p - stance) / (1.0 - stance)
			x += float(w.stride) * (smoothstep(0.0, 1.0, q) - 0.5)
			lift = float(w.lift) * sin(q * PI)
			pitch = toe_off * pow(1.0 - q, 2.0)
	elif k.get("idle", {}).has(pose):
		var ip: Dictionary = k.idle[pose]
		x += float(ip.get("forward", 0.0))
		out = float(ip.get("out", 0.0))
		pitch = float(ip.get("pitch", 0.0))
	var toe := Vector2(x - heel_back + foot, -h + pad + lift)
	var r := deg_to_rad(pitch)
	var heel := toe + Vector2(-foot * cos(r), foot * sin(r))
	var ankle := heel + Vector2(heel_back, ankle_h - pad).rotated(-r)
	var thigh := float(L.bones[0])
	var shin := float(L.bones[1])
	var reach := thigh + shin - 0.05
	if ankle.length() > reach:   # out of reach: the foot comes up a little
		var fix := ankle.normalized() * reach - ankle
		ankle += fix
		heel += fix
		toe += fix
	return {"knee": _ik(Vector2.ZERO, ankle, thigh, shin, 1.0), "ankle": ankle, "heel": heel, "toe": toe, "out": out}


## Two-bone IK in a plane: the middle joint for bones l1, l2 from a to b, bending to `side`
## (+1: forward of the line from a to b when it points down; -1: behind it).
static func _ik(a: Vector2, b: Vector2, l1: float, l2: float, side: float) -> Vector2:
	var d := b - a
	var l := clampf(d.length(), 0.01, l1 + l2 - 0.01)
	var u := d.normalized()
	var along := (l1 * l1 - l2 * l2 + l * l) / (2.0 * l)
	var hh := sqrt(maxf(0.0, l1 * l1 - along * along))
	return a + u * along + Vector2(-u.y, u.x) * hh * side


# ------------------------------------------------------------------ models

## The model for a kit part ("body.bear", "leg.bear", "head.bear"); m is the UnitModels building it
## (its primitives and materials; m.hold is the body's hold or pose, or a leg's pose; m.rest the pose
## a body holding a weapon rests in, "body.bear@draw@ease").
func build(m, id: String, colours: Dictionary) -> Dictionary:
	var kr: Array = part_kit[id]
	var k: Dictionary = kits[kr[0]]
	var pose: String = m.rest if m.rest != "" else ("" if m.hold == "low" else m.hold)
	var spec: Dictionary
	match kr[1]:
		"body":
			spec = _quad_body(m, k, colours, pose if pose in idle(k) else "") if quad(k) else _biped_body(m, k, colours, pose if pose in idle(k) else "")
		"head":
			spec = _head(m, k, colours)
		_:
			spec = _quad_leg(m, k, colours, kr[1] == "hind", pose) if quad(k) else _biped_leg(m, k, colours, pose)
	if spec.has("seam_r"):
		spec.seam_r *= float(k.get("scale", 1.0))
	return m._scaled(spec, float(k.get("scale", 1.0)))


func _coat(m, k: Dictionary, c: Dictionary) -> Dictionary:
	var tex: String = k.get("fur", "hide")
	var units := float(k.get("fur_units", 4.0))
	var pale: Color = c.get("skin3", c.skin.lightened(0.35))
	return {"fur": m.surf(tex, c.skin, units), "dark": m.surf(tex, c.skin2, units), "stripe": m.surf(tex, c.skin2, units),
		"pale": m.surf(tex, pale, units), "sock": m.surf(tex, c.get("skin4", c.skin), units),
		"pad": m.plain(Color(k.get("pad_colour", "#2a2020"))), "claw": m.plain(Color(k.get("claw_colour", "#e8e0cc"))),
		"nose": m.plain(Color(k.get("head", {}).get("nose", {}).get("colour", "#1c1614"))),
		"eye": m.plain(INK), "iris": m.plain(Color(k.get("head", {}).get("eyes", {}).get("iris", "#3a2412"))),
		"ear_in": m.plain(Color(k.get("head", {}).get("ears", {}).get("inner", "#3a2a24")))}


## The torso's volumes as blobs (or the modelled mesh named in `body.mesh`, lowered by `body.drop`).
func _torso(m, k: Dictionary, mats: Dictionary, into: Node3D, turn: Callable, lift := Vector3.ZERO, pose_basis := Basis.IDENTITY) -> void:
	if k.body.get("mesh") != null:
		var low := Node3D.new()
		low.position.y = -float(k.body.get("drop", 0.0))
		low.add_child(m.glb(k.body.mesh, mats))
		into.add_child(low)
		return
	for v in volumes(k):
		var at: Vector3 = turn.call(v[0])
		into.add_child(m.blob(v[1], mats[v[2]], at, Vector3(0, 0, v[3] - float(k.get("lean", 0.0)) * (0.0 if quad(k) else 1.0))))
	for patch in k.body.get("patches", []):   # markings: a pale chest crescent, a belly
		into.add_child(m.blob(_v3(patch.r), mats[patch.get("mat", "pale")], turn.call(_v3(patch.at)), Vector3(0, 0, float(patch.get("rot", 0.0)))))
	if k.has("neck"):
		var nk: Dictionary = k.neck
		into.add_child(m.rod(turn.call(_v3(nk.from)), neck_end(k, lift, pose_basis), float(nk.r[0]), float(nk.r[1]), mats.fur))


## Where the neck ends (the body's frame, before the pose turns it). A neck that runs into the head
## (`neck.into`: a point in the head's frame, in the back of the skull) ends there, wherever the head
## sits and however it's pitched, so the neck is one mass from the withers into the skull and the
## head (cut by the body) shows only in front of it: no notch at the join (Dominic on the bear
## mount, B2: "mounted bears I think have broken neck still"). Otherwise it ends just under the head
## socket.
static func neck_end(k: Dictionary, lift := Vector3.ZERO, pose_basis := Basis.IDENTITY) -> Vector3:
	var nk: Dictionary = k.neck
	var at := _v3(nk.to) + lift
	if nk.get("into") == null:
		return at + Vector3(-0.4, -0.6, 0)
	var h: Dictionary = k.get("head", {})
	var local := Basis(Vector3(0, 0, 1), deg_to_rad(float(h.get("tilt", 0.0)))) * (_v3(nk.into) * float(h.get("k", 1.0)))
	return at + pose_basis.inverse() * local


func _tail(m, k: Dictionary, mats: Dictionary, into: Node3D, xf: Transform3D, pose: String) -> void:
	if not k.has("tail"):
		return
	var t: Dictionary = k.tail
	if t.has("stub"):
		into.add_child(m.blob(_v3(t.stub.r), mats.fur, xf * _v3(t.stub.at)))
		return
	var r: Array = t.r
	var dark: Material = mats.stripe if t.get("rings", false) else mats.fur
	var sit: Dictionary = k.get("sit", {}).get("poses", {}).get(pose, {})
	var root := _v3(t.get("sit_root", t.pts[0]))
	if not sit.is_empty() and sit.has("fold"):
		# Sitting: the tail drops straight to the ground and comes forward round the near side, its tip
		# over the forepaws.
		var b := xf * root
		var paw := (xf * _v3(k.shoulder)).x + 0.9
		m._cat_tail(into, [b, Vector3(b.x + 0.5, 1.1, 1.8), Vector3(b.x + 1.6, 1.0, 3.4), Vector3(b.x + 3.4, 1.0, 4.8),
			Vector3(paw - 6.5, 1.0, 5.2), Vector3(paw - 3.0, 1.1, 4.9), Vector3(paw - 1.2, 2.0, 4.3)],
			float(r[0]) * 0.85, float(r[1]) * 0.85, mats.fur, dark)
	elif not sit.is_empty():
		# On the way down: out behind and down to the ground, the tip resting on it.
		var b := xf * (root + Vector3(0, 0.4, 0))
		m._cat_tail(into, [b, b + Vector3(-2.8, -0.9, 0.2), Vector3(b.x - 4.8, maxf(2.6, b.y - 3.6), 0.5),
			Vector3(b.x - 5.6, 1.2, 0.9), Vector3(b.x - 4.6, 1.0, 1.6)], float(r[0]), float(r[1]), mats.fur, dark)
	else:
		var pts := []
		for p in t.pts:
			pts.append(xf * _v3(p))
		m._cat_tail(into, pts, float(r[0]), float(r[1]), mats.fur, dark)


func _quad_body(m, k: Dictionary, c: Dictionary, pose: String) -> Dictionary:
	var sk := skeleton(k, pose)
	var xf: Transform3D = sk.xf
	var n := Node3D.new()
	var inner := Node3D.new()
	inner.transform = xf
	n.add_child(inner)
	var mats := _coat(m, k, c)
	_torso(m, k, mats, inner, func(p): return p, head_lift(k, pose), xf.basis)
	_tail(m, k, mats, n if pose != "" else inner, xf if pose != "" else Transform3D.IDENTITY, pose)
	var tack: Dictionary = k.get("tack", {})
	if tack.has("cloth"):
		var seat: Vector3 = skeleton(k, "").sockets.seat
		var cl: Dictionary = tack.cloth
		var girth := _v3(cl.girth) if cl.has("girth") else Vector3(seat.x + 4.6, (top_at(k, seat.x) + bottom_at(k, seat.x)) * 0.5, 0)
		var half := half_width_at(k, seat.x)
		m._cat_saddle(inner, c, seat.x, seat.y - float(cl.get("below", 1.4)), float(cl.get("half", half * 0.85)), girth,
			float(cl.get("ry", (top_at(k, girth.x) - bottom_at(k, girth.x)) * 0.5 + 0.2)), float(cl.get("rz", half_width_at(k, girth.x) + 0.2)),
			float(cl.get("length", 6.0)), float(cl.get("drop", 2.6)))
	var spec := {"node": n, "sockets": sk.sockets, "anchors": sk.anchors, "torso_scale": Vector2(1.3, 1.0), "carry": "harness"}
	if k.has("head") and k.neck.get("into") != null:
		spec.seam_head = k.parts.head   # (the bake holds the head out of the body: no line at the join)
		spec.sockets.join = xf * neck_end(k, head_lift(k, pose), xf.basis)
		spec.seam_r = float(k.neck.r[1]) * 1.6   # (scaled with the kit in build())
	return spec


func _biped_body(m, k: Dictionary, c: Dictionary, pose: String) -> Dictionary:
	var sk := skeleton(k, pose)
	var n := Node3D.new()
	var mats := _coat(m, k, c)
	_torso(m, k, mats, n, func(p): return lean(k, p))
	_tail(m, k, mats, n, Transform3D.IDENTITY, pose)
	var a: Dictionary = k.arm
	var head: Vector3 = sk.sockets.head
	var near_hand := Vector3.ZERO
	var front := Node3D.new()
	for side in [1, -1]:
		var into: Node3D = front if side == 1 else n
		var sh := lean(k, _v3(a.shoulder) * Vector3(1, 1, side))
		var elbow := sh + _v3(a.elbow) * Vector3(1, 1, side)
		var hand := _v3(a.hand) if side == 1 else _v3(a.hand_l)
		if side == 1:
			var p: Array = m.arm_pose(sh, elbow, hand, head)
			elbow = p[0]
			hand = p[1]
			near_hand = hand
		into.add_child(m.blob(Vector3.ONE * float(a.r[0][0]) * 1.05, mats.fur, sh))
		into.add_child(m.rod(sh, elbow, float(a.r[0][0]), float(a.r[0][1]), mats.fur))
		into.add_child(m.rod(elbow, hand, float(a.r[1][0]), float(a.r[1][1]), mats.fur))
		into.add_child(m.blob(_v3(a.paw), mats.dark if a.get("dark_paws", true) else mats.fur, hand))
	sk.sockets.hand_r = near_hand   # (posed for the hold: what the hand holds is built round its grip there)
	if k.get("kerchief", false):
		m.kerchief(front, c, lean(k, _v3(k.neck.from)) + Vector3(0.6, 0.4, 0), float(k.neck.r[0]) * 0.95, float(k.get("lean", 0.0)))
	return {"node": n, "front": front, "sockets": sk.sockets, "anchors": sk.anchors,
		"torso_scale": Vector2(0.9, 1.1), "torso_fit": torso_fit(k), "torso_tilt": -float(k.get("lean", 0.0)), "legs_under": false}


## A leg of four, posed (see _quad_joints): hind is thigh, shin, metatarsus and paw; fore the
## shoulder blade, upper arm, forearm, pastern and paw.
func _quad_leg(m, k: Dictionary, c: Dictionary, hind: bool, pose: String) -> Dictionary:
	var j := _quad_joints(k, hind, pose)
	var L: Dictionary = k.hind if hind else k.fore
	var mats := _coat(m, k, c)
	var r: Array = L.r
	var ms: Array = L.get("mats", ["fur", "fur", "fur", "fur", "fur"])
	var n := Node3D.new()
	var out := Vector3(0, 0, float(j.get("out", 0.0)))
	if hind:
		var top := _v3(L.get("thigh_top", [0.3, 1.6]))
		n.add_child(m.rod(top, _v3([j.knee.x, j.knee.y]) + out * 0.5, float(r[0][0]), float(r[0][1]), mats[ms[0]]))
		n.add_child(m.rod(_v3([j.knee.x, j.knee.y]) + out * 0.5, _v3([j.hock.x, j.hock.y]) + out, float(r[1][0]), float(r[1][1]), mats[ms[1]]))
		n.add_child(m.rod(_v3([j.hock.x, j.hock.y]) + out, _v3([j.paw.x, j.paw.y]) + out, float(r[2][0]), float(r[2][1]), mats[ms[2]]))
	else:
		n.add_child(m.rod(Vector3.ZERO, _v3([j.scapula.x, j.scapula.y]), float(r[0][0]), float(r[0][1]), mats[ms[0]]))
		n.add_child(m.rod(Vector3.ZERO, _v3([j.elbow.x, j.elbow.y]), float(r[1][0]), float(r[1][1]), mats[ms[1]]))
		n.add_child(m.rod(_v3([j.elbow.x, j.elbow.y]), _v3([j.wrist.x, j.wrist.y]), float(r[2][0]), float(r[2][1]), mats[ms[2]]))
		n.add_child(m.rod(_v3([j.wrist.x, j.wrist.y]), _v3([j.paw.x, j.paw.y]), float(r[3][0]), float(r[3][1]), mats[ms[3]]))
	var toe: Vector2 = j.toe
	var paw_out := out if hind else Vector3.ZERO
	var at := _v3([j.paw.x + toe.x * 0.45, j.paw.y + toe.y * 0.45]) + paw_out
	n.add_child(m.blob(_v3(L.paw), mats[L.get("paw_mat", "pale")], at, Vector3(0, 0, rad_to_deg(toe.angle()))))
	if L.get("claws", false):
		var ps: Vector3 = _v3(L.paw)
		for t in [-1, 0, 1]:
			n.add_child(m.blob(Vector3(0.45, 0.28, 0.3), mats.claw, at + Vector3(toe.x * ps.x * 0.95, toe.y * ps.x * 0.95 - ps.y * 0.6, t * ps.z * 0.55)))
	return {"node": n}


## A leg of two: thigh, shin, a long flat foot with dark pads and pale claws.
func _biped_leg(m, k: Dictionary, c: Dictionary, pose: String) -> Dictionary:
	var j := _biped_joints(k, pose)
	var L: Dictionary = k.leg
	var mats := _coat(m, k, c)
	var r: Array = L.r
	var n := Node3D.new()
	var out := Vector3(0, 0, float(j.out))
	var knee := _v3([j.knee.x, j.knee.y]) + out * 0.5
	var ankle := _v3([j.ankle.x, j.ankle.y]) + out
	var heel := _v3([j.heel.x, j.heel.y]) + out
	var toe := _v3([j.toe.x, j.toe.y]) + out
	n.add_child(m.rod(_v3(L.get("thigh_top", [0.2, 0.8])), knee, float(r[0][0]), float(r[0][1]), mats.fur))
	n.add_child(m.rod(knee, ankle, float(r[1][0]), float(r[1][1]), mats.fur))
	var mid := (heel + toe) * 0.5 + Vector3(0, float(L.get("foot_h", 0.5)), 0)
	var d := toe - heel
	n.add_child(m.blob(Vector3(d.length() * 0.55, float(L.get("foot_r", [1.0, 1.5])[0]), float(L.get("foot_r", [1.0, 1.5])[1])), mats.fur, mid,
		Vector3(0, 0, rad_to_deg(atan2(d.y, d.x)))))
	n.add_child(m.rod(ankle, mid, float(r[1][1]), float(L.get("foot_r", [1.0, 1.5])[0]), mats.fur))
	for t in [-1, 0, 1]:
		var tip := toe + Vector3(0.2, 0.1, t * float(L.get("foot_r", [1.0, 1.5])[1]) * 0.55)
		n.add_child(m.blob(Vector3(0.45, 0.3, 0.32), mats.claw, tip + Vector3(0.35, -0.05, 0)))
	return {"node": n}


## The head on its socket: skull, cheeks, muzzle (a dished face has a stop, the forehead's step down
## to the muzzle), nose, eyes under a brow, ears; a mount's bridle. Built facing +x from the neck.
func _head(m, k: Dictionary, c: Dictionary) -> Dictionary:
	var h: Dictionary = k.head
	var mats := _coat(m, k, c)
	var root := Node3D.new()
	var hk := float(h.get("k", 1.0))
	var tilt := float(h.get("tilt", 0.0))
	if h.get("mesh") != null:
		var g: Node3D = m.glb(h.mesh, mats)
		g.rotation_degrees.z = tilt
		g.scale = Vector3.ONE * hk
		root.add_child(g)
	else:
		var n := Node3D.new()
		n.rotation_degrees.z = tilt
		n.scale = Vector3.ONE * hk
		root.add_child(n)
		var sk: Dictionary = h.skull
		var sc := _v3(sk.at)
		var sr := _v3(sk.r)
		n.add_child(m.blob(sr, mats.fur, sc))
		if h.get("cheeks") != null:
			n.add_child(m.blob(_v3(h.cheeks.r), mats[h.cheeks.get("mat", "fur")], _v3(h.cheeks.at)))
		if h.get("stop") != null:
			n.add_child(m.blob(_v3(h.stop.r), mats.fur, _v3(h.stop.at)))
		var mz: Dictionary = h.muzzle
		var tip := _v3(mz.to)
		n.add_child(m.rod(_v3(mz.from), tip, float(mz.r[0]), float(mz.r[1]), mats[mz.get("mat", "fur")]))
		if mz.get("bridge") != null:   # a roman nose: the muzzle's top arched
			n.add_child(m.blob(_v3(mz.bridge.r), mats[mz.get("mat", "fur")], _v3(mz.bridge.at)))
		if h.has("nose"):
			n.add_child(m.blob(_v3(h.nose.r), mats.nose, tip + _v3(h.nose.get("at", [float(mz.r[1]) * 0.55, float(mz.r[1]) * 0.35]))))
		var mouth := tip + Vector3(-float(mz.r[1]) * 0.2, -float(mz.r[1]) * 0.75, 0)
		n.add_child(m.rod(mouth + Vector3(-1.6, 0.1, 0), mouth, 0.18, 0.15, mats.eye, false))
		if h.has("eyes"):
			var e: Dictionary = h.eyes
			for side in [1, -1]:
				var look := _v3(e.look) * Vector3(1, 1, side)
				var at: Vector3 = m.on_surface(sc, sr, look, -0.15)
				var eye: MeshInstance3D = m.blob(Vector3.ONE * float(e.r), mats.eye, at)
				eye.mesh.resource_name = "eye"   # (the placement check finds eyes by name)
				n.add_child(eye)
				if e.has("iris"):
					n.add_child(m.blob(Vector3(0.35, 0.45, 0.35) * float(e.r) / 0.55, mats.iris, at + look.normalized() * float(e.r) * 0.6))
				if h.has("brow"):
					var brow: MeshInstance3D = m.blob(_v3(h.brow.r), mats.fur, at + _v3(h.brow.at) * Vector3(1, 1, side))
					brow.mesh.resource_name = "brow"
					n.add_child(brow)
		if h.has("ears"):
			var ea: Dictionary = h.ears
			for side in [1, -1]:
				var at := _v3(ea.at) * Vector3(1, 1, side)
				var size := _v3(ea.size)
				if ea.get("shape", "round") == "point":
					n.add_child(m.cone(0.0, size.x, size.y, mats.fur, at, Vector3(-12 * side, 0, float(ea.get("lean", 8.0)))))
					n.add_child(m.cone(0.0, size.x * 0.6, size.y * 0.75, mats.ear_in, at + Vector3(0.25, -0.1, 0.15 * side), Vector3(-12 * side, 0, float(ea.get("lean", 8.0)))))
				else:
					n.add_child(m.blob(size, mats.fur, at, Vector3(0, 0, float(ea.get("lean", -10.0)))))
					n.add_child(m.blob(size * Vector3(0.5, 0.62, 0.62), mats.ear_in, at + Vector3(0.45, -0.1, 0.12 * side), Vector3(0, 0, float(ea.get("lean", -10.0)))))
	if h.has("whiskers"):   # out from the muzzle pads
		var wn := Node3D.new()
		wn.rotation_degrees.z = tilt
		wn.scale = Vector3.ONE * hk
		root.add_child(wn)
		var white: Material = m.plain(Color(c.get("skin3", Color("#e8e2d6"))).lightened(0.3))
		for s in [1, -1]:
			for w in [-0.5, 0.0, 0.5]:
				var a := _v3(h.whiskers) + Vector3(0, w * 0.5, 1.2 * s)
				wn.add_child(m.rod(a, a + Vector3(1.2, w, 2.4 * s), 0.09, 0.06, white, false))
	if h.has("bridle"):
		var b: Dictionary = h.bridle
		m._cat_bridle(root, c, _v3(b.snout) * hk, float(b.snout_r) * hk, _v3(b.crown) * hk, float(b.crown_r) * hk, tilt)
	var spec := {"node": root, "sockets": {"top": _v3(h.top) * hk}}
	if h.has("gear_scale"):
		spec.gear_scale = float(h.gear_scale) * hk   # (the gear frame grows with the head)
	return spec
