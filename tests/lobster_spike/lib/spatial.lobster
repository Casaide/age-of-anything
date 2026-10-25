// ------------------------------------------------------------------ spatial.gd

def spatial_build():
    let n = u_x.length
    let cells = W * H
    for(cells) c: sp_cursor[c] = 0
    for(n) i:
        let c = clamp(u_y[i] / TILE, 0, H - 1) * W + clamp(u_x[i] / TILE, 0, W - 1)
        sp_cell[i] = c
        sp_cursor[c]++
    var acc = 0
    for(cells) c:
        sp_start[c] = acc
        acc += sp_cursor[c]
        sp_end[c] = acc
        sp_cursor[c] = sp_start[c]
    for(n) i:
        let c = sp_cell[i]
        sp_items[sp_cursor[c]] = i
        sp_cursor[c]++

