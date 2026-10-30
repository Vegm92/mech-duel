extends CanvasLayer

signal picked(slot: String, key: String)
signal ui(kind: String)

const Garage = preload("res://src/garage.gd")
const PartView = preload("res://src/part_view.gd")
const Sim = preload("res://src/sim.gd")

const SIZE := Vector2(1280, 720)
const GAP := 14.0
const COLS := 5
const TOP := 176.0
const LIFT := 8.0
const ROWS := 5
const ROW := 18.0
const PW := 620.0
const PH := 130.0

var root: Control
var bold := FontVariation.new()
var items := []
var cards := []
var rest := []
var badges := []
var sel := 0
var keep_btn: Button
var keep_y := 600.0
var panel: Panel
var panel_y := 540.0
var tight := false
var lo := {}
var prog


func _init() -> void:
	layer = 5
	visible = false
	bold.base_font = ThemeDB.fallback_font
	bold.variation_embolden = 0.7
	var dim := ColorRect.new()
	dim.color = Color(Garage.A_GROUND, 0.97)
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


func open(list: Array, set_key: String, fought: int, progress, mine: Dictionary = {}) -> void:
	items = list
	prog = progress
	lo = mine if not mine.is_empty() else Sim.DEFAULT_LOADOUT
	clear()
	sel = 0
	Garage.hazard(root, Rect2(0, 0, SIZE.x, 10))
	var title := label(root, tr("claimTitle"), Rect2(64, 36, 760, 104), 84, Garage.A_HAZARD, false, HORIZONTAL_ALIGNMENT_LEFT, Garage.impact())
	title.add_theme_color_override("font_shadow_color", Color.BLACK)
	title.add_theme_constant_override("shadow_offset_x", 5)
	title.add_theme_constant_override("shadow_offset_y", 5)
	var tw := Garage.impact().get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 84).x
	label(root, tr("claimHint"), Rect2(64 + tw + 24, 98, SIZE.x - tw - 152, 24), 16, Garage.A_INK, true)
	var n := items.size()
	var rows := ceili(n / float(COLS))
	var cw := (SIZE.x - 128.0 - GAP * (COLS - 1)) / COLS
	tight = rows > 1
	var ch := 350.0 if rows == 1 else 190.0
	panel_y = TOP + rows * ch + (rows - 1) * GAP + 14.0
	keep_y = panel_y + (PH - 56.0) / 2.0
	label(root, tr("claimFrom").format({"name": tr("set_" + set_key), "n": fought}), Rect2(64 + tw + 24, 124, SIZE.x - tw - 152, 24), 14, Garage.A_DIM)
	panel = Panel.new()
	panel.position = Vector2(64, panel_y)
	panel.size = Vector2(PW, PH)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", Garage.box(Garage.A_PANEL, 14, Color.TRANSPARENT))
	root.add_child(panel)
	var cols := mini(COLS, n)
	var x0 := (SIZE.x - (cols * cw + (cols - 1) * GAP)) / 2.0
	for i in n:
		card(i, Rect2(x0 + (i % COLS) * (cw + GAP), TOP + (i / COLS) * (ch + GAP), cw, ch), progress)
	visible = true
	hot(0, true)
	cards[0].grab_focus()


func card(i: int, r: Rect2, progress) -> void:
	var it: Dictionary = items[i]
	var b := Button.new()
	b.position = r.position
	b.size = r.size
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(pick.bind(i))
	b.mouse_entered.connect(ui.emit.bind("hover"))
	b.focus_entered.connect(ui.emit.bind("hover"))
	b.mouse_entered.connect(hot.bind(i))
	b.focus_entered.connect(hot.bind(i))
	root.add_child(b)
	cards.append(b)
	rest.append(r.position)
	var bg := ColorRect.new()
	bg.size = Vector2(28, 28)
	bg.position = Vector2(14, 14)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(bg)
	var num := label(bg, str(i + 1), Rect2(0, 0, 28, 28), 16, Color.WHITE, false, HORIZONTAL_ALIGNMENT_CENTER, Garage.impact())
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badges.append([bg, num])
	var lvl: int = progress.level(it.slot, it.key)
	var fresh := lvl == 0
	var t := Garage.tag(b, tr("claimNew") if fresh else tr("claimUp").format({"a": lvl, "b": lvl + 1}), Vector2.ZERO, Garage.A_HAZARD if fresh else Garage.A_SURGE, Garage.A_GROUND)
	t.position = Vector2(r.size.x - 14.0 - t.size.x, 18)
	var th := r.size.y - (118.0 if tight else 144.0)
	var back := ColorRect.new()
	back.color = Color(Garage.A_GROUND, 0.7)
	back.position = Vector2(14, 52)
	back.size = Vector2(r.size.x - 28, th)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(back)
	var v := PartView.new()
	v.position = back.position
	v.size = back.size
	v.show_part(it.slot, it.key)
	b.add_child(v)
	for e in ["mouse_entered", "focus_entered"]:
		b.connect(e, v.turn.bind(true))
	for e in ["mouse_exited", "focus_exited"]:
		b.connect(e, v.turn.bind(false))
	label(b, tr("tab_" + it.slot).to_upper(), Rect2(14, (58 if tight else 60) + th, r.size.x - 28, 16), 11, Garage.A_DIM, true)
	var nm := label(b, tr("p_" + it.key), Rect2(14, (74 if tight else 78) + th, r.size.x - 28, 28 if tight else 52), 17 if tight else 21, Color.WHITE, false, HORIZONTAL_ALIGNMENT_LEFT, Garage.impact())
	if tight:
		nm.clip_text = true
	else:
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skin(i, false)


func skin(i: int, on: bool) -> void:
	var b: Button = cards[i]
	var fill := Garage.A_PICKED if on else Garage.A_PANEL
	var stripe := Garage.A_HAZARD if on else Color.TRANSPARENT
	b.add_theme_stylebox_override("normal", Garage.box(fill, 14, stripe))
	var hov := Garage.box(fill.lightened(0.06), 14, stripe)
	for s in ["hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(s, hov)
	var ring := Garage.plate(Color.TRANSPARENT, Color.WHITE, 3, 14)
	ring.set_expand_margin_all(3)
	b.add_theme_stylebox_override("focus", ring)
	b.position.y = rest[i].y - (LIFT if on else 0.0)
	badges[i][0].color = Garage.A_GROUND if on else Garage.A_LINE
	badges[i][1].add_theme_color_override("font_color", Garage.A_HAZARD if on else Color.WHITE)


func hot(i: int, force := false) -> void:
	if i == sel and not force:
		return
	if sel < cards.size():
		skin(sel, false)
	sel = i
	skin(i, true)
	keep()
	changes()


func after(it: Dictionary) -> Dictionary:
	var next: Dictionary = lo.merged({it.slot: it.key}, true)
	var lv: Dictionary = prog.with_levels(next).get("lv", {}).duplicate()
	lv[it.slot] = mini(Sim.MAX_LEVEL, prog.level(it.slot, it.key) + 1)
	return next.merged({"lv": lv}, true)


func changes() -> void:
	for c in panel.get_children():
		c.queue_free()
	var it: Dictionary = items[sel]
	var lvl: int = prog.level(it.slot, it.key)
	var head := tr("p_" + lo[it.slot]).to_upper() + "  →  " + tr("p_" + it.key).to_upper()
	if lo[it.slot] == it.key:
		head = tr("p_" + it.key).to_upper() + "  ·  " + tr("claimUp").format({"a": lvl, "b": lvl + 1})
	label(panel, head, Rect2(16, 8, PW - 32, 18), 12, Garage.A_HAZARD, true)
	var now := Garage.sheet(prog.with_levels(lo))
	var then := Garage.sheet(after(it))
	var n := 0
	for i in now.size():
		var row: Array = now[i]
		var d: float = then[i][1] - row[1]
		var t := Garage.trend(d, row[2], row[3])
		if t == 0 or n >= ROWS:
			continue
		var y := 32.0 + n * ROW
		var col: Color = Garage.A_GOOD if t > 0 else Garage.A_SOFT
		label(panel, tr(row[0]), Rect2(16, y, 100, ROW), 13, Garage.A_DIM)
		label(panel, "%s → %s" % [stat(row[0], row[1], row[2]), stat(row[0], then[i][1], row[2])], Rect2(116, y, 130, ROW), 13, Color.WHITE, true)
		label(panel, "%s%s" % ["▲" if d > 0 else "▼", Garage.num(absf(d), row[2])], Rect2(246, y, 60, ROW), 13, col, true)
		n += 1
	var was := skill(it.slot, lo[it.slot])
	var gets := skill(it.slot, it.key)
	var y := 32.0
	if gets != "" and gets != was:
		var line := gets if was == "" else "%s  →  %s" % [was, gets]
		label(panel, line, Rect2(326, y, PW - 342, 20), 13, Garage.A_SURGE if it.slot == "core" else Garage.A_HAZARD, true)
		y += 22.0
	var l := label(panel, "", Rect2(326, y, PW - 342, PH - y - 6), 12, Garage.A_INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.text = tr("d_" + it.key)


func skill(slot: String, key: String) -> String:
	var p: Dictionary = Sim.CATALOG.get(slot, {}).get(key, {})
	if p.has("ult"):
		return tr("titleSkill").format({"name": tr("u_" + p.ult)})
	if p.has("move"):
		return tr("dashMove").format({"name": tr("dm_" + p.move)})
	if p.has("trail"):
		return tr("trailLine").format({"name": tr("tr_" + p.trail)})
	if p.has("e"):
		return tr("eSkillLine").format({"name": tr("e_" + (p.e if p.e != "" else "none"))})
	return ""


func stat(key: String, v: float, dec: int) -> String:
	return tr(Garage.UNIT[key]).format({"n": Garage.num(v, dec)}) if Garage.UNIT.has(key) else Garage.num(v, dec)


func keep() -> void:
	if keep_btn != null:
		keep_btn.queue_free()
	var s := tr("keepBtn").format({"name": tr("p_" + items[sel].key).to_upper()})
	var w := Garage.impact().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x + 70.0
	keep_btn = Button.new()
	keep_btn.size = Vector2(w, 56)
	keep_btn.position = Vector2(SIZE.x - 64.0 - w - 5.0, keep_y)
	keep_btn.focus_mode = Control.FOCUS_NONE
	keep_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	Garage.skew(keep_btn, Garage.A_HAZARD, true)
	keep_btn.pressed.connect(pick.bind(sel))
	root.add_child(keep_btn)
	label(keep_btn, s, Rect2(0, 0, w, 56), 26, Garage.A_GROUND, false, HORIZONTAL_ALIGNMENT_CENTER, Garage.impact()).vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func label(parent: Control, s: String, r: Rect2, px: int, c: Color, heavy := false, align := HORIZONTAL_ALIGNMENT_LEFT, font: Font = null) -> Label:
	var l := Label.new()
	l.text = s
	l.position = r.position
	l.size = r.size
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", c)
	if font != null:
		l.add_theme_font_override("font", font)
	elif heavy:
		l.add_theme_font_override("font", bold)
	parent.add_child(l)
	return l


func clear() -> void:
	for c in root.get_children():
		c.queue_free()
	cards.clear()
	rest.clear()
	badges.clear()
	keep_btn = null
	panel = null


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
