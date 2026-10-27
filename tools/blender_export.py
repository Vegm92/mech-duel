import os
import sys

import bpy

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
stem = os.path.splitext(os.path.basename(bpy.data.filepath))[0]
out = args[args.index("--out") + 1] if "--out" in args else bpy.path.abspath(f"//../godot/assets/models/{stem}.glb")

if "--build" in args:
    text = bpy.data.texts[f"{stem}_build.py"]
    exec(compile(text.as_string(), text.name, "exec"), {"__name__": "__main__"})
if "--save" in args:
    bpy.ops.wm.save_mainfile()

name = stem.capitalize()
view = bpy.context.view_layer
layer = view.layer_collection.children[name]
layer.collection.hide_viewport = False
view.update()
view.active_layer_collection = layer
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_active_collection=True)
print(f"exported {name} -> {out}")
