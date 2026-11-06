extends CanvasLayer

const Sim = preload("res://src/sim.gd")
const Mech = preload("res://src/mech.gd")
const Garage = preload("res://src/garage.gd")
const Sfx = preload("res://src/sfx.gd")
const Look = preload("res://src/look.gd")
const Edition = preload("res://src/edition.gd")

const PANEL := Color(0.04, 0.11, 0.23, 0.82)
const EDGE := Color(0.31, 0.59, 0.9, 0.5)
const TEXT := Color(0.91, 0.95, 1.0)
const DIM := Color(0.5, 0.65, 0.84)
const SURGE_C := Color(0.77, 0.55, 1.0)
const HEAT_C := Color(1.0, 0.36, 0.24)
const WIRE := Color8(94, 240, 232)
const ACCENT := Color8(255, 154, 60)
const SEG_OFF := Color(0.24, 0.35, 0.5)
const REC := Color8(255, 59, 48)
const BARS := 0.08
const PANEL_SIZE := Vector2(220, 142)
const SLOT := Vector2(84, 58)
const NUMBER := {"size": 42, "scale": {"hit": 1.0, "head": 1.2, "block": 0.75, "heal": 1.0}, "outline": 8, "glow": 24, "rise": 1.6, "life": 45, "fade": 18, "pop": 1.4, "snap": 7}
const FIG := Transform2D(0, Vector2(0.6, 0.6), 0, Vector2(23, 5))
const PARTS := ["head", "larm", "rarm", "legs"]
const SHAPES := {
	"head": [[Vector2(135, 50), Vector2(155, 50), Vector2(160, 58), Vector2(158, 68), Vector2(132, 68), Vector2(130, 58), Vector2(135, 50)], [Vector2(136, 60), Vector2(154, 60)], [Vector2(153, 50), Vector2(153, 42)]],
	"core": [[Vector2(124, 73), Vector2(166, 73), Vector2(170, 92), Vector2(160, 106), Vector2(130, 106), Vector2(120, 92), Vector2(124, 73)], [Vector2(136, 78), Vector2(154, 78), Vector2(154, 98), Vector2(136, 98), Vector2(136, 78)], [Vector2(139, 106), Vector2(151, 106), Vector2(149, 114), Vector2(141, 114), Vector2(139, 106)]],
	"larm": [[Vector2(112, 82), Vector2(120, 90), Vector2(92, 120), Vector2(84, 112), Vector2(112, 82)]],
	"rarm": [[Vector2(178, 82), Vector2(170, 90), Vector2(198, 120), Vector2(206, 112), Vector2(178, 82)]],
	"legs": [[Vector2(128, 116), Vector2(140, 116), Vector2(140, 152), Vector2(126, 152), Vector2(128, 116)], [Vector2(150, 116), Vector2(162, 116), Vector2(164, 152), Vector2(150, 152), Vector2(150, 116)]],
}
const BROKEN := {"head": Rect2(134, 50, 22, 18), "larm": Rect2(88, 92, 24, 24), "rarm": Rect2(178, 92, 24, 24), "legs": Rect2(128, 120, 34, 30)}
const READOUT := {
	"head": [Vector2(128, 38), 46.0, Vector2(150, 45), HORIZONTAL_ALIGNMENT_RIGHT],
	"larm": [Vector2(10, 71), 52.0, Vector2(10, 66), HORIZONTAL_ALIGNMENT_LEFT],
	"rarm": [Vector2(158, 71), 52.0, Vector2(150, 66), HORIZONTAL_ALIGNMENT_RIGHT],
	"legs": [Vector2(85, 99), 50.0, Vector2(80, 120), HORIZONTAL_ALIGNMENT_CENTER],
}
const WALLET := ["kit", "coolant", "surge", "reinforce", "revive"]
const TIER_ROWS := ["left", "right", "head", "arms", "legs", "booster", "core"]
const A := Look.ARCADE
const STRIP := Vector2(262, 44)
const STRIP_GAP := 8.0
const STRIP_TOP := 74.0
const STRIP_CLOCK := 60.0
const STRIP_BOT := 0.66
const SIDE := Vector2(176, 208)
const DIAGRAM := [["head", Rect2(40, 0, 36, 24)], ["larm", Rect2(6, 28, 22, 56)], ["rarm", Rect2(88, 28, 22, 56)], ["legs", Rect2(33, 72, 22, 56)], ["legs", Rect2(61, 72, 22, 56)]]
const MINI := [["head", Rect2(23, 0, 14, 10)], ["larm", Rect2(9, 12, 8, 24)], ["rarm", Rect2(43, 12, 8, 24)], ["legs", Rect2(20, 30, 9, 22)], ["legs", Rect2(31, 30, 9, 22)]]
const SLOT_KEYS := ["left", "right", "shield", "hook", "dash", "ult"]
const SIEGE_LEFT := 262.0
const ROW_W := 230.0
const KEYS := {"left": ["kLmb", "capLt"], "right": ["kRmb", "capRt"], "shield": ["capQ", "capRb"], "hook": ["capE", "capL3"], "dash": ["capSpace", "capLb"], "ult": ["capR", "capR3"]}
const SLOTS := [["left", "capLmb", "capLt"], ["right", "capRmb", "capRt"], ["shield", "capQ", "capRb"], ["hook", "capE", "capL3"], ["dash", "capSpace", "capLb"], ["ult", "capR", "capR3"]]

signal resume
signal restart
signal quit
signal ui(kind: String)

var state: Dictionary
var view: Node3D
var paused := false
var pad := false
var humans := 1
var Siege
var SHOP: Array = []
var canvas: Control
var font: Font
var bold: FontVariation
var heavy: FontVariation
var semi: FontVariation
var label_f: FontVariation
var top := {}
var last := {}
var menu: VBoxContainer
var sound: VBoxContainer
var values: Array[Label] = []
var replay := -1.0
var who := Vector2i(-1, -1)
var rounds := []
var fade := 1.0
var cd_peak := {}
var calls_bottom := 0.0
var hp_was := {}
var best := 0
var hurt_at := {}


func _init() -> void:
	if Edition.siege:
		Siege = load("res://src/siege.gd")
		SHOP = Siege.WHEEL.plaza


func _ready() -> void:
	font = Look.font(Look.FONT.text)
	bold = Look.font(Look.FONT.bold)
	heavy = Look.font(Look.FONT.heavy, true, Look.FONT.impact)
	semi = Look.font(800, true, Look.FONT.impact)
	label_f = Look.font(700)
	canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(paint)
	add_child(canvas)
	menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation", 10)
	menu.set_anchors_preset(Control.PRESET_TOP_LEFT)
	menu.position = Vector2(120, 300)
	for row in [["mResume", resume, Vector2(380, 64)], ["mRestart", restart, Vector2(350, 52)], ["mGarage", quit, Vector2(320, 52)]]:
		var b := Button.new()
		b.set_meta("key", row[0])
		b.custom_minimum_size = row[2]
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for s in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			b.add_theme_stylebox_override(s, StyleBoxEmpty.new())
		b.pressed.connect(row[1].emit)
		b.pressed.connect(ui.emit.bind("select"))
		b.mouse_entered.connect(ui.emit.bind("hover"))
		b.focus_entered.connect(ui.emit.bind("hover"))
		menu.add_child(b)
	menu.visible = false
	add_child(menu)
	sound = VBoxContainer.new()
	sound.add_theme_constant_override("separation", 14)
	sound.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	sound.offset_left = -554
	sound.offset_right = -146
	sound.offset_top = 362
	var vol := Sfx.volumes()
	var img := Image.create_empty(12, 28, false, Image.FORMAT_RGBA8)
	img.fill(A.hazard)
	var grab := ImageTexture.create_from_image(img)
	var track := StyleBoxFlat.new()
	track.bg_color = A.line
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	var fill := StyleBoxFlat.new()
	fill.bg_color = A.hazard
	fill.content_margin_top = 4
	fill.content_margin_bottom = 4
	for row in [["vMaster", "Master"], ["vMusic", "Music"], ["vSfx", "SFX"], ["vEnv", "Env"], ["vCrowd", "Crowd"]]:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		var l := Label.new()
		l.set_meta("key", row[0])
		l.custom_minimum_size = Vector2(90, 0)
		l.add_theme_font_override("font", label_f)
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", A.dim)
		line.add_child(l)
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		s.value = vol[row[1]]
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		s.custom_minimum_size = Vector2(0, 28)
		s.add_theme_stylebox_override("slider", track)
		s.add_theme_stylebox_override("grabber_area", fill)
		s.add_theme_stylebox_override("grabber_area_highlight", fill)
		for ic in ["grabber", "grabber_highlight", "grabber_disabled"]:
			s.add_theme_icon_override(ic, grab)
		var v := Label.new()
		v.custom_minimum_size = Vector2(40, 0)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v.add_theme_font_override("font", label_f)
		v.add_theme_font_size_override("font_size", 13)
		v.text = str(roundi(s.value * 100.0))
		values.append(v)
		var bus: String = row[1]
		s.value_changed.connect(func(x: float) -> void:
			Sfx.set_volume(bus, x)
			v.text = str(roundi(x * 100.0)))
		s.drag_ended.connect(func(_c: bool) -> void: ui.emit("select"))
		line.add_child(s)
		line.add_child(v)
		sound.add_child(line)
	sound.visible = false
	add_child(sound)


func _process(_dt: float) -> void:
	var was := menu.visible
	menu.visible = paused and visible
	sound.visible = menu.visible
	if menu.visible and not was:
		menu.get_child(0).grab_focus()
	for line in sound.get_children():
		var l: Label = line.get_child(0)
		l.text = tr(l.get_meta("key")).to_upper()
	if not state.is_empty() and not state.has("siege"):
		if state.round == 1 and state.phase == "countdown":
			rounds.clear()
		if state.phase == "ko" and rounds.size() < state.round:
			rounds.append({"winner": state.winner, "time": state.finalKo < 0})
	while view != null and view.pops.size() and view.tick - view.pops[0].at >= NUMBER.life:
		view.pops.pop_front()
	canvas.queue_redraw()


func plate(r: Rect2, fill := PANEL) -> void:
	canvas.draw_style_box(Garage.plate(fill, EDGE, 1, 8), r)


func label(s: String, pos: Vector2, size: int, c: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, outline := 0, f: Font = null, glow := 0) -> void:
	if f == null:
		f = font
	if glow > 0:
		canvas.draw_string_outline(f, pos, s, align, width, size, glow, Color(c, 0.15 * c.a))
		canvas.draw_string_outline(f, pos, s, align, width, size, roundi(glow * 0.6), Color(c, 0.35 * c.a))
	if outline > 0:
		canvas.draw_string_outline(f, pos, s, align, width, size, outline, Color(0, 0, 0, c.a))
	canvas.draw_string(f, pos, s, align, width, size, c)


func hp_color(f: float) -> Color:
	if f <= 0:
		return Color8(58, 63, 72)
	if f > 0.5:
		return Color8(46, 232, 160)
	return Color8(232, 192, 80) if f > 0.25 else Color8(255, 90, 60)


func paint() -> void:
	if state.is_empty():
		return
	var size := canvas.size
	if view != null:
		pops()
	if replay >= 0.0:
		replay_bars(size)
	elif state.has("siege"):
		siege_top(size)
		siege_left(size)
		siege_marks(size)
		if not paused:
			side_panel(state.mechs[0], Vector2(16, size.y - 16 - SIDE.y))
			if build_phase() and not shop_open():
				siege_shop(size)
			siege_crate(size)
		if state.phase != "over":
			siege_calls(size)
			siege_down(size)
		else:
			calls_bottom = 0.0
			siege_over(size)
	else:
		top_bar(size)
		if not paused:
			skill_bars(size)
		callouts(size)
	if paused:
		pause_screen(size)


func pops() -> void:
	var cam := get_viewport().get_camera_3d()
	for n in view.pops:
		var t := float(view.tick - n.at)
		var p: Vector3 = n.p + Vector3(0, NUMBER.rise * (1.0 - pow(1.0 - t / NUMBER.life, 2.0)), 0)
		if cam.is_position_behind(p):
			continue
		var s := lerpf(NUMBER.pop, 1.0, minf(t / NUMBER.snap, 1.0))
		var px := roundi(NUMBER.size * NUMBER.scale[n.k])
		var c := Color(Look.POP[n.k], clampf((NUMBER.life - t) / (NUMBER.life - NUMBER.fade), 0.0, 1.0))
		canvas.draw_set_transform(cam.unproject_position(p), 0.0, Vector2(s, s))
		var o := Vector2.ONE * roundf(px * 0.09)
		label(n.text, Vector2(-200, px * 0.35) + o, px, Color(0, 0, 0, c.a), HORIZONTAL_ALIGNMENT_CENTER, 400.0, 0, heavy)
		label(n.text, Vector2(-200, px * 0.35), px, c, HORIZONTAL_ALIGNMENT_CENTER, 400.0, 0, heavy)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)


func ac(c: Color) -> Color:
	return Color(c, c.a * fade)


func poly(pts: PackedVector2Array, c: Color) -> void:
	canvas.draw_colored_polygon(pts, ac(c))


func rect_poly(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


func cut(r: Rect2, n: float) -> PackedVector2Array:
	return PackedVector2Array([r.position + Vector2(n, 0), Vector2(r.end.x, r.position.y), r.end - Vector2(0, n), r.end - Vector2(n, 0), Vector2(r.position.x, r.end.y), r.position + Vector2(0, n)])


func slant(r: Rect2, deg: float) -> PackedVector2Array:
	var o := tan(deg_to_rad(absf(deg))) * r.size.y
	if deg < 0.0:
		return PackedVector2Array([Vector2(r.position.x + o, r.position.y), Vector2(r.end.x, r.position.y), Vector2(r.end.x - o, r.end.y), Vector2(r.position.x, r.end.y)])
	return PackedVector2Array([r.position, Vector2(r.end.x - o, r.position.y), Vector2(r.end.x, r.end.y), Vector2(r.position.x + o, r.end.y)])


func stripes(clip: PackedVector2Array, r: Rect2, c1: Color, c2: Color, period: float, lean: float) -> void:
	poly(clip, c2)
	var x := r.position.x - absf(lean) - period
	while x < r.end.x:
		var band := PackedVector2Array([Vector2(x, r.end.y), Vector2(x + period, r.end.y), Vector2(x + period + lean, r.position.y), Vector2(x + lean, r.position.y)])
		var lo := minf(x, x + lean)
		if lo >= r.position.x and maxf(x + period, x + period + lean) <= r.end.x:
			poly(band, c1)
		else:
			for p in Geometry2D.intersect_polygons(band, clip):
				poly(p, c1)
		x += period * 2.0


func hazard(r: Rect2) -> void:
	stripes(rect_poly(r), r, A.hazard, A.ground, r.size.y * 1.4, r.size.y)


func txt(s: String, pos: Vector2, size: int, c: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, f: Font = null, shadow := 0.0) -> void:
	if f == null:
		f = label_f
	if shadow > 0.0:
		canvas.draw_string(f, pos + Vector2.ONE * shadow, s, align, width, size, ac(Color.BLACK))
	canvas.draw_string(f, pos, s, align, width, size, ac(c))


func fit(s: String, f: Font, size: int, width: float) -> int:
	while size > 8 and f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		size -= 1
	return size


func tone(f: float) -> Color:
	return Color.WHITE if f > 0.5 else (A.hazard if f > 0.25 else A.danger)


func mech_name(i: int) -> String:
	return tr("nameMech%d" % mini(i, 3))


func seat_pad(i: int) -> bool:
	var p := get_parent()
	if p != null and "aims" in p and i < p.aims.size():
		return p.aims[i].on_pad
	return pad and i == 0


func cap(i: int, key: String) -> String:
	if i >= humans:
		return ""
	return tr(KEYS[key][1 if seat_pad(i) else 0])


func strip_rects(size: Vector2, teams: Array) -> Array:
	var cx := size.x / 2.0
	var seen := [0, 0]
	var out := []
	for t in teams:
		var side: int = t % 2
		var k: int = seen[side]
		seen[side] += 1
		var x := cx - STRIP_CLOCK - STRIP.x - k * (STRIP.x + STRIP_GAP) if side == 0 else cx + STRIP_CLOCK + k * (STRIP.x + STRIP_GAP)
		out.append(Rect2(x, STRIP_TOP, STRIP.x, STRIP.y))
	return out


func skill_bars(size: Vector2) -> void:
	var ms: Array = state.mechs
	var rects := strip_rects(size, ms.map(func(m): return m.team))
	for i in rects.size():
		strip(ms[i], rects[i], i, ms.size() > 2)


func meter(r: Rect2, f: float, c: Color) -> void:
	poly(rect_poly(r), A.track)
	poly(rect_poly(Rect2(r.position, Vector2(r.size.x * clampf(f, 0.0, 1.0), r.size.y))), c)


func strip(m: Dictionary, r: Rect2, seat: int, named: bool) -> void:
	var t: Color = A.team[m.team]
	var w := r.size.x
	var h := r.size.y
	fade = 0.4 if m.ko else 1.0
	canvas.draw_set_transform(r.position)
	poly(PackedVector2Array([Vector2(8, 0), Vector2(w, 0), Vector2(w, h - 8), Vector2(w - 8, h), Vector2(0, h), Vector2(0, 8)]), Color(A.panel, 0.94))
	poly(rect_poly(Rect2(8, 0, w - 8, 2)), t)
	var o := Vector2(7, 7)
	poly(rect_poly(Rect2(o + Vector2(19, 12) * STRIP_BOT, Vector2(22, 16) * STRIP_BOT)), A.core)
	for b in MINI:
		var br: Rect2 = b[1]
		part_block(m, b[0], Rect2(o + br.position * STRIP_BOT, br.size * STRIP_BOT), 0.0)
	var hx := 50.0
	var mw := 76.0
	if named:
		var nm := mech_name(m.id).to_upper()
		poly(slant(Rect2(50, 5, 76, 13), -14), t)
		txt(nm, Vector2(50, 15.5), fit(nm, heavy, 11, 62.0), A.ground, HORIZONTAL_ALIGNMENT_CENTER, 76.0, heavy)
		hx = 136.0
		mw = 44.0
	icon("heat", Vector2(hx, 11.5), 0.3, A.heat_text)
	meter(Rect2(hx + 6.0, 9, mw, 5), m.heat / float(Sim.HEAT.max), A.heat)
	icon("ult", Vector2(hx + mw + 17.0, 11.5), 0.3, A.surge_text)
	meter(Rect2(hx + mw + 24.0, 9, mw, 5), m.surge / float(Sim.SURGE.max), A.surge)
	for i in SLOT_KEYS.size():
		slot(m, SLOT_KEYS[i], Rect2(50.0 + i * 34.0, 20, 32, 22), cap(seat, SLOT_KEYS[i]))
	if m.ko:
		fade = 1.0
		canvas.draw_set_transform(r.position + Vector2(w * 0.5, h * 0.5), deg_to_rad(-4))
		canvas.draw_rect(Rect2(-26, -8, 52, 16), A.danger)
		txt(tr("ko"), Vector2(-26, 5), 13, A.ground, HORIZONTAL_ALIGNMENT_CENTER, 52.0, heavy)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	fade = 1.0


func top_bar(size: Vector2) -> void:
	var ms: Array = state.mechs
	var cx := size.x / 2.0
	var n: int = Sim.MATCH.wins
	if ms.size() == 2:
		for side in 2:
			var c: Color = A.team[ms[side].team]
			var r := Rect2(cx - 68 - 280 if side == 0 else cx + 68, 26, 280, 44)
			poly(slant(r, -14 if side == 0 else 14), c)
			var nm := mech_name(side).to_upper()
			if side == 0:
				txt(nm, Vector2(r.position.x + 24, 56), 22, A.ground, HORIZONTAL_ALIGNMENT_LEFT, -1.0, heavy)
			else:
				txt(nm, Vector2(r.position.x, 56), 22, A.ground, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 24.0, heavy)
			for i in n:
				var px := r.end.x - 24 - 11 - (n - 1 - i) * 16.0 if side == 0 else r.position.x + 24 + i * 16.0
				canvas.draw_rect(Rect2(px, 38, 11, 20), Color(A.ground, 1.0 if state.score[ms[side].team] > i else 0.25))
	else:
		for side in 2:
			var teams := [0, 2] if side == 0 else [1, 3]
			for i in teams.size():
				if teams[i] >= state.score.size():
					continue
				var r := Rect2(cx - 56 - 8 - 44 - i * 52.0 if side == 0 else cx + 56 + 8 + i * 52.0, 32, 44, 32)
				poly(slant(r, -14 if side == 0 else 14), A.team[teams[i]])
				txt(str(state.score[teams[i]]), Vector2(r.position.x, 55), 20, A.ground, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, heavy)
	var h := Vector2(cx - 56, 18)
	poly(PackedVector2Array([h + Vector2(14, 0), h + Vector2(98, 0), h + Vector2(112, 30), h + Vector2(98, 60), h + Vector2(14, 60), h + Vector2(0, 30)]), Color.WHITE)
	txt(tr("round").format({"n": state.round}), h + Vector2(0, 20), 10, A.ground, HORIZONTAL_ALIGNMENT_CENTER, 112.0)
	var secs := int(ceil(maxf(0.0, state.clock) / Sim.TICKS))
	txt("%d:%02d" % [floori(secs / 60.0), secs % 60], h + Vector2(0, 47), 32, A.ground if secs > 10 else A.danger, HORIZONTAL_ALIGNMENT_CENTER, 112.0, heavy)


func armor_frac(m: Dictionary, part: String) -> float:
	return maxf(0.0, m.armor[part]) / float(m.max[part])


func health_c(f: float) -> Color:
	if f > 0.75:
		return A.good
	if f > 0.5:
		return A.hazard
	return A.orange if f > 0.25 else A.danger


func part_block(m: Dictionary, part: String, r: Rect2, n: float) -> void:
	var shape := cut(r, n) if n > 0.0 else rect_poly(r)
	if m.armor[part] <= 0:
		stripes(shape, r, A.jam_dark, A.ground, 4.0, -r.size.y)
		return
	poly(shape, A.track)
	var f := armor_frac(m, part)
	var fr := Rect2(r.position.x, r.end.y - r.size.y * f, r.size.x, r.size.y * f)
	for p in Geometry2D.intersect_polygons(rect_poly(fr), shape):
		poly(p, health_c(f))
	if n > 0.0:
		for q in [0.25, 0.5, 0.75]:
			canvas.draw_rect(Rect2(r.position.x, r.end.y - r.size.y * q - 0.5, r.size.x, 1.0), ac(Color(A.ground, 0.75)))


func gauge(p: Vector2, f: float, c: Color, kind: String, ic: Color) -> void:
	icon(kind, Vector2(p.x + 7.0, p.y + 33.0), 0.5, ic)
	var bottom := p.y + 156.0
	var lit := ceili(f * 14.0)
	for i in 14:
		canvas.draw_rect(Rect2(p.x, bottom - i * 8.0 - 6.0, 14, 6), ac(c if i < lit else A.track))


func side_panel(m: Dictionary, at: Vector2) -> void:
	var t: Color = A.team[m.team]
	fade = 0.4 if m.ko else 1.0
	canvas.draw_set_transform(at)
	poly(PackedVector2Array([Vector2(12, 0), Vector2(SIDE.x, 0), Vector2(SIDE.x, SIDE.y - 12), Vector2(SIDE.x - 12, SIDE.y), Vector2(0, SIDE.y), Vector2(0, 12)]), Color(A.panel, 0.94))
	poly(rect_poly(Rect2(12, 0, SIDE.x - 12, 3)), t)
	poly(slant(Rect2(10, 10, 64, 9), -24.0), t)
	gauge(Vector2(8, 0), clampf(m.heat / float(Sim.HEAT.max), 0.0, 1.0), A.heat, "heat", A.heat_text)
	gauge(Vector2(SIDE.x - 22.0, 0), clampf(m.surge / float(Sim.SURGE.max), 0.0, 1.0), A.surge, "ult", A.surge_text)
	var d := Vector2(30, 30)
	canvas.draw_rect(Rect2(d + Vector2(52, 22), Vector2(12, 8)), ac(A.line))
	poly(cut(Rect2(d + Vector2(32, 28), Vector2(52, 40)), 5), A.core)
	canvas.draw_rect(Rect2(d + Vector2(50, 40), Vector2(16, 16)), ac(A.raised))
	for b in DIAGRAM:
		var r: Rect2 = b[1]
		r.position += d
		part_block(m, b[0], r, 4.0)
	for i in SLOT_KEYS.size():
		slot(m, SLOT_KEYS[i], Rect2(8.0 + i * 27.0, 166, 25, 32))
	if m.ko:
		fade = 1.0
		canvas.draw_set_transform(at + Vector2(88, 100), deg_to_rad(-4))
		hazard(Rect2(-44, -9, 88, 18))
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	fade = 1.0


func slot(m: Dictionary, key: String, r: Rect2, label := "") -> void:
	var cd: float = m.cd.get(key, 0.0)
	var id := "%d%s" % [m.id, key]
	if cd > cd_peak.get(id, 0.0):
		cd_peak[id] = cd
	elif cd <= 0.0:
		cd_peak.erase(id)
	var rise: float = 1.0 - cd / cd_peak[id] if cd_peak.has(id) else 1.0
	var jam: bool = Sim.ARM_OF.has(key) and Sim.jammed(m, Sim.ARM_OF[key])
	var shape := cut(r, 5)
	var bg: Color = A.track
	var ink: Color = A.soft
	var tint := Color(A.soft, 0.3)
	var kind := key
	var lit := false
	var pips := 0
	var fill := 0.0
	match key:
		"left", "right":
			kind = "blade" if Sim.weapon(m, key).kind == "melee" else "gun"
			bg = A.team[m.team]
			ink = A.ground
			tint = Color(A.team[m.team], 0.75)
		"shield":
			lit = Sim.shield_up(m)
		"hook":
			if Sim.e_skill(m) == "":
				canvas.draw_rect(r, ac(Color(A.line, 0.7)), false, 1.0)
				return
			kind = "skill"
			lit = Sim.e_active(m)
		"dash":
			pips = Sim.charges(m.loadout)
			if m.dashes <= 0:
				bg = A.line
		"ult":
			var ready: bool = m.surge >= Sim.SURGE.max
			if ready:
				bg = A.surge
			else:
				fill = m.surge / float(Sim.SURGE.max)
			ink = A.ground if ready or label == "" else A.soft
	if cd > 0.0 and key != "ult":
		bg = A.line if key == "left" or key == "right" else A.track
		ink = Color.WHITE if key == "left" or key == "right" else A.soft
		fill = rise
	poly(shape, bg)
	if fill > 0.0:
		var f := Rect2(r.position.x, r.end.y - r.size.y * fill, r.size.x, r.size.y * fill)
		var c: Color = A.surge if key == "ult" else tint
		for p in Geometry2D.intersect_polygons(rect_poly(f), shape):
			poly(p, c)
	if jam:
		var jr := Rect2(r.position.x, r.end.y - 6, r.size.x, 6)
		for p in Geometry2D.intersect_polygons(rect_poly(jr), shape):
			stripes(p, jr, A.danger, A.jam_dark, 4.0, 6.0)
	if lit:
		canvas.draw_polyline(shape + PackedVector2Array([shape[0]]), ac(Color.WHITE), 1.5, true)
	var px := r.position.x + 3.0
	if label != "":
		var base := 11.0 if key == "dash" else r.size.y / 2.0 + 4.0
		txt(label, Vector2(r.position.x, r.position.y + base), fit(label, heavy, 11, r.size.x - 4.0), ink, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, heavy)
		px = r.get_center().x - (pips * 7.0 - 2.0) / 2.0
	else:
		icon(kind, Vector2(r.get_center().x, r.position.y + (12.5 if key == "dash" else 15.5)), 0.6, ink)
	for i in pips:
		canvas.draw_rect(Rect2(px + i * 7.0, r.end.y - 9.0, 5, 5), ac(A.hazard if i < m.dashes else A.panel))


func ring(c: Vector2, rad: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 17:
		pts.append(c + Vector2.from_angle(TAU * i / 16.0) * rad)
	return pts


func icon_lines(kind: String) -> Array:
	match kind:
		"gun":
			return [PackedVector2Array([Vector2(3, 11), Vector2(16, 11), Vector2(16, 19), Vector2(3, 19), Vector2(3, 11)]), PackedVector2Array([Vector2(16, 13), Vector2(25, 13), Vector2(25, 17), Vector2(16, 17)]), PackedVector2Array([Vector2(7, 19), Vector2(7, 24), Vector2(12, 24), Vector2(12, 19)])]
		"blade":
			return [ring(Vector2(14, 14), 7.0), ring(Vector2(14, 14), 2.0), PackedVector2Array([Vector2(14, 3), Vector2(14, 7)]), PackedVector2Array([Vector2(14, 21), Vector2(14, 25)]), PackedVector2Array([Vector2(3, 14), Vector2(7, 14)]), PackedVector2Array([Vector2(21, 14), Vector2(25, 14)]), PackedVector2Array([Vector2(6.2, 6.2), Vector2(9, 9)]), PackedVector2Array([Vector2(19, 19), Vector2(21.8, 21.8)]), PackedVector2Array([Vector2(6.2, 21.8), Vector2(9, 19)]), PackedVector2Array([Vector2(19, 9), Vector2(21.8, 6.2)])]
		"shield":
			return [PackedVector2Array([Vector2(14, 3), Vector2(23, 6), Vector2(23, 13), Vector2(14, 25), Vector2(5, 13), Vector2(5, 6), Vector2(14, 3)])]
		"dash":
			return [PackedVector2Array([Vector2(14, 3), Vector2(18, 8), Vector2(18, 17), Vector2(10, 17), Vector2(10, 8), Vector2(14, 3)]), PackedVector2Array([Vector2(10, 14), Vector2(6, 19), Vector2(10, 19)]), PackedVector2Array([Vector2(18, 14), Vector2(22, 19), Vector2(18, 19)]), PackedVector2Array([Vector2(14, 21), Vector2(14, 25)])]
		"ult":
			return [PackedVector2Array([Vector2(16, 3), Vector2(7, 16), Vector2(13, 16), Vector2(11, 25), Vector2(21, 11), Vector2(15, 11), Vector2(16, 3)])]
		"heat":
			return [PackedVector2Array([Vector2(14, 3), Vector2(19, 9), Vector2(22, 16), Vector2(21, 22), Vector2(14, 26), Vector2(7, 22), Vector2(6, 16), Vector2(9, 12), Vector2(11, 15), Vector2(14, 3)])]
	return [PackedVector2Array([Vector2(14, 3), Vector2(24, 14), Vector2(14, 25), Vector2(4, 14), Vector2(14, 3)]), PackedVector2Array([Vector2(14, 10), Vector2(18, 14), Vector2(14, 18), Vector2(10, 14), Vector2(14, 10)])]


func icon(kind: String, c: Vector2, k: float, col: Color) -> void:
	for line in icon_lines(kind):
		var pts := PackedVector2Array()
		for p in line:
			pts.append(c + (p - Vector2(14, 14)) * k)
		canvas.draw_polyline(pts, ac(col), maxf(1.5, 2.8 * k), true)


func callout(s: String, c: Color, cx: float, y: float, px: int, alpha := 1.0) -> float:
	var w := maxf(300.0, heavy.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + 60.0)
	var band := roundf(px * 0.18)
	var h := band * 2.0 + px * 1.1
	fade = alpha
	canvas.draw_set_transform(Vector2(cx, y + h / 2.0), deg_to_rad(-3.0), Vector2.ONE)
	hazard(Rect2(-w / 2.0, -h / 2.0, w, band))
	hazard(Rect2(-w / 2.0, h / 2.0 - band, w, band))
	txt(s, Vector2(-w / 2.0, px * 0.35), px, c, HORIZONTAL_ALIGNMENT_CENTER, w, heavy, maxf(3.0, px * 0.09))
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	fade = 1.0
	return h


func callouts(size: Vector2) -> void:
	var cx := size.x / 2.0
	var cy := size.y * 0.3
	match state.phase:
		"countdown":
			var y := cy - 60.0
			y += callout(tr("round").format({"n": state.round}), Color.WHITE, cx, y, 54) + 8.0
			if state.timer > 0:
				callout(str(int(ceil(state.timer / float(Sim.TICKS)))), A.hazard, cx, y, 140)
		"ko":
			slam(size)
		"over":
			match_over(size)
		"fight":
			var go = has_fx("fight")
			if go != null:
				callout(tr("go"), A.hazard, cx, cy, 110, clampf(go.t / 50.0, 0.0, 1.0))
	if state.phase != "countdown" and state.phase != "fight":
		return
	var y := 118.0
	if state.mechs[0].overheat > 0:
		y += callout(tr("overheat"), A.danger, cx, y, 34) + 10.0
	for f in state.fx:
		var text := ""
		var c: Color = A.hazard
		match f.k:
			"closing":
				text = tr("closing")
			"ventsOn":
				text = tr("ventsOn")
			"healUp":
				text = tr("healReady")
			"break":
				text = tr("broke_" + f.part)
				c = A.team[state.mechs[f.id].team]
		if text != "":
			y += callout(text, c, cx, y, 34) + 10.0


func slam(size: Vector2) -> void:
	var title: String = tr("timeUp") if state.finalKo < 0 else tr("ko") + "!"
	var sub: String = (tr("draw") if state.winner < 0 else (tr("youWin") if state.winner == state.mechs[0].team else tr("rivalWins"))).to_upper()
	var w := size.x * 1.3
	canvas.draw_set_transform(Vector2(size.x / 2.0, size.y * 0.47), deg_to_rad(-4.0), Vector2.ONE)
	canvas.draw_rect(Rect2(-w / 2.0, -100, w, 200), Color(A.ground, 0.96))
	hazard(Rect2(-w / 2.0, -108, w, 14))
	hazard(Rect2(-w / 2.0, 94, w, 14))
	txt(title, Vector2(-w / 2.0, 45), 168, A.hazard, HORIZONTAL_ALIGNMENT_CENTER, w, heavy, 8.0)
	txt(sub, Vector2(-w / 2.0, 86), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, w, semi)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)


func match_over(size: Vector2) -> void:
	var mine: int = state.mechs[0].team
	var won: bool = state.score[mine] == state.score.max()
	var word := tr("victory") if won else tr("defeat")
	canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(A.ground, 0.88))
	var bw := size.x + 160.0
	canvas.draw_set_transform(Vector2(size.x / 2.0, 145), deg_to_rad(-3.0), Vector2.ONE)
	canvas.draw_rect(Rect2(-bw / 2.0, -85, bw, 170), A.team[mine] if won else A.line)
	hazard(Rect2(-bw / 2.0, 81, bw, 12))
	var tw := heavy.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 140).x
	txt(word, Vector2(64 - size.x / 2.0, 44), 140, Color("#160800") if won else Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1.0, heavy)
	txt("%d–%d" % [state.score[mine], state.score[1 - mine] if state.score.size() > 1 else 0], Vector2(64 - size.x / 2.0 + tw + 36, 22), 60, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1.0, heavy, 4.0)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	for i in rounds.size():
		var rd: Dictionary = rounds[i]
		var r := Rect2(64, 300 + i * 60.0, 700, 52)
		var who_i := 0
		for j in state.mechs.size():
			if state.mechs[j].team == rd.winner:
				who_i = j
				break
		poly(slant(r, -12), A.team[rd.winner] if rd.winner >= 0 else A.line)
		var ink: Color = A.ground if rd.winner >= 0 else Color.WHITE
		txt(tr("round").format({"n": i + 1}), Vector2(r.position.x + 24, r.position.y + 31), 11, ink)
		txt(mech_name(who_i).to_upper() if rd.winner >= 0 else tr("draw").to_upper(), Vector2(r.position.x + 120, r.position.y + 34), 22, ink, HORIZONTAL_ALIGNMENT_LEFT, -1.0, heavy)
		txt(tr("timeUp") if rd.time else tr("ko"), Vector2(r.position.x, r.position.y + 31), 14, ink, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 24.0)
	var b := Rect2(size.x - 64 - 400, size.y - 64 - 52, 400, 52)
	poly(slant(b, -12), A.raised)
	txt(tr("backGarage").to_upper(), Vector2(b.position.x + 28, b.position.y + 34), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1.0, semi)
	txt(tr("keyEnter"), Vector2(b.position.x, b.position.y + 31), 12, A.dim, HORIZONTAL_ALIGNMENT_RIGHT, b.size.x - 28.0)


func pause_screen(size: Vector2) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(A.ground, 0.7))
	canvas.draw_set_transform(Vector2(size.x / 2.0, 126), deg_to_rad(-3.0), Vector2.ONE)
	hazard(Rect2(-size.x / 2.0 - 40, -6, size.x + 80, 12))
	var title := tr("mPaused")
	var tw := heavy.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 96).x
	canvas.draw_set_transform(Vector2(120 + tw / 2.0, 188), deg_to_rad(-3.0), Vector2.ONE)
	txt(title, Vector2(-tw / 2.0, 34), 96, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1.0, heavy, 6.0)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	for b in menu.get_children():
		var r := Rect2(b.global_position, b.size)
		var on: bool = b.has_focus() or b.is_hovered()
		var shape := slant(r, -12)
		if on:
			var back := PackedVector2Array()
			for p in shape:
				back.append(p + Vector2(5, 5))
			poly(back, Color.BLACK)
		poly(shape, A.hazard if on else A.raised)
		var big: bool = r.size.y > 60
		txt(tr(b.get_meta("key")).to_upper(), Vector2(r.position.x + 28, r.position.y + r.size.y / 2.0 + (10 if big else 8)), 30 if big else 22, A.ground if on else Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1.0, heavy if big else semi)
	var p := Rect2(size.x - 580, 300, 460, 280)
	poly(cut(p, 18), A.panel)
	txt(tr("soundTitle"), Vector2(p.position.x + 26, p.position.y + 44), 22, A.hazard, HORIZONTAL_ALIGNMENT_LEFT, -1.0, heavy)
	txt(tr("pauseHint"), Vector2(0, size.y - 40), 13, A.dim, HORIZONTAL_ALIGNMENT_CENTER, size.x)


func replay_bars(size: Vector2) -> void:
	var bar := roundf(size.y * 0.125 * minf(1.0, replay * 20.0))
	var by := size.y - bar
	canvas.draw_rect(Rect2(0, 0, size.x, bar), Color.BLACK)
	canvas.draw_rect(Rect2(0, by, size.x, bar), Color.BLACK)
	canvas.draw_rect(Rect2(0, by, size.x, 4), A.raised)
	canvas.draw_rect(Rect2(0, by, size.x * replay, 4), A.danger)
	if Time.get_ticks_msec() / 500 % 2 == 1:
		canvas.draw_circle(Vector2(47, bar / 2.0), 7, A.danger)
	txt(tr("kcReplay"), Vector2(68, bar / 2.0 + 11), 30, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1.0, heavy)
	if who.x >= 0 and who.x < state.mechs.size():
		var t := tr("kcTag").format({"a": mech_name(who.x).to_upper(), "b": mech_name(who.y).to_upper()})
		var tw := heavy.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 28.0
		poly(slant(Rect2(size.x - 40 - tw, bar / 2.0 - 15, tw, 30), -12), A.team[state.mechs[who.x].team])
		txt(t, Vector2(size.x - 40 - tw, bar / 2.0 + 6), 18, A.ground, HORIZONTAL_ALIGNMENT_CENTER, tw, heavy)
	var hint := tr("kcSkipOr")
	var hw := label_f.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	var x := size.x - 40 - hw
	txt(hint, Vector2(x, by + bar / 2.0 + 5), 14, A.dim)
	for key in ["A", "Enter"]:
		var kw := label_f.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 16.0
		x -= kw + 10.0
		canvas.draw_rect(Rect2(x, by + bar / 2.0 - 11, kw, 22), A.raised)
		txt(key, Vector2(x, by + bar / 2.0 + 5), 13, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, kw)


func ally_color(i: int) -> Color:
	return A.team[mini(i, 3)]


func recall_of(i: int):
	for c in state.siege.recall:
		if c.player == i:
			return c
	return null


func ally_status(i: int) -> String:
	if state.mechs[i].ko:
		return "down"
	return "recall" if recall_of(i) != null else "alive"


func shop_open() -> bool:
	for c in get_children():
		if c.has_method("refresh") and c.visible:
			return true
	return false


func build_phase() -> bool:
	return not state.siege.wave.live and state.phase != "over"


func siege_box(size: Vector2) -> Rect2:
	var right := 270.0 if build_phase() else 48.0
	var bottom := 120.0 if build_phase() else 48.0
	var top := maxf(138.0, calls_bottom + 8.0)
	return Rect2(Vector2(SIEGE_LEFT, top), Vector2(size.x - SIEGE_LEFT - right, size.y - top - bottom))


func stat_chip(label: String, value: String, pos: Vector2, accent: Color) -> float:
	var lw := label_f.get_string_size(label.strip_edges().to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	var vw := heavy.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
	var w := lw + vw + 42.0
	poly(rect_poly(Rect2(pos, Vector2(w, 42))), Color(A.panel, 0.95))
	poly(rect_poly(Rect2(pos, Vector2(6, 42))), accent)
	txt(label.strip_edges().to_upper(), pos + Vector2(18, 27), 15, A.dim)
	txt(value, pos + Vector2(18 + lw + 10.0, 33), 28, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, heavy)
	return w


func chip(s: String, pos: Vector2, c: Color = A.panel, ink: Color = Color.WHITE) -> float:
	var w := label_f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 24.0
	poly(rect_poly(Rect2(pos, Vector2(w, 24))), Color(c, 0.92))
	txt(s, pos + Vector2(0, 17), 12, ink, HORIZONTAL_ALIGNMENT_CENTER, w)
	return w


func tag(s: String, cx: float, y: float, bg: Color, ink: Color) -> void:
	var w := label_f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 44.0
	poly(slant(Rect2(cx - w / 2.0, y, w, 26), -12.0), bg)
	txt(s, Vector2(cx - w / 2.0, y + 18), 13, ink, HORIZONTAL_ALIGNMENT_CENTER, w)


func skew_bar(r: Rect2, f: float, c: Color) -> void:
	poly(slant(r, -20.0), A.line)
	if f > 0.0:
		poly(slant(Rect2(r.position, Vector2(r.size.x * clampf(f, 0.0, 1.0), r.size.y)), -20.0), c)


func siege_top(size: Vector2) -> void:
	var sg: Dictionary = state.siege
	var w: Dictionary = sg.wave
	var cx := size.x / 2.0
	var title := tr("siegeWave").format({"n": w.n if w.live else w.n + 1}).to_upper()
	var tw := heavy.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x + 36.0
	var left: int = sg.enemies.filter(func(e): return e.act != "die" and not e.get("neutral", false)).size() + sg.queue.filter(func(q): return q.has("kind")).size()
	var sub: String = tr("siegeLeft").format({"n": left}) if w.live or w.next_in > 36000 else tr("siegeNext").format({"s": int(ceil(w.next_in / float(Sim.TICKS)))})
	var tail := tr("siegeBest").format({"n": best}) if best > 0 else ""
	var sw := label_f.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	var bw := label_f.get_string_size(tail, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var x := cx - (tw + 10.0 + sw + (10.0 + bw if tail != "" else 0.0)) / 2.0
	poly(slant(Rect2(x, 14, tw, 40), -12.0), Color.WHITE if w.live else A.line)
	txt(title, Vector2(x, 43), 26, A.ground if w.live else Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, tw, heavy)
	txt(sub, Vector2(x + tw + 10.0, 39), 14, Color.WHITE)
	if tail != "":
		txt(tail, Vector2(x + tw + 20.0 + sw, 39), 12, A.dim)
	var c: Dictionary = sg.core
	var f := clampf(c.hp / c.max, 0.0, 1.0)
	var bar := Rect2(cx - 170.0, 66, 310, 14)
	txt(tr("siegeCore"), Vector2(cx - 220.0, 78), 11, A.hazard)
	poly(rect_poly(bar), A.line)
	poly(rect_poly(Rect2(bar.position, Vector2(bar.size.x * f, bar.size.y))), A.hazard)
	for i in 4:
		var tx := bar.position.x + bar.size.x * (3 - i) / 4.0
		poly(rect_poly(Rect2(tx - 1.5, bar.position.y - 4, 3, bar.size.y + 8)), A.team[1] if c.rings[i] > 0 else A.danger)
	txt(str(roundi(f * 100.0)), Vector2(bar.end.x + 10, 79), 16, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, heavy)


func siege_left(size: Vector2) -> void:
	var sg: Dictionary = state.siege
	var x := 16.0
	if not shop_open():
		x += stat_chip(tr("siegeWallet").format({"n": ""}), str(sg.wallets[0]), Vector2(x, 14), A.hazard) + 8.0
		if sg.tokens[0] > 0:
			stat_chip(tr("siegeTokens").format({"n": ""}), str(sg.tokens[0]), Vector2(x, 14), A.surge)
	for c in get_children():
		if c.has_method("refresh") and "chips" in c:
			c.chips = [[tr("siegeWallet").format({"n": sg.wallets[0]}).to_upper(), true], [tr("siegeTokens").format({"n": sg.tokens[0]}).to_upper(), false]]
	var g: Dictionary = sg.garrison
	if g.tier > 0:
		if g.respawn_in <= 0:
			chip(tr("siegeGuard").format({"t": g.tier}), Vector2(16, 62), A.team[1], A.ground)
		else:
			chip(tr("siegeGuardDown").format({"t": g.tier, "s": int(ceil(g.respawn_in / float(Sim.TICKS)))}), Vector2(16, 62), A.line, A.jam_text)
	for i in sg.team:
		ally_row(i, Vector2(16, 94 + i * 54))
	var y: float = 94.0 + sg.team * 54.0 + 8.0
	var rc = recall_of(0)
	if rc != null:
		txt(tr("siegeRecall"), Vector2(16, y + 10), 11, A.team[1])
		skew_bar(Rect2(16, y + 16, ROW_W, 8), rc.t / float(rc.max), A.team[1])
		y += 34.0
	if get_children().any(func(c): return c.has_method("refresh") and c.visible and c.heading == "radialShop"):
		siege_tiers(Vector2(16, y))


func ally_row(i: int, at: Vector2) -> void:
	var m: Dictionary = state.mechs[i]
	var c := ally_color(i)
	fade = 0.45 if m.ko else 1.0
	poly(rect_poly(Rect2(at, Vector2(ROW_W, 50))), Color(A.panel, 0.92))
	poly(rect_poly(Rect2(at, Vector2(8 if i == 0 else 5, 50))), c)
	txt(mech_name(i).to_upper(), at + Vector2(18, 32), 16, c, HORIZONTAL_ALIGNMENT_LEFT, -1, heavy)
	canvas.draw_set_transform(at + Vector2(134, 4), 0.0, Vector2(0.85, 0.85))
	poly(rect_poly(Rect2(19, 12, 22, 16)), A.core)
	for b in MINI:
		part_block(m, b[0], b[1], 0.0)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	fade = 1.0
	var mid := at + Vector2(ROW_W - 20.0, 25)
	match ally_status(i):
		"down":
			canvas.draw_line(mid + Vector2(-8, -8), mid + Vector2(8, 8), A.danger, 4.0)
			canvas.draw_line(mid + Vector2(8, -8), mid + Vector2(-8, 8), A.danger, 4.0)
		"recall":
			var rc = recall_of(i)
			canvas.draw_arc(mid, 10.0, -PI / 2.0, -PI / 2.0 + TAU * clampf(rc.t / float(rc.max), 0.02, 1.0), 24, A.team[1], 4.0)
		_:
			pass


func siege_tiers(at: Vector2) -> void:
	var t: Dictionary = state.siege.tiers[0]
	poly(rect_poly(Rect2(at, Vector2(ROW_W, 18 + TIER_ROWS.size() * 15))), Color(A.panel, 0.92))
	txt(tr("siegeTiers"), at + Vector2(10, 14), 10, A.dim)
	for r in TIER_ROWS.size():
		var y: float = at.y + 30 + r * 15
		txt(tr("tierShort_" + TIER_ROWS[r]), Vector2(at.x + 10, y), 11, Color.WHITE)
		for k in 5:
			poly(slant(Rect2(at.x + 90 + k * 22, y - 9, 18, 8), -20.0), A.team[0] if k < t[TIER_ROWS[r]] else A.line)


func siege_crate(size: Vector2) -> void:
	for y in state.siege.yards:
		for c in y.crates:
			if c.progress > 0.0:
				var r := Rect2(size.x / 2.0 - 100, size.y * 0.62, 200, 12)
				txt(tr("siegeCrate"), Vector2(r.position.x, r.position.y - 6), 12, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
				skew_bar(r, c.progress, A.surge)


func siege_shop(size: Vector2) -> void:
	var sg: Dictionary = state.siege
	var x := size.x - 266.0
	txt((tr("radialTeam") + " · " + tr("siegeWallet").format({"n": sg.wallets[0]})).to_upper(), Vector2(x, 28), 10, A.dim)
	for i in SHOP.size():
		var k: String = SHOP[i]
		var cost: int = Siege.next_cost(sg) if k == "garrison" else Siege.SHOP[k]
		var can: bool = cost >= 0 and sg.wallets[0] >= cost
		var r := Rect2(x, 36 + i * 34, 250, 30)
		poly(rect_poly(r), Color(A.panel, 0.92))
		txt(tr("shop_" + k).format({"t": sg.garrison.tier + 1}), r.position + Vector2(12, 20), 12, Color.WHITE if can else A.dim)
		if cost >= 0:
			txt(str(cost), Vector2(r.position.x, r.position.y + 21), 14, Color.WHITE if can else A.dim, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 10.0, heavy)
	poly(rect_poly(Rect2(x, 36 + SHOP.size() * 34, 250, 22)), Color(A.panel, 0.92))
	txt(tr("siegeBuildHint"), Vector2(x + 10, 36 + SHOP.size() * 34 + 15), 11, A.soft)
	var left: int = int(ceil(maxf(0, sg.wave.next_in - 480) / float(Sim.TICKS)))
	var y := size.y - 96.0
	var cx := size.x / 2.0
	tag(tr("siegeShop"), cx, y, A.hazard, A.ground)
	if left > 0 and left < 600:
		tag(tr("siegeCall").format({"n": 2 * left}), cx, y + 30.0, A.team[1], A.ground)
	var keys := tr("siegeKeys") + "   ·   " + tr("siegeUse")
	var kw := label_f.get_string_size(keys, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 24.0
	poly(rect_poly(Rect2(cx - kw / 2.0, y + 62.0 - 15.0, kw, 22.0)), Color(A.panel, 0.88))
	txt(keys, Vector2(0, y + 62.0), 12, A.soft, HORIZONTAL_ALIGNMENT_CENTER, size.x)


func build_menu(i: int, kind: String) -> Array:
	var sg: Dictionary = state.siege
	var m: Dictionary = state.mechs[i]
	var pd = Siege.pad_at(sg, m, Siege.MODULE.pad)
	var g = Siege.gate_at(sg, m)
	var out := []
	for k in Siege.WHEEL[kind]:
		var c: int = Siege.SHOP[k]
		var ok: bool = not sg.wave.live and sg.wallets[i] >= c
		if kind == "square":
			ok = ok and pd != null and (pd.module == "" or (pd.module == k and pd.get("hp", 1) <= 0))
		elif g != null:
			ok = ok and (g.hp <= 0 if k == "rebuild" else g.hp > 0 and g.hp < g.max)
		out.append({"id": k, "label_key": "shop_" + k, "cost": c, "enabled": ok, "sub": [], "note": tr("siegeWallet").format({"n": sg.wallets[i]})})
	return out


func shop_menu(i: int, kind := "plaza") -> Array:
	if kind != "plaza":
		return build_menu(i, kind)
	var sg: Dictionary = state.siege
	var m: Dictionary = state.mechs[i]
	var w: int = sg.wallets[i]
	var tier := func(slot: String) -> Dictionary:
		var c: int = Siege.price_of(sg, m, "tier:" + slot)
		var t: int = sg.tiers[i][slot]
		var note: String = tr("noteMax") if c < 0 else tr("noteTier").format({"a": t, "b": t + 1}) + " · " + tr("fx_" + ("hand" if slot in ["left", "right"] else slot))
		return {"id": "tier:" + slot, "label_key": "tier_" + slot, "cost": c, "enabled": c >= 0 and w >= c, "sub": [], "note": note}
	var wallet := func(id: String) -> Dictionary:
		var c: int = Siege.price_of(sg, m, id)
		return {"id": id, "label_key": "shop_" + id, "cost": c, "enabled": w >= c or (id == "reinforce" and sg.tokens[i] > 0), "sub": [], "note": ""}
	var parts := []
	for slot in Siege.S.PART_SLOTS:
		var keys := []
		for key in Sim.CATALOG[slot]:
			var c: int = Siege.price_of(sg, m, "swap:%s:%s" % [slot, key])
			if c >= 0:
				keys.append({"id": "swap:%s:%s" % [slot, key], "label_key": "p_" + key, "cost": c, "enabled": w >= c, "sub": [], "note": tr("noteLevel").format({"n": Siege.owned_level(sg, i, slot, key)})})
		if not keys.is_empty():
			parts.append({"id": "parts:" + slot, "label_key": "tierShort_" + slot, "cost": -1, "enabled": true, "sub": keys.slice(0, 8), "note": ""})
	var team := []
	for k in SHOP:
		var c: int = Siege.next_cost(sg) if k == "garrison" else Siege.SHOP[k]
		team.append({"id": k, "label_key": "shop_" + k, "cost": c, "enabled": c >= 0 and not sg.wave.live and w >= c, "sub": [], "note": tr("siegeWallet").format({"n": w}) if k == "ring" else ""})
	var group := func(id: String, key: String, sub: Array) -> Dictionary:
		return {"id": id, "label_key": key, "cost": -1, "enabled": true, "sub": sub, "note": ""}
	return [
		group.call("weapons", "radialWeapons", [tier.call("left"), tier.call("right")]),
		group.call("plating", "radialPlating", [tier.call("head"), tier.call("arms"), tier.call("legs")]),
		group.call("engine", "radialEngine", [tier.call("legs"), tier.call("booster")]),
		group.call("core", "radialCore", [tier.call("core")]),
		group.call("heal", "radialHeal", [wallet.call("kit"), wallet.call("coolant"), wallet.call("surge")]),
		group.call("parts", "radialParts", parts),
		group.call("team", "radialTeam", team),
		wallet.call("reinforce"),
		wallet.call("revive"),
	]


func watch(key: String, hp: float, now: int) -> void:
	if hp < hp_was.get(key, hp):
		hurt_at[key] = now
	hp_was[key] = hp


func siege_marks(size: Vector2) -> void:
	var sg: Dictionary = state.siege
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var now := Time.get_ticks_msec()
	var spots := {"core": Vector3(sg.core.x, 2.0, sg.core.y)}
	for i in sg.gates.size():
		spots["g%d" % i] = Vector3(sg.gates[i].x, 2.0, sg.gates[i].y)
		watch("g%d" % i, sg.gates[i].hp, now)
	watch("core", sg.core.hp, now)
	for key in hurt_at:
		if now - hurt_at[key] < 1500:
			marker(cam, size, spots[key], A.danger, "", true)
	for f in state.fx:
		if f.k == "warn":
			var g: Dictionary = sg.gates[f.lane]
			marker(cam, size, Vector3(g.x, 4.0, g.y), A.danger if f.boss else A.hazard, tr("siegeIncoming").format({"bot": tr("bot_" + f.kind), "n": f.n}), int(f.t / 15) % 2 == 0)
	ally_marks(size, cam)


func edge_arrow(cam: Camera3D, size: Vector2, at: Vector3, c: Color, lit: bool) -> Vector2:
	var p := cam.unproject_position(at)
	var behind := cam.is_position_behind(at)
	var box := siege_box(size)
	if not behind and box.has_point(p):
		return Vector2.INF
	var mid := box.get_center()
	var d := (p - mid) * (-1.0 if behind else 1.0)
	var k := minf(absf(box.size.x / 2.0 / d.x) if d.x != 0 else 1e9, absf(box.size.y / 2.0 / d.y) if d.y != 0 else 1e9)
	var e := mid + d * k
	var u := d.normalized()
	var n := Vector2(-u.y, u.x)
	poly(PackedVector2Array([e + u * 16, e - u * 8 + n * 11, e - u * 8 - n * 11]), Color(c, 1.0 if lit else 0.45))
	return e - u * 30


func marker(cam: Camera3D, size: Vector2, at: Vector3, c: Color, text: String, lit: bool) -> void:
	var p := edge_arrow(cam, size, at, c, lit)
	if p == Vector2.INF:
		p = cam.unproject_position(at)
		if text == "":
			return
	if text == "":
		return
	var tw := heavy.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 44.0
	var r := Rect2(p.x - tw / 2.0, p.y - 40, tw, 32)
	poly(rect_poly(r), Color(A.panel, 0.95))
	canvas.draw_rect(r, ac(c if lit else A.line), false, 2.0)
	var h := r.position + Vector2(10, 9)
	poly(rect_poly(Rect2(h + Vector2(0, 4), Vector2(14, 10))), c)
	poly(PackedVector2Array([h + Vector2(9, 4), h + Vector2(14, 4), h + Vector2(16, -3)]), c)
	poly(rect_poly(Rect2(h + Vector2(3, 8), Vector2(8, 3))), A.team[1])
	txt(text, Vector2(r.position.x + 32, r.position.y + 22), 15, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, heavy)


func ally_marks(size: Vector2, cam: Camera3D) -> void:
	for i in range(1, state.siege.team):
		var m: Dictionary = state.mechs[i]
		if not m.ko:
			edge_arrow(cam, size, Vector3(m.x, 3.4, m.y), ally_color(i), true)


func siege_calls(size: Vector2) -> void:
	var cy := 118.0
	var shown := {}
	calls_bottom = 0.0
	for f in state.fx:
		var text := ""
		var sub := ""
		var c: Color = Color.WHITE
		match f.k:
			"cleared":
				text = tr("siegeCleared")
				sub = tr("siegeBonus").format({"n": f.n}) if f.n > 0 else ""
				c = A.good
			"call":
				text = tr("siegeBonus").format({"n": f.n})
				c = A.team[1]
			"ring":
				text = tr("siegeRing")
				c = A.danger
			"raid":
				text = tr("siegeRaid").format({"yard": Siege.S.QUADS[f.q].name})
				c = A.danger
			"mutator":
				text = tr("siegeMutator").format({"name": tr("mut_" + f.id)})
				sub = tr("mutd_" + f.id)
				c = A.surge
			"tactic":
				var names: Array = f.lanes.map(func(l): return Siege.S.LANES[l].name)
				var air: Array = Siege.S.AIR[f.get("corner", 0)]
				var yard: Array = Siege.S.QUADS.filter(func(q): return q.sx == signi(int(air[0])) and q.sy == signi(int(air[1])))
				var parts: PackedStringArray = tr("dir_" + f.id).format({"a": names[0] if names.size() > 0 else "", "b": names[1] if names.size() > 1 else "", "lane": names[0] if names.size() > 0 else "", "corner": yard[0].name}).split("|")
				text = parts[0]
				sub = parts[1] if parts.size() > 1 else ""
				c = A.team[1] if f.id == "breather" else A.danger
			"warn":
				if f.boss:
					text = tr("siegeBoss")
					c = A.danger
		if text != "" and not shown.has(text):
			shown[text] = true
			var h := callout(text.to_upper(), c, size.x / 2.0, cy, 44)
			if sub != "":
				txt(sub, Vector2(0, cy + h + 24.0), 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, size.x, heavy, 2.0)
			cy += h + (40.0 if sub != "" else 14.0)
			calls_bottom = cy


func siege_down(size: Vector2) -> void:
	var left = state.siege.down.get(0)
	if not state.mechs[0].ko or left == null:
		return
	var y := size.y * 0.42
	var h := callout(tr("siegeDown").to_upper(), A.danger, size.x / 2.0, y, 44)
	txt(tr("siegeBackIn"), Vector2(0, y + h + 34.0), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, size.x, heavy, 2.0)
	txt(str(int(ceil(left / float(Sim.TICKS)))), Vector2(0, y + h + 130.0), 96, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, size.x, heavy, 4.0)


func siege_over(size: Vector2) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.45))
	var cx := size.x / 2.0
	canvas.draw_set_transform(Vector2(cx, 300), deg_to_rad(-3.0))
	canvas.draw_rect(Rect2(-size.x, -95, size.x * 2.0, 190), A.danger)
	hazard(Rect2(-size.x, 91, size.x * 2.0, 14))
	txt(tr("siegeLost"), Vector2(-size.x / 2.0, 50), 140, Color("#1A0508"), HORIZONTAL_ALIGNMENT_CENTER, size.x, heavy)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	var held := tr("siegeHeld").format({"n": maxi(0, state.siege.wave.n - 1)})
	var hw := heavy.get_string_size(held, HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x
	var tail := tr("siegeBest").format({"n": best}).to_upper() if best > 0 else ""
	var bw := label_f.get_string_size(tail, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 24.0
	var x := cx - (hw + (18.0 + bw if tail != "" else 0.0)) / 2.0
	txt(held, Vector2(x, 460), 36, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, heavy, 3.0)
	if tail != "":
		poly(rect_poly(Rect2(x + hw + 18.0, 434, bw, 30)), A.line)
		txt(tail, Vector2(x + hw + 18.0, 455), 14, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, bw)
	var btn := tr("rematch")
	var bt := heavy.get_string_size(btn, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x + 60.0
	poly(slant(Rect2(cx - bt / 2.0, size.y - 132.0, bt, 60), -12.0), A.hazard)
	txt(btn, Vector2(cx - bt / 2.0, size.y - 132.0 + 40.0), 26, A.ground, HORIZONTAL_ALIGNMENT_CENTER, bt, heavy)


func has_fx(kind: String):
	for f in state.fx:
		if f.k == kind:
			return f
	return null


