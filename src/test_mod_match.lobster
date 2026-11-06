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
import gen.mods
import lib.consts
import lib.fixed
import lib.tokens
import lib.state
import lib.flow
import lib.spatial
import lib.orders
import lib.movement
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
import gen.setup
import gen.modes
import gen.start
import gen.reset
import gen.save
import testkit.kit

// A whole bot match with a mod that takes most of the game out (mods/scifi_short), played twice for the same result,
// and shorter matches with one building taken out at a time, so a bot path that needs it shows.
// Run from src:  lobster test_mod_match.lobster -- [map_id]   (reed_meadow)
// Prints "N passed, M failed" and exits 1 on a failure.

let args = plain_args(command_line_arguments())
let map_id = if args.length > 0: args[0] else: "reed_meadow"
let LIMIT = 45 * 1200
let SINGLE_LIMIT = 15 * 1200
let SINGLES = [ "archery_range", "armoury", "barracks", "castle", "farm", "lumber_camp", "market", "mill", "mining_camp", "pen", "siege_workshop",
                "stable", "university", "wall", "watchtower", "wonder" ]
lib_load("../data")
id_load("../data")

// The match: its state hash, or -1 if something it shouldn't have turned up.
def play(races:[JV], rules:JV, limit:int, allowed:[string]) -> int:
    new_world(2026, map_id, races, rules, [])
    let sides = map(2) p: full_side(p)
    var h = 0
    while tick < limit and winner < 0:
        think_all(sides)
        wstep()
        for(u_kind) k, i:
            if allowed.length and u_owner[i] < 2 and t_animal[k] == 0 and not has_s(allowed, t_slot[k]):
                check(false, "only the roster trains (P{u_owner[i]}: {t_slot[k]})")
                return -1
        if tick % 30 == 0: h = (h * 31 + state_hash()) & ((1 << 40) - 1)
    return h

let used = mods_use([ "scifi_test", "scifi_short" ])
check(used.length == 2, "the mods load ({mods_refused.get_keys()}: {map(mods_refused.get_keys()) id: mods_refused.get(id, "")})")
let rules = load_rules("short")
let races = map([ "future soldiers", "sewer rats from the future" ]) p: generate(p, rules, 0)
let allowed = [ "worker", "spear", "infantry", "skirmisher" ]
let h1 = play(races, rules, LIMIT, allowed)
print "scifi_short on {map_id}: winner {winner} at {clock(tick)}, ages {ages[0]} and {ages[1]}, {bt_name.length} building types, lost {lost[0]} and {lost[1]}"
check(winner >= 0, "the match ends with a winner")
check(lost[0] + lost[1] > 0, "the sides fight")
check(not has_s(bt_name, "stable") and not has_s(bt_name, "wonder") and has_s(bt_name, "barracks"), "the buildings taken out are gone")
check(ages_list.length == 2, "two ages")
check(ages[0] <= 2 and ages[1] <= 2 and (ages[0] == 2 or ages[1] == 2), "someone reaches age 2")
var rifles = 0
for(t_slot) s, k: if s == "skirmisher" and t_player[k] < 2: rifles++
check(rifles == 2, "each side has its rifles")
let h2 = play(races, rules, LIMIT, allowed)
check(h1 == h2 and h1 >= 0, "the same match again ({h1}, {h2})")
// Saved and loaded with the mod on, the same ticks follow.
new_world(2026, map_id, races, rules, [])
var bots = map(num_players) p: new_bot(p)
def run_ticks(n:int) -> [int]:
    return map(n):
        for(bots) bot: full_bot_think(bot)
        step()
        state_hash()
run_ticks(6000)
let save_path = "aoa_mod_match.sav"
check(save_world(save_path, bots), "the match saves")
let want = run_ticks(1000)
reset_world()
bots = load_world(save_path)
delete_file(save_path)
let got = run_ticks(1000)
check(equal(want, got), "1000 ticks after a load match")
let rifle = audio_file("sfx/shoot_pulse_1.wav")
check(rifle == "../mods/scifi_short/audio/sfx/shoot_pulse_1.wav", "the rifle sound comes from the mod ({rifle})")
check(audio_file("sfx/shoot_arrow_1.wav") == AUDIO_DIR + "/sfx/shoot_arrow_1.wav", "the rest from the game")

// A save names its mods: without them it's refused by name, and nothing is touched; with them it loads.
new_world(2026, map_id, races, rules, [])
bots = map(num_players) p: new_bot(p)
run_ticks(20)
check(save_world(save_path, bots), "a save with the mods")
mods_use([])
let refused_why = save_refusal_of(save_path)
check(find_string(refused_why, "scifi_test") >= 0, "without the mods it says which ({refused_why})")
let units_before = u_id.length
check(not load_world(save_path).length and save_refused != "" and u_id.length == units_before, "and refuses, touching nothing")
mods_use([ "scifi_test", "scifi_short" ])
reset_world()
check(load_world(save_path).length > 0, "with the mods it loads")
delete_file(save_path)
mods_use([])

// A save from before save formats: the base game (D-141).
reset_world()
let old_bots = load_world("../tests/saves/before_formats.sav")
check(old_bots.length == 2 and tick > 0, "a save from before formats loads (tick {tick}; {save_refused})")
bots = old_bots
run_ticks(20)
check(tick > 0, "and plays on")
check(save_refusal(SAVE_FORMAT + 1, []::string) != "", "a save from a newer build is refused")
// One building at a time: the bots play on without it.
for(SINGLES) id:
    let gone = parse_json("\{\"buildings\":\{\"{id}\":\{\"remove\":true\}\}\}")
    let trial = pack_open("trial", "", jobj())
    set(trial.data, "buildings.json", gone)
    lib_packs = [ lib_packs[0], trial ]
    id_load(lib_root)
    let r2 = load_rules("default")
    let rc = map([ "centaur romans", "sewer rats" ]) p: generate(p, r2, 0)
    play(rc, r2, SINGLE_LIMIT, []::string)
    var army = 0
    for(u_kind) k, i:
        if u_owner[i] < 2 and t_animal[k] == 0 and not t_worker[k]: army++
    print "  without {id}: {clock(tick)}, winner {winner}, army {army}, ages {ages[0]} {ages[1]}, lost {lost[0]} {lost[1]}"
    check(lost[0] + lost[1] > 0 or winner >= 0, "without {id} the bots still fight")
lib_packs = [ lib_packs[0] ]
id_load(lib_root)
print "\n{checks - failures} passed, {failures} failed"
if failures > 0: set_exit_code(1)
