extends CanvasLayer

signal picked(slot: String, key: String)
signal ui(kind: String)

const Garage = preload("res://src/garage.gd")
const PartView = preload("res://src/part_view.gd")

const SIZE := Vector2(1280, 720)
const CARD := Vector2(280, 170)
const GAP := 16.0
const COLS := 4
const TOP := 220.0

var root: Control
var bold := FontVariation.new()
var items := []
var cards := []


func _init() -> void:
	layer = 5
	visible = false
	bold.base_font = ThemeDB.fallback_font
	bold.variation_embolden = 0.7
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.03, 0.08, 0.92)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	root = Control.new()
	root.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_preset(Control.PRESET_CENTER)
	root.offset_left = -SIZE.x / 2.0
	root.offset_right = SIZE.x / 2.0
	root.offset_top = -SIZE.y / 2.0
	root.offset_bottom = SIZE.y / 2.0
	add_child(root)


## `who` names the player picking ("P2") when several do, one after another.
func open(list: Array, set_key: String, fought: int, progress, who := "") -> void:
	items = list
	clear()
	label(root, (who + " · " if who != "" else "") + tr("claimTitle"), Rect2(0, 70, SIZE.x, 64), 56, Garage.GUN, true, HORIZONTAL_ALIGNMENT_CENTER)
	label(root, tr("claimFrom").format({"name": tr("set_" + set_key), "n": fought}), Rect2(0, 140, SIZE.x, 30), 20, Garage.TEXT, false, HORIZONTAL_ALIGNMENT_CENTER)
	label(root, tr("claimHint"), Rect2(0, 640, SIZE.x, 24), 15, Garage.DIM, false, HORIZONTAL_ALIGNMENT_CENTER)
	var cols := mini(COLS, items.size())
	var x0 := (SIZE.x - (cols * CARD.x + (cols - 1) * GAP)) / 2.0
	for i in items.size():
		card(i, Vector2(x0 + (i % COLS) * (CARD.x + GAP), TOP + (i / COLS) * (CARD.y + GAP)), progress)
	visible = true
	cards[0].grab_focus()


func card(i: int, at: Vector2, progress) -> void:
	var it: Dictionary = items[i]
	var b := Button.new()
	b.position = at
	b.size = CARD
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal", Garage.plate(Garage.CARD, Garage.LINE, 1, 8))
	var glow := Color(Garage.HOLO, 0.45)
	for s in ["hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(s, Garage.plate(Garage.SEL, Garage.HI, 2, 8, glow))
	b.add_theme_stylebox_override("focus", Garage.plate(Color.TRANSPARENT, Color.WHITE, 3, 8))
	b.pressed.connect(pick.bind(i))
	b.mouse_entered.connect(ui.emit.bind("hover"))
	b.focus_entered.connect(ui.emit.bind("hover"))
	root.add_child(b)
	cards.append(b)
	var v := PartView.new()
	v.position = Vector2(8, 8)
	v.size = Vector2(110, 154)
	v.show_part(it.slot, it.key)
	b.add_child(v)
	for e in ["mouse_entered", "focus_entered"]:
		b.connect(e, v.turn.bind(true))
	for e in ["mouse_exited", "focus_exited"]:
		b.connect(e, v.turn.bind(false))
	label(b, "[%d]" % (i + 1), Rect2(126, 8, 60, 18), 13, Garage.DIM)
	label(b, tr("tab_" + it.slot), Rect2(126, 30, 146, 18), 13, Garage.LABEL)
	var title := label(b, tr("p_" + it.key), Rect2(126, 52, 146, 44), 17, Garage.TEXT, true)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var lvl: int = progress.level(it.slot, it.key)
	var gain := tr("claimNew") if lvl == 0 else tr("claimUp").format({"a": lvl, "b": lvl + 1})
	label(b, gain, Rect2(126, 128, 146, 24), 15, Garage.GOOD, true)


func label(parent: Control, s: String, r: Rect2, px: int, c: Color, heavy := false, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = s
	l.position = r.position
	l.size = r.size
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", c)
	if heavy:
		l.add_theme_font_override("font", bold)
	parent.add_child(l)
	return l


func clear() -> void:
	for c in root.get_children():
		c.queue_free()
	cards.clear()


func pick(i: int) -> void:
	var it: Dictionary = items[i]
	visible = false
	clear()
	ui.emit("equip")
	picked.emit(it.slot, it.key)


func _unhandled_key_input(e: InputEvent) -> void:
	if not visible or not e.pressed or e.echo:
		return
	var i: int = e.physical_keycode - KEY_1
	if i >= 0 and i < mini(9, items.size()):
		pick(i)
		get_viewport().set_input_as_handled()
