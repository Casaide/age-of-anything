# The scifi_test mod's one Blender-modelled part (milestone 21: a mod's .glb path): the arc buckler, a
# small hexagonal arm shield with a team face and a ring of light. Run from the project root:
#   blender -b --python mods/scifi_test/tools/buckler.py -- mods/scifi_test/models/buckler.glb
# Modelled in the game's part units, facing +X, up +Z (glTF turns it into the game's +X forward, +Y
# up); built round the off hand, its face turned out and towards the viewer like the game's shields.
# Materials are named for what the game puts there (src/mods.gd, UnitModels.mod_materials): "iron"
# (a game texture), "team" (the team colour), "glow_7fe6ff" (lit, unshaded).
import sys
import bpy
from mathutils import Vector

out = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    return m


def hexagon(radius, depth, material, z):
    bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=radius, depth=depth, location=(0, 0, z))
    o = bpy.context.object
    o.data.materials.append(material)
    return o


iron, team, light = mat("iron"), mat("team"), mat("glow_7fe6ff")
parts = [hexagon(4.2, 0.8, iron, 0.0), hexagon(3.0, 0.4, team, 0.5)]
bpy.ops.mesh.primitive_torus_add(major_radius=1.1, minor_radius=0.35, location=(0, 0, 0.8))
ring = bpy.context.object
ring.data.materials.append(light)
parts.append(ring)
for o in parts:
    o.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
shield = bpy.context.object
# Face it like the game's shields: SHIELD_FACE (1, 0.1, 0.45) in game axes is (1, -0.45, 0.1) here,
# centred at the game's (3, 0.5, 1.5), here (3, -1.5, 0.5).
face = Vector((1.0, -0.45, 0.1)).normalized()
shield.rotation_mode = "QUATERNION"
shield.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(face)
shield.location = (3.0, -1.5, 0.5)
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=False)
print("wrote", out)
