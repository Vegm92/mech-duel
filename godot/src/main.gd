extends Node3D

const Sim = preload("res://src/sim.gd")
const Bot = preload("res://src/bot.gd")
const View = preload("res://src/view.gd")
const Fx = preload("res://src/fx.gd")
const Hud = preload("res://src/hud.gd")
const I18n = preload("res://src/i18n.gd")
const PartView = preload("res://src/part_view.gd")
const Garage = preload("res://src/garage.gd")
const CrowdSound = preload("res://src/crowd_sound.gd")
const Sfx = preload("res://src/sfx.gd")

const PITCH := deg_to_rad(60.0)
const SAVE := "user://loadout.cfg"
const CAMS := [[], [0.6, 0.3, 5.0, true], [PI / 2, 0.12, 5.0, true], [PI + 0.6, 0.4, 5.0, true], [PI / 2, PITCH, 6.0, false]]
const DEAD := 0.2
const REACH := 16.0
const LOOKBACK := 6
const PAD := {"dash": JOY_BUTTON_LEFT_SHOULDER, "shield": JOY_BUTTON_RIGHT_SHOULDER, "hook": JOY_BUTTON_LEFT_STICK, "ult": JOY_BUTTON_RIGHT_STICK}
const TRIGGER := {"left": JOY_AXIS_TRIGGER_LEFT, "right": JOY_AXIS_TRIGGER_RIGHT}
const SANDBOX := {"gap": 0.8, "pad": 0.8, "min": 2.4, "max": 10.0, "refill": 0.5, "cam": 1.1, "guard": 2.5, "dash": 80}

var state: Dictionary
var crowd_sound := CrowdSound.new()
var sfx := Sfx.new()
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
var kick := Vector3.ZERO
var kick_t := 0.0
var stop := 0
var slow := 0.0
var sandbox := false
var gun := -1
var auto_fire := true
var guard := false
var block := false
var auto_hook := false
var refill := true
var auto_dash := false
var auto_ult := false
var frozen := false
var cam_mode := 0
var hands_arg := PackedStringArray()
var head_arg := ""
var core_arg := ""
var arms_arg := ""
var legs_arg := ""
var booster_arg := ""
var set_arg := ""
var parts_arg := ""
var garage_arg := -1
var hover_arg := ""
var loadout: Dictionary
var garage: CanvasLayer
var target := 0
var orbit := Vector2.ZERO
var zoom := 1.0
var pad_id := 0
var on_pad := false
var reach := Vector2.ZERO
var recent: Array[Vector2] = []


func _ready() -> void:
	I18n.setup()
	var accept := InputEventJoypadButton.new()
	accept.device = -1
	accept.button_index = JOY_BUTTON_A
	InputMap.action_add_event("ui_accept", accept)
	for a in OS.get_cmdline_user_args():
		if a == "--autopilot":
			autopilot = true
		elif a.begins_with("--seed="):
			seed_arg = a.substr(7).to_int()
		elif a.begins_with("--shot="):
			shot_path = a.substr(7)
		elif a.begins_with("--at="):
			shot_at = a.substr(5).to_int()
		elif a.begins_with("--cam="):
			cam_mode = a.substr(6).to_int() % CAMS.size()
		elif a.begins_with("--hands="):
			hands_arg = a.substr(8).split(",")
		elif a.begins_with("--head="):
			head_arg = a.substr(7)
		elif a.begins_with("--core="):
			core_arg = a.substr(7)
		elif a.begins_with("--arms="):
			arms_arg = a.substr(7)
		elif a.begins_with("--legs="):
			legs_arg = a.substr(7)
		elif a.begins_with("--booster="):
			booster_arg = a.substr(10)
		elif a.begins_with("--set="):
			set_arg = a.substr(6)
		elif a.begins_with("--parts="):
			parts_arg = a.substr(8)
		elif a == "--garage" or a.begins_with("--garage="):
			garage_arg = a.substr(9).to_int() if a.contains("=") else 0
		elif a.begins_with("--hover="):
			hover_arg = a.substr(8)
		elif a == "--guard":
			guard = true
		elif a == "--block":
			block = true
		elif a == "--hook":
			auto_hook = true
		elif a == "--norefill":
			refill = false
		elif a == "--dash":
			auto_dash = true
		elif a == "--ult":
			auto_ult = true
		elif a == "--sandbox" or a.begins_with("--sandbox="):
			sandbox = true
			gun = Sim.WEAPONS.keys().find(a.substr(10)) if a.contains("=") else -1
	if parts_arg != "":
		part_sheet(parts_arg)
		return
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	cam = Camera3D.new()
	cam.fov = 40.0
	cam.far = 400.0
	cam.rotation = Vector3(-PITCH, 0, 0)
	add_child(cam)
	view = View.new()
	add_child(view)
	add_child(crowd_sound)
	add_child(sfx)
	view.build()
	hud = Hud.new()
	add_child(hud)
	loadout = flag_loadout()
	garage = Garage.new()
	add_child(garage)
	garage.fight.connect(start)
	hud.resume.connect(resume)
	hud.restart.connect(new_match)
	hud.quit.connect(to_garage)
	hud.ui.connect(sfx.ui)
	garage.ui.connect(sfx.ui)
	if sandbox and gun < 0:
		gun = maxi(0, Sim.WEAPONS.keys().find(loadout.left))
	if garage_arg >= 0 or not (autopilot or shot_at >= 0 or sandbox):
		to_garage()
	else:
		garage.visible = false
		new_match()


func flag_loadout() -> Dictionary:
	var base := Sim.DEFAULT_LOADOUT if autopilot or sandbox or shot_path != "" else saved_loadout()
	var mine: Dictionary = Sim.SETS.get(set_arg, base).duplicate()
	if hands_arg.size() == 2:
		mine.left = hands_arg[0]
		mine.right = hands_arg[1]
	if head_arg != "":
		mine.head = head_arg
	if core_arg != "":
		mine.core = core_arg
	if arms_arg != "":
		mine.arms = arms_arg
	if legs_arg != "":
		mine.legs = legs_arg
	if booster_arg != "":
		mine.booster = booster_arg
	return mine


func saved_loadout() -> Dictionary:
	var cfg := ConfigFile.new()
	cfg.load(SAVE)
	return Sim.normalize(cfg.get_value("garage", "loadout", {}))


func save_loadout() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("garage", "loadout", loadout)
	cfg.save(SAVE)


func resume() -> void:
	paused = false
	tapped.clear()


func to_garage() -> void:
	paused = false
	crowd_sound.update([], 0.0, false, false)
	sfx.menu()
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	view.visible = false
	hud.visible = false
	get_viewport().disable_3d = true
	garage.open(loadout, garage_arg)
	if hover_arg != "":
		garage.set_hover({"set": hover_arg} if garage.SLOTS[garage.tab] == "set" else {"slot": garage.SLOTS[garage.tab], "key": hover_arg})
	if shot_path != "":
		for i in 8:
			await get_tree().process_frame
		take_shot()


func start(lo: Dictionary) -> void:
	loadout = lo
	if not autopilot and shot_path == "":
		save_loadout()
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	garage.visible = false
	view.visible = true
	get_viewport().disable_3d = false
	new_match()


func new_match() -> void:
	paused = false
	stop = 0
	slow = 0.0
	Engine.time_scale = 1.0
	tapped.clear()
	var s := seed_arg if seed_arg >= 0 else int(Time.get_unix_time_from_system() * 1000.0) & 0x7fffffff
	var rival: Dictionary = Sim.SETS.values()[s % Sim.SETS.size()].duplicate()
	if sandbox:
		loadout.left = Sim.WEAPONS.keys()[gun]
		loadout.right = loadout.left
	state = Sim.create_state([loadout.duplicate(), rival])
	if sandbox:
		pin()
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


func pad(k: String) -> bool:
	if TRIGGER.has(k):
		return Input.get_joy_axis(pad_id, TRIGGER[k]) > 0.5
	return Input.is_joy_button_pressed(pad_id, PAD[k])


func stick(x: JoyAxis, y: JoyAxis) -> Vector2:
	var v := Vector2(Input.get_joy_axis(pad_id, x), Input.get_joy_axis(pad_id, y)).limit_length(1.0)
	return v if v.length() > DEAD else Vector2.ZERO


func player_input() -> Dictionary:
	var move := stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)
	var inp := {
		"mx": float(int(key(KEY_D)) - int(key(KEY_A))) + move.x,
		"my": float(int(key(KEY_S)) - int(key(KEY_W))) + move.y,
		"ax": aim.x,
		"ay": aim.z,
		"left": Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or tapped.has("left") or pad("left"),
		"right": Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or tapped.has("right") or pad("right"),
		"shield": key(KEY_Q) or tapped.has("shield") or pad("shield"),
		"hook": key(KEY_E) or tapped.has("hook") or pad("hook"),
		"dash": key(KEY_SPACE) or tapped.has("dash") or pad("dash"),
		"ult": key(KEY_R) or tapped.has("ult") or pad("ult"),
	}
	tapped.clear()
	return inp


func aim_point() -> Vector3:
	var r := stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y) * REACH
	if r != Vector2.ZERO:
		on_pad = true
		reach = r
		recent.push_back(r)
		if recent.size() > LOOKBACK:
			recent.pop_front()
	elif not recent.is_empty():
		reach = recent[0]
		recent.clear()
	if on_pad:
		var me = state.mechs[0]
		return Vector3(me.x + reach.x, 0, me.y + reach.y)
	var mp := get_viewport().get_mouse_position()
	var o := cam.project_ray_origin(mp)
	var d := cam.project_ray_normal(mp)
	if absf(d.y) < 0.001:
		return aim
	var t := -o.y / d.y
	return o + d * t if t > 0 else aim


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_M, KEY_N]:
		Sfx.toggle("muted" if event.physical_keycode == KEY_M else "music_on")
	if garage.visible:
		return
	if event is InputEventMouseMotion:
		on_pad = false
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		pad_id = event.device
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
					to_garage()
					get_viewport().set_input_as_handled()
			KEY_L:
				I18n.toggle()
			KEY_F:
				frozen = not frozen
				tapped.clear()
			KEY_C:
				cam_mode = (cam_mode + 1) % CAMS.size()
				orbit = Vector2.ZERO
				zoom = 1.0
			KEY_TAB:
				target = (target + 1) % state.mechs.size()
			KEY_LEFT, KEY_RIGHT:
				if sandbox:
					gun = posmod(gun + (1 if event.physical_keycode == KEY_RIGHT else -1), Sim.WEAPONS.size())
					new_match()
			KEY_T:
				auto_fire = not auto_fire
			KEY_G:
				guard = not guard
			KEY_K:
				refill = not refill
			KEY_J:
				auto_dash = not auto_dash
	elif event is InputEventMouseMotion and frozen and cam_mode > 0 and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		orbit += event.relative * 0.01
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			tapped.left = true
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			tapped.right = true
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = maxf(zoom * 0.9, 0.3)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = minf(zoom * 1.1, 3.0)
	elif event is InputEventJoypadButton and event.pressed:
		var k = PAD.find_key(event.button_index)
		if k:
			tapped[k] = true
		elif event.button_index == JOY_BUTTON_START:
			paused = not paused
	elif event is InputEventJoypadMotion and event.axis_value > 0.5:
		var k = TRIGGER.find_key(event.axis)
		if k:
			tapped[k] = true


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not autopilot and shot_path == "" and state.get("phase", "") == "fight":
		paused = true


func _physics_process(delta: float) -> void:
	if garage.visible:
		return
	aim = aim_point()
	var held := stop > 0
	if held:
		stop -= 1
	if not paused and not frozen and not held:
		var me = Bot.bot_input(state, pilot, 0) if autopilot and not sandbox else player_input()
		var foe = Bot.bot_input(state, brain, 1)
		if sandbox:
			pin()
			var t = state.mechs[1]
			me.mx = 0.0
			me.my = 0.0
			me.ax = t.x
			me.ay = t.y
			if auto_fire:
				me.left = state.tick % 2 == 0
			if auto_dash and state.tick % SANDBOX.dash == 0:
				me.dash = true
				me.my = -1.0
			if auto_hook:
				me.hook = state.tick % 2 == 0
			if auto_ult:
				state.mechs[0].surge = Sim.SURGE.max
				me.ult = true
			foe = Sim.IDLE.duplicate()
			foe.ax = state.mechs[0].x
			foe.ay = state.mechs[0].y
			foe.shield = block
			if guard:
				for s in state.shots:
					if s.owner == 0 and Vector2(s.x - t.x, s.y - t.y).length() < SANDBOX.guard:
						foe.shield = true
		Sim.step(state, [me, foe])
	if not frozen and not held:
		view.sync(state, aim, delta)
	crowd_sound.update(view.fresh_fx, view.hype, state.phase == "fight" and not paused, not paused)
	sfx.update(state, view.fresh_fx, paused)
	view.fresh_fx = []
	shake = maxf(shake, view.shake)
	view.shake = 0.0
	if view.kick.length() > kick.length() * exp(-kick_t * Fx.KICK.decay):
		kick = view.kick
		kick_t = 0.0
	view.kick = Vector3.ZERO
	stop = maxi(stop, view.stop)
	view.stop = 0
	slow = maxf(slow, view.slow)
	view.slow = 0.0
	view.process_mode = Node.PROCESS_MODE_DISABLED if stop > 0 else Node.PROCESS_MODE_INHERIT
	if cam_mode == 0:
		follow(delta)
	else:
		close_camera()
	hud.visible = cam_mode == 0
	hud.paused = paused
	hud.pad = on_pad
	if shot_at >= 0 and state.tick >= shot_at and not shooting:
		shooting = true
		take_shot()


func pin() -> void:
	var w: Dictionary = Sim.WEAPONS[loadout.left]
	var gap := clampf(w.get("range", 3.0) * SANDBOX.gap + SANDBOX.pad, SANDBOX.min, SANDBOX.max)
	if state.phase == "over":
		state.score.fill(0)
		Sim.reset_round(state)
	if state.phase == "countdown":
		state.phase = "fight"
		state.timer = 0
	state.clock = Sim.MATCH.time
	for i in 2:
		var m = state.mechs[i]
		m.heat = 0.0
		m.overheat = 0
		if m.act == null or m.act.k != "dash":
			m.x = Sim.CX + gap * (i - 0.5)
			m.y = Sim.CY
			m.vx = 0.0
			m.vy = 0.0
		for k in m.armor:
			if refill and m.armor[k] < m.max[k] * SANDBOX.refill:
				m.armor[k] = m.max[k]


func follow(delta: float) -> void:
	var me = state.mechs[0]
	var foe = state.mechs[1]
	var a := Vector3(me.x, 0, me.y)
	var b := Vector3(foe.x, 0, foe.y)
	var target := (a + b) / 2.0
	var want := clampf(maxf(absf(a.x - b.x) * 0.9 + 8.0, absf(a.z - b.z) * 2.0 + 12.0), 28.0, 64.0)
	if sandbox:
		want = maxf(absf(a.x - b.x) * SANDBOX.cam + 8.0, 10.0) * zoom
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
	cam.rotation = Vector3(-PITCH, 0, 0)


func close_camera() -> void:
	var m = state.mechs[target]
	var c: Array = CAMS[cam_mode]
	var at := Vector3(m.x, Sim.height_of(m) + 1.1, m.y)
	var t: float = (m.aim if c[3] else 0.0) + c[0] + orbit.x
	var p := clampf(c[1] + orbit.y, -0.1, 1.5)
	cam.position = at + Vector3(cos(t) * cos(p), sin(p), sin(t) * cos(p)) * c[2] * zoom
	cam.look_at(at)


func _process(delta: float) -> void:
	if slow > 0.0:
		slow -= delta / Engine.time_scale
		Engine.time_scale = Fx.KO.slow if slow > 0.0 else 1.0
	shake = maxf(0.0, shake - delta * 2.5)
	var s := shake * shake
	kick_t += delta
	var k := -kick * exp(-kick_t * Fx.KICK.decay) * cos(kick_t * Fx.KICK.freq)
	cam.h_offset = randf_range(-1.0, 1.0) * s * 0.6 + k.dot(cam.global_basis.x)
	cam.v_offset = randf_range(-1.0, 1.0) * s * 0.6 + k.dot(cam.global_basis.y)


func part_sheet(slot: String) -> void:
	set_process(false)
	set_physics_process(false)
	set_process_input(false)
	var layer := CanvasLayer.new()
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.05, 0.11)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(grid)
	for key in Sim.CATALOG[slot]:
		var v := PartView.new()
		v.custom_minimum_size = Vector2(210, 170)
		v.show_part(slot, key)
		var tag := Label.new()
		tag.text = key
		v.add_child(tag)
		grid.add_child(v)
	if shot_path != "":
		for i in 4:
			await get_tree().process_frame
		take_shot()


func take_shot() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(shot_path)
	get_tree().quit()
