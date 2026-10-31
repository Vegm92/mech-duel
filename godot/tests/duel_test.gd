extends SceneTree

const Sim = preload("res://src/sim.gd")
const Garage = preload("res://src/garage.gd")
const Seats = preload("res://src/seats.gd")
const Menu = preload("res://src/menu.gd")
const Edition = preload("res://src/edition.gd")
const I18n = preload("res://src/i18n.gd")

const SAVE := "user://loadout.cfg"
const KEYS := ["fmtLabel", "fmt_1v1", "fmt_ffa", "fmt_2v2", "whoPlayer", "seatsTitle", "seatKb", "seatPad", "seatBot", "seatFree", "seatsHint", "seatsNeed", "creditsBtn", "creditsTitle", "creditsSound", "creditsBack", "creditsKenney", "creditsQuendel", "creditsNocturnal", "seatMine", "seatBuild", "seatTeamA", "seatTeamB", "gameTitle", "menuPick", "menu_solo", "menu_coop", "menu_versus", "menu_garage", "menu_quit", "menuSub_solo", "menuSub_coop", "menuSub_versus", "menuSub_garage", "menuSub_siege", "seatsJoin", "seatsNeed2", "garageDone"]

var failed := 0
var filter := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var at := args.find("--filter")
	if at >= 0 and at + 1 < args.size():
		filter = args[at + 1]
	I18n.setup()
	await run("the_format_is_picked_on_the_seat_screen_and_the_match_follows_it", test_picker)
	await run("the_format_is_saved_with_the_loadout", test_saved_format)
	await run("seats_join_leave_and_start", test_seats)
	await run("a_seat_picks_a_build_with_keys_pad_and_stick_and_remembers_it", test_build_pick)
	await run("a_picked_build_reaches_the_match_and_bots_keep_the_old_rules", test_pick_in_match)
	await run("in_2v2_humans_pick_teams_and_bots_fill_to_two_against_two", test_teams)
	await run("two_local_humans_read_their_own_pads_and_aim_with_no_assist", test_two_humans)
	await run("the_camera_frames_every_local_human_and_never_rotates", test_camera)
	await run("the_camera_frames_the_living_foe_not_a_dead_mech_1", test_camera_follows_the_living)
	await run("a_full_duel_runs_with_siege_off", test_siege_off)
	await run("the_menu_offers_the_modes_and_siege_only_when_on", test_menu)
	await run("solo_coop_and_versus_set_the_seats_and_models", test_modes)
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
	var m = await duel("1v1")
	m.autopilot = true
	var bad := 0
	for fmt in ["ffa", "2v2", "1v1"]:
		m.open_seats("solo")
		m.seats.set_format(fmt)
		bad += ensure(m.seats.fmt == fmt and m.seats.count == Sim.FORMATS[fmt].size(), "the seat screen picks %s" % fmt)
		m.seats.go()
		await physics_frame
		bad += ensure(m.format_arg == fmt, "the match takes the picked format")
		var teams: Array = m.state.mechs.map(func(x): return x.team)
		var want: Array = [0, 0, 1, 1] if fmt == "2v2" else Sim.FORMATS[fmt]
		bad += ensure(teams == want, "FIGHT in %s builds the teams %s, got %s" % [fmt, want, teams])
	m.queue_free()
	var s = Seats.new()
	root.add_child(s)
	s.open(["kb"], "1v1")
	await process_frame
	var labels := texts(s.root)
	bad += ensure(labels.has("1V1") and labels.has("FFA") and labels.has("2V2"), "the three formats are on screen")
	s._input(key(KEY_TAB))
	bad += ensure(s.fmt == "ffa", "Tab goes to the next format")
	s._input(joy(JOY_BUTTON_LEFT_SHOULDER, 0))
	bad += ensure(s.fmt == "1v1", "LB goes back one")
	s.set_format("nonsense")
	bad += ensure(s.fmt == "1v1", "an unknown format is ignored")
	s.queue_free()
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
	s.confirmed.connect(func(list, picks): sent.append(list))
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


func test_camera_follows_the_living() -> int:
	var bad := 0
	for fmt in ["ffa", "2v2"]:
		var m = await duel(fmt, ["kb"])
		var teams := [0, 1, 0, 1] if fmt == "2v2" else [0, 1, 2, 3]
		var xs := [20.0, 24.0, 28.0, 90.0]
		for i in 4:
			m.state.mechs[i].team = teams[i]
			m.state.mechs[i].x = xs[i]
			m.state.mechs[i].y = 30.0
		m.state.mechs[1].ko = true
		if fmt == "ffa":
			m.state.mechs[2].ko = true
		var pts: Array = m.frame_points()
		bad += ensure(pts.has(Vector3(90, 0, 30)), fmt + ": the last living foe is framed")
		bad += ensure(not pts.has(Vector3(24, 0, 30)), fmt + ": the dead mech 1 is not framed")
		m.state.mechs[3].ko = true
		bad += ensure(m.frame_points() == [Vector3(20, 0, 30)], fmt + ": no foe alive frames only the human")
		m.queue_free()
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


func test_menu() -> int:
	var menu = Menu.new()
	root.add_child(menu)
	var got := []
	menu.picked.connect(func(m): got.append(m))
	menu.open()
	await process_frame
	var labels := texts(menu.root)
	var bad := 0
	for k in ["menu_solo", "menu_coop", "menu_versus", "menu_garage", "siegeBtn"]:
		bad += ensure(labels.has(menu.tr(k)), "with siege on the menu has " + k)
	bad += ensure(not labels.any(func(t): return t.to_upper().contains("ONLINE")), "there is no ONLINE button")
	menu.buttons[2].pressed.emit()
	bad += ensure(got == ["versus"] and not menu.visible, "a click picks the mode and hides the menu")
	Edition.siege = false
	menu.open()
	await process_frame
	labels = texts(menu.root)
	bad += ensure(not labels.has(menu.tr("siegeBtn")) and labels.has(menu.tr("menu_solo")) and menu.buttons.size() == 5, "with siege off the siege entry is gone")
	Edition.siege = true
	menu.queue_free()
	var m = await duel("1v1")
	m.autopilot = true
	m.to_menu()
	m.menu.buttons[3].pressed.emit()
	bad += ensure(m.garage.visible and not m.menu.visible, "GARAGE opens the garage")
	m.garage.go()
	await physics_frame
	m.to_menu()
	m.menu.buttons[0].pressed.emit()
	bad += ensure(m.seats.visible and m.seats.mode == "solo" and not m.menu.visible, "SOLO opens the seat screen")
	m.seats._input(key(KEY_ESCAPE))
	bad += ensure(m.menu.visible and not m.seats.visible, "Esc on the seat screen goes back to the menu")
	m.queue_free()
	await process_frame
	return int(bad > 0)


func test_modes() -> int:
	var m = await duel("1v1")
	m.autopilot = true
	var bad := 0
	m.open_seats("solo")
	var s = m.seats
	bad += ensure(s.list == ["kb"] and s.cap() == 1, "solo seats one human")
	s.join(3)
	bad += ensure(s.list == ["kb"], "and nobody else can join")
	bad += ensure(s.bots.size() == 4 and s.views[1].visible and s.views[0].visible and not s.views[2].visible, "models for the human and the bot, none for a closed slot")
	var before: String = s.shown[0]
	s.cycle("kb", 1)
	bad += ensure(s.shown[0] != before, "changing the build updates the model")
	s.set_format("ffa")
	bad += ensure(s.views[3].visible and s.shown[3] != "", "in ffa all four cards have a model")
	m.open_seats("coop")
	bad += ensure(s.fmt == "2v2" and s.formats() == ["2v2"], "co-op is 2v2 only")
	s.set_format("ffa")
	bad += ensure(s.fmt == "2v2", "co-op refuses other formats")
	s.join(3)
	s.join(4)
	bad += ensure(s.list == ["kb", 3] and s.picks["kb"].team == 0 and s.picks[3].team == 0, "co-op seats two humans, both on team A")
	s.set_team(3, 1)
	bad += ensure(s.picks[3].team == 0, "and they cannot switch")
	s.go()
	await physics_frame
	bad += ensure(m.state.mechs.map(func(x): return x.team) == [0, 0, 1, 1] and m.locals == ["kb", 3], "co-op: both humans on one team against two bots")
	m.open_seats("versus")
	var sent := []
	s.confirmed.connect(func(l, p): sent.append(l))
	s.go()
	bad += ensure(sent.is_empty() and s.warn == "seatsNeed2" and s.visible, "versus will not start with one human")
	s.join(3)
	bad += ensure(s.picks["kb"].team != s.picks[3].team, "versus splits the humans between teams")
	s.set_format("ffa")
	s.join(4)
	s.join(5)
	s.set_format("1v1")
	bad += ensure(s.list == ["kb", 3], "going back to 1v1 keeps the first two humans")
	s.go()
	await physics_frame
	bad += ensure(sent == [["kb", 3]] and m.state.mechs.size() == 2 and m.locals == ["kb", 3], "versus 1v1 with two humans starts")
	m.queue_free()
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


func key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	return e


func tilt(device: int, a: JoyAxis, v: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.device = device
	e.axis = a
	e.axis_value = v
	return e


func test_build_pick() -> int:
	var s = Seats.new()
	root.add_child(s)
	s.open(["kb", 3], "1v1")
	var sets: Array = Sim.SETS.keys()
	var bad := ensure(s.picks["kb"].set == "" and s.picks[3].set == sets[1], "the first seat starts on MY BUILD, the next on a set")
	s._input(key(KEY_D))
	bad += ensure(s.picks["kb"].set == sets[0], "D moves the keyboard seat to the first set")
	s._input(key(KEY_LEFT))
	s._input(key(KEY_LEFT))
	bad += ensure(s.picks["kb"].set == sets[sets.size() - 1], "left wraps round to the last set")
	s._input(joy(JOY_BUTTON_DPAD_RIGHT, 3))
	bad += ensure(s.picks[3].set == sets[2], "the d-pad of pad 3 moves pad 3 only")
	s._input(tilt(3, JOY_AXIS_LEFT_X, 1.0))
	s._input(tilt(3, JOY_AXIS_LEFT_X, 1.0))
	bad += ensure(s.picks[3].set == sets[3], "a held stick tilt moves one step, not one per event")
	s._input(tilt(3, JOY_AXIS_LEFT_X, 0.0))
	s._input(tilt(3, JOY_AXIS_LEFT_X, -1.0))
	bad += ensure(s.picks[3].set == sets[2], "letting go and tilting back moves again")
	await process_frame
	var labels := texts(s.root)
	bad += ensure(labels.has(s.tr("set_" + sets[2])) and labels.has(s.tr("seatMine")) == false, "the card shows the set name")
	bad += ensure(labels.any(func(t): return t.contains(s.tr("u_" + Sim.ult_of(Sim.SETS[sets[2]])))), "and its R skill")
	s.leave(3)
	s.join(3)
	bad += ensure(s.picks[3].set == sets[2], "a pad remembers its last pick when it joins again")
	s.queue_free()
	await process_frame
	return int(bad > 0)


func test_pick_in_match() -> int:
	var m = await duel("1v1", ["kb", 3])
	var picks := [{"set": "", "team": 0}, {"set": "sniper", "team": 1}]
	m.autopilot = true
	m.pending = m.loadout
	m.seated(["kb", 3], picks)
	await physics_frame
	var bad := ensure(m.state.mechs[1].loadout.left == Sim.SETS.sniper.left and m.state.mechs[1].loadout.core == Sim.SETS.sniper.core, "the second human fights with the picked set")
	bad += ensure(m.state.mechs[0].loadout.head == m.loadout.head and m.state.mechs[0].loadout.core == m.loadout.core, "MY BUILD is the garage loadout")
	m.seated(["kb"], [{"set": "tank", "team": 0}])
	await physics_frame
	bad += ensure(m.state.mechs[0].loadout.core == Sim.SETS.tank.core, "the first seat can take a set too")
	bad += ensure(m.state.mechs.size() == 2 and m.locals.size() == 1 and m.state.mechs[1].loadout.core != Sim.SETS.tank.core, "the other mech stays a bot with its own build")
	m.queue_free()
	await process_frame
	return int(bad > 0)


func teams_for(picks: Array) -> Array:
	var m = await duel("2v2")
	m.autopilot = true
	m.pending = m.loadout
	m.seated(range(picks.size()).map(func(i): return "kb" if i == 0 else i), picks)
	await physics_frame
	var out: Array = m.state.mechs.map(func(x): return x.team)
	m.queue_free()
	await process_frame
	return out


func test_teams() -> int:
	var s = Seats.new()
	root.add_child(s)
	s.open(["kb", 3], "2v2")
	var bad := ensure(s.picks["kb"].team == 0 and s.picks[3].team == 1, "seats start on alternate teams")
	s._input(joy(JOY_BUTTON_DPAD_UP, 3))
	bad += ensure(s.picks[3].team == 0 and s.humans_on(0) == 2, "up on pad 3 moves it to team A, two friends together")
	s.join(4)
	bad += ensure(s.picks[4].team == 1, "a third human lands on the team with room")
	s._input(joy(JOY_BUTTON_DPAD_UP, 4))
	bad += ensure(s.picks[4].team == 1, "a full team refuses a third human")
	s._input(key(KEY_S))
	bad += ensure(s.picks["kb"].team == 1 and s.humans_on(1) == 2, "S moves the keyboard seat to team B")
	var plain = Seats.new()
	root.add_child(plain)
	plain.open(["kb", 3], "ffa")
	plain._input(joy(JOY_BUTTON_DPAD_DOWN, 3))
	bad += ensure(plain.picks[3].team == 1 and plain.picks["kb"].team == 0, "teams stay as seated outside 2v2")
	plain.queue_free()
	s.queue_free()
	var ab := [{"set": "", "team": 0}, {"set": "tank", "team": 0}]
	var a: Array = await teams_for(ab)
	bad += ensure(a == [0, 0, 1, 1], "two humans on team A: the bots are team B, got %s" % [a])
	var b: Array = await teams_for([{"set": "", "team": 1}, {"set": "tank", "team": 1}])
	bad += ensure(b == [1, 1, 0, 0], "two humans on team B: the bots are team A, got %s" % [b])
	var c: Array = await teams_for([{"set": "", "team": 0}, {"set": "tank", "team": 1}])
	bad += ensure(c == [0, 1, 0, 1], "one each side: a bot fills each team, got %s" % [c])
	var d: Array = await teams_for([{"set": "", "team": 1}])
	bad += ensure(d.count(0) == 2 and d.count(1) == 2 and d[0] == 1, "one human on team B still gets 2 v 2, got %s" % [d])
	await process_frame
	return int(bad > 0)
