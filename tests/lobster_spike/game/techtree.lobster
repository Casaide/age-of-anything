// ------------------------------------------------------------------ the tech tree page (src/view/tech_tree_model.gd, scenes/tech_tree.gd)
// From data alone: the ages as rows (data/tech.json), the buildings as columns (data/buildings.json,
// its "tree" order), under each building its unit lines (the rules' roster: a node where the unit
// changes, from the age it's first trained) and its research (tracks joined by `after` share a lane),
// packed into lanes so a line or a track runs straight down. For your race: its own unit names, other
// races' own research left off, what it lacks crossed out, research only some races get marked.
// Planned things show as blank frames. F1 in a match; arrows or the wheel scroll it, Esc / F1 close it.
// Imported by game.lobster after the HUD helpers (lobby_text, ui).

class TNode:
    key:string
    kind:string                  // building, unit, research
    name:string
    desc:string
    age:int
    planned:bool
    col:int
    lane = -1
    lacks = false
    race_only = false            // research only some races get, and this race does
    cost = ""

class TColumn:
    name:string
    lanes:int
    x = 0.0                      // where it starts on the page (lanes from the left)

class TTree:
    ages:[string]
    columns:[TColumn]
    nodes:[TNode]
    joins:[int2]                 // node indexes: a line's steps, a research track

def cost_text(c:JV) -> string:
    let parts = []::string
    for(c.keys) r, n:
        let v = as_int(c.a[n])
        if v > 0: parts.push("{v} {r}")
    return concat_string(parts, ", ")

def race_lacks(ident:JV, id:string) -> bool:
    if gbool(su_rules, "full_tech_tree", false): return false
    return has_str(glist(ident, "lacks"), id) or has_str(glist(ident, "lacks_slots"), id)

// The race's unit for a roster slot, and the step of its line at an age (or nil).
def race_unit(race:JV, slot:string) -> JV?:
    for(glist(race, "units")) u:
        if rstr(at(u, "recipe"), "slot") == slot: return u
    return nil

def line_step(unit:JV?, age:int) -> JV?:
    if not unit: return nil
    for(glist(unit, "line")) l:
        if gint(l, "age", 0) == age: return l
    return nil

def build_tree(p:int) -> TTree:
    let race = su_races[p]
    let ident = su_idents[p]
    let rules = su_rules
    let full = gbool(rules, "full_tech_tree", false)
    let bdata = load_json(lib_root + "/buildings.json")
    let tdata = load_json(lib_root + "/tech.json")
    let ages_d = glist(tdata, "ages")
    let age_names = map(ages_d) a: gstr(a, "name", "")
    let last_age = gint(ages_d[ages_d.length - 1], "age", 1)
    def age_planned(age:int) -> bool:
        for(ages_d) a:
            if gint(a, "age", 0) == age: return gstr(a, "status", "built") == "planned"
        return true
    let blds = at(bdata, "buildings")
    var ids = filter(gstrs(bdata, "tree")) id: has(blds, id)
    let rest = filter(sorted_strs(blds.keys)) id: not has_s(ids, id)
    insertion_sort(rest) a, b: gint(at(blds, a), "age", 1) < gint(at(blds, b), "age", 1) or (gint(at(blds, a), "age", 1) == gint(at(blds, b), "age", 1) and a < b)
    ids = append(ids, rest)
    // Research a creature or culture names as its own (Identity.owners).
    let owners = dictionary<string, [string]>(64)
    for([lib_creatures, lib_families]) src:
        for(sorted_strs(src.keys)) id:
            for(gstrs(at(src, id), "research")) r:
                let o = owners.get(r) or []::string
                o.push(id)
                owners.set(r, o)
    let nodes = []::TNode
    let keys = []::string
    let joins = []::int2
    let columns = []::TColumn
    for(ids) id:
        let b = at(blds, id)
        let col = columns.length
        let bn = TNode { "b:" + id, "building", gstr(b, "name", id), gstr(b, "desc", ""), gint(b, "age", 1), gstr(b, "status", "built") == "planned", col }
        bn.lacks = race_lacks(ident, id)
        bn.cost = cost_text(gobj(b, "cost"))
        nodes.push(bn)
        keys.push(bn.key)
        let lanes_g = []::[TNode]
        for(glist(rules, "roster")) sd:
            let slot = gstr(sd, "slot", "")
            if gstr(sd, "building", "") == id and gstr(sd, "status", "") != "parked" and gstr(sd, "role", "") != "hero":
                let first_age = max(gint(sd, "tier", 1), gint(b, "age", 1))
                let line_planned = gstr(sd, "status", "") == "planned"
                let line_name = gstr(sd, "name", slot)
                if not line_planned and (has_str(glist(race, "lacks"), slot) or race_lacks(ident, slot)):
                    let n = TNode { "u:{slot}@{first_age}", "unit", line_name, gstr(sd, "desc", ""), first_age, false, col }
                    n.lacks = true
                    lanes_g.push([n])
                else:
                    let unit = race_unit(race, slot)
                    let group = []::TNode
                    var prev = ""
                    var age = first_age
                    while age <= gint(sd, "last_age", last_age):
                        let st = line_step(unit, age)
                        let planned = line_planned or not st or age_planned(age)
                        let rk = if st: stringify(at(st, "recipe")) else: ""
                        if planned or rk != prev:
                            if not planned: prev = rk
                            var name = line_name
                            var desc = gstr(sd, "desc", "")
                            if st:
                                name = gstr(at(st, "recipe"), "name", name)
                                let un = gstr(at(st, "recipe"), "unique", "")
                                if un != "": desc = gstr(at(lib_uniques, un), "desc", desc)
                            let n = TNode { "u:{slot}@{age}", "unit", name, desc, age, planned, col }
                            if st and not planned: n.cost = cost_text(gobj(at(st, "eval"), "cost"))
                            n.lacks = age > first_age and race_lacks(ident, "line.{slot}.{age}")
                            group.push(n)
                        age++
                    if group.length: lanes_g.push(group)
        let here = filter(glist(tdata, "research")) r: gstr(r, "building", "") == id and (not has(r, "own") or full or has_str(glist(ident, "research"), gstr(r, "id", "")))
        let here_ids = map(here) r: gstr(r, "id", "")
        let done = []::string
        for(here) r:
            let rid = gstr(r, "id", "")
            if not has_s(done, rid) and not has_s(here_ids, gstr(r, "after", "")):
                let group = []::TNode
                var cur:JV? = r
                while cur:
                    let c = cur
                    if c:
                        let cid = gstr(c, "id", "")
                        done.push(cid)
                        let only = if has(c, "only"): gstrs(c, "only") else: owners.get(cid) or []::string
                        var lacks = only.length > 0 and not full and not (has_s(only, rstr(race, "creature")) or has_s(only, rstr(race, "family")))
                        lacks = lacks or race_lacks(ident, cid)
                        let n = TNode { "r:" + cid, "research", gstr(c, "name", cid), gstr(c, "desc", ""), gint(c, "age", 1), gstr(c, "status", "built") == "planned", col }
                        n.lacks = lacks
                        n.race_only = only.length > 0 and not lacks
                        n.cost = cost_text(gobj(c, "cost"))
                        group.push(n)
                        var nxt:JV? = nil
                        for(here) r2:
                            if gstr(r2, "after", "") == cid: nxt = r2
                        cur = nxt
                lanes_g.push(group)
        // Pack: each group in the first lane free at all its ages (lines and tracks first, then singles).
        let ordered = append(filter(lanes_g) g: g.length > 1 or g[0].kind == "unit", filter(lanes_g) g: not (g.length > 1 or g[0].kind == "unit"))
        let used = []::[int]
        for(ordered) g:
            var lane = 0
            while lane < used.length and (filter(g) n: has_int(used[lane], n.age)).length > 0: lane++
            if lane == used.length: used.push([])
            for(g) n, k:
                used[lane].push(n.age)
                n.lane = lane
                if k > 0: joins.push(int2 { nodes.length - 1, nodes.length })
                nodes.push(n)
                keys.push(n.key)
        columns.push(TColumn { gstr(b, "name", id), max(1, used.length) })
    var x = 0.0
    for(columns) c:
        c.x = x
        x += float(c.lanes)
    return TTree { age_names, columns, nodes, joins }

def has_int(xs:[int], v:int) -> bool:
    for(xs) x:
        if x == v: return true
    return false

// The race in words (TechTreeModel.identity_text): its bonuses and where each comes from, its own
// research, what it lacks.
class RaceWords:
    bonuses:[string]
    own:[string]
    lacks:[string]

def slot_word(slot:string) -> string:
    for(glist(su_rules, "roster")) sd:
        if gstr(sd, "slot", "") == slot: return gstr(sd, "name", slot)
    return slot

def race_words(p:int) -> RaceWords:
    let ident = su_idents[p]
    let race = su_races[p]
    let tdata = load_json(lib_root + "/tech.json")
    let blds = at(load_json(lib_root + "/buildings.json"), "buildings")
    def research_of(id:string) -> JV?:
        for(glist(tdata, "research")) r:
            if gstr(r, "id", "") == id: return r
        return nil
    let bonuses = map(glist(ident, "bonuses")) b: "{gstr(b, "text", "")} ({gstr(b, "from", "")})"
    let own = []::string
    for(gstrs(ident, "research")) id:
        let r = research_of(id)
        if r: own.push("{gstr(r, "name", id)}: {gstr(r, "desc", "")}")
    let lacks = []::string
    if not gbool(su_rules, "full_tech_tree", false):
        for(gstrs(ident, "lacks")) id:
            let r = research_of(id)
            if r: lacks.push(gstr(r, "name", id))
            elif has(blds, id): lacks.push(gstr(at(blds, id), "name", id) + (if glist(at(blds, id), "trains").length: " (and what it trains)" else: ""))
            elif id == "trade": lacks.push("Market trade (buying and selling)")
            elif starts_with(id, "line."):
                let parts = tokenize(id, ".", "")
                lacks.push("{slot_word(parts[1])}\'s age-{parts[2]} step")
            else: lacks.push(slot_word(id) + " line")
    for(gstrs(race, "lacks")) slot:
        let w = slot_word(slot) + " line"
        if not has_s(lacks, w): lacks.push(w)
    return RaceWords { bonuses, own, lacks }

var tree_words:RaceWords? = nil

var tree_open = false
var tree_page:TTree? = nil
var tree_scroll = 0.0

let TREE_LANE = 150.0           // ui px a lane
let TREE_ROW = 120.0            // ui px an age
let TREE_TOP = 120.0

// A filled box and a line on the page; the text waits in page_texts and goes on top at the end.
class PageText:
    at:float2
    s:string
    size:int
    col:float4

var page_texts = []::PageText

def page_text(at:float2, s:string, size:int, col:float4): page_texts.push(PageText { at, s, size, col })

def page_flush():
    for(page_texts) t:
        gl.set_font_size(t.size)
        lobby_text(t.at, t.s, t.col)
    page_texts = []

// (gl.rect draws -size..size round the point in this build, so it's given the centre and half the size)
def page_rect(at:float2, size:float2, col:float4):
    gl.set_shader("color")
    ui_fill(at, size, col)

def page_line(a:float2, b:float2, w:float, col:float4):
    gl.set_shader("color")
    ui_line(a, b, w, col)

def tree_node_at(t:TTree, n:TNode, u:float) -> float2:
    let c = t.columns[n.col]
    let x = 180.0 * u + (c.x + float(max(0, n.lane))) * TREE_LANE * u - tree_scroll
    let y = TREE_TOP * u + float(n.age - 1) * TREE_ROW * u + (if n.kind == "building": 0.0 else: 42.0 * u)
    return float2 { x, y }

// The page over everything; true while it's up.
def tree_tick() -> bool:
    if gl.button("f1") == 1:
        tree_open = not tree_open
        if tree_open:
            tree_page = build_tree(ME)
            tree_words = race_words(ME)
    if tree_open and gl.button("escape") == 1: tree_open = false
    if not tree_open: return false
    let t = tree_page
    if not t: return false
    let u = ui()
    let ws = float(gl.window_size())
    let width = (t.columns[t.columns.length - 1].x + float(t.columns[t.columns.length - 1].lanes)) * TREE_LANE * u + 220.0 * u
    if gl.button("right") >= 1: tree_scroll += 900.0 * gl.delta_time() * u
    if gl.button("left") >= 1: tree_scroll -= 900.0 * gl.delta_time() * u
    tree_scroll -= float(gl.mousewheel_delta()) * 120.0 * u
    tree_scroll = clamp(tree_scroll, 0.0, max(0.0, width - ws.x))
    gl.set_shader("color")
    ui_mat(float2_0, ws, ui_look.face * float4 { 0.5, 0.5, 0.5, 1.0 }, 0)
    page_text(float2 { 30.0 * u, 24.0 * u }, "Tech tree: " + rstr(su_races[ME], "name"), int(26.0 * u), ui_look.title)
    page_text(float2 { 30.0 * u, 64.0 * u }, "Crossed out: your race lacks it.  Gold: research only some races get.  F1 or Esc: close.  Arrows or the wheel: scroll.", int(14.0 * u), float4 { 0.75, 0.72, 0.64, 1.0 })
    for(t.ages) name, a:   // the ages, as bands
        let y = TREE_TOP * u + float(a) * TREE_ROW * u
        page_rect(float2 { 0.0, y - 10.0 * u }, float2 { ws.x, TREE_ROW * u }, if a % 2 == 0: float4 { 0.11, 0.09, 0.07, 1.0 } else: float4 { 0.09, 0.08, 0.06, 1.0 })
        page_text(float2 { 20.0 * u, y + 30.0 * u }, name, int(14.0 * u), float4 { 0.85, 0.75, 0.5, 1.0 })
    for(t.joins) j:
        let a = tree_node_at(t, t.nodes[j.x], u) + float2 { 60.0 * u, 30.0 * u }
        let b = tree_node_at(t, t.nodes[j.y], u) + float2 { 60.0 * u, 0.0 }
        page_rect(float2 { a.x - 1.5 * u, a.y }, float2 { 3.0 * u, max(0.0, b.y - a.y) }, float4 { 0.5, 0.42, 0.28, 1.0 })   // (a line's steps run straight down a lane)
    let m = float(gl.mouse_pos(0))
    var hover = -1
    for(t.nodes) n, k:
        let at = tree_node_at(t, n, u)
        if at.x > -TREE_LANE * u and at.x < ws.x:
            let size = float2 { 140.0 * u, 40.0 * u }
            let fill = if n.kind == "building": ui_look.button elif n.kind == "unit": float4 { 0.24, 0.3, 0.4, 1.0 } else: float4 { 0.28, 0.34, 0.2, 1.0 }
            if n.planned: ui_box(at, size, -1, fill, false)   // (planned: an empty frame)
            else: ui_box(at, size, 1, fill, false)
            if n.race_only: page_rect(at, float2 { 4.0 * u, size.y }, float4 { 0.95, 0.78, 0.3, 1.0 })
            let col = if n.planned: float4 { 0.45, 0.43, 0.4, 1.0 } elif n.lacks: float4 { 0.55, 0.5, 0.45, 1.0 } else: float4 { 0.92, 0.88, 0.78, 1.0 }
            page_text(at + float2 { 11.0 * u, 10.0 * u }, if n.name.length > 17: n.name.substring(0, 16) + "." else: n.name, int(14.0 * u), col)
            if n.lacks: page_rect(at + float2 { 0.0, size.y * 0.5 - 1.5 * u }, float2 { size.x, 3.0 * u }, float4 { 0.8, 0.25, 0.2, 0.9 })   // struck through
            if m.x >= at.x and m.y >= at.y and m.x <= at.x + size.x and m.y <= at.y + size.y: hover = k
    let words = tree_words or race_words(ME)
    tree_words = words
    let py = TREE_TOP * u + float(t.ages.length) * TREE_ROW * u + 20.0 * u
    ui_box(float2 { 20.0 * u, py }, float2 { ws.x - 40.0 * u, ws.y - py - 110.0 * u }, -1, ui_look.face, false)
    let col_w = (ws.x - 80.0 * u) / 3.0
    def column(k:int, title:string, items:[string]):
        let x = 44.0 * u + float(k) * col_w
        page_text(float2 { x, py + 16.0 * u }, title, int(18.0 * u), ui_look.title)
        var line_y = py + 46.0 * u
        for(items) w:
            page_text(float2 { x, line_y }, if w.length > 70: w.substring(0, 68) + "..." else: w, int(13.0 * u), ui_look.text)
            line_y += 20.0 * u
        if not items.length: page_text(float2 { x, line_y }, "nothing", int(13.0 * u), ui_look.dim)
    column(0, "Bonuses", words.bonuses)
    column(1, "Its own research", words.own)
    column(2, "It lacks", words.lacks)
    if hover >= 0:   // what it is, at the foot of the page
        let n = t.nodes[hover]
        page_rect(float2 { 0.0, ws.y - 90.0 * u }, float2 { ws.x, 90.0 * u }, float4 { 0.0, 0.0, 0.0, 0.85 })
        page_text(float2 { 30.0 * u, ws.y - 80.0 * u }, n.name + (if n.cost != "": "   (" + n.cost + ")" else: "") + (if n.lacks: "   - your race lacks it" else: ""), int(18.0 * u), ui_look.title)
        page_text(float2 { 30.0 * u, ws.y - 48.0 * u }, n.desc, int(14.0 * u), float4 { 0.8, 0.78, 0.7, 1.0 })
    page_flush()
    return true
