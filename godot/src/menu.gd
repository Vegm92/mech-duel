extends CanvasLayer

signal picked(mode: String)
signal ui(kind: String)

const Garage = preload("res://src/garage.gd")
const I18n = preload("res://src/i18n.gd")
const Look = preload("res://src/look.gd")
const Edition = preload("res://src/edition.gd")

const SIZE := Vector2(1280, 720)
const W := 500.0
const H := 78.0
const GAP := 10.0
const TOP := 176.0

var root: Control
var buttons := []


func _init() -> void:
	layer = 6
	visible = false
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


func modes() -> Array:
	var out := ["solo", "coop", "versus", "garage"]
	if Edition.siege:
		out.append("siege")
	return out


func open() -> void:
	visible = true
	build()


func label(parent: Control, s: String, r: Rect2, px: int, c: Color, display := true, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = s
	l.position = r.position
	l.size = r.size
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", c)
	if display:
		l.add_theme_font_override("font", Garage.impact())
	parent.add_child(l)
	return l


func button(r: Rect2, mode: String) -> Button:
	var b := Button.new()
	b.position = r.position
	b.size = r.size
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal", Garage.box(Garage.A_PANEL, 14))
	for s in ["hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(s, Garage.box(Garage.A_PICKED, 14, Garage.A_HAZARD))
	var ring := Garage.plate(Color.TRANSPARENT, Color.WHITE, 3, 14)
	ring.set_expand_margin_all(3)
	b.add_theme_stylebox_override("focus", ring)
	b.pressed.connect(choose.bind(mode))
	b.focus_entered.connect(func() -> void: ui.emit("hover"))
	root.add_child(b)
	buttons.append(b)
	return b


func build() -> void:
	for c in root.get_children():
		c.queue_free()
	buttons.clear()
	Garage.hazard(root, Rect2(0, 0, SIZE.x, 8))
	var title := label(root, tr("gameTitle"), Rect2(0, 36, SIZE.x, 90), 76, Color.WHITE)
	title.add_theme_color_override("font_shadow_color", Color.BLACK)
	title.add_theme_constant_override("shadow_offset_x", 5)
	title.add_theme_constant_override("shadow_offset_y", 5)
	label(root, tr("menuPick"), Rect2(0, 126, SIZE.x, 28), 16, Garage.A_DIM, false)
	var y := TOP
	for m in modes():
		var b := button(Rect2((SIZE.x - W) / 2.0, y, W, H), m)
		label(b, tr("siegeBtn") if m == "siege" else tr("menu_" + m), Rect2(0, 8, W, 40), 32, Color.WHITE)
		label(b, tr("menuSub_" + m), Rect2(16, 48, W - 32, 22), 13, Garage.A_DIM, false)
		y += H + GAP
	var q := button(Rect2((SIZE.x - W) / 2.0, y + 6, W, 48), "quit")
	label(q, tr("menu_quit"), Rect2(0, 0, W, 48), 20, Garage.A_DIM)
	buttons[0].grab_focus.call_deferred()


func choose(mode: String) -> void:
	ui.emit("select")
	if mode == "quit":
		get_tree().quit()
		return
	visible = false
	picked.emit(mode)


func _unhandled_key_input(e: InputEvent) -> void:
	if visible and e.pressed and not e.echo and e.physical_keycode == KEY_L:
		I18n.toggle()
		build()
		get_viewport().set_input_as_handled()
