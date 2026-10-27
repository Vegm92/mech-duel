extends TextureRect

const Mech = preload("res://src/mech.gd")
const Look = preload("res://src/look.gd")

const YAW := 0.6
const PITCH := 0.32
const FOV := 30.0
const FILL := 1.0
const TURN := 0.9
const FRAME := AABB(Vector3(-1.0, -0.1, -1.0), Vector3(2.0, 2.6, 2.0))

static var _env: Environment

var port := SubViewport.new()
var stand := Node3D.new()
var cam := Camera3D.new()
var turning := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	port.own_world_3d = true
	port.transparent_bg = true
	port.msaa_3d = Viewport.MSAA_4X
	add_child(port)
	cam.fov = FOV
	cam.environment = env()
	port.add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.light_energy = Look.STAGE.garage_key
	sun.light_color = Look.STAGE.key_color
	sun.transform = Transform3D(Basis.looking_at(Vector3(0.5, -1.2, -1.0)), Vector3.ZERO)
	cam.add_child(sun)
	port.add_child(stand)
	texture = port.get_texture()


static func env() -> Environment:
	if _env == null:
		_env = Look.env(true)
	return _env


func show_part(slot: String, key: String, t := 0) -> void:
	var m := Mech.new()
	m.build_part(slot, key, t)
	put(m, YAW + PI if slot == "booster" else YAW)


func show_mech(lo: Dictionary, t := 0) -> void:
	var m := Mech.new()
	m.build(lo, t)
	Mech.add(m, Mech.cyl(1.05, 1.1, 0.08), Look.ARENA.dark, Vector3(0, -0.04, 0))
	Mech.add(m, Mech.ring(1.08, 1.16), Look.ARENA.pad, Vector3(0, 0.005, 0))
	put(m, YAW, FRAME)


func put(m: Node3D, yaw: float, frame = null) -> void:
	for c in stand.get_children():
		c.free()
	var box: AABB = frame if frame != null else bounds(m)
	m.position = -box.get_center()
	stand.add_child(m)
	var dir := Vector3(cos(yaw) * cos(PITCH), sin(PITCH), sin(yaw) * cos(PITCH))
	var dist := box.size.length() / 2.0 / sin(deg_to_rad(FOV) / 2.0) * FILL
	cam.transform = Transform3D(Basis.looking_at(-dir), dir * dist)
	redraw()


func turn(on: bool) -> void:
	turning = on
	if not on:
		stand.rotation.y = 0.0
	redraw()


func redraw() -> void:
	port.render_target_update_mode = SubViewport.UPDATE_ALWAYS if turning else SubViewport.UPDATE_ONCE


func _process(dt: float) -> void:
	var px := Vector2i((size * get_viewport().get_final_transform().get_scale()).round()).max(Vector2i.ONE)
	if port.size != px:
		port.size = px
		redraw()
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
