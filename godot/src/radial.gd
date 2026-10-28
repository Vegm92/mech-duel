extends Control

const Look = preload("res://src/look.gd")

signal picked(path: PackedStringArray)
signal closed

const RING := {"outer": 200.0, "inner": 84.0, "dead": 60.0, "gap": 0.03, "grow": 12.0, "open": 0.12, "stick": 0.35, "segs": 14, "from": 0.82}
const FILL := Color(0.09, 0.1, 0.13, 0.96)
const FILL_HOT := Color(0.13, 0.2, 0.28, 0.98)
const FILL_OFF := Color(0.06, 0.06, 0.08, 0.92)
const SCRIM := Color(0, 0, 0, 0.45)
const TEXT := Color(0.91, 0.95, 1.0)
const DIM := Color(0.5, 0.56, 0.64)
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


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	font = Look.font(Look.FONT.text)
	bold = Look.font(Look.FONT.bold)


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
		var fill := FILL_HOT if hot else (FILL if on else FILL_OFF)
		draw_colored_polygon(shape, Color(fill, fill.a * k))
		var rim: Color = Look.PAL.cyan if on else DIM
		shape.append(shape[0])
		draw_polyline(shape, Color(rim.lightened(0.35) if hot else rim, (1.0 if hot else 0.55) * k), 3.0 if hot else 1.5, true)
		var mid := c + dir(i * step) * (r0 + r1) / 2.0
		var room := minf(2.0 * (r0 + r1) / 2.0 * sin(step / 2.0) - TYPE.pad, r1 - r0 + 40.0)
		var label := tr(e.label_key)
		var px := fit(label, room, TYPE.label)
		var tc := TEXT if on else DIM
		var cost: int = e.get("cost", -1)
		var y := mid.y + (px / 2.0 - 8.0 if cost >= 0 else px / 2.0 - 2.0)
		draw_string(bold, Vector2(mid.x - room / 2.0, y), label, HORIZONTAL_ALIGNMENT_CENTER, room, px, Color(tc, k))
		if cost >= 0:
			draw_string(font, Vector2(mid.x - room / 2.0, y + TYPE.cost + 2), str(cost), HORIZONTAL_ALIGNMENT_CENTER, room, TYPE.cost, Color(Look.PAL.hazard if on else Look.PAL.warn, k))
		if not e.get("sub", []).is_empty():
			var tip := c + dir(i * step) * (r1 - 8.0)
			var side := dir(i * step + PI / 2.0) * 6.0
			draw_colored_polygon(PackedVector2Array([tip, tip - dir(i * step) * 8.0 + side, tip - dir(i * step) * 8.0 - side]), Color(rim, 0.9 * k))
	var hub: float = (RING.inner - 8.0) * grow
	draw_circle(c, hub, Color(FILL, k))
	draw_arc(c, hub, 0.0, TAU, 48, Color(Look.PAL.cyan, 0.6 * k), 1.5, true)
	if hover >= 0:
		var e: Dictionary = items[hover]
		var on: bool = e.get("enabled", true)
		var w := hub * 1.8
		var title := tr(e.label_key)
		draw_string(bold, c + Vector2(-w / 2.0, -10), title, HORIZONTAL_ALIGNMENT_CENTER, w, fit(title, w, TYPE.name), Color(TEXT if on else DIM, k))
		var cost: int = e.get("cost", -1)
		if cost >= 0:
			draw_string(bold, c + Vector2(-w / 2.0, 14), str(cost), HORIZONTAL_ALIGNMENT_CENTER, w, TYPE.cost + 3, Color(Look.PAL.hazard if on else Look.PAL.warn, k))
		var note: String = e.get("note", "")
		if note != "":
			draw_string(font, c + Vector2(-w / 2.0, 36), note, HORIZONTAL_ALIGNMENT_CENTER, w, fit(note, w, TYPE.note), Color(Look.PAL.heal, k))
	elif trail.size() > 0:
		draw_string(font, c + Vector2(-hub, 6), tr(parent_label()), HORIZONTAL_ALIGNMENT_CENTER, hub * 2.0, TYPE.note, Color(DIM, k))


func parent_label() -> String:
	var items: Array = stack[-2]
	for e in items:
		if e.id == trail[-1]:
			return e.label_key
	return ""


func fit(s: String, room: float, px: int) -> int:
	while px > TYPE.min and bold.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > room:
		px -= 1
	return px


static func dir(a: float) -> Vector2:
	return Vector2(sin(a), -cos(a))
