extends CanvasLayer

signal confirmed(list: Array, picks: Array)
signal back
signal ui(kind: String)

const Garage = preload("res://src/garage.gd")
const Look = preload("res://src/look.gd")
const Sim = preload("res://src/sim.gd")

const SIZE := Vector2(1280, 720)
const CARD := Vector2(270, 340)
const GAP := 20.0
const TOP := 140.0
const TILT := 0.6
const PER_TEAM := 2

var root: Control
var bold: FontVariation
var list: Array = []
var picks := {}
var memory := {}
var mine: Dictionary = Sim.DEFAULT_LOADOUT
var count := 2
var fmt := "1v1"
var warn := false
var tilt := {}


func _init() -> void:
	layer = 6
	visible = false
	bold = Look.font(Look.FONT.bold)
	var bg := ColorRect.new()
	bg.color = Garage.A_GROUND
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	root = Control.new()
	root.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_preset(Control.PRESET_CENTER)
	root.offset_left = -SIZE.x / 2.0
	root.offset_right = SIZE.x / 2.0
	root.offset_top = -SIZE.y / 2.0
	root.offset_bottom = SIZE.y / 2.0
	add_child(root)


func open(start: Array, format: String, garage_loadout: Dictionary = Sim.DEFAULT_LOADOUT) -> void:
	list = []
	picks = {}
	fmt = format
	count = Sim.FORMATS[format].size()
	mine = garage_loadout
	warn = false
	for who in start.slice(0, count):
		seat(who)
	visible = true
	refresh()


func options() -> Array:
	return [""] + Sim.SETS.keys()


func name_of(who) -> String:
	return tr("seatKb") if who is String else tr("seatPad").format({"n": int(who) + 1})


func humans_on(team: int) -> int:
	return picks.values().filter(func(p): return p.team == team).size()


func seat(who) -> void:
	var i := list.size()
	var set: String = memory.get(who, "" if i == 0 else Sim.SETS.keys()[i % Sim.SETS.size()])
	var team := i % 2
	if humans_on(team) >= PER_TEAM:
		team = 1 - team
	list.append(who)
	picks[who] = {"set": set, "team": team}


func join(who) -> void:
	if list.has(who) or list.size() >= count:
		return
	seat(who)
	warn = false
	ui.emit("equip")
	refresh()


func leave(who) -> bool:
	if not list.has(who):
		return false
	list.erase(who)
	picks.erase(who)
	ui.emit("tab")
	refresh()
	return true


func cycle(who, step: int) -> void:
	if not picks.has(who):
		return
	var opts := options()
	var set: String = opts[posmod(opts.find(picks[who].set) + step, opts.size())]
	picks[who].set = set
	memory[who] = set
	ui.emit("hover")
	refresh()


func set_team(who, team: int) -> void:
	if fmt != "2v2" or not picks.has(who) or picks[who].team == team or humans_on(team) >= PER_TEAM:
		return
	picks[who].team = team
	ui.emit("hover")
	refresh()


func go() -> void:
	if list.is_empty():
		warn = true
		refresh()
		return
	ui.emit("start")
	visible = false
	confirmed.emit(list.duplicate(), list.map(func(w): return picks[w].duplicate()))


func label(s: String, pos: Vector2, px: int, c: Color, w := 0.0, align := HORIZONTAL_ALIGNMENT_LEFT, display := false) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", c)
	l.add_theme_font_override("font", Garage.impact() if display else bold)
	l.position = pos
	if w > 0.0:
		l.size.x = w
		l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(l)
	return l


func click(r: Rect2, press: Callable) -> void:
	var b := Button.new()
	b.position = r.position
	b.size = r.size
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for s in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(s, Garage.box(Color(1, 1, 1, 0.08 if s == "hover" else 0.0), 6))
	b.pressed.connect(press)
	root.add_child(b)


func build_of(who) -> Dictionary:
	var set: String = picks[who].set
	return mine if set == "" else Sim.SETS[set]


func card(i: int, at: Vector2) -> void:
	var who = list[i]
	var p: Dictionary = picks[who]
	var lo := build_of(who)
	var w := CARD.x - 40.0
	label(name_of(who), at + Vector2(20, 96), 18, Garage.A_HAZARD, w)
	label(tr("seatBuild"), at + Vector2(20, 142), 12, Garage.A_LOCKED)
	label("<", at + Vector2(12, 160), 30, Garage.A_DIM, 30.0, HORIZONTAL_ALIGNMENT_CENTER, true)
	label(">", at + Vector2(CARD.x - 42, 160), 30, Garage.A_DIM, 30.0, HORIZONTAL_ALIGNMENT_CENTER, true)
	var title := label(tr("seatMine") if p.set == "" else tr("set_" + p.set), at + Vector2(46, 162), 22, Color.WHITE, CARD.x - 92.0, HORIZONTAL_ALIGNMENT_CENTER, true)
	var px := 22
	while px > 12 and title.get_theme_font("font").get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > CARD.x - 92.0:
		px -= 1
	title.add_theme_font_size_override("font_size", px)
	click(Rect2(at + Vector2(8, 152), Vector2(36, 48)), cycle.bind(who, -1))
	click(Rect2(at + Vector2(CARD.x - 44, 152), Vector2(36, 48)), cycle.bind(who, 1))
	label(tr("setSkill") + ": " + tr("u_" + Sim.ult_of(lo)), at + Vector2(20, 206), 14, Garage.A_SURGE, w)
	if fmt != "2v2":
		return
	for t in 2:
		var r := Rect2(at + Vector2(20 + t * (w / 2.0 + 4.0), 262), Vector2(w / 2.0 - 4.0, 40))
		var on: bool = p.team == t
		var chip := Panel.new()
		chip.position = r.position
		chip.size = r.size
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_theme_stylebox_override("panel", Garage.box(Look.ARCADE.team[t] if on else Garage.A_RAISED, 8))
		root.add_child(chip)
		label(tr("seatTeam" + ("A" if t == 0 else "B")), r.position + Vector2(0, 8), 18, Garage.A_GROUND if on else Garage.A_DIM, r.size.x, HORIZONTAL_ALIGNMENT_CENTER, true)
		click(r, set_team.bind(who, t))


func refresh() -> void:
	for c in root.get_children():
		c.queue_free()
	Garage.hazard(root, Rect2(0, 0, SIZE.x, 8))
	label(tr("seatsTitle"), Vector2(60, 24), 54, Color.WHITE, 0.0, HORIZONTAL_ALIGNMENT_LEFT, true)
	label(tr("fmt_" + fmt), Vector2(60, 92), 20, Garage.A_HAZARD)
	var x0 := (SIZE.x - (CARD.x * 4 + GAP * 3)) / 2.0
	for i in 4:
		var at := Vector2(x0 + i * (CARD.x + GAP), TOP)
		var open_slot := i < count
		var who = list[i] if i < list.size() else null
		var fill: Color = Garage.A_PICKED if who != null else Garage.A_PANEL
		var p := Panel.new()
		p.position = at
		p.size = CARD
		p.modulate.a = 1.0 if open_slot else 0.35
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_theme_stylebox_override("panel", Garage.box(fill, 14, Garage.A_HAZARD if who != null else Color.TRANSPARENT))
		root.add_child(p)
		label("P%d" % (i + 1), at + Vector2(20, 20), 64, Color.WHITE if who != null else Garage.A_LOCKED, 0.0, HORIZONTAL_ALIGNMENT_LEFT, true)
		if not open_slot:
			continue
		if who != null:
			card(i, at)
		else:
			label(tr("seatBot"), at + Vector2(20, 130), 28, Garage.A_DIM, CARD.x - 40.0, HORIZONTAL_ALIGNMENT_LEFT, true)
			if i == list.size():
				var l := label(tr("seatFree"), at + Vector2(20, 176), 15, Garage.A_INK, CARD.x - 40.0)
				l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label(tr("seatsNeed") if warn else "", Vector2(0, 500), 22, Garage.A_DANGER, SIZE.x, HORIZONTAL_ALIGNMENT_CENTER)
	label(tr("seatsHint"), Vector2(0, 650), 14, Garage.A_DIM, SIZE.x, HORIZONTAL_ALIGNMENT_CENTER)
	var f := Button.new()
	f.position = Vector2(SIZE.x / 2.0 - 120, 546)
	f.size = Vector2(240, 64)
	f.focus_mode = Control.FOCUS_NONE
	f.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	Garage.skew(f, Garage.A_HAZARD, true)
	f.pressed.connect(go)
	root.add_child(f)
	var t := label(tr("go"), Vector2.ZERO, 34, Garage.A_GROUND, f.size.x, HORIZONTAL_ALIGNMENT_CENTER, true)
	root.remove_child(t)
	f.add_child(t)
	t.size.y = f.size.y
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func steer(who, dx: int, dy: int) -> void:
	if dx != 0:
		cycle(who, dx)
	elif dy != 0:
		set_team(who, 0 if dy < 0 else 1)


func _input(e: InputEvent) -> void:
	if not visible:
		return
	if e is InputEventKey and e.pressed and not e.echo:
		match e.physical_keycode:
			KEY_ENTER, KEY_KP_ENTER:
				go()
			KEY_SPACE:
				if not leave("kb"):
					join("kb")
			KEY_BACKSPACE:
				leave("kb")
			KEY_A, KEY_LEFT:
				steer("kb", -1, 0)
			KEY_D, KEY_RIGHT:
				steer("kb", 1, 0)
			KEY_W, KEY_UP:
				steer("kb", 0, -1)
			KEY_S, KEY_DOWN:
				steer("kb", 0, 1)
			KEY_ESCAPE:
				visible = false
				back.emit()
			_:
				return
	elif e is InputEventJoypadButton and e.pressed:
		match e.button_index:
			JOY_BUTTON_A:
				join(e.device)
			JOY_BUTTON_B:
				if not leave(e.device):
					visible = false
					back.emit()
			JOY_BUTTON_START:
				go()
			JOY_BUTTON_DPAD_LEFT:
				steer(e.device, -1, 0)
			JOY_BUTTON_DPAD_RIGHT:
				steer(e.device, 1, 0)
			JOY_BUTTON_DPAD_UP:
				steer(e.device, 0, -1)
			JOY_BUTTON_DPAD_DOWN:
				steer(e.device, 0, 1)
			_:
				return
	elif e is InputEventJoypadMotion and e.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		var key := Vector2i(e.device, e.axis)
		var dir := 0 if absf(e.axis_value) < TILT else int(signf(e.axis_value))
		var was: int = tilt.get(key, 0)
		tilt[key] = dir
		if dir == 0 or dir == was:
			return
		steer(e.device, dir if e.axis == JOY_AXIS_LEFT_X else 0, dir if e.axis == JOY_AXIS_LEFT_Y else 0)
	else:
		return
	get_viewport().set_input_as_handled()
