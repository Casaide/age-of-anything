import from "../creel/src"
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
import gen.scenario_out
import gen.reset
import gen.save
import lua.parse
import gen.mods
import net.lockstep
import net.lan
import net.swarm
import net.room
import game.levels

// A network match paced as the game plays it, headless (#151 in Creel): net_check's two processes, each stepping its frames
// at 60 a second with sim_owe and sim_run's rules (time owed, a turn not in yet waits). The joiner loads late:<s> later;
// the match must still start together, with no stall longer than a turn and a bit, no burst of saved-up ticks, the hashes
// matching. Run from src:  sh net_pace_check.sh [ticks] [late]
let args = command_line_arguments()
let role = args[0]
let ticks = string_to_int(args[1])
var people = 2       // players:<n>: that many people (a 2v2 on four: teams 1 and 2)
var port = NET_PORT  // port:<n>: another port, so these can run beside another pair

// mods:a,b: these packs in use on this side. refused: this joiner expects the host to turn it away.
def use_mods():
    for(args) a:
        if starts_with(a, "mods:"): mods_use(tokenize(a.substring(5, a.length - 5), ",", " "))
var code = ""                      // code:<join code>: join through the sidecar (online play, #514)
let in_room = has_s(args, "room")  // room: through the lobby (#519): joiners take sides, type their army, then the host starts
var sides = 2                      // sides:<n>: the room's sides (4: a 2v2, AIs in the sides no one takes)
var want_side = -1                 // side:<n>: the side this joiner takes
for(args) a:
    if starts_with(a, "sides:"): sides = string_to_int(a.substring(6, a.length - 6))
    if starts_with(a, "side:"): want_side = string_to_int(a.substring(5, a.length - 5))
    if starts_with(a, "code:"): code = a.substring(5, a.length - 5)
    if starts_with(a, "bootstrap:"): swarm_setup.extra = "--bootstrap " + a.substring(10, a.length - 10)  // (a local test DHT)
    if starts_with(a, "players:"): people = string_to_int(a.substring(8, a.length - 8))
    if starts_with(a, "port:"): port = string_to_int(a.substring(5, a.length - 5))
var me = 0
var bots = []::Bot
var link = Link {}
let others = []::Link  // the host's other joiners
let hosted = []::Room  // the host's room
let t_wait = seconds_elapsed()
let words = [ "sewer rats with cheese hammers", "frogs with spears", "moonbears", "tiny vikings" ]
if role == "host":  // (through the door: a scan's '?' gets an answer, a 'J' becomes the match)
    lib_load("../data")
    use_mods()
    let room = room_open(port, "net_check", if sides > 2: "reed_meadow_2v2" else: "reed_meadow")
    hosted.push(room)
    let door = room.door
    if has_s(args, "swarm"):  // (online too: a join code through the sidecar)
        let sw = swarm_host(port)
        while sw.code == "" and sw.error == "":
            assert seconds_elapsed() - t_wait < 20.0
            swarm_poll(sw)
        assert sw.error == ""
        print "host: join code {sw.code}"
        for(args) a: if starts_with(a, "codefile:"): write_file(a.substring(9, a.length - 9), sw.code, 0, 1)  // (print waits in a buffer)
    let joined = []::Link
    if in_room:  // (#519) the room: until every joiner holds a side and has typed its army
        room_sides(room, map(sides) k: if sides > 2: k / 2 else: k, map(sides) k: words[k % words.length], map(sides) k: 0)
        let hold = has_s(args, "hold")  // hold: never start (captures of a joiner's lobby)
        while hold or room_players(room) < people - 1 or (filter(room.sides) rs: rs.who == ROOM_PLAYER and rs.prompt == "").length:
            assert door.error == ""
            assert hold or seconds_elapsed() - t_wait < 60.0
            room_tick(room)
            tcp.wait(door.listener, nil, false, 0.02)
        let seen = map(room.sides) rs: rs.who + ":" + rs.prompt
        print "host: the room: {seen}"
    else:
        while joined.length < people - 1:
            assert door.error == ""
            assert seconds_elapsed() - t_wait < 60.0
            let got = door_tick(door)
            if got:
                net_send(got, 'W', string(joined.length + 1))  // (your seat)
                joined.push(got)
            tcp.wait(door.listener, nil, false, 0.02)
    if joined.length:
        link = joined[0]
        for(joined.slice(1, -1)) l: others.push(l)
else:
    lib_load("../data")
    use_mods()
    let found = if has_s(args, "noscan"): []::LanHost else: lan_scan(1.5, port)
    let names = map(found) h: h.name + "@" + h.ip
    print "join: found {found.length} host(s): {names}"
    var at = port
    if code != "":
        assert join_code_in(code) != ""
        let sw = swarm_join(join_code_in(code), 0)
        while sw.port == 0 and sw.error == "":
            assert seconds_elapsed() - t_wait < 20.0
            swarm_poll(sw)
        assert sw.error == ""
        at = sw.port
        print "join: through the sidecar at {at} ({sw.out})"
    link = net_join("127.0.0.1", at)
    while not net_ready(link):
        if link.error != "": print "join: {link.error}"
        assert link.error == ""
        assert seconds_elapsed() - t_wait < 20.0
        tcp.wait(nil, link.sock, true, 0.05)
    if not in_room: join_hello(link)
var seats = map(people) k: k                                   // the people's sides (lockstep's players)
let levels = map(sides) k: if k % 2 == 1: "easy" else: "hard"  // (the AIs' levels: the joiner must hear them)
if role != "host" and in_room:                                 // (#519) in the room: take the side asked for, type an army, wait for the start
    let g = guest_new(link)
    var asked = false
    while g.world == "":
        assert g.error == ""
        assert seconds_elapsed() - t_wait < 60.0
        guest_tick(g)
        if g.side >= 0 and want_side >= 0 and g.side != want_side and not asked:
            guest_take(g, want_side)
            asked = true
        if g.side >= 0 and (want_side < 0 or g.side == want_side): guest_prompt(g, words[g.side % words.length], 0)
        tcp.wait(nil, link.sock, false, 0.02)
    me = g.side
    seats = g.seats
    ai_levels_set(g.levels)
    bots = load_world_bytes(g.world)
    net_unread(link, g.later)
    print "join: took side {me} of {seats}, got the match at tick {tick}, {u_id.length} units"
if role == "host":
    lib_load("../data")
    id_load("../data")
    use_mods()
    let rules = load_rules("default")
    set(rules, "animals", jbool(true))
    let n = if in_room: sides else: people
    let races = map(n) k: generate(if in_room and hosted[0].sides[k].who == ROOM_PLAYER: hosted[0].sides[k].prompt else: words[k % words.length], rules, 0)
    setup_match(20261010, if n > 2: "reed_meadow_2v2" else: "reed_meadow", races, rules, if n > 2: map(n) k: k / 2 else: [])
    bots = map(num_players) p: new_bot(p)
    if in_room:
        let lv = map(sides) k: if hosted[0].sides[k].who == ROOM_AI: levels[k] else: ""
        ai_levels_set(lv)
        let st, ls_links = room_start(hosted[0], lv)
        seats = st
        link = ls_links[0]
        for(ls_links.slice(1, -1)) l: others.push(l)
    let bytes = world_bytes(bots)
    net_send(link, 'S', bytes)
    for(others) l: net_send(l, 'S', bytes)
    print "host: sent the match ({bytes.length / 1024} KB)"
else:
    while not bots.length and not in_room:
        let later = []::[string]
        for(net_poll(link)) f:
            if f[0] == "W": me = string_to_int(f[1])
            elif f[0] == "X":
                print "join: refused: {f[1]}"
                if has_s(args, "refused"): return from program
                assert false
            elif f[0] == "S": bots = load_world_bytes(f[1])
            elif bots.length: later.push(f)  // (a turn that came with the match: kept for the lockstep)
        net_unread(link, later)
        assert not link.closed
        tcp.wait(nil, link.sock, false, 0.05)
    if not in_room: print "join: got the match at tick {tick}, {u_id.length} units"
events_on = true
let ls = new_lockstep(link, me, seats)
ls.more = others
ls.relay = role == "host"
// ---- paced as the game is (frames at 60 a second, sim_owe and sim_run's rules), each stall on a turn timed (#151 in Creel)
var late = 0.0
for(args) a: if starts_with(a, "late:"): late = string_to_float(a.substring(5, a.length - 5))
if late > 0.0:
    let tl = seconds_elapsed()
    while seconds_elapsed() - tl < late: tcp.wait(nil, nil, false, 0.05)  // (this side loads slower)
ls_begin(ls)                                                              // (every player starts the first tick together: this side's loaded)
let t_begin = seconds_elapsed()
while not ls_begin_tick(ls):
    assert seconds_elapsed() - t_begin < 20.0 and not link.closed
    tcp.wait(nil, link.sock, false, 0.01)
var acc = 0.0
var stall_t0 = -1.0
var stall_long = 0.0
var stall_sum = 0.0
var stall_n = 0
let frame = 1.0 / 60.0
let t_start = seconds_elapsed()
var last = t_start
var frames = 0
var stalled = 0  // frames the sim wanted to step but waited on a turn
var multi = 0    // frames that ran more than 2 ticks
var worst_ms = 0.0
while tick < ticks and ls.desync == "" and not link.closed:
    let now = seconds_elapsed()
    acc = min(acc + (now - last), 0.5)
    last = now
    let w0 = seconds_elapsed()
    ls_receive(ls)
    var ran = 0
    while acc >= 0.05:
        if tick % TICKS_PER_TURN == 0 and not may_run(ls, tick / TICKS_PER_TURN):
            acc = min(acc, 0.05)
            stalled++
            if stall_t0 < 0.0:
                stall_t0 = seconds_elapsed()
                stall_n++
            break
        if stall_t0 >= 0.0:
            let d = seconds_elapsed() - stall_t0
            stall_sum += d
            stall_long = max(stall_long, d)
            stall_t0 = -1.0
        for(bots) b, p:
            if p == me or not contains(seats, p):
                ai_level_for(p)
                full_bot_think(b)
        step()
        ls_after_step(ls)
        acc -= 0.05
        ran++
    if ran > 2: multi++
    let w = (seconds_elapsed() - w0) * 1000.0
    if w > worst_ms: worst_ms = w
    frames++
    let left = frame - (seconds_elapsed() - now)
    if left > 0.0: tcp.wait(nil, link.sock, false, left)
print "{role}: {frames} frames in {seconds_elapsed() - t_start} s, tick {tick}, {stall_n} stalls on a turn, {int(stall_sum * 1000.0)} ms in all, the longest {int(stall_long * 1000.0)} ms, {multi} frames ran 3+ ticks, the worst frame\'s work {int(worst_ms * 10.0) / 10} ms{if ls.desync != "": ", DESYNC " + ls.desync else: ""}"
// The last turns' hashes: keep the link up until the other side's are in.
let t_end = seconds_elapsed()
while ls.mine.get_keys().length and ls.desync == "" and not link.closed and seconds_elapsed() - t_end < 5.0:
    ls_receive(ls)
    tcp.wait(nil, link.sock, false, 0.01)
var bad = 0
def fail(what:string):
    print "FAIL {role}: {what}"
    bad++
if ls.desync != "": fail("out of step: {ls.desync}")
if tick < ticks: fail("stopped at tick {tick} of {ticks}")
if ls.mine.get_keys().length: fail("{ls.mine.get_keys().length} hashes never checked")
if stall_long > 0.25: fail("a stall of {int(stall_long * 1000.0)} ms (a side that loads later must not freeze the other: at most a turn and a bit)")
if multi > 0: fail("{multi} frames ran 3+ ticks (time saved up and rushed through)")
if bad: set_exit_code(1)
print "{role}: {if bad: "{bad} failed" else: "all pass"}"
