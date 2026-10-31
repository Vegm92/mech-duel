extends CanvasLayer

signal fight(lo: Dictionary)
signal ui(kind: String)

const Sim = preload("res://src/sim.gd")
const PartView = preload("res://src/part_view.gd")
const I18n = preload("res://src/i18n.gd")
const Progress = preload("res://src/progress.gd")
const Look = preload("res://src/look.gd")

const SIZE := Vector2(1280, 720)
const PAD := 20.0
const RX := 880.0
const RW := 380.0
const AREA := RX - 16.0 - PAD
const GRID_Y := 144.0
const BOTTOM := 704.0
const SKEW := 0.2126
const A_GROUND := Color("0B0A12")
const A_PANEL := Color("17141F")
const A_RAISED := Color("221E2E")
const A_PICKED := Color("2A2440")
const A_LINE := Color("34304A")
const A_DIM := Color("B3ACCB")
const A_INK := Color("D9D4EA")
const A_HAZARD := Color("FFC93C")
const A_ORANGE := Color("FF6B1A")
const A_BLUE := Color("2F9BFF")
const A_SURGE := Color("C86BFF")
const A_DANGER := Color("FF4D5E")
const A_SOFT := Color("FF8A95")
const A_GOOD := Color("39D98A")
const A_LOCKED := Color("8E87A8")
const SLOTS := ["head", "core", "arms", "legs", "booster", "left", "right", "set"]
const TITLES := ["gHead", "gCore", "gArms", "gLegs", "gBooster", "gLeftHand", "gRightHand", "gSets"]
const MAIN := [["mainParts", 0, 4], ["mainWeapons", 5, 6], ["mainSets", 7, 7]]
const CREDITS := [
	["Kenney", "kenney.nl", "CC0", "creditsKenney"],
	["Gregor Quendel", "opengameart.org/content/free-crowd-cheering-sounds", "CC BY 4.0", "creditsQuendel"],
	["Nocturnal_Vanguard", "opengameart.org/content/oooooooooooooo", "CC0", "creditsNocturnal"],
]
const UNIT := {"siSpeed": "vMs", "siDash": "vM", "siDashCd": "vS", "siHandling": "vPct", "siCharge": "vPct", "siVent": "vPs"}

static var SERIES_C := {"light": Color("7ef0ff"), "standard": Color("c6d4e8"), "heavy": Color("ffb45f")}
static var CARD := Color8(10, 28, 58, 235)
static var HOV := Color8(18, 46, 90, 242)
static var SEL := Color8(26, 66, 124, 247)
static var LINE := Color8(80, 150, 230, 115)
static var LINE_HOV := Color8(150, 210, 255, 178)
static var HI := Color8(160, 215, 255, 242)
static var TEXT := Color.WHITE
static var DIM := A_DIM
static var LABEL := A_LOCKED
static var HOLO := Color8(95, 180, 255)
static var PANEL := Color8(6, 18, 40, 240)
static var SKILL := A_SURGE
static var GUN := A_HAZARD
static var MELEE := A_ORANGE
static var GOOD := A_GOOD
static var BAD := A_DANGER

var loadout: Dictionary = Sim.DEFAULT_LOADOUT.duplicate()
var credits: Control
var progress := Progress.new()
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
	bold = Look.font(Look.FONT.bold)
	var bg := ColorRect.new()
	bg.color = A_GROUND
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
	loadout = progress.fit(lo)
	if at >= 0:
		tab = at % SLOTS.size()
	hover = null
	visible = true
	build()


func build() -> void:
	for c in root.get_children():
		c.queue_free()
	left = null
	credits = null
	hazard(root, Rect2(0, 0, SIZE.x, 8))
	var title := big(root, tr("garage"), Vector2(PAD, 12), 42, Color.WHITE, 220, 56)
	title.add_theme_color_override("font_shadow_color", Color.BLACK)
	title.add_theme_constant_override("shadow_offset_x", 4)
	title.add_theme_constant_override("shadow_offset_y", 4)
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
		var b := button(left, Rect2(250 + i * 146, 18, 140, 40), {"tab": MAIN[i][1]}, select_tab.bind(MAIN[i][1]))
		skew(b, Color.WHITE if on else A_RAISED)
		text(b, tr(MAIN[i][0]).to_upper(), Vector2.ZERO, 15, A_GROUND if on else A_DIM, 140, true, HORIZONTAL_ALIGNMENT_CENTER, 40)
	var n: int = mt[2] - mt[1] + 1
	var sw := 150.0
	for j in n:
		var i: int = mt[1] + j
		var on := i == tab
		var b := button(left, Rect2(PAD + j * (sw + 6), 72, sw, 44), {"tab": i}, select_tab.bind(i))
		skew(b, A_HAZARD if on else A_RAISED)
		text(b, tr("tab_" + SLOTS[i]).to_upper(), Vector2(0, 4), 13, A_GROUND if on else A_DIM, sw, true, HORIZONTAL_ALIGNMENT_CENTER)
		subs.append([i, text(b, "", Vector2(4, 24), 11, Color(A_GROUND, 0.75) if on else A_LOCKED, sw - 8, false, HORIZONTAL_ALIGNMENT_CENTER)])
	text(left, tr(TITLES[tab]), Vector2(PAD, 120), 12, A_DIM, AREA, true)
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
	panel(b, Rect2(6, 6, ts, ts), Color(A_GROUND, 0.7), 4)
	var v := PartView.new()
	v.position = Vector2(6, 6)
	v.size = Vector2(ts, ts)
	b.add_child(v)
	if is_set:
		v.show_mech(p)
	else:
		v.show_part(slot, key)
	var lock := locked(h)
	if lock:
		v.modulate = Color(0.1, 0.12, 0.18)
	var x := ts + 16.0
	var tw := r.size.x - x - 8.0
	var lvl := 0 if is_set else progress.level(slot, key)
	var worn := tag(b, tr("equippedTag"), Vector2(8, ts - 12), A_HAZARD, A_GROUND)
	worn.visible = not lock and selected(h)
	if lock:
		tag(b, tr("lockedTag"), Vector2(8, ts - 12), A_LINE, A_DIM)
	if lvl > 1 and not lock:
		var mk := tr("mk").format({"n": lvl})
		var mkw := bold.get_string_size(mk, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 2.0
		text(b, mk, Vector2(r.size.x - mkw - 8.0, 6), 11, A_DIM, mkw, true, HORIZONTAL_ALIGNMENT_RIGHT)
		tw -= mkw
	var title := text(b, tr(("set_" if is_set else "p_") + key), Vector2(x, 4), 15, A_LOCKED if lock else Color.WHITE, tw, true)
	title.add_theme_font_override("font", impact(false))
	fit(title, 15, tw, 10)
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
		text(b, tr(stats[i][0]), Vector2(x, y - 5), 10, A_DIM, 58)
		var bw := tw - 60.0
		rect(b, Rect2(x + 60, y + 2, bw, 5), A_LINE)
		rect(b, Rect2(x + 60, y + 2, maxf(5.0, bw * clampf(stats[i][1], 0.0, 1.0)), 5), A_LOCKED if lock else Color.WHITE)
	cards.append([b, v, h, title, worn])


func build_right() -> void:
	var tt := panel(root, Rect2(RX, 74, RW, 252), A_PANEL, 14)
	stage = PartView.new()
	stage.position = Vector2(4, 4)
	stage.size = Vector2(RW - 80, 244)
	tt.add_child(stage)
	stage.turn(true)
	shown = {}
	var sx := RW - 70.0
	text(tt, tr("weaponsLabel"), Vector2(sx - 8, 8), 11, A_DIM, 76, true, HORIZONTAL_ALIGNMENT_CENTER)
	hands.clear()
	for i in Sim.HANDS.size():
		var hand: String = Sim.HANDS[i]
		var b := button(tt, Rect2(sx, 28 + i * 66, 60, 60), {"tab": 5 + i}, select_tab.bind(5 + i))
		var v := PartView.new()
		v.position = Vector2(3, 3)
		v.size = Vector2(54, 54)
		b.add_child(v)
		text(b, tr("handL" if i == 0 else "handR"), Vector2(44, 40), 12, A_HAZARD, 0, true)
		hands[hand] = [b, v, ""]
	fit(text(tt, tr("skillLabel"), Vector2(sx - 12, 166), 11, A_DIM, 84, true, HORIZONTAL_ALIGNMENT_CENTER), 11, 84, 8)
	skill_btn = button(tt, Rect2(sx, 186, 60, 60), {"tab": 1}, select_tab.bind(1))
	skill_name = text(skill_btn, "", Vector2(2, 0), 11, SKILL, 56, true, HORIZONTAL_ALIGNMENT_CENTER, 60)
	skill_name.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	skill_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var info := panel(root, Rect2(RX, 334, RW, 170), A_PANEL, 12)
	big(info, tr("mechInfo"), Vector2(14, 5), 16, Color.WHITE, 0, 24)
	info_rows.clear()
	var colw := (RW - 28.0) / 2.0
	for i in 12:
		var x := 14.0 + (0.0 if i < 6 else colw + 6.0)
		var y := 32.0 + (i % 6) * 22.0
		if i % 6:
			rect(info, Rect2(x, y - 2, colw - 6, 1), A_LINE)
		info_rows.append([text(info, "", Vector2(x, y), 11, A_DIM, colw * 0.55, true), rich(info, Vector2(x, y - 1), colw - 8, 13)])
	var ab := panel(root, Rect2(RX, 512, RW, 160), A_PANEL, 12)
	about_title = big(ab, "", Vector2(14, 6), 18, Color.WHITE, RW - 28, 26)
	about_desc = para(ab, "", Rect2(14, 36, RW - 28, 66), 12, A_INK, 4)
	about_skill = para(ab, "", Rect2(14, 106, RW - 28, 48), 12, SKILL, 3)
	text(root, tr("garageHint"), Vector2(RX, 678), 12, A_DIM, RW)
	var cb := Button.new()
	cb.position = Vector2(RX + RW - 124, 338)
	cb.size = Vector2(110, 24)
	cb.focus_mode = Control.FOCUS_NONE
	cb.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	skew(cb, A_RAISED)
	cb.pressed.connect(open_credits)
	root.add_child(cb)
	big(cb, tr("creditsBtn"), Vector2.ZERO, 13, A_DIM, 110, 24, true)
	var f := Button.new()
	f.position = Vector2(RX + RW - 190, 12)
	f.size = Vector2(190 - 5, 52)
	f.focus_mode = Control.FOCUS_NONE
	f.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	skew(f, A_HAZARD, true)
	f.pressed.connect(go)
	root.add_child(f)
	big(f, tr("garageDone"), Vector2.ZERO, 30, A_GROUND, f.size.x, 52, true)


func refresh() -> void:
	var next := next_lo()
	for c in cards:
		var on := selected(c[2])
		paint(c[0], on)
		c[4].visible = on and not locked(c[2])
	for s in subs:
		s[1].text = current(s[0])
	if next != shown:
		shown = next.duplicate()
		stage.show_mech(next)
	for hand in hands:
		var row: Array = hands[hand]
		paint(row[0], tab == 5 + Sim.HANDS.find(hand), A_RAISED)
		if row[2] != loadout[hand]:
			row[2] = loadout[hand]
			row[1].show_part(hand, loadout[hand])
	var ult := Sim.ult_of(next)
	var changing := ult != Sim.ult_of(loadout)
	paint(skill_btn, tab == 1, A_RAISED)
	if changing:
		skill_btn.add_theme_stylebox_override("normal", box(A_PICKED if tab == 1 else A_RAISED, 12, SKILL))
	skill_name.text = tr("u_" + ult)
	var px := 11
	while px > 8 and Array(skill_name.text.split(" ")).any(func(w): return bold.get_string_size(w, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > 54):
		px -= 1
	skill_name.add_theme_font_size_override("font_size", px)
	skill_name.add_theme_color_override("font_color", Color.WHITE if changing else SKILL)
	var now := sheet(progress.with_levels(loadout))
	var then := sheet(progress.with_levels(next))
	for i in now.size():
		var row: Array = now[i]
		info_rows[i][0].text = tr(row[0])
		var d: float = then[i][1] - row[1]
		var s := trend(d, row[2], row[3])
		var arrow := ""
		if s != 0:
			arrow = "[font_size=10][color=#%s]%s%s[/color][/font_size]  " % [(GOOD if s > 0 else A_SOFT).to_html(false), "▲" if d > 0 else "▼", num(absf(d), row[2])]
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
	var part: Dictionary = {"set": s} if s != "" else {"slot": slot, "key": key}
	if locked(part):
		about_title.text += "  ·  " + tr("lockedTag")
	elif s == "" and progress.level(slot, key) > 1:
		about_title.text += "  ·  " + tr("mk").format({"n": progress.level(slot, key)})
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


func locked(h: Dictionary) -> bool:
	if h.has("set"):
		return not progress.complete(Sim.SETS[h.set])
	return not progress.has(h.slot, h.key)


func equip(h: Dictionary) -> void:
	if locked(h):
		return
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


func open_credits() -> void:
	ui.emit("tab")
	close_credits()
	credits = Control.new()
	credits.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(credits)
	rect(credits, Rect2(Vector2.ZERO, SIZE), A_GROUND)
	hazard(credits, Rect2(0, 0, SIZE.x, 8))
	big(credits, tr("creditsTitle"), Vector2(60, 30), 54, Color.WHITE, 0, 70)
	text(credits, tr("creditsSound"), Vector2(60, 124), 14, A_HAZARD, 0, true)
	for i in CREDITS.size():
		var c: Array = CREDITS[i]
		var y := 156.0 + i * 130.0
		panel(credits, Rect2(60, y, SIZE.x - 120, 116), A_PANEL, 12)
		big(credits, c[0], Vector2(84, y + 10), 28, Color.WHITE, 0, 36)
		text(credits, c[2], Vector2(SIZE.x - 84 - 120, y + 16), 18, A_HAZARD if c[2] != "CC0" else A_GOOD, 120, true, HORIZONTAL_ALIGNMENT_RIGHT)
		text(credits, c[1], Vector2(84, y + 48), 13, A_BLUE)
		para(credits, tr(c[3]), Rect2(84, y + 72, SIZE.x - 168, 40), 14, A_INK, 2)
	var back := button(credits, Rect2(SIZE.x - 260, SIZE.y - 60, 200, 40), {}, close_credits)
	back.focus_mode = Control.FOCUS_NONE
	text(back, tr("creditsBack"), Vector2.ZERO, 15, A_DIM, 200, true, HORIZONTAL_ALIGNMENT_CENTER, 40)


func close_credits() -> void:
	if credits != null:
		credits.queue_free()
		credits = null


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
	if credits != null:
		if e.button_index in [JOY_BUTTON_B, JOY_BUTTON_A, JOY_BUTTON_START]:
			close_credits()
		get_viewport().set_input_as_handled()
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
	if credits != null:
		if e.physical_keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER]:
			close_credits()
		get_viewport().set_input_as_handled()
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
	var lv: Dictionary = lo.get("lv", {})
	var mx := Sim.max_armor(lo)
	var head := Sim.tuned("head", lo.head, lv.get("head", 1))
	var c := Sim.tuned("core", lo.core, lv.get("core", 1))
	var arms := Sim.tuned("arms", lo.arms, lv.get("arms", 1))
	var legs := Sim.tuned("legs", lo.legs, lv.get("legs", 1))
	var b := Sim.tuned("booster", lo.booster, lv.get("booster", 1))
	return [
		["siHead", mx.head, 0, false],
		["siArms", mx.rarm, 0, false],
		["siLegs", mx.legs, 0, false],
		["siTotal", mx.head + mx.rarm + mx.larm + mx.legs, 0, false],
		["siPoise", legs.poise, 0, false],
		["siCharge", 100.0 * head.surge * c.get("surgeGain", 1.0), 0, false],
		["siSpeed", legs.top * Sim.speed_of(lo) * c.get("speed", 1.0), 1, false],
		["siDash", b.dash * c.get("dashDist", 1.0), 1, false],
		["siDashCd", b.dashCd * c.get("dashCd", 1.0) / Sim.TICKS, 1, true],
		["siHandling", 100.0 / arms.handling, 0, false],
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


func paint(b: Button, on: bool, base := A_PANEL) -> void:
	var fill := A_PICKED if on else base
	var stripe := A_HAZARD if on else Color.TRANSPARENT
	b.add_theme_stylebox_override("normal", box(fill, 12, stripe))
	var hov := box(fill.lightened(0.1), 12, stripe)
	for s in ["hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(s, hov)
	var ring := plate(Color.TRANSPARENT, Color.WHITE, 2, 12)
	ring.set_expand_margin_all(3)
	b.add_theme_stylebox_override("focus", ring)


static func box(fill: Color, cut: int, stripe := Color.TRANSPARENT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.corner_detail = 1
	s.corner_radius_top_left = cut
	s.corner_radius_bottom_right = cut
	if stripe.a > 0:
		s.border_width_top = 4
		s.border_color = stripe
	return s


static func impact(heavy := true) -> FontVariation:
	return Look.font(Look.FONT.heavy if heavy else Look.FONT.bold, true, Look.FONT.impact)


static func skew(b: Button, fill: Color, shadow := false) -> Polygon2D:
	for s in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	var sk := b.size.y * SKEW
	var pts := PackedVector2Array([Vector2(sk, 0), Vector2(b.size.x, 0), Vector2(b.size.x - sk, b.size.y), Vector2(0, b.size.y)])
	if shadow:
		var sh := Polygon2D.new()
		sh.polygon = pts
		sh.position = Vector2(5, 5)
		sh.color = Color.BLACK
		b.add_child(sh)
	var p := Polygon2D.new()
	p.polygon = pts
	p.color = fill
	b.add_child(p)
	b.mouse_entered.connect(func(): p.color = fill.lightened(0.12))
	b.mouse_exited.connect(func(): p.color = fill)
	return p


static func hazard(parent: Control, r: Rect2) -> Control:
	var c := Control.new()
	c.position = r.position
	c.size = r.size
	c.clip_contents = true
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		c.draw_rect(Rect2(Vector2.ZERO, r.size), A_GROUND)
		var x := -r.size.y
		while x < r.size.x:
			c.draw_colored_polygon(PackedVector2Array([Vector2(x, r.size.y), Vector2(x + 14.14, r.size.y), Vector2(x + 14.14 + r.size.y, 0), Vector2(x + r.size.y, 0)]), A_HAZARD)
			x += 28.28)
	parent.add_child(c)
	return c


static func tag(parent: Control, s: String, at: Vector2, fill: Color, ink: Color) -> Control:
	var f := Look.font(Look.FONT.bold)
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 12.0
	var c := ColorRect.new()
	c.color = fill
	c.position = at
	c.size = Vector2(w, 16)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var y := (16.0 - f.get_height(10)) / 2.0 + f.get_ascent(10)
	c.draw.connect(func(): c.draw_string(f, Vector2(0, y), s, HORIZONTAL_ALIGNMENT_CENTER, w, 10, ink))
	parent.add_child(c)
	return c


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


func panel(parent: Control, r: Rect2, fill: Color, cut: int) -> Panel:
	var p := Panel.new()
	p.position = r.position
	p.size = r.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", box(fill, cut))
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


func big(parent: Control, s: String, pos: Vector2, px: int, c: Color, w := 0.0, h := 0.0, center := false) -> Label:
	var l := text(parent, s, pos, px, c, w, false, HORIZONTAL_ALIGNMENT_CENTER if center else HORIZONTAL_ALIGNMENT_LEFT, h)
	l.add_theme_font_override("font", impact())
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
	r.add_theme_color_override("default_color", Color.WHITE)
	r.position = pos
	r.size = Vector2(w, px + 6)
	parent.add_child(r)
	return r
