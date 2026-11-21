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
import game.steading_lay
import game.model_type
import game.tips

// The economy mod's first slice (mods/steading, #524): a stocked town of wood, planks and stone, played headless for
// 15 minutes by a script (no bot, no enemy). Woodcutters and stone cutters gather, a woodcutter's hut, a sawmill and a
// quarry go up (paid by carrying planks and stone to their sites), and the sawmill turns logs into planks.
// Run from src:  lobster test_steading.lobster
lib_load("../data")
id_load("../data")

let MINUTES = 32      // (long enough for the food chain at the genre's pace: the farm is up at 8 minutes, its wheat ripe six on, #122; serfs no quicker on roads, #138)
let FIELD_GRAIN = 12  // the farm's fields in the scripted towns (game/steading_lay's auto_fields), a sheaf of grain each
// who works where
let JOBS = [ [ "woodcutter", "lumber_camp" ], [ "stonecutter", "mining_camp" ], [ "sawyer", "sawmill" ], [ "farmer", "farm" ], [ "miller", "mill" ], [ "baker", "bakery" ], [ "miner", "coal_mine" ], [ "miner", "iron_mine" ], [ "miner", "gold_mine" ], [ "smelter", "iron_smelter" ], [ "smelter", "gold_smelter" ], [ "smith", "armoury" ] ]
let MAP = "steading_vale"  // (the mod's own map: the meadow with seams in its mountains, #42)
let COAL_LEFT = 3          // the loads the test leaves in each cell of the coal seam by the town, so it runs out
let T_EAT = 100            // (the mod's hunger.lua: its own task, going to eat)
let used = mods_use([ "steading" ])
check(used.length == 1, "the mod loads ({map(mods_refused.get_keys()) id: id + ": " + mods_refused.get(id, "")})")
// Every good of the mod's own has its icon in the mod (#141): the storehouse, the School and the build cards show it.
let steading_root = lib_packs[lib_packs.length - 1].root
let goods_unshown = filter(map(glist(lib_data("resources.json"), "resources")) r: gstr(r, "id", "")) id: not read_file("icons/res_" + id + ".png") and not read_file(steading_root + "/icons/res_" + id + ".png")
check(goods_unshown.length == 0, "steading: every good has an icon ({goods_unshown})")
let rules = load_rules("steading")
let races = map([ "serfs", "sewer rats" ]) p: generate(p, rules, 0)
// Every side plays serfs, whatever was typed (rules "race", #70).
let typed_rats = gstr(races[1], "creature", "")
check(gstr(races[0], "creature", "") == "human" and typed_rats == "human", "steading: every side is serfs, whatever was typed ({typed_rats})")
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

// Lay building `id` for player 0 near (x, y) in tiles, from the town (no worker named), with a road to its door (game/steading_lay).
def lay(id:string, x:int, y:int) -> bool:
    let ok = lay_or_wait(id, x, y)
    if not ok: print "steading: no room for {id} near {x},{y} with a road to its door"
    return ok

// A road dragged along a row near x, y, a plan a cell as the road tool lays it (game/roads, #68): the first row of n free
// cells, built in order. How many plans were laid.
var dragged = []::int  // the cells of the last road dragged

def lay_road(x:int, y:int, n:int) -> int:
    let k = btype_index("road")
    for(12) d:
        for([ y + d, y - d ]) ry:
            var free = true
            for(n) j: free = free and can_place(0, k, x + j, ry, 0)
            if free:
                for(n) j: issue_cmd(0, CMD_BUILD, []::int, k, x + j, ry, 0, if j > 0: 1 else: 0)
                dragged = map(n) j: ry * W + x + j
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

// Mines (#42): one goes up only against a seam of its own. In a world of its own: the roads to the doors here cost stone.
// With doors on roads (#119), each place gets a road to its door first, so only the seam decides.
def seam_check():
    new_world(2026, MAP, races, rules, [])
    lay_later = []
    lay_sent = []
    fields_by_script(false)
    let seam = cells_of(res("coal"), start_x[0] / TILE, start_y[0] / TILE, 12)
    let cm = btype_index("coal_mine")
    let ik = btype_index("iron_mine")
    let sx = seam[0] % W
    let sy = seam[0] / W
    let by_seam = road_to_door(cm, sx - 2, sy)
    var mx = start_x[0] / TILE - 6
    let my = start_y[0] / TILE + 6
    while not (open_square(mx, my, bt_size[cm]) and road_to_door(cm, mx, my)) and mx < start_x[0] / TILE + 6: mx++
    check(by_seam and not can_place(0, cm, mx, my, 0) and not can_place(0, ik, sx - 2, sy, 0) and can_place(0, cm, sx - 2, sy, 0),
          "steading: a mine goes up only with its back to a seam of its own (coal against the coal, not in the meadow; iron not there)")

def play() -> int:
    new_world(2026, MAP, races, rules, [])
    lay_later = []
    lay_sent = []
    fields_by_script(true)  // (each farm gets its fields once built, a player's way: #122)
    let w = res("wood")
    let pl = res("plank")
    let st = res("stone")
    check(r_stocked == 1 and pl >= 0 and t_carrier[u_kind[index_of(mine()[0])]] == 1, "steading: a stocked economy, planks, workers who carry")
    let tc = 0
    check(b_owner[tc] == 0 and b_kind[tc] == btype_index("town_center") and pop[0] == 8 and pop[0] <= pop_cap[0] and btype_index("house") < 0,
          "steading: the town starts with a storehouse and 8 serfs, room for them, and no houses ({pop[0]} of {pop_cap[0]})")
    var by_tc = 0
    for(u_x.length) i:
        if u_owner[i] == 0 and abs(u_x[i] / TILE - (b_cx[tc] + 1)) <= 3 and abs(u_y[i] / TILE - (b_cy[tc] + 1)) <= 3: by_tc++
    check(by_tc == 8, "steading: the serfs start round the storehouse ({by_tc} of 8)")
    // Mines (#42): one goes up only against a seam of its own; the coal seam by the town is left small, to run out.
    let coal = res("coal")
    let seam = cells_of(coal, start_x[0] / TILE, start_y[0] / TILE, 12)
    check(seam.length == 3 and res("iron_ore") >= 0 and res("gold_ore") >= 0, "steading: the vale has a coal seam in the mountain by the town ({seam.length} cells)")
    let sx = seam[0] % W
    let sy = seam[0] / W
    for(seam) c: amount[c] = COAL_LEFT
    let tips = match_tips(su_rules)
    check(tips.length == 12 and tips[0].done == "laid:school" and not tip_done(tips[0], 0, 5), "steading: its own opening tips and goals, the first (lay a school) not yet done ({tips.length})")
    let vk = type_of_slot(0, "worker")
    check(t_cost[vk][res("gold")] == 10 and t_cost[vk][res("food")] == 0 and stock[res("gold")][0] == 400, "steading: the school\'s fee is 10 gold, no food, and the town starts with 400 gold (#116; {t_cost[vk]})")
    check(equal(gstrs(su_rules, "topbar_hide"), [ "age", "idle", "tree" ]), "steading: its top bar leaves out the age, the idle workers and the tech tree (#113)")
    // The goals' kinds of done (#104): so much made or gathered, so many people.
    let goal = Tip { "", "", "made:bread:50", "Goal" }
    check(tips[4].label == "Goal" and tips[0].label == "Tip" and not tip_done(goal, 0, 8) and tip_done(Tip { "", "", "people:8", "Goal" }, 0, 8) and not tip_done(Tip { "", "", "people:9", "Goal" }, 0, 8),
          "steading: the goals come after the tips; one for 8 people is met by the 8 serfs, one for 9 isn\'t, nor 50 loaves made yet")
    let plank0 = stock[pl][0]
    let gr = res("grain")
    let fl = res("flour")
    let br = res("bread")
    let tx = start_x[0] / TILE
    let ty = start_y[0] / TILE
    var laid = 0
    var h = 0
    var sites_ok = true
    let ate = []::int  // the workers that went to eat
    var planned = 0
    var most_builders = 0    // the most serfs building one site at once
    var site_walked = false  // someone stood on a site's cells while it went up
    let site_ids = []::int   // the sites seen (not roads), and how long each had stood with nobody building it (-1 once someone did)
    let site_waits = []::int
    var longest_wait = 0  // the longest a site stood before its first builder came
    var trained = false
    var mill_up = -1                                          // the tick the mill was first up
    var crafters = false                                      // the miller and the baker sent for
    var mill_waited = false                                   // the mill held grain enough for a round with no miller yet
    var flour_unstaffed = -1                                  // the flour made before the miller came
    var gatherers_ok = true                                   // nobody but a woodcutter or a stone cutter ever gathered
    var off_door = 0  // stays inside begun away from the building's door tile (#157)
    var went_in = 0
    var dropped_away = 0                                      // ticks a specialist was on its way to drop goods somewhere not its own workplace (#134)
    let col_work = find(hook_unit_names) n: n == "workplace"  // (the mod's jobs.lua: the hut a specialist works at)
    let inside_for = map(1000): 0                             // (#140) each unit slot's ticks inside a building so far, and each stay's length when it came out
    let stays = []::int
    let hc = gobj(gobj(rules, "economy"), "hunger")  // (#132: who ate in the first 15 minutes, and the least time left on a bar then)
    let col_meal = find(hook_unit_names) n: n == "meal"
    var ate_15 = -1
    var lowest = 1 << 30
    var planks_seen = -1  // the sawmill's rounds (#139): planks made as of last tick, when the last round ended, the shortest gap
    var round_at = -1
    var shortest_round = 1 << 30
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
        // The miller and the baker only half a minute after the mill is up and holds grain: till then it makes nothing.
        let mill = done_of("mill")
        if mill != 0 and mill_up < 0: mill_up = t
        if mill_up >= 0 and not crafters and mill_waited and t > mill_up + 30 * TICK_HZ and done_of("bakery") != 0:
            flour_unstaffed = produced[fl][0]
            for([ "miller", "baker" ]) slot: issue_cmd(0, CMD_TRAIN, []::int, school, type_of_slot(0, slot), 1, 0)
            crafters = true
        if mill != 0 and not crafters and b_hold[b_index_of(mill)][gr] >= 2: mill_waited = true
        for(u_x.length) i:
            if u_owner[i] == 0 and u_task[i] == T_EAT and not contains(ate, u_id[i]): ate.push(u_id[i])
            if u_task[i] == GATHER and (find([ "woodcutter", "stonecutter", "farmer", "miner" ]) g: g == t_slot[u_kind[i]]) < 0: gatherers_ok = false
            if u_owner[i] == 0 and u_task[i] == T_RETURN and t_carrier[u_kind[i]] == 0 and hook_unit_get(col_work, i) != 0 and u_target[i] != hook_unit_get(col_work, i): dropped_away++
        if t == 15 * 60 * TICK_HZ:
            ate_15 = ate.length
            lowest = fold(filter(u_x.length) i: u_owner[i] == 0, 1 << 30) a, i: min(a, gint(hc, "life", 0) * TICK_HZ - (hook_unit_get(col_meal, i) - 1))
        lay_step()
        for(u_x.length) i:
            if i < inside_for.length:
                if is_inside(i, -1):  // (a carrier or a worker at a drop, not one at the inn)
                    if inside_for[i] == 0:  // (going in: by the door, #157)
                        let at_ = b_index_of(u_target[i])
                        if at_ >= 0 and b_done[at_] != 0:  // (a site is built from round it)
                            let x0, y0, x1, y1 = entry_rect(at_)
                            if not by_door(at_) or not in_reach(i, x0, y0, x1, y1): off_door++
                            went_in++
                    inside_for[i]++
                elif inside_for[i] > 0:
                    stays.push(inside_for[i])
                    inside_for[i] = 0
        let sawn = produced[res("plank")][0]
        if planks_seen >= 0 and sawn > planks_seen:
            if round_at >= 0: shortest_round = min(shortest_round, tick - round_at)
            round_at = tick
        planks_seen = sawn
        for(b_id.length) b:
            if b_site[b].length and b_done[b] == 0 and b_progress[b] > build_cap(b) + 1: sites_ok = false
        if tick % 20 == 0:
            for(b_id.length) b:
                if b_owner[b] == 0 and b_done[b] == 0 and bt_road[b_kind[b]] < 0:
                    var n = 0
                    for(u_x.length) i:
                        if u_task[i] == BUILD and u_target[i] == b_id[b]: n++
                        if occupied[cell_of(u_x[i], u_y[i])] == b_id[b]: site_walked = true
                    most_builders = max(most_builders, n)
                    var s = find(site_ids): _ == b_id[b]
                    if s < 0:
                        site_ids.push(b_id[b])
                        site_waits.push(0)
                        s = site_ids.length - 1
                    if site_waits[s] >= 0 and n == 0: site_waits[s] += 20
                    if n > 0 and site_waits[s] >= 0:
                        longest_wait = max(longest_wait, site_waits[s])
                        site_waits[s] = -1
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
    let dragged_built = (filter(dragged) c: road[c] > 0).length
    check(planned == 5 and dragged_built == 5 and rd_names.length == 1, "steading: a road dragged 5 cells long is built, a road cell each ({dragged_built} of {planned})")
    check(most_builders >= 2 and most_builders <= 3, "steading: idle serfs help build a site, no more than 3 sent at once ({most_builders})")
    check(site_walked, "steading: serfs walk across a site while it goes up")
    check(next_job / MINUTES <= 50, "steading: serfs aren\'t run off their feet: at the genre\'s pace a town of this size makes at most 50 carry jobs a minute, most for its building sites ({next_job / MINUTES}; 59 at the old pace)")
    check(shortest_round >= 44 * TICK_HZ and shortest_round < 1 << 30,
          "steading: a sawyer saws a log in 36 s and takes a break after each round, the genre\'s pace (the shortest round {shortest_round / TICK_HZ} s)")
    let full_stays = filter(stays): _ == r_inside_ticks
    let short_stays = filter(stays): _ < r_inside_ticks
    let long_stays = filter(stays): _ > r_inside_ticks
    print "steading: stays inside: {full_stays.length} of {r_inside_ticks} ticks, shorter {short_stays}, longer {long_stays}"
    check(r_inside_ticks == 30 and stays.length >= 100 and full_stays.length * 100 >= stays.length * 95,
          "steading: every pick-up and drop takes a carrier inside for 1.5 s ({full_stays.length} of {stays.length} stays that long)")
    check(went_in > 100 and off_door == 0, "steading: people go into a building only by its door ({off_door} of {went_in} went in elsewhere; #157)")
    check(dropped_away == 0, "steading: a gatherer only ever drops at its own hut, and waits there when it\'s full; serfs take goods on ({dropped_away} ticks headed elsewhere)")
    let never = filter(site_waits): _ >= 0
    check(longest_wait <= 30 * TICK_HZ and not never.length,
          "steading: a site laid in a busy town gets its first builder within half a minute, however much is being hauled (the longest {longest_wait / TICK_HZ} s, {never.length} never)")
    // (as in the genre, #132: people start with 60% of a 45-minute bar, give or take 10%, and eat with 6 minutes left,
    // so nobody is hungry in a town's first 15 minutes; the big towns, 36 minutes long, eat)
    check(ate_15 == 0 and lowest > gint(hc, "hungry_at", 0) * TICK_HZ and gint(hc, "life", 0) == 45 * 60,
          "steading: a bar lasts 45 minutes and nobody is hungry in the first 15 ({ate_15} went to eat, {lowest / TICK_HZ} s left at the lowest)")
    check(sites_ok, "steading: no site was built ahead of its goods")
    check((filter(4) j: tip_done(tips[j], 0, 5)).length == 4, "steading: every opening tip is done by playing the town")
    let met = map(filter(tips) tip: tip.label == "Goal" and tip_done(tip, 0, 5)) tip: tip.done
    print "steading: goals met: {met}"
    check((find(met) d: d == "people:15") >= 0 and (find(met) d: d == "laid:iron_mine") >= 0 and tip_done(Tip { "", "", "made:bread:{produced[br][0]}", "Goal" }, 0, 5) and not tip_done(Tip { "", "", "made:bread:{produced[br][0] + 1}", "Goal" }, 0, 5),
          "steading: the town meets its goals as it grows: 15 people, the mines laid, so many loaves made")
    check(produced[pl][0] >= 20, "steading: the sawmill makes planks ({produced[pl][0]}; {plank0} -> {stock[pl][0]} in store)")
    let hungry = (filter(u_x.length) i: u_owner[i] == 0 and u_task[i] == 101).length  // (hunger.lua's T_FAINT)
    print "steading: grain cut {gathered[gr][0]}, flour {produced[fl][0]} ({flour_unstaffed} before the miller), bread {produced[br][0]}, {hungry} resting hungry at the end"
    check(gathered[gr][0] > FIELD_GRAIN, "steading: the farmer reaps his fields and sows them again ({gathered[gr][0]} cut, from {FIELD_GRAIN} fields)")
    check(mill_waited and flour_unstaffed == 0, "steading: a mill with its grain in but no miller makes nothing ({flour_unstaffed})")
    check(produced[fl][0] > 0 and produced[br][0] > 0, "steading: the miller mills flour and the baker bakes bread ({produced[fl][0]} flour, {produced[br][0]} bread)")
    check(hungry * 4 <= pop[0], "steading: the town lives on its own bread: at the end, hardly anyone is resting hungry ({hungry} of {pop[0]})")
    return h

// A bigger town (#106): the seventeen buildings of a whole Steading town, laid where a player might, shifted a tile or
// two to show it isn't one lucky layout. Everything gets built, every trade goes to work, the sawmills keep sawing and
// the town stays fed: carriers don't all go hauling to the storehouse, and nobody stands jammed at a door.
def big_town(dx:int, dy:int) -> int:
    new_world(2026, MAP, races, rules, [])
    lay_later = []
    lay_sent = []
    fields_by_script(true)  // (each farm gets its fields once built, a player's way: #122)
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
    let au = res("gold")
    var asked = false
    var iron_laid = false
    var asked_at = 0
    var next_pop = 0
    let later = [ "worker", "worker", "worker", "worker", "worker", "miner", "smelter", "sawyer", "smith", "farmer", "woodcutter", "worker", "worker", "worker", "worker" ]
    var full = 0  // sawmill ticks spent standing with its planks not taken away
    var mill_ticks = 0
    var stuck_most = 0
    let col_seat = find(hook_unit_names) n: n == "seat"
    let sat = []::int  // those who sat down at the inn
    var on_road = 0    // a carrier's moving ticks with a load, on a road cell and not (#138)
    var off_road = 0
    var off_line = 0  // of the road ticks, those off the lines through its tiles' centres (cutting across it at an angle)
    var h = 0
    for(48 * 60 * TICK_HZ) t:  // (at the genre's pace, going inside at each drop by the door: #139, #140, #157)
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
        if t == 90 and lay("coal_mine", sx - 1, sy + 3): laid++
        if t == 100 and lay("iron_mine", sx + 3, sy): laid++  // (the mines early, while the seams are clear: the camps' doors and roads crowd round them later)
        if t == 2950 and lay("gold_mine", start_x[0] / TILE + 16, start_y[0] / TILE - 2): laid++
        if not iron_laid and done_of("gold_smelter") != 0:  // (once the gold smelter is up, so the first smelter trained goes there: it pays the school)
            iron_laid = true
            if lay("iron_smelter", tx + 9, ty + 9): laid++
        if t == 3200 and lay("gold_smelter", tx + 13, ty + 9): laid++
        if t == 3400 and lay("armoury", tx + 9, ty - 6): laid++
        if t == 3500 and lay("farm", tx - 8, ty + 8): laid++
        let school = done_of("school")
        if school != 0 and trained == 0:
            trained = 1
            trained_at = t
            for([ "woodcutter", "stonecutter", "sawyer", "farmer", "miller", "baker", "miner", "miner", "smelter", "worker", "worker", "worker", "worker", "worker", "worker" ]) slot: issue_cmd(0, CMD_TRAIN, []::int, school, type_of_slot(0, slot), 1, 0)
        if t > trained_at + 100 and trained == 1 and b_queue[b_index_of(school)].length == 0:  // (a school teaches 15 at most at a time)
            trained = 2
        // Then one at a time as the gold comes in (#116): the starting gold pays for the first of them, the
        // town's own smelted gold for the rest.
        if trained == 2:  // (one at a time, each struck off once it has joined the town)
            let q = b_queue[b_index_of(school)].length
            if asked and pop[0] >= next_pop:
                later.remove(0)
                asked = false
                if not later.length: trained = 3
            elif asked and q == 0 and t > asked_at + 60: asked = false
            if trained == 2 and not asked and q == 0 and stock[au][0] >= 10:
                issue_cmd(0, CMD_TRAIN, []::int, school, type_of_slot(0, later[0]), 1, 0)
                asked = true
                asked_at = t
                next_pop = pop[0] + 1
        lay_step()
        for(b_id.length) b:
            if b_owner[b] == 0 and b_done[b] != 0 and bt_name[b_kind[b]] == "sawmill" and hook_building_get(col_present, b) != 0:
                mill_ticks++
                if b_make[b] == 0 and out_full(b, pl): full++
        for(u_x.length) i:
            if u_owner[i] == 0: stuck_most = max(stuck_most, u_stuck[i])
            if u_owner[i] == 0 and t_carrier[u_kind[i]] != 0 and u_carry[i] > 0 and u_moving[i] != 0 and t > 6000:  // (once the roads are laid)
                if road.length and road[cell_of(u_x[i], u_y[i])] > 0:
                    on_road++
                    if min(abs(u_x[i] % TILE - TILE / 2), abs(u_y[i] % TILE - TILE / 2)) > TILE / 5: off_line++
                else: off_road++
            if u_owner[i] == 0 and hook_unit_get(col_seat, i) != 0 and not contains(sat, u_id[i]): sat.push(u_id[i])
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
    let road_pct = on_road * 100 / max(1, on_road + off_road)
    let line_pct = off_line * 100 / max(1, on_road)
    print "steading: big town +{dx},{dy}: carriers with a load walked on roads {road_pct}% of the time, {line_pct}% of that off the middle of the road"
    check(road_pct >= 75 and line_pct <= 15, "steading: a big town (+{dx},{dy}): carriers keep to the roads and walk down their middle, as the genre\'s serfs do ({road_pct}% of their loaded walking on roads, {line_pct}% of that off the middle; #138)")
    print "steading: big town +{dx},{dy}: {pop[0]} people, gold smelted {produced[au][0]}, {stock[au][0]} in store"
    check(pop[0] >= 30 and produced[au][0] >= 50, "steading: a big town (+{dx},{dy}) grows past 25, paying the school with the gold it smelts ({pop[0]} people, {produced[au][0]} gold smelted)")
    check(laid == 17 and built == 17, "steading: a big town (+{dx},{dy}) builds all seventeen of its buildings ({built} of {laid}; not {unbuilt})")
    check(staffed == 15, "steading: a big town (+{dx},{dy}): every trade trained goes to work at its own ({staffed} of 15; not {idle_trades})")
    check(full_pct <= 20, "steading: a big town (+{dx},{dy}): its sawmills\' planks are carried off, not left to stop them ({full_pct}% of the time full)")
    check(hungry * 4 <= pop[0] and produced[br][0] > 0, "steading: a big town (+{dx},{dy}) keeps its people fed ({hungry} of {pop[0]} resting hungry)")
    check(produced[tl][0] > 0, "steading: a big town (+{dx},{dy}) forges tools ({produced[tl][0]})")
    check(sat.length >= 5, "steading: a big town (+{dx},{dy}): its first people get hungry after 20 minutes or so and sit down at the inn ({sat.length} sat)")
    return h

// Smelting and the smithy (#102), on their own: a storehouse given ore, coal and planks but no tools. The smelters
// make iron and gold, the smithy makes tools from iron and planks, and a farmer trained with no tools in store waits,
// then goes to its farm once the smithy's tools are in. Whether all of that happened, and the hash.
def metal_chain() -> int:
    new_world(2026, MAP, races, rules, [])
    lay_later = []
    lay_sent = []
    fields_by_script(false)
    bt_after = map(bt_after) _: []::int  // (unlocks off: this one checks a chain on its own, not the order they open in)
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
        lay_step()
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
    lay_later = []
    lay_sent = []
    fields_by_script(false)
    bt_after = map(bt_after) _: []::int  // (unlocks off: this one checks a chain on its own, not the order they open in)
    let tc = 0
    let br = res("bread")
    let pg = res("pig")
    let sa = res("sausage")
    hold_take(tc, br, b_hold[tc][br])
    for([ "plank", "stone", "grain" ]) g, j: hold_put(tc, res(g), [ 60, 30, 60 ][j])
    let sausages0 = all_of(sa)  // (the stocked start's)
    let tx = start_x[0] / TILE
    let ty = start_y[0] / TILE
    var laid = 0
    var trained = false
    var h = 0
    for(20 * 60 * TICK_HZ) t:  // (at the genre's pace a pig takes two minutes, #139)
        if t == 20 and lay("school", tx - 2, ty - 6): laid++
        if t == 40 and lay("pig_farm", tx + 6, ty - 4): laid++
        if t == 60 and lay("butcher", tx - 6, ty + 3): laid++
        let school = done_of("school")
        if school != 0 and not trained:
            for([ "swineherd", "butcher", "worker", "worker", "worker" ]) slot: issue_cmd(0, CMD_TRAIN, []::int, school, type_of_slot(0, slot), 1, 0)
            trained = true
        lay_step()
        if tick % 30 == 0: h = (h * 31 + state_hash()) & ((1 << 40) - 1)
    let eaten = sausages0 + produced[sa][0] - all_of(sa)
    print "steading: pigs: {laid} laid, pigs {produced[pg][0]}, sausages {produced[sa][0]}, {eaten} eaten"
    check(laid == 3 and done_of("pig_farm") != 0 and done_of("butcher") != 0, "steading: a pig farm and a butcher go up ({laid} laid)")
    check(produced[pg][0] > 0 and produced[sa][0] >= 3 and produced[sa][0] >= 3 * (produced[pg][0] - all_of(pg)) - 6, "steading: pigs are fattened on grain and made into sausages, three a pig (but those not yet butchered) ({produced[pg][0]} pigs, {produced[sa][0]} sausages)")
    check(eaten > 0, "steading: with no bread, the town eats sausages ({eaten})")
    return h

def store_planks() -> int:
    var n = 0
    for(b_id.length) b:
        if is_store(b, 0): n += b_hold[b][res("plank")]
    return n

// Fields as in the genre (#122): a farm's wheat fields and a vineyard's vines are laid a cell at a time round it, like
// roads, and a serf digs each. The farmer sows a tilled field, it ripens, he reaps it (a sheaf of grain) and sows it
// again; the winegrower picks ripe grapes, which grow again by themselves, and presses them into wine at the vineyard.
// A farm with twelve fields, one with four and one with none, and a vineyard with six vines, for 20 minutes.
def fields():
    new_world(2026, MAP, races, rules, [])
    lay_later = []
    lay_sent = []
    fields_by_script(false)
    bt_after = map(bt_after) _: []::int  // (unlocks off)
    let tx = start_x[0] / TILE
    let ty = start_y[0] / TILE
    let at_ = [ [ 7, -5 ], [ -8, -5 ], [ 7, 6 ], [ -8, 6 ] ]
    for([ "farm", "farm", "farm", "vineyard" ]) id, n: check(lay(id, tx + at_[n][0], ty + at_[n][1]), "steading: a {id} is laid")
    for(8 * 60 * TICK_HZ):
        if (filter(b_id.length) b: b_owner[b] == 0 and b_done[b] != 0 and (bt_name[b_kind[b]] == "farm" or bt_name[b_kind[b]] == "vineyard")).length < 4: lay_step()
    let places = filter(b_id.length) b: b_owner[b] == 0 and (bt_name[b_kind[b]] == "farm" or bt_name[b_kind[b]] == "vineyard")
    check(places.length == 4 and (filter(places) b: b_done[b] != 0).length == 4, "steading: the three farms and the vineyard go up")
    // their fields: a block to the left of each (twelve, four, none; six vines), and the trades to work them
    let sizes = [ [ 4, 3 ], [ 2, 2 ], [ 0, 0 ], [ 3, 2 ] ]
    let blocks = map(places) b, n: field_block(b, if bt_name[b_kind[b]] == "farm": "wheat_field" else: "vine_field", sizes[n][0], sizes[n][1])
    let laid = map(places) b, n: if blocks[n].length: lay_fields(if bt_name[b_kind[b]] == "farm": "wheat_field" else: "vine_field", blocks[n][0] % W, blocks[n][0] / W, sizes[n][0], sizes[n][1]) else: 0
    for([ "farmer", "farmer", "farmer", "winegrower" ]) slot: add_unit(0, type_of_slot(0, slot), start_x[0], start_y[0] + TILE * 3)
    let tilled = str_index(tr_names, "tilled")
    let sown = str_index(tr_names, "wheat_sown")
    let ripe = str_index(tr_names, "wheat_ripe")
    let young = str_index(tr_names, "vines_young")
    let grapes = str_index(tr_names, "vines_ripe")
    let was = map(W * H) c: terrain[c]
    let reaped = map(places) _: 0  // ripe wheat (or grapes) gone from each one's own block
    var sown_seen = 0
    var dug_by = -1  // the tick every field had been dug
    for(20 * 60 * TICK_HZ) t:
        lay_step()
        for(blocks) cells, n:
            for(cells) c:
                if was[c] != terrain[c]:
                    if (was[c] == ripe and terrain[c] == tilled) or (was[c] == grapes and terrain[c] == young): reaped[n]++
                    if terrain[c] == sown: sown_seen++
                    was[c] = terrain[c]
        if dug_by < 0 and (find(blocks) cells: (find(cells) c: terrain[c] != tilled and terrain[c] != sown and terrain[c] != ripe and terrain[c] != young and terrain[c] != grapes) >= 0) < 0: dug_by = t
    let wine = res("wine")
    print "steading: fields: {laid} laid, all dug by {dug_by / TICK_HZ} s, {sown_seen} sown, reaped {reaped}, grapes picked {gathered[res("grapes")][0]}, wine pressed {produced[wine][0]}"
    check(laid[0] == 12 and laid[1] == 4 and laid[2] == 0 and laid[3] == 6 and dug_by >= 0 and dug_by <= 3 * 60 * TICK_HZ,
          "steading: fields are laid a cell at a time round a farm and a vineyard, and serfs dig them within 3 minutes ({laid}, by {dug_by / TICK_HZ} s)")
    check(sown_seen >= 16 and reaped[0] >= 12 and reaped[1] >= 4 and reaped[0] >= 2 * reaped[1] and reaped[2] == 0,
          "steading: the farmer sows his own fields and reaps them once ripe; more fields grow more grain, and a farm with none grows nothing (sown {sown_seen}, reaped {reaped})")
    check(reaped[3] >= 6 and produced[wine][0] >= 4, "steading: the winegrower picks his vines, which grow their grapes again, and presses them into wine ({reaped[3]} picked, {produced[wine][0]} wine)")

// The inn as in the genre (#132): six seats at its table. Ten starved people go to eat at once: six sit down, the rest
// wait for a seat. Each sits over one food at a time, the most filling first (a sausage before a loaf), never two of
// the same at one sitting, and gets up once full or once the inn has nothing more for them.
def inn_seats():
    new_world(2026, MAP, races, rules, [])
    lay_later = []
    lay_sent = []
    fields_by_script(false)
    bt_after = map(bt_after) _: []::int  // (unlocks off)
    let tc = b_index_of(done_of("town_center"))
    let br = res("bread")
    let sa = res("sausage")
    let wi = res("wine")
    let tx = start_x[0] / TILE
    let ty = start_y[0] / TILE
    check(lay("inn", tx + 6, ty - 1), "steading: an inn is laid by the storehouse")
    for(3 * 60 * TICK_HZ):
        if done_of("inn") == 0: lay_step()
    let inn = b_index_of(done_of("inn"))
    check(inn >= 0, "steading: the inn goes up")
    for([ br, sa, wi ]) r:
        hold_take(tc, r, b_hold[tc][r])  // (only what the inn holds is eaten)
        b_want[inn][r] = 0
        hold_take(inn, r, b_hold[inn][r])
    hold_put(inn, sa, 4)
    hold_put(inn, br, 12)
    hold_put(inn, wi, 3)
    while(filter(u_x.length) i: u_owner[i] == 0).length < 10: add_unit(0, type_of_slot(0, "worker"), start_x[0], start_y[0] + TILE * 3)
    let col_meal = find(hook_unit_names) n: n == "meal"
    let col_seat = find(hook_unit_names) n: n == "seat"
    let life = gint(gobj(gobj(rules, "economy"), "hunger"), "life", 0) * TICK_HZ
    for(u_x.length) i:
        if u_owner[i] == 0: hook_unit_set(col_meal, i, life + 1)  // (their bars empty: 1 + the ticks used up)
    var most = 0
    var full_and_waiting = false
    var seen_seated = false             // someone at the table drawn or in the crowd outside
    let sat_for = map(u_x.length) _: 0  // ticks each has sat so far, this sitting
    var shortest = 1 << 30              // the shortest sitting, in ticks, per food eaten at it
    let ate_at = map(u_x.length) _: 0   // sittings each has had
    for(90 * TICK_HZ):
        lay_step()
        var seated = 0
        var waiting = 0
        for(u_x.length) i:
            if u_task[i] == T_EAT and u_target[i] == b_id[inn]:
                if col_seat >= 0 and hook_unit_get(col_seat, i) != 0:
                    seated++
                    sat_for[i]++
                    if not is_inside(i, inside_col()): seen_seated = true
                elif u_moving[i] == 0: waiting++
            elif sat_for[i] > 0:
                shortest = min(shortest, sat_for[i])
                sat_for[i] = 0
                ate_at[i]++
        most = max(most, seated)
        if seated == 6 and waiting > 0: full_and_waiting = true
    let seats = gint(at(at(lib_data("buildings.json"), "buildings"), "inn"), "seats", 0)
    let eat_ticks = gint(gobj(gobj(rules, "economy"), "hunger"), "eat_secs", 0) * TICK_HZ
    print "steading: inn: {seats} seats, at most {most} sat at once, someone waiting while full {full_and_waiting}, {4 - b_hold[inn][sa]} sausages and {12 - b_hold[inn][br]} loaves eaten, shortest sitting {shortest} ticks"
    check(seats == 6 and most == 6 and full_and_waiting, "steading: the inn seats six at once and the rest wait for a seat (at most {most} sat; waiting while full {full_and_waiting})")
    check(b_hold[inn][wi] == 0, "steading: and a cup of wine after a loaf, for those not yet full (#122: {3 - b_hold[inn][wi]} of 3 drunk)")
    check(b_hold[inn][sa] == 0 and 12 - b_hold[inn][br] >= 10, "steading: they eat the sausages first, then a loaf with or after one ({4 - b_hold[inn][sa]} of 4 sausages, {12 - b_hold[inn][br]} loaves)")
    check(not seen_seated, "steading: those at the inn\'s table are inside it: not drawn, and out of the crowd at its door")
    check(eat_ticks > 0 and shortest >= eat_ticks, "steading: a meal takes its time at the table ({shortest} ticks at the shortest; a food takes {eat_ticks})")

// Through a save (#75): the mod's Lua loads again with the saved match, and its state comes back in the hook columns.
// A hut goes up and the serfs wait, carry and get hungry for 2 minutes; then 2 minutes more, once straight on and once from a save made
// there: the same hash every tick. Whether they matched, and whether anyone was hungry or ate by then.
// stop: the mod's rules stop before the save (as an error would stop them): they must stay stopped after the load.
def save_run(stop:bool) -> bool, bool:
    let path = "test_steading.sav"
    new_world(2026, MAP, races, rules, [])
    lay_later = []
    lay_sent = []
    fields_by_script(false)
    bt_after = map(bt_after) _: []::int  // (unlocks off: this one checks a chain on its own, not the order they open in)
    let tx = start_x[0] / TILE
    let ty = start_y[0] / TILE
    for(2 * 60 * TICK_HZ) t:
        if t == 40: lay("lumber_camp", tx + 6, ty - 4)
        lay_step()
    if stop:
        let pk = l_packs[find(l_packs) p: p.id == "steading"]
        pk.error = "stopped by the test"
        lx_note_stop(pk)
    assert save_world(path, [])
    let want = map(2 * 60 * TICK_HZ):
        lay_step()
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
        lay_step()
        state_hash()
    let off = l_packs[find(l_packs) p: p.id == "steading"].error != ""
    return equal(want, got) and off == stop, lively

seam_check()
// A fresh town (#124): only the first buildings are open; a building laid with no road gets a road plan at its door by
// itself; a site whose goods aren't there is built to its foundation (rules foundation_pct) and no further, a serf
// waiting at it, and finished once the goods come.
def start_rules():
    new_world(2026, MAP, races, rules, [])
    lay_later = []
    lay_sent = []
    fields_by_script(false)
    let sc = btype_index("school")
    check(not build_barred(0, sc) and build_barred(0, btype_index("lumber_camp")) and build_barred(0, btype_index("sawmill")) and build_barred(0, btype_index("iron_smelter")),
          "steading: a fresh town can lay a school, not a woodcutter\'s hut, a sawmill or a smelter before what comes first")
    let tc = b_index_of(done_of("town_center"))
    let pl = res("plank")
    let st = res("stone")
    let kept = [ b_hold[tc][pl], b_hold[tc][st] ]
    b_hold[tc][pl] = 0  // (the store emptied of what the school is built of)
    b_hold[tc][st] = 0
    let id = lay_foundation(0, []::int, sc, start_x[0] / TILE - 2, start_y[0] / TILE - 6)
    check(id != 0, "steading: a school is laid with no road to it")
    let b = b_index_of(id)
    var door_road = false
    var waited = false
    for(60 * TICK_HZ):
        lay_step()
        if is_road_at(door_of(b)): door_road = true
        if (find(u_x.length) i: u_task[i] == BUILD and u_target[i] == id) >= 0 and b_progress[b] > 0: waited = true
    let cap = bt_build_ticks[sc] * r_foundation_pct / 100
    check(door_road, "steading: the tile in front of a door gets a road plan by itself")
    check(r_foundation_pct > 0 and b_progress[b] == cap and b_done[b] == 0 and waited,
          "steading: with no goods a site is built to its foundation and no further, a serf waiting at it ({b_progress[b]} of {cap}, waited {waited})")
    b_hold[tc][pl] = kept[0]
    b_hold[tc][st] = kept[1]
    for(3 * 60 * TICK_HZ):
        if b_done[b] == 0: lay_step()
    check(b_done[b] != 0 and not build_barred(0, btype_index("lumber_camp")) and build_barred(0, btype_index("sawmill")),
          "steading: the goods come and the school is finished, which opens the woodcutter\'s hut but not yet the sawmill")

// Builders aren't starved by hauling (Dominic, #124): with serfs busy carrying for many sites at once, every site still
// gets a builder soon after it's laid (a serf on its way to fetch something is taken off it for a site nobody builds).
def busy_sites():
    new_world(2026, MAP, races, rules, [])
    lay_later = []
    lay_sent = []
    fields_by_script(false)
    let sc = btype_index("school")
    let tx = start_x[0] / TILE
    let ty = start_y[0] / TILE
    let ids = []::int
    for(15) gy:
        for(15) gx:
            if ids.length < 6:
                let id = lay_foundation(0, []::int, sc, tx - 14 + gx * 2, ty - 14 + gy * 2)
                if id != 0: ids.push(id)
    let first = map(ids) _: -1  // the tick each site first had a builder
    var hauling = false
    for(60 * TICK_HZ) t:
        lay_step()
        if (find(u_x.length) i: u_owner[i] == 0 and u_task[i] == T_CARRY) >= 0: hauling = true
        for(ids) id, n:
            if first[n] < 0 and (find(u_x.length) i: u_task[i] == BUILD and u_target[i] == id) >= 0: first[n] = t
    let slowest = fold(first, 0) a, f: if f < 0 or a < 0: -1 else: max(a, f)
    check(ids.length == 6 and hauling and slowest >= 0 and slowest <= 20 * TICK_HZ,
          "steading: six sites laid at once while serfs haul for them each get a builder within 20 s ({ids.length} laid, the slowest at {slowest} ticks: {first})")

// Woods as in the genre (#126): a tree is one trunk, felled and carried home whole; a sapling grows into a tree after
// its time (terrain.json "grows"), through a save too; and a woodcutter with no grown tree in reach plants saplings.
def woods():
    new_world(2026, MAP, races, rules, [])
    lay_later = []
    lay_sent = []
    fields_by_script(false)
    let tree = str_index(tr_names, "tree")
    let sap = str_index(tr_names, "sapling")
    let grass = str_index(tr_names, "grass")
    check(tree >= 0 and tr_amount[tree] == 1 and r_carry_of[res("wood")] == 1, "steading: a tree is one trunk, and a woodcutter carries one home at a time")
    // A sapling planted by hand grows into a tree after 10 minutes, saved and loaded halfway.
    let c = find(W * H) cc: terrain[cc] == grass and occupied[cc] == 0 and can_plant(cc, sap)
    check(sap >= 0 and tr_grows[sap] == tree and plant(c, sap) and not plant(c, sap) and not plant(c, grass), "steading: a sapling is planted on open grass once, and grass doesn\'t grow")
    let due = tick + tr_grow_ticks[sap]
    for(tr_grow_ticks[sap] / 2): wstep()
    let path = "test_steading_woods.sav"
    assert save_world(path, [])
    reset_world()
    lua_reset()
    lua_on = false
    lua_rules = jobj()
    load_world(path)
    delete_file(path)
    var early = false
    while tick <= due + TICK_HZ:
        if tick < due and terrain[c] != sap: early = true
        wstep()
    check(tr_grow_ticks[sap] == 600 * TICK_HZ and not early and terrain[c] == tree and amount[c] == 1, "steading: the sapling is a tree of one trunk 10 minutes on, through a save (now {tr_names[terrain[c]]})")
    // A woodcutter whose trees are all felled plants saplings round his hut, and fells them once they've grown.
    new_world(2026, MAP, races, rules, [])
    lay_later = []
    lay_sent = []
    fields_by_script(false)
    let tx = start_x[0] / TILE
    let ty = start_y[0] / TILE
    lay("school", tx - 2, ty - 6)
    lay("lumber_camp", tx + 6, ty - 4)
    var trained = false
    var cleared = false
    var most_saplings = 0
    var cut_after = 0
    var grown = 0
    for(16 * 60 * TICK_HZ):
        lay_step()
        let school = done_of("school")
        if school != 0 and not trained:
            issue_cmd(0, CMD_TRAIN, []::int, school, type_of_slot(0, "woodcutter"), 1, 0)
            trained = true
        let hut = b_index_of(done_of("lumber_camp"))
        if hut >= 0 and not cleared:  // (the woods round the hut felled at once: nothing left in reach)
            cleared = true
            for(W * H) cc:
                if terrain[cc] == tree and abs(cc % W - (b_cx[hut] + 1)) <= 9 and abs(cc / W - (b_cy[hut] + 1)) <= 9: set_terrain(cc, str_index(tr_names, "stump"))
            cut_after = gathered[res("wood")][0]
        if hut >= 0 and tick % TICK_HZ == 0:
            var n = 0
            var t = 0
            for(W * H) cc:
                if abs(cc % W - (b_cx[hut] + 1)) <= 9 and abs(cc / W - (b_cy[hut] + 1)) <= 9:
                    if terrain[cc] == sap: n++
                    if terrain[cc] == tree: t++
            most_saplings = max(most_saplings, n)
            grown = max(grown, t)
    let cut = gathered[res("wood")][0] - cut_after
    check(cleared and most_saplings >= 3 and most_saplings <= 6 and grown >= 1 and cut >= 1,
          "steading: a woodcutter with no trees in reach plants saplings (at most {most_saplings}), they grow ({grown} trees) and he fells them ({cut} trunks)")

fields()
inn_seats()
start_rules()
busy_sites()
woods()
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
