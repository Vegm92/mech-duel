extends CanvasLayer

signal fight(lo: Dictionary)
signal ui(kind: String)

const Sim = preload("res://src/sim.gd")
const PartView = preload("res://src/part_view.gd")
const I18n = preload("res://src/i18n.gd")

const SIZE := Vector2(1280, 720)
const PAD := 20.0
const RX := 880.0
const RW := 380.0
const AREA := RX - 16.0 - PAD
const GRID_Y := 180.0
const BOTTOM := 700.0
const SLOTS := ["head", "core", "arms", "legs", "booster", "left", "right", "set"]
const TITLES := ["gHead", "gCore", "gArms", "gLegs", "gBooster", "gLeftHand", "gRightHand", "gSets"]
const MAIN := [["mainParts", 0, 4], ["mainWeapons", 5, 6], ["mainSets", 7, 7]]
const UNIT := {"siSpeed": "vMs", "siDash": "vM", "siDashCd": "vS", "siHandling": "vPct", "siCharge": "vPct", "siVent": "vPs"}

static var SERIES_C := {"light": Color("7ef0ff"), "standard": Color("c6d4e8"), "heavy": Color("ffb45f")}
static var CARD := Color8(10, 28, 58, 235)
static var HOV := Color8(18, 46, 90, 242)
static var SEL := Color8(26, 66, 124, 247)
static var LINE := Color8(80, 150, 230, 115)
static var LINE_HOV := Color8(150, 210, 255, 178)
static var HI := Color8(160, 215, 255, 242)
static var TEXT := Color("e8f2ff")
static var DIM := Color("7fa6d6")
static var LABEL := Color("5d84b8")
static var HOLO := Color8(95, 180, 255)
static var PANEL := Color8(6, 18, 40, 240)
static var SKILL := Color("e6c8ff")
static var GUN := Color("ffd27a")
static var MELEE := Color("ff9c86")
static var GOOD := Color("7dffa8")
static var BAD := Color("ff7a6a")

var loadout: Dictionary = Sim.DEFAULT_LOADOUT.duplicate()
var tab := 0
var hover = null
var pad := false
var bold: FontVariation
var root: Control
var left: Control
var cards := []
var subs := []
var stage: PartView
var shown := {}
var hands := {}
var skill_btn: Button
var skill_name: Label
var info_rows := []
var about_title: Label
var about_desc: Label
var about_skill: Label


func _init() -> void:
	bold = FontVariation.new()
	bold.base_font = ThemeDB.fallback_font
	bold.variation_embolden = 0.7
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
	root.offset_left = -SIZE.x / 2.0
	root.offset_right = SIZE.x / 2.0
	root.offset_top = -SIZE.y / 2.0
	root.offset_bottom = SIZE.y / 2.0
	add_child(root)


func open(lo: Dictionary, at := -1) -> void:
	loadout = Sim.normalize(lo)
	if at >= 0:
		tab = at % SLOTS.size()
	hover = null
	visible = true
	build()


func build() -> void:
	for c in root.get_children():
		c.queue_free()
	left = null
	var head := panel(root, Rect2(PAD, 12, 220, 42), Color8(14, 40, 80, 242), HI, 10)
	var title := text(head, tr("garage"), Vector2(0, 0), 26, TEXT, 220, true, HORIZONTAL_ALIGNMENT_CENTER, 42)
	title.add_theme_color_override("font_shadow_color", Color(HOLO, 0.8))
	title.add_theme_constant_override("shadow_outline_size", 8)
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 0)
	text(root, tr("garageHint"), Vector2(PAD + 236, 12), 13, DIM, AREA - 236, false, HORIZONTAL_ALIGNMENT_LEFT, 42)
	build_right()
	build_tab()


func build_tab() -> void:
	if left != null:
		left.queue_free()
	left = Control.new()
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(left)
	cards.clear()
	subs.clear()
	var mt: Array = main_of(tab)
	for i in MAIN.size():
		var on: bool = MAIN[i] == mt
		var b := button(left, Rect2(PAD + i * 178, 64, 170, 34), {"tab": MAIN[i][1]}, select_tab.bind(MAIN[i][1]))
		paint(b, on)
		text(b, tr(MAIN[i][0]), Vector2.ZERO, 15, Color.WHITE if on else DIM, 170, true, HORIZONTAL_ALIGNMENT_CENTER, 34)
	var n: int = mt[2] - mt[1] + 1
	var sw := (AREA - 6.0 * (n - 1)) / n
	for j in n:
		var i: int = mt[1] + j
		var on := i == tab
		var b := button(left, Rect2(PAD + j * (sw + 6), 106, sw, 44), {"tab": i}, select_tab.bind(i))
		paint(b, on)
		text(b, tr("tab_" + SLOTS[i]), Vector2(0, 3), 13, Color.WHITE if on else TEXT, sw, true, HORIZONTAL_ALIGNMENT_CENTER)
		subs.append([i, text(b, "", Vector2(4, 22), 11, Color("bfe4ff") if on else LABEL, sw - 8, false, HORIZONTAL_ALIGNMENT_CENTER)])
	text(left, tr(TITLES[tab]), Vector2(PAD, 156), 12, HOLO, AREA, true)
	var slot: String = SLOTS[tab]
	var items: Array = Sim.SETS.keys() if slot == "set" else Sim.CATALOG[slot].keys()
	var cols := 3 if slot == "set" and items.size() > 6 else 4 if items.size() > 10 else 2
	var rows := ceili(items.size() / float(cols))
	var gap := 8.0
	var cw := (AREA - gap * (cols - 1)) / cols
	var ch := minf(110.0, (BOTTOM - GRID_Y - gap * (rows - 1)) / rows)
	for k in items.size():
		var at := Vector2(PAD + (k % cols) * (cw + gap), GRID_Y + floorf(k / float(cols)) * (ch + gap))
		card(slot, items[k], Rect2(at, Vector2(cw, ch)))
	refresh()
	if pad:
		point()


func card(slot: String, key: String, r: Rect2) -> void:
	var is_set := slot == "set"
	var p: Dictionary = Sim.SETS[key] if is_set else Sim.CATALOG[slot][key]
	var h := {"set": key} if is_set else {"slot": slot, "key": key}
	var b := button(left, r, h, equip.bind(h))
	b.focus_mode = Control.FOCUS_ALL if pad else Control.FOCUS_NONE
	b.focus_entered.connect(set_hover.bind(h))
	b.focus_exited.connect(leave.bind(h))
	var ts := r.size.y - 12.0
	panel(b, Rect2(6, 6, ts, ts), Color8(0, 10, 30, 115), Color8(80, 150, 230, 51), 4)
	var v := PartView.new()
	v.position = Vector2(6, 6)
	v.size = Vector2(ts, ts)
	b.add_child(v)
	if is_set:
		v.show_mech(p)
	else:
		v.show_part(slot, key)
	var x := ts + 16.0
	var tw := r.size.x - x - 8.0
	var title := text(b, tr(("set_" if is_set else "p_") + key), Vector2(x, 4), 14, TEXT, tw, true)
	fit(title, 14, tw, 10)
	var kind: Array
	if is_set:
		kind = [tr("setSkill"), tr("u_" + Sim.ult_of(p)), SKILL]
	elif p.has("series"):
		kind = [tr("seriesLabel"), tr("series_" + p.series), SERIES_C[p.series]]
	else:
		var gun := Sim.is_gun(p)
		kind = [tr("typeLabel"), tr("typeGun" if gun else "typeMelee"), GUN if gun else MELEE]
	var nw := ThemeDB.fallback_font.get_string_size(kind[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 6.0
	if nw + bold.get_string_size(kind[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x > tw:
		nw = 0.0
	else:
		text(b, kind[0], Vector2(x, 23), 11, LABEL)
	fit(text(b, kind[1], Vector2(x + nw, 23), 11, kind[2], tw - nw, true), 11, tw - nw, 9)
	var extra := ""
	if p.has("ult"):
		extra = tr("titleSkill").format({"name": tr("u_" + p.ult)})
	elif p.has("move"):
		extra = tr("dashMove").format({"name": tr("dm_" + p.move)})
	elif p.has("trail"):
		extra = tr("trailLine").format({"name": tr("tr_" + p.trail)})
	elif p.has("e"):
		extra = tr("eSkillLine").format({"name": tr("e_" + (p.e if p.e != "" else "none"))})
	if extra != "":
		fit(text(b, extra, Vector2(x, 41), 11, SKILL if p.has("ult") else GUN, tw, true), 11, tw, 9)
	var stats := card_stats(slot, p)
	if stats.is_empty():
		var top := 58.0 if extra != "" else 42.0
		para(b, tr(("sd_" if is_set else "d_") + key), Rect2(x, top, tw, r.size.y - top - 4), 10, DIM, 2 if extra != "" else 3)
	for i in stats.size():
		var y := r.size.y - (stats.size() - i) * 14.0 - 6.0
		text(b, tr(stats[i][0]), Vector2(x, y - 5), 10, DIM, 58)
		var bw := tw - 60.0
		rect(b, Rect2(x + 60, y + 2, bw, 5), Color8(120, 180, 255, 26))
		rect(b, Rect2(x + 60, y + 2, maxf(5.0, bw * clampf(stats[i][1], 0.0, 1.0)), 5), Color(HOLO, 0.85))
	cards.append([b, v, h, title])


func build_right() -> void:
	var tt := panel(root, Rect2(RX, 12, RW, 280), PANEL, LINE, 14)
	stage = PartView.new()
	stage.position = Vector2(4, 4)
	stage.size = Vector2(RW - 80, 272)
	tt.add_child(stage)
	stage.turn(true)
	shown = {}
	var sx := RW - 70.0
	text(tt, tr("weaponsLabel"), Vector2(sx - 8, 8), 11, DIM, 76, true, HORIZONTAL_ALIGNMENT_CENTER)
	hands.clear()
	for i in Sim.HANDS.size():
		var hand: String = Sim.HANDS[i]
		var b := button(tt, Rect2(sx, 28 + i * 66, 60, 60), {"tab": 5 + i}, select_tab.bind(5 + i))
		var v := PartView.new()
		v.position = Vector2(3, 3)
		v.size = Vector2(54, 54)
		b.add_child(v)
		text(b, tr("handL" if i == 0 else "handR"), Vector2(44, 40), 12, HI, 0, true)
		hands[hand] = [b, v, ""]
	fit(text(tt, tr("skillLabel"), Vector2(sx - 12, 166), 11, DIM, 84, true, HORIZONTAL_ALIGNMENT_CENTER), 11, 84, 8)
	skill_btn = button(tt, Rect2(sx, 186, 60, 60), {"tab": 1}, select_tab.bind(1))
	skill_name = text(skill_btn, "", Vector2(2, 0), 11, SKILL, 56, true, HORIZONTAL_ALIGNMENT_CENTER, 60)
	skill_name.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	skill_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var info := panel(root, Rect2(RX, 300, RW, 170), PANEL, LINE, 12)
	text(info, tr("mechInfo"), Vector2(14, 6), 13, HI, 0, true)
	info_rows.clear()
	var colw := (RW - 28.0) / 2.0
	for i in 12:
		var x := 14.0 + (0.0 if i < 6 else colw + 6.0)
		var y := 32.0 + (i % 6) * 22.0
		if i % 6:
			rect(info, Rect2(x, y - 2, colw - 6, 1), Color8(80, 150, 230, 31))
		info_rows.append([text(info, "", Vector2(x, y), 11, DIM, colw * 0.55), rich(info, Vector2(x, y - 1), colw - 8, 13)])
	var ab := panel(root, Rect2(RX, 478, RW, 160), PANEL, LINE, 10)
	about_title = text(ab, "", Vector2(14, 8), 15, HI, RW - 28, true)
	about_desc = para(ab, "", Rect2(14, 34, RW - 28, 68), 12, DIM, 4)
	about_skill = para(ab, "", Rect2(14, 106, RW - 28, 48), 12, SKILL, 3)
	var f := Button.new()
	f.position = Vector2(RX, 646)
	f.size = Vector2(RW, 54)
	f.focus_mode = Control.FOCUS_NONE
	f.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var glow := Color(1.0, 0.48, 0.18, 0.9)
	f.add_theme_stylebox_override("normal", plate(Color("ff9447"), Color("ffd2a8"), 2, 12, glow))
	for s in ["hover", "pressed", "hover_pressed"]:
		f.add_theme_stylebox_override(s, plate(Color("ffae6e"), Color("ffd2a8"), 2, 12, glow))
	f.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	f.pressed.connect(go)
	root.add_child(f)
	text(f, tr("fightBtn"), Vector2.ZERO, 20, Color("1a0d05"), RW, true, HORIZONTAL_ALIGNMENT_CENTER, 54)


func refresh() -> void:
	var next := next_lo()
	for c in cards:
		var on := selected(c[2])
		paint(c[0], on)
		c[3].add_theme_color_override("font_color", Color.WHITE if on else TEXT)
	for s in subs:
		s[1].text = current(s[0])
	if next != shown:
		shown = next.duplicate()
		stage.show_mech(next)
	for hand in hands:
		var row: Array = hands[hand]
		paint(row[0], tab == 5 + Sim.HANDS.find(hand))
		if row[2] != loadout[hand]:
			row[2] = loadout[hand]
			row[1].show_part(hand, loadout[hand])
	var ult := Sim.ult_of(next)
	var changing := ult != Sim.ult_of(loadout)
	skill_btn.add_theme_stylebox_override("normal", plate(SEL if tab == 1 else CARD, SKILL if changing else Color(SKILL, 0.7), 2 if changing else 1, 8, Color(SKILL, 0.5) if changing else Color.TRANSPARENT))
	skill_name.text = tr("u_" + ult)
	var px := 11
	while px > 8 and Array(skill_name.text.split(" ")).any(func(w): return bold.get_string_size(w, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > 54):
		px -= 1
	skill_name.add_theme_font_size_override("font_size", px)
	skill_name.add_theme_color_override("font_color", Color.WHITE if changing else SKILL)
	var now := sheet(loadout)
	var then := sheet(next)
	for i in now.size():
		var row: Array = now[i]
		info_rows[i][0].text = tr(row[0])
		var d: float = then[i][1] - row[1]
		var s := trend(d, row[2], row[3])
		var arrow := ""
		if s != 0:
			arrow = "[font_size=10][color=#%s]%s%s[/color][/font_size]  " % [(GOOD if s > 0 else BAD).to_html(false), "▲" if d > 0 else "▼", num(absf(d), row[2])]
		info_rows[i][1].text = "[right]%s[b]%s[/b][/right]" % [arrow, fmt(row[0], row[1], row[2])]
	about()


func about() -> void:
	var h: Dictionary = hover if hover != null else {}
	var s: String = h.get("set", "")
	if s == "" and not h.has("slot") and SLOTS[tab] == "set":
		s = set_of(loadout)
	var slot: String = h.get("slot", SLOTS[tab])
	var key: String = s if s != "" else h.get("key", loadout.get(slot, ""))
	about_title.text = ""
	about_desc.text = ""
	about_skill.text = ""
	if key == "":
		return
	about_title.text = tr(("set_" if s != "" else "p_") + key)
	about_desc.text = tr(("sd_" if s != "" else "d_") + key)
	var skill := ""
	if s != "":
		skill = Sim.ult_of(Sim.SETS[s])
	elif slot == "core":
		skill = Sim.CORES[key].ult
	if skill != "":
		about_skill.text = tr("skillDesc").format({"name": tr("titleSkill").format({"name": tr("u_" + skill)}), "desc": tr("ud_" + skill)})


func set_hover(h) -> void:
	if h == hover:
		return
	hover = h
	if h != null:
		ui.emit("hover")
	for c in cards:
		c[1].turn(c[2] == hover)
	refresh()


func leave(h: Dictionary) -> void:
	if hover == h:
		set_hover(null)


func equip(h: Dictionary) -> void:
	if h.has("set"):
		loadout = Sim.SETS[h.set].duplicate()
	else:
		loadout = Sim.normalize(loadout.merged({h.slot: h.key}, true))
	ui.emit("set" if h.has("set") else "equip")
	refresh()


func select_tab(i: int) -> void:
	tab = i
	hover = null
	ui.emit("tab")
	build_tab()


func go() -> void:
	ui.emit("start")
	fight.emit(loadout.duplicate())


func point() -> void:
	var on := cards.filter(func(c): return selected(c[2]))
	(on[0] if on else cards[0])[0].grab_focus()


func use_pad(on: bool) -> void:
	if on == pad:
		return
	pad = on
	for c in cards:
		c[0].focus_mode = Control.FOCUS_ALL if on else Control.FOCUS_NONE
	if visible and on:
		point()
	elif visible:
		get_viewport().gui_release_focus()


func _input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		use_pad(false)
	elif (e is InputEventJoypadButton and e.pressed) or (e is InputEventJoypadMotion and absf(e.axis_value) > 0.5):
		use_pad(true)


func _unhandled_input(e: InputEvent) -> void:
	if not visible or not (e is InputEventJoypadButton and e.pressed):
		return
	match e.button_index:
		JOY_BUTTON_LEFT_SHOULDER:
			select_tab((tab + SLOTS.size() - 1) % SLOTS.size())
		JOY_BUTTON_RIGHT_SHOULDER:
			select_tab((tab + 1) % SLOTS.size())
		JOY_BUTTON_START:
			go()
		_:
			return
	get_viewport().set_input_as_handled()


func _unhandled_key_input(e: InputEvent) -> void:
	if not visible or not e.pressed or e.echo:
		return
	match e.physical_keycode:
		KEY_TAB:
			select_tab((tab + (SLOTS.size() - 1 if e.shift_pressed else 1)) % SLOTS.size())
		KEY_ENTER, KEY_KP_ENTER:
			go()
		KEY_L:
			I18n.toggle()
			build()
		_:
			return
	get_viewport().set_input_as_handled()


func next_lo() -> Dictionary:
	if hover == null:
		return loadout
	if hover.has("set"):
		return Sim.SETS[hover.set]
	if hover.has("slot"):
		return Sim.normalize(loadout.merged({hover.slot: hover.key}, true))
	return loadout


func main_of(i: int) -> Array:
	for mt in MAIN:
		if i >= mt[1] and i <= mt[2]:
			return mt
	return MAIN[0]


func set_of(lo: Dictionary) -> String:
	for k in Sim.SETS:
		if Sim.SETS[k] == lo:
			return k
	return ""


func selected(h: Dictionary) -> bool:
	return set_of(loadout) == h.set if h.has("set") else loadout[h.slot] == h.key


func current(i: int) -> String:
	if SLOTS[i] == "set":
		var s := set_of(loadout)
		return tr("set_" + s) if s != "" else tr("setCustom")
	return tr("p_" + loadout[SLOTS[i]])


static func rate(cd: float) -> float:
	return log(120.0 / cd) / log(12.0)


static func card_stats(slot: String, p: Dictionary) -> Array:
	match slot:
		"head":
			return [["stArmor", p.armor / 345.0], ["stCharge", (p.surge - 0.7) / 0.65]]
		"arms":
			return [["stArmor", p.armor / 250.0], ["stHandling", (1.3 - p.handling) / 0.46]]
		"legs":
			return [["stSpeed", p.top / 9.0], ["stArmor", p.armor / 270.0]]
		"booster":
			return [["stDash", p.dash / 8.5], ["stRecharge", 200.0 / p.dashCd]]
		"left", "right":
			if Sim.is_gun(p):
				return [["stDamage", p.get("pellets", 1) * p.dmg / 120.0], ["stRange", minf(p.range, 30.0) / 30.0], ["stRate", rate(p.cd)]]
			return [["stDamage", p.dmg * p.get("hits", 1) / 150.0], ["stReach", p.range / 5.0], ["stSpeed", rate(p.cd + p.windup)]]
	return []


static func sheet(lo: Dictionary) -> Array:
	var mx := Sim.max_armor(lo)
	var c: Dictionary = Sim.CORES[lo.core]
	var legs: Dictionary = Sim.LEG_PARTS[lo.legs]
	var b: Dictionary = Sim.BOOSTERS[lo.booster]
	return [
		["siHead", mx.head, 0, false],
		["siArms", mx.rarm, 0, false],
		["siLegs", mx.legs, 0, false],
		["siTotal", mx.head + mx.rarm + mx.larm + mx.legs, 0, false],
		["siPoise", legs.poise, 0, false],
		["siCharge", 100.0 * Sim.HEADS[lo.head].surge * c.get("surgeGain", 1.0), 0, false],
		["siSpeed", legs.top * Sim.speed_of(lo) * c.get("speed", 1.0), 1, false],
		["siDash", b.dash * c.get("dashDist", 1.0), 1, false],
		["siDashCd", b.dashCd * c.get("dashCd", 1.0) / Sim.TICKS, 1, true],
		["siHandling", 100.0 / Sim.ARMS[lo.arms].handling, 0, false],
		["siVent", Sim.HEAT.vent * c.get("vent", 1.0), 0, false],
		["siWeight", Sim.weight_of(lo), 0, true],
	]


static func trend(d: float, dec: int, low: bool) -> int:
	if absf(d) < (0.05 if dec else 0.5):
		return 0
	return 1 if (d < 0 if low else d > 0) else -1


static func num(v: float, dec: int) -> String:
	return ("%." + str(dec) + "f") % v


func fmt(key: String, v: float, dec: int) -> String:
	return tr(UNIT[key]).format({"n": num(v, dec)}) if UNIT.has(key) else num(v, dec)


static func plate(fill: Color, edge: Color, width: int, cut: int, shadow := Color.TRANSPARENT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = edge
	s.set_border_width_all(width)
	s.corner_detail = 1
	s.corner_radius_top_left = cut
	s.corner_radius_bottom_right = cut
	s.shadow_color = shadow
	s.shadow_size = 10 if shadow.a > 0 else 0
	return s


func paint(b: Button, on: bool) -> void:
	var cut := 8
	b.add_theme_stylebox_override("normal", plate(SEL if on else CARD, HI if on else LINE, 2 if on else 1, cut, Color(HOLO, 0.45) if on else Color.TRANSPARENT))
	var hov := plate(SEL if on else HOV, HI if on else LINE_HOV, 2 if on else 1, cut, Color(HOLO, 0.45) if on else Color.TRANSPARENT)
	for s in ["hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(s, hov)
	var ring := plate(Color.TRANSPARENT, Color.WHITE, 2, cut)
	ring.set_expand_margin_all(3)
	b.add_theme_stylebox_override("focus", ring)


func button(parent: Control, r: Rect2, h: Dictionary, press: Callable) -> Button:
	var b := Button.new()
	b.position = r.position
	b.size = r.size
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	paint(b, false)
	b.pressed.connect(press)
	b.mouse_entered.connect(set_hover.bind(h))
	b.mouse_exited.connect(leave.bind(h))
	parent.add_child(b)
	return b


func panel(parent: Control, r: Rect2, fill: Color, edge: Color, cut: int) -> Panel:
	var p := Panel.new()
	p.position = r.position
	p.size = r.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", plate(fill, edge, 1, cut))
	parent.add_child(p)
	return p


func rect(parent: Control, r: Rect2, c: Color) -> ColorRect:
	var cr := ColorRect.new()
	cr.position = r.position
	cr.size = r.size
	cr.color = c
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(cr)
	return cr


func text(parent: Control, s: String, pos: Vector2, px: int, c: Color, w := 0.0, heavy := false, align := HORIZONTAL_ALIGNMENT_LEFT, h := 0.0) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", c)
	if heavy:
		l.add_theme_font_override("font", bold)
	if w > 0:
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.horizontal_alignment = align
		l.size.x = w
	if h > 0:
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.size.y = h
	l.position = pos
	parent.add_child(l)
	return l


func para(parent: Control, s: String, r: Rect2, px: int, c: Color, lines: int) -> Label:
	var l := text(parent, s, r.position, px, c)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.max_lines_visible = lines
	l.clip_text = true
	l.size = r.size
	return l


func fit(l: Label, px: int, w: float, low: int) -> void:
	var f := l.get_theme_font("font")
	while px > low and f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > w:
		px -= 1
	l.add_theme_font_size_override("font_size", px)


func rich(parent: Control, pos: Vector2, w: float, px: int) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_size_override("normal_font_size", px)
	r.add_theme_font_size_override("bold_font_size", px)
	r.add_theme_font_override("bold_font", bold)
	r.add_theme_color_override("default_color", TEXT)
	r.position = pos
	r.size = Vector2(w, px + 6)
	parent.add_child(r)
	return r
