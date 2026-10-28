extends SceneTree

const SiegeView = preload("res://src/siege_view.gd")
const SiegeState = preload("res://src/siege_state.gd")
const Main = preload("res://src/main.gd")
const CAMS := {"top": [Vector3.ZERO, 205.0], "game": [Vector3(0, 0, -34), 48.0], "core": [Vector3(0, 3.5, 0), 16.0], "gate": [Vector3(0, 1, -16.75), 18.0], "lane": [Vector3(0, 0, -52), 34.0]}

var view
var siege: Dictionary
var out := ""
var wait := 90
var cam := Camera3D.new()


func _initialize() -> void:
	var o := {"rings": "4", "cam": "top", "gate": "", "hp": "", "warn": "", "repair": "", "modules": ""}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		o[kv[0]] = kv[1] if kv.size() > 1 else "1"
	out = o.get("shot", "")
	siege = SiegeState.stub(o.rings.to_int())
	siege.wave.next_in = 300 if o.warn else 0
	siege.wave.lanes_open = [o.warn != "", false, false, false]
	if o.hp:
		siege.core.hp = siege.core.max * o.hp.to_float()
	siege.core.repairing = o.repair != ""
	if o.modules:
		for k in 3:
			siege.pads[k].module = ["wall", "mine", "laser"][k]
	var g: Dictionary = siege.gates[0]
	if o.gate == "broken":
		g.hp = 0.0
	elif o.gate == "hurt":
		g.hp = g.max * 0.4
	elif o.gate == "open":
		g.open = true
	view = SiegeView.new()
	root.add_child(view)
	view.build()
	if o.has("cheer"):
		view.crowd_mat.set_shader_parameter("cheer", PackedFloat32Array([1, 1, 1, 1]))
	var c: Array = CAMS[o.cam]
	cam.fov = Main.FOV
	cam.position = c[0] + Vector3(0, 0, c[1] * 0.09) + Vector3(0, sin(Main.PITCH), cos(Main.PITCH)) * c[1]
	cam.rotation = Vector3(-Main.PITCH, 0, 0)
	root.add_child(cam)
	cam.make_current()
	if out:
		RenderingServer.frame_post_draw.connect(drawn)


func _process(_dt: float) -> bool:
	siege.tick += 1
	view.update(siege)
	return false


func drawn() -> void:
	wait -= 1
	if wait == 0:
		root.get_texture().get_image().save_png(out)
		quit()
