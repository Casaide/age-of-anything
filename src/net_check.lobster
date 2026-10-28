import std
import dictionary
import gen.json
import gen.sha256
import gen.rng
import gen.datalib
import gen.identity
import gen.pricing
import gen.heroes
import gen.generator
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
import gen.scenario_out
import gen.reset
import gen.save
import net.lockstep
import net.lan

// A network match, headless (src/net, tests/net_check.gd): two processes on one machine linked over
// TCP. The host sets the match up and sends it whole; then each runs the same world in lockstep,
// with only its own side's bot playing (its commands travel to the other). Both print their last
// hash; they must match, with no desync on the way.
// Run from src:  sh net_check.sh [ticks]   (or by hand: -- host <ticks> / -- join <ticks>)
let args = command_line_arguments()
let role = args[0]
let ticks = string_to_int(args[1])
var people = 2                    // players:<n>: that many people (a 2v2 on four: teams 1 and 2)
for(args) a:
    if starts_with(a, "players:"): people = string_to_int(a.substring(8, a.length - 8))
var me = 0
var bots = []::Bot
var link = Link {}
let others = []::Link             // the host's other joiners
let t_wait = seconds_elapsed()
if role == "host":   // (through the door: a scan's '?' gets an answer, a 'J' becomes the match)
    lib_load("../data")
    let door = door_open(NET_PORT, "net_check", "reed_meadow")
    let joined = []::Link
    while joined.length < people - 1:
        assert door.error == ""
        assert seconds_elapsed() - t_wait < 60.0
        let got = door_tick(door)
        if got:
            net_send(got, 'W', string(joined.length + 1))   // (your seat)
            joined.push(got)
        tcp.wait(door.listener, nil, false, 0.02)
    link = joined[0]
    for(joined.slice(1, -1)) l: others.push(l)
else:
    lib_load("../data")
    let found = if has_s(args, "noscan"): []::LanHost else: lan_scan(1.5)
    let names = map(found) h: h.name + "@" + h.ip
    print "join: found {found.length} host(s): {names}"
    link = net_join("127.0.0.1", NET_PORT)
    while not net_ready(link):
        if link.error != "": print "join: {link.error}"
        assert link.error == ""
        assert seconds_elapsed() - t_wait < 20.0
        tcp.wait(nil, link.sock, true, 0.05)
    join_hello(link)
if role == "host":
    lib_load("../data")
    id_load("../data")
    let rules = load_rules("default")
    set(rules, "animals", jbool(true))
    let prompts = ["sewer rats with cheese hammers", "frogs with spears", "moonbears", "tiny vikings"]
    let races = map(people) k: generate(prompts[k % prompts.length], rules, 0)
    setup_world(20261010, if people > 2: "reed_meadow_2v2" else: "reed_meadow", races, rules, if people > 2: map(people) k: k / 2 else: [])
    bots = map(num_players) p: new_bot(p)
    let bytes = world_bytes(bots)
    net_send(link, 'S', bytes)
    for(others) l: net_send(l, 'S', bytes)
    print "host: sent the match ({bytes.length / 1024} KB)"
else:
    while not bots.length:
        let later = []::[string]
        for(net_poll(link)) f:
            if f[0] == "W": me = string_to_int(f[1])
            elif f[0] == "S": bots = load_world_bytes(f[1])
            elif bots.length: later.push(f)   // (a turn that came with the match: kept for the lockstep)
        net_unread(link, later)
        assert not link.closed
        tcp.wait(nil, link.sock, false, 0.05)
    print "join: got the match at tick {tick}, {u_id.length} units"
events_on = true
let ls = new_lockstep(link, me, map(people) k: k)
ls.more = others
ls.relay = role == "host"
let t0 = seconds_elapsed()
var waits = 0
while tick < ticks and ls.desync == "" and not link.closed:
    ls_receive(ls)
    if tick % TICKS_PER_TURN == 0 and not may_run(ls, tick / TICKS_PER_TURN):
        waits++
        tcp.wait(nil, link.sock, false, 0.002)
    else:
        full_bot_think(bots[me])
        step()
        ls_after_step(ls)
// The last turns' hashes: keep the link up until the other side's are in.
let t_end = seconds_elapsed()
while ls.mine.get_keys().length and ls.desync == "" and not link.closed and seconds_elapsed() - t_end < 5.0:
    ls_receive(ls)
    tcp.wait(nil, link.sock, false, 0.01)
let checked = (ticks / HASH_EVERY) - ls.mine.get_keys().length
print "{role}: tick {tick}, {u_id.length} units, {b_id.length} buildings, last hash {state_hash()}, {checked} hashes checked, {waits} waits, {int((seconds_elapsed() - t0) * 1000.0)} ms{if ls.desync != "": ", DESYNC: " + ls.desync else: ""}"
