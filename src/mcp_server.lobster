// The game's side of Creel's MCP (creel/mcp/README.md): a headless match an agent starts, steps, orders, reads and
// saves while it works on the game or a mod. Run by creel/mcp/creel-mcp.js (with ../creel-mcp.json), not by hand.
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
import mcp.serve

lib_load("../data")
id_load("../data")

var mcp_sides = []::Side  // the players the game's bots play

def mcp_map_found(id:string) -> bool:
    if read_file("../data/maps/" + id + ".json") != nil: return true
    return exists(pack_mods()): get(_.data, "maps/{id}.json") != nil

// args: mods (["steading"]), rules (its id: default the first mod's, or "default"), map, seed (2026), races (one prompt
// a player: default "serfs" twice with Steading, else "romans" and "greeks"), bots (the players a bot plays: default
// none with Steading, else every player but 0).
def mcp_start(args:JV) -> string:
    let mods = gstrs(args, "mods")
    let used = mods_use(mods)
    if used.length != mods.length:
        return "mods not loaded: " + concat_string(map(mods_refused.get_keys()) id: id + " (" + mods_refused.get(id, "") + ")", ", ")
    let steading = mods.length > 0 and mods[0] == "steading"
    let rules_id = gstr(args, "rules", if mods.length and read_file("../mods/{mods[0]}/data/rules/{mods[0]}.json") != nil: mods[0] else: "default")
    let rules = load_rules(rules_id)
    if not rules.keys.length: return "no rules \"{rules_id}\""
    let map_id = gstr(args, "map", if steading: "steading_vale" else: "reed_meadow")
    if not mcp_map_found(map_id): return "no map \"{map_id}\" in data/maps or the mods\' maps"
    var prompts = gstrs(args, "races")
    if not prompts.length: prompts = if steading: [ "serfs", "serfs" ] else: [ "romans", "greeks" ]
    let races = map(prompts) p: generate(p, rules, 0)
    new_world(gint(args, "seed", 2026), map_id, races, rules, [])
    var bots = map(glist(args, "bots")) v: as_int(v)
    if not has(args, "bots") and not steading: bots = filter(prompts.length) p: p != 0
    mcp_sides = map(filter(bots): _ >= 0 and _ < prompts.length) p: full_side(p)
    return ""

def mcp_step():
    think_all(mcp_sides)
    wstep()

def mcp_bots() -> [Bot]:
    let bots = []::Bot
    for(mcp_sides) s:
        if s.full: bots.push(s.full)
    if not bots.length: bots.push(new_bot(1))  // (a save with no bot is read as a failed load)
    return bots

// (the MCP's saves are in its scratch folder, an absolute path)
def mcp_save(path:string) -> string: return if write_file(path, world_bytes(mcp_bots()), 0, 1): "" else: "couldn\'t write {path}"

def mcp_load(path:string) -> string:
    let why = save_refusal_of(path)
    if why != "": return why
    let bots = load_world(path)
    if not bots.length: return "{path} isn\'t a save"
    let botted = map(mcp_sides) s: s.player  // (the players bots played before: a save made with none has a stand-in bot)
    mcp_sides = map(filter(bots) b: contains(botted, b.player)) b: Side { b.player, b, nil, nil }
    return ""

mcp_serve()
