extends SceneTree

const Sim = preload("res://src/sim.gd")
const Garage = preload("res://src/garage.gd")
const Seats = preload("res://src/seats.gd")
const Edition = preload("res://src/edition.gd")
const I18n = preload("res://src/i18n.gd")

const SAVE := "user://loadout.cfg"
const KEYS := ["fmtLabel", "fmt_1v1", "fmt_ffa", "fmt_2v2", "whoPlayer", "seatsTitle", "seatKb", "seatPad", "seatBot", "seatFree", "seatsHint", "seatsNeed", "creditsBtn", "creditsTitle", "creditsSound", "creditsBack", "creditsKenney", "creditsQuendel", "creditsNocturnal"]

var failed := 0
var filter := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var at := args.find("--filter")
	if at >= 0 and at + 1 < args.size():
		filter = args[at + 1]
	I18n.setup()
	await run("the_format_picker_sets_the_format_and_the_match_follows_it", test_picker)
	await run("the_format_is_saved_with_the_loadout", test_saved_format)
	await run("seats_join_leave_and_start", test_seats)
	await run("two_local_humans_read_their_own_pads_and_aim_with_no_assist", test_two_humans)
	await run("the_camera_frames_every_local_human_and_never_rotates", test_camera)
	await run("a_full_duel_runs_with_siege_off", test_siege_off)
	await run("the_siege_button_is_there_only_when_siege_is_on", test_siege_button)
	await run("credits_list_every_licensed_asset_in_both_languages", test_credits)
	await run("the_steam_preset_turns_siege_off_and_no_uid_is_orphaned", test_files)
	print("FAILED" if failed else "ALL PASSED")
	quit(1 if failed else 0)


func run(name: String, test: Callable) -> void:
	if filter != "" and not name.contains(filter):
		print("test skipped: " + name)
		return
	var t0 := Time.get_ticks_msec()
	var r = await test.call()
	if not (r is int and r == 0):
		failed += 1
		print("test failed: %s" % name)
	else:
		print("test passed: %s (%d ms)" % [name, Time.get_ticks_msec() - t0])


func ensure(cond: bool, what: String) -> int:
	if not cond:
		print("  condition false: " + what)
		return 1
	return 0


func duel(fmt := "1v1", locals := ["kb"], seed := 5):
	var m = load("res://main.tscn").instantiate()
	m.autopilot = true
	m.seed_arg = seed
	m.format_arg = fmt
	root.add_child(m)
	await process_frame
	m.locals = locals
	m.new_match()
	m.autopilot = false
	m.frozen = true
	return m


func joy(button: int, device: int) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.device = device
	e.button_index = button
	e.pressed = true
	return e


func axis(a: JoyAxis, v: float, device: int) -> void:
	var e := InputEventJoypadMotion.new()
	e.device = device
	e.axis = a
	e.axis_value = v
	Input.parse_input_event(e)


func texts(n: Node) -> Array:
	var out := []
	for c in n.find_children("*", "Label", true, false):
		out.append(c.text)
	return out


func test_picker() -> int:
	var g = Garage.new()
	root.add_child(g)
	g.open(Sim.DEFAULT_LOADOUT)
	await process_frame
	var bad := ensure(g.format == "1v1", "the garage starts on 1v1")
	var labels := texts(g.root)
	bad += ensure(labels.has("1V1") and labels.has("FFA") and labels.has("2V2"), "the three formats are on screen")
	g.set_format("2v2")
	bad += ensure(g.format == "2v2" and g.loadout == Sim.DEFAULT_LOADOUT, "picking 2v2 changes the format and keeps the bot")
	g.set_format("nonsense")
	bad += ensure(g.format == "2v2", "an unknown format is ignored")
	g.queue_free()
	for fmt in ["ffa", "2v2", "1v1"]:
		var m = await duel(fmt)
		m.garage.set_format(fmt)
		m.garage.go()
		await physics_frame
		bad += ensure(m.state.mechs.map(func(x): return x.team) == Sim.FORMATS[fmt], "FIGHT in %s builds the teams %s" % [fmt, Sim.FORMATS[fmt]])
		m.queue_free()
		await process_frame
	return int(bad > 0)


func test_saved_format() -> int:
	var had := FileAccess.file_exists(SAVE)
	var keep := FileAccess.get_file_as_bytes(SAVE) if had else PackedByteArray()
	var m = await duel("ffa")
	m.save_loadout()
	var bad := ensure(m.saved_format() == "ffa", "the saved file remembers ffa")
	var cfg := ConfigFile.new()
	cfg.load(SAVE)
	cfg.set_value("garage", "format", "bogus")
	cfg.save(SAVE)
	bad += ensure(m.saved_format() == "1v1", "a bad saved format falls back to 1v1")
	m.queue_free()
	if had:
		var f := FileAccess.open(SAVE, FileAccess.WRITE)
		f.store_buffer(keep)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	await process_frame
	return int(bad > 0)


func test_seats() -> int:
	var s = Seats.new()
	root.add_child(s)
	var sent := []
	s.confirmed.connect(func(list): sent.append(list))
	s.open(["kb"], "1v1")
	var bad := ensure(s.list == ["kb"], "the keyboard starts seated")
	s._input(joy(JOY_BUTTON_A, 3))
	bad += ensure(s.list == ["kb", 3], "A on a pad takes the next seat")
	s._input(joy(JOY_BUTTON_A, 4))
	bad += ensure(s.list == ["kb", 3], "1v1 has two seats only")
	s._input(joy(JOY_BUTTON_B, 3))
	bad += ensure(s.list == ["kb"], "B on a seated pad leaves")
	s.open(["kb"], "ffa")
	for d in [1, 2, 3, 4]:
		s._input(joy(JOY_BUTTON_A, d))
	bad += ensure(s.list == ["kb", 1, 2, 3], "ffa seats four, in join order")
	s._input(joy(JOY_BUTTON_START, 1))
	bad += ensure(sent == [["kb", 1, 2, 3]] and not s.visible, "Start confirms the seated list")
	s.open([], "2v2")
	s.go()
	bad += ensure(sent.size() == 1 and s.warn and s.visible, "nobody seated: no match, a warning")
	s.queue_free()
	await process_frame
	return int(bad > 0)


func test_two_humans() -> int:
	var m = await duel("1v1", ["kb", 3])
	var bad := ensure(m.aims.size() == 2, "one aim state per seat")
	m.state.mechs[0].x = 40.0
	m.state.mechs[0].y = 20.0
	m.state.mechs[1].x = 45.0
	m.state.mechs[1].y = 23.0
	axis(JOY_AXIS_LEFT_X, 1.0, 3)
	axis(JOY_AXIS_RIGHT_X, 1.0, 3)
	for i in 3:
		await physics_frame
	var one: Dictionary = m.player_input(1)
	var zero: Dictionary = m.player_input(0)
	bad += ensure(one.mx == 1.0 and zero.mx == 0.0, "pad 3 walks seat 2 and nobody else")
	var me: Dictionary = m.state.mechs[1]
	bad += ensure(m.aims[1].at == Vector3(me.x + 16.0, 0, me.y), "full right stick aims 16 m straight out, not bent toward the foe")
	bad += ensure(m.aims[0].reach == Vector2.ZERO and not m.aims[0].on_pad, "the keyboard seat is untouched")
	m._input(joy(JOY_BUTTON_RIGHT_SHOULDER, 3))
	bad += ensure(m.taps.get(3, {}).has("shield") and not m.tapped.has("shield"), "a tap on pad 3 latches for pad 3 only")
	var ins: Dictionary = m.player_input(1)
	bad += ensure(ins.shield and not m.player_input(0).shield, "the latched shield tap reaches seat 2 and is then used up")
	axis(JOY_AXIS_LEFT_X, 0.0, 3)
	axis(JOY_AXIS_RIGHT_X, 0.0, 3)
	await physics_frame
	m.queue_free()
	await process_frame
	return int(bad > 0)


func test_camera() -> int:
	var m = await duel("ffa", ["kb", 1, 2, 3])
	var xs := [10.0, 70.0, 20.0, 30.0]
	var zs := [5.0, 15.0, 45.0, 25.0]
	for i in 4:
		m.state.mechs[i].x = xs[i]
		m.state.mechs[i].y = zs[i]
	var pts: Array = m.frame_points()
	var box: Array = m.frame_box(pts)
	var bad := ensure(pts.size() == 4 and box[0] == Vector3(10, 0, 5) and box[1] == Vector3(70, 0, 45), "all four humans are in the frame box")
	for i in 120:
		m.follow(1.0 / 60.0)
	var pitch: float = m.PITCH
	bad += ensure(m.cam.rotation == Vector3(-pitch, 0, 0), "the camera never rotates")
	bad += ensure(absf(m.focus.x - 40.0) < 3.0 and m.dist > 40.0, "it settles on the middle of the four and pulls back")
	m.queue_free()
	await process_frame
	var solo = await duel("1v1", ["kb"])
	bad += ensure(solo.frame_points().size() == 2, "a lone human still keeps the rival in frame")
	solo.queue_free()
	await process_frame
	return int(bad > 0)


func test_siege_off() -> int:
	Edition.siege = false
	var m = load("res://main.tscn").instantiate()
	m.autopilot = true
	m.seed_arg = 11
	m.siege = true
	root.add_child(m)
	await process_frame
	var bad := ensure(not m.siege and not m.state.has("siege"), "--siege is ignored")
	bad += ensure(m.Siege == null and m.SiegeView == null and m.Radial == null and m.shop == null and m.hud.Siege == null, "no siege script is loaded")
	var i := 0
	while m.state.phase != "over" and i < 60000:
		m._physics_process(1.0 / 60.0)
		i += 1
	bad += ensure(m.state.phase == "over" and m.state.score.max() == Sim.MATCH.wins, "a full duel ends with a winner after %d ticks" % i)
	m.queue_free()
	await process_frame
	var f = await duel("ffa", ["kb", 1])
	f.autopilot = true
	f.frozen = false
	i = 0
	while f.state.phase != "over" and i < 60000:
		f._physics_process(1.0 / 60.0)
		i += 1
	bad += ensure(f.state.phase == "over", "a full ffa match also ends with siege off")
	f.queue_free()
	Edition.siege = true
	await process_frame
	return int(bad > 0)


func test_siege_button() -> int:
	var on = Garage.new()
	root.add_child(on)
	on.open(Sim.DEFAULT_LOADOUT)
	var bad := ensure(texts(on.root).has(on.tr("siegeBtn")), "with siege on the garage has the CORE SIEGE button")
	on.queue_free()
	Edition.siege = false
	var off = Garage.new()
	root.add_child(off)
	off.open(Sim.DEFAULT_LOADOUT)
	bad += ensure(not texts(off.root).has(off.tr("siegeBtn")) and texts(off.root).has("2V2"), "with siege off it is gone and the picker stays")
	off.queue_free()
	Edition.siege = true
	await process_frame
	return int(bad > 0)


func test_credits() -> int:
	var g = Garage.new()
	root.add_child(g)
	g.open(Sim.DEFAULT_LOADOUT)
	g.open_credits()
	var all := " ".join(texts(g.credits))
	var bad := 0
	for name in ["Kenney", "Gregor Quendel", "Nocturnal_Vanguard", "CC BY 4.0", "CC0"]:
		bad += ensure(all.contains(name), "credits show " + name)
	var lic := FileAccess.get_file_as_string("res://assets/sounds/LICENSE.txt")
	for c in Garage.CREDITS:
		bad += ensure(lic.contains(c[0]), "%s is in LICENSE.txt" % c[0])
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	g._unhandled_key_input(esc)
	bad += ensure(g.credits == null, "Esc closes the credits")
	for k in KEYS:
		bad += ensure(I18n.STRINGS.en.has(k) and I18n.STRINGS.es.has(k), "%s exists in en and es" % k)
	g.queue_free()
	await process_frame
	return int(bad > 0)


func test_files() -> int:
	var cfg := FileAccess.get_file_as_string("res://export_presets.cfg")
	var i := cfg.find('name="Mech Duel (Steam)"')
	var bad := ensure(i >= 0 and cfg.substr(i, 300).contains('custom_features="steam"'), "the Steam preset sets the steam feature")
	bad += ensure(cfg.substr(i, 600).contains("src/siege*.gd"), "the Steam preset leaves the siege scripts out")
	var dir := DirAccess.open("res://src")
	for f in dir.get_files():
		if f.ends_with(".gd.uid"):
			bad += ensure(FileAccess.file_exists("res://src/" + f.trim_suffix(".uid")), "%s has its script" % f)
	return int(bad > 0)
