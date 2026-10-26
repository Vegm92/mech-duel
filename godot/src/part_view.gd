extends SubViewportContainer

const Mech = preload("res://src/mech.gd")

const YAW := 0.6
const PITCH := 0.32
const FOV := 30.0
const FILL := 1.0
const TURN := 0.9

static var _env: Environment

var port := SubViewport.new()
var stand := Node3D.new()
var cam := Camera3D.new()
var turning := false


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	port.own_world_3d = true
	port.transparent_bg = true
	port.msaa_3d = Viewport.MSAA_4X
	add_child(port)
	cam.fov = FOV
	cam.environment = env()
	port.add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 2.2
	sun.light_color = Color(1.0, 0.95, 0.88)
	sun.transform = Transform3D(Basis.looking_at(Vector3(0.5, -1.2, -1.0)), Vector3.ZERO)
	cam.add_child(sun)
	port.add_child(stand)


static func env() -> Environment:
	if _env == null:
		_env = Environment.new()
		_env.background_mode = Environment.BG_CLEAR_COLOR
		_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		_env.ambient_light_color = Color(0.45, 0.5, 0.7)
		_env.tonemap_mode = Environment.TONE_MAPPER_AGX
		_env.glow_enabled = true
		_env.glow_intensity = 0.5
		_env.glow_hdr_threshold = 2.2
	return _env


func show_part(slot: String, key: String, t := 0) -> void:
	var m := Mech.new()
	m.build_part(slot, key, t)
	put(m, YAW + PI if slot == "booster" else YAW)


func show_mech(lo: Dictionary, t := 0) -> void:
	var m := Mech.new()
	m.build(lo, t)
	put(m, YAW)


func put(m: Node3D, yaw: float) -> void:
	for c in stand.get_children():
		c.free()
	var box: AABB = bounds(m)
	m.position = -box.get_center()
	stand.add_child(m)
	var dir := Vector3(cos(yaw) * cos(PITCH), sin(PITCH), sin(yaw) * cos(PITCH))
	var dist := box.size.length() / 2.0 / sin(deg_to_rad(FOV) / 2.0) * FILL
	cam.transform = Transform3D(Basis.looking_at(-dir), dir * dist)
	redraw()


func turn(on: bool) -> void:
	turning = on
	redraw()


func redraw() -> void:
	port.render_target_update_mode = SubViewport.UPDATE_ALWAYS if turning else SubViewport.UPDATE_ONCE


func _process(dt: float) -> void:
	if turning:
		stand.rotation.y += dt * TURN


static func bounds(n: Node, x := Transform3D.IDENTITY, box = null):
	for c in n.get_children():
		if not c is Node3D or not c.visible:
			continue
		var cx: Transform3D = x * c.transform
		if c is MeshInstance3D:
			var b: AABB = cx * c.get_aabb()
			box = b if box == null else box.merge(b)
		box = bounds(c, cx, box)
	return box
