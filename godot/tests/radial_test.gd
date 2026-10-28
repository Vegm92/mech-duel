extends SceneTree

const Radial = preload("res://src/radial.gd")

var failed := 0
var picks := []
var closes := 0


func _process(_dt: float) -> bool:
	angles()
	menu()
	print("FAILED" if failed else "ALL PASSED")
	quit(1 if failed else 0)
	return true


func angles() -> void:
	for n in [4, 6, 9]:
		var step: float = TAU / n
		var ok := true
		for i in n:
			for a in [i * step, i * step + step / 2.0 - 0.02, i * step - step / 2.0 + 0.02]:
				ok = ok and Radial.wedge_at(Radial.dir(a) * 150.0, n, Radial.RING.dead) == i
		check(ok, "%d wedges: every direction lands on its own wedge, up is wedge 0, clockwise" % n)
	check(Radial.wedge_at(Vector2(150, 0), 4, Radial.RING.dead) == 1 and Radial.wedge_at(Vector2(0, 150), 4, Radial.RING.dead) == 2 and Radial.wedge_at(Vector2(-150, 0), 4, Radial.RING.dead) == 3, "4 wedges: right, down, left are 1, 2, 3")
	check(Radial.wedge_at(Vector2(20, -30), 6, Radial.RING.dead) == -1, "the dead zone picks nothing")


func menu() -> void:
	var r := Radial.new()
	r.size = Vector2(1280, 720)
	root.add_child(r)
	r.picked.connect(func(p): picks.append(p))
	r.closed.connect(func(): closes += 1)
	r.open(entries())
	check(r.visible and r.level().size() == 6, "open shows the top ring")
	r.point(Radial.dir(TAU / 6) * 150.0)
	r.confirm()
	check(picks.is_empty() and r.visible, "a disabled wedge cannot be picked")
	r.point(Vector2(5, 5))
	r.confirm()
	check(picks.is_empty() and r.visible, "confirm in the dead zone does nothing")
	r.point(Radial.dir(0) * 150.0)
	r.confirm()
	check(picks.size() == 1 and picks[0] == PackedStringArray(["gate"]) and not r.visible, "a top-level pick returns its id and hides the menu")
	check(closes == 0, "a pick is not a close")
	r.open(entries())
	r.point(Radial.dir(3 * TAU / 6) * 150.0)
	r.confirm()
	check(r.stack.size() == 2 and r.level().size() == 4 and r.hover == -1, "a wedge with children opens the second ring")
	r.back()
	check(r.stack.size() == 1 and r.visible and closes == 0, "back from the second ring returns to the top")
	r.point(Radial.dir(3 * TAU / 6) * 150.0)
	r.confirm()
	r.point(Radial.dir(TAU / 4) * 150.0)
	press(r, JOY_BUTTON_A)
	check(picks.size() == 2 and picks[1] == PackedStringArray(["modules", "mine"]), "a two-level pick returns the path (pad A confirms)")
	r.open(entries())
	r.point(Radial.dir(3 * TAU / 6) * 150.0)
	r.confirm()
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	r._input(esc)
	check(r.stack.size() == 1 and r.visible, "Esc goes back one level")
	press(r, JOY_BUTTON_B)
	check(not r.visible and closes == 1, "pad B at the top closes and emits closed")
	r.open(entries())
	var rmb := InputEventMouseButton.new()
	rmb.button_index = MOUSE_BUTTON_RIGHT
	rmb.pressed = true
	r._input(rmb)
	check(closes == 2, "right click at the top closes")
	InputMap.add_action(&"shop_hold")
	r.confirm_on_release = true
	r.hold_action = &"shop_hold"
	r.open(entries())
	r.point(Radial.dir(2 * TAU / 6) * 150.0)
	var up := InputEventAction.new()
	up.action = &"shop_hold"
	up.pressed = false
	r._input(up)
	check(picks.size() == 3 and picks[2] == PackedStringArray(["ring"]), "releasing the hold key confirms when confirm_on_release is on")
	r.confirm_on_release = false
	r.open(entries())
	r.point(Vector2(0.9, 0.1))
	check(r.hover == 2, "a stick vector picks by direction")
	r.point(Vector2(0.1, 0.05))
	check(r.hover == 2, "a centered stick keeps the last pick")
	check(r.confirm() == "ring", "confirm returns the picked id")
	r.open(entries())
	r.point(Radial.dir(3 * TAU / 6) * 150.0)
	check(r.confirm() == "", "opening a second ring returns no id")
	r.point(Radial.dir(TAU / 4) * 150.0)
	var poor := entries()
	poor[3].sub[1].enabled = false
	poor[3].sub[1].cost = 999
	r.refresh(poor)
	check(r.stack.size() == 2 and r.hover == 1 and r.level()[1].cost == 999, "refresh keeps the open ring and the hover, with new costs")
	check(r.confirm() == "", "refresh can disable the hovered wedge")
	r.own_input = false
	var lmb := InputEventMouseButton.new()
	lmb.button_index = MOUSE_BUTTON_RIGHT
	lmb.pressed = true
	r._input(lmb)
	check(r.stack.size() == 2, "with own_input off the widget ignores raw input")
	r.free()


func press(r: Node, button: JoyButton) -> void:
	var b := InputEventJoypadButton.new()
	b.button_index = button
	b.pressed = true
	r._input(b)


func entries() -> Array:
	var leaf := func(id: String, cost: int, on := true) -> Dictionary: return {"id": id, "label_key": "shop_" + id, "cost": cost, "enabled": on, "sub": [], "note": ""}
	return [
		leaf.call("gate", 40),
		leaf.call("rebuild", 120, false),
		leaf.call("ring", 200),
		{"id": "modules", "label_key": "radialModules", "cost": -1, "enabled": true, "note": "", "sub": [leaf.call("wall", 60), leaf.call("mine", 80), leaf.call("laser", 150, false), leaf.call("post", 120)]},
		leaf.call("repair", 30),
		leaf.call("upgrade", 80),
	]


func check(ok: bool, what: String) -> void:
	print(("test passed: " if ok else "test failed: ") + what)
	if not ok:
		failed += 1
