// ------------------------------------------------------------------ walls (walls.gd)
// Breaches: a wall piece of a type in breach.from destroyed leaves its cells as walkable rubble its
// owner can rebuild cheaply (repair_cost). A ladder's foot is walked over.

// Wall piece b is falling (destroyed): its cells become rubble, remembering what stood there.
// Call before the building is removed.
def breach(b:int):
    let k = b_kind[b]
    if bt_ladder[k]: set_walk_over(footprint(b), false)
    if rubble_terrain < 0 or not contains(rubble_from, k) or b_done[b] == 0: return
    var along = 0
    if b_diag[b] != 0: along = b_diag[b] + 1
    elif b_sy[b] > b_sx[b]: along = 1
    for(footprint(b)) c:
        if not rubble.get(c):
            rubble.set(c, [terrain[c], b_owner[b], k, b_cx[b], b_cy[b], along])
            let found, at = binary_search(rubble_cells, c)
            rubble_cells.insert(at, c)
            set_terrain(c, rubble_terrain)

// The rubble's part of the hash (Walls.hash_into: the rubble, cell by cell).
def rubble_hash(h0:int) -> int:
    var h = h0
    for(rubble_cells) c:
        h = mix(h, c)
        for(rubble.get(c) or []::int) v: h = mix(h, v)
    return h
