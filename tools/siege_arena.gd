extends SceneTree

const SiegeView = preload("res://src/siege_view.gd")
const SiegeState = preload("res://src/siege_state.gd")
const PITCH := deg_to_rad(60.0)
const FOV := 40.0
const CAMS := {"top": [Vector3.ZERO, 205.0], "game": [Vector3(0, 0, -34), 48.0], "core": [Vector3(0, 3.5, 0), 16.0], "gate": [Vector3(0, 1, -16.75), 18.0], "lane": [Vector3(0, 0, -52), 34.0]}

var view
var siege: Dictionary
var out := ""
var wait := 90
var cam := Camera3D.new()


func _initialize() -> void:
	var o := {"rings": "4", "cam": "top", "gate": "", "hp": "", "warn": "", "repair": "", "modules": "", "q": "0", "cleared": "", "crate": "", "garrison": "", "rebuild": "", "shop": "", "recall": ""}
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
	if o.cleared:
		var y: Dictionary = siege.yards[o.cleared.to_int()]
		for c in y.camps:
			c.alive = false
		for c in y.crates:
			c.taken = true
	if o.crate:
		siege.yards[0].crates[0].progress = o.crate.to_float()
	if o.garrison:
		siege.garrison.tier = o.garrison.to_int()
	if o.rebuild:
		siege.garrison.respawn_in = 300
	if o.shop:
		siege.shop_open = [true]
	if o.recall:
		siege.recall = [{"player": 0, "t": roundi(o.recall.to_float() * 240), "max": 240, "x": 0.0, "y": -30.0}]
	var q: int = o.q.to_int()
	var bay: Dictionary = SiegeView.contract("BAY", SiegeView.BAY_AT)
	var yc := SiegeState.yard_at(q, 40.0, 40.0)
	var cr: Dictionary = siege.yards[0].crates[0]
	var cams := CAMS.merged({"yard": [Vector3(yc.x, 0, yc.y), 48.0], "yardclose": [Vector3(yc.x, 0, yc.y), 30.0],
		"crate": [Vector3(cr.x, 0.5, cr.y), 10.0], "dock": [Vector3(SiegeState.GARRISON_DOCK.x, 2, SiegeState.GARRISON_DOCK.y), 14.0],
		"edge": [Vector3(0, 0, 70), 48.0], "bay": [Vector3(bay.x, 2, bay.y), 13.0], "recall": [Vector3(0, 2, -30), 16.0], "elite": [Vector3(SiegeState.yard_at(q, 62.0, 62.0).x, 1, SiegeState.yard_at(q, 62.0, 62.0).y), 24.0]})
	view = SiegeView.new()
	root.add_child(view)
	view.build()
	if o.has("cheer"):
		view.crowd_mat.set_shader_parameter("cheer", PackedFloat32Array([1, 1, 1, 1]))
	var c: Array = cams[o.cam]
	cam.fov = FOV
	cam.position = c[0] + Vector3(0, 0, c[1] * 0.09) + Vector3(0, sin(PITCH), cos(PITCH)) * c[1]
	cam.rotation = Vector3(-PITCH, 0, 0)
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
