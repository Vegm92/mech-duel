extends CanvasLayer
## The first screens: players join (one device each, up to 4), then pick a mode. A mode opens the garage.

signal picked(mode: String)
signal ui(kind: String)

const Garage = preload("res://src/garage.gd")
const I18n = preload("res://src/i18n.gd")
const Look = preload("res://src/look.gd")
const Mech = preload("res://src/mech.gd")
const MODES := [["duel", "menuDuel", "menuDuelSub"], ["siege", "siegeBtn", "menuSiegeSub"], ["back", "backBtn", ""]]
const MAX := 4

var root: Control
var bold: FontVariation
var buttons := []
var page := "players"
## One input device per player, in join order; -1 = keyboard + mouse, else a gamepad id.
var players := []


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


## Shows the join screen, or the mode screen when players already joined.
func open() -> void:
	visible = true
	page = "modes" if not players.is_empty() else "players"
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
	label(root, tr("version").format({"v": ProjectSettings.get_setting("application/config/version", "dev")}), Rect2(0, 690, Garage.SIZE.x - 20, 20), 10, Garage.LABEL, false, HORIZONTAL_ALIGNMENT_RIGHT)
	if page == "players":
		build_players()
		return
	label(root, tr("menuPick"), Rect2(0, 210, Garage.SIZE.x, 24), 15, Garage.DIM)
	var y := 262.0
	for m in MODES:
		var tall := 56.0 if m[2] == "" else 92.0
		var b := button(Rect2(Garage.SIZE.x / 2.0 - 220, y, 440, tall), choose.bind(m[0]))
		if m[2] == "":
			label(b, tr(m[1]), Rect2(0, 0, 440, tall), 20, Garage.TEXT)
		else:
			label(b, tr(m[1]), Rect2(0, 16, 440, 34), 28, Garage.TEXT)
			label(b, tr(m[2]), Rect2(16, 52, 408, 22), 13, Garage.DIM, false)
		y += tall + 14.0
	buttons[0].grab_focus.call_deferred()


func build_players() -> void:
	label(root, tr("menuJoin"), Rect2(0, 210, Garage.SIZE.x, 24), 15, Garage.DIM)
	var w := 230.0
	var x0 := (Garage.SIZE.x - MAX * w - (MAX - 1) * 16.0) / 2.0
	for i in MAX:
		var on := i < players.size()
		var p := Panel.new()
		p.position = Vector2(x0 + i * (w + 16.0), 252)
		p.size = Vector2(w, 150)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_theme_stylebox_override("panel", Garage.plate(Garage.SEL if on else Garage.CARD, Mech.TEAM_LIGHT[i] if on else Garage.LINE, 2, 12))
		root.add_child(p)
		label(p, tr("playerN").format({"n": i + 1}), Rect2(0, 24, w, 50), 40, Mech.TEAM_LIGHT[i] if on else Garage.LABEL)
		var dev := tr("joinHint")
		if on:
			dev = tr("devKeys") if players[i] < 0 else tr("devPad").format({"n": players[i] + 1})
		label(p, dev, Rect2(10, 92, w - 20, 24), 15 if on else 13, Garage.TEXT if on else Garage.DIM, on)
	var go := button(Rect2(Garage.SIZE.x / 2.0 - 220, 440, 440, 64), go_modes)
	label(go, tr("menuGo"), Rect2(0, 0, 440, 64), 24, Garage.TEXT)
	var q := button(Rect2(Garage.SIZE.x / 2.0 - 220, 518, 440, 48), choose.bind("quit"))
	label(q, tr("quitBtn"), Rect2(0, 0, 440, 48), 18, Garage.TEXT)
	for b in buttons:
		b.focus_mode = Control.FOCUS_NONE


func button(r: Rect2, press: Callable) -> Button:
	var b := Button.new()
	b.position = r.position
	b.size = r.size
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal", Garage.plate(Garage.CARD, Garage.LINE, 2, 12))
	for s in ["hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(s, Garage.plate(Garage.HOV, Garage.LINE_HOV, 2, 12))
	b.add_theme_stylebox_override("focus", Garage.plate(Color.TRANSPARENT, Color.WHITE, 2, 12))
	b.pressed.connect(press)
	b.focus_entered.connect(func() -> void: ui.emit("hover"))
	root.add_child(b)
	buttons.append(b)
	return b


## Adds a device as the next player (no-op when it already joined or 4 have).
func join(dev: int) -> void:
	if dev in players or players.size() >= MAX:
		return
	players.append(dev)
	ui.emit("equip")
	build()


func drop(dev: int) -> void:
	if not dev in players:
		return
	players.erase(dev)
	ui.emit("tab")
	build()


func go_modes() -> void:
	if players.is_empty():
		players.append(-1)
	page = "modes"
	ui.emit("select")
	build()


func choose(mode: String) -> void:
	if mode == "quit":
		get_tree().quit()
		return
	if mode == "back":
		page = "players"
		ui.emit("tab")
		build()
		return
	ui.emit("select")
	picked.emit(mode)


func _input(e: InputEvent) -> void:
	if not visible:
		return
	var dev := -2
	var yes := false
	var no := false
	if e is InputEventKey and e.pressed and not e.echo:
		dev = -1
		yes = e.physical_keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
		no = e.physical_keycode == KEY_ESCAPE
	elif e is InputEventJoypadButton and e.pressed:
		dev = e.device
		yes = e.button_index in [JOY_BUTTON_A, JOY_BUTTON_START]
		no = e.button_index == JOY_BUTTON_B
	if page == "modes":
		if no:
			choose("back")
			get_viewport().set_input_as_handled()
		return
	if not yes and not no:
		return
	get_viewport().set_input_as_handled()
	if no:
		drop(dev)
	elif dev in players:
		go_modes()
	else:
		join(dev)


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
