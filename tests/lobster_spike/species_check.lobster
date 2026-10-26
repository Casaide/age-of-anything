// game/pack_data.lobster's tree species against map_species.gd's (maps/<id>.txt, from Godot's LandView): every
// map, every cell.
//   lobster species_check.lobster

import std
import vec
import dictionary
import color
import gl
import texture
import .gen.json
import .gen.sha256
import .gen.rng
import .gen.datalib
import .gen.identity
import .gen.pricing
import .gen.heroes
import .gen.generator
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
import .lib.abilities
import .lib.trails
import .lib.commands
import .lib.ai_cfg
import .lib.scout
import .lib.land
import .lib.expand
import .lib.bot
import .lib.walls_ai
import .lib.world
import .gen.setup
import .gen.reset
import .view.node
import .model.kit
import .model.grng
import .model.base
import .model.props
import .game.audio
import .game.pack
import .game.pack_data

lib_load("../../data")
var failed = 0
for(["choke_test", "flat_test", "hill_test", "old_forest", "reed_meadow", "reed_meadow_2v2", "river_delta", "river_test", "siege_vale"]) id:
    let text = read_file("maps/" + id + ".txt")
    if not text: continue
    reset_world()
    load_map(id)
    let theirs = filter(tokenize(text, " \n", "")): _.length > 0
    let mine = species_from_map(id)
    var bad = 0
    for(mine) s, c:
        if c >= theirs.length or s != theirs[c]: bad++
    if bad or mine.length != theirs.length: failed++
    print "{if bad or mine.length != theirs.length: "FAIL" else: "PASS"} {id}: {mine.length} cells, {bad} differ"
print "{failed} failed"
