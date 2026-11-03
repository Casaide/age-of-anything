// Voxel buildings, an experiment (Dominic, 2026-11-03: "test a few buildings, see how close we can make them using
// voxels"; then "textures and lights real issue"). Writes data/voxel/buildings/: materials (colours, and surface
// patterns: stone blocks, planks, corrugated sheet with rust, roof tiles, worn plaster, mottle; lights that glow) and
// bodies (the voxel format's points and shapes, a shape a line) for a Roman house and Town Center, the rats' shack and
// silo, two trees and a rock. The game doesn't load the folder; voxel_buildings.lobster draws them. Body units: z up,
// y to the front, x across; a tile is about 62. Each is drawn facing as the game's baked one is (its front to the
// lower left).
//   lobster voxel_buildings_gen.lobster
import std
import vec
import dictionary
import gen.json
import gen.vx_write

let OUT = "../data/voxel/buildings"

// ---- materials: a colour, and a pattern (its kind, size in body units, depth, how much of the second colour)

mat("plaster", "#e6dfd0", false, pat("wear", float2_1, 0.16, 0.55, "#8f7f63"))
mat("plaster_lit", "#f2ece0", false, pat("wear", float2_1, 0.12, 0.4, "#8f7f63"))
mat("stone", "#b3ab9b", false, pat("blocks", float2 { 6.5, 3.2 }, 0.12, 1.0, "#78705f"))
mat("paving", "#a9a395", false, pat("blocks", float2 { 7.5, 7.5 }, 0.1, 1.0, "#6f6a5e"))
mat("stone_dark", "#8c8475", false, pat("mottle", float2_1, 0.3, 0.0, "#000000"))
mat("tile", "#b84a2c", true, pat("tiles", float2 { 3.6, 4.6 }, 0.09, 0.25, "#6d6236"))  // (each row a tile at a time, a tone each)
mat("tile_dark", "#5e2216", false, pat("mottle", float2_1, 0.15, 0.0, "#000000"))       // (the channels between the rows, and the ridge)
mat("timber", "#7a5230", false, pat("planks", float2 { 4.5, 1.0 }, 0.14, 1.0, "#2e1e12"))
mat("timber_dark", "#4e321e", false, pat("planks", float2 { 3.0, 1.0 }, 0.12, 1.0, "#22160d"))
mat("crate", "#9a6c3c", false, pat("planks", float2 { 2.2, 1.0 }, 0.14, 1.0, "#3a2614"))
glow("glass", "#ffe9a0")
glow("fire", "#ffb040")
mat("shutter", "#a33f2a", false, pat("planks", float2 { 1.4, 1.0 }, 0.1, 1.0, "#5a2014"))
mat("sheet", "#b9bdc3", false, pat("ripples", float2 { 0.55, 26.0 }, 0.2, 0.6, "#9a5a30"))
let round_sheet = pat("ripples", float2 { 0.55, 40.0 }, 0.2, 0.8, "#9a5a30")
set(round_sheet, "round", jbool(true))
mat("sheet_round", "#b9bdc3", false, round_sheet)
mat("sheet_dark", "#80858d", false, pat("ripples", float2 { 0.55, 26.0 }, 0.2, 0.7, "#7a4424"))
mat("steel", "#a7acb4", false, nil)
mat("pipe", "#2c2a2a", false, nil)
mat("cheese", "#f0c23c", false, pat("mottle", float2_1, 0.12, 0.0, "#000000"))
mat("sack", "#c9b58a", false, pat("mottle", float2_1, 0.2, 0.0, "#000000"))
mat("leaf", "#3f6b29", true, pat("mottle", float2_1, 0.35, 0.0, "#000000"))
mat("leaf_dark", "#2b4c1d", true, pat("mottle", float2_1, 0.35, 0.0, "#000000"))
mat("cypress", "#24401f", true, pat("mottle", float2_1, 0.35, 0.0, "#000000"))
mat("bark", "#5a4030", false, pat("planks", float2 { 1.2, 1.0 }, 0.2, 0.6, "#2e1e12"))
mat("rock", "#c4b69a", false, pat("mottle", float2_1, 0.28, 0.0, "#000000"))
mat("rock_dark", "#8d877a", false, pat("mottle", float2_1, 0.28, 0.0, "#000000"))
mat("pot", "#b0582e", false, pat("mottle", float2_1, 0.15, 0.0, "#000000"))
mat("team", "#cc2921", false, nil)

def roman_house():
    box(float3 { 0.0, 0.0, 2.5 }, float3 { 38.0, 30.0, 2.5 }, FRONT, "stone", 0.5)
    wall(float3 { 0.0, 0.0, 21.0 }, float3 { 33.0, 25.0, 16.0 }, "plaster")
    gable_roof(33.0, 25.0, 37.0, 17.0, 5.0, "tile", "tile_dark", false)
    wall(float3 { -8.0, 25.6, 12.0 }, float3 { 5.0, 0.8, 9.5 }, "timber_dark")
    wall(float3 { -8.0, 26.2, 22.5 }, float3 { 6.5, 0.8, 1.2 }, "stone")
    for([ -8.0, 8.0 ]) y:  // the gable end to the lower right: two shuttered, lit windows
        box(float3 { -33.6, y, 24.0 }, float3 { 0.7, 3.0, 4.5 }, SIDE, "glass", 0.3)
        box(float3 { -33.9, y - 4.6, 24.0 }, float3 { 0.7, 1.5, 4.8 }, SIDE, "shutter", 0.3)
        box(float3 { -33.9, y + 4.6, 24.0 }, float3 { 0.7, 1.5, 4.8 }, SIDE, "shutter", 0.3)
    wall(float3 { 0.0, 25.4, 35.5 }, float3 { 33.0, 0.9, 1.2 }, "team")
    wall(float3 { 20.0, -10.0, 58.0 }, float3 { 2.6, 2.6, 9.0 }, "stone_dark")
    wall(float3 { 20.0, -10.0, 67.5 }, float3 { 3.4, 3.4, 0.8 }, "stone")
    amphora(-20.0, 31.0, 4.0)
    wall(float3 { 14.0, 31.0, 4.5 }, float3 { 3.2, 2.4, 0.5 }, "timber")  // a stool
    for([ -2.6, 2.6 ]) dx: for([ -1.8, 1.8 ]) dy:
        cap(float3 { 14.0 + dx, 31.0 + dy, 0.0 }, float3 { 14.0 + dx, 31.0 + dy, 4.2 }, float2 { 0.4, 0.4 }, "timber_dark", true)
    facet_rock(30.0, 33.0, 2.4, 3, "rock_dark")

def roman_tc():
    box(float3 { 0.0, 0.0, 3.0 }, float3 { 52.0, 62.0, 3.0 }, FRONT, "paving", 0.6)
    for(3) k: wall(float3 { 0.0, 65.0 + float(k) * 3.5, 1.0 + float(k) * 2.0 }, float3 { 30.0, 3.5 - float(k) * 0.5, 1.0 + float(k) * 2.0 }, "stone")
    wall(float3 { 0.0, -8.0, 30.0 }, float3 { 40.0, 42.0, 24.0 }, "plaster")
    gable_roof(46.0, 58.0, 54.0, 20.0, 4.0, "tile", "tile_dark", true)
    for([ -36.0, -12.0, 12.0, 36.0 ]) x:  // the portico's columns
        cap(float3 { x, 50.0, 6.0 }, float3 { x, 50.0, 52.0 }, float2 { 3.2, 2.8 }, "plaster_lit", false)
        wall(float3 { x, 50.0, 7.0 }, float3 { 4.2, 4.2, 1.2 }, "stone")
        wall(float3 { x, 50.0, 52.5 }, float3 { 4.2, 4.2, 1.2 }, "stone")
    wall(float3 { 0.0, 54.0, 55.0 }, float3 { 47.0, 6.0, 2.0 }, "plaster")  // the entablature over the columns
    wall(float3 { 0.0, 54.2, 55.0 }, float3 { 47.0, 0.8, 0.9 }, "team")
    disc(float3 { 0.0, 59.6, 64.0 }, FRONT, 6.2, 0.7, "stone")                        // the crest on the pediment: a rim
    disc(float3 { 0.0, 60.4, 64.0 }, FRONT, 4.8, 0.6, "team")                         // and the team's disc in it
    for([ -46.0, 46.0 ]) x: ball(float3 { x, 60.5, 56.5 }, 2.0, "plaster_lit", true)  // white finials on the gable
    ball(float3 { 0.0, 60.5, 76.0 }, 2.0, "plaster_lit", true)
    wall(float3 { 0.0, 34.4, 20.0 }, float3 { 8.0, 0.8, 14.0 }, "timber_dark")
    for([ -30.0, -6.0, 18.0 ]) y: box(float3 { -40.6, y, 27.0 }, float3 { 0.7, 4.0, 6.0 }, SIDE, "glass", 0.3)  // the long side: lit windows
    box(float3 { -40.4, -8.0, 41.0 }, float3 { 0.9, 42.0, 3.0 }, SIDE, "team", 0.3)                             // the team's band along the wall, under the eaves
    cap(float3 { -46.0, 66.0, 0.0 }, float3 { -46.0, 66.0, 60.0 }, float2 { 0.9, 0.7 }, "timber_dark", true)    // the flag pole
    ball(float3 { -46.0, 66.0, 61.0 }, 1.4, "pot", true)
    for([ 0.0, 120.0, 240.0 ]) a:  // a brazier on the steps, its fire alight
        cap(float3 { 22.0 + 2.4 * cos(a), 70.0 + 2.4 * sin(a), 0.0 }, float3 { 22.0, 70.0, 9.0 }, float2 { 0.4, 0.4 }, "timber_dark", true)
    disc(float3 { 22.0, 70.0, 9.5 }, UP, 3.4, 0.7, "steel")
    ball(float3 { 22.0, 70.0, 11.0 }, 2.4, "fire", true)
    amphora(-30.0, 70.0, 0.0)

def rat_shack():
    box(float3 { 0.0, 0.0, 1.0 }, float3 { 40.0, 30.0, 1.0 }, FRONT, "stone_dark", 0.4)
    wall(float3 { 0.0, 0.0, 19.0 }, float3 { 36.0, 26.0, 17.0 }, "timber")
    let ang = atan2(float2 { 31.0, 15.0 })
    for([ 1.0, -1.0 ]) side:  // the roof: two slopes of corrugated sheet
        box(float3 { 0.0, side * 15.5, 44.0 }, float3 { 41.0, 1.1, sqrt(31.0 * 31.0 + 15.0 * 15.0) / 2.0 }, float3 { 0.0, side * sin(ang), cos(ang) }, "sheet", 0.1)
    cap(float3 { -41.0, 0.0, 52.0 }, float3 { 41.0, 0.0, 52.0 }, float2 { 1.2, 1.2 }, "sheet_dark", true)
    wall(float3 { 0.0, 0.0, 40.0 }, float3 { 36.0, 12.0, 4.0 }, "timber")
    box(float3 { -36.3, 0.0, 44.0 }, float3 { 0.6, 14.0, 4.0 }, SIDE, "timber", 0.3)
    wall(float3 { -10.0, 26.4, 12.0 }, float3 { 5.0, 0.8, 10.0 }, "timber_dark")
    for(3) k: wall(float3 { -10.0, 29.0 + float(k) * 2.2, 0.6 + float(k) * 1.2 }, float3 { 6.0, 1.1, 0.6 + float(k) * 1.2 }, "timber_dark")
    wall(float3 { 14.0, 26.4, 24.0 }, float3 { 4.5, 0.6, 4.5 }, "glass")
    box(float3 { -36.6, -9.0, 24.0 }, float3 { 0.6, 4.5, 4.5 }, SIDE, "glass", 0.3)
    box(float3 { -36.6, 9.0, 24.0 }, float3 { 0.6, 4.5, 4.5 }, SIDE, "glass", 0.3)
    box(float3 { -37.0, 0.0, 15.0 }, float3 { 0.8, 7.0, 15.0 }, SIDE, "sheet_dark", 0.1)  // a patch of sheet on the gable
    cap(float3 { 22.0, -10.0, 40.0 }, float3 { 22.0, -10.0, 64.0 }, float2 { 2.6, 2.6 }, "pipe", true)
    cap(float3 { 22.0, -10.0, 64.0 }, float3 { 27.0, -10.0, 68.0 }, float2 { 2.6, 2.4 }, "pipe", true)
    disc(float3 { 34.0, 30.0, 5.0 }, float3 { 0.3, 1.0, 0.0 }, 5.5, 2.6, "cheese")
    barrel(-26.0, 31.0)
    box(float3 { -32.0, 22.0, 3.2 }, float3 { 3.2, 3.2, 3.2 }, float3 { 0.25, 1.0, 0.0 }, "crate", 0.2)
    firewood(26.0, 31.0)
    facet_rock(-18.0, 34.0, 3.6, 7, "rock")
    facet_rock(4.0, 34.0, 3.0, 11, "rock")
    ball(float3 { -40.0, 10.0, 3.0 }, 3.2, "sack", false)
    wall(float3 { 0.0, 26.2, 36.0 }, float3 { 36.0, 0.8, 1.0 }, "team")

def rat_silo():
    disc(float3 { 0.0, 0.0, 1.0 }, UP, 25.0, 1.0, "stone_dark")
    disc(float3 { 0.0, 0.0, 23.0 }, UP, 22.0, 21.0, "sheet_round")
    for([ 14.0, 32.0 ]) z: disc(float3 { 0.0, 0.0, z }, UP, 22.9, 0.9, "steel")  // two hoops
    disc(float3 { 0.0, 0.0, 44.7 }, UP, 23.2, 0.8, "sheet")                      // the flat lid, a stone on it
    facet_rock(6.0, -4.0, 3.2, 5, "rock")
    cap(float3 { -6.0, -2.0, 45.0 }, float3 { -6.0, -2.0, 54.0 }, float2 { 1.5, 1.5 }, "pipe", true)
    box(float3 { -2.0, 23.0, 14.0 }, float3 { 7.0, 1.4, 11.0 }, float3 { 0.1, 1.0, 0.0 }, "pipe", 0.2)  // the door
    box(float3 { -13.0, 23.8, 15.0 }, float3 { 4.5, 1.2, 12.0 }, float3 { 0.45, 1.0, 0.0 }, "sheet_dark", 0.1)
    box(float3 { 14.0, 18.5, 24.0 }, float3 { 2.4, 0.6, 2.0 }, float3 { 0.6, 0.8, 0.0 }, "team", 0.3)

def cypress():
    cap(float3_0, float3 { 0.0, 0.0, 10.0 }, float2 { 1.6, 1.2 }, "bark", true)
    for(9) k:
        let r = 8.5 * sin(180.0 * float(k + 1) / 10.0) + 1.2
        ball(float3 { 0.3 * float(k % 2), 0.0, 8.0 + float(k) * 6.0 }, r, if k % 3 != 0: "cypress" else: "leaf_dark", false)

def broadleaf():
    cap(float3_0, float3 { 0.0, 0.0, 22.0 }, float2 { 3.0, 2.0 }, "bark", false)
    cap(float3 { 0.0, 0.0, 18.0 }, float3 { 7.0, 3.0, 28.0 }, float2 { 1.4, 1.0 }, "bark", true)
    cap(float3 { 0.0, 0.0, 18.0 }, float3 { -6.0, -4.0, 27.0 }, float2 { 1.4, 1.0 }, "bark", true)
    for([ float4 { 0.0, 0.0, 34.0, 12.0 }, float4 { 9.0, 4.0, 30.0, 9.0 }, float4 { -9.0, -3.0, 30.0, 9.0 }, float4 { 4.0, -9.0, 32.0, 8.0 },
          float4 { -4.0, 9.0, 32.0, 8.0 }, float4 { 2.0, 2.0, 42.0, 8.0 }, float4 { -7.0, 6.0, 38.0, 7.0 }, float4 { 7.0, -6.0, 38.0, 7.0 } ]) b, k:
        ball(xyz(b), b.w, if k % 2 == 0: "leaf" else: "leaf_dark", false)

def rock():
    facet_rock(0.0, 0.0, 7.0, 1, "rock")
    facet_rock(9.0, 4.0, 4.5, 2, "rock")
    facet_rock(-7.0, 5.0, 3.5, 4, "rock")

def write_body(name:string, doc:string, size:float): vxw_body(OUT + "/bodies/" + name + ".json", doc, size, [])

write_file(OUT + "/materials.json", "\{\n \"_doc\": \"The voxel buildings\' materials (an experiment: the game doesn\'t load this folder). pattern: a surface texture in the colour (view/voxel.lobster, vx_patterned): blocks, planks, ripples, tiles, wear, mottle; size in body units; glow: a light.\",\n " + concat_string(mats, ",\n ") + "\n\}\n")
roman_house()
write_body("roman_house", "A Roman house (2 tiles): plaster on a stone plinth, a red tile gable roof, a door, shuttered lit windows, the team\'s band under the eaves, a chimney, an amphora and a stool.", 1.0)
roman_tc()
write_body("roman_tc", "A Roman Town Center (3 tiles): a temple on a paved podium with steps, four columns, a tiled roof along its length, lit windows, the team\'s band and disc, a flag, a brazier, an amphora.", 1.0)
rat_shack()
write_body("rat_shack", "The rats\' Town Center: a timber shack under a roof of corrugated sheet (two slopes, rust), a stove pipe, lit windows, a sheet patch on the gable, steps, a cheese wheel, a barrel, a crate, firewood, rocks and a sack at the door, the team\'s band under the eaves.", 1.0)
rat_silo()
write_body("rat_silo", "The rats\' silo: a round tank of corrugated sheet with two steel hoops, a flat corrugated lid with a stone on it, a vent pipe, a dark door with a sheet panel leant beside it, the team\'s plate.", 1.0)
cypress()
write_body("cypress", "A cypress: a dark green spire of melted balls on a short trunk.", 1.7)
broadleaf()
write_body("broadleaf", "A broadleaf tree: a crown of melted balls on a forked trunk.", 1.6)
rock()
write_body("rock", "Rocks of flat cut faces: boxes at angles, overlapping, mottled.", 2.2)
