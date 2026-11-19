// Age of Anything in Lobster (docs/milestones/lobster-port.md): the ported sim and bots, the art
// from a match pack (art_pack.gd), a window to play in. You are player 0; the ported bot plays the
// rest ("watch": the bot plays you too).
// Run: lobster game.lobster -- <pack dir> <scenario file, or - to make the start from the pack\'s races> [watch]
//   left click / drag: select;  right click: move, attack, gather, build, rally;  shift: queue
//   Ctrl + right click: attack-move;  X: stop;  B then 1-9: build;  1-9 on a building: train;  U: age up
//   Q E R T Y F G H J on a building: research;  M: sound on / off;  the minimap (bottom right): click to look there
//   WASD / arrows / screen edges: scroll;  wheel: zoom;  space: pause;  + / -: speed;  Ctrl/Cmd + / -: the HUD's size

import from "../creel/src"
import std
import vec
import color
import gl
import texture
import dictionary
import .lib.consts
import .lib.fixed
import .lib.tokens
import .lib.state
import .lib.flow
import .lib.spatial
import .lib.orders
import .lib.movement
import .lib.steering
import .lib.fog
import .lib.map
import .lib.economy
import .lib.tech
import .lib.combat
import .lib.siege
import .lib.eco_bot
import .lib.garrison
import .lib.heal
import .lib.heroes
import .lib.match
import .lib.trade
import .lib.recipes
import .lib.carry
import .lib.animals
import .lib.bridges
import .lib.walls
import .lib.abilities
import .lib.trails
import .lib.commands
import .lib.ai_cfg
import .lib.scout
import .lib.land
import .lib.expand
import .lib.bot
import .lib.walls_ai
import .lib.world
import .gen.json
import .gen.sha256
import .gen.rng
import .gen.datalib
import .gen.identity
import .gen.effect_words
import .gen.mods
import .gen.pricing
import .gen.heroes
import .gen.generator
import .hooks.active
import .hooks.rules
import .gen.setup
import .gen.race_to_types
import .gen.modes
import .gen.start
import .hooks.economy
import .view.facing
import .view.shot_look
import .view.node
import .view.art
import .view.png
import .view.bake_cache
import .view.atmosphere
import .gen.reset
import .gen.balance
import .gen.swap
import .gen.save
import .net.lockstep
import .net.lan
import .net.swarm
import .net.room
import .game.audio
import .game.pack
import .game.relief
import .game.fog_look
import .game.ground
import .game.doodads
import .game.paths
import .game.fx
import .game.topbar_fit
import .game.text_field
import .game.ui
import .game.view_state
import .game.text_cache
import .game.levels
import .game.perf
import .game.pace
import .game.window_mode
import .game.window_switch

let args = command_line_arguments()
// Options after the two paths: watch (the bot plays you too), speed:<x>, shot:<png> with at:<seconds>
// (a screenshot after that much play, then quit), look:<x>,<y> (the camera on that tile).
var follow = false        // the camera follows the fighting (captures)
var look_at_army = false  // a skirmish you play: the camera starts on your army and stays yours
var selftest = false      // play a few orders through the controls, check the sim took them, quit
var airtest = false       // does a click on an aircraft, where it's drawn, take it? Then quit (#185)
var shot_at = 0.0
var start_speed = 1.0
var look_x = -1
var swap_arg = ""  // swap:<prompt>@<seconds>: become that race then (tests and captures)
var swap_at = -1.0
var rules_arg = ""            // rules:<id>: the host rules (else the pack's)
var mods_arg = ""             // mods:a,b: mods to merge over the data (else the pack's)
var lobby_rerolls = [ 0, 0 ]  // each side's reroll (the generator's other takes on the same prompt)
var rebake_art = false        // rebake: every prop baked in Lobster, even those the pack has
var mesh_dir = ""             // meshes:<dir>: the mesh library (mesh_export.gd library): parts the pack lacks are baked here
var mode_arg = ""             // mode:<id>: the lobby's game mode (data/modes.json)
var map_arg = ""              // map:<id>: the lobby's map (tests and captures)
var races_arg = ""            // races:<A>|<B>: the lobby's prompts, as if typed (then played)
var look_y = -1
var rec_type = []::string  // typein:A|B: (filming the lobby)
var rec_side = 0
var rec_char = 0
var rec_wait = 30
var window_arg = int2 { 1600, 1000 }  // window:<w>,<h>: the window's size in points (filming: 1280,720 is 16:9, 2560x1440 frames on a Mac)
var fort_gate = int2 { -1, -1 }       // place:fort's gate (captures: army: walks through it)
var place_arg = ""                    // place:<building>: one finished by your Town Center at the start; fort, palisade_fort: a wall line (captures)
var skirmish = false                  // the lobby's Skirmish: both armies on the map at once, marching on each other
var army_n = 0                        // army:<n>: n of each of your soldier types by your Town Center at the start (captures)
var army_snap = false                 // a skirmish's armies start in their blocks, once the first order has made them
let ARMY_GAP = 600                    // milli-tiles between them, in ranks
var zoom_arg = 0.0                    // zoom:<n>: the camera at that zoom at the start, 1 the farthest out (filming)
var density_arg = 0.0                 // density:<z>: prebake at that art density (prebake.sh: the base, then a Retina Mac's 2.4, #358)
var hurt_pct = -1                     // hurt:<percent>: your buildings start at that much of their hit points (captures of fire)
var page_arg = ""                     // page:<name>: the lobby opened on that page (title, setup, lab, saves, net; boot: the boot screen), captures with shot:
var lab_arg = false                   // lab: the lobby with races:A|B typed in, a picture (shot:) after a second, then quit
var tree_arg = false                  // tree: the tech tree page open from the start (captures)
var tree_hover_arg = ""               // treehover:<node key>: that node hovered on it (captures: "r:fletching", "u:hero.<id>@3")
var padtest = false                   // padtest: a fake pad plays a few seconds, then quit
var net_people = 2                    // people in a network match (host:<n>)
var net_others = []::Link             // a host's joiners after the first
var net_seats = []::int               // the people's sides, from the lobby's room (#519); []: the first net_people
var hosting = false                   // host: a network match, waiting for a player to join (net/lockstep.lobster)
var join_ip = ""                      // join:<ip or join code>: play the second side of the match a host there sets up
var reload_at = -1.0                  // reload:<seconds>: save then, load 5 s later (tests and captures)
var reload_tick = -1
var atmo_arg = ""  // atmosphere:<mood>: the match in that mood (data/atmosphere.json; <a>~<b>@<t>: between two, game/mood.lobster), atmosphere:off: none (the frame drawn straight)
// A mod can say how it starts (its manifest's `launch`): those options, as if typed after the rest.
for(copy(args)) a:
    if starts_with(a, "mods:"):
        for(mods_launch_args(tokenize(a.substring(5, a.length - 5), ",", ""))) option: args.push(option)
for(args) a, k:
    if k >= 2:
        if a == "watch": watch = true
        if a == "touch":
            touch_play = true
            ui_touch = true
        let key, val = split_string(a, ":")
        if key == "shot": shot = val
        if key == "fsat": window_toggles = map(tokenize(val, ",", " ")) t: string_to_float(t)
        if key == "fsreport": window_report = val
        if key == "at": shot_at = string_to_float(val)
        if key == "record": rec_dir = val
        if key == "typein": rec_type = tokenize(val, "|", " ")
        if key == "from": rec_from = string_to_float(val)
        if key == "for": rec_for = string_to_float(val)
        if key == "fps": rec_fps = string_to_float(val)
        if key == "push": rec_push = string_to_float(val)
        if key == "pan":
            let px, py = split_string(val, ",")
            rec_pan = float2 { string_to_float(px), string_to_float(py) }
        if key == "window":
            let wx, wy = split_string(val, ",")
            window_arg = int2 { string_to_int(wx), string_to_int(wy) }
        if a == "clean": rec_clean = true
        if key == "perf": perf_for = string_to_float(val)  // (game/perf.lobster: the drawing's cost in the window)
        if key == "zoom": zoom_arg = string_to_float(val)
        if key == "density": density_arg = string_to_float(val)
        if a == "reveal": reveal = true
        if a == "perflive": perf_live = true
        if a == "oldtext": text_off = true  // (measuring: text drawn as before game/text_cache.lobster)
        if key == "speed": start_speed = string_to_float(val)
        if a == "selftest": selftest = true
        if a == "airtest": airtest = true
        if a == "follow": follow = true
        if key == "races": races_arg = val
        if key == "map": map_arg = val
        if key == "mode": mode_arg = val
        if key == "reroll": lobby_rerolls = map(tokenize(val, "|", " ")) r: string_to_int(r)
        if key == "rules": rules_arg = val
        if key == "meshes": mesh_dir = val
        if a == "rebake": rebake_art = true
        if key == "mods": mods_arg = val
        if key == "atmosphere": atmo_arg = val
        if key == "reload": reload_at = string_to_float(val)
        if a == "host": hosting = true
        if key == "host":  // host:<n>: n people (more than two: a 2v2 on the four-player map)
            hosting = true
            net_people = max(2, string_to_int(val))
        if a == "padtest": padtest = true
        if a == "skirmish": skirmish = true
        if a == "tree": tree_arg = true
        if key == "treehover":
            tree_arg = true
            tree_hover_arg = val
        if a == "lab": lab_arg = true
        if key == "page": page_arg = val
        if key == "hurt": hurt_pct = string_to_int(val)
        if key == "raze": raze_at = string_to_float(val)
        if key == "army": army_n = string_to_int(val)
        if key == "place": place_arg = val
        if key == "join": join_ip = val
        if key == "dht": swarm_setup.extra = "--bootstrap " + val  // dht:<host:port>: online play on a local test DHT (creel/sidecar/test/testnet.js)
        if key == "swap":
            let sp, sa = split_string(val, "@")
            swap_arg = sp
            swap_at = string_to_float(sa)
        if key == "look":
            let lx, ly = split_string(val, ",")
            look_x = string_to_int(lx)
            look_y = string_to_int(ly)

// Tests and captures are silent (Dominic: no sound from testing); `mute` silences a game too.
if has_s(args, "mute") or shot != "" or rec_dir != "" or selftest or airtest or padtest or has_s(args, "labtest") or reload_at >= 0.0 or perf_for > 0.0:
    sound_on = false
    pace_background = false  // (tests and captures keep their pace with the window in the background, game/pace.lobster)

import .game.world_view
import .model.kit
import .model.grng
import .model.base
import .model.flat
import .model.props
import .model.town_props
import .model.bridges
import .model.build_mats
import .view.voxel_mesh
import .view.voxel_grid
import .model.trees
import .model.rocks
import .model.buildings
import .model.future
import .model.buildings2
import .game.art_kit
import .game.ruin
import .game.model_type
import .game.art_kit_buildings
import .game.pack_data
import .view.vox
import .view.voxel
import .game.voxel_units

import .game.town  // (here: it uses the views)
import .game.glows
import .game.world_draw
import .game.match_loop

// Each side's paths (sim_debug._refresh_paths): from its biggest finished building's door to its other
// finished buildings and the nearest food and wood; the hub and resource ends picked once. An
// enemy's only run between the buildings you've seen. Re-planned when the finished count changes.
def refresh_paths() -> bool:
    var count = 0
    let owners = []::PathOwner
    for(su_races) race, p:
        let mine = []::int
        for(b_id.length) b:
            if b_owner[b] == p and b_done[b] == 1 and not wall_like(b) and (teams[p] == teams[ME] or fog[ME][b_cy[b] * W + b_cx[b]] != 0):
                mine.push(b)
        count += mine.length
        if mine.length:
            insertion_sort(mine) a, b: b_sx[a] * b_sy[a] > b_sx[b] * b_sy[b] or (b_sx[a] * b_sy[a] == b_sx[b] * b_sy[b] and b_id[a] < b_id[b])
            let st = gobj(family(rstr(race, "family")), "paths")
            if path_anchor_hub.get(p, float2 { -9.0, -9.0 }).x < -8.0:
                let at = door_of(mine[0])
                let res = []::float2
                for([ "food", "wood" ]) kind:
                    let t = nearest_resource_edge(str_index(resource_names, kind) + 1, at)
                    if t.x >= 0.0: res.push(t)
                path_anchor_hub.set(p, at)
                path_anchor_res.set(p, res)
            let hub = path_anchor_hub.get(p, float2_0)
            let targets = []::float2
            for(mine) b:
                if door_of(b) != hub: targets.push(door_of(b))
            for(path_anchor_res.get(p, [])) t: targets.push(t)
            let w = get(st, "width")
            owners.push(PathOwner { gstr(st, "style", "trail"), if w: as_float(w) else: 0.36, hub, targets })
    if count == path_count: return false
    path_count = count
    path_plan(owners)
    paint_paths()
    return true

// ------------------------------------------------------------------ the lobby (type your races; Lobster makes and sets them up)
// Two prompts, each race shown as you type (the generator takes a few milliseconds); Enter starts the
// match at the generator's prices, calibrated offline (src/calibrate.lobster, D-195): no fights at load.
// The units are drawn from the part library (art_pack.gd library).

def rules_id() -> string: return if rules_arg != "": rules_arg else: pack_rules
var lobby_map = "reed_meadow"
let MODE_IDS = [ "standard", "fortress", "siege" ]  // data/modes.json (gen/modes.lobster)
var lobby_mode = "standard"
var lobby_prompts = []::string  // each side's words (the lobby's, or races:A|B)
var lobby_teams = []::int       // each side's team (a team game from the lobby)
var lobby_levels = []::string   // each side's AI level ("" for a person)
var front_shown = false         // the lobby's pages were up (the match loader shows their armies)

// The maps a match can be on (data/maps).
def map_ids() -> [string]:
    let names = scan_folder("../data/maps", false)
    let out = []::string
    if names:
        for(names) n:
            if ends_with(n, ".json"): out.push(substring(n, 0, n.length - 5))
    return sorted_strs(out)

import .game.mood

// The map's tree species per cell
// (and every table the pack lacks, from data: game/pack_data.lobster; the species worked out as Godot's LandView
// does, species_check.lobster)
def load_species(map_id:string):
    species = species_from_map(map_id)
    pack_from_data(map_id)
    let atmo = lib_data("atmosphere.json")  // (the mood: the asked one, the map's, else the default; an unknown one stops the game)
    let bad = atmo_set_asked(atmo, atmo_mood_for(atmo, map_id, atmo_arg))
    if bad != "": fatal_exit(bad)

def lobby_text(p:float2, s:string, col:float4): text_label(p, s, gl.get_font_size(), col, TEXT_FACE, 0.0, float4_0)

// A filled box from its top-left corner (gl.rect draws -size..size round its point in this build).
def box(at:float2, size:float2, col:float4): ui_fill(at, size, col)

// The Race Lab's Test: rounds of the round robin in age 2 between its races, each line's win rate and the
// price the fights would give it (gen/balance.lobster), shown as it goes. Returns the report. (A match
// never runs it: prices are calibrated offline, D-195.)
def balance_for_match(races:[JV], rules:JV, rounds:int) -> [string]:
    let report = []::string
    let t0 = seconds_elapsed()
    let stop = false
    auto_balance(races, rules, 2, rounds, 10) round, units, rates, mean, off:
        report.push("round {round + 1}: {off} of {units.length} lines more than 10 points off the mean ({rr_fights} fights, {seconds_elapsed() - t0} s)")
        gl.frame()
        if front_shown:  // (from the lobby's pages: the match loader, game/lobby.lobster)
            fe_loader("Balancing the armies by fighting them: round {round + 1} of {rounds}", 0.05 + 0.45 * float(round + 1) / float(rounds))
        else:
            gl.clear(float4 { 0.07, 0.06, 0.05, 1.0 })
            gl.set_shader("color")
            let u = ui()
            gl.set_font_size(int(26.0 * u))
            lobby_text(float2 { 40.0 * u, 40.0 * u }, "Balancing the armies by fighting them...", float4 { 0.95, 0.85, 0.6, 1.0 })
            gl.set_font_size(int(16.0 * u))
            for(report) line, n: lobby_text(float2 { 40.0 * u, 100.0 * u + float(n) * 24.0 * u }, line, float4 { 0.8, 0.78, 0.72, 1.0 })
            for(units) un, k:
                let pct = rr_price_pct.get(price_key(races, un), 100)
                lobby_text(float2 { 40.0 * u + float(k / 18) * 560.0 * u, 260.0 * u + float(k % 18) * 22.0 * u },
                           "{rates[k]}%  {un.label}" + (if pct != 100: "  price {pct}%" else: ""), float4 { 0.75, 0.72, 0.66, 1.0 })
    return report

// CombatFx.shot_kind: what a unit's shots are, by its weapon's tags.
def shot_kind_of(tags:[string]) -> string:
    for(sorted_strs(mod_shots.keys)) k:  // (a mod's look first, by its tag)
        if has_s(tags, gstr(at(mod_shots, k), "tag", "")): return k
    if has_s(tags, "great_sling"): return "sling_stone"
    if has_s(tags, "catapult"): return "boulder"
    if has_s(tags, "bolt_thrower"): return "siege_bolt"
    if has_s(tags, "javelin"): return "javelin"
    if has_s(tags, "sling"): return "stone"
    if has_s(tags, "poison"): return "dart"
    if has_s(tags, "gun"): return "ball"
    if has_s(tags, "heavy") and has_s(tags, "bow"): return "bolt"
    return "arrow"

// What the pack used to tell per race: names, voices, blow and shot sounds, architectures.
def race_facts(races:[JV]):
    voice_of = map(races) r: rstr(creature(rstr(r, "creature")), "voice")
    arch_of = map(races) r: architecture(r)
    for(t_slot.length) k:
        let r = at(su_units[k], "look")
        unit_names.set(k, gstr(r, "name", t_slot[k]))
        let tags = unit_tags(su_units[k])
        unit_blow.set(k, if has_s(tags, "ram"): "ram_hit" elif has_s(tags, "blade"): "hit_blade" elif has_s(tags, "blunt"): "hit_blunt" else: "hit_pierce")
        let kind = shot_kind_of(tags)
        unit_shotk.set(k, kind)
        unit_shot.set(k, gstr(get(lib_data("shots.json"), kind) or jobj(), "sound", "shoot_arrow"))

// ------------------------------------------------------------------ becoming another race mid-match (gen/swap.lobster)
// N: type a race; Enter: your people become it at its own prices (no fights, D-195), line by line,
// units and all, and your buildings take its style.

var banner = ""
var banner_t = -100.0

def become(prompt:string):
    let race = generate(prompt, su_rules, 0)
    let t0 = seconds_elapsed()
    let old = rstr(su_races[ME], "name")
    swap_race(ME, race)
    race_facts(su_races)
    bake_buildings_for(arch_of)  // (and its culture's buildings)
    banner = old + " become " + rstr(race, "name") + " (" + rstr(race, "creature") + ", " + rstr(race, "family") + "), in {int((seconds_elapsed() - t0) * 1000.0)} ms"
    banner_t = seconds_elapsed()
    print banner

def typing_tick():
    let text = gl.text_input_state()
    if gl.button("escape") == 1:
        typing_text = false
        gl.end_text_input()
        return
    if gl.button("return") == 1 and not window_combo():
        typing_text = false
        gl.end_text_input()
        if text != "": become(text)
        return
    let u = ui()
    let ws = float(gl.window_size())
    gl.set_shader("color")
    ui_fill(float2 { ws.x * 0.2, ws.y * 0.4 }, float2 { ws.x * 0.6, 110.0 * u }, float4 { 0.08, 0.06, 0.04, 0.92 })
    gl.set_font_size(int(18.0 * u))
    lobby_text(float2 { ws.x * 0.2 + 20.0 * u, ws.y * 0.4 + 14.0 * u }, "Your people become... (Enter: balance and change; Esc: never mind)", float4 { 0.8, 0.78, 0.7, 1.0 })
    gl.set_font_size(int(26.0 * u))
    let preview = if text != "": rstr(generate(text, su_rules, 0), "name") else: ""
    lobby_text(float2 { ws.x * 0.2 + 20.0 * u, ws.y * 0.4 + 46.0 * u }, text + (if (int(seconds_elapsed() * 2.0) % 2) == 0: "|" else: "") + (if preview != "": "    -> " + preview else: ""), float4 { 1.0, 0.95, 0.85, 1.0 })

def draw_banner():
    if seconds_elapsed() - banner_t > 8.0: return
    let u = ui()
    let ws = float(gl.window_size())
    gl.set_shader("color")
    ui_fill(float2 { 20.0 * u, 50.0 * u }, float2 { ws.x - 40.0 * u, 40.0 * u }, float4 { 0.08, 0.06, 0.04, 0.85 })
    gl.set_font_size(int(20.0 * u))
    lobby_text(float2 { 34.0 * u, 58.0 * u }, banner, float4 { 0.95, 0.85, 0.6, 1.0 })

import .game.controls

// ------------------------------------------------------------------ the self-test

var test_step = 0
var test_log = ""
var test_foe = 0  // the enemy unit the self-test looks at

def screen_of_cell(c:int) -> float2: return to_screen(iso(float((c % W) * 1000 + 500), float((c / W) * 1000 + 500)))

def expect_ok(ok:bool, what:string):
    test_log += (if ok: "PASS " else: "FAIL ") + what + "\n"
    if not ok: set_exit_code(1)  // (selftest, padtest: a failed check fails the run)

// The nearest cell to (x, y) (tiles) whose test passes, or -1.
def nearest_cell(x:int, y:int, test) -> int:
    var best = -1
    var best_d = 1 << 30
    for(W * H) c:
        if test(c):
            let d = (c % W - x) * (c % W - x) + (c / W - y) * (c / W - y)
            if d < best_d:
                best_d = d
                best = c
    return best

def self_test() -> bool:
    let tc = town_center(ME)
    let tx = b_cx[tc] + 1
    let ty = b_cy[tc] + 1
    let ws = float(gl.window_size())
    if test_step == 0 and clock_s >= 1.0:
        box_select(float2 { 1.0, 1.0 }, ws - 1.0)
        expect_ok(selected.length >= 3, "a drag over the screen selects my {selected.length} units")
        let wood = nearest_cell(tx, ty) c: res_at(c) == resource_index("wood") + 1
        let some = selected.slice(0, 2)
        selected = some
        fake_mouse = screen_of_cell(wood)
        order(fake_mouse)
        test_step++
    elif test_step == 1 and clock_s >= 2.0:
        let pick = selected_units()
        expect_ok((filter(pick) id: u_task[index_of(id)] == GATHER).length == pick.length, "right click on reeds sends the workers gathering")
        let all = filter(u_id) id: u_owner[index_of(id)] == ME and t_worker[u_kind[index_of(id)]]
        selected = [ all[all.length - 1] ]
        placing = btype_named("house")
        let spot = nearest_cell(tx, ty) c: can_place(ME, placing, c % W - 0, c / W - 0) and (c % W - tx) * (c % W - tx) + (c / W - ty) * (c / W - ty) > 9
        fake_mouse = screen_of_cell(spot)
        place_here(false)
        test_step++
    elif test_step == 2 and clock_s >= 3.0:
        expect_ok((filter(b_id.length) b: b_owner[b] == ME and bt_name[b_kind[b]] == "house").length >= 1, "B, a house and a click lays a house down")
        fake_mouse = screen_of_cell(b_cy[tc] * W + b_cx[tc] + 1)
        click_select(fake_mouse)
        expect_ok(sel_building == b_id[tc], "a click on the Town Center selects it")
        train_slot(0)
        test_step++
    elif test_step == 3 and clock_s >= 4.0:
        expect_ok(b_queue[tc].length >= 1 or pop[ME] > 3, "1 on the Town Center trains a worker")
        let army = filter(u_id) id: u_owner[index_of(id)] == ME
        selected = army.slice(0, 2)
        store_group(2)
        selected = []
        recall_group(2)
        expect_ok(selected.length == 2, "Ctrl+3 keeps two units, 3 brings them back")
        selected = army
        fake_mouse = to_screen(iso(float(tx * 1000 + 4000), float(ty * 1000 + 4000)))
        order(fake_mouse)
        test_step++
    elif test_step == 4 and clock_s >= 4.5:
        expect_ok((filter(selected_units()) id: u_moving[index_of(id)] == 1 or u_task[index_of(id)] != T_NONE).length > 0, "right click on open ground moves them")
        // two workers carrying nothing, right-clicked onto the Town Center: they go inside
        let idle = filter(u_id) id: u_owner[index_of(id)] == ME and t_worker[u_kind[index_of(id)]] != 0 and u_carry[index_of(id)] == 0
        selected = idle.slice(0, 2)
        fake_mouse = screen_of_cell(b_cy[tc] * W + b_cx[tc] + 1)
        order(fake_mouse)
        test_step++
    elif test_step == 5 and clock_s >= 9.0:
        expect_ok(b_inside[tc].length > 0, "right click on the Town Center sends workers inside ({b_inside[tc].length / REC_SIZE} in)")
        selected = []
        sel_building = b_id[tc]
        for(panel_buttons()) btn:
            if btn.act == 12: press(btn)
        test_step++
    elif test_step == 6 and clock_s >= 10.0:
        expect_ok(b_inside[tc].length == 0, "Ungarrison brings them out")
        let foe = town_center(1 - ME)
        cam = iso(float(b_cx[foe] * 1000 + b_sx[foe] * 500), float(b_cy[foe] * 1000 + b_sy[foe] * 500))
        test_step++
    elif test_step == 7 and clock_s >= 10.5:
        let foe = town_center(1 - ME)
        click_select(screen_of_cell(b_cy[foe] * W + b_cx[foe]))
        expect_ok(sel_building == 0, "a click on an enemy building in the fog selects nothing")
        reveal = true
        // (a cell of it with no unit in the way)
        let clear = find(b_sx[foe] * b_sy[foe]) n: unit_at_screen(screen_of_cell((b_cy[foe] + n / b_sx[foe]) * W + b_cx[foe] + n % b_sx[foe]), false) < 0
        fake_mouse = screen_of_cell((b_cy[foe] + clear / b_sx[foe]) * W + b_cx[foe] + clear % b_sx[foe])
        click_select(fake_mouse)
        expect_ok(sel_building == b_id[foe], "a click on a visible enemy building selects it")
        test_step++
    elif test_step == 8 and clock_s >= 11.0:
        let foe = town_center(1 - ME)
        expect_ok(panel_hp == b_hp[foe], "the panel shows the enemy building\'s HP ({panel_hp} of {b_hp[foe]})")
        let before = pending.length
        expect_ok(not panel_buttons().length, "an enemy building has no buttons")
        train_slot(0)
        order(fake_mouse)
        expect_ok(pending.length == before, "no orders for an enemy building ({pending.length - before} issued)")
        reveal = false
        test_step++
    elif test_step == 9 and clock_s >= 11.5:
        expect_ok(sel_building == 0, "an enemy building back in the fog lets go of the selection")
        reveal = true
        let foes = filter(u_id.length) i: is_foe(u_owner[i], ME) and t_animal[u_kind[i]] == 0
        let u = foes[0]
        cam = iso(float(u_x[u]), float(u_y[u]))
        test_foe = u_id[u]
        test_step++
    elif test_step == 10 and clock_s >= 12.0:
        let u = index_of(test_foe)
        fake_mouse = to_screen(iso(float(u_x[u]), float(u_y[u])) - float2 { 0.0, 14.0 })
        click_select(fake_mouse)
        expect_ok(sel_foreign == test_foe and not selected.length, "a click on a visible enemy unit shows it, and doesn\'t select it")
        test_step++
    elif test_step == 11 and clock_s >= 12.5:
        let u = index_of(test_foe)
        expect_ok(panel_hp == u_hp[u], "the panel shows the enemy unit\'s HP ({panel_hp} of {u_hp[u]})")
        let before = pending.length
        expect_ok(not panel_buttons().length, "an enemy unit has no buttons")
        order(fake_mouse)
        expect_ok(pending.length == before, "no orders for an enemy unit ({pending.length - before} issued)")
        reveal = false
        test_step++
    elif test_step == 12 and clock_s >= 13.0:
        expect_ok(sel_foreign == 0, "an enemy unit back in the fog lets go of the selection")
        reveal = true
        let wild = filter(u_id.length) i: u_owner[i] == gaia
        let u = wild[wild.length - 1]
        cam = iso(float(u_x[u]), float(u_y[u]))
        test_foe = u_id[u]
        test_step++
    elif test_step == 13 and clock_s >= 13.5:
        let u = index_of(test_foe)
        fake_mouse = to_screen(iso(float(u_x[u]), float(u_y[u])) - float2 { 0.0, 14.0 })
        click_select(fake_mouse)
        expect_ok(sel_foreign == test_foe and not selected.length, "a click on a wild animal shows it, and doesn\'t select it")
        test_step++
    elif test_step == 14 and clock_s >= 14.0:
        expect_ok(panel_hp == u_hp[index_of(test_foe)], "the panel shows the wild animal\'s HP ({panel_hp})")
        print test_log
        return true
    return false

import .game.hud_kit
import .game.pad  // (here: it plays through the controls above)
import .game.techtree
import .game.panel
import .game.topbar
import .game.order_marks
import .game.touch          // (here: it plays through the pad, and leaves the panel, top bar and minimap to the mouse)
import .game.techtree_page  // (here: it draws with the panel's portraits and the top bar's icons)
import .game.build_id
import .game.lobby
import .game.boot

// Control groups shown (Dominic, 2026-10-26: "visible somewhere, at least as a number on the units",
// then "only when you select the group"): a small number by each selected unit that's in a group (its
// lowest), and under the top bar each group's number and how many are in it. Screen space, after the world.
// About the space a short label takes at this font size (gl.text_size doesn't match the drawn text at
// every window scale).
def label_size(s:string, fs:int) -> float2: return float2 { 0.6 * float(fs) * float(s.length), float(fs) }

def outlined_text(p:float2, s:string, col:float4, u:float):
    text_label(p, s, gl.get_font_size(), col, TEXT_FACE, 1.5 * u, float4 { 0.05, 0.04, 0.02, 0.9 })

def draw_groups():
    let keys = sorted_ints_g(groups.get_keys())
    let live = map(keys) n: filter(groups.get(n, [])) id: index_of(id) >= 0
    if not (filter(live) ids: ids.length > 0).length: return
    gl.set_shader("color")
    let u = ui()
    let fs = int(13.0 * u)
    gl.set_font_size(fs)
    let first = dictionary<int, int>(64)
    for(keys) n, k:
        for(live[k]) id:
            if first.get(id, -1) < 0 and contains(selected, id): first.set(id, n)  // (only on what's selected: Dominic)
    let ws = float(gl.window_size())
    for(first.get_keys()) id:
        let i = index_of(id)
        if fog[ME][cell_of(u_x[i], u_y[i])] != 0:
            let at = to_screen(iso(float(u_x[i]), float(u_y[i])) + float2 { -16.0, -40.0 })
            if at.x > 0.0 and at.y > 0.0 and at.x < ws.x and at.y < ws.y:
                let label = string(first.get(id, 0) + 1)
                outlined_text(at - label_size(label, fs) / 2.0, label, float4 { 1.0, 0.88, 0.5, 1.0 }, u)
    var x = 16.0 * u
    let y = topbar_bottom() + 8.0 * u  // under the top bar (game/topbar.lobster)
    let fs2 = int(15.0 * u)
    gl.set_font_size(fs2)
    for(keys) n, k:
        if live[k].length:
            let label = "{n + 1}: {live[k].length}"
            let size = label_size(label, fs2)
            let on = live[k].length == selected.length and (filter(live[k]) id: contains(selected, id)).length == live[k].length
            outlined_text(float2 { x, y }, label, if on: float4 { 1.0, 0.8, 0.3, 1.0 } else: float4 { 0.95, 0.88, 0.65, 1.0 }, u)
            x += size.x + 18.0 * u

// padtest: a fake pad plays a few seconds (tests/pad_check.gd's idea): pan, the circle, the wheel, a house.
var pad_step = 0
var test_pause = false
var pad_paged = false
var pad_spot = float2_0
var pad_houses = 0
def pad_script() -> PadIn:
    let t = clock_s
    let none = PadIn { [ 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 ], [] }
    let tc = town_center(ME)
    if pad_step == 0 and t >= 1.0:
        pad_spot = cam
        pad_step++
    if pad_step == 1:
        if t < 1.5: return PadIn { [ 1.0, 0.0, 0.0, 0.0, 0.0, 0.0 ], [] }
        expect_ok(cam.x > pad_spot.x + 50.0, "the left stick pans (camera {pad_spot.x} -> {cam.x})")
        let mine = filter(u_id.length) i: u_owner[i] == ME and t_animal[u_kind[i]] == 0
        cam = iso(float(fold(mine, 0) acc, i: acc + u_x[i]) / float(mine.length), float(fold(mine, 0) acc, i: acc + u_y[i]) / float(mine.length))
        pad_step++
    if pad_step == 2:
        if t < 3.5: return PadIn { none.axes, [ "a" ] }
        pad_step++
        return none
    if pad_step == 3:
        expect_ok(selected_units().length >= 3, "holding A grows a circle that takes {selected_units().length} units")
        store_group(0)
        selected = selected_workers()
        store_group(1)
        let i = index_of(selected[0])
        cam = iso(float(u_x[i]), float(u_y[i]))
        pad_off = float2_0
        test_pause = true  // (the worker stays under the reticle)
        pad_step++
        return none
    if pad_step == 4:
        pad_step++
        return PadIn { none.axes, [ "a" ] }
    if pad_step == 5:
        pad_step++
        return none
    if pad_step == 6 and wheel_pages() > 1 and not pad_paged:  // (more than a page: LB turns it, and back)
        pad_paged = true
        pad_step = 60
        return PadIn { none.axes, [ "leftshoulder" ] }
    if pad_step == 60:
        expect_ok(pad_page == 1, "LB turns the wheel\'s page ({wheel_pages()} pages)")
        pad_step = 61
        return none
    if pad_step == 61:
        pad_step = 62
        return PadIn { none.axes, [ "leftshoulder" ] }
    if pad_step == 62:
        pad_step = 6
        return none
    if pad_step == 6 and has_s(args, "wheelshot") and shot != "": gl.screenshot(shot + ".wheel.png")  // (captures: the wheel as it opened)
    if pad_step == 6 and pad_page == 0:
        expect_ok(pad_wheel.length > 0, "A on a selected worker opens its wheel ({pad_wheel.length} things to build)")
        var house = 0
        let items = wheel_page_items()
        for(items) w, n:
            if w.act == 3 and bt_name[w.arg] == "house": house = n
        let a = float(house) / float(max(1, items.length)) * 360.0 - 90.0
        pad_step++
        return PadIn { [ cos(a), sin(a), 0.0, 0.0, 0.0, 0.0 ], [] }
    if pad_step == 7:
        pad_step++
        return PadIn { none.axes, [ "a" ] }

    if pad_step == 8:
        expect_ok(placing >= 0 and bt_name[placing] == "house", "pointing at the house and A starts placing one")
        pad_houses = (filter(b_id.length) b: b_owner[b] == ME and bt_name[b_kind[b]] == "house").length
        cam = iso(float(b_cx[tc] * 1000 - 3000), float(b_cy[tc] * 1000 + 3000))
        test_pause = false
        pad_step++
        return none
    if pad_step == 9:  // (#507: the A that chose it on the wheel has been let go)
        expect_ok(placing >= 0, "letting go of the A that chose the house lays nothing (still placing)")
        pad_step = 100
        return PadIn { none.axes, [ "a" ] }
    if pad_step == 100:
        expect_ok(placing < 0, "A lays the house as it\'s pressed, not on its release")
        pad_step = 101
    if pad_step == 101 and t < 9.0: return PadIn { none.axes, [ "a" ] }  // (A held on: it laid the house, so no circle)
    if pad_step == 101:
        let houses = (filter(b_id.length) b: b_owner[b] == ME and bt_name[b_kind[b]] == "house").length
        expect_ok(houses > pad_houses, "the house is laid down ({pad_houses} -> {houses})")
        expect_ok(pad_circle == 0.0, "holding on the A that laid the house grows no circle")
        pad_step = 102
        return none
    if pad_step == 102:
        expect_ok(selected_workers().length > 0, "letting go of the A that laid the house keeps the worker selected")
        var best = int2 { -1, -1 }  // (#508: the reticle on the tree nearest the Town Center)
        var best_d = 1000000000
        for(H) y:
            for(W) x:
                let r = res_at(cell_of(x * TILE + TILE / 2, y * TILE + TILE / 2))
                let d = abs(x - b_cx[tc]) + abs(y - b_cy[tc])
                if r != 0 and resource_names[r - 1] == "wood" and d < best_d:
                    best_d = d
                    best = int2 { x, y }
        assert best.x >= 0
        cam = iso(float(best.x * TILE + TILE / 2), float(best.y * TILE + TILE / 2))
        pad_off = float2_0
        test_pause = true
        pad_step = 103
        return none
    if pad_step == 103:
        pad_step = 104
        return none
    if pad_step == 104:
        expect_ok(pad_cursor == "chop", "the reticle on a tree with a worker selected shows the chop cursor ({pad_cursor})")
        if has_s(args, "reticleshot") and shot != "":  // (captures, with reveal: the reticle on the tree, then on a foe)
            gl.screenshot(shot + ".tree.png")
            let foes = filter(u_id.length) i: is_enemy(u_owner[i], ME) and t_animal[u_kind[i]] == 0
            assert foes.length
            cam = iso(float(u_x[foes[0]]), float(u_y[foes[0]]))
            pad_off = float2_0
            pad_step = 105
            return none
        test_pause = false
        pad_step = 11
        return PadIn { none.axes, [ "b" ] }
    if pad_step == 105:
        pad_step = 106
        return none
    if pad_step == 106:
        gl.screenshot(shot + ".foe.png")
        test_pause = false
        pad_step = 11
        return PadIn { none.axes, [ "b" ] }
    if pad_step == 11:
        expect_ok(not selected.length, "B lets the selection go")
        pad_step++
        return PadIn { none.axes, [ "dpleft" ] }
    if pad_step == 12:
        pad_step++
        return none
    if pad_step == 13:
        expect_ok(selected.length > 0 and selected.length == (filter(groups.get(0, [])) id: index_of(id) >= 0).length, "a tap on d-pad left brings group 1 back ({selected.length})")
        for(t_slot.length) k:  // (a soldier by the workers, so there's more than one kind to cycle)
            if t_player[k] == ME and not t_worker[k] and t_animal[k] == 0 and t_trader[k] == 0 and t_healer[k] == 0 and pad_step == 13:
                mode_put(ME, k, start_x[ME] + 4000, start_y[ME] + 4000)
                pad_step = 69
        selected = map(filter(u_id.length) i: u_owner[i] == ME and t_animal[u_kind[i]] == 0) i: u_id[i]
        pad_step = 70
        return PadIn { none.axes, [ "leftshoulder" ] }
    if pad_step == 70:  // (LB let go: a tap)
        pad_step++
        return none
    if pad_step == 71:
        let kinds = []::int
        for(selected_units()) id:
            if not contains(kinds, u_kind[index_of(id)]): kinds.push(u_kind[index_of(id)])
        expect_ok(kinds.length == 1 and selected.length < pad_cycle_all.length, "a tap on LB keeps one kind of the selection ({selected.length} of {pad_cycle_all.length})")
        selected = filter(pad_cycle_all) id: index_of(id) >= 0
        arming_attack = true
        pad_step++
        return PadIn { none.axes, [ "a" ] }
    if pad_step == 72:
        expect_ok(not arming_attack, "A gives the armed attack-move")
        let mine = filter(u_id.length) i: u_owner[i] == ME and t_animal[u_kind[i]] == 0
        cam = iso(float(fold(mine, 0) acc, i: acc + u_x[i]) / float(mine.length), float(fold(mine, 0) acc, i: acc + u_y[i]) / float(mine.length))
        pad_step = 14
        return PadIn { none.axes, [ "rightshoulder" ] }
    if pad_step == 14:  // (#510: the pause menu, opened from the pad, sits on Resume and keeps the focus)
        menu_open = true
        pad_step = 140
        return none
    if pad_step == 140 or pad_step == 141 or pad_step == 142:
        pad_step++
        return none
    if pad_step == 143:
        expect_ok(ui_focus == 0, "the pause menu opened on the pad has the focus on Resume, frames later ({ui_focus})")
        if has_s(args, "reticleshot") and shot != "": gl.screenshot(shot + ".menu.png")  // (captures: the pause menu on the pad)
        menu_open = false
        pad_step = 15
        print test_log
    return none

// ------------------------------------------------------------------ main

assert args.length >= 2
var trail = ""
def note(s:string):
    trail += "{seconds_elapsed()}: {s}\n"
    write_file("/tmp/aoa_lobster_trail.txt", trail, 0, 1)

note("start")
// (a capture runs without vsync: with the display asleep or the screen locked, vsync never lets a frame through;
// novsync: the same for a measure, the frame cap still pacing it)
let no_vsync = shot != "" or rec_dir != "" or selftest or padtest or has_s(args, "novsync")
volume_load()
window_fullscreen = starts_fullscreen(args, windowed_setting)
fatal(gl.window("Age of Anything (Lobster)", window_arg.x, window_arg.y, window_flags(no_vsync, window_fullscreen)))
pace(PACE_MATCH)                           // (a 120 Hz display would draw twice as often for nothing: the laptop runs hot)
gl.window_icon("icons/game_icon_mac.png")  // (the Dock's icon on the Mac)
note("window")
fatal(gl.load_materials(SPRITE_SHADERS, true))
fatal(gl.load_materials(TERRAIN_SHADERS, true))
fatal(gl.load_materials(ATMO_SHADERS, true))
check(gl.set_font_name("data/fonts/Droid_Sans/DroidSans.ttf"), "no font")
bake_live = shot == "" and not selftest and not padtest  // (the window kept alive while art bakes; captures and tests bake quietly)

// Something on the screen from the first moment (not a black window): the boot screen (game/boot), until the title.
def startup_frame(what:string, done:float):
    if not bake_live: return
    boot_draw(what, done)
    gl.frame()

fatal(gl.load_materials(UI_SHADERS, true))  // (the boot screen paints the UI's wood)
ui_ready = true
// page:boot shot:<png>: a picture of the boot screen, then quit
if page_arg == "boot":
    for(3):
        boot_draw("Loading the sounds...", 0.35)
        gl.frame()
    boot_draw("Loading the sounds...", 0.35)
    if shot != "": gl.screenshot(shot)
    return from program
startup_frame("Loading...", 0.05)
for(args) a:  // cache:<folder>: the parts kept there instead of bake_cache/ ("cache:" alone: baked afresh, kept nowhere)
    if starts_with(a, "cache:"): bake_cache_dir = a.substring(6, a.length - 6)
zoom = 2.0 * floor(ui() + 0.5)  // two screen points an art pixel, as the game's camera
// Desktops start one zoom step further out, and then a quarter further again (#358); Steam Deck-sized screens (800 px
// tall or less) and touch keep the closer view
if not touch_play and gl.framebuffer_size().y > 800: zoom = max(1.0, (zoom - 1.0) * 0.8)
art_density(if has_s(args, "prebake"): density_arg else: zoom)  // (prebake: the density it's asked for, the base by default)
if zoom_arg > 0.0: zoom = zoom_arg
// The tables come from data (game/pack_data.lobster); units are voxel bodies (game/voxel_units.lobster); buildings and
// props are baked once (src/baked/) or at the start. (A Godot art pack, args[0], is gone with Godot: D-184.)
pack_library = true
startup_frame("Loading the sounds...", 0.2)
startup_frame("Loading the data...", 0.5)
lib_load("../data")
pack_teams()
ui_setup("")
let mods_wanted = if mods_arg != "": tokenize(mods_arg, ",", " ") else: pack_mods
if mods_wanted.length: print "mods: {mods_use(mods_wanted)}"
music_start()  // (after the mods: they can bring their own)
ambience_start()
startup_frame("Loading the parts...", 0.8)
id_load("../data")
// propframes dump:<folder>: every prop baked as PNGs, then quit (art review).
if has_s(args, "propframes"):
    for(args) d: if starts_with(d, "dump:"): ak_dump = d.substring(5, d.length - 5)
    bake_live = false
    bake_cache_dir = ""
    bake_shipped_dir = ""
    ak_rebake = true
    bake_doodads()
    bake_quit = true
// lookframes:<arch>,<type> dump:<folder>: every frame of a look baked as PNGs (its stages, ruins), then quit (art review).
for(args) a:
    if starts_with(a, "lookframes:"):
        let at_ = tokenize(a.substring(11, a.length - 11), ",", " ")
        for(args) d: if starts_with(d, "dump:"): akb_check_dump = d.substring(5, d.length - 5)
        bake_live = false
        let keep_cache = bake_cache_dir
        bake_cache_dir = ""
        ak_rebake = true
        bmat_matte = true
        akb_bake_look(at_[0], at_[1], "", "")
        bake_cache_dir = keep_cache
        bake_quit = true
// vbcheck: the buildings' checks as voxels (game/art_kit_buildings.lobster, akb_check), then quit.
if has_s(args, "vbcheck"):
    bake_live = false
    for(args) a: if starts_with(a, "dump:"): akb_check_dump = a.substring(5, a.length - 5)
    var checked = all_architectures()
    for(args) a:  // shard:<i>/<n>: every n-th architecture from the i-th, for n processes side by side (batch.sh)
        if starts_with(a, "shard:"):
            let shard, shards = split_string(a.substring(6, a.length - 6), "/")
            checked = filter(checked) _a, n: n % string_to_int(shards) == string_to_int(shard)
    if akb_check(checked) > 0: set_exit_code(1)
    bake_quit = true
// prebake: every prop and every architecture's buildings baked into the shipped folder (src/prebake.sh), then quit.
// shard:<i>/<n>: the props are the first piece, each architecture one more, and this bakes every n-th piece from the
// i-th, for n processes side by side (each thing is its own files, so they never write the same one, #456). `pieces`:
// how many pieces there are.
if has_s(args, "prebake"):
    bake_cache_dir = bake_shipped_dir
    bake_shipped_dir = ""
    bake_live = false  // (no progress drawn: the window's frames aren't needed, and a hidden one can stop the bake)
    var shard, shards = 0, 1
    for(args) a:
        if starts_with(a, "shard:"):
            let i, n = split_string(a.substring(6, a.length - 6), "/")
            shard, shards = string_to_int(i), string_to_int(n)
    let pieces = all_architectures()
    pieces.insert(0, "")
    if has_s(args, "pieces"): print "prebake: {pieces.length} pieces"  // (how many, for prebake.sh's shards)
    else: for(pieces) arch, n:
        if n % shards == shard:
            let t0 = seconds_elapsed()
            if arch == "": print "prebake: {bake_doodads()} prop frames in {int(seconds_elapsed() - t0)} s"
            else: print "prebake: {bake_buildings_for([ arch ])} building frames ({arch}) in {int(seconds_elapsed() - t0)} s"
    bake_quit = true

// A line in the middle of an empty screen while the link is made (true: the window was closed).
// A waiting or failed join or host: B or Esc goes back to the menu (net_backed_out), never a dead end.
var net_backed_out = false
var net_code = ""         // the join code on the waiting screen (online play, #514)
var net_swarm = Swarm {}  // the sidecar of this game's network match (an empty one: none)

def net_swarm_stop():
    swarm_stop(net_swarm)
    net_swarm = Swarm {}

def net_swarm_found() -> bool: return net_swarm.out == "" or net_swarm.peers > 0  // (no sidecar, or it reached the host)

def net_wait_frame(msg:string) -> bool:
    if not gl.frame(): return true
    if gl.button("escape") == 1 or gl.button("controller_b") == 1:
        net_backed_out = true
        return true
    gl.clear(float4 { 0.05, 0.05, 0.05, 1.0 })
    gl.blend(1)
    let u = ui()
    gl.set_font_size(int(22.0 * u))
    let half = float(gl.text_size(msg).x) * 0.5  // (a refusal can be long: centred, so it stays on screen)
    lobby_text(float(gl.window_size()) * float2 { 0.5, 0.5 } - float2 { half, 0.0 }, msg, float4 { 0.95, 0.85, 0.6, 1.0 })
    let hint = "B or Esc: back to the menu"
    gl.set_font_size(int(16.0 * u))
    lobby_text(float(gl.window_size()) * float2 { 0.5, 0.5 } + float2 { float(gl.text_size(hint).x) * -0.5, 44.0 * u }, hint, float4 { 0.7, 0.68, 0.62, 1.0 })
    if net_code != "":  // (the host's join code, big, above: the other player types or pastes it)
        if gl.button("c") == 1 or gl.button("controller_y") == 1: gl.set_clipboard(net_code)
        let title = "Join code: {net_code}"
        gl.set_font_size(int(44.0 * u))
        lobby_text(float(gl.window_size()) * float2 { 0.5, 0.5 } + float2 { float(gl.text_size(title).x) * -0.5, -130.0 * u }, title, float4 { 1.0, 0.92, 0.7, 1.0 })
        let how = "Copied. Send it to the other player; they join with it from anywhere. C or Y: copy again"
        gl.set_font_size(int(16.0 * u))
        lobby_text(float(gl.window_size()) * float2 { 0.5, 0.5 } + float2 { float(gl.text_size(how).x) * -0.5, -66.0 * u }, how, float4 { 0.7, 0.68, 0.62, 1.0 })
        if shot != "" and has_s(args, "waitshot"):  // (captures: host waitshot shot:<png>, the waiting screen with its code, then quit)
            gl.screenshot(shot)
            return true
    return false

var joined_bots = []::Bot
var back_to_lobby = false  // the pause menu's Back to the menu (or the match won or lost from the lobby)
var quit_app = false
var next_choice = ""   // the next match without the lobby (the pause menu's Load game)
var front_choice = ""  // what the lobby chose (game/lobby.lobster: play, host, join, fight, load:<path>)

// A saved match from the lobby's Load game: its world and bots, as a joiner takes the host's.
def load_saved(path:string) -> bool:
    let loaded = load_world(path)
    if not loaded.length: return false
    joined_bots = loaded
    map_name_now = gstr(su_map, "id", "reed_meadow")
    load_species(map_name_now)
    if pack_library: race_facts(su_races)
    return true

// The match: joined, loaded, or made here from the lobby's prompts (or the pack's scenario); the bots, the
// network, the captures' extras, the lockstep. False when the window was closed meanwhile.
// ---- the playtest log (milestone 10): one JSON line per finished match in matches.jsonl: the races, who won, how long
// it ran, when each side reached each age (docs/playtest.md)
var log_races = []::string
var log_prompts = []::string
var log_ages = []::int
var log_age_ups = []::JV
var log_done = false

def log_tick():
    if log_ages.length != ages.length: log_ages = copy(ages)
    for(ages) a, p:
        if a > log_ages[p]:
            log_age_ups.push(jarr([ jint(p), jint(a), jint(tick / 20) ]))
            log_ages[p] = a
    if winner >= 0 and not log_done:
        log_done = true
        let o = jobj()
        set(o, "map", jstr(map_name_now))
        set(o, "races", jstrs(log_races))
        set(o, "prompts", jstrs(log_prompts))
        set(o, "winner_team", jint(winner))
        set(o, "you", jint(ME))
        set(o, "seconds", jint(tick / 20))
        set(o, "ages", jarr(map(ages) a: jint(a)))
        set(o, "age_ups", jarr(log_age_ups))
        write_file("matches.jsonl", (read_file("matches.jsonl") or "") + stringify(o) + "\n")
        print "match logged: src/matches.jsonl"

def make_match() -> bool:
    log_done = false
    log_ages = []
    log_age_ups = []
    joined_bots = []
    ai_levels = []
    if starts_with(front_choice, "load:"):
        if not load_saved(front_choice.substring(5, front_choice.length - 5)): return false
    net_swarm_stop()                                                     // (the last match's)
    if join_ip != "" and fe_guests.length and fe_guests[0].world != "":  // joined in the host's lobby (#519): it sent the match
        let g = fe_guests[0]
        link = g.link
        joined_bots = load_world_bytes(g.world)
        net_unread(link, g.later)
        ME = g.side
        net_seats = g.seats
        net_people = g.seats.length
        if g.levels.length == num_players: ai_levels_set(g.levels)  // (the AIs think on every machine, each at its level)
        net_swarm = fe_swarm
        fe_swarm = Swarm {}
        fe_guests = []
        map_name_now = gstr(su_map, "id", "reed_meadow")
        load_species(map_name_now)
        if pack_library: race_facts(su_races)
    elif join_ip != "" and not joined_bots.length:
        var at_ip = join_ip
        var at_port = NET_PORT
        let code = join_code_in(join_ip)
        if code != "":  // a join code (#514): through our own sidecar, which finds the host by it
            let sw = swarm_join(code, 0)
            net_swarm = sw
            while sw.port == 0:
                swarm_poll(sw)
                if net_wait_frame(if sw.error != "": "No online play: {sw.error}" else: "Starting online play..."):
                    net_swarm_stop()
                    return false
            at_ip = "127.0.0.1"
            at_port = sw.port
        link = net_join(at_ip, at_port)
        var msg = "Joining {join_ip}..."
        var said = false
        var said_why = false
        while not joined_bots.length:
            if link.error != "" and not said_why:
                print "net: could not join {join_ip}: {link.error}"  // (in the log too: #506)
                said_why = true
            if net_swarm.out != "":
                swarm_poll(net_swarm)
                if net_swarm.error != "": link.error = net_swarm.error
                elif net_swarm.peers == 0: msg = "Looking for the host of {join_ip}..."
            if net_wait_frame(if link.error != "": "Could not join {join_ip}: {link.error}" else: msg):
                net_swarm_stop()
                return false
            if link.error == "" and net_ready(link):
                if not said:
                    join_hello(link)
                    said = true
                if net_swarm_found(): msg = "Joined {join_ip}: the host is sending the match..."
                let later = []::[string]
                for(net_poll(link)) f:
                    if f[0] == "W": ME = string_to_int(f[1])  // (our seat)
                    elif f[0] == "S": joined_bots = load_world_bytes(f[1])
                    elif f[0] == "X": link.error = f[1]
                    elif joined_bots.length: later.push(f)  // (a turn that came with the match: kept for the lockstep)
                net_unread(link, later)
        if ME == 0: ME = 1  // (a host that sends no seat: the second one)
        net_people = num_players
        map_name_now = gstr(su_map, "id", "reed_meadow")
        load_species(map_name_now)
        if pack_library: race_facts(su_races)
    elif joined_bots.length: pass()
    elif args[1] == "-" or args[1] == "lobby":  // the races from their prompts and the match start, made here (gen/)
        let rules = load_rules(rules_id())
        set(rules, "animals", jbool(true))
        let prompts = lobby_prompts
        let t_gen = seconds_elapsed()
        // (more than two people: the other seats take the two prompts' further takes, a team each)
        let races = map(max(prompts.length, if hosting: net_people else: 0)) k: generate(prompts[k % prompts.length], rules, if k < lobby_rerolls.length: lobby_rerolls[k] else: k / prompts.length)
        log_races = map(races) r: rstr(r, "name")
        log_prompts = map(races.length) k: prompts[k % prompts.length]
        let t_setup = seconds_elapsed()
        if args[1] == "lobby": reset_world()  // (the lobby's pages may have run a world: the Race Lab's)
        let map_id = if args[1] == "lobby": lobby_map elif pack_map != "": pack_map else: "reed_meadow"
        if args[1] == "lobby": set(rules, "mode", jstr(lobby_mode))                                  // (the match's mode)
        let picked = args[1] == "lobby" and lobby_teams.length == races.length and races.length > 2  // (a team game picked in the lobby: its map and teams)
        let four = races.length > 2 and not picked                                                   // (host:<n> with more people: the 2v2 map)
        let real_map = if four: "reed_meadow_2v2" else: map_id
        setup_match(20261010, real_map, races, rules, if picked: lobby_teams elif four: map(races.length) k: k % 2 else: [])
        load_species(real_map)
        map_name_now = real_map
        if pack_library: race_facts(races)
        print "races in {(t_setup - t_gen) * 1000.0} ms, the start in {(seconds_elapsed() - t_setup) * 1000.0} ms"
    else:
        // a scenario has no recipes: set its races up (as export.gd did) for the units' looks, then load it over a clean world
        let rules = load_rules(rules_id())
        let races = map(if pack_prompts.length >= 2: pack_prompts else: [ "sewer rats with cheese hammers", "angry swamp frogs with reed spears" ]) pr: generate(pr, rules, 0)
        setup_match(20261010, if pack_map != "": pack_map else: "flat_test", races, rules, [])
        let keep_units = su_units
        let keep_btypes = su_btypes
        let keep_races = su_races
        let keep_rules = su_rules
        reset_world()
        start_world(args[1])
        su_units = keep_units
        su_btypes = keep_btypes
        su_races = keep_races
        su_rules = keep_rules
        if pack_library: race_facts(races)
        roles_from_data()  // (a scenario file carries no building roles)
    note("world")
    events_on = true
    if args[1] == "lobby" and lobby_levels.length == num_players and not joined_bots.length: ai_levels_set(lobby_levels)  // (each AI at its level)
    bots = map(num_players) p: new_bot(p)
    if joined_bots.length: bots = joined_bots
    if hosting and fe_rooms.length:  // the lobby's room (#519): its players are in, each on the side they took
        let seats, links = room_start(fe_rooms[0], map(num_players) p: if p < lobby_levels.length: lobby_levels[p] else: "")
        net_seats = seats
        net_people = seats.length
        link = links[0]
        net_others = links.slice(1, -1)
        net_swarm = fe_swarm
        fe_swarm = Swarm {}
        fe_rooms = []
        let bytes = world_bytes(bots)
        for(links) l: net_send(l, 'S', bytes)
    elif hosting:
        let door = door_open(NET_PORT, rstr(su_races[0], "name"), map_name_now)
        let joined = []::Link
        let here = my_ipv4()
        let sw = swarm_host(NET_PORT)  // (online too, #514: a join code, through the sidecar to this door)
        net_swarm = sw
        while joined.length < net_people - 1:
            swarm_poll(sw)
            if sw.code != "" and net_code == "":
                net_code = sw.code
                gl.set_clipboard(sw.code)
            let online = if sw.error != "": "  (online is off: {sw.error})" elif sw.code != "" and not sw.announced: "  (going online...)" else: ""
            if net_wait_frame(if door.error != "": "Could not host: {door.error}" else: "Hosting at {if here != "": here else: "this machine"}: {joined.length} of {net_people - 1} joined, waiting...{online}"):
                net_code = ""
                net_swarm_stop()
                return false
            let got = door_tick(door)
            if got:
                net_send(got, 'W', string(joined.length + 1))
                joined.push(got)
        net_code = ""
        link = joined[0]
        net_others = joined.slice(1, -1)
        let bytes = world_bytes(bots)
        for(joined) l: net_send(l, 'S', bytes)
    net_on = hosting or join_ip != ""
    if place_arg == "fort" or place_arg == "palisade_fort":  // (captures: every join of a wall line at once)
        // a run of wall along x with a gate in it, a turn down y, a diagonal run, wall towers at the corners
        let stone = place_arg == "fort"
        let fwall = btype_index(if stone: "wall" else: "palisade")
        let fgate = btype_index(if stone: "stone_gate" else: "palisade_gate")
        let ftower = btype_index(if stone: "wall_tower" else: "watchtower")
        let tc = town_center(ME)
        if tc >= 0:
            var done = false
            for([ int2 { 5, -4 }, int2 { -12, 5 }, int2 { 5, 6 }, int2 { -10, -10 }, int2 { 6, 0 }, int2 { 0, 6 }, int2 { -8, 0 }, int2 { 0, -8 } ]) o:
                if not done:
                    let x0 = b_cx[tc] + o.x
                    let y0 = b_cy[tc] + o.y
                    let cells = []::int3  // x, y, kind (-1 wall, -2 gate along x, -3 tower)
                    for(3) i: cells.push(int3 { x0 + i, y0, -1 })
                    cells.push(int3 { x0 + 3, y0, -2 })
                    for(2) i: cells.push(int3 { x0 + 6 + i, y0, -1 })
                    cells.push(int3 { x0 + 8, y0, -3 })
                    for(3) i: cells.push(int3 { x0 + 8, y0 + 1 + i, -1 })
                    for(3) i: cells.push(int3 { x0 + 7 - i, y0 + 4 + i, -1 })
                    cells.push(int3 { x0 - 1, y0, -3 })
                    let fits = (filter(cells) c: can_place(ME, if c.z == -1: fwall elif c.z == -2: fgate else: ftower, c.x, c.y)).length
                    if fits * 10 >= cells.length * 8:  // (most of it: a tree or a rock in the way leaves a gap)
                        for(cells) c:
                            let k = if c.z == -1: fwall elif c.z == -2: fgate else: ftower
                            if can_place(ME, k, c.x, c.y): fort_put(ME, k, c.x, c.y, 0)
                        update_pop()
                        cam = iso(float(x0 * 1000 + 5500), float(y0 * 1000 + 4500))
                        print "fort: {fits} of {cells.length} tiles at {x0},{y0}"
                        fort_gate = int2 { x0 + 3, y0 }
                        done = true
    elif place_arg != "":
        let k = btype_index(place_arg)
        let tc = town_center(ME)
        if k >= 0 and tc >= 0:
            var done = false
            for(12) r:
                for(8) a:
                    if not done:
                        let x = b_cx[tc] + int(cos(float(a) * 45.0) * float(4 + r))
                        let y = b_cy[tc] + int(sin(float(a) * 45.0) * float(4 + r))
                        if can_place(ME, k, x, y):
                            fort_put(ME, k, x, y, 0)
                            update_pop()
                            cam = iso(float(x * 1000 + 1500), float(y * 1000 + 1500))
                            done = true
    if skirmish: army_n = max(army_n, 3)
    if army_n > 0:  // (a skirmish: both sides, marching on each other)
        for(num_players) p:
            if p == ME or skirmish:
                let slots = []::string
                for(t_slot.length) k:
                    if t_player[k] == p and not t_worker[k] and t_animal[k] == 0 and t_trader[k] == 0 and t_healer[k] == 0: push_new(slots, t_slot[k])
                let ids = []::int
                let side = int(ceiling(sqrt(float(slots.length * army_n))))  // (in ranks, not all on one spot)
                for(slots) slot:
                    let kind = type_of_slot(p, slot)
                    for(if has(gobj(su_units[kind], "look"), "crew"): max(1, army_n / 8) else: army_n):  // (engines: a few, not as many as soldiers)
                        let at = ids.length
                        let x = clamp(start_x[p] + 4000 + (at % side - side / 2) * ARMY_GAP, TILE, (W - 1) * TILE)
                        let y = clamp(start_y[p] + 4000 + (at / side - side / 2) * ARMY_GAP, TILE, (H - 1) * TILE)
                        let i = mode_put(p, kind, x, y)
                        ids.push(u_id[i])
                if skirmish:
                    let foe = (p + 1) % num_players
                    issue_cmd(p, CMD_ATTACK_MOVE, ids, start_x[foe], start_y[foe], 0, 0)
                    army_snap = true
        update_pop()
        if fort_gate.x >= 0 and has_s(args, "in_gate"):  // (captures: soldiers standing through the gate's arch, before, in it, past it)
            let gk = find(t_slot.length) j: t_player[j] == ME and t_slot[j] == "infantry"
            let gx = (fort_gate.x + 1) * 1000 + 500
            if gk >= 0:
                for([ -900, -300, 300, 900, 1500 ]) dy: add_unit(ME, gk, gx, fort_gate.y * 1000 + 500 + dy)
                for([ -1, 1 ]) side: for([ -700, 1400 ]) dy: add_unit(ME, gk, gx + side * 1300, fort_gate.y * 1000 + 500 + dy)  // (beside its towers)
        elif fort_gate.x >= 0:                                                                                                  // (through the fort's gate and out the far side)
            let mine = filter(u_id.length) i: u_owner[i] == ME and t_worker[u_kind[i]] == 0
            issue_cmd(ME, CMD_MOVE, map(mine) i: u_id[i], fort_gate.x * 1000 + 500, (fort_gate.y + 4) * 1000, 0, 0, 0)
        if skirmish:
            if watch:
                let mid_x = (start_x[0] + start_x[1]) / 2
                let mid_y = (start_y[0] + start_y[1]) / 2
                cam = iso(float(mid_x), float(mid_y))
                if look_x < 0: follow = true  // (watching: the camera goes where they fight, unless look: says where)
            else: look_at_army = true
    if hurt_pct >= 0:
        for(b_id.length) b:
            if b_owner[b] == ME: b_hp[b] = max(1, bm_hp[ME][b_kind[b]] * hurt_pct / 100)
    in_net_match = net_on
    lockstep = new_lockstep(link, ME, if net_on and net_seats.length: net_seats elif net_on: map(net_people) k: k else: [ ME ])
    lockstep.more = net_others
    lockstep.relay = hosting
    return true

// Saving and loading (gen/save.lobster): F5 saves the match, F9 brings the save back (the whole world
// and the bots); the view starts over from it: units redrawn, the ground, paths and town read again.
let SAVE_PATH = "quick.sav"
def quick_save(): save_to(SAVE_PATH)

// The pause menu's Save game: a new file in saves/ each time, with a line about it beside it (the lobby's Load game lists them).
def save_game():
    launch_subprocess([ "/bin/mkdir", "-p", "saves" ])
    let stamp = date_time_string_format("%Y-%m-%d_%H-%M-%S")
    let names = concat_string(map(su_races) r: rstr(r, "name"), " vs ")
    let secs = tick / 20
    write_file("saves/{stamp}.txt", "{names}  -  {capitalize(map_name_now)}  -  {secs / 60}:{if secs % 60 < 10: "0" else: ""}{secs % 60}  -  {date_time_string_format("%d %b %H:%M")}\n")
    save_to("saves/{stamp}.sav")

def save_to(path:string):
    let t0 = seconds_elapsed()
    let ok = save_world(path, bots)
    banner = if ok: "Saved ({int((seconds_elapsed() - t0) * 1000.0)} ms)" else: "Could not save"
    banner_t = gl.time()

// What the view keeps about a match, let go (a save loaded over it, or a new match).
def view_reset():
    corpses = []
    fx_clear()
    hit_t0.clear()
    attack_t0.clear()
    shot_from.clear()
    shot_mouth.clear()
    town_last.clear()
    town_idle_since.clear()
    chores.clear()
    piles.clear()
    house_born.clear()
    town_puffs = []
    path_used = []
    path_done.clear()
    path_out = []
    path_painted = 0
    path_raw = []
    path_anchor_hub.clear()
    path_anchor_res.clear()
    path_count = -1
    ground_tick = -1000
    paths_tick = -1000
    mask_version = -1
    mask_tick = -1000
    selected = []
    sel_building = 0
    sel_foreign = 0
    groups.clear()
    placing = -1

def quick_load(): load_from(SAVE_PATH)

def load_from(path:string):
    let t0 = seconds_elapsed()
    let loaded = load_world(path)
    if not loaded.length:
        banner = if save_refused != "": save_refused else: "No save to load"
        banner_t = gl.time()
        return
    bots = loaded
    view_reset()
    refresh_paths()
    clock_s = float(tick) / 20.0
    p_id = copy(u_id)
    p_x = copy(u_x)
    p_y = copy(u_y)
    banner = "Loaded ({int((seconds_elapsed() - t0) * 1000.0)} ms)"
    banner_t = gl.time()
var tc0 = -1
var paused = false
var speed = start_speed
var frame_no = 0
var menu_saves = false     // ...showing the saved games (Load game)
var menu_settings = false  // ...showing Settings (game/lobby.lobster)
var quit_game = false
var told_end = false  // the match's end was shown (the menu opens once)

def end_screen_up() -> bool: return winner >= 0 and not end_watching and not menu_open

// The match's end: Victory or Defeat over the dimmed world, how long it was played, and the ways out.
def end_screen():
    menu_frame(true)
    end_screen_body()
    menu_frame_end()

def end_screen_body():
    let ws = float(gl.window_size())
    let k = hud_s()
    ui_fill(float2_0, ws, float4 { 0.0, 0.0, 0.0, 0.6 })
    let from_lobby = args[1] == "lobby"
    let buttons = filter([ "Back to the menu", "Quit" ]) l: l != "Back to the menu" or from_lobby
    let bw = 380.0
    let size = float2 { bw + 48.0, 250.0 + 54.0 * float(buttons.length) } * k
    let at = ws / 2.0 - size / 2.0
    ui_box(at, size, 1, ui_look.face, true)
    tb_icon_wide("crest_" + hud_crest, float2 { at.x + size.x / 2.0, at.y + 2.0 * k }, 34.0 * k)
    let x = at.x + 24.0 * k
    var y = at.y + 34.0 * k
    ui_text_c(ws.x / 2.0, y, if winner == teams[ME]: "Victory!" else: "Defeat", int(52.0 * k), ui_look.title, 2, 2.0 * k)
    y += 80.0 * k
    let secs = tick / 20
    def two(n:int) -> string: return (if n < 10: "0" else: "") + string(n)
    let played = if secs >= 3600: "{secs / 3600}:{two(secs / 60 % 60)}:{two(secs % 60)}" else: "{secs / 60}:{two(secs % 60)}"
    ui_text_c(ws.x / 2.0, y, "Played for " + played, int(20.0 * k), ui_look.dim, 0, 0.0)
    y += 44.0 * k
    if ui_button(float2 { x, y }, float2 { bw * k, 56.0 * k }, "", true) or gl.button("controller_b") == 1: end_watching = true
    ui_text_c(ws.x / 2.0, y + (56.0 * k - 24.0 * k) / 2.0 - 3.0 * k, "Keep watching", int(24.0 * k), ui_look.title, 2, 1.5 * k)
    y += 68.0 * k
    for(buttons) label:
        let fs = int(19.0 * k)
        if ui_button(float2 { x, y }, float2 { bw * k, 42.0 * k }, "", false):
            if label == "Back to the menu": back_to_lobby = true
            quit_game = true
        ui_text_f(float2 { x + (bw * k - ui_text_wf(label, fs, 1)) / 2.0, y + (42.0 * k - float(fs)) / 2.0 - 2.0 * k }, label, fs, ui_look.text, 1, 1.0 * k)
        y += 54.0 * k
    ui_flush()

// A menu over the match keeps its own buttons and pad focus (#510): the command panel, drawn first each frame, starts
// the UI's frame with the pad off, which drops the focus and leaves its own buttons as the ones the d-pad walks.
// Opened on the pad, a menu starts on its first button (Resume), as the Godot game's did.
var menu_hits = []::UiHit
var menu_focus = -1
var menu_was_up = false
def menu_frame(up:bool):
    if up and not menu_was_up: menu_focus = if pad_on: 0 else: -1
    menu_was_up = up
    ui_hits = menu_hits
    ui_focus = menu_focus
    ui_frame(true)
def menu_frame_end():
    menu_hits = ui_hits
    menu_focus = ui_focus

// The pause menu (Esc, or Start on the pad): a panel of buttons over the dimmed match. In a network
// match the world goes on (only you stop looking), and Load isn't offered.
def pause_menu():
    menu_frame(true)
    pause_menu_body()
    menu_frame_end()
    if not menu_open and gl.button("controller_a") >= 1: pad_a_eaten = true  // (the A that chose Resume: it selects nothing on its way up)

def pause_menu_body():
    let ws = float(gl.window_size())
    if menu_saves:  // Load game: the saves (game/lobby.lobster)
        fe_fit()
        let picked = fe_saves_card("")
        if picked == "back": menu_saves = false
        elif picked != "":  // (a new match from the save: its map may be another)
            next_choice = "load:" + picked
            back_to_lobby = true
            quit_game = true
        fe_draw_tip()
        ui_flush()
        return
    if menu_settings:  // Settings: the volumes and the UI scale (game/lobby.lobster)
        fe_fit()
        if fe_settings_card() == "back": menu_settings = false
        ui_flush()
        return
    if gl.button("controller_b") == 1: menu_open = false
    // sim_debug.gd's _make_pause_menu: a framed card in your race's look, its crest on top, sized to what's in it: the
    // title, your race and the map, a rule; Resume (the primary), the everyday buttons (Settings among them); then, set apart
    // under a rule, the ones that end the match (in red)
    let k = hud_s()
    ui_fill(float2_0, ws, float4 { 0.0, 0.0, 0.0, 0.5 })
    let from_lobby = args[1] == "lobby"
    let title = if winner >= 0: (if winner == teams[ME]: "Victory!" else: "Defeat") elif net_on: "Menu" else: "Paused"
    let sub = rstr(su_races[ME], "name") + "  ·  " + gstr(su_map, "name", map_name_now) + (if net_on: "  ·  the match goes on" else: "")
    let everyday = filter([ "Save game", "Load game", "Settings", "Tech tree" ]) l: l != "Load game" or not net_on
    let ending = filter([ "Surrender", "Back to the menu", "Quit" ]) l: (l != "Surrender" or (winner < 0 and defeated[ME] == 0)) and (l != "Back to the menu" or from_lobby)
    let bw = 380.0
    let size = float2 { bw + 48.0, 268.0 + 62.0 * float(everyday.length) + 54.0 * float(ending.length) } * k  // (the rows below, top to bottom)
    let at = ws / 2.0 - size / 2.0
    ui_box(at, size, 1, ui_look.face, true)
    tb_icon_wide("crest_" + hud_crest, float2 { at.x + size.x / 2.0, at.y + 2.0 * k }, 34.0 * k)
    let x = at.x + 24.0 * k
    var y = at.y + (22.0 + 8.0) * k
    ui_text_c(ws.x / 2.0, y, title, int(42.0 * k), ui_look.title, 2, 2.0 * k)
    y += 68.0 * k
    ui_text_c(ws.x / 2.0, y, sub, int(17.0 * k), ui_look.dim, 0, 0.0)
    y += 36.0 * k
    def rule():
        let t = max(1.0, k)
        ui_fill(float2 { x + 6.0 * k, y + 6.0 * k + t }, float2 { bw * k - 12.0 * k, t }, float4 { 0.0, 0.0, 0.0, 0.55 })
        ui_fill(float2 { x + 6.0 * k, y + 6.0 * k }, float2 { bw * k - 12.0 * k, t }, float4 { ui_look.metal.x, ui_look.metal.y, ui_look.metal.z, 0.7 })
        let c = float2 { x + bw * k / 2.0, y + 6.0 * k }
        let d = 4.5 * k
        ui_paint_poly([ c + float2 { 0.0, -d }, c + float2 { d, 0.0 }, c + float2 { 0.0, d }, c + float2 { -d, 0.0 } ], [ ui_look.metal, ui_look.metal, ui_look.metal, ui_look.metal ], [ 0, 1, 2, 0, 2, 3 ], ui_material("bronze"))
        y += 24.0 * k
    rule()
    def item(label:string, h:float, col:float4) -> bool:
        let hit = ui_button(float2 { x, y }, float2 { bw * k, h * k }, "", false)
        let fs = int(19.0 * k)
        ui_text_f(float2 { x + (bw * k - ui_text_wf(label, fs, 1)) / 2.0, y + (h * k - float(fs)) / 2.0 - 2.0 * k }, label, fs, col, 1, 1.0 * k)
        y += (h + 12.0) * k
        return hit
    let primary = ui_button(float2 { x, y }, float2 { bw * k, 64.0 * k }, "", true)
    ui_text_c(ws.x / 2.0, y + (64.0 * k - 28.0 * k) / 2.0 - 4.0 * k, "Resume", int(28.0 * k), ui_look.title, 2, 1.5 * k)
    if primary: menu_open = false
    y += 76.0 * k
    for(everyday) label:
        if item(label, 50.0, ui_look.text):
            if label == "Save game":
                save_game()
                menu_open = false
            elif label == "Load game": menu_saves = true
            elif label == "Settings": menu_settings = true
            else:
                menu_open = false
                open_tree(ME)
    rule()
    let danger = float4 { 0.91, 0.54, 0.44, 1.0 }  // #e88a70, as a lacked line
    for(ending) label:
        if item(label, 42.0, danger):
            if label == "Surrender":  // (the match ends as a defeat for your side)
                issue_cmd(ME, CMD_SURRENDER, []::int, 0, 0, 0, 0)
                menu_open = false
            elif label == "Back to the menu":
                back_to_lobby = true
                quit_game = true
            else: quit_game = true
    ui_flush()

import .game.cursor_images
import .game.cursors

// A match from its start: the camera on your Town Center, the clock at 0, played until it's quit (or a capture's done).
def play_match():
    tc0 = town_center(ME)
    if tc0 >= 0: cam = iso(float(b_cx[tc0] * 1000 + 1500), float(b_cy[tc0] * 1000 + 1500))
    if look_at_army:
        let mine = filter(u_id.length) i: u_owner[i] == ME and t_worker[u_kind[i]] == 0 and t_animal[u_kind[i]] == 0
        if mine.length: cam = iso(float(fold(mine, 0) a, i: a + u_x[i]) / float(mine.length), float(fold(mine, 0) a, i: a + u_y[i]) / float(mine.length))
    if look_x >= 0: cam = iso(float(look_x * 1000 + 500), float(look_y * 1000 + 500))
    sim_reset()
    paused = false
    speed = start_speed
    frame_no = 0
    menu_open = false
    menu_saves = false
    menu_settings = false
    quit_game = false
    told_end = false
    end_watching = false
    note("loop")
    pace(PACE_MATCH)
    if rec_dir != "":  // (as fast as it goes up to from:)
        gl.set_fixed_delta_time(0.2, 0.0)
        speed = 8.0
    while gl.frame() and not quit_game and not bake_quit:
        ui_click_tick()
        window_tick()
        if perf_for > 0.0:  // (the Town Center selected: its panel and queue drawn, the HUD full)
            perf_begin()
            if tc0 >= 0 and tc0 < b_id.length: sel_building = b_id[tc0]
            perf_finish_house(clock_s, ME)
        drop_lost_selection()
        if gl.button("escape") == 1 and placing < 0 and not build_menu and not typing_text and not tree_open and not pad_wheel.length and not arming_attack and not arming_ability: menu_open = not menu_open
        if gl.button("controller_start") == 1 and not typing_text and not tree_open: menu_open = not menu_open
        if has_s(args, "menu") and frame_no == 2: menu_open = true  // (captures)
        if has_s(args, "orders") and frame_no == 30:                // (captures: your units sent off, and the Town Center's rally set)
            selected = filter(u_id) id: u_owner[index_of(id)] == ME
            let tc = town_center(ME)
            if tc >= 0 and selected.length:
                let gx = b_cx[tc] * TILE + 6000
                let gy = b_cy[tc] * TILE - 4000
                issue_cmd(ME, CMD_MOVE, selected_units(), gx, gy, 0, 0, 0)
                issue_cmd(ME, CMD_MOVE, selected_units(), gx + 3000, gy + 3000, 0, 0, 1)
                issue_cmd(ME, CMD_RALLY, []::int, b_id[tc], gx - 3000, gy + 6000, 0)
        if gl.button("escape") == 1: build_menu = false
        if gl.button("space") == 1 and not net_on: paused = not paused
        let ctrl = gl.button("left ctrl") >= 1 or gl.button("right ctrl") >= 1 or gl.button("left gui") >= 1 or gl.button("right gui") >= 1
        if ctrl and (gl.button("=") == 1 or gl.button("-") == 1):  // Ctrl/Cmd + and -: the HUD's size (saved)
            hud_size = clamp(hud_size + (if gl.button("=") == 1: 10 else: -10), 70, 200)
            volume_save()
        elif gl.button("=") == 1 and not net_on: speed = min(8.0, speed * 2.0)
        elif gl.button("-") == 1 and not net_on: speed = max(0.25, speed / 2.0)
        let dt = gl.delta_time()
        frame_dt = dt
        fx_tick(dt)
        vx_tick(0.006, u_x.length < 300 and gl.time() - last_battle >= 6.0)  // (the voxel units' later bakes, not in a fight)
        akb_wall_tick()                                                      // (a wall tile with joins not seen before: one a frame)
        town_tick(dt)
        music_tick("age{clamp(ages[ME], 1, 4)}", gl.time() - last_battle < 6.0, dt)
        ambience_tick(town_level(), dt)
        unit_loops_tick(dt)
        frame_no++
        if frame_no == 1:                                                            // (inside a frame: a bake outside one leaves the window drawing nothing)
            if bake_live and fe_sides.length == num_players and front_choice != "":  // (the match loader shows the bake's progress)
                bake_progress = fn(st, f): fe_loader(st, f)
                bake_progress_on = true
            bake_loading = true
            bake_progress_from = 0.5
            bake_progress_to = 0.95
            bake_what = "the armies"
            vx_all_fielded = army_n > 0 or skirmish  // (an army or a skirmish: they're all on the field)
            vx_start_now = army_n > 0
            vx_start()
            let t1 = seconds_elapsed()
            ak_rebake = rebake_art
            bake_progress_from = 0.95
            bake_progress_to = 1.0
            bake_what = "the town"
            let nd = bake_doodads()
            print "baked {nd} props{if rebake_art: "" else: " the pack lacked"}, in {int((seconds_elapsed() - t1) * 1000.0)} ms"
            let t2 = seconds_elapsed()
            let nb = bake_buildings_for(arch_of)
            print "baked {nb} building frames{if rebake_art: "" else: " the pack lacked"}, in {int((seconds_elapsed() - t2) * 1000.0)} ms"
            bake_progress_on = false
            bake_loading = false
        if shot != "" and frame_no < 3: note("frame {frame_no} tc at {if tc0 >= 0: to_screen(iso(float(b_cx[tc0] * 1000 + 2000), float(b_cy[tc0] * 1000 + 2000))) else: float2_0} cam {cam} zoom {zoom} ws {gl.window_size()} fb {gl.framebuffer_size()} tc {tc0} draws {draws.length} W {W} H {H} first {iso(0.0, 0.0)} last {iso(float(W * 1000), float(H * 1000))}")
        if shot != "" and frame_no % 60 == 0: print "frame {frame_no}: {dt * 1000.0} ms, play {clock_s} s"
        if reload_at >= 0.0 and clock_s >= reload_at:
            quick_save()
            reload_tick = tick
            print "saved at tick {tick}: {u_id.length} units, {b_id.length} buildings, hash {state_hash()}"
            reload_at = -1.0
        if reload_tick >= 0 and tick >= reload_tick + 100:
            quick_load()
            print "loaded: tick {tick}, {u_id.length} units, {b_id.length} buildings, hash {state_hash()}"
            reload_tick = -1
        if not typing_text and gl.button("f5") == 1: quick_save()
        if not typing_text and not net_on and gl.button("f9") == 1: quick_load()
        if swap_arg != "" and clock_s >= swap_at:
            become(swap_arg)
            swap_arg = ""
        if not paused and not test_pause and winner < 0 and not typing_text and ((not tree_open and not menu_open) or net_on): sim_owe(dt * speed)
        if net_on:
            ls_receive(lockstep)
            if lockstep.desync != "": banner = "Out of step with the other player: {lockstep.desync}"
            elif link.closed: banner = "The other player has left"
            if lockstep.desync != "" or link.closed: banner_t = gl.time()
        sim_run(skirmish):  // (a skirmish: the armies' orders alone, no bots)
            if army_snap and (find(fb_state) s: s != 0) >= 0:
                blocks_snap()
                army_snap = false
        if follow: cam_follow_fight(0.05)
        if not typing_text and not tree_open and not menu_open and not end_screen_up():
            let padded = (touch_play and touch_tick(dt)) or pad_tick(if padtest: pad_script() else: read_pad(), dt)
            if touch_wants_menu:
                menu_open = true
                touch_wants_menu = false
            if not padded and not touch_play and not typing_text: scroll()
            keys()
            if not padded and not panel_click(mouse_px()): mouse()
        perf_lap(0)
        if drawing():  // (minimised: the sim plays on, nothing is drawn)
            gl.clear(float4 { 0.05, 0.05, 0.05, 1.0 })
            gl.blend(1)
            draw_world_lit()
            if not rec_clean: ui_batch(): draw_panel()
            perf_lap(6)
            if not rec_clean: draw_hud(paused, speed)
            perf_lap(7)
            if not rec_clean: draw_groups()
            perf_lap(8)
            pad_draw()
            if touch_play: build_button()
            if tree_arg and frame_no == 2:
                open_tree(ME)
            tree_tick()
            if menu_open: pause_menu()
            elif end_screen_up(): end_screen()
            else: menu_was_up = false
            if padtest and menu_open: pad_script()  // (#510: the menu reads the real pad; the script only checks it)
            if not rec_clean: draw_banner()
            if typing_text: typing_tick()
            os_cursor_tick()
        perf_lap(9)
        if has_s(args, "savegame") and clock_s >= 3.0:  // (tests: the pause menu's Save game, then quit)
            save_game()
            quit_app = true
            return
        if has_s(args, "lobbyloop") and loop_round == 0 and clock_s >= 2.0:  // (tests: back to the lobby, then a second match)
            loop_round++
            back_to_lobby = true
            quit_game = true
        if airtest and air_test(): break
        if selftest and self_test():
            if shot != "": gl.screenshot(shot)
            quit_app = true
            return
        if padtest and pad_step >= 15 and pad_step < 60:
            if shot != "": gl.screenshot(shot)
            quit_app = true
            return
        if not net_on or ME == 0: log_tick()
        if has_s(args, "tillend") and (winner >= 0 or (shot_at > 0.0 and clock_s >= shot_at)):  // a whole match to its end (tests: with watch)
            if shot != "": gl.screenshot(shot)
            print "match over: {if winner >= 0: "team {winner} won" else: "no winner yet"} at {int(clock_s) / 60}:{int(clock_s) % 60}, tick {tick}"
            quit_app = true
            return
        if shot != "" and clock_s >= shot_at and not selftest and not padtest and not has_s(args, "tillend") and (not tree_arg or (frame_no > 4 and tree_waiting == 0)) and (not has_s(args, "menu") or frame_no > 4):
            gl.screenshot(shot)
            print "shot {shot} at {clock_s} s, tick {tick}; sim {sim_step_time * 1000.0 / max(1, sim_steps)} ms a tick; cam {cam} zoom {zoom} ws {gl.window_size()} fb {gl.framebuffer_size()}"
            quit_app = true
            return
        if rec_dir != "" and winner >= 0 and clock_s < rec_from:  // (the match was over before from:, and play has stopped)
            print "record: match over at {clock_s} s, before from:"
            quit_app = true
            return
        if rec_dir != "" and clock_s >= rec_from:
            if rec_n == 0:
                record_begin()
                speed = start_speed
                if rec_pan != float2_0: follow = false  // (a pan is the take's own camera move; the follow would pull against it)
            if record_frame():
                quit_app = true
                return
        if perf_for > 0.0 and perf_end(clock_s, army_n > 0):
            quit_app = true
            return

// Everything the last match left, let go: the world, the view, the network, the captures' extras.
def new_match_reset():
    view_reset()
    reset_world()
    ground_mesh = nil
    ground_quad = nil
    relief_built = false
    relief = []
    relief_faces = []
    relief_tops = []
    relief_rims = []
    occluders = []
    mask_version = -1
    doodad_list = []
    bld_seen.clear()
    busts.clear()
    hud_culture = "?"
    unit_dir.clear()
    last_aim.clear()
    unit_sound_of.clear()
    aim_moved.clear()
    unit_kick.clear()
    last_kind.clear()
    last_owner.clear()
    critters = []
    critter_towns.clear()
    town_tick_seen = -1
    town_parts = []
    town_emit.clear()
    town_builders = []
    path_bytes = []
    typing_text = false
    tree_open = false
    build_menu = false
    arming_attack = false
    arming_ability = false
    pad_wheel = []
    clock_s = 0.0
    p_id = []
    p_x = []
    p_y = []
    if in_net_match: link.closed = true
    hosting = false
    join_ip = ""
    net_seats = []
    in_net_match = false
    net_on = false
    ME = 0
    skirmish = false
    army_n = 0
    follow = false
    look_at_army = false
    ai_levels = []
    back_to_lobby = false
    ui_setup("")

// ------------------------------------------------------------------ the game: the lobby, a match, back to the lobby
// "lobby" opens the front end (game/lobby.lobster) on its title, or page:<name> (title, setup, lab, saves, net) with
// races:A|B... typed; "lobby races:A|B" (no page) goes straight to the match. After a match from the lobby, back to it.
if args[1] == "lobby":
    if map_arg != "": lobby_map = map_arg
    if mode_arg != "": lobby_mode = mode_arg
    lobby_prompts = if pack_prompts.length >= 2: pack_prompts else: [ "sewer rats with cheese hammers", "angry swamp frogs with reed spears" ]
    if races_arg != "": lobby_prompts = tokenize(races_arg, "|", " ")
var front_first = args[1] == "lobby" and join_ip == "" and not hosting and (races_arg == "" or lab_arg or page_arg != "")
while not quit_app and not bake_quit:
    if next_choice != "":
        front_choice = next_choice
        next_choice = ""
    elif front_first:
        if vx_source == "":  // (the units' data on the boot screen: in the title's first frame it froze the menu for seconds, #494)
            startup_frame("Loading the armies...", 0.9)
            vx_init()
            build_label_now(net_version())  // (git asked here too, not in the title's first frame)
        front_choice = run_front(if lab_arg: "lab" elif page_arg != "": page_arg else: "title", if races_arg != "": lobby_prompts else: [])
        if front_choice == "": break
    if not make_match():
        if not net_backed_out: break
        net_backed_out = false  // (backed out of a join or a host: the menu again, nothing played)
        link = Link {}
        new_match_reset()
        front_first = true
        continue
    play_match()
    os_cursor_release()
    if quit_app or bake_quit or not back_to_lobby: break
    new_match_reset()
    front_first = true
// The looks the lobby baked and didn't keep (a menu doesn't stop to save, #494): kept now, for the next start.
let vx_left = vx_unsaved.length
for(vx_left) i:
    startup_frame("Keeping the armies for next time...", float(i) / float(vx_left))
    vx_save(vx_unsaved.pop())
view_reset()
fe_free_views()
