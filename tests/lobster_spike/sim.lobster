// The Lobster sim spike (2026-10-25): src/sim ported to Lobster, headless, checked against the
// GDScript sim by a hash of its state after every tick (scenarios from tests/lobster_spike/export.gd).
// The modules in lib/ follow src/sim: consts and fixed (fixed.gd), state (the World's, units.gd's and
// buildings.gd's arrays), flow (flow.gd: fields, patching, the field cache), spatial (spatial.gd),
// orders (World's orders and formations, MOVE / ATTACK_MOVE / STANCE), movement (World._move,
// _separate, the spots round a rect), fog (fog.gd's visible grid), map (sim_map.gd's changes and
// World._sync_map), economy (economy.gd: buildings, jobs, farms, training, its commands) and combat
// (combat.gd, shots.gd). The tick and the scenario file are here.
// Left out (none in the scenarios, asserted by the exporter): walls, gates, bridges, pens, towers,
// research and ageing up, heroes, healers, animals, siege weapons, trade, garrisons, webs, trails,
// wading, shift-queued orders.
// Run: lobster sim.lobster -- <scenario file> [dump tick] [trace tick]

import std
import dictionary
import .lib.consts
import .lib.fixed
import .lib.tokens
import .lib.state
import .lib.flow
import .lib.spatial
import .lib.orders
import .lib.movement
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
import .lib.animals
import .lib.bridges
import .lib.walls
import .lib.commands
import .lib.ai_cfg
import .lib.scout
import .lib.land
import .lib.expand
import .lib.bot
import .lib.world

let args = command_line_arguments()
assert args.length >= 1
start_world(args[0])
let n0 = u_x.length
for(b_id.length) b: assert not bt_special[b_kind[b]]

expect("HASHES")
let ticks = next_int()
let expected = read_ints(ticks)
// Arguments after the file: "bots" (the eco bots play, in Lobster, instead of the orders recorded
// from GDScript's), dump:<tick>, trace:<tick>.
var dump_tick = -1
var bots_mode = false
for(args) a, k:
    if k > 0:
        if a == "bots": bots_mode = true
        if a == "cmdlog": cmd_log = true
        let key, val = split_string(a, ":")
        let v, ok = string_to_int(val)
        if key == "dump": dump_tick = v
        if key == "trace": trace_tick = v
let bots = map(num_players) p: EcoBot { p }
let full_bots = map(num_players) p: new_bot(p)
if bots_mode:
    cmds = []::Cmd

var spent = 0.0
var first_bad = -1
for(ticks) k:
    let t0 = seconds_elapsed()
    if bots_mode:
        if scenario_mode == "match":
            events_on = true
            for(full_bots) bot: full_bot_think(bot)
        else:
            for(bots) bot: bot_think(bot)
    step()
    spent += seconds_elapsed() - t0
    if first_bad < 0 and state_hash() != expected[k]:
        first_bad = k
    if tick == dump_tick:
        write_file(args[0] + ".lobster.dump", dump_state(), 0, 1)
var left = map(num_players + 1): 0   // (and gaia's animals)
for(u_owner) p: left[p]++
print "{n0} units, {ticks} ticks, {cmds.length} orders; at the end: units {left}, buildings {b_id.length}, gathered {gathered}, lanes {walks.length}, gates {(filter(b_kind) k: bt_gate[k] != 0).length}"
print "lobster step: {spent * 1000.0 / ticks} ms a tick"
if first_bad < 0:
    print "hashes: all {ticks} match"
else:
    print "hashes: first mismatch after tick {tick - ticks + first_bad} (index {first_bad})"
