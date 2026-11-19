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
import gen.scenario_out
import gen.reset
import gen.save
import gen.mods
import net.lockstep
import net.lan
import net.swarm
import game.build_id
// The lobby's home-network pieces (creel/src/net/lan.lobster), headless (#498):
// - this machine's address read from what each OS's tool prints (the Deck's hostname has no -I: its scan found nobody)
// - the network version: data the sim reads splits builds; files only the looks read (atmosphere, sound, tips) don't
var bad = 0
def expect(what:string, got:string, want:string):
    if got != want:
        print "FAIL {what}: got \"{got}\", want \"{want}\""
        bad++

expect("macOS ipconfig getifaddr", ipv4_in("192.168.0.3\n"), "192.168.0.3")
expect("ip -4 -o addr (SteamOS)", ipv4_in("3: wlan0    inet 192.168.0.42/24 brd 192.168.0.255 scope global dynamic noprefixroute wlan0\\       valid_lft 86000sec preferred_lft 86000sec\n"), "192.168.0.42")
expect("hostname -I", ipv4_in("10.0.0.7 172.17.0.1 fe80::1 \n"), "10.0.0.7")
expect("loopback skipped", ipv4_in("1: lo    inet 127.0.0.1/8 scope host lo\n2: wlan0    inet 192.168.1.9/24 brd 192.168.1.255 scope global wlan0\n"), "192.168.1.9")
expect("an error message", ipv4_in("hostname: invalid option -- \'I\'\n"), "")
expect("nothing", ipv4_in(""), "")
expect("not an address", ipv4_in("1.2.3\n"), "")

// two builds that differ only in look-only files are one version; one that differs in a unit file is another (tests/lan)
def version_of(dir:string) -> string:
    lib_root = "../tests/lan/" + dir
    net_version_cache = ""
    return net_version()
let va = version_of("a")
expect("look-only files keep the version", version_of("b"), va)
if version_of("c") == va: expect("a unit file changes the version", va, "another version")

// the menu's build line (#500): the Deck's build_id.txt, else git's short hash (+changes), and the network version
expect("the build id file", build_label("1a2b3c4\n", "", "", "7f79e3ef717d"), "build 1a2b3c4, net 7f79e3ef717d")
expect("git, clean", build_label("", "9e8d7c6\n", "", "abc"), "build 9e8d7c6, net abc")
expect("git, local edits", build_label("", "9e8d7c6\n", " M src/game.lobster\n", "abc"), "build 9e8d7c6+changes, net abc")
expect("no git, no file", build_label("", "", "", "abc"), "build unknown, net abc")

// the real tools (launch_subprocess doesn't search PATH: a bare "git" or "ip" never ran, #500)
if my_ipv4() == "": expect("this machine has a home-network address", "", "an address")
if find_string(build_label_now("x"), "build unknown") >= 0: expect("git names this checkout", build_label_now("x"), "build <hash>, net x")

// what's typed in the join box (#514): a join code in any case, with or without its dash, is a code; an address isn't
for([ [ "w5yku-69i3p", "w5yku69i3p" ], [ "W5YKU69I3P", "w5yku69i3p" ], [ " w5yku 69i3p", "w5yku69i3p" ], [ "192.168.1.20", "" ], [ "127.0.0.1", "" ], [ "w5yku-69i3", "" ], [ "w5yku-69i3pq", "" ], [ "w5ykl-69i3p", "" ] ]) t:
    if join_code_in(t[0]) != t[1]: expect("join code in \"{t[0]}\"", join_code_in(t[0]), t[1])

// a scan says what it reached (#506): a host listening here is reached on 127.0.0.1, and the note names this machine
let test_port = 47829
let door = door_open(test_port, "check", "meadow")
if door.error != "": expect("a test host opens", door.error, "")
lan_scan(0.6, test_port)
if lan_seen.reached < 1: expect("the scan reaches the host on this machine", string(lan_seen.reached), ">= 1")
if lan_seen.me != my_ipv4(): expect("the scan knows this machine", lan_seen.me, my_ipv4())
if find_string(lan_scan_note(), "from {my_ipv4()}") < 0: expect("the note names this machine", lan_scan_note(), "... from {my_ipv4()} ...")
print lan_scan_note()

if bad: set_exit_code(1)
print if bad: "lan_check: {bad} failed" else: "lan_check: all pass"
