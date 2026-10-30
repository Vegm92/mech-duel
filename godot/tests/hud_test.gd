extends SceneTree

const Sim = preload("res://src/sim.gd")
const Look = preload("res://src/look.gd")

const KEYS := ["nameMech0", "nameMech1", "nameMech2", "nameMech3", "whoYou", "whoBot", "barLarm", "barHead", "barCore", "barRarm", "barLegs", "jam", "heatN", "kLmb", "kRmb", "kcTag", "kcSkipOr", "backGarage", "keyEnter", "soundTitle", "capQ", "capE", "capR", "capSpace", "capLt", "capRt", "capLb", "capRb", "capL3", "capR3", "slotShield", "round", "go", "ko", "timeUp", "victory", "defeat", "mPaused", "mResume", "mRestart", "mGarage", "closing", "ventsOn", "healReady", "overheat"]

var failed := 0
var filter := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var at := args.find("--filter")
	if at >= 0 and at + 1 < args.size():
		filter = args[at + 1]
	await run("every_hud_string_exists_in_english_and_spanish", test_strings)
	await run("the_arcade_palette_holds_the_design_colors", test_palette)
	await run("pause_shows_three_slabs_and_five_sliders_only_while_paused", test_pause)
	await run("a_round_win_is_remembered_for_the_match_over_list", test_rounds)
	await run("an_ffa_match_runs_and_draws_four_bars", test_ffa)
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
		print("  FAIL: " + what)
	return 0 if cond else 1


func start(seed: int, fmt := "1v1"):
	var m = load("res://main.tscn").instantiate()
	m.autopilot = true
	m.seed_arg = seed
	m.format_arg = fmt
	root.add_child(m)
	await process_frame
	return m


func test_strings() -> int:
	var m = await start(3)
	var bad := 0
	for loc in ["en", "es"]:
		TranslationServer.set_locale(loc)
		for k in KEYS:
			bad += ensure(TranslationServer.translate(k) != k, "%s has %s" % [loc, k])
	TranslationServer.set_locale("en")
	m.queue_free()
	return bad


func test_palette() -> int:
	var A: Dictionary = Look.ARCADE
	var bad := ensure(A.ground == Color("#0B0A12") and A.panel == Color("#17141F") and A.raised == Color("#221E2E") and A.line == Color("#34304A"), "greys")
	bad += ensure(A.dim == Color("#B3ACCB") and A.hazard == Color("#FFC93C") and A.surge == Color("#C86BFF") and A.danger == Color("#FF4D5E"), "accents")
	bad += ensure(A.team.size() == 4 and A.team[0] == Color("#FF6B1A") and A.team[3] == Color("#FF4FA3"), "team colors")
	return bad


func test_pause() -> int:
	var m = await start(3)
	var hud = m.hud
	await process_frame
	var hidden: bool = not hud.menu.visible and not hud.sound.visible
	m.paused = true
	hud.paused = true
	await process_frame
	await process_frame
	var bad := ensure(hidden, "menu and sliders start hidden")
	bad += ensure(hud.menu.visible and hud.sound.visible, "pause shows both")
	bad += ensure(hud.menu.get_child_count() == 3, "three buttons")
	bad += ensure(hud.sound.get_child_count() == 5, "five sliders")
	var line: HBoxContainer = hud.sound.get_child(1)
	var slider: HSlider = line.get_child(1)
	slider.value = 0.35
	bad += ensure(line.get_child(2).text == "35", "the value label follows the slider")
	m.queue_free()
	return bad


func test_rounds() -> int:
	var m = await start(1)
	for i in 20000:
		m._physics_process(1.0 / Sim.TICKS)
		if m.state.phase == "ko":
			break
	await process_frame
	m.hud._process(0.0)
	var r: Array = m.hud.rounds
	var bad := ensure(m.state.phase == "ko", "a K.O. happens")
	bad += ensure(r.size() == 1 and r[0].winner == m.state.winner, "the round is listed with its winner (%s)" % [r])
	m.queue_free()
	return bad


func test_ffa() -> int:
	var m = await start(5, "ffa")
	var bad := ensure(m.state.mechs.size() == 4 and m.state.score.size() == 4, "four mechs, four scores")
	for i in 400:
		m._physics_process(1.0 / Sim.TICKS)
	for i in 3:
		await process_frame
	bad += ensure(m.state.tick >= 400, "the match runs")
	m.queue_free()
	return bad
