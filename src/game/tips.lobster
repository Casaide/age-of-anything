// The opening tips (#92): a match's rules may give their own ("tips": [{ "text", "pad", "done", "label" }]), else the
// classic three. Each is done when its "done" holds for the player: "trained" (more units than when they began),
// "gathering" (one of them gathers), "housing" (a housing building that isn't the hub, or four minutes gone),
// "laid:<building id>" (one laid, built or not), "made:<resource>:<n>" (n of it gathered or made in all, #104) or
// "people:<n>" (n people). "label" is what the bar calls it ("Tip" unless given: a town's goals say "Goal").
class Tip:
    text:string
    pad:string
    done:string
    label:string

let CLASSIC_TIPS = [ Tip { "Click your Town Center, then press Q (or its button) to train a worker.", "D-pad up: your Town Center. Tap A on it for its commands, point at the worker, A to train.", "trained", "Tip" },
                     Tip { "Select a worker and right-click a bush, reeds or stone to gather.", "D-pad down: an idle worker. Aim at a bush, reeds or stone and press X to gather.", "gathering", "Tip" },
                     Tip { "Build a House (select a worker, press H) before your population fills up: every unit needs room.", "Build a House (tap A on a selected worker, Build: Civilian, House, A to place) before your population fills up.", "housing", "Tip" } ]

def match_tips(rules:JV) -> [Tip]:
    let own = glist(rules, "tips")
    if not own.length: return CLASSIC_TIPS
    return map(own) t: Tip { gstr(t, "text", ""), gstr(t, "pad", gstr(t, "text", "")), gstr(t, "done", ""), gstr(t, "label", "Tip") }

// The text after a "done"'s kind ("made:", "people:"), if it starts with that kind; "" if it doesn't.
def done_arg(done:string, kind:string) -> string:
    if done.length <= kind.length or substring(done, 0, kind.length) != kind: return ""
    return substring(done, kind.length, done.length - kind.length)

def tip_done(t:Tip, p:int, units0:int) -> bool:
    if t.done == "trained": return (filter(u_owner) o: o == p).length > units0
    if t.done == "gathering": return (filter(u_owner.length) i: u_owner[i] == p and u_task[i] == GATHER).length > 0
    if t.done == "housing":
        return tick > 20 * 240 or (filter(b_owner.length) b: b_owner[b] == p and has_role(b_kind[b], ROLE_HOUSING) and not has_role(b_kind[b], ROLE_HUB)).length > 0
    if substring(t.done, 0, min(5, t.done.length)) == "laid:":
        let k = btype_named(substring(t.done, 5, t.done.length - 5))
        assert k >= 0
        return (filter(b_owner.length) b: b_owner[b] == p and b_kind[b] == k).length > 0
    let made = done_arg(t.done, "made:")
    if made != "":
        let parts = tokenize(made, ":", " ")
        assert parts.length == 2
        let r = find(resource_names) n: n == parts[0]
        assert r >= 0
        let n, ok = string_to_int(parts[1])
        assert ok
        return gathered[r][p] + produced[r][p] >= n
    let people = done_arg(t.done, "people:")
    if people != "":
        let n, ok = string_to_int(people)
        assert ok
        return pop[p] >= n
    assert false
    return false
