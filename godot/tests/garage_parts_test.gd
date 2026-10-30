extends SceneTree

const Sim = preload("res://src/sim.gd")
const Mech = preload("res://src/mech.gd")
const PartView = preload("res://src/part_view.gd")
const Garage = preload("res://src/garage.gd")
const Decor = preload("res://src/decor.gd")
const Progress = preload("res://src/progress.gd")
const Claim = preload("res://src/claim.gd")

const FLOW := "user://progress_flow_test.cfg"

var failed := 0


func _initialize() -> void:
	await run("every_part_builds_alone_with_a_model", test_every_part_builds_alone_with_a_model)
	await run("garage_previews_on_hover_and_equips_on_click", test_garage_previews_on_hover_and_equips_on_click)
	await run("match_flow_comes_back_to_the_garage", test_match_flow_comes_back_to_the_garage)
	await run("siege_button_starts_a_siege_and_fight_goes_back_to_a_duel", test_siege_button_starts_a_siege_and_fight_goes_back_to_a_duel)
	await run("pad_moves_aims_acts_and_pauses", test_pad_moves_aims_acts_and_pauses)
	await run("garage_works_with_a_pad", test_garage_works_with_a_pad)
	await run("decor_keeps_off_pads_spawns_and_traps", test_decor_keeps_off_pads_spawns_and_traps)
	await run("garage_locks_parts_you_have_not_won", test_garage_locks_parts_you_have_not_won)
	await run("winning_a_match_opens_the_claim_screen_and_a_pick_unlocks_the_part", test_winning_a_match_opens_the_claim_screen_and_a_pick_unlocks_the_part)
	await run("losing_a_match_gives_no_claim", test_losing_a_match_gives_no_claim)
	await run("claim_lifts_the_hovered_card_and_keep_takes_it", test_claim_lifts_the_hovered_card_and_keep_takes_it)
	await run("claim_panel_lists_changed_stats_and_the_new_skill", test_claim_panel_lists_changed_stats_and_the_new_skill)
	await run("garage_tags_the_equipped_card_after_a_click", test_garage_tags_the_equipped_card_after_a_click)
	print("FAILED" if failed else "ALL PASSED")
	quit(1 if failed else 0)


func run(name: String, test: Callable) -> void:
	var t0 := Time.get_ticks_msec()
	if await test.call() != 0:
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


func test_siege_button_starts_a_siege_and_fight_goes_back_to_a_duel() -> int:
	var m = load("res://main.tscn").instantiate()
	m.autopilot = true
	root.add_child(m)
	await process_frame
	m.state.phase = "over"
	m.to_garage()
	await process_frame
	m.garage.go_siege()
	await physics_frame
	await physics_frame
	var bad := ensure(m.siege and m.state.has("siege") and m.siege_view != null, "CORE SIEGE starts a siege run")
	bad += ensure(m.view.visible and not m.garage.visible, "the siege view shows")
	m.state.phase = "over"
	m.to_garage()
	await process_frame
	m.garage.go()
	await physics_frame
	await physics_frame
	bad += ensure(not m.siege and not m.state.has("siege") and m.siege_view == null, "FIGHT goes back to a duel")
	m.queue_free()
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


func test_claim_lifts_the_hovered_card_and_keep_takes_it() -> int:
	var c = Claim.new()
	root.add_child(c)
	var list := [{"slot": "head", "key": "horn"}, {"slot": "legs", "key": "hover"}, {"slot": "core", "key": "titan"}]
	var got := []
	c.picked.connect(func(slot, key): got.append([slot, key]))
	c.open(list, "tank", 1, Progress.new())
	var bad := ensure(c.sel == 0 and c.cards[0].position.y < c.cards[1].position.y, "the first card starts lifted")
	c.cards[2].mouse_entered.emit()
	bad += ensure(c.sel == 2 and c.cards[2].position.y < c.cards[0].position.y and c.cards[0].position.y == c.cards[1].position.y, "hovering a card lifts it and drops the old one")
	c.keep_btn.pressed.emit()
	bad += ensure(got == [["core", "titan"]] and not c.visible, "KEEP takes the lifted card")
	c.queue_free()
	await process_frame
	return int(bad > 0)


func test_claim_panel_lists_changed_stats_and_the_new_skill() -> int:
	var c = Claim.new()
	root.add_child(c)
	var p := Progress.new()
	c.open([{"slot": "head", "key": "horn"}, {"slot": "core", "key": "titan"}], "tank", 1, p, Sim.DEFAULT_LOADOUT)
	await process_frame
	var texts := func(): return c.panel.get_children().filter(func(n): return n is Label and not n.is_queued_for_deletion()).map(func(n): return n.text)
	var t: Array = texts.call()
	var bad := ensure(t.any(func(x): return x.contains("Lunge") or x.contains("Embestida")), "a head with a new E skill names it")
	bad += ensure(t.any(func(x): return x.contains("▲")), "a better stat shows an up arrow")
	c.cards[1].mouse_entered.emit()
	await process_frame
	t = texts.call()
	bad += ensure(t.any(func(x): return x.begins_with("R ·")), "a new core names its R skill")
	c.queue_free()
	await process_frame
	return int(bad > 0)


func test_garage_tags_the_equipped_card_after_a_click() -> int:
	var g = Garage.new()
	g.progress.unlock_all = true
	root.add_child(g)
	g.open(Sim.DEFAULT_LOADOUT)
	await process_frame
	var tags := func(): return g.cards.filter(func(c): return c[4].visible).map(func(c): return c[2])
	var bad := ensure(tags.call() == [{"slot": "head", "key": "rookie"}], "the worn head carries the EQUIPPED tag")
	g.equip({"slot": "head", "key": "demon"})
	bad += ensure(tags.call() == [{"slot": "head", "key": "demon"}], "the tag moves to the card you click")
	g.queue_free()
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
