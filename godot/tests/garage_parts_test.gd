extends SceneTree

const Sim = preload("res://src/sim.gd")
const Mech = preload("res://src/mech.gd")
const PartView = preload("res://src/part_view.gd")
const Garage = preload("res://src/garage.gd")
const Decor = preload("res://src/decor.gd")
const Progress = preload("res://src/progress.gd")

const FLOW := "user://progress_flow_test.cfg"

var failed := 0


func _initialize() -> void:
	await run("every_part_builds_alone_with_a_model", test_every_part_builds_alone_with_a_model)
	await run("garage_previews_on_hover_and_equips_on_click", test_garage_previews_on_hover_and_equips_on_click)
	await run("match_flow_comes_back_to_the_garage", test_match_flow_comes_back_to_the_garage)
	await run("menu_picks_the_mode_and_the_garage_goes_back_to_it", test_menu_picks_the_mode_and_the_garage_goes_back_to_it)
	await run("players_join_and_each_device_drives_its_own_mech", test_players_join_and_each_device_drives_its_own_mech)
	await run("two_players_beat_a_ladder_rival_together_and_each_picks_a_part", test_two_players_beat_a_ladder_rival_together_and_each_picks_a_part)
	await run("siege_setup_starts_a_basic_run_with_allies_and_ends_back_on_the_setup", test_siege_setup_starts_a_basic_run_with_allies_and_ends_back_on_the_setup)
	await run("pad_moves_aims_acts_and_pauses", test_pad_moves_aims_acts_and_pauses)
	await run("garage_works_with_a_pad", test_garage_works_with_a_pad)
	await run("decor_keeps_off_pads_spawns_and_traps", test_decor_keeps_off_pads_spawns_and_traps)
	await run("garage_locks_parts_you_have_not_won", test_garage_locks_parts_you_have_not_won)
	await run("help_blocks_fight_and_esc_goes_back", test_help_blocks_fight_and_esc_goes_back)
	await run("winning_a_match_opens_the_claim_screen_and_a_pick_unlocks_the_part", test_winning_a_match_opens_the_claim_screen_and_a_pick_unlocks_the_part)
	await run("losing_a_match_gives_no_claim", test_losing_a_match_gives_no_claim)
	print("FAILED" if failed else "ALL PASSED")
	quit(1 if failed else 0)


func run(name: String, test: Callable) -> void:
	var t0 := Time.get_ticks_msec()
	var r = await test.call()
	if not r is int or r != 0:
		failed += 1
		print("test failed: " + name)
	else:
		print("test passed: %s (%d ms)" % [name, Time.get_ticks_msec() - t0])


func has_model(slot: String, key: String) -> bool:
	match slot:
		"head":
			return Mech.models("heads").has(key)
		"core":
			return Mech.models("cores").has(key) and Mech.models("light").has("Chest_" + Sim.CORES[key].series)
		"arms":
			return ["_upper_L", "_upper_R", "_fore_L", "_fore_R"].all(func(s): return Mech.models("arms").has(key + s))
		"legs":
			return Mech.models("legs").keys().any(func(n): return n == key or n.begins_with(key + "_"))
		"booster":
			return Mech.models("boosters").has(key)
	return Mech.models("guns").has(key)


func test_every_part_builds_alone_with_a_model() -> int:
	var bad := []
	for slot in Sim.CATALOG:
		for key in Sim.CATALOG[slot]:
			if not has_model(slot, key):
				bad.append("%s/%s has no model" % [slot, key])
				continue
			var m := Mech.new()
			m.build_part(slot, key, 0)
			var box = PartView.bounds(m)
			if box == null or box.size.length() < 0.05:
				bad.append("%s/%s builds empty" % [slot, key])
			m.queue_free()
	for b in bad:
		print("  " + b)
	return int(not bad.is_empty())


func card_at(g, h: Dictionary) -> Vector2:
	for c in g.cards:
		if c[2] == h:
			return c[0].get_global_rect().get_center()
	return Vector2(-1, -1)


func mouse(at: Vector2, click := false) -> void:
	var move := InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	root.push_input(move, true)
	if click:
		for down in [true, false]:
			var b := InputEventMouseButton.new()
			b.button_index = MOUSE_BUTTON_LEFT
			b.pressed = down
			b.position = at
			b.global_position = at
			root.push_input(b, true)
	await process_frame


func test_garage_previews_on_hover_and_equips_on_click() -> int:
	var g = Garage.new()
	root.add_child(g)
	g.open(Sim.DEFAULT_LOADOUT)
	await process_frame
	var demon := {"slot": "head", "key": "demon"}
	await mouse(card_at(g, demon))
	var bad := ensure(g.hover == demon, "hovering the demon card previews it")
	bad += ensure(g.next_lo().head == "demon" and g.loadout.head == "rookie", "hover does not equip")
	await mouse(card_at(g, demon), true)
	bad += ensure(g.loadout.head == "demon", "clicking the demon card equips it")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_TAB
	key.pressed = true
	root.push_input(key)
	await process_frame
	bad += ensure(g.tab == 1, "Tab moves to the core tab")
	g.select_tab(7)
	await process_frame
	await mouse(card_at(g, {"set": "brawler"}), true)
	bad += ensure(g.loadout == Sim.SETS.brawler, "clicking a set equips all of it")
	var sent := []
	g.fight.connect(func(lo): sent.append(lo))
	g.go()
	bad += ensure(sent.size() == 1 and sent[0] == Sim.SETS.brawler, "FIGHT sends the built loadout")
	g.queue_free()
	return int(bad > 0)


func test_match_flow_comes_back_to_the_garage() -> int:
	var m = load("res://main.tscn").instantiate()
	m.autopilot = true
	root.add_child(m)
	await process_frame
	var bad := ensure(not m.garage.visible, "autopilot starts in a match")
	m.state.phase = "over"
	var enter := InputEventKey.new()
	enter.physical_keycode = KEY_ENTER
	enter.pressed = true
	root.push_input(enter)
	await process_frame
	bad += ensure(m.garage.visible, "Enter after the match opens the garage and stays there")
	m.garage.equip({"set": "tank"})
	m.garage.go()
	await physics_frame
	bad += ensure(not m.garage.visible and m.state.mechs[0].loadout == Sim.SETS.tank, "FIGHT starts a match with the built bot")
	m.paused = true
	await process_frame
	await process_frame
	var quit: Button = m.hud.menu.get_child(2)
	await mouse(quit.get_global_rect().get_center(), true)
	bad += ensure(m.garage.visible and m.garage.loadout == Sim.SETS.tank, "Quit to garage keeps your bot")
	m.queue_free()
	return int(bad > 0)


func test_menu_picks_the_mode_and_the_garage_goes_back_to_it() -> int:
	var m = load("res://main.tscn").instantiate()
	m.autopilot = true
	root.add_child(m)
	await process_frame
	m.state.phase = "over"
	m.to_menu()
	await process_frame
	var bad := ensure(m.menu.visible and not m.garage.visible and not m.view.visible, "the menu shows alone")
	m.menu.choose("siege")
	bad += ensure(m.menu.page == "siege" and m.menu.siege.start == "basic", "Core Siege opens its setup: a basic start by default")
	m.menu.set_opt("start", "garage", 0)
	m.menu.go_siege()
	await process_frame
	bad += ensure(m.garage.visible and not m.menu.visible and m.garage.mode == "siege", "a garage start opens the garage in siege mode")
	bad += ensure(m.garage.last, "one player: one garage turn")
	m.garage.go()
	await physics_frame
	await physics_frame
	bad += ensure(m.siege and m.state.has("siege") and m.siege_view != null, "the garage starts a siege run")
	bad += ensure(m.view.visible and not m.garage.visible, "the siege view shows")
	m.state.phase = "over"
	m.to_garage()
	await process_frame
	m.garage.go_back()
	await process_frame
	bad += ensure(m.menu.visible and not m.garage.visible and m.menu.page == "siege", "Back goes to the siege setup")
	m.menu.choose("duel")
	bad += ensure(m.menu.page == "duel" and m.menu.setup.slots.size() == 2 and m.menu.setup.slots[1].who == -1, "Duel opens its setup: you against a bot")
	m.menu.go_duel()
	await process_frame
	bad += ensure(m.garage.visible and m.garage.mode == "duel" and m.garage.last, "CONTINUE opens the garage")
	m.garage.go()
	await physics_frame
	await physics_frame
	bad += ensure(not m.siege and not m.state.has("siege") and m.siege_view == null, "the garage starts a duel")
	m.queue_free()
	return int(bad > 0)


func test_two_players_beat_a_ladder_rival_together_and_each_picks_a_part() -> int:
	wipe_flow()
	var p2 := FLOW.get_basename() + "_p2.cfg"
	if FileAccess.file_exists(p2):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p2))
	var m = load("res://main.tscn").instantiate()
	m.autopilot = true
	m.progress_arg = FLOW
	root.add_child(m)
	await process_frame
	m.state.phase = "over"
	m.menu.players = [-1, 0]
	m.menu.choose("duel")
	m.menu.set_format("2v2")
	m.menu.cycle_level(2)
	var s: Dictionary = m.menu.setup
	var bad := ensure(s.slots.map(func(sl): return sl.who) == [0, 1, -1, -1] and s.slots[2].level == "hard" and m.menu.pve(s) and s.ladder, "2 VS 2 puts both players on one team against two bots; the ladder is on")
	m.menu.go_duel()
	await process_frame
	m.garage.go()
	m.garage.go()
	await physics_frame
	bad += ensure(m.state.mechs.map(func(x): return x.team) == [0, 0, 1, 1] and m.rival_key == "duelist" and m.rival_id == 2 and m.hud.levels[2] == "hard", "the first bot is the ladder rival, at the level picked for its slot")
	bad += ensure(m.prog(1).path == p2 and m.prog(0) == m.progress and m.garage.progress == m.prog(1), "P2 has their own save")
	m.broke = ["legs"]
	m.foe_ko = true
	m.state.score = [3, 1]
	m.state.phase = "over"
	await physics_frame
	await physics_frame
	bad += ensure(m.claim.visible and m.claimer == 0 and m.claims == [1], "P1 picks first, P2 waits")
	m.claim.pick(0)
	bad += ensure(m.claim.visible and m.claimer == 1, "then P2 picks")
	m.claim.pick(0)
	bad += ensure(m.garage.visible and m.progress.beaten.get("duelist", 0) == 1 and m.prog(1).beaten.get("duelist", 0) == 1 and FileAccess.file_exists(p2), "both beat the rival and both saves are written")
	m.queue_free()
	wipe_flow()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(p2))
	await process_frame
	return int(bad > 0)


func test_siege_setup_starts_a_basic_run_with_allies_and_ends_back_on_the_setup() -> int:
	var m = load("res://main.tscn").instantiate()
	m.autopilot = true
	root.add_child(m)
	await process_frame
	m.state.phase = "over"
	m.menu.players = [-1, 0]
	m.menu.siege = {"allies": 3}
	m.menu.choose("siege")
	var bad := ensure(m.menu.siege.allies == 2, "2 players: at most 2 AI allies")
	m.menu.set_opt("goal", 20, 0)
	m.menu.set_opt("rest", 15, 0)
	m.menu.set_opt("allies", 1, 0)
	m.menu.go_siege()
	await physics_frame
	var sg: Dictionary = m.state.siege
	bad += ensure(m.siege and not m.garage.visible and not m.menu.visible, "a basic start skips the garage")
	bad += ensure(sg.team == 3 and sg.goal == 20 and sg.rest == 15 * m.Sim.TICKS, "2 players + 1 ally, 20 waves, 15 s breaks")
	var basic: Dictionary = m.Sim.normalize(m.Sim.DEFAULT_LOADOUT)
	bad += ensure(m.state.mechs[0].loadout == basic and m.state.mechs[1].loadout == basic, "every player starts on the basic mech")
	sg.won = true
	m.state.phase = "over"
	await physics_frame
	m.after_match()
	await process_frame
	bad += ensure(m.menu.visible and m.menu.page == "siege", "after a basic run you land on the siege setup")
	m.queue_free()
	await process_frame
	return int(bad > 0)


func key_event(k: Key, down := true) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.pressed = down
	return e


func pad_event(dev: int, b: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.device = dev
	e.button_index = b
	e.pressed = true
	return e


func test_players_join_and_each_device_drives_its_own_mech() -> int:
	var m = load("res://main.tscn").instantiate()
	m.autopilot = true
	root.add_child(m)
	await process_frame
	m.state.phase = "over"
	m.menu.players.clear()
	m.to_menu()
	await process_frame
	m.menu._input(key_event(KEY_ENTER))
	m.menu._input(pad_event(0, JOY_BUTTON_A))
	m.menu._input(pad_event(1, JOY_BUTTON_A))
	m.menu._input(pad_event(1, JOY_BUTTON_B))
	var bad := ensure(m.menu.players == [-1, 0] and m.menu.page == "players", "Enter and pad A join, pad B leaves")
	m.menu._input(pad_event(0, JOY_BUTTON_A))
	bad += ensure(m.menu.page == "modes", "A from a joined pad goes on to the modes")
	m.menu.choose("duel")
	bad += ensure(m.menu.setup.format == "1v1" and m.menu.setup.slots.map(func(sl): return sl.who) == [0, 1] and not m.menu.pve(m.menu.setup), "two players default to P1 against P2, no ladder")
	m.menu.go_duel()
	await process_frame
	bad += ensure(m.garage.who == m.tr("playerN").format({"n": 1}) and not m.garage.last, "P1 builds first")
	m.garage.equip({"set": "tank"})
	m.garage.go()
	await process_frame
	bad += ensure(m.garage.visible and m.garage.who == m.tr("playerN").format({"n": 2}) and m.garage.last, "then P2 builds")
	m.garage.go()
	await physics_frame
	bad += ensure(m.state.mechs[0].loadout == Sim.SETS.tank and m.state.mechs[1].loadout != Sim.SETS.tank, "each player fights with their own mech")
	m.autopilot = false
	m.frozen = true
	bad += ensure(m.state.mechs.size() == 2 and m.rival_key == "" and m.hud.humans == 2, "two players fight each other, no ladder rival")
	Input.parse_input_event(key_event(KEY_D))
	pad(JOY_BUTTON_LEFT_SHOULDER, true)
	await settle()
	var p1: Dictionary = m.player_input(0)
	var p2: Dictionary = m.player_input(1)
	bad += ensure(p1.mx == 1.0 and not p1.dash and p2.mx == 0.0 and p2.dash, "the keyboard drives P1 only, pad 0 drives P2 only")
	Input.parse_input_event(key_event(KEY_D, false))
	pad(JOY_BUTTON_LEFT_SHOULDER, false)
	m.duel = {}
	m.set_players([-1, 0, 1])
	m.new_match()
	bad += ensure(m.state.mechs.size() == 4 and m.state.mechs[3].team == 3 and m.brains.size() == 4, "three players play a free-for-all with one bot")
	m.siege = true
	m.make_view()
	m.new_match()
	bad += ensure(m.state.siege.team == 3 and m.group().size() == 3 and m.state.siege.owned.size() >= 3, "Core Siege gives each of the three players a mech")
	m.queue_free()
	await process_frame
	return int(bad > 0)


func axis(a: JoyAxis, v: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.device = 0
	e.axis = a
	e.axis_value = v
	Input.parse_input_event(e)


func pad(b: JoyButton, down: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.device = 0
	e.button_index = b
	e.pressed = down
	Input.parse_input_event(e)


func settle() -> void:
	for i in 2:
		await physics_frame
	await process_frame
	await process_frame


func press(b: JoyButton) -> void:
	pad(b, true)
	await settle()
	pad(b, false)
	await settle()


func test_pad_moves_aims_acts_and_pauses() -> int:
	var m = load("res://main.tscn").instantiate()
	m.autopilot = true
	root.add_child(m)
	await process_frame
	m.autopilot = false
	m.frozen = true
	axis(JOY_AXIS_LEFT_X, 0.1)
	axis(JOY_AXIS_RIGHT_X, 1.0)
	for i in 4:
		await settle()
	var bad := ensure(m.on_pad and m.reach == Vector2(16, 0) and m.hud.pad, "full right stick aims 16 m right and the HUD shows pad buttons")
	bad += ensure(m.player_input().mx == 0.0, "left stick drift inside the dead zone does not walk")
	axis(JOY_AXIS_RIGHT_X, 0.5)
	await settle()
	bad += ensure(m.reach == Vector2(8, 0), "half tilt aims half as far")
	axis(JOY_AXIS_RIGHT_X, 0.0)
	await settle()
	bad += ensure(m.reach == Vector2(16, 0), "letting go keeps the aim from before the stick sprang back")
	axis(JOY_AXIS_LEFT_X, 1.0)
	axis(JOY_AXIS_TRIGGER_RIGHT, 0.9)
	pad(JOY_BUTTON_LEFT_SHOULDER, true)
	pad(JOY_BUTTON_RIGHT_STICK, true)
	await settle()
	var inp: Dictionary = m.player_input()
	bad += ensure(inp.mx == 1.0 and inp.right and inp.dash and inp.ult and not inp.left and not inp.hook, "left stick walks, RT fires the right hand, LB dashes, R3 casts the R skill")
	pad(JOY_BUTTON_LEFT_SHOULDER, false)
	pad(JOY_BUTTON_RIGHT_STICK, false)
	axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	await settle()
	m.player_input()
	await press(JOY_BUTTON_LEFT_STICK)
	inp = m.player_input()
	bad += ensure(inp.hook and not inp.dash and not inp.ult, "a quick L3 click still throws the hook")
	var move := InputEventMouseMotion.new()
	move.relative = Vector2(5, 0)
	root.push_input(move, true)
	await settle()
	bad += ensure(not m.on_pad and not m.hud.pad, "moving the mouse hands aim back to the mouse")
	await press(JOY_BUTTON_START)
	bad += ensure(m.paused and get_root().gui_get_focus_owner() == m.hud.menu.get_child(0), "Start pauses with Resume picked")
	await press(JOY_BUTTON_DPAD_DOWN)
	await press(JOY_BUTTON_DPAD_DOWN)
	await press(JOY_BUTTON_A)
	bad += ensure(m.garage.visible, "D-pad down twice and A quits to the garage")
	axis(JOY_AXIS_LEFT_X, 0.0)
	await process_frame
	m.queue_free()
	await process_frame
	return int(bad > 0)


func focused_card(g):
	for c in g.cards:
		if c[0] == get_root().gui_get_focus_owner():
			return c[2]
	return null


func test_garage_works_with_a_pad() -> int:
	var g = Garage.new()
	root.add_child(g)
	g.open(Sim.DEFAULT_LOADOUT)
	await process_frame
	var sent := []
	g.fight.connect(func(lo): sent.append(lo))
	var bad := ensure(not g.pad and focused_card(g) == null, "with the mouse no card has the pad cursor")
	await press(JOY_BUTTON_DPAD_DOWN)
	var h = focused_card(g)
	bad += ensure(g.pad and h != null and h.slot == "head" and h.key != "rookie", "the first D-pad press shows the cursor and moves it off the equipped head")
	bad += ensure(g.hover == h and g.next_lo().head == h.key and g.loadout.head == "rookie", "the card under the cursor previews like a hover, nothing equipped yet")
	await press(JOY_BUTTON_A)
	bad += ensure(g.loadout.head == h.key, "A equips the card under the cursor")
	await press(JOY_BUTTON_RIGHT_SHOULDER)
	bad += ensure(g.tab == 1 and focused_card(g) == {"slot": "core", "key": g.loadout.core}, "RB moves to the core tab with the cursor on the equipped core")
	await press(JOY_BUTTON_LEFT_SHOULDER)
	await press(JOY_BUTTON_LEFT_SHOULDER)
	bad += ensure(g.tab == 7 and focused_card(g) != null, "LB goes back and wraps around to the sets tab")
	await press(JOY_BUTTON_START)
	bad += ensure(sent.size() == 1 and sent[0].head == h.key, "Start sends the built bot to FIGHT")
	await mouse(Vector2(5, 5))
	bad += ensure(not g.pad and focused_card(g) == null, "moving the mouse hides the pad cursor")
	g.queue_free()
	await process_frame
	return int(bad > 0)


func test_garage_locks_parts_you_have_not_won() -> int:
	var p := Progress.new()
	p.unlock_all = false
	p.path = ""
	var g = Garage.new()
	g.progress = p
	root.add_child(g)
	g.open(Sim.DEFAULT_LOADOUT)
	await process_frame
	var demon := {"slot": "head", "key": "demon"}
	await mouse(card_at(g, demon), true)
	var bad := ensure(g.loadout.head == "rookie" and g.locked(demon), "clicking a locked part does not equip it")
	g.select_tab(7)
	await process_frame
	await mouse(card_at(g, {"set": "brawler"}), true)
	bad += ensure(g.loadout == Sim.DEFAULT_LOADOUT, "clicking a set with locked parts does nothing")
	p.claim("head", "demon")
	g.select_tab(0)
	await process_frame
	await mouse(card_at(g, demon), true)
	bad += ensure(g.loadout.head == "demon" and not g.locked(demon), "once claimed the part equips")
	g.queue_free()
	return int(bad > 0)


func test_help_blocks_fight_and_esc_goes_back() -> int:
	var g = Garage.new()
	g.progress = Progress.new()
	root.add_child(g)
	g.open(Sim.DEFAULT_LOADOUT)
	await process_frame
	var fights := [0]
	g.fight.connect(func(_lo): fights[0] += 1)
	var labels: Array = g.find_children("*", "Label", true, false).map(func(l): return l.text)
	var backs := [0]
	g.back.connect(func(): backs[0] += 1)
	var bad := ensure(not labels.has(g.tr("siegeBtn")), "no Core Siege button in the garage")
	bad += ensure(labels.has(g.tr("helpBtn")) and labels.has(g.tr("backBtn")), "how to play and back buttons are there")
	g.show_help()
	var enter := InputEventKey.new()
	enter.physical_keycode = KEY_ENTER
	enter.pressed = true
	g._input(enter)
	bad += ensure(g.help == null and fights[0] == 0, "Enter closes the help without starting a fight")
	g._unhandled_key_input(enter)
	bad += ensure(fights[0] == 1, "the next Enter fights")
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	g._unhandled_key_input(esc)
	bad += ensure(backs[0] == 1, "Esc goes back to the menu")
	g.queue_free()
	return int(bad > 0)


func wipe_flow() -> void:
	if FileAccess.file_exists(FLOW):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FLOW))


func over(score: Array) -> Node:
	wipe_flow()
	var m = load("res://main.tscn").instantiate()
	m.autopilot = true
	m.progress_arg = FLOW
	root.add_child(m)
	await process_frame
	m.state.score = score
	m.state.phase = "over"
	return m


func test_winning_a_match_opens_the_claim_screen_and_a_pick_unlocks_the_part() -> int:
	var m = await over([3, 0])
	var bad := ensure(m.rival_key == "duelist" and not m.progress.unlock_all, "a real run starts against the first rival with parts locked")
	m.broke = ["legs"]
	m.foe_ko = true
	await physics_frame
	await physics_frame
	bad += ensure(m.claim.visible and m.claim.items.size() == 4, "a win with a K.O. and a broken leg offers four parts")
	var at: int = m.claim.items.find_custom(func(d): return d.key == "horn")
	m.claim.pick(at)
	bad += ensure(m.progress.has("head", "horn") and m.progress.beaten.get("duelist", 0) == 1, "the pick is owned and the rival is beaten")
	bad += ensure(m.garage.visible and m.loadout.head == "horn" and not m.claim.visible, "the garage opens with the stolen part bolted on")
	bad += ensure(FileAccess.file_exists(FLOW) and m.progress.next_rival() == "sniper", "progress is saved and the next rival is the next on the ladder")
	m.queue_free()
	wipe_flow()
	await process_frame
	return int(bad > 0)


func test_losing_a_match_gives_no_claim() -> int:
	var m = await over([1, 3])
	m.broke = ["legs"]
	m.foe_ko = true
	await physics_frame
	await physics_frame
	var bad := ensure(not m.claim.visible and m.progress.beaten.is_empty(), "a loss offers nothing and beats no rival")
	m.queue_free()
	wipe_flow()
	await process_frame
	return int(bad > 0)


func ensure(cond: bool, what: String) -> int:
	if not cond:
		print("  condition false: " + what)
	return int(not cond)


## Visual plan M4: no decor within 1.5 m of a pad (band edge 1.4), spawn (chevrons reach 4.7),
## crusher (band 2.0), tesla reach, EMP vent strip or oil slick.
func test_decor_keeps_off_pads_spawns_and_traps() -> int:
	var all := Decor.spots()
	var bad := 0
	for kind in ["scorch", "grime", "grate", "scrap"]:
		bad += ensure(all.any(func(s): return s.kind == kind), "some %s is placed" % kind)
	for s in all:
		var p: Vector2 = s.p
		var k: float = 1.5 + s.r
		var near := []
		for o in Sim.PADS + [Sim.HEAL]:
			near.append(p.distance_to(Vector2(o.x, o.y)) < 1.4 + k)
		for o in Sim.SPAWNS:
			near.append(p.distance_to(Vector2(o.x, o.y)) < 4.7 + k)
		for o in Sim.TRAPS.crush.at:
			var q := (p - Vector2(o.x, o.y)).abs()
			near.append(maxf(q.x, q.y) < 2.0 + k)
		for o in Sim.TRAPS.tesla.at:
			near.append(p.distance_to(Vector2(o.x, o.y)) < Sim.TRAPS.tesla.reach + k)
		for o in Sim.TRAPS.oil.at:
			near.append(p.distance_to(Vector2(o.x, o.y)) < Sim.TRAPS.oil.r + k)
		for g in Sim.vents(0.0):
			var q := p - Vector2(g.x, g.y)
			var along := q.dot(Vector2(g.dx, g.dy))
			near.append(along > -k and along < Sim.HAZARDS.reach + k and absf(q.cross(Vector2(g.dx, g.dy))) < Sim.HAZARDS.half + k)
		bad += ensure(not near.has(true), "%s at %s is too close to a pad, spawn or trap" % [s.kind, p])
	return int(bad > 0)
