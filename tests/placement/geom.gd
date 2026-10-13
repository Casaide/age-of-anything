extends RefCounted
## Geometry of a posed 3D model, headless (no rendering): its solid voxels on a fixed grid and its
## vertices in world space. Used by the placement check (tests/placement_check.gd) to measure ground
## contact, attachment and interpenetration. Primitive meshes (spheres, cylinders and cones, boxes,
## tori) are filled exactly by an inside test at each voxel centre; any other mesh (a .glb, an
## extruded slab) by ray parity along y, column by column (an open mesh marks only its crossings).
## Decals (quads, planes) are left out: they are pictures on a surface, not volume.

const RES := 0.5   # part units per voxel edge
const BIAS := 2048


static func key(i: int, j: int, k: int) -> int:
	return (i + BIAS) | ((j + BIAS) << 12) | ((k + BIAS) << 24)


static func unkey(q: int) -> Vector3i:
	return Vector3i((q & 4095) - BIAS, ((q >> 12) & 4095) - BIAS, ((q >> 24) & 4095) - BIAS)


## The centre of a voxel in part units.
static func centre(q: int) -> Vector3:
	var v := unkey(q)
	return (Vector3(v) + Vector3.ONE * 0.5) * RES


static func cell(p: Vector3) -> int:
	return key(floori(p.x / RES), floori(p.y / RES), floori(p.z / RES))


## Every MeshInstance3D under n with its transform relative to n's parent space, times xf.
static func meshes(n: Node3D, xf := Transform3D.IDENTITY) -> Array:
	var out := []
	_meshes(n, xf * n.transform, out)
	return out


static func _meshes(n: Node, t: Transform3D, out: Array) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null and (n as Node3D).visible:
		var m: Mesh = (n as MeshInstance3D).mesh
		if not (m is QuadMesh or m is PlaneMesh):
			out.append([m, t])
	for c in n.get_children():
		if c is Node3D:
			_meshes(c, t * (c as Node3D).transform, out)


static var _arrays := {}


## A mesh surface's arrays, read once per shape: a primitive's from its parameters (generated on the
## CPU), a modelled mesh's by resource (reading them back from the renderer is slow with a window).
static func arrays(m: Mesh, s: int) -> Array:
	var k: Variant = [m, s]
	if m is PrimitiveMesh:
		var props := [m.get_class()]
		for name in ["radius", "height", "radial_segments", "rings", "is_hemisphere", "top_radius", "bottom_radius", "size",
				"inner_radius", "outer_radius", "ring_segments", "cap_top", "cap_bottom", "subdivide_width", "subdivide_height", "subdivide_depth"]:
			props.append(m.get(name))
		k = var_to_str(props)
	if not _arrays.has(k):
		_arrays[k] = (m as PrimitiveMesh).get_mesh_arrays() if m is PrimitiveMesh else m.surface_get_arrays(s)
	return _arrays[k]


## The solid voxels of a model placed by xf: {key: true}.
static func voxels(n: Node3D, xf := Transform3D.IDENTITY) -> Dictionary:
	var out := {}
	for mt in meshes(n, xf):
		_fill(mt[0], mt[1], out)
	return out


## The world-space vertices of a model placed by xf.
static func vertices(n: Node3D, xf := Transform3D.IDENTITY) -> PackedVector3Array:
	var out := PackedVector3Array()
	for mt in meshes(n, xf):
		var m: Mesh = mt[0]
		var t: Transform3D = mt[1]
		for s in m.get_surface_count():
			var vs: PackedVector3Array = arrays(m, s)[Mesh.ARRAY_VERTEX]
			for v in vs:
				out.append(t * v)
	return out


static func _fill(m: Mesh, t: Transform3D, out: Dictionary) -> void:
	if t.basis.determinant() == 0.0:
		return
	var box: AABB = t * m.get_aabb()
	var inv := t.affine_inverse()
	var lo := Vector3i(floori(box.position.x / RES), floori(box.position.y / RES), floori(box.position.z / RES))
	var hi := Vector3i(floori(box.end.x / RES), floori(box.end.y / RES), floori(box.end.z / RES))
	if m is SphereMesh:
		var a: AABB = m.get_aabb()
		var c := a.get_center()
		var r := a.size * 0.5
		var base := -INF
		if (m as SphereMesh).is_hemisphere:
			c.y = a.position.y
			r.y = a.size.y
			base = a.position.y
		_scan(lo, hi, inv, out, func(p: Vector3) -> bool:
			var d := (p - c) / r
			return p.y >= base and d.length_squared() <= 1.0)
	elif m is CylinderMesh:
		var cm := m as CylinderMesh
		var h := cm.height * 0.5
		_scan(lo, hi, inv, out, func(p: Vector3) -> bool:
			if absf(p.y) > h:
				return false
			var rr := lerpf(cm.bottom_radius, cm.top_radius, (p.y + h) / (2.0 * h))
			return p.x * p.x + p.z * p.z <= rr * rr)
	elif m is BoxMesh:
		var s := (m as BoxMesh).size * 0.5
		_scan(lo, hi, inv, out, func(p: Vector3) -> bool:
			return absf(p.x) <= s.x and absf(p.y) <= s.y and absf(p.z) <= s.z)
	elif m is TorusMesh:
		var tm := m as TorusMesh
		var big := (tm.inner_radius + tm.outer_radius) * 0.5
		var small := (tm.outer_radius - tm.inner_radius) * 0.5
		_scan(lo, hi, inv, out, func(p: Vector3) -> bool:
			var q := sqrt(p.x * p.x + p.z * p.z) - big
			return q * q + p.y * p.y <= small * small)
	else:
		_parity(m, t, out)


static func _scan(lo: Vector3i, hi: Vector3i, inv: Transform3D, out: Dictionary, inside: Callable) -> void:
	for i in range(lo.x, hi.x + 1):
		for j in range(lo.y, hi.y + 1):
			for k in range(lo.z, hi.z + 1):
				var p := inv * ((Vector3(i, j, k) + Vector3.ONE * 0.5) * RES)
				if inside.call(p):
					out[key(i, j, k)] = true


## Ray parity along +y through each voxel column's centre: crossings sorted, filled in pairs. The
## crossings of all a mesh's surfaces count together: a modelled object painted in several materials
## (a cat's tabby coat) comes as one surface per material, none of them closed on its own.
static func _parity(m: Mesh, t: Transform3D, out: Dictionary) -> void:
	var cols := {}   # column key -> PackedFloat32Array of y crossings (in voxel units)
	for s in m.get_surface_count():
		var arr: Array = arrays(m, s)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var w := PackedVector3Array()
		w.resize(vs.size())
		for i in vs.size():
			w[i] = t * vs[i] / RES
		var tri_count := idx.size() / 3 if idx.size() > 0 else vs.size() / 3
		for f in tri_count:
			var a: Vector3 = w[idx[f * 3]] if idx.size() > 0 else w[f * 3]
			var b: Vector3 = w[idx[f * 3 + 1]] if idx.size() > 0 else w[f * 3 + 1]
			var c: Vector3 = w[idx[f * 3 + 2]] if idx.size() > 0 else w[f * 3 + 2]
			var area := (b.x - a.x) * (c.z - a.z) - (c.x - a.x) * (b.z - a.z)
			if absf(area) < 1e-9:
				continue
			var x0 := floori(minf(a.x, minf(b.x, c.x)))
			var x1 := floori(maxf(a.x, maxf(b.x, c.x)))
			var z0 := floori(minf(a.z, minf(b.z, c.z)))
			var z1 := floori(maxf(a.z, maxf(b.z, c.z)))
			for i in range(x0, x1 + 1):
				for k in range(z0, z1 + 1):
					var px := i + 0.5
					var pz := k + 0.5
					var w0 := _edge(b, c, px, pz, area)
					var w1 := _edge(c, a, px, pz, area)
					var w2 := _edge(a, b, px, pz, area)
					if w0 < 0.0 or w1 < 0.0 or w2 < 0.0:
						continue
					# Half-open edges so a column through a shared edge counts once.
					if (w0 == 0.0 and not _top_left(b, c, area)) or (w1 == 0.0 and not _top_left(c, a, area)) or (w2 == 0.0 and not _top_left(a, b, area)):
						continue
					var y := (w0 * a.y + w1 * b.y + w2 * c.y) / absf(area)
					var ck := key(i, 0, k)
					if not cols.has(ck):
						cols[ck] = PackedFloat32Array()
					cols[ck].append(y)
	for ck in cols:
		var ys: PackedFloat32Array = cols[ck]
		ys.sort()
		var v := unkey(ck)
		if ys.size() % 2 == 1:
			for y in ys:
				out[key(v.x, floori(y), v.z)] = true
			continue
		for p in range(0, ys.size(), 2):
			for j in range(floori(ys[p]), floori(ys[p + 1]) + 1):
				if j + 0.5 >= ys[p] - 0.5 and j + 0.5 <= ys[p + 1] + 0.5:
					out[key(v.x, j, v.z)] = true


## Signed area weight of (px, pz) against edge a->b, in the triangle's winding (>= 0 inside).
static func _edge(a: Vector3, b: Vector3, px: float, pz: float, area: float) -> float:
	var e := (b.x - a.x) * (pz - a.z) - (px - a.x) * (b.z - a.z)
	return e if area > 0.0 else -e


static func _top_left(a: Vector3, b: Vector3, area: float) -> bool:
	var dx := b.x - a.x
	var dz := b.z - a.z
	if area < 0.0:
		dx = -dx
		dz = -dz
	return dz < 0.0 or (dz == 0.0 and dx > 0.0)


## How many voxels two sets share.
static func shared(a: Dictionary, b: Dictionary) -> int:
	if a.size() > b.size():
		var t := a
		a = b
		b = t
	var n := 0
	for q in a:
		if b.has(q):
			n += 1
	return n


## The shared voxels themselves.
static func intersect(a: Dictionary, b: Dictionary) -> Array:
	if a.size() > b.size():
		var t := a
		a = b
		b = t
	var out := []
	for q in a:
		if b.has(q):
			out.append(q)
	return out


## Signed distance (part units, voxel accurate) from p to the surface of a voxel set: < 0 inside
## (how deep), > 0 outside (how far). Searched out to `reach`; beyond that returns +-reach.
static func depth(cells: Dictionary, p: Vector3, reach := 8.0) -> float:
	var c := unkey(cell(p))
	var inside := cells.has(cell(p))
	var steps := ceili(reach / RES)
	var best := reach
	for r in range(1, steps + 1):
		if float(r - 1) * RES >= best:
			break
		for i in range(-r, r + 1):
			for j in range(-r, r + 1):
				for k in range(-r, r + 1):
					if maxi(absi(i), maxi(absi(j), absi(k))) != r:
						continue
					if cells.has(key(c.x + i, c.y + j, c.z + k)) != inside:
						best = minf(best, Vector3(i, j, k).length() * RES)
	return -best if inside else best


## The sizes of a voxel set's 6-connected pieces, biggest first.
static func components(cells: Dictionary) -> Array:
	var seen := {}
	var sizes := []
	var steps := [1, -1, 1 << 12, -(1 << 12), 1 << 24, -(1 << 24)]
	for start in cells:
		if seen.has(start):
			continue
		var n := 0
		var todo := [start]
		seen[start] = true
		while not todo.is_empty():
			var q: int = todo.pop_back()
			n += 1
			for d in steps:
				var r: int = q + d
				if cells.has(r) and not seen.has(r):
					seen[r] = true
					todo.append(r)
		sizes.append(n)
	sizes.sort()
	sizes.reverse()
	return sizes


## The world boxes of a model's features named by `word`: meshes whose resource name has it (a
## modelled eye or brow) and decals made from a picture whose name has it (a painted eye).
static func features(n: Node3D, word: String, xf := Transform3D.IDENTITY) -> Array:
	var out := []
	_features(n, xf * n.transform, word, out)
	return out


static func _features(n: Node, t: Transform3D, word: String, out: Array) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var m: Mesh = (n as MeshInstance3D).mesh
		if word in m.resource_name or word in str(n.get_meta("decal", "")):
			out.append(t * m.get_aabb())
	for c in n.get_children():
		if c is Node3D:
			_features(c, t * (c as Node3D).transform, word, out)
