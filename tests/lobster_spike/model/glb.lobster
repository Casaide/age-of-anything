// ------------------------------------------------------------------ parts modelled in Blender (.glb; unit_models.gd glb_file)
// A binary glTF read as Godot imports it: its node tree (translation, rotation, scale or a matrix),
// each mesh's triangles (positions, normals, UVs, indices), each material a plain colour (glTF's linear
// base colour turned to sRGB, as Godot's importer does) unless `mats` names it: then ours (palettes and
// team colours still apply). What the game's .glb files use: no skins, no textures.

class GlbDoc:
    j:JV
    bin:string

let glb_cache = dictionary<string, GlbDoc>(16)

def glb_doc(path:string) -> GlbDoc:
    let known = glb_cache.get(path)
    if known: return known
    let f = read_file(path, true)
    assert f
    let jlen, _a = read_int32_le(f, 12)
    let j = parse_json(f.substring(20, jlen))
    let at = 20 + jlen
    let blen, _b = read_int32_le(f, at)
    let doc = GlbDoc { j, f.substring(at + 8, blen) }
    glb_cache.set(path, doc)
    return doc

def lin_to_srgb(x:float) -> float: return if x < 0.0031308: 12.92 * x else: 1.055 * pow(x, 1.0 / 2.4) - 0.055

// An accessor's numbers, `comps` a vertex (floats; integer indices come back as floats too).
def glb_accessor(doc:GlbDoc, k:int) -> [float]:
    let acc = glist(doc.j, "accessors")[k]
    let view = glist(doc.j, "bufferViews")[gint(acc, "bufferView", 0)]
    let base = gint(view, "byteOffset", 0) + gint(acc, "byteOffset", 0)
    let count = gint(acc, "count", 0)
    let kind = gstr(acc, "type", "SCALAR")
    let comps = if kind == "VEC2": 2 elif kind == "VEC3": 3 elif kind == "VEC4": 4 else: 1
    let ct = gint(acc, "componentType", 5126)
    let size = if ct == 5126 or ct == 5125: 4 elif ct == 5123 or ct == 5122: 2 else: 1
    let stride = gint(view, "byteStride", comps * size)
    let out = []::float
    for(count) i:
        for(comps) c:
            let o = base + i * stride + c * size
            if ct == 5126:
                let v, _n = read_float32_le(doc.bin, o)
                out.push(v)
            elif ct == 5125:
                let v, _n = read_uint32_le(doc.bin, o)
                out.push(float(v))
            elif ct == 5123:
                let v, _n = read_uint16_le(doc.bin, o)
                out.push(float(v))
            else:
                let v, _n = read_uint8_le(doc.bin, o)
                out.push(float(v))
    return out

def glb_material(doc:GlbDoc, k:int, mats:dictionary<string, MMat>) -> MMat:
    if k < 0: return plain(float3_1)
    let m = glist(doc.j, "materials")[k]
    let name = gstr(m, "name", "")
    let ours = mats.get(name)
    if ours: return ours
    let pbr = gobj(m, "pbrMetallicRoughness")
    let f = map(glist(pbr, "baseColorFactor")) v: as_float(v)
    let c = if f.length >= 3: float3 { lin_to_srgb(f[0]), lin_to_srgb(f[1]), lin_to_srgb(f[2]) } else: float3_1
    let out = plain(c)
    let e = map(glist(m, "emissiveFactor")) v: as_float(v)
    if e.length == 3: out.emission = float3 { lin_to_srgb(e[0]), lin_to_srgb(e[1]), lin_to_srgb(e[2]) }
    return out

var glb_vols = 0                 // .glb meshes read so far (a mesh's surfaces are one volume: MNode.vol)

def glb_node(doc:GlbDoc, k:int, mats:dictionary<string, MMat>) -> MNode:
    let jn = glist(doc.j, "nodes")[k]
    let n = mnode()
    let mtx = map(glist(jn, "matrix")) v: as_float(v)
    if mtx.length == 16:
        set_basis(n, Basis { float3 { mtx[0], mtx[1], mtx[2] }, float3 { mtx[4], mtx[5], mtx[6] }, float3 { mtx[8], mtx[9], mtx[10] } })
        n.pos = float3 { mtx[12], mtx[13], mtx[14] }
    else:
        let t = map(glist(jn, "translation")) v: as_float(v)
        let r = map(glist(jn, "rotation")) v: as_float(v)
        let s = map(glist(jn, "scale")) v: as_float(v)
        if t.length == 3: n.pos = float3 { t[0], t[1], t[2] }
        if r.length == 4: set_basis(n, quat_basis(float4 { r[0], r[1], r[2], r[3] }))
        if s.length == 3: n.scl = float3 { s[0], s[1], s[2] }
    if has(jn, "mesh"):
        let jm = glist(doc.j, "meshes")[gint(jn, "mesh", 0)]
        glb_vols++
        for(glist(jm, "primitives")) pr:
            let attrs = gobj(pr, "attributes")
            let mesh = new_mesh()
            let p = glb_accessor(doc, gint(attrs, "POSITION", 0))
            let nr = if has(attrs, "NORMAL"): glb_accessor(doc, gint(attrs, "NORMAL", 0)) else: []
            let uv = if has(attrs, "TEXCOORD_0"): glb_accessor(doc, gint(attrs, "TEXCOORD_0", 0)) else: []
            for(p.length / 3) i:
                add_vertex(mesh, float3 { p[i * 3], p[i * 3 + 1], p[i * 3 + 2] },
                           if nr.length: float3 { nr[i * 3], nr[i * 3 + 1], nr[i * 3 + 2] } else: float3 { 0.0, 1.0, 0.0 },
                           if uv.length: float2 { uv[i * 2], uv[i * 2 + 1] } else: float2_0)
            mesh.idx = if has(pr, "indices"): map(glb_accessor(doc, gint(pr, "indices", 0))) v: int(v) else: map(mesh.p.length) i: i
            let mi = add_child(n, mesh_node(mesh, glb_material(doc, gint(pr, "material", -1), mats)))
            mi.meta = gstr(jm, "name", "")   // (Godot's mesh resource_name: the placement check finds eyes and brows by it)
            mi.vol = glb_vols
    for(glist(jn, "children")) ch: add_child(n, glb_node(doc, as_int(ch), mats))
    return n

// The whole scene of a .glb as a fresh node tree, materials named in `mats` replaced.
def glb_file(path:string, mats:dictionary<string, MMat>) -> MNode:
    let doc = glb_doc(path)
    let root = mnode()
    let scene = glist(doc.j, "scenes")[gint(doc.j, "scene", 0)]
    for(glist(scene, "nodes")) k: add_child(root, glb_node(doc, as_int(k), mats))
    return root

var models_dir = "../../assets/models"
def glb(name:string, mats:dictionary<string, MMat>) -> MNode: return glb_file(models_dir + "/" + name + ".glb", mats)

// A material map from name, material pairs.
def mats_of(pairs:[MMat], names:[string]) -> dictionary<string, MMat>:
    let d = dictionary<string, MMat>(11)
    for(names) n, i: d.set(n, pairs[i])
    return d
