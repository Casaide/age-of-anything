import from "../creel/src"
import std
import vec
import dictionary
import gen.json
import gen.sha256
import gen.rng
import gen.datalib
import gen.identity
import gen.pricing
import gen.heroes
import gen.generator
import lua.parse
import gen.mods
import lib.consts
import lib.fixed
import lib.tokens
import lib.state
import lib.flow
import lib.spatial
import lib.orders
import lib.movement
import lib.steering
import lib.fog
import lib.map
import lib.economy
import lib.tech
import lib.combat
import lib.siege
import lib.eco_bot
import lib.garrison
import lib.heal
import lib.heroes
import lib.match
import lib.trade
import lib.recipes
import lib.carry
import lib.animals
import lib.bridges
import lib.walls
import lib.abilities
import lib.trails
import lib.commands
import lib.ai_cfg
import lib.scout
import lib.land
import lib.expand
import lib.bot
import lib.walls_ai
import lib.world
import hooks.active
import hooks.rules
import gen.setup
import gen.race_to_types
import gen.modes
import gen.start
import lua.lua
import lua.api
import gen.reset
import gen.save
import testkit.kit
import game.model_type
import game.tips

// The economy mod's first slice (mods/steading, #524): a stocked town of wood, planks and stone, played headless for
// 15 minutes by a script (no bot, no enemy). Woodcutters and stone cutters gather, a woodcutter's hut, a sawmill and a
// quarry go up (paid by carrying planks and stone to their sites), and the sawmill turns logs into planks.
// Run from src:  lobster test_steading.lobster
lib_load("../data")
id_load("../data")

let MINUTES = 15
let FIELD_GRAIN = 40  // the grain a sown field holds (Steading's farm)
// who works where
let JOBS = [ [ "woodcutter", "lumber_camp" ], [ "stonecutter", "mining_camp" ], [ "sawyer", "sawmill" ], [ "farmer", "farm" ], [ "miller", "mill" ], [ "baker", "bakery" ], [ "miner", "coal_mine" ], [ "miner", "iron_mine" ], [ "miner", "gold_mine" ], [ "smelter", "iron_smelter" ], [ "smelter", "gold_smelter" ], [ "smith", "armoury" ] ]
let MAP = "steading_vale"  // (the mod's own map: the meadow with seams in its mountains, #42)
let COAL_LEFT = 3          // the loads the test leaves in each cell of the coal seam by the town, so it runs out
let T_EAT = 100            // (the mod's hunger.lua: its own task, going to eat)
let used = mods_use([ "steading" ])
check(used.length == 1, "the mod loads ({map(mods_refused.get_keys()) id: id + ": " + mods_refused.get(id, "")})")
let rules = load_rules("steading")
let races = map([ "villagers", "sewer rats" ]) p: generate(p, rules, 0)
// Every side plays villagers, whatever was typed (rules "race", #70).
let typed_rats = gstr(races[1], "creature", "")
check(gstr(races[0], "creature", "") == "human" and typed_rats == "human", "steading: every side is villagers, whatever was typed ({typed_rats})")
// Every building is drawn with a model the game has: its own, or the one it extends (#58: the sawmill had none, and the
// game stopped baking it at the start).
let game_buildings = at(parse_json(read_file("../data/buildings.json") or ""), "buildings")
let merged_buildings = at(lib_data("buildings.json"), "buildings")
for(merged_buildings.keys) id:
    let mt = model_type(merged_buildings, id)
    check(has(game_buildings, mt), "steading: {id} is drawn with a model the game has (it gets {mt})")
// A workshop makes only what its own recipe says, not what the one it extends makes as well (#106: the bakery extends
// the mill, and baked from grain and flour into flour and bread, so it stopped once its flour slot filled).
let own_buildings = at(parse_json(read_file("../mods/steading/data/buildings.json") or ""), "buildings")
for(own_buildings.keys) id:
    if has(merged_buildings, id) and has(at(own_buildings, id), "makes"):
        let own = gobj(at(own_buildings, id), "makes")
        for([ "in", "out" ]) side:
            let mine_ = gobj(own, side)
            let got = gobj(gobj(at(merged_buildings, id), "makes"), side)
            let extra = filter(got.keys) r: gint(got, r, 0) > 0 and gint(mine_, r, 0) == 0
            check(not extra.length, "steading: {id} makes only from its own recipe ({side} also has {extra})")
        // (nor hands out its inputs: the sawmill got the woodcutter's hut's offer of wood, and carriers took its logs
        // to the storehouse and to the other sawmill)
        let offers = filter(glist(at(merged_buildings, id), "offers")) o: gint(gobj(own, "in"), as_str(o), 0) > 0
        check(not offers.length, "steading: {id} doesn\'t offer what it makes from ({map(offers) o: as_str(o)})")
    if has(merged_buildings, id) and has(at(own_buildings, id), "staff"):  // (nor takes the staff of the one it extends: a woodcutter went to work at the sawmill)
        let got = gobj(at(merged_buildings, id), "staff")
        let extra = filter(got.keys) k: gint(got, k, 0) > 0 and gint(gobj(at(own_buildings, id), "staff"), k, 0) == 0
        check(not extra.length, "steading: {id} is worked only by its own staff (also {extra})")

def res(name:string) -> int: return str_index(resource_names, name)

def mine() -> [int]: return map(filter(u_x.length) i: u_owner[i] == 0 and t_worker[u_kind[i]] != 0) i: u_id[i]

def all_of(r:int) -> int:  // player 0's r: in its buildings and in its units' hands
    var n = 0
    for(b_id.length) b:
        if b_owner[b] == 0 and b_hold[b].length: n += b_hold[b][r]
    for(u_x.length) i:
        if u_owner[i] == 0 and u_carry_kind[i] == r + 1: n += u_carry[i]
    return n

// Lay building `id` for player 0 near (x, y) in tiles, from the town (no worker named): the first place it fits, spiralling out.
def lay(id:string, x:int, y:int) -> bool:
    let k = btype_index(id)
    assert k >= 0
    for(12) d:
        for(2 * d + 1) ey:
            for(2 * d + 1) ex:
                let dx = ex - d
                let dy = ey - d
                if max(abs(dx), abs(dy)) == d and can_place(0, k, x + dx, y + dy, 0):
                    issue_cmd(0, CMD_BUILD, []::int, k, x + dx, y + dy, 0)
                    return true
    return false

// A road dragged along a row near x, y, a plan a cell as the road tool lays it (game/roads, #68): the first row of n free
// cells, built in order. How many plans were laid.
def lay_road(x:int, y:int, n:int) -> int:
    let k = btype_index("road")
    for(12) d:
        for([ y + d, y - d ]) ry:
            var free = true
            for(n) j: free = free and can_place(0, k, x + j, ry, 0)
            if free:
                for(n) j: issue_cmd(0, CMD_BUILD, []::int, k, x + j, ry, 0, if j > 0: 1 else: 0)
                return n
    return 0

def road_cells() -> int:
    var n = 0
    for(road) r:
        if r > 0: n++
    return n

// The id of player 0's finished building of type `id`, 0 if there's none yet.
def done_of(id:string) -> int:
    for(b_id.length) b:
        if b_owner[b] == 0 and b_done[b] != 0 and bt_name[b_kind[b]] == id: return b_id[b]
    return 0

// The cells of resource r (its index) within d tiles of (x, y), in cell order.
def cells_of(r:int, x:int, y:int, d:int) -> [int]:
    return filter(W * H) c: res_at(c) == r + 1 and abs(c % W - x) <= d and abs(c / W - y) <= d

def play() -> int:
    new_world(2026, MAP, races, rules, [])
    let w = res("wood")
    let pl = res("plank")
    let st = res("stone")
    check(r_stocked == 1 and pl >= 0 and t_carrier[u_kind[index_of(mine()[0])]] == 1, "steading: a stocked economy, planks, workers who carry")
    let tc = 0
    check(b_owner[tc] == 0 and b_kind[tc] == btype_index("town_center") and pop[0] == 5 and pop[0] <= pop_cap[0] and btype_index("house") < 0,
          "steading: the town starts with a storehouse and 5 villagers, room for them, and no houses ({pop[0]} of {pop_cap[0]})")
    var by_tc = 0
    for(u_x.length) i:
        if u_owner[i] == 0 and abs(u_x[i] / TILE - (b_cx[tc] + 1)) <= 3 and abs(u_y[i] / TILE - (b_cy[tc] + 1)) <= 3: by_tc++
    check(by_tc == 5, "steading: the villagers start round the storehouse ({by_tc} of 5)")
    // Mines (#42): one goes up only against a seam of its own; the coal seam by the town is left small, to run out.
    let coal = res("coal")
    let seam = cells_of(coal, start_x[0] / TILE, start_y[0] / TILE, 12)
    check(seam.length == 3 and res("iron_ore") >= 0 and res("gold_ore") >= 0, "steading: the vale has a coal seam in the mountain by the town ({seam.length} cells)")
    let cm = btype_index("coal_mine")
    let sx = seam[0] % W
    let sy = seam[0] / W
    check(not can_place(0, cm, start_x[0] / TILE - 6, start_y[0] / TILE + 6, 0) and not can_place(0, btype_index("iron_mine"), sx - 2, sy, 0) and can_place(0, cm, sx - 2, sy, 0),
          "steading: a mine goes up only with its back to a seam of its own (coal against the coal, not in the meadow; iron not there)")
    for(seam) c: amount[c] = COAL_LEFT
    let tips = match_tips(su_rules)
    check(tips.length == 12 and tips[0].done == "laid:school" and not tip_done(tips[0], 0, 5), "steading: its own opening tips and goals, the first (lay a school) not yet done ({tips.length})")
    check(equal(gstrs(su_rules, "topbar_hide"), [ "age", "idle", "tree" ]), "steading: its top bar leaves out the age, the idle workers and the tech tree (#113)")
    // The goals' kinds of done (#104): so much made or gathered, so many people.
    let goal = Tip { "", "", "made:bread:50", "Goal" }
    check(tips[4].label == "Goal" and tips[0].label == "Tip" and not tip_done(goal, 0, 5) and tip_done(Tip { "", "", "people:5", "Goal" }, 0, 5) and not tip_done(Tip { "", "", "people:6", "Goal" }, 0, 5),
          "steading: the goals come after the tips; one for 5 people is met by the 5 villagers, one for 6 isn\'t, nor 50 loaves made yet")
    let plank0 = stock[pl][0]
    let gr = res("grain")
    let fl = res("flour")
    let br = res("bread")
    let bread0 = all_of(br)
    let tx = start_x[0] / TILE
    let ty = start_y[0] / TILE
    var laid = 0
    var h = 0
    var sites_ok = true
    let ate = []::int  // the workers that went to eat
    var planned = 0
    var most_builders = 0    // the most villagers building one site at once
    var site_walked = false  // someone stood on a site's cells while it went up
    var trained = false
    var mill_up = -1                                          // the tick the mill was first up
    var crafters = false                                      // the miller and the baker sent for
    var mill_waited = false                                   // the mill held grain enough for a round with no miller yet
    var flour_unstaffed = -1                                  // the flour made before the miller came
    var gatherers_ok = true                                   // nobody but a woodcutter or a stone cutter ever gathered
    let col_work = find(hook_unit_names) n: n == "workplace"  // (the mod's jobs.lua: the hut a specialist works at)
    for(MINUTES * 60 * TICK_HZ) t:
        if t == 20 and lay("school", tx - 2, ty - 6): laid++
        if t == 40 and lay("lumber_camp", tx + 6, ty - 4): laid++
        if t == 60 and lay("sawmill", tx - 6, ty + 3): laid++
        if t == 80 and lay("mining_camp", tx + 5, ty + 6): laid++
        if t == 2400 and lay("inn", tx + 7, ty + 1): laid++  // (once the sawmill is going: planks for it first)
        if t == 140: planned = lay_road(tx - 2, ty + 4, 5)
        if t == 600 and lay("farm", tx - 8, ty - 4): laid++  // (the food chain, #99: farm, mill, bakery)
        if t == 700 and lay("mill", tx - 5, ty - 9): laid++
        if t == 800 and lay("bakery", tx + 2, ty + 8): laid++
        if t == 3000 and lay("coal_mine", sx - 2, sy + 1): laid++  // (not up against the inn: its door is above)  // (the mines, #42)
        if t == 3050 and lay("iron_mine", sx + 3, sy): laid++
        if t == 3100 and lay("gold_mine", tx + 16, ty - 2): laid++
        let school = done_of("school")
        if school != 0 and not trained:
            for([ "woodcutter", "stonecutter", "sawyer", "farmer", "miner", "miner", "miner", "worker", "worker", "worker", "worker", "worker", "worker", "worker", "worker", "worker", "worker" ]) slot: issue_cmd(0, CMD_TRAIN, []::int, school, type_of_slot(0, slot), 1, 0)
            trained = true
        // The miller and the baker only half a minute after the mill is up: till then it holds its grain and makes nothing.
        let mill = done_of("mill")
        if mill != 0 and mill_up < 0: mill_up = t
        if mill_up >= 0 and not crafters and t > mill_up + 30 * TICK_HZ and done_of("bakery") != 0:
            flour_unstaffed = produced[fl][0]
            for([ "miller", "baker" ]) slot: issue_cmd(0, CMD_TRAIN, []::int, school, type_of_slot(0, slot), 1, 0)
            crafters = true
        if mill != 0 and not crafters and b_hold[b_index_of(mill)][gr] >= 2: mill_waited = true
        for(u_x.length) i:
            if u_owner[i] == 0 and u_task[i] == T_EAT and not contains(ate, u_id[i]): ate.push(u_id[i])
            if u_task[i] == GATHER and (find([ "woodcutter", "stonecutter", "farmer", "miner" ]) g: g == t_slot[u_kind[i]]) < 0: gatherers_ok = false
        wstep()
        for(b_id.length) b:
            if b_site[b].length and b_done[b] == 0 and b_progress[b] * 1000 > bt_build_ticks[b_kind[b]] * site_permille(b) + bt_build_ticks[b_kind[b]]: sites_ok = false
        if tick % 20 == 0:
            for(b_id.length) b:
                if b_owner[b] == 0 and b_done[b] == 0 and bt_road[b_kind[b]] < 0:
                    var n = 0
                    for(u_x.length) i:
                        if u_task[i] == BUILD and u_target[i] == b_id[b]: n++
                        if occupied[cell_of(u_x[i], u_y[i])] == b_id[b]: site_walked = true
                    most_builders = max(most_builders, n)
        if tick % 30 == 0: h = (h * 31 + state_hash()) & ((1 << 40) - 1)
    var built = 0
    for(b_id.length) b:
        if b_owner[b] == 0 and b_done[b] != 0 and b_kind[b] != btype_index("town_center"): built++
    var staffed = 0  // specialists at a hut of their own trade
    for(u_x.length) i:
        let at_ = b_index_of(hook_unit_get(col_work, i))
        if u_owner[i] == 0 and at_ >= 0:
            let job = t_slot[u_kind[i]]
            if (find(JOBS) jb: jb[0] == job and jb[1] == bt_name[b_kind[at_]]) >= 0: staffed++
    print "steading: {MINUTES} min, {laid} laid, {built} built, {staffed} staffed, {most_builders} at most on a site, {ate.length} ate, {road_cells()} road; planks {plank0} -> {stock[pl][0]} (sawn {produced[pl][0]}), wood {stock[w][0]} (cut {gathered[w][0]}), stone {stock[st][0]} (cut {gathered[st][0]}) in store"
    check(laid == 11 and built == 11, "steading: the school, the hut, the sawmill, the quarry, an inn, a farm, a mill, a bakery and three mines are built ({built} of {laid})")
    check(staffed == 9, "steading: a woodcutter, a stone cutter, a sawyer, a farmer, a miller, a baker and three miners trained at the school each went to work at their own ({staffed} of 9)")
    let coal_mine = b_index_of(done_of("coal_mine"))
    let col_out = find(hook_building_names) n: n == "worked_out"
    var miner_home = false  // the coal miner, its seam gone, waits by its mine
    for(u_x.length) i:
        if u_owner[i] == 0 and hook_unit_get(col_work, i) == b_id[coal_mine] and u_task[i] == T_NONE and mid_dist2(coal_mine, u_x[i], u_y[i]) <= 9 * TILE * TILE: miner_home = true
    let dug_out = (filter(seam) c: tr_names[terrain[c]] == "worked_out").length
    print "steading: coal {gathered[coal][0]} of {seam.length * COAL_LEFT}, iron ore {gathered[res("iron_ore")][0]}, gold ore {gathered[res("gold_ore")][0]}"
    check(gathered[coal][0] == seam.length * COAL_LEFT and dug_out == seam.length, "steading: the coal mine digs its seam out, every load of it, and the seam is bare rock ({gathered[coal][0]} of {seam.length * COAL_LEFT}, {dug_out} cells worked out)")
    check(hook_building_get(col_out, coal_mine) == 1 and miner_home, "steading: a worked-out mine stops, its miner waiting at its door (out {hook_building_get(col_out, coal_mine)}, home {miner_home})")
    check(gathered[res("iron_ore")][0] > 0 and gathered[res("gold_ore")][0] > 0, "steading: the iron and gold mines dig ore")
    check(gatherers_ok and gathered[w][0] > 0 and gathered[st][0] > 0, "steading: wood and stone come in, cut only by the specialists ({gathered[w][0]} wood, {gathered[st][0]} stone)")
    check(planned == 5 and road_cells() == 5 and rd_names.length == 1, "steading: a road dragged 5 cells long is built, a road cell each ({road_cells()} of {planned})")
    check(most_builders >= 2 and most_builders <= 3, "steading: idle villagers help build a site, no more than 3 sent at once ({most_builders})")
    check(site_walked, "steading: villagers walk across a site while it goes up")
    check(ate.length >= 3, "steading: hungry workers go to eat ({ate.length} of them)")
    check(sites_ok, "steading: no site was built ahead of its goods")
    check((filter(4) j: tip_done(tips[j], 0, 5)).length == 4, "steading: every opening tip is done by playing the town")
    let met = map(filter(tips) tip: tip.label == "Goal" and tip_done(tip, 0, 5)) tip: tip.done
    print "steading: goals met: {met}"
    check((find(met) d: d == "people:15") >= 0 and (find(met) d: d == "laid:iron_mine") >= 0 and tip_done(Tip { "", "", "made:bread:{produced[br][0]}", "Goal" }, 0, 5) and not tip_done(Tip { "", "", "made:bread:{produced[br][0] + 1}", "Goal" }, 0, 5),
          "steading: the town meets its goals as it grows: 15 people, the mines laid, so many loaves made")
    check(produced[pl][0] >= 20, "steading: the sawmill makes planks ({produced[pl][0]}; {plank0} -> {stock[pl][0]} in store)")
    let bread_eaten = bread0 + produced[br][0] - all_of(br)
    let hungry = (filter(u_x.length) i: u_owner[i] == 0 and u_task[i] == 101).length  // (hunger.lua's T_FAINT)
    print "steading: grain cut {gathered[gr][0]}, flour {produced[fl][0]} ({flour_unstaffed} before the miller), bread {produced[br][0]}, {bread_eaten} bread eaten, {hungry} resting hungry at the end"
    check(gathered[gr][0] > FIELD_GRAIN, "steading: the farmer reaps grain and sows the field again ({gathered[gr][0]} cut, a field holds {FIELD_GRAIN})")
    check(mill_waited and flour_unstaffed == 0, "steading: a mill with its grain in but no miller makes nothing ({flour_unstaffed})")
    check(produced[fl][0] > 0 and produced[br][0] > 0, "steading: the miller mills flour and the baker bakes bread ({produced[fl][0]} flour, {produced[br][0]} bread)")
    check(bread_eaten > 0, "steading: the town eats bread ({bread_eaten})")
    check(hungry * 4 <= pop[0], "steading: the town lives on its own bread: at the end, hardly anyone is resting hungry ({hungry} of {pop[0]})")
    return h

// A bigger town (#106): the seventeen buildings of a whole Steading town, laid where a player might, shifted a tile or
// two to show it isn't one lucky layout. Everything gets built, every trade goes to work, the sawmills keep sawing and
// the town stays fed: carriers don't all go hauling to the storehouse, and nobody stands jammed at a door.
def big_town(dx:int, dy:int) -> int:
    new_world(2026, MAP, races, rules, [])
    let pl = res("plank")
    let br = res("bread")
    let tl = res("tools")
    let seam = cells_of(res("coal"), start_x[0] / TILE, start_y[0] / TILE, 12)
    let sx = seam[0] % W
    let sy = seam[0] / W
    let tx = start_x[0] / TILE + dx
    let ty = start_y[0] / TILE + dy
    let col_work = find(hook_unit_names) n: n == "workplace"
    let col_present = find(hook_building_names) n: n == "present"
    var laid = 0
    var trained = 0
    var trained_at = 0
    var full = 0  // sawmill ticks spent standing with its planks not taken away
    var mill_ticks = 0
    var stuck_most = 0
    var h = 0
    for(30 * 60 * TICK_HZ) t:
        if t == 20 and lay("school", tx - 2, ty - 6): laid++
        if t == 40 and lay("lumber_camp", tx + 6, ty - 4): laid++
        if t == 60 and lay("sawmill", tx - 6, ty + 3): laid++
        if t == 80 and lay("mining_camp", tx + 5, ty + 6): laid++
        if t == 600 and lay("farm", tx - 8, ty - 4): laid++
        if t == 700 and lay("mill", tx - 5, ty - 9): laid++
        if t == 800 and lay("bakery", tx + 2, ty + 8): laid++
        if t == 2400 and lay("inn", tx + 7, ty - 1): laid++
        if t == 2600 and lay("sawmill", tx - 9, ty + 3): laid++
        if t == 2700 and lay("lumber_camp", tx + 12, ty - 3): laid++  // (a second: two sawmills want more logs than one woodcutter cuts)
        if t == 3000 and lay("coal_mine", sx - 1, sy + 3): laid++
        if t == 3050 and lay("iron_mine", sx + 3, sy): laid++
        if t == 3100 and lay("gold_mine", start_x[0] / TILE + 16, start_y[0] / TILE - 2): laid++
        if t == 3200 and lay("iron_smelter", tx + 9, ty + 9): laid++
        if t == 3300 and lay("gold_smelter", tx + 13, ty + 9): laid++
        if t == 3400 and lay("armoury", tx + 9, ty - 6): laid++
        if t == 3500 and lay("farm", tx - 8, ty + 8): laid++
        let school = done_of("school")
        if school != 0 and trained == 0:
            trained = 1
            trained_at = t
            for([ "woodcutter", "stonecutter", "sawyer", "sawyer", "farmer", "miller", "baker", "miner", "miner", "miner", "worker", "worker", "worker", "worker", "worker" ]) slot: issue_cmd(0, CMD_TRAIN, []::int, school, type_of_slot(0, slot), 1, 0)
        if t > trained_at + 100 and trained == 1 and b_queue[b_index_of(school)].length == 0:  // (a school teaches 15 at most at a time)
            trained = 2
            hold_put(0, res("food"), 300)  // (the school's fees for a second batch: the starting food pays for the first)
            for([ "smelter", "smelter", "smith", "farmer", "woodcutter", "worker", "worker", "worker", "worker", "worker", "worker", "worker", "worker", "worker", "worker" ]) slot: issue_cmd(0, CMD_TRAIN, []::int, school, type_of_slot(0, slot), 1, 0)
        wstep()
        for(b_id.length) b:
            if b_owner[b] == 0 and b_done[b] != 0 and bt_name[b_kind[b]] == "sawmill" and hook_building_get(col_present, b) != 0:
                mill_ticks++
                if b_make[b] == 0 and out_full(b, pl): full++
        for(u_x.length) i:
            if u_owner[i] == 0: stuck_most = max(stuck_most, u_stuck[i])
        if tick % 30 == 0: h = (h * 31 + state_hash()) & ((1 << 40) - 1)
    var built = 0
    for(b_id.length) b:
        if b_owner[b] == 0 and b_done[b] != 0 and b_kind[b] != btype_index("town_center"): built++
    var staffed = 0
    for(u_x.length) i:
        let at_ = b_index_of(hook_unit_get(col_work, i))
        if u_owner[i] == 0 and at_ >= 0 and (find(JOBS) jb: jb[0] == t_slot[u_kind[i]] and jb[1] == bt_name[b_kind[at_]]) >= 0: staffed++
    let hungry = (filter(u_x.length) i: u_owner[i] == 0 and u_task[i] == 101).length
    let idle_trades = map(filter(u_x.length) i: u_owner[i] == 0 and t_carrier[u_kind[i]] == 0 and b_index_of(hook_unit_get(col_work, i)) < 0) i: t_slot[u_kind[i]]
    let unbuilt = map(filter(b_id.length) b: b_owner[b] == 0 and b_done[b] == 0 and bt_road[b_kind[b]] < 0) b: bt_name[b_kind[b]]
    let full_pct = full * 100 / max(1, mill_ticks)
    print "steading: big town +{dx},{dy}: {built} of {laid} built, {staffed} staffed, sawmills stood full {full_pct}% of their staffed time, planks {produced[pl][0]} ({stock[pl][0]} in store), bread {produced[br][0]}, tools {produced[tl][0]}, {hungry} of {pop[0]} resting hungry, longest stuck {stuck_most}"
    check(laid == 17 and built == 17, "steading: a big town (+{dx},{dy}) builds all seventeen of its buildings ({built} of {laid}; not {unbuilt})")
    check(staffed == 15, "steading: a big town (+{dx},{dy}): every trade trained goes to work at its own ({staffed} of 15; not {idle_trades})")
    check(full_pct <= 20, "steading: a big town (+{dx},{dy}): its sawmills\' planks are carried off, not left to stop them ({full_pct}% of the time full)")
    check(hungry * 4 <= pop[0] and produced[br][0] > 0, "steading: a big town (+{dx},{dy}) keeps its people fed ({hungry} of {pop[0]} resting hungry)")
    check(produced[tl][0] > 0, "steading: a big town (+{dx},{dy}) forges tools ({produced[tl][0]})")
    return h

// Smelting and the smithy (#102), on their own: a storehouse given ore, coal and planks but no tools. The smelters
// make iron and gold, the smithy makes tools from iron and planks, and a farmer trained with no tools in store waits,
// then goes to its farm once the smithy's tools are in. Whether all of that happened, and the hash.
def metal_chain() -> int:
    new_world(2026, MAP, races, rules, [])
    let tc = 0
    let tl = res("tools")
    let fe = res("iron")
    let au = res("gold")
    hold_take(tc, tl, b_hold[tc][tl])
    for([ "plank", "stone", "iron_ore", "coal", "gold_ore" ]) g, j: hold_put(tc, res(g), [ 80, 40, 6, 8, 2 ][j])
    let tx = start_x[0] / TILE
    let ty = start_y[0] / TILE
    let col_work = find(hook_unit_names) n: n == "workplace"
    var laid = 0
    var trained = false
    var farmer_waited = false  // the farm up, no tools in store, its farmer with no workplace
    var h = 0
    for(10 * 60 * TICK_HZ) t:
        if t == 20 and lay("school", tx - 2, ty - 6): laid++
        if t == 40 and lay("iron_smelter", tx + 6, ty - 4): laid++
        if t == 60 and lay("gold_smelter", tx - 6, ty + 3): laid++
        if t == 80 and lay("armoury", tx + 5, ty + 6): laid++
        if t == 100 and lay("farm", tx - 8, ty - 4): laid++
        if t == 120:
            let st = b_index_of(done_of("town_center"))  // (its door: below its bottom edge's middle)
            check(not can_place(0, btype_index("inn"), b_cx[st] + b_sx[st] / 2 - 1, b_cy[st] + b_sy[st], 0), "steading: nothing goes up over the tile in front of a door (the storehouse\'s)")
        let school = done_of("school")
        if school != 0 and not trained:
            for([ "smelter", "smelter", "smith", "farmer", "worker", "worker", "worker", "worker" ]) slot: issue_cmd(0, CMD_TRAIN, []::int, school, type_of_slot(0, slot), 1, 0)
            trained = true
        if done_of("farm") != 0 and stock[tl][0] == 0 and (find(u_x.length) i: u_owner[i] == 0 and t_slot[u_kind[i]] == "farmer" and hook_unit_get(col_work, i) == 0) >= 0: farmer_waited = true
        wstep()
        if tick % 30 == 0: h = (h * 31 + state_hash()) & ((1 << 40) - 1)
    let farmer = find(u_x.length) i: u_owner[i] == 0 and t_slot[u_kind[i]] == "farmer"
    let farm_id = done_of("farm")
    print "steading: metal: {laid} laid, iron {produced[fe][0]}, gold {produced[au][0]}, tools {produced[tl][0]} ({stock[tl][0]} in store), farmer waited {farmer_waited}"
    check(laid == 5 and done_of("armoury") != 0 and done_of("iron_smelter") != 0 and done_of("gold_smelter") != 0, "steading: two smelters and a smithy go up ({laid} laid)")
    check(produced[fe][0] > 0 and produced[au][0] > 0, "steading: the smelters melt ore with coal into iron and gold ({produced[fe][0]} iron, {produced[au][0]} gold)")
    check(produced[tl][0] > 0, "steading: the smith forges iron and planks into tools ({produced[tl][0]})")
    check(farmer_waited and farmer >= 0 and farm_id != 0 and hook_unit_get(col_work, farmer) == farm_id, "steading: a farmer trained with no tools in store waits, then works the farm once the smithy\'s tools are in")
    return h

// Pigs and sausages (#103), on their own: a storehouse given grain and planks but no bread. The swineherd fattens pigs
// on grain, the butcher makes them into sausages, and the town eats those. Whether it did, and the hash.
def pig_chain() -> int:
    new_world(2026, MAP, races, rules, [])
    let tc = 0
    let br = res("bread")
    let pg = res("pig")
    let sa = res("sausage")
    hold_take(tc, br, b_hold[tc][br])
    for([ "plank", "stone", "grain" ]) g, j: hold_put(tc, res(g), [ 60, 30, 60 ][j])
    let tx = start_x[0] / TILE
    let ty = start_y[0] / TILE
    var laid = 0
    var trained = false
    var h = 0
    for(10 * 60 * TICK_HZ) t:
        if t == 20 and lay("school", tx - 2, ty - 6): laid++
        if t == 40 and lay("pig_farm", tx + 6, ty - 4): laid++
        if t == 60 and lay("butcher", tx - 6, ty + 3): laid++
        let school = done_of("school")
        if school != 0 and not trained:
            for([ "swineherd", "butcher", "worker", "worker", "worker" ]) slot: issue_cmd(0, CMD_TRAIN, []::int, school, type_of_slot(0, slot), 1, 0)
            trained = true
        wstep()
        if tick % 30 == 0: h = (h * 31 + state_hash()) & ((1 << 40) - 1)
    let eaten = produced[sa][0] - all_of(sa)
    print "steading: pigs: {laid} laid, pigs {produced[pg][0]}, sausages {produced[sa][0]}, {eaten} eaten"
    check(laid == 3 and done_of("pig_farm") != 0 and done_of("butcher") != 0, "steading: a pig farm and a butcher go up ({laid} laid)")
    check(produced[pg][0] > 0 and produced[sa][0] >= 3 * produced[pg][0] - 6, "steading: pigs are fattened on grain and made into sausages, three a pig ({produced[pg][0]} pigs, {produced[sa][0]} sausages)")
    check(eaten > 0, "steading: with no bread, the town eats sausages ({eaten})")
    return h

def store_planks() -> int:
    var n = 0
    for(b_id.length) b:
        if is_store(b, 0): n += b_hold[b][res("plank")]
    return n

// Through a save (#75): the mod's Lua loads again with the saved match, and its state comes back in the hook columns.
// A hut goes up and the villagers wait, carry and get hungry for 2 minutes; then 2 minutes more, once straight on and once from a save made
// there: the same hash every tick. Whether they matched, and whether anyone was hungry or ate by then.
// stop: the mod's rules stop before the save (as an error would stop them): they must stay stopped after the load.
def save_run(stop:bool) -> bool, bool:
    let path = "test_steading.sav"
    new_world(2026, MAP, races, rules, [])
    let tx = start_x[0] / TILE
    let ty = start_y[0] / TILE
    for(2 * 60 * TICK_HZ) t:
        if t == 40: lay("lumber_camp", tx + 6, ty - 4)
        wstep()
    if stop:
        let pk = l_packs[find(l_packs) p: p.id == "steading"]
        pk.error = "stopped by the test"
        lx_note_stop(pk)
    assert save_world(path, [])
    let want = map(2 * 60 * TICK_HZ):
        wstep()
        state_hash()
    let cols = map(hook_unit_names) n: n
    var lively = false
    for(u_id.length) i:
        for([ "meal" ]) name:
            let c = find(cols) n: n == name
            if c >= 0 and hook_unit_get(c, i) != 0: lively = true
    reset_world()
    lua_reset()  // (as a game started fresh to load it has no Lua yet)
    lua_on = false
    lua_rules = jobj()
    load_world(path)
    delete_file(path)
    let got = map(2 * 60 * TICK_HZ):
        wstep()
        state_hash()
    let off = l_packs[find(l_packs) p: p.id == "steading"].error != ""
    return equal(want, got) and off == stop, lively

let h1 = play()
let h2 = play()
check(h1 == h2, "steading: the same town twice, the same hash")
check(pig_chain() == pig_chain(), "steading: the same pigs twice, the same hash")
check(metal_chain() == metal_chain(), "steading: the same metal trades twice, the same hash")
for([ [ 0, 0 ], [ 1, 0 ], [ 0, 1 ], [ -1, 1 ] ]) d: big_town(d[0], d[1])
let same, lively = save_run(false)
check(lively and same, "steading: through a save, the mod\'s rules and their state play on the same (lively {lively}, same {same})")
let same_off, _ = save_run(true)
check(same_off, "steading: rules that stopped before a save stay stopped after it, the same on every machine")
lib_packs = [ lib_packs[0] ]
id_load(lib_root)
print "\n{checks - failures} passed, {failures} failed"
if failures > 0: set_exit_code(1)
