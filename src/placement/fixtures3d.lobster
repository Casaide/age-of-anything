// ------------------------------------------------------------------ regression fixtures for the 3D check (tests/placement/fixtures_3d.gd)
// Each puts back a configuration Dominic caught (an old model, anchor, lean or rule) and asserts the check FAILS it
// with the rule that names the bug, then that the same unit passes that rule as it is now (the control). A fixture
// that doesn't fail is a check that has gone blind.

class Fixture:
    what:string
    label:string                     // the case it runs on
    rules:[string]                   // it must fail one of these, and the unit as it is now none of them
    which:int                        // its setup (fixture_set)
    recipe:JV? = nil                 // its own unit (else the case's)

// The bear mount's neck in round B2 (data/later/bears.json before B3): short, sloping down from the hump to a head
// set on it, a step between them ("mounted bears I think have broken neck still").
let B2_BEAR_NECK = "\{\"neck\": \{\"from\": [9.0, 17.0], \"to\": [13.0, 12.4], \"r\": [4.0, 3.4], \"into\": null\}, \"sit\": \{\"poses\": \{\"sit2\": \{\"head\": [-1.6, 4.4]\}, \"sit\": \{\"head\": [-2.0, 5.0]\}\}\}\}"
let TC1_RATS = "composite: sewer rats tc1_a_junk hauled by a cat"
var kept_kit:JV? = nil
var kept_haul:JV? = nil

// The leather cap before 2026-10-12: half a unit lower, its brim a darker band.
def old_cap() -> Spec:
    let n = mnode()
    let leather = surf("leather", float3 { 0.9, 0.82, 0.72 }, 3.0)
    add_child(n, dome(float3 { 4.9, 3.6, 4.7 }, leather, float3 { 0.0, -3.0, 0.0 }))
    add_child(n, ring(4.6, 5.3, surf("leather", float3 { 0.7, 0.6, 0.5 }, 2.0), float3 { 0.0, -3.0, 0.0 }))
    add_child(n, blob(float3_1 * 0.6, leather, float3 { 0.0, 0.7, 0.0 }))
    return spec_of(n)

// Puts a fixture's old configuration back (on) or today's (off).
def fixture_set(f:Fixture, r:JV, on:bool):
    switch f.which:
        case 0: mirror_legs = not on
        case 1:
            rat_hunch = if on: -15.0 else: RAT_LEAN
            rat_head_follows = not on
        case 2:
            rat_hunch = if on: -15.0 else: RAT_LEAN
            rat_torso_x = if on: 1.4 else: 0.8
        case 3: rig_old_bob = on
        case 4: rig_old_seat = on
        case 5:
            let b = part("body.beetle")
            let cut = filter(gstrs(b, "cut")) c: c != "legs"
            if not on: cut.push("legs")
            set(b, "cut", jstrs(cut))
        case 6:
            if on:
                let k = kit_kits.get("bear_mount")
                kept_kit = k
                if k: kit_kits.set("bear_mount", kit_merge(k, parse_json(B2_BEAR_NECK)))
            else:
                let k = kept_kit
                if k: kit_kits.set("bear_mount", k)
        case 7:
            if on: rig_overrides.set("helm.cap", old_cap())
            else: rig_overrides.clear()
        case 8: set(gobj(part("body.frog"), "corpse"), "body", jstr(if on: "" else: "limp"))
        case 9:
            let haul = at(r, "haul")
            if on:
                kept_haul = deep_copy(at(haul, "parts"))
                rig_overrides.set("concept.tc1_a_junk", cart_a_v1("junk", colours_for(rstr(r, "skin"), rstr(r, "family"), float3 { 1.0, 0.0, 1.0 })))
                set(haul, "parts", jobj())
            else:
                rig_overrides.clear()
                let kh = kept_haul
                if kh: set(haul, "parts", kh)
        default: pass()

// The rules a unit fails (rule -> its first failing view) with the fixture's setup on or off.
def fixture_rules(f:Fixture, r:JV, on:bool) -> dictionary<string, string>:
    check_results.clear()
    while check_order.length: check_order.pop()
    vox_cache.clear()
    attach_cache.clear()
    vox_cached = 0
    rig_clear()
    if on: fixture_set(f, r, true)
    check_unit(f.label, r)
    if on: fixture_set(f, r, false)
    rig_clear()
    vox_cache.clear()
    attach_cache.clear()
    let out = dictionary<string, string>(63)
    for(check_order) key:
        let fails = check_results.get(key) or []::string
        if fails.length: out.set(tokenize(key, "|", "")[0], fails[0])
    return out

// [all caught, lines]
def fixtures_3d(cases:[Case]) -> bool, [string]:
    def case_recipe(label:string) -> JV:
        for(cases) c:
            if c.label == label: return c.recipe
        assert false
        return jobj()
    let human = deep_copy(case_recipe("romans spear"))
    set(at(human, "parts"), "head_gear", jstr("helm.cap"))
    let cap_fixture = Fixture { "the leather cap\'s brim across the brows like a headband (the cap before it sat higher)",
                                "human in a leather cap", ["A2 an open cap clear of the brow"], 7 }
    cap_fixture.recipe = human
    let list = [
        Fixture { "newt legs not reaching the ground facing left (legs not turned to their side: the far legs\' feet under the belly)",
                  "frog on newt_fire", ["A4 feet out to their own side", "A1 weight over the feet"], 0 },
        Fixture { "the rat\'s head floating ahead of its body with a gap at the neck (its body leaning back: Dominic\'s crossbowman)",
                  "sewer rats archer", ["A2 head joint on its body\'s surface"], 1 },
        Fixture { "the rat\'s head on its armour, both in front of the body (the body leaning back out of its bottle-cap armour)",
                  "sewer rats spear age 2", ["A2 worn armour centred on the torso", "A2 worn armour on its body"], 2 },
        Fixture { "a walk whose body rose as its legs spread (no foot on the ground mid-stride)", "romans spear", ["A1 walking, a foot planted"], 3 },
        Fixture { "a frog sunk into the hummingbird it rides (riders dropped a fixed amount below the seat)",
                  "frog on hummingbird", ["A2 rider not sunk into its mount", "A2 the seat on its mount\'s back"], 4 },
        Fixture { "a beetle\'s legs as one sprite for every hip (far feet under the belly, rear legs facing forward)",
                  "rat on beetle", ["A2 one-sided legs baked at each hip", "A4 feet out to their own side"], 5 },
        Fixture { "the bear mount\'s head on a short neck below the hump, a notch between them (round B2: \"broken neck\")",
                  "kit: human on bear bear_brown", ["A2 head joins the neck without a notch"], 6 },
        cap_fixture,
        Fixture { "a dead frog propped up on its far hand, the belly in the air (HF2b: the arms still braced as it stood; Dominic: \"looks like it\'s floating\")",
                  "swamp frogs spear", ["D1 a corpse lies on the ground"], 8 },
        Fixture { "TC1 A for rats as first drawn (the traces loose lines to the air by the cat\'s chest, no harness, the cart floating behind)",
                  TC1_RATS, ["C2 a hauler wears its harness", "C2 a hauler\'s hitches on the cart", "C3 no loose ends"], 9 },
    ]
    var ok = true
    let said = []::string
    for(list) f:
        let own = f.recipe
        let r = if own: own else: case_recipe(f.label)
        let bad = fixture_rules(f, r, true)
        let good = fixture_rules(f, r, false)
        let caught = filter(f.rules) rule: bad.get(rule) != nil
        let still = filter(caught) rule: good.get(rule) != nil
        let passed = caught.length > 0 and still.length == 0
        ok = ok and passed
        let msg = if caught.length: bad.get(caught[0]) or "" else: "no failure"
        said.push((if passed: "PASS" else: "BROKEN") + " fixture: {f.what}\n      FAILS " + (if caught.length: concat_string(caught, ", ") else: "{f.rules}") +
                   " ({msg})" + (if still.length: "\n      but the control fails too: " + concat_string(still, ", ") else: ""))
    return ok, said
