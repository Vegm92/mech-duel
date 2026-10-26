extends SceneTree

const Sim = preload("res://src/sim.gd")
const Mech = preload("res://src/mech.gd")
const PartView = preload("res://src/part_view.gd")
const Garage = preload("res://src/garage.gd")

var failed := 0


func _initialize() -> void:
	await run("every_part_builds_alone_with_a_model", test_every_part_builds_alone_with_a_model)
	await run("garage_previews_on_hover_and_equips_on_click", test_garage_previews_on_hover_and_equips_on_click)
	await run("match_flow_comes_back_to_the_garage", test_match_flow_comes_back_to_the_garage)
	print("FAILED" if failed else "ALL PASSED")
	quit(1 if failed else 0)


func run(name: String, test: Callable) -> void:
	var t0 := Time.get_ticks_msec()
	if await test.call():
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
	bad += ensure(g.next_lo().head == "demon" and g.loadout.head == "horn", "hover does not equip")
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


func ensure(cond: bool, what: String) -> int:
	if not cond:
		print("  condition false: " + what)
	return int(not cond)
