extends Node3D

const Sim = preload("res://src/sim.gd")
const Bot = preload("res://src/bot.gd")
const View = preload("res://src/view.gd")
const Hud = preload("res://src/hud.gd")
const I18n = preload("res://src/i18n.gd")

const PITCH := deg_to_rad(60.0)

var state: Dictionary
var brain: Dictionary
var pilot: Dictionary
var view: Node3D
var hud: CanvasLayer
var cam: Camera3D
var focus := Vector3(Sim.CX, 0, Sim.CY)
var dist := 32.0
var aim := Vector3(Sim.CX, 0, Sim.CY)
var paused := false
var autopilot := false
var seed_arg := -1
var shot_path := ""
var shot_at := -1
var shooting := false
var tapped := {}
var shake := 0.0


func _ready() -> void:
	I18n.setup()
	for a in OS.get_cmdline_user_args():
		if a == "--autopilot":
			autopilot = true
		elif a.begins_with("--seed="):
			seed_arg = a.substr(7).to_int()
		elif a.begins_with("--shot="):
			shot_path = a.substr(7)
		elif a.begins_with("--at="):
			shot_at = a.substr(5).to_int()
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	cam = Camera3D.new()
	cam.fov = 40.0
	cam.far = 400.0
	cam.rotation = Vector3(-PITCH, 0, 0)
	add_child(cam)
	view = View.new()
	add_child(view)
	view.build()
	hud = Hud.new()
	add_child(hud)
	new_match()


func new_match() -> void:
	var s := seed_arg if seed_arg >= 0 else int(Time.get_unix_time_from_system() * 1000.0) & 0x7fffffff
	var rival := Bot.random_loadout(Bot.create_brain(s))
	state = Sim.create_state([Sim.DEFAULT_LOADOUT, rival])
	brain = Bot.create_brain(s + 1)
	pilot = Bot.create_brain(s + 2)
	view.reset(state)
	hud.state = state
	var me = state.mechs[0]
	var foe = state.mechs[1]
	focus = Vector3((me.x + foe.x) / 2.0, 0, (me.y + foe.y) / 2.0)
	place_camera()
	cam.reset_physics_interpolation()


func key(k: Key) -> bool:
	return Input.is_physical_key_pressed(k)


func player_input() -> Dictionary:
	var inp := {
		"mx": float(int(key(KEY_D)) - int(key(KEY_A))),
		"my": float(int(key(KEY_S)) - int(key(KEY_W))),
		"ax": aim.x,
		"ay": aim.z,
		"left": Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or tapped.has("left"),
		"right": Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or tapped.has("right"),
		"shield": key(KEY_Q) or tapped.has("shield"),
		"hook": key(KEY_E) or tapped.has("hook"),
		"dash": key(KEY_SPACE) or tapped.has("dash"),
		"ult": key(KEY_R) or tapped.has("ult"),
	}
	tapped.clear()
	return inp


func aim_point() -> Vector3:
	var mp := get_viewport().get_mouse_position()
	var o := cam.project_ray_origin(mp)
	var d := cam.project_ray_normal(mp)
	if absf(d.y) < 0.001:
		return aim
	var t := -o.y / d.y
	return o + d * t if t > 0 else aim


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_Q:
				tapped.shield = true
			KEY_E:
				tapped.hook = true
			KEY_SPACE:
				tapped.dash = true
			KEY_R:
				tapped.ult = true
			KEY_ESCAPE:
				paused = not paused
			KEY_ENTER, KEY_KP_ENTER:
				if state.phase == "over":
					new_match()
			KEY_L:
				I18n.toggle()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			tapped.left = true
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			tapped.right = true


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not autopilot and shot_path == "" and state.get("phase", "") == "fight":
		paused = true


func _physics_process(delta: float) -> void:
	aim = aim_point()
	if not paused:
		var me = Bot.bot_input(state, pilot, 0) if autopilot else player_input()
		Sim.step(state, [me, Bot.bot_input(state, brain, 1)])
	view.sync(state, aim, delta)
	shake = maxf(shake, view.shake)
	view.shake = 0.0
	follow(delta)
	hud.paused = paused
	if shot_at >= 0 and state.tick >= shot_at and not shooting:
		shooting = true
		take_shot()


func follow(delta: float) -> void:
	var me = state.mechs[0]
	var foe = state.mechs[1]
	var a := Vector3(me.x, 0, me.y)
	var b := Vector3(foe.x, 0, foe.y)
	var target := (a + b) / 2.0
	var want := clampf(maxf(absf(a.x - b.x) * 0.9 + 8.0, absf(a.z - b.z) * 2.0 + 12.0), 28.0, 64.0)
	var dead := 1.5
	var ease := 3.5
	if state.phase == "ko" and state.finalKo >= 0:
		var k = state.mechs[state.finalKo]
		target = Vector3(k.x, 0, k.y)
		want = 15.0
		dead = 0.0
		ease = 3.0
	target.z += dist * 0.09
	var off := target - focus
	if off.length() > dead:
		focus += off.normalized() * (off.length() - dead) * (1.0 - exp(-delta * ease))
	dist = lerpf(dist, want, 1.0 - exp(-delta * 2.5))
	place_camera()


func place_camera() -> void:
	cam.position = focus + Vector3(0, sin(PITCH), cos(PITCH)) * dist


func _process(delta: float) -> void:
	shake = maxf(0.0, shake - delta * 2.5)
	var s := shake * shake
	cam.h_offset = randf_range(-1.0, 1.0) * s * 0.6
	cam.v_offset = randf_range(-1.0, 1.0) * s * 0.6


func take_shot() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(shot_path)
	get_tree().quit()
