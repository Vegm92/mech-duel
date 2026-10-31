extends CanvasLayer

signal confirmed(list: Array)
signal back
signal ui(kind: String)

const Garage = preload("res://src/garage.gd")
const Look = preload("res://src/look.gd")
const Sim = preload("res://src/sim.gd")

const SIZE := Vector2(1280, 720)
const CARD := Vector2(270, 320)
const GAP := 20.0
const TOP := 150.0

var root: Control
var bold: FontVariation
var list: Array = []
var count := 2
var fmt := "1v1"
var warn := false


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


func open(start: Array, format: String) -> void:
	list = start.duplicate()
	fmt = format
	count = Sim.FORMATS[format].size()
	warn = false
	visible = true
	refresh()


func name_of(who) -> String:
	return tr("seatKb") if who is String else tr("seatPad").format({"n": int(who) + 1})


func join(who) -> void:
	if list.has(who) or list.size() >= count:
		return
	list.append(who)
	warn = false
	ui.emit("equip")
	refresh()


func leave(who) -> bool:
	if not list.has(who):
		return false
	list.erase(who)
	ui.emit("tab")
	refresh()
	return true


func go() -> void:
	if list.is_empty():
		warn = true
		refresh()
		return
	ui.emit("start")
	visible = false
	confirmed.emit(list.duplicate())


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
	root.add_child(l)
	return l


func refresh() -> void:
	for c in root.get_children():
		c.queue_free()
	Garage.hazard(root, Rect2(0, 0, SIZE.x, 8))
	label(tr("seatsTitle"), Vector2(60, 28), 54, Color.WHITE, 0.0, HORIZONTAL_ALIGNMENT_LEFT, true)
	label(tr("fmt_" + fmt), Vector2(60, 100), 20, Garage.A_HAZARD)
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
		label("P%d" % (i + 1), at + Vector2(20, 22), 64, Color.WHITE if who != null else Garage.A_LOCKED, 0.0, HORIZONTAL_ALIGNMENT_LEFT, true)
		if not open_slot:
			continue
		if who != null:
			label(name_of(who), at + Vector2(20, 130), 20, Garage.A_HAZARD, CARD.x - 40.0)
		else:
			label(tr("seatBot"), at + Vector2(20, 130), 28, Garage.A_DIM, CARD.x - 40.0, HORIZONTAL_ALIGNMENT_LEFT, true)
			if i == list.size():
				var l := label(tr("seatFree"), at + Vector2(20, 176), 15, Garage.A_INK, CARD.x - 40.0)
				l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label(tr("seatsNeed") if warn else "", Vector2(0, 490), 22, Garage.A_DANGER, SIZE.x, HORIZONTAL_ALIGNMENT_CENTER)
	label(tr("seatsHint"), Vector2(0, 640), 14, Garage.A_DIM, SIZE.x, HORIZONTAL_ALIGNMENT_CENTER)
	var f := Button.new()
	f.position = Vector2(SIZE.x / 2.0 - 120, 540)
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
			_:
				return
	else:
		return
	get_viewport().set_input_as_handled()
