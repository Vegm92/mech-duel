extends Node3D

const Sim = preload("res://src/sim.gd")
const Bot = preload("res://src/bot.gd")
const View = preload("res://src/view.gd")
const Fx = preload("res://src/fx.gd")
const Hud = preload("res://src/hud.gd")
const I18n = preload("res://src/i18n.gd")
const PartView = preload("res://src/part_view.gd")
const Garage = preload("res://src/garage.gd")
const Menu = preload("res://src/menu.gd")
const Progress = preload("res://src/progress.gd")
const Claim = preload("res://src/claim.gd")
const CrowdSound = preload("res://src/crowd_sound.gd")
const Sfx = preload("res://src/sfx.gd")
const Killcam = preload("res://src/killcam.gd")
const Look = preload("res://src/look.gd")
const Siege = preload("res://src/siege.gd")
const SiegeView = preload("res://src/siege_view.gd")
const SiegeBots = preload("res://src/siege_bots.gd")
const Radial = preload("res://src/radial.gd")
const SIEGE_CAM := {"dist": 48.0, "edge": 62.0, "near": 36.0, "far": 64.0, "group": 110.0, "top": 205.0}
const DUEL_CAM := {"near": 28.0, "far": 64.0, "crowd": 80.0}

const PITCH := deg_to_rad(60.0)
const FOV := 40.0
const SAVE := "user://loadout.cfg"
const DEV_KEYS := [KEY_F, KEY_C, KEY_TAB, KEY_T, KEY_K, KEY_J]
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
var brains := []
var view: Node3D
var hud: CanvasLayer
var cam: Camera3D
var focus := Vector3(Sim.CX, 0, Sim.CY)
var dist := 32.0
var paused := false
var autopilot := false
var seed_arg := -1
var shot_path := ""
var shot_at := -1
var shooting := false
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
## The Duel setup from the menu ({format, slots, ladder}); empty = the old lineup (look checks, --garage).
var duel := {}
## Per seat: the player number it belongs to (0 = P1, who keeps the old save files).
var who := [0]
var loadouts := [{}]
var profiles := {}
var free := Progress.new()
var turn := 0
var claims := []
var claimer := 0
var bot_level := "normal"
## Per mech: {seat (-1 = bot), team, level}.
var lineup := []
var rival_id := 1
var garage: CanvasLayer
var menu: CanvasLayer
var first_help := false
var claim: CanvasLayer
var progress := Progress.new()
var progress_arg := ""
var unlock_arg := false
var claim_arg := false
var rival_key := ""
var rival_lo: Dictionary
var broke := []
var foe_ko := false
var settled := false
var target := 0
var orbit := Vector2.ZERO
var zoom := 1.0
var pad_id := 0
## One seat per human. dev: -2 = the only player (keyboard, mouse and the last pad), -1 = keyboard + mouse, else a gamepad id.
var seats := [seat(-2)]
var shop_seat := 0
var join_arg := []
var aim: Vector3:
	get:
		return seats[0].aim
	set(v):
		seats[0].aim = v
var on_pad: bool:
	get:
		return seats[0].pad
	set(v):
		seats[0].pad = v
var reach: Vector2:
	get:
		return seats[0].reach
var rec := Killcam.recorder()
var replay := {}
var replay_at := -1
var siege := false
var team_n := 2
var wave_arg := 1
var director_on := false
var spawn_arg := ""
var modules_arg := false
var top_arg := false
var guard_arg := 0
var farm_arg := false
var shop_arg := false
var core_arg_pct := -1.0
var shot_on := ""
var allies := []
var siege_view: Node3D
var siege_bots: Node3D
var shop: Control


func _ready() -> void:
	I18n.setup()
	Look.ui()
	var accept := InputEventJoypadButton.new()
	accept.device = -1
	accept.button_index = JOY_BUTTON_A
	InputMap.action_add_event("ui_accept", accept)
	for a in OS.get_cmdline_user_args():
		if a == "--autopilot":
			autopilot = true
		elif a.begins_with("--seed="):
			seed_arg = a.substr(7).to_int()
		elif a.begins_with("--replay="):
			replay_at = a.substr(9).to_int()
			autopilot = true
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
		elif a == "--unlock-all":
			unlock_arg = true
		elif a == "--claim":
			claim_arg = true
		elif a.begins_with("--progress="):
			progress_arg = a.substr(11)
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
		elif a == "--siege":
			siege = true
		elif a == "--shop":
			shop_arg = true
		elif a == "--farm":
			farm_arg = true
		elif a.begins_with("--guard="):
			guard_arg = clampi(a.substr(8).to_int(), 0, 5)
		elif a == "--top":
			top_arg = true
		elif a.begins_with("--core=") and a.substr(7).is_valid_float():
			core_arg_pct = a.substr(7).to_float()
		elif a.begins_with("--shot-on="):
			shot_on = a.substr(10)
		elif a == "--modules":
			modules_arg = true
		elif a.begins_with("--spawn="):
			spawn_arg = a.substr(8)
		elif a.begins_with("--director="):
			director_on = a.substr(11) == "on"
		elif a.begins_with("--wave="):
			wave_arg = maxi(1, a.substr(7).to_int())
		elif a.begins_with("--players="):
			var devs := [-1]
			for i in range(1, clampi(a.substr(10).to_int(), 1, 4)):
				devs.append(i - 1)
			set_players(devs)
			join_arg = devs
		elif a.begins_with("--team="):
			team_n = clampi(a.substr(7).to_int(), 1, 4)
		elif a.begins_with("--lang="):
			TranslationServer.set_locale(a.substr(7))
		elif a == "--pad":
			on_pad = true
		elif a == "--sandbox" or a.begins_with("--sandbox="):
			sandbox = true
			gun = Sim.WEAPONS.keys().find(a.substr(10)) if a.contains("=") else -1
	var real := progress_arg != "" or not (autopilot or sandbox or shot_path != "")
	progress.unlock_all = unlock_arg or not real
	if progress_arg != "":
		progress.path = progress_arg
	if real:
		progress.load_file()
	if parts_arg != "":
		part_sheet(parts_arg)
		return
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	cam = Camera3D.new()
	cam.fov = FOV
	cam.far = 400.0
	cam.rotation = Vector3(-PITCH, 0, 0)
	add_child(cam)
	add_child(crowd_sound)
	add_child(sfx)
	hud = Hud.new()
	add_child(hud)
	shop_action()
	shop = Radial.new()
	hud.add_child(shop)
	shop.confirm_on_release = true
	shop.hold_action = &"siege_shop"
	shop.picked.connect(func(path: PackedStringArray): seats[shop_seat].tap.buy = path[-1])
	make_view()
	loadout = flag_loadout()
	garage = Garage.new()
	garage.progress = progress
	garage.mode = "siege" if siege else "duel"
	var saved := ConfigFile.new()
	saved.load(SAVE)
	var d := str(saved.get_value("garage", "difficulty", "normal"))
	bot_level = d if Bot.LEVELS.has(d) else "normal"
	add_child(garage)
	claim = Claim.new()
	add_child(claim)
	claim.picked.connect(claimed)
	claim.ui.connect(sfx.ui)
	garage.fight.connect(built)
	garage.back.connect(func() -> void: to_menu("duel" if garage.mode == "duel" else "modes"))
	menu = Menu.new()
	menu.bot_level = bot_level
	menu.setup = saved.get_value("setup", "duel", {})
	add_child(menu)
	menu.picked.connect(pick_mode)
	menu.ui.connect(sfx.ui)
	hud.resume.connect(resume)
	hud.restart.connect(new_match)
	hud.quit.connect(to_garage)
	hud.ui.connect(sfx.ui)
	garage.ui.connect(sfx.ui)
	if sandbox and gun < 0:
		gun = maxi(0, Sim.WEAPONS.keys().find(loadout.left))
	first_help = real and not FileAccess.file_exists(SAVE)
	if garage_arg >= 0:
		to_garage()
	elif not (autopilot or shot_at >= 0 or sandbox):
		to_menu()
	else:
		menu.visible = false
		garage.visible = false
		new_match()
		if claim_arg:
			claim.open(progress.pool(["larm", "legs"], rival_lo, true), rival_key, progress.tier(rival_key), progress)


func shop_action() -> void:
	if InputMap.has_action(&"siege_shop"):
		return
	InputMap.add_action(&"siege_shop")
	var k := InputEventKey.new()
	k.physical_keycode = KEY_SHIFT
	InputMap.action_add_event(&"siege_shop", k)
	var b := InputEventJoypadButton.new()
	b.device = -1
	b.button_index = JOY_BUTTON_Y
	InputMap.action_add_event(&"siege_shop", b)


func make_view() -> void:
	for n in [view, siege_view, siege_bots]:
		if n != null:
			n.queue_free()
	siege_view = null
	siege_bots = null
	view = View.new()
	add_child(view)
	view.build(siege)
	if siege:
		siege_view = SiegeView.new()
		add_child(siege_view)
		siege_view.build()
		view.crowd_mat = siege_view.crowd_mat
		view.towers.append_array(siege_view.towers)
		siege_bots = SiegeBots.new()
		add_child(siege_bots)
	hud.view = view
	view.visible = not garage.visible if garage != null else true


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


static func lo_key(p: int) -> String:
	return "loadout" if p == 0 else "loadout_p%d" % (p + 1)


func saved_loadout(p := 0) -> Dictionary:
	var cfg := ConfigFile.new()
	cfg.load(SAVE)
	return progress.fit(cfg.get_value("garage", lo_key(p), {}))


## Saves every seat's mech (P1 under the old key) and the Duel setup.
func save_loadout() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE)
	for t in seats.size():
		cfg.set_value("garage", lo_key(who[t]), lo_of(t))
	cfg.set_value("garage", "difficulty", bot_level)
	if not duel.is_empty():
		cfg.set_value("setup", "duel", duel)
	cfg.save(SAVE)


func lo_of(t: int) -> Dictionary:
	return loadout if t == 0 else loadouts[t]


func set_lo(t: int, lo: Dictionary) -> void:
	if t == 0:
		loadout = lo
	else:
		loadouts[t] = lo


## Player p's ladder save: P1 keeps progress.cfg, the others get progress_p<n>.cfg next to it.
func profile(p: int) -> Progress:
	if p == 0:
		return progress
	if not profiles.has(p):
		var pr := Progress.new()
		pr.unlock_all = progress.unlock_all
		pr.path = progress.path.get_basename() + "_p%d.cfg" % (p + 1)
		if not pr.unlock_all:
			pr.load_file()
		profiles[p] = pr
	return profiles[p]


## The parts seat t may use: all of them in a free match, else that player's own unlocks.
func prog(t: int) -> Progress:
	if not siege and not duel.is_empty() and not duel.ladder:
		return free
	return profile(who[t])


func ladder_on() -> bool:
	if duel.is_empty():
		return not progress.unlock_all and seats.size() == 1
	return duel.ladder and not progress.unlock_all


func resume() -> void:
	paused = false
	clear_taps()


func leave_match() -> void:
	end_replay()
	paused = false
	crowd_sound.update([], 0.0, false, false)
	sfx.menu()
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	view.visible = false
	hud.visible = false
	get_viewport().disable_3d = true


func to_menu(at := "") -> void:
	leave_match()
	garage.visible = false
	menu.open(at)
	if not join_arg.is_empty():
		menu.players = join_arg.duplicate()
		menu.page = "players"
		menu.build()
	if shot_path != "":
		for i in 8:
			await get_tree().process_frame
		take_shot()


func clear_taps() -> void:
	for t in seats:
		t.tap.clear()


static func seat(dev: int) -> Dictionary:
	return {"dev": dev, "tap": {}, "aim": Vector3(Sim.CX, 0, Sim.CY), "reach": Vector2.ZERO, "recent": [], "pad": dev >= 0}


## One seat per joined device; a single player keeps every device.
func set_players(devs: Array, ids := []) -> void:
	seats = [seat(-2)] if devs.size() <= 1 else devs.map(func(d): return seat(d))
	who = ids if ids.size() == devs.size() and not ids.is_empty() else range(maxi(1, devs.size()))
	loadouts = [loadout]
	for t in range(1, seats.size()):
		loadouts.append(saved_loadout(who[t]) if not (autopilot or shot_path != "") else loadout.duplicate())


func pick_mode(mode: String) -> void:
	duel = menu.setup.duplicate(true) if mode == "duel" else {}
	if duel.is_empty():
		set_players(menu.players)
	else:
		var ids: Array = duel.slots.map(func(sl): return sl.who).filter(func(w): return w >= 0)
		set_players(ids.map(func(w): return menu.players[w]), ids)
	garage.mode = mode
	loadout = prog(0).fit(loadout)
	to_garage()
	if first_help:
		first_help = false
		garage.show_help()


func to_garage() -> void:
	garage_turn(0)
	if hover_arg != "" or shot_path != "":
		look_garage()


## Opens the garage for seat t: its player's name, unlocks and mech.
func garage_turn(t: int) -> void:
	leave_match()
	menu.visible = false
	claim.visible = false
	turn = t
	garage.progress = prog(t)
	garage.who = tr("playerN").format({"n": who[t] + 1}) if seats.size() > 1 and garage.mode == "duel" else ""
	garage.last = garage.mode == "siege" or t == seats.size() - 1
	garage.open(lo_of(t), garage_arg)


## FIGHT in the garage: keep this seat's mech, then the next seat builds or the match starts.
func built(lo: Dictionary) -> void:
	set_lo(turn, lo)
	if not garage.last:
		garage_turn(turn + 1)
		return
	start(loadout, garage.mode == "siege")


func look_garage() -> void:
	if hover_arg != "":
		garage.set_hover({"set": hover_arg} if garage.SLOTS[garage.tab] == "set" else {"slot": garage.SLOTS[garage.tab], "key": hover_arg})
	if shot_path != "":
		for i in 8:
			await get_tree().process_frame
		take_shot()


func start(lo: Dictionary, mode := false) -> void:
	if mode != siege:
		siege = mode
		make_view()
	loadout = lo
	if loadouts.size() > 0:
		loadouts[0] = lo
	if not autopilot and shot_path == "":
		save_loadout()
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	garage.visible = false
	view.visible = true
	get_viewport().disable_3d = false
	new_match()


func new_match() -> void:
	end_replay()
	paused = false
	stop = 0
	slow = 0.0
	Engine.time_scale = 1.0
	clear_taps()
	rec = Killcam.recorder()
	var s := seed_arg if seed_arg >= 0 else int(Time.get_unix_time_from_system() * 1000.0) & 0x7fffffff
	rival_key = ""
	rival_id = -1
	broke = []
	foe_ko = false
	settled = false
	if sandbox:
		loadout.left = Sim.WEAPONS.keys()[gun]
		loadout.right = loadout.left
	if siege:
		shop.close()
		var los := [progress.with_levels(loadout.duplicate())]
		allies = [null]
		for i in range(1, maxi(team_n, seats.size())):
			los.append(los[0].duplicate() if i < seats.size() else Sim.SETS.values()[(s + i) % Sim.SETS.size()])
			allies.append(Bot.create_brain(s + 10 + i))
		state = Siege.create(los, s)
		state.siege.director.on = director_on
		if not progress.unlock_all:
			var own := {}
			for slot in Siege.S.PART_SLOTS:
				own[slot] = {}
				for key in Sim.CATALOG[slot]:
					if progress.has(slot, key):
						own[slot][key] = progress.level(slot, key)
			for i in seats.size():
				state.siege.owned[i] = own.duplicate(true)
		state.siege.wave.n = wave_arg - 1
		for t in guard_arg:
			state.siege.fund += Siege.GARRISON.cost[t]
			Siege.buy(state, state.siege, "garrison", state.mechs[0])
		if guard_arg > 0 and cam_mode > 0:
			target = state.siege.guard
		if core_arg_pct >= 0.0:
			state.siege.core.hp = state.siege.core.max * core_arg_pct / 100.0
			Siege.rings(state, state.siege)
		if modules_arg:
			for b in [[0, "wall"], [1, "mine"], [2, "laser"], [3, "post"]]:
				Siege.build(state, state.siege.pads[b[0]], b[1])
		if Siege.BOTS.has(spawn_arg):
			Siege.look(state, spawn_arg)
	else:
		lineup = lineup_of()
		var los := []
		var teams := []
		for k in lineup.size():
			var e: Dictionary = lineup[k]
			teams.append(e.team)
			if e.seat >= 0:
				los.append(prog(e.seat).with_levels(lo_of(e.seat).duplicate()))
				continue
			var lo: Dictionary
			if rival_id < 0 and ladder_on():
				rival_key = prog(0).next_rival()
				lo = prog(0).rival(rival_key)
			else:
				lo = Sim.SETS.values()[(s + (0 if rival_id < 0 else k)) % Sim.SETS.size()].duplicate()
			if rival_id < 0:
				rival_id = k
				rival_lo = lo
			los.append(lo)
		state = Sim.create_state(los, teams)
	if sandbox:
		pin()
	brain = Bot.create_brain(s + 1)
	pilot = Bot.create_brain(s + 2)
	brains = [pilot, brain]
	for i in range(2, state.mechs.size()):
		brains.append(Bot.create_brain(s + 10 + i))
	hud.levels = []
	for i in state.mechs.size():
		var lv: String = lineup[i].level if not siege and i < lineup.size() and lineup[i].seat < 0 else ""
		hud.levels.append(lv)
		if lv != "":
			brains[i].merge(Bot.LEVELS[lv], true)
	hud.humans = seats.size()
	if farm_arg:
		pilot.farm = true
	view.reset(state)
	hud.state = state
	snap_camera()
	if replay_at >= 0:
		while state.phase != "over" and not Killcam.wants(state, rec):
			var ins := [Bot.bot_input(state, pilot, 0), Bot.bot_input(state, brain, 1)]
			Killcam.record(rec, state, ins)
			Sim.step(state, ins)
		if Killcam.wants(state, rec):
			start_replay()


## Who fights in a duel: humans first (seat order), then bots, each with its team and level.
func lineup_of() -> Array:
	var out := []
	if duel.is_empty():
		var lv := "" if autopilot or sandbox else bot_level
		for i in 2 if seats.size() <= 2 else 4:
			out.append({"seat": i if i < seats.size() else -1, "team": i, "level": lv})
		return out
	var teams: Array = Menu.TEAMS[duel.format]
	for k in duel.slots.size():
		if duel.slots[k].who >= 0:
			out.append({"seat": who.find(duel.slots[k].who), "team": teams[k], "level": ""})
	for k in duel.slots.size():
		if duel.slots[k].who < 0:
			out.append({"seat": -1, "team": teams[k], "level": duel.slots[k].level})
	return out


## Where the camera keeps in view: every human in Core Siege, every mech in a duel.
func group() -> Array:
	var pts := []
	for i in (seats.size() if siege else state.mechs.size()):
		pts.append(Vector3(state.mechs[i].x, 0, state.mechs[i].y))
	return pts


func snap_camera() -> void:
	var pts := group()
	focus = pts.reduce(func(a, b): return a + b, Vector3.ZERO) / pts.size()
	place_camera()
	cam.reset_physics_interpolation()


func key(k: Key, i := 0) -> bool:
	return seats[i].dev < 0 and Input.is_physical_key_pressed(k)


## The gamepad seat i reads, or -1 (keyboard + mouse only).
func pad_of(i: int) -> int:
	return pad_id if seats[i].dev == -2 else seats[i].dev


func pad(k: String, i := 0) -> bool:
	var p := pad_of(i)
	if p < 0:
		return false
	if TRIGGER.has(k):
		return Input.get_joy_axis(p, TRIGGER[k]) > 0.5
	return Input.is_joy_button_pressed(p, PAD[k])


func stick(x: JoyAxis, y: JoyAxis, i := 0) -> Vector2:
	var p := pad_of(i)
	if p < 0:
		return Vector2.ZERO
	var v := Vector2(Input.get_joy_axis(p, x), Input.get_joy_axis(p, y)).limit_length(1.0)
	return v if v.length() > DEAD else Vector2.ZERO


func mouse(b: MouseButton, i: int) -> bool:
	return seats[i].dev < 0 and Input.is_mouse_button_pressed(b)


func player_input(i := 0) -> Dictionary:
	var st: Dictionary = seats[i]
	var tap: Dictionary = st.tap
	var p := pad_of(i)
	var move := stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, i)
	var shopping: bool = shop.visible and shop_seat == i
	var inp := {
		"mx": float(int(key(KEY_D, i)) - int(key(KEY_A, i))) + move.x,
		"my": float(int(key(KEY_S, i)) - int(key(KEY_W, i))) + move.y,
		"ax": st.aim.x,
		"ay": st.aim.z,
		"left": mouse(MOUSE_BUTTON_LEFT, i) or tap.has("left") or pad("left", i),
		"right": mouse(MOUSE_BUTTON_RIGHT, i) or tap.has("right") or pad("right", i),
		"shield": key(KEY_Q, i) or tap.has("shield") or pad("shield", i),
		"hook": key(KEY_E, i) or tap.has("hook") or pad("hook", i),
		"dash": key(KEY_SPACE, i) or tap.has("dash") or pad("dash", i),
		"ult": key(KEY_R, i) or tap.has("ult") or pad("ult", i),
		"buy": tap.get("buy", ""),
		"call": tap.has("call"),
		"post": tap.has("post"),
		"use": key(KEY_V, i) or (siege and p >= 0 and Input.is_joy_button_pressed(p, JOY_BUTTON_A)),
		"recall": key(KEY_B, i) or (siege and p >= 0 and Input.is_joy_button_pressed(p, JOY_BUTTON_X)),
		"shop": shopping,
	}
	if shopping:
		for k in ["left", "right", "hook", "ult", "dash", "shield"]:
			inp[k] = false
		inp.ax = state.mechs[i].tx
		inp.ay = state.mechs[i].ty
	tap.clear()
	return inp


func aim_point(i := 0) -> Vector3:
	var st: Dictionary = seats[i]
	var r := stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y, i) * REACH
	if r != Vector2.ZERO:
		st.pad = true
		st.reach = r
		st.recent.push_back(r)
		if st.recent.size() > LOOKBACK:
			st.recent.pop_front()
	elif not st.recent.is_empty():
		st.reach = st.recent[0]
		st.recent.clear()
	if st.pad or st.dev >= 0:
		var me = state.mechs[i]
		return Vector3(me.x + st.reach.x, 0, me.y + st.reach.y)
	var mp := get_viewport().get_mouse_position()
	var o := cam.project_ray_origin(mp)
	var d := cam.project_ray_normal(mp)
	if absf(d.y) < 0.001:
		return st.aim
	var t := -o.y / d.y
	return o + d * t if t > 0 else st.aim


## The seat an event belongs to, or -1 (a device nobody joined with).
func seat_of(ev: InputEvent) -> int:
	if seats.size() == 1:
		return 0
	var d: int = ev.device if ev is InputEventJoypadButton or ev is InputEventJoypadMotion else -1
	for i in seats.size():
		if seats[i].dev == d:
			return i
	return -1


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_M, KEY_N]:
		Sfx.toggle("muted" if event.physical_keycode == KEY_M else "music_on")
	if garage.visible or claim.visible or menu.visible:
		return
	var sid := seat_of(event)
	var tap: Dictionary = seats[sid].tap if sid >= 0 else {}
	if event is InputEventMouseMotion and sid >= 0:
		seats[sid].pad = false
	if seats.size() == 1 and (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		pad_id = event.device
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in DEV_KEYS and not OS.is_debug_build():
			return
		match event.physical_keycode:
			KEY_Q:
				tap.shield = true
			KEY_E:
				tap.hook = true
			KEY_SPACE:
				tap.dash = true
			KEY_R:
				tap.ult = true
			KEY_ESCAPE:
				paused = not paused
			KEY_ENTER, KEY_KP_ENTER:
				if skip():
					get_viewport().set_input_as_handled()
				elif state.phase == "over":
					to_garage()
					get_viewport().set_input_as_handled()
			KEY_L:
				I18n.toggle()
			KEY_X:
				tap.post = true
			KEY_SHIFT:
				open_shop(sid)
			KEY_F:
				frozen = not frozen
				clear_taps()
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
				tap.call = true
			KEY_K:
				refill = not refill
			KEY_J:
				auto_dash = not auto_dash
	elif event is InputEventMouseMotion and frozen and cam_mode > 0 and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		orbit += event.relative * 0.01
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			tap.left = true
			skip()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			tap.right = true
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = maxf(zoom * 0.9, 0.3)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = minf(zoom * 1.1, 3.0)
	elif event is InputEventJoypadButton and event.pressed:
		var k = PAD.find_key(event.button_index)
		if event.button_index == JOY_BUTTON_Y:
			open_shop(sid)
		elif k:
			tap[k] = true
		elif event.button_index == JOY_BUTTON_START:
			paused = not paused
		elif event.button_index == JOY_BUTTON_A:
			skip()
	elif event is InputEventJoypadMotion and event.axis_value > 0.5:
		var k = TRIGGER.find_key(event.axis)
		if k:
			tap[k] = true


func open_shop(i := 0) -> void:
	if i < 0 or not siege or shop.visible or paused or state.phase == "over" or state.mechs[i].ko:
		return
	if Sim.hypot(state.mechs[i].x, state.mechs[i].y) > Siege.S.PLAZA:
		return
	shop_seat = i
	shop.device = seats[i].dev
	if seats[i].dev >= 0:
		shop.pad_id = seats[i].dev
	shop.open(hud.shop_menu(i))


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not autopilot and shot_path == "" and state.get("phase", "") == "fight":
		paused = true


func _physics_process(delta: float) -> void:
	if garage.visible or claim.visible or menu.visible:
		return
	for i in seats.size():
		seats[i].aim = aim_point(i)
	var held := stop > 0
	if held:
		stop -= 1
	if not paused and not frozen and not held and not replay.is_empty():
		Killcam.advance(replay)
		if Killcam.done(replay):
			back_to_live()
	elif not paused and not frozen and not held:
		var bots: bool = autopilot and not sandbox
		var ins := []
		for i in seats.size():
			if not bots:
				ins.append(player_input(i))
			elif siege:
				ins.append(Siege.ally_input(state, pilot if i == 0 else allies[i], i))
			else:
				ins.append(Bot.bot_input(state, brains[i], i))
		var me = ins[0]
		if siege:
			for i in range(ins.size(), state.siege.team):
				ins.append(Siege.ally_input(state, allies[i], i))
			Siege.step(state, ins)
		else:
			for i in range(ins.size(), state.mechs.size()):
				ins.append(Bot.bot_input(state, brains[i], i))
		var foe = null if siege else ins[1]
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
			ins[1] = foe
		elif not siege:
			Killcam.record(rec, state, ins)
		if not siege:
			Sim.step(state, ins)
		if not siege and Killcam.wants(state, rec):
			start_replay()
	if siege and shop_arg and state.tick == 60:
		state.siege.fund += 2000
		state.siege.wallets[0] += 600
		open_shop()
	if siege and shop.visible:
		var sm: Dictionary = state.mechs[shop_seat]
		if sm.ko or Sim.hypot(sm.x, sm.y) > Siege.S.PLAZA:
			shop.close()
		elif state.tick % 10 == 0:
			shop.refresh(hud.shop_menu(shop_seat))
	if not frozen and not held:
		view.sync(state, aim, delta, seats.slice(1).map(func(t): return t.aim))
		if siege:
			siege_view.update(state.siege)
			siege_bots.sync(state.siege, delta)
	track()
	crowd_sound.update(view.fresh_fx, 0.0 if siege else view.hype, state.phase == "fight" and not paused and not siege, not paused)
	sfx.update(state, view.fresh_fx, paused)
	if shot_on != "" and not shooting and view.fresh_fx.any(func(f): return f.k == shot_on):
		shooting = true
		take_shot()
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
	if replay.is_empty() and cam_mode == 0:
		follow(delta)
	elif replay.is_empty():
		close_camera()
	hud.visible = cam_mode == 0 or not replay.is_empty()
	hud.replay = Killcam.progress(replay)
	hud.paused = paused
	hud.pad = on_pad
	if shot_at >= 0 and state.tick >= shot_at and not shooting:
		shooting = true
		take_shot()
	if replay_at >= 0 and shot_path != "" and not replay.is_empty() and replay.i >= replay_at and not shooting:
		shooting = true
		take_shot()


func track() -> void:
	if siege:
		for f in view.fresh_fx:
			if f.k == "milestone" and not progress.unlock_all:
				var drops := progress.spoils(f.n)
				if not drops.is_empty():
					Input.set_default_cursor_shape(Input.CURSOR_ARROW)
					claim.open(drops, Progress.SIEGE_SPOILS[f.n], f.n / 10, progress)
		if state.phase == "over" and not settled:
			settled = true
			if not progress.unlock_all and progress.held(maxi(0, state.siege.wave.n - 1)):
				progress.save_file()
		hud.best = progress.best
		return
	for f in view.fresh_fx:
		if f.k == "break" and f.id == rival_id and not broke.has(f.part):
			broke.append(f.part)
		elif f.k == "ko" and f.id == rival_id:
			foe_ko = true
	if state.phase == "over" and not settled:
		settle()


## A ladder win: every player beats the rival and, when it broke something new for them, picks a part.
func settle() -> void:
	settled = true
	if progress.unlock_all or rival_key == "":
		return
	var team: int = state.mechs[0].team
	for t in state.score.size():
		if t != team and state.score[t] >= state.score[team]:
			return
	claims = []
	for t in seats.size():
		if prog(t).pool(broke, rival_lo, foe_ko).is_empty():
			prog(t).win(rival_key)
			prog(t).save_file()
		else:
			claims.append(t)
	next_claim()


func next_claim() -> void:
	if claims.is_empty():
		return
	claimer = claims.pop_front()
	var p := prog(claimer)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	claim.open(p.pool(broke, rival_lo, foe_ko), rival_key, p.tier(rival_key), p, tr("playerN").format({"n": who[claimer] + 1}) if seats.size() > 1 else "")


func claimed(slot: String, key: String) -> void:
	if siege:
		progress.claim(slot, key)
		progress.save_file()
		Input.set_default_cursor_shape(Input.CURSOR_CROSS)
		return
	var p := prog(claimer)
	p.claim(slot, key)
	p.win(rival_key)
	p.save_file()
	set_lo(claimer, Sim.normalize(lo_of(claimer).merged({slot: key}, true)))
	if not autopilot and shot_path == "":
		save_loadout()
	if claims.is_empty():
		to_garage()
	else:
		next_claim()


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
	var pts := group()
	var a: Vector3 = pts[0]
	var b: Vector3 = pts[0]
	for p in pts:
		a = a.min(p)
		b = b.max(p)
	var target := (a + b) / 2.0
	var want := clampf(maxf(absf(a.x - b.x) * 0.9 + 8.0, absf(a.z - b.z) * 2.0 + 12.0), DUEL_CAM.near, DUEL_CAM.far if pts.size() <= 2 else DUEL_CAM.crowd)
	if siege:
		want = clampf(maxf(SIEGE_CAM.dist * zoom, want if pts.size() > 1 else 0.0), SIEGE_CAM.near, SIEGE_CAM.far if pts.size() == 1 else SIEGE_CAM.group)
		target = Vector3(clampf(target.x, -SIEGE_CAM.edge, SIEGE_CAM.edge), 0, clampf(target.z, -SIEGE_CAM.edge, SIEGE_CAM.edge))
		if top_arg:
			want = SIEGE_CAM.top
			target = Vector3.ZERO
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


func start_replay() -> void:
	var live := state
	replay = Killcam.start(rec, live)
	replay.live = live
	cut_to(replay.state)
	view.replaying = true
	cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	sfx.ui("rewind")


## Drops the replay (also on a restart or quit) and gives the match back its live state.
func end_replay() -> void:
	if replay.is_empty():
		return
	state = replay.live
	replay = {}
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = Sim.TICKS
	cam.fov = FOV
	view.replaying = false
	cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_INHERIT


func back_to_live() -> void:
	end_replay()
	while state.phase == "ko":
		Sim.step(state, [])
	Killcam.untag(state)
	cut_to(state)
	snap_camera()


func skip() -> bool:
	if replay.is_empty() or paused or replay.i < Killcam.KILLCAM.grace:
		return false
	back_to_live()
	return true


func cut_to(s: Dictionary) -> void:
	state = s
	hud.state = s
	var h: float = view.hype
	view.reset(s)
	view.hype = h
	stop = 0
	slow = 0.0
	clear_taps()


## Slow motion = fewer physics ticks per real second (the sim steps once per tick) with time_scale
## keeping each tick's delta at 1/60; time_scale alone only shrinks delta.
func direct(real: float) -> void:
	var f := Killcam.film(replay, spot(replay.killer), spot(replay.victim), real)
	var ticks := roundi(Sim.TICKS * f.speed)
	if ticks != Engine.physics_ticks_per_second:
		Engine.physics_ticks_per_second = ticks
		Engine.time_scale = ticks / float(Sim.TICKS)
	cam.fov = f.fov
	cam.position = f.eye
	cam.look_at(f.look)


func spot(id: int) -> Vector3:
	var m: Dictionary = state.mechs[id]
	var n = view.mechs[id]
	return n.get_global_transform_interpolated().origin if is_same(n.src, m) else Killcam.spot_of(m)


func _process(delta: float) -> void:
	if not replay.is_empty():
		if not paused:
			direct(delta / Engine.time_scale)
	elif slow > 0.0:
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
