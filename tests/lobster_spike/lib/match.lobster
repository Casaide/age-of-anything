// ------------------------------------------------------------------ winning and losing (match.gd)
// A player who started with a Town Center is out once it has none left (finished or not); when only
// one team has players left, that team wins. Checked once a second. Left out: surrender, game
// modes, Wonder victory (no Wonders in the scenarios: asserted).

let CHECK_EVERY = 20

def towns(p:int) -> int:
    let tk = btype_named("town_center")
    var n = 0
    for(b_id.length) b:
        if b_owner[b] == p and b_kind[b] == tk: n++
    return n

def match_tick():
    if winner >= 0 or tick % CHECK_EVERY != 0: return
    for(num_players) p:
        if defeated[p] == 0 and started_with_town[p] == 1 and towns(p) == 0: defeated[p] = tick + 1
    let wk = btype_named("wonder")
    for(b_kind) k: assert k != wk   // (Wonder victory isn't ported)
    let left = []::int
    for(num_players) p:
        if defeated[p] == 0 and not contains(left, teams[p]): left.push(teams[p])
    if contains(started_with_town, 1) and left.length == 1: winner = left[0]
