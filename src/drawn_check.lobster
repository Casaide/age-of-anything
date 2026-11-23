// What a Steading town was drawn as, from Creel's draw probe (#188), read back from a capture's probe:<json>: every
// carrier is drawn carrying its good, in that good's own pose, not walking empty-handed; every site shows a stage, and
// nothing over it (a site's front was its roof before its walls, #182). drawn_check.sh takes the capture.
//   lobster drawn_check.lobster -- <probe.json>
import from "../creel/src"
import std
import dictionary
import gen.json

var n_checks = 0
var n_failed = 0

def expect(ok:bool, what:string):
    n_checks++
    if not ok:
        n_failed++
        print "FAIL: " + what

let path = command_line_arguments()[0]
let probe = parse_json(assert read_file(path))
let units = glist(probe, "units")
let carriers = filter(units) u: starts_with(gstr(u, "state", ""), "carry_")
expect(carriers.length >= 3, "drawn: some carriers in sight ({carriers.length})")
for(carriers) u:
    let state = gstr(u, "state", "")
    let good = state.substring(6, state.length - 6)
    expect(gstr(u, "carried", "") == good and gbool(u, "exact", false), "drawn: unit {gint(u, "id", 0)} carries {good} in its own pose (drawn carrying \"{gstr(u, "carried", "")}\", exact {gbool(u, "exact", false)})")
let sites = filter(glist(probe, "buildings")) b: gint(b, "stage", -1) >= 0
expect(sites.length >= 1, "drawn: a site in sight ({sites.length})")
for(sites) b:
    let piece = gstr(b, "piece", "")
    expect(find_string(piece, ":stage") >= 0 and not gbool(b, "front", true), "drawn: site {gint(b, "id", 0)} at stage {gint(b, "stage", 0)} shows that stage, nothing over it ({piece}, front {gbool(b, "front", true)})")
print "drawn_check: {n_checks - n_failed} passed, {n_failed} failed"
if n_failed > 0: set_exit_code(1)
