// ------------------------------------------------------------------ a built model as the baker's triangles
// Walks a node tree (model/kit.lobster) down to its meshes, each placed by its transforms, its normals
// by their inverse transpose (as Godot's), its colour the material's (times the mesh's own colours
// when the material asks), its material one of the baker's (one per distinct look, its texture from
// textures/<name>.png: tex_png.gd).

var model_tex_dir = "textures"
let model_mat_at = dictionary<string, int>(64)

def mat_index(m:MMat) -> int:
    let key = "{m.tex}|{m.triplanar}|{m.uv_scale}|{m.uv_offset}|{m.scissor}|{m.unshaded}|{m.emission}"
    let known = model_mat_at.get(key, -1)
    if known >= 0: return known
    var tex:resource<texture>? = nil
    if m.tex != "":
        let file = if find_string(m.tex, "/") >= 0: m.tex + ".png" else: model_tex_dir + "/" + m.tex + ".png"
        tex = bake_tex_cache.get(file)
        if not tex:
            let loaded = gl.load_texture(file)
            assert loaded
            bake_tex_cache.set(file, loaded)
            tex = loaded
    let bm = BakeMat { tex, float2 { m.uv_scale.x, m.uv_scale.y }, float2 { m.uv_offset.x, m.uv_offset.y }, m.triplanar }
    bm.scissor = m.scissor
    bm.unshaded = m.unshaded
    bm.emission = m.emission
    bake_mats.push(bm)
    model_mat_at.set(key, bake_mats.length - 1)
    return bake_mats.length - 1

def flatten(n:MNode, parent:Xform, out:[BakeTri]) -> void:
    if not n.visible: return
    let t = xmul(parent, node_xform(n))
    let mesh = n.mesh
    let mat = n.mat
    if mesh and mat:
        let nb = btransposed(binverse(t.b))
        let mi = mat_index(mat)
        var k = 0
        while k + 2 < mesh.idx.length:
            let tri = BakeTri { [], [], [], [], mi }
            for(3) j:
                let i = mesh.idx[k + j]
                tri.p.push(xf(t, mesh.p[i]))
                tri.n.push(normalize(bxf(nb, mesh.n[i])))
                tri.c.push(if mat.vertex_colours and mesh.c.length > i: mat.albedo * mesh.c[i] else: mat.albedo)
                tri.uv.push(mesh.uv[i])
            out.push(tri)
            k += 3
    for(n.kids) kid: flatten(kid, t, out)

def model_tris(n:MNode) -> [BakeTri]:
    let out = []::BakeTri
    flatten(n, XF_ID, out)
    return out

// Each mesh's box in the tree's space (Godot's transform * mesh AABB: the box round its corners turned).
def mesh_boxes(n:MNode, parent:Xform, out:[[float3]]) -> void:
    if not n.visible: return
    let t = xmul(parent, node_xform(n))
    let mesh = n.mesh
    if mesh and mesh.p.length:
        var lo = mesh.p[0]
        var hi = mesh.p[0]
        for(mesh.p) p:
            lo = min(lo, p)
            hi = max(hi, p)
        var blo = float3_1 * 1000000000.0
        var bhi = float3_1 * -1000000000.0
        for(8) i:
            let q = xf(t, float3 { if i & 1: hi.x else: lo.x, if i & 2: hi.y else: lo.y, if i & 4: hi.z else: lo.z })
            blo = min(blo, q)
            bhi = max(bhi, q)
        out.push([blo, bhi])
    for(n.kids) kid: mesh_boxes(kid, t, out)
