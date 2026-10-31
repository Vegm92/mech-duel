extends SceneTree

const Sim = preload("res://src/sim.gd")
const Look = preload("res://src/look.gd")

const KEYS := ["nameMech0", "nameMech1", "nameMech2", "nameMech3", "whoYou", "whoBot", "barLarm", "barHead", "barCore", "barRarm", "barLegs", "jam", "heatN", "kLmb", "kRmb", "kcTag", "kcSkipOr", "backGarage", "keyEnter", "soundTitle", "radialShop", "radialNote", "radialHint", "siegeWave", "siegeBest", "siegeTiers", "siegeRecall", "siegeCrate", "siegeShop", "siegeBuildHint", "radialSquare", "radialSquareNote", "radialGate", "radialGateNote", "shop_turret", "shop_gate", "shop_rebuild", "siegeKeys", "siegeLost", "siegeHeld", "capQ", "capE", "capR", "capSpace", "capLt", "capRt", "capLb", "capRb", "capL3", "capR3", "slotShield", "round", "go", "ko", "timeUp", "victory", "defeat", "mPaused", "mResume", "mRestart", "mGarage", "closing", "ventsOn", "healReady", "overheat"]

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
	await run("player_strips_hug_the_top_and_bottom_edges_and_stay_small", test_strips)
	await run("each_seat_shows_its_own_device_labels_and_bots_show_none", test_labels)
	await run("each_wheel_sells_only_its_own_things_and_dims_what_the_fund_cannot_pay", test_wheels)
	await run("a_four_player_siege_shows_allies_and_keeps_its_arrows_clear_of_the_hud", test_siege)
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


func start_humans(fmt: String, n: int):
	var m = load("res://main.tscn").instantiate()
	m.autopilot = true
	m.seed_arg = 3
	m.format_arg = fmt
	m.humans_arg = n
	root.add_child(m)
	await process_frame
	await process_frame
	return m


func test_strips() -> int:
	var hud = load("res://src/hud.gd").new()
	var old_area := 580.0 * 0.7 * 180.0 * 0.7
	var band := 72.0
	var bad := 0
	for size in [Vector2(1280, 720), Vector2(1920, 1080)]:
		var cx: float = size.x / 2.0
		var clock := Rect2(cx - 210.0, 0, 420, 90)
		for n in [2, 3, 4]:
			var rects: Array = hud.strip_rects(size, n)
			var area := 0.0
			bad += ensure(rects.size() == n, "%d strips for %d mechs" % [rects.size(), n])
			for i in rects.size():
				var r: Rect2 = rects[i]
				area += r.get_area()
				bad += ensure(r.end.y <= band or r.position.y >= size.y - band, "strip %d of %d hugs the top or bottom edge at %s" % [i, n, size])
				bad += ensure(Rect2(Vector2.ZERO, size).encloses(r), "strip %d stays on screen at %s" % [i, size])
				bad += ensure(not r.intersects(clock), "strip %d keeps clear of the clock and score at %s" % [i, size])
				for j in i:
					bad += ensure(not r.intersects(rects[j]), "strips %d and %d do not overlap" % [i, j])
			bad += ensure(area <= 0.25 * old_area * n, "%d strips take %d px, at most a quarter of the old %d" % [n, area, 0.25 * old_area * n])
	hud.free()
	var m = await start_humans("ffa", 4)
	for i in 4:
		m._physics_process(1.0 / Sim.TICKS)
	await process_frame
	bad += ensure(m.state.mechs.size() == 4 and m.hud.humans == 4, "four humans in an FFA")
	m.queue_free()
	return bad


func test_labels() -> int:
	var m = await start_humans("ffa", 3)
	TranslationServer.set_locale("en")
	var hud = m.hud
	hud.humans = 3
	var bad := ensure(m.locals == ["kb", 1, 2], "seats are the keyboard and two pads, got %s" % [m.locals])
	var keyboard := {"left": "LMB", "right": "RMB", "shield": "Q", "hook": "E", "dash": "SPACE", "ult": "R"}
	var gamepad := {"left": "LT", "right": "RT", "shield": "RB", "hook": "L3", "dash": "LB", "ult": "R3"}
	for k in keyboard:
		bad += ensure(hud.cap(0, k) == keyboard[k], "keyboard seat %s reads %s, got %s" % [k, keyboard[k], hud.cap(0, k)])
		for seat in [1, 2]:
			bad += ensure(hud.cap(seat, k) == gamepad[k], "pad seat %d %s reads %s, got %s" % [seat, k, gamepad[k], hud.cap(seat, k)])
		bad += ensure(hud.cap(3, k) == "", "the bot has no label for %s" % k)
	m.aims[0].on_pad = true
	bad += ensure(hud.cap(0, "left") == "LT", "the keyboard seat shows pad names once its owner picks up a pad")
	m.aims[0].on_pad = false
	TranslationServer.set_locale("es")
	bad += ensure(hud.cap(0, "left") == "CLIC I" and hud.cap(1, "left") == "LT", "labels follow the language, pad names stay")
	TranslationServer.set_locale("en")
	m.queue_free()
	var duo = await start_humans("1v1", 2)
	for i in 3:
		await process_frame
	bad += ensure(duo.hud.humans == 2 and duo.hud.cap(1, "dash") == "LB", "a two-human 1v1 labels both seats")
	duo.queue_free()
	return bad


func start_siege(n: int):
	var m = load("res://main.tscn").instantiate()
	m.autopilot = true
	m.seed_arg = 3
	m.siege = true
	m.team_n = n
	root.add_child(m)
	await process_frame
	return m


func test_siege() -> int:
	var m = await start_siege(4)
	var hud = m.hud
	var bad := ensure(hud.state.has("siege") and hud.state.siege.team == 4, "a siege with 4 players")
	bad += ensure(hud.ally_status(1) == "alive", "an ally in the fight is alive")
	m.state.mechs[2].ko = true
	bad += ensure(hud.ally_status(2) == "down", "a knocked out ally is down")
	m.state.siege.recall.append({"player": 3, "t": 10, "max": 100})
	bad += ensure(hud.ally_status(3) == "recall", "an ally holding a recall is recalling")
	for i in 3:
		await process_frame
	var size := Vector2(1280, 720)
	var box: Rect2 = hud.siege_box(size)
	var colors := []
	for i in 4:
		colors.append(m.view.mark_color(m.state.mechs[i]))
	bad += ensure(colors[0] == Look.ARCADE.team[0] and colors.size() == 4 and colors.filter(func(c): return colors.count(c) > 1).is_empty(), "every squad mech gets its own marker color, the human orange")
	hud.calls_bottom = 300.0
	bad += ensure(hud.siege_box(Vector2(1280, 720)).position.y >= 308.0, "edge arrows drop below the calls while a call shows")
	hud.calls_bottom = 0.0
	var reserved := {"ally strip and upgrades": Rect2(16, 16, hud.ROW_W, 450), "skill panel": Rect2(16, size.y - 16 - hud.SIDE.y, hud.SIDE.x, hud.SIDE.y), "wave plate and core bar": Rect2(420, 14, 440, 70)}
	for k in reserved:
		bad += ensure(not box.intersects(reserved[k]), "edge arrows stay clear of the %s" % k)
	m.state.siege.wave.live = false
	box = hud.siege_box(size)
	bad += ensure(not box.intersects(Rect2(size.x - 266, 16, 250, 300)), "edge arrows stay clear of the team shop in the build phase")
	m.queue_free()
	return bad


func ids(menu: Array) -> Array:
	return menu.map(func(e): return e.id)


func test_wheels() -> int:
	var m = await start_siege(1)
	var sg: Dictionary = m.state.siege
	var me: Dictionary = m.state.mechs[0]
	sg.wallets[0] = 1000
	var bad := 0
	var plaza: Array = m.hud.shop_menu(0, "plaza")
	var team: Array = plaza.filter(func(e): return e.id == "team")[0].sub
	bad += ensure(ids(team) == ["ring", "garrison"], "the plaza team wedge sells a core ring and a garrison only, got %s" % [ids(team)])
	bad += ensure(not ids(plaza).has("wall") and not ids(plaza).any(func(i): return i in ["gate", "rebuild", "modules"]), "no module or gate buy in the plaza")
	me.x = sg.pads[1].x
	me.y = sg.pads[1].y
	var square: Array = m.hud.shop_menu(0, "square")
	bad += ensure(ids(square) == ["wall", "mine", "laser", "post", "turret"], "the square wheel sells the five modules, got %s" % [ids(square)])
	bad += ensure(square.all(func(e): return e.enabled), "an empty pad with 1000 in the fund can buy all of them")
	sg.wallets[0] = 100
	square = m.hud.shop_menu(0, "square")
	bad += ensure(square.filter(func(e): return not e.enabled).map(func(e): return e.id) == ["laser", "post", "turret"], "what 100 cannot pay is dimmed")
	sg.wallets[0] = 1000
	me.x = sg.gates[2].x
	me.y = sg.gates[2].y
	sg.gates[2].hp = 100.0
	var gate: Array = m.hud.shop_menu(0, "gate")
	bad += ensure(ids(gate) == ["gate", "rebuild"] and gate[0].enabled and not gate[1].enabled, "a hurt, standing gate can be repaired, not rebuilt")
	m.queue_free()
	return bad


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
