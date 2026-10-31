extends Control

const Look = preload("res://src/look.gd")

signal picked(path: PackedStringArray)
signal closed

const RING := {"outer": 200.0, "inner": 84.0, "dead": 60.0, "gap": 0.03, "grow": 12.0, "open": 0.12, "stick": 0.35, "segs": 14, "from": 0.82}
const A := Look.ARCADE
const FILL := Color8(34, 30, 46, 245)
const FILL_HOT := Color8(255, 201, 60, 250)
const FILL_OFF := Color8(23, 20, 31, 235)
const SCRIM := Color(0, 0, 0, 0.55)
const TEXT := Color.WHITE
const DIM := Color8(142, 135, 168)
const SOFT := Color8(217, 212, 234)
const INK := Color8(11, 10, 18)
const LINE := Color8(52, 48, 74)
const HAZARD := Color8(255, 201, 60)
const TYPE := {"label": 16, "min": 11, "cost": 15, "name": 19, "note": 14, "pad": 14.0}

var own_input := true
var confirm_on_release := false
var hold_action := &""
var stack := []
var trail := PackedStringArray()
var hover := -1
var aim := Vector2.ZERO
var age := 0.0
var pad_id := -1
var font: Font
var bold: Font
var title: Font
var chips := []
var heading := "radialShop"
var caption := "radialNote"


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	font = Look.font(Look.FONT.text)
	bold = Look.font(Look.FONT.bold)
	title = Look.font(Look.FONT.heavy, true, Look.FONT.impact)


## Entries: {id, label_key, cost (-1 = no price), enabled, sub: [entries], note}. A pick emits `picked(path)`; backing out of the top ring emits `closed`.
func open(entries: Array) -> void:
	stack = [entries]
	trail = PackedStringArray()
	visible = true
	enter()
	if is_inside_tree():
		get_viewport().warp_mouse(get_global_rect().get_center())


func close() -> void:
	visible = false
	stack.clear()
	closed.emit()


func back() -> void:
	if stack.size() > 1:
		stack.pop_back()
		trail.remove_at(trail.size() - 1)
		enter()
	else:
		close()


## Returns the picked leaf id, or "" (nothing hovered, disabled, or a second ring opened).
func confirm() -> String:
	if hover < 0:
		return ""
	var e: Dictionary = level()[hover]
	if not e.get("enabled", true):
		return ""
	trail.append(e.id)
	if not e.get("sub", []).is_empty():
		stack.append(e.sub)
		enter()
		return ""
	var path := trail
	visible = false
	stack.clear()
	picked.emit(path)
	return e.id


## New costs and enabled flags while open; keeps the open ring and the hovered wedge.
func refresh(entries: Array) -> void:
	if stack.is_empty():
		return
	stack = [entries]
	var kept := PackedStringArray()
	for id in trail:
		var hit = level().filter(func(e): return e.id == id)
		if hit.is_empty() or hit[0].get("sub", []).is_empty():
			break
		stack.append(hit[0].sub)
		kept.append(id)
	trail = kept
	hover = mini(hover, level().size() - 1)
	queue_redraw()


func level() -> Array:
	return stack[-1]


func enter() -> void:
	age = 0.0
	aim = Vector2.ZERO
	hover = -1
	queue_redraw()


## A pointer offset from the center in this control's units, or a stick vector (length <= 1; a centered stick keeps the last pick).
func point(v: Vector2) -> void:
	if v.length() <= 1.0:
		if v.length() <= RING.stick:
			return
		v = v.normalized() * (RING.inner + RING.outer) / 2.0
	aim = v
	hover = wedge_at(v, level().size(), RING.dead)
	queue_redraw()


## Wedge 0 is centered straight up, then clockwise; -1 inside the dead zone.
static func wedge_at(v: Vector2, n: int, dead: float) -> int:
	if n <= 0 or v.length() < dead:
		return -1
	var step := TAU / n
	return int(floorf(fposmod(atan2(v.x, -v.y) + step / 2.0, TAU) / step)) % n


func _input(ev: InputEvent) -> void:
	if not visible or not own_input:
		return
	var used := true
	if ev is InputEventMouseMotion:
		point(get_local_mouse_position() - size / 2.0)
	elif ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_LEFT:
			confirm()
		elif ev.button_index == MOUSE_BUTTON_RIGHT:
			back()
	elif ev is InputEventJoypadMotion:
		pad_id = ev.device
	elif ev is InputEventJoypadButton and ev.pressed:
		pad_id = ev.device
		if ev.button_index == JOY_BUTTON_A:
			confirm()
		elif ev.button_index == JOY_BUTTON_B:
			back()
	elif ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_ESCAPE:
		back()
	elif confirm_on_release and hold_action != &"" and ev.is_action_released(hold_action):
		confirm()
	else:
		used = false
	if used and is_inside_tree():
		get_viewport().set_input_as_handled()


func _process(dt: float) -> void:
	if not visible:
		return
	age += dt
	if own_input and pad_id >= 0:
		var l := Vector2(Input.get_joy_axis(pad_id, JOY_AXIS_LEFT_X), Input.get_joy_axis(pad_id, JOY_AXIS_LEFT_Y))
		var r := Vector2(Input.get_joy_axis(pad_id, JOY_AXIS_RIGHT_X), Input.get_joy_axis(pad_id, JOY_AXIS_RIGHT_Y))
		var s := l if l.length() >= r.length() else r
		point(s)
	queue_redraw()


func _draw() -> void:
	if stack.is_empty():
		return
	var k := ease(clampf(age / RING.open, 0.0, 1.0), 0.4)
	var c := size / 2.0
	var grow := lerpf(RING.from, 1.0, k)
	var items := level()
	var n := items.size()
	var step := TAU / n
	draw_circle(c, (RING.outer + RING.grow + 36.0) * grow, Color(SCRIM, SCRIM.a * k))
	header(k)
	for i in n:
		var e: Dictionary = items[i]
		var on: bool = e.get("enabled", true)
		var hot := i == hover
		var r0: float = RING.inner * grow
		var r1: float = (RING.outer + (RING.grow if hot else 0.0)) * grow
		var a0 := i * step - step / 2.0 + RING.gap
		var a1 := i * step + step / 2.0 - RING.gap
		var shape := PackedVector2Array()
		for j in RING.segs + 1:
			shape.append(c + dir(lerpf(a0, a1, float(j) / RING.segs)) * r1)
		for j in range(RING.segs, -1, -1):
			shape.append(c + dir(lerpf(a0, a1, float(j) / RING.segs)) * r0)
		var fill := FILL_HOT if hot and on else (FILL if on else FILL_OFF)
		draw_colored_polygon(shape, Color(fill, fill.a * k))
		shape.append(shape[0])
		draw_polyline(shape, Color(Color.WHITE if hot else LINE, (1.0 if hot else 0.8) * k), 3.0 if hot else 1.5, true)
		var mid := c + dir(i * step) * (r0 + r1) / 2.0
		var room := minf(2.0 * (r0 + r1) / 2.0 * sin(step / 2.0) - TYPE.pad, r1 - r0 + 40.0)
		var label := tr(e.label_key).to_upper()
		var px := fit(label, room, TYPE.label)
		var tc := INK if hot and on else (TEXT if on else DIM)
		var cost: int = e.get("cost", -1)
		var y := mid.y + (px / 2.0 - 8.0 if cost >= 0 else px / 2.0 - 2.0)
		draw_string(title, Vector2(mid.x - room / 2.0, y), label, HORIZONTAL_ALIGNMENT_CENTER, room, px, Color(tc, k))
		if cost >= 0:
			var cc := INK if hot and on else (HAZARD if on else Color(A.danger, 0.9))
			draw_string(title, Vector2(mid.x - room / 2.0, y + TYPE.cost + 2), str(cost), HORIZONTAL_ALIGNMENT_CENTER, room, TYPE.cost, Color(cc, k))
		if not e.get("sub", []).is_empty():
			var tip := c + dir(i * step) * (r1 - 8.0)
			var side := dir(i * step + PI / 2.0) * 6.0
			draw_colored_polygon(PackedVector2Array([tip, tip - dir(i * step) * 8.0 + side, tip - dir(i * step) * 8.0 - side]), Color(INK if hot else HAZARD, 0.95 * k))
	var hub: float = (RING.inner - 8.0) * grow
	draw_circle(c, hub, Color(FILL_OFF, k))
	draw_arc(c, hub, 0.0, TAU, 48, Color(LINE, k), 3.0, true)
	if hover >= 0:
		var e: Dictionary = items[hover]
		var on: bool = e.get("enabled", true)
		var w := hub * 1.8
		var name := tr(e.label_key).to_upper()
		draw_string(title, c + Vector2(-w / 2.0, -10), name, HORIZONTAL_ALIGNMENT_CENTER, w, fit(name, w, TYPE.name), Color(HAZARD if on else DIM, k))
		var cost: int = e.get("cost", -1)
		if cost >= 0:
			draw_string(title, c + Vector2(-w / 2.0, 14), str(cost), HORIZONTAL_ALIGNMENT_CENTER, w, TYPE.cost + 3, Color(TEXT if on else A.danger, k))
		var note: String = e.get("note", "")
		if note != "":
			draw_string(font, c + Vector2(-w / 2.0, 36), note, HORIZONTAL_ALIGNMENT_CENTER, w, fit(note, w, TYPE.note), Color(SOFT, k))
	elif trail.size() > 0:
		draw_string(font, c + Vector2(-hub, 6), tr(parent_label()).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, hub * 2.0, TYPE.note, Color(DIM, k))


func header(k: float) -> void:
	var x := 24.0
	for ch in chips:
		var s: String = ch[0]
		var w := bold.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 28.0
		draw_rect(Rect2(x, 20, w, 28), Color(HAZARD if ch[1] else FILL_OFF, k))
		draw_string(bold, Vector2(x, 40), s, HORIZONTAL_ALIGNMENT_CENTER, w, 13, Color(INK if ch[1] else TEXT, k))
		x += w + 6.0
	var steps := PackedStringArray([tr(heading).to_upper()])
	for d in trail.size():
		for e in stack[d]:
			if e.id == trail[d]:
				steps.append(tr(e.label_key).to_upper())
				break
	var line := ""
	for i in steps.size():
		line += ("  ›  " if i > 0 else "") + steps[i]
	draw_string(title, Vector2(0, 150), line, HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, Color(HAZARD, k))
	draw_string(font, Vector2(0, 24), tr(caption), HORIZONTAL_ALIGNMENT_RIGHT, size.x - 24.0, 13, Color(DIM, k))
	var hint := tr("radialHint")
	var hw := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 28.0
	draw_rect(Rect2(size.x / 2.0 - hw / 2.0, size.y - 42.0, hw, 28.0), Color(FILL_OFF, 0.9 * k))
	draw_string(font, Vector2(0, size.y - 23), hint, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color(SOFT, k))


func parent_label() -> String:
	var items: Array = stack[-2]
	for e in items:
		if e.id == trail[-1]:
			return e.label_key
	return ""


func fit(s: String, room: float, px: int) -> int:
	while px > TYPE.min and title.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > room:
		px -= 1
	return px


static func dir(a: float) -> Vector2:
	return Vector2(sin(a), -cos(a))
