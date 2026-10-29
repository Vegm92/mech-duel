extends CanvasLayer
## The first screen: pick a mode (Duel or Core Siege) or quit. Picking a mode opens the garage.

signal picked(mode: String)
signal ui(kind: String)

const Garage = preload("res://src/garage.gd")
const I18n = preload("res://src/i18n.gd")
const Look = preload("res://src/look.gd")
const MODES := [["duel", "menuDuel", "menuDuelSub"], ["siege", "siegeBtn", "menuSiegeSub"], ["quit", "quitBtn", ""]]

var root: Control
var bold: FontVariation
var buttons := []


func _init() -> void:
	bold = Look.font(Look.FONT.bold)
	var bg := TextureRect.new()
	var g := GradientTexture2D.new()
	g.gradient = Gradient.new()
	g.gradient.set_color(0, Color("03091a"))
	g.gradient.set_color(1, Color("0a1c3a"))
	g.fill_to = Vector2(0, 1)
	bg.texture = g
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	root = Control.new()
	root.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_preset(Control.PRESET_CENTER)
	root.offset_left = -Garage.SIZE.x / 2.0
	root.offset_right = Garage.SIZE.x / 2.0
	root.offset_top = -Garage.SIZE.y / 2.0
	root.offset_bottom = Garage.SIZE.y / 2.0
	add_child(root)


## Shows the menu with the cursor on Duel.
func open() -> void:
	visible = true
	build()


func build() -> void:
	for c in root.get_children():
		c.queue_free()
	buttons.clear()
	var title := label(root, tr("gameTitle"), Rect2(0, 120, Garage.SIZE.x, 80), 64, Garage.TEXT)
	title.add_theme_color_override("font_shadow_color", Color(Garage.HOLO, 0.8))
	title.add_theme_constant_override("shadow_outline_size", 12)
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 0)
	label(root, tr("menuPick"), Rect2(0, 210, Garage.SIZE.x, 24), 15, Garage.DIM)
	var y := 262.0
	for m in MODES:
		var tall := 56.0 if m[2] == "" else 92.0
		var b := Button.new()
		b.position = Vector2(Garage.SIZE.x / 2.0 - 220, y)
		b.size = Vector2(440, tall)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_stylebox_override("normal", Garage.plate(Garage.CARD, Garage.LINE, 2, 12))
		for s in ["hover", "pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(s, Garage.plate(Garage.HOV, Garage.LINE_HOV, 2, 12))
		b.add_theme_stylebox_override("focus", Garage.plate(Color.TRANSPARENT, Color.WHITE, 2, 12))
		b.pressed.connect(choose.bind(m[0]))
		b.focus_entered.connect(func() -> void: ui.emit("hover"))
		root.add_child(b)
		buttons.append(b)
		if m[2] == "":
			label(b, tr(m[1]), Rect2(0, 0, 440, tall), 20, Garage.TEXT)
		else:
			label(b, tr(m[1]), Rect2(0, 16, 440, 34), 28, Garage.TEXT)
			label(b, tr(m[2]), Rect2(16, 52, 408, 22), 13, Garage.DIM, false)
		y += tall + 14.0
	label(root, tr("version").format({"v": ProjectSettings.get_setting("application/config/version", "dev")}), Rect2(0, 690, Garage.SIZE.x - 20, 20), 10, Garage.LABEL, false, HORIZONTAL_ALIGNMENT_RIGHT)
	buttons[0].grab_focus.call_deferred()


func choose(mode: String) -> void:
	if mode == "quit":
		get_tree().quit()
		return
	ui.emit("select")
	picked.emit(mode)


func label(parent: Control, s: String, r: Rect2, px: int, c: Color, heavy := true, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = s
	l.position = r.position
	l.size = r.size
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", c)
	if heavy:
		l.add_theme_font_override("font", bold)
	parent.add_child(l)
	return l


func _unhandled_key_input(e: InputEvent) -> void:
	if visible and e.pressed and not e.echo and e.physical_keycode == KEY_L:
		I18n.toggle()
		build()
		get_viewport().set_input_as_handled()
