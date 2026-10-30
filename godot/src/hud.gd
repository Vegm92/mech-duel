extends CanvasLayer

const Sim = preload("res://src/sim.gd")
const Mech = preload("res://src/mech.gd")
const Garage = preload("res://src/garage.gd")
const Sfx = preload("res://src/sfx.gd")
const Look = preload("res://src/look.gd")
const Siege = preload("res://src/siege.gd")

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
const SHOP := ["gate", "rebuild", "ring", "wall", "mine", "laser", "post", "garrison"]
const WALLET := ["kit", "coolant", "surge", "reinforce", "revive"]
const TIER_ROWS := ["left", "right", "head", "arms", "legs", "booster", "core"]
const A := Look.ARCADE
const BAR := Vector2(580, 180)
const GROUPS := [["larm", "barLarm", ["left"]], ["head", "barHead", ["hook"]], ["core", "barCore", ["shield", "ult"]], ["rarm", "barRarm", ["right"]], ["legs", "barLegs", ["dash"]]]
const BOT := [["head", Rect2(18, 2, 17, 14)], ["core", Rect2(13, 20, 26, 34)], ["larm", Rect2(1, 22, 10, 36)], ["rarm", Rect2(42, 22, 10, 36)], ["legs", Rect2(14, 58, 11, 38)], ["legs", Rect2(28, 58, 11, 38)]]
const SIDE := Vector2(340, 420)
const SIDE_K := 0.5
const DIAGRAM := [["head", Rect2(88, 4, 64, 44)], ["larm", Rect2(22, 54, 40, 100)], ["rarm", Rect2(178, 54, 40, 100)], ["legs", Rect2(76, 134, 42, 100)], ["legs", Rect2(122, 134, 42, 100)]]
const MINI := [["head", Rect2(23, 0, 14, 10)], ["larm", Rect2(9, 12, 8, 24)], ["rarm", Rect2(43, 12, 8, 24)], ["legs", Rect2(20, 30, 9, 22)], ["legs", Rect2(31, 30, 9, 22)]]
const SLOT_KEYS := ["left", "right", "shield", "hook", "dash", "ult"]
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
var hp_was := {}
var best := 0
var hurt_at := {}


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
		mech_panel(state.mechs[0], Vector2(16, 16), tr("you"))
		siege_tiers(Vector2(16, 16 + PANEL_SIZE.y + 10))
		siege_top(size)
		siege_marks(size)
		if not paused:
			slots(size)
			if not state.siege.wave.live and state.phase != "over":
				siege_shop(size)
			siege_crate(size)
		if state.phase != "over":
			siege_calls(size)
		if state.phase == "over":
			var cy := size.y * 0.38
			label(tr("siegeLost"), Vector2(0, cy + 30), 110, HEAT_C, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, heavy, 32)
			label(tr("siegeHeld").format({"n": maxi(0, state.siege.wave.n - 1)}) + ("   ·   " + tr("siegeBest").format({"n": best}) if best > 0 else ""), Vector2(0, cy + 80), 30, TEXT, HORIZONTAL_ALIGNMENT_CENTER, size.x, 8, bold, 14)
			label(tr("rematch"), Vector2(0, cy + 118), 22, DIM, HORIZONTAL_ALIGNMENT_CENTER, size.x, 6, bold)
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


func skill_bars(size: Vector2) -> void:
	var ms: Array = state.mechs
	if ms.size() <= 2:
		side_panel(ms[0], Vector2(16, size.y - 16 - SIDE.y * SIDE_K))
		return
	var k := 0.7
	var w := BAR.x * k
	var h := BAR.y * k
	var spots := [Vector2(16, size.y - 16 - h), Vector2(size.x - 16 - w, size.y - 16 - h), Vector2(16, 16), Vector2(size.x - 16 - w, 16)]
	for i in ms.size():
		skill_bar(ms[i], spots[i], k, i == 0)


func skill_bar(m: Dictionary, at: Vector2, k: float, mine: bool) -> void:
	var t: Color = A.team[m.team]
	fade = 0.4 if m.ko else 1.0
	canvas.draw_set_transform(at, 0.0, Vector2(k, k))
	poly(cut(Rect2(Vector2.ZERO, BAR), 18), Color(A.panel, 0.94))
	poly(PackedVector2Array([Vector2(18, 0), Vector2(BAR.x, 0), Vector2(BAR.x, 4), Vector2(14, 4)]), t)
	var nm := mech_name(m.id).to_upper()
	var pw := heavy.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 28.0
	poly(slant(Rect2(16, 14, pw, 24), -12), t)
	txt(nm, Vector2(16, 32), 16, A.ground, HORIZONTAL_ALIGNMENT_CENTER, pw, heavy)
	txt(tr("whoYou") if m.id == 0 else tr("whoBot").format({"n": m.id + 1}), Vector2(16 + pw + 10, 31), 11, A.dim)
	robot(m)
	var x := 83.0
	for g in GROUPS:
		x += group(m, g, x, mine) + 14.0
	if m.ko:
		fade = 1.0
		canvas.draw_set_transform(at + Vector2(BAR.x * 0.72, BAR.y * 0.42) * k, deg_to_rad(-4), Vector2(k, k))
		canvas.draw_rect(Rect2(-50, -20, 100, 40), A.danger)
		txt(tr("ko"), Vector2(-50, 8), 22, A.ground, HORIZONTAL_ALIGNMENT_CENTER, 100.0, heavy)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	fade = 1.0


func robot(m: Dictionary) -> void:
	for b in BOT:
		var part: String = b[0]
		var r: Rect2 = b[1]
		r.position += Vector2(16, 52)
		var shape := cut(r, 3)
		if part == "core":
			poly(shape, A.core)
		elif m.armor[part] <= 0 and part != "head":
			stripes(shape, r, A.danger, A.jam_dark, 8.0, -r.size.y)
		else:
			poly(shape, A.line if m.armor[part] <= 0 else tone(m.armor[part] / float(m.max[part])))


func group(m: Dictionary, g: Array, x: float, mine: bool) -> float:
	var part: String = g[0]
	var keys: Array = g[2]
	var w := 84.0 if part == "legs" else 64.0 * keys.size() + 8.0 * (keys.size() - 1)
	var status: String
	var sc := Color.WHITE
	if part == "core":
		status = tr("heatN").format({"n": roundi(m.heat)})
		sc = A.heat_text
	elif m.armor[part] <= 0 and part != "head":
		status = tr("jam")
		sc = A.jam_text
	else:
		status = str(ceili(100.0 * maxf(0.0, m.armor[part]) / m.max[part]))
		sc = tone(maxf(0.0, m.armor[part]) / float(m.max[part]))
	txt(tr(g[1]), Vector2(x, 60), 11, A.dim)
	txt(status, Vector2(x, 62), 15, sc, HORIZONTAL_ALIGNMENT_RIGHT, w, heavy)
	for i in keys.size():
		key_cap(m, keys[i], Vector2(x + i * 72.0, 70), mine)
	return w


func key_cap(m: Dictionary, key: String, at: Vector2, mine: bool) -> void:
	var r := Rect2(at, Vector2(84 if key == "dash" else 64, 64))
	var kn := tr(KEYS[key][1 if pad and mine else 0])
	var cd: float = m.cd.get(key, 0.0)
	var jam: bool = Sim.ARM_OF.has(key) and Sim.jammed(m, Sim.ARM_OF[key])
	var bg: Color = A.team[m.team]
	var ink: Color = A.ground
	var big := kn
	var small := ""
	var small_c := Color(0, 0, 0, 0)
	var name := ""
	var lit := false
	var fill := 0.0
	var pips := 0
	match key:
		"left", "right":
			name = tr("p_" + m.loadout[key])
		"shield":
			name = tr("slotShield")
			lit = Sim.shield_up(m)
		"hook":
			var sk := Sim.e_skill(m)
			if sk == "":
				poly(cut(r, 10), Color(A.raised, 0.4))
				return
			name = tr("e_" + sk)
			lit = Sim.e_active(m)
		"dash":
			name = tr("p_" + m.loadout.booster)
			pips = Sim.charges(m.loadout)
			cd = 0.0 if m.dashes > 0 else 1.0
			big = ""
			small = kn
		"ult":
			name = tr("u_" + Sim.ult_of(m.loadout))
			cd = 0.0
			var ready: bool = m.surge >= Sim.SURGE.max
			bg = A.surge if ready else A.raised
			ink = A.ground if ready else Color.WHITE
			if not ready:
				fill = m.surge / float(Sim.SURGE.max)
				small = str(int(m.surge))
				small_c = A.surge_text
	if cd > 0.0 and key != "ult":
		bg = A.line
		ink = A.jam_text if jam else Color.WHITE
		if key != "dash":
			big = "%.1f" % (cd / Sim.TICKS)
			small = kn
	if jam:
		small = (small + " " if small != "" else "") + "×2"
		small_c = A.jam_text if cd > 0.0 else A.ground
	elif small_c.a == 0.0:
		small_c = ink
	var shape := cut(r, 10)
	poly(shape, bg)
	if fill > 0.0:
		var f := Rect2(r.position.x, r.end.y - r.size.y * fill, r.size.x, r.size.y * fill)
		for p in Geometry2D.intersect_polygons(rect_poly(f), shape):
			poly(p, Color(A.surge, 0.45))
	if jam:
		for p in Geometry2D.intersect_polygons(rect_poly(Rect2(r.position.x, r.end.y - 4, r.size.x, 4)), shape):
			poly(p, A.danger)
	if lit:
		canvas.draw_polyline(shape + PackedVector2Array([shape[0]]), ac(Color.WHITE), 2.0, true)
	if key == "dash":
		txt(small, Vector2(r.position.x, r.position.y + 29), 12, ink, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		for i in pips:
			var px := r.position.x + r.size.x / 2.0 + (i - (pips - 1) / 2.0) * 15.0 - 5.0
			canvas.draw_rect(Rect2(px, r.position.y + 36, 10, 10), ac(Color(A.ground, 1.0 if i < m.dashes else 0.3)))
	else:
		if small != "":
			txt(small, r.position + Vector2(6, 14), 10, small_c)
		txt(big, Vector2(r.position.x, r.position.y + 40), fit(big, heavy, 24, r.size.x - 8.0), ink, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, heavy)
	txt(name, Vector2(r.position.x - 8, r.end.y + 15), fit(name, label_f, 11, r.size.x + 14.0), A.soft, HORIZONTAL_ALIGNMENT_CENTER, r.size.x + 16.0)


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
		rival_bot(ms[1], Vector2(cx + 356.0, 18.0))
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


func armor_c(f: float) -> Color:
	return A.good if f > 0.5 else (A.hazard if f > 0.25 else A.danger)


func is_jam(m: Dictionary, part: String) -> bool:
	return m.armor[part] <= 0 and part != "head"


func part_block(m: Dictionary, part: String, r: Rect2, n: float) -> void:
	var shape := cut(r, n) if n > 0.0 else rect_poly(r)
	if is_jam(m, part):
		stripes(shape, r, A.danger, A.jam_dark, 8.0, -r.size.y)
	else:
		poly(shape, A.line if m.armor[part] <= 0 else armor_c(armor_frac(m, part)))


func part_number(m: Dictionary, part: String, r: Rect2) -> void:
	var jam := is_jam(m, part)
	var s := tr("jam") if jam else str(ceili(100.0 * armor_frac(m, part)))
	var ink: Color = Color.WHITE if m.armor[part] <= 0 else A.ground
	txt(s, Vector2(r.position.x, r.get_center().y + 8.0), fit(s, heavy, 22, r.size.x - 4.0), ink, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, heavy)


func gauge(p: Vector2, f: float, c: Color, name: String, nc: Color) -> void:
	txt(name, Vector2(p.x, p.y + 10), 10, nc, HORIZONTAL_ALIGNMENT_CENTER, 28.0)
	var box := Rect2(p.x, p.y + 16, 28, 212)
	canvas.draw_rect(box, ac(A.line), false, 1.0)
	var top := box.position.y + 1.0
	var i := 0
	while i * 11.0 < 210.0:
		var y := top + 210.0 - i * 11.0 - 8.0
		if y >= top:
			canvas.draw_rect(Rect2(box.position.x + 1.0, y, 26, 8), ac(c if i * 11.0 < f * 210.0 else A.raised))
		i += 1
	txt(str(roundi(f * 100.0)), Vector2(p.x, p.y + 247), 15, nc, HORIZONTAL_ALIGNMENT_CENTER, 28.0, heavy)


func side_panel(m: Dictionary, at: Vector2) -> void:
	var t: Color = A.team[m.team]
	fade = 0.4 if m.ko else 1.0
	canvas.draw_set_transform(at, 0.0, Vector2(SIDE_K, SIDE_K))
	poly(PackedVector2Array([Vector2(18, 0), Vector2(SIDE.x, 0), Vector2(SIDE.x, SIDE.y - 18), Vector2(SIDE.x - 18, SIDE.y), Vector2(0, SIDE.y), Vector2(0, 18)]), Color(A.panel, 0.94))
	poly(rect_poly(Rect2(18, 0, SIDE.x - 18, 4)), t)
	var nm := mech_name(m.id).to_upper()
	var pw := heavy.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x + 36.0
	poly(slant(Rect2(16, 18, pw, 33), -15.3), t)
	txt(nm, Vector2(16, 42), 21, A.ground, HORIZONTAL_ALIGNMENT_CENTER, pw, heavy)
	txt(tr("whoYou") if m.id == 0 else tr("whoBot").format({"n": m.id + 1}), Vector2(16, 40), 11, A.dim, HORIZONTAL_ALIGNMENT_RIGHT, SIDE.x - 32.0)
	var g := Vector2(16, 65)
	gauge(g, clampf(m.heat / float(Sim.HEAT.max), 0.0, 1.0), A.heat, tr("barHeat"), A.heat_text)
	gauge(Vector2(SIDE.x - 44.0, g.y), clampf(m.surge / float(Sim.SURGE.max), 0.0, 1.0), A.surge, tr("capR"), A.surge_text)
	var d := g + Vector2(36, 4)
	canvas.draw_rect(Rect2(d + Vector2(112, 46), Vector2(16, 10)), ac(A.line))
	poly(cut(Rect2(d + Vector2(72, 54), Vector2(96, 74)), 8), A.core)
	canvas.draw_rect(Rect2(d + Vector2(104, 72), Vector2(32, 38)), ac(A.raised))
	for b in DIAGRAM:
		var r: Rect2 = b[1]
		r.position += d
		part_block(m, b[0], r, 6.0)
	for b in DIAGRAM.slice(0, 3):
		part_number(m, b[0], Rect2(d + b[1].position, b[1].size))
	part_number(m, "legs", Rect2(d + Vector2(76, 134), Vector2(88, 100)))
	var gap := (SIDE.x - 32.0 - 46.0 * 6.0) / 5.0
	for i in SLOT_KEYS.size():
		slot(m, SLOT_KEYS[i], Rect2(16.0 + i * (46.0 + gap), g.y + 276.0, 46, 60))
	if m.ko:
		fade = 1.0
		canvas.draw_set_transform(at + Vector2(170, 190) * SIDE_K, deg_to_rad(-4), Vector2(SIDE_K, SIDE_K))
		canvas.draw_rect(Rect2(-50, -20, 100, 40), A.danger)
		txt(tr("ko"), Vector2(-50, 8), 22, A.ground, HORIZONTAL_ALIGNMENT_CENTER, 100.0, heavy)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	fade = 1.0


func slot(m: Dictionary, key: String, r: Rect2) -> void:
	var cd: float = m.cd.get(key, 0.0)
	var jam: bool = Sim.ARM_OF.has(key) and Sim.jammed(m, Sim.ARM_OF[key])
	var bg: Color = A.team[m.team]
	var ink: Color = A.ground
	var kind := key
	var num := ""
	var lit := false
	var fill := 0.0
	var pips := 0
	match key:
		"left", "right":
			kind = "blade" if Sim.weapon(m, key).kind == "melee" else "gun"
		"shield":
			bg = A.raised
			ink = A.soft
			lit = Sim.shield_up(m)
		"hook":
			if Sim.e_skill(m) == "":
				poly(cut(r, 8), Color(A.raised, 0.4))
				return
			kind = "skill"
			bg = A.raised
			ink = A.soft
			lit = Sim.e_active(m)
		"dash":
			bg = A.raised
			ink = A.soft
			pips = Sim.charges(m.loadout)
			cd = 0.0 if m.dashes > 0 else 1.0
		"ult":
			cd = 0.0
			var ready: bool = m.surge >= Sim.SURGE.max
			bg = A.surge if ready else A.raised
			ink = A.ground if ready else A.soft
			if not ready:
				fill = m.surge / float(Sim.SURGE.max)
				num = str(int(m.surge))
				if fill > 0.5:
					ink = A.ground
	if cd > 0.0:
		bg = A.line
		ink = Color.WHITE
		if key != "dash":
			num = "%.1f" % (cd / Sim.TICKS)
	if jam and num == "":
		num = "×2"
	var shape := cut(r, 8)
	poly(shape, bg)
	if fill > 0.0:
		var f := Rect2(r.position.x, r.end.y - r.size.y * fill, r.size.x, r.size.y * fill)
		for p in Geometry2D.intersect_polygons(rect_poly(f), shape):
			poly(p, Color(A.surge, 0.85))
	if jam:
		for p in Geometry2D.intersect_polygons(rect_poly(Rect2(r.position.x, r.end.y - 4, r.size.x, 4)), shape):
			poly(p, A.danger)
	if lit:
		canvas.draw_polyline(shape + PackedVector2Array([shape[0]]), ac(Color.WHITE), 2.0, true)
	var tall := num != "" or pips > 0
	icon(kind, Vector2(r.get_center().x, r.position.y + (24.0 if tall else 30.0)), 1.07 if key == "left" or key == "right" else 0.93, ink)
	if num != "":
		txt(num, Vector2(r.position.x, r.position.y + 51), 14, ink, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, heavy)
	for i in pips:
		var px := r.get_center().x + (i - (pips - 1) / 2.0) * 12.0 - 4.0
		canvas.draw_rect(Rect2(px, r.position.y + 44, 8, 8), ac(A.hazard if i < m.dashes else Color(A.ground, 0.7)))


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
	return [PackedVector2Array([Vector2(14, 3), Vector2(24, 14), Vector2(14, 25), Vector2(4, 14), Vector2(14, 3)]), PackedVector2Array([Vector2(14, 10), Vector2(18, 14), Vector2(14, 18), Vector2(10, 14), Vector2(14, 10)])]


func icon(kind: String, c: Vector2, k: float, col: Color) -> void:
	for line in icon_lines(kind):
		var pts := PackedVector2Array()
		for p in line:
			pts.append(c + (p - Vector2(14, 14)) * k)
		canvas.draw_polyline(pts, ac(col), 2.2 * k, true)


func rival_bot(m: Dictionary, at: Vector2) -> void:
	fade = 0.4 if m.ko else 1.0
	canvas.draw_set_transform(at)
	poly(PackedVector2Array([Vector2(0, 0), Vector2(132, 0), Vector2(132, 50), Vector2(122, 60), Vector2(0, 60)]), Color(A.panel, 0.94))
	poly(rect_poly(Rect2(0, 0, 132, 3)), A.team[m.team])
	var o := Vector2(10, 5)
	poly(rect_poly(Rect2(o + Vector2(19, 12), Vector2(22, 16))), A.core)
	for b in MINI:
		var r: Rect2 = b[1]
		r.position += o
		part_block(m, b[0], r, 0.0)
	var worst := 1.0
	var wp := "head"
	for p in PARTS:
		var f := armor_frac(m, p)
		if f < worst:
			worst = f
			wp = p
	var s := tr("jam") if is_jam(m, wp) else str(ceili(100.0 * worst))
	txt(s, Vector2(78, 36), fit(s, heavy, 22, 48.0), armor_c(worst), HORIZONTAL_ALIGNMENT_LEFT, -1.0, heavy)
	txt("%s %d" % [tr("capR"), int(m.surge)], Vector2(78, 53), 10, A.surge_text)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	fade = 1.0


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


func segs(at: Vector2, w: float, n: int, frac: float, c: Color) -> void:
	var sw := (w - 2.0 * (n - 1)) / n
	var lit := ceili(clampf(frac, 0.0, 1.0) * n)
	for i in n:
		var a := at.x + i * (sw + 2.0)
		var pts := PackedVector2Array([Vector2(a + 2, at.y), Vector2(a + sw, at.y), Vector2(a + sw - 2, at.y + 5), Vector2(a, at.y + 5)])
		if i < lit:
			canvas.draw_colored_polygon(pts, c)
		else:
			pts.append(pts[0])
			canvas.draw_polyline(pts, SEG_OFF, 1.0)


func mech_panel(m: Dictionary, at: Vector2, title: String) -> void:
	var t: int = m.team
	canvas.draw_style_box(Garage.plate(PANEL, EDGE, 1, 10), Rect2(at, PANEL_SIZE))
	canvas.draw_rect(Rect2(at + Vector2(0, 10), Vector2(3, PANEL_SIZE.y - 20)), Mech.TEAM[t])
	label(title, at + Vector2(12, 19), 15, Mech.TEAM_LIGHT[t], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 0, bold)
	canvas.draw_line(at + Vector2(12, 25), at + Vector2(208, 25), Color(ACCENT, 0.4), 1.0)
	canvas.draw_line(at + Vector2(75, 25), at + Vector2(145, 25), ACCENT, 2.0)
	var fig := Transform2D(0, at) * FIG
	for line in SHAPES.core:
		canvas.draw_polyline(fig * PackedVector2Array(line), WIRE, 1.2, true)
	for p in PARTS:
		var f: float = maxf(0.0, m.armor[p]) / float(m.max[p])
		var c := hp_color(f)
		for line in SHAPES[p]:
			canvas.draw_polyline(fig * PackedVector2Array(line), WIRE if f > 0.5 else c, 1.2, true)
		if f <= 0:
			var r: Rect2 = fig * BROKEN[p]
			canvas.draw_line(r.position, r.end, HEAT_C, 2.0, true)
			canvas.draw_line(Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), HEAT_C, 2.0, true)
		var o: Array = READOUT[p]
		segs(at + o[0], o[1], 6, f, c)
		canvas.draw_string(bold, at + o[2], str(int(maxf(0.0, m.armor[p]))), o[3], 60, 17, c)
	var hot := Sim.hot_of(m)
	label(tr("heat"), at + Vector2(10, 134), 11, Color8(255, 176, 112))
	segs(at + Vector2(44, 127), 52, 5, m.heat / 100.0, HEAT_C if hot or m.overheat > 0 else ACCENT)
	canvas.draw_line(at + Vector2(110, 124), at + Vector2(110, 136), Color(ACCENT, 0.5), 1.0)
	var full: bool = m.surge >= Sim.SURGE.max
	label(tr("surge"), at + Vector2(118, 134), 11, SURGE_C)
	segs(at + Vector2(158, 127), 52, 5, m.surge / float(Sim.SURGE.max), SURGE_C if not full else SURGE_C.lightened(0.4))
	if m.overheat > 0:
		label(tr("overheat"), at + Vector2(12, PANEL_SIZE.y + 16), 12, HEAT_C, HORIZONTAL_ALIGNMENT_LEFT, -1, 4)
	elif hot:
		label(tr("hot"), at + Vector2(12, PANEL_SIZE.y + 16), 12, HEAT_C, HORIZONTAL_ALIGNMENT_LEFT, -1, 4)


func siege_top(size: Vector2) -> void:
	var sg: Dictionary = state.siege
	var w: Dictionary = sg.wave
	var r := Rect2(size.x / 2.0 - 150, 12, 300, 76)
	plate(r)
	label(tr("siegeWave").format({"n": w.n if w.live else w.n + 1}), Vector2(r.position.x, r.position.y + 32), 28, TEXT, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 0, bold)
	var left: int = sg.enemies.filter(func(e): return e.act != "die" and not e.get("neutral", false)).size() + sg.queue.filter(func(q): return q.has("kind")).size()
	var sub: String = tr("siegeLeft").format({"n": left}) if w.live or w.next_in > 36000 else tr("siegeNext").format({"s": int(ceil(w.next_in / float(Sim.TICKS)))})
	label(sub + "   " + tr("siegeFund").format({"n": sg.fund}) + "   " + tr("siegeWallet").format({"n": sg.wallets[0]}) + ("   " + tr("siegeTokens").format({"n": sg.tokens[0]}) if sg.tokens[0] > 0 else ""), Vector2(r.position.x, r.position.y + 50), 13, DIM, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var c: Dictionary = sg.core
	var bar := Rect2(r.position.x + 16, r.position.y + 58, r.size.x - 32, 10)
	canvas.draw_rect(bar, SEG_OFF)
	canvas.draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(c.hp / c.max, 0, 1), bar.size.y)), hp_color(c.hp / c.max))
	for i in 4:
		var x := bar.position.x + bar.size.x * (3 - i) / 4.0
		canvas.draw_rect(Rect2(x - 1, bar.position.y - 3, 2, bar.size.y + 6), WIRE if c.rings[i] > 0 else HEAT_C)
	label(tr("siegeCore"), Vector2(bar.position.x, bar.position.y - 2), 10, DIM)
	var G: Dictionary = sg.garrison
	if G.tier > 0:
		var gt := tr("siegeGuard").format({"t": G.tier}) if G.respawn_in <= 0 else tr("siegeGuardDown").format({"t": G.tier, "s": int(ceil(G.respawn_in / float(Sim.TICKS)))})
		label(gt, Vector2(r.position.x, r.position.y + r.size.y + 16), 13, WIRE if G.respawn_in <= 0 else HEAT_C, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 4, bold)


func siege_shop(size: Vector2) -> void:
	var sg: Dictionary = state.siege
	var y := size.y - SLOT.y - 14 - 30
	var left: int = int(ceil(maxf(0, sg.wave.next_in - 480) / float(Sim.TICKS)))
	var line: String = tr("siegeShop")
	if left > 0 and left < 600:
		line += "   ·   " + tr("siegeCall").format({"n": 2 * left})
	label(line, Vector2(0, y - 22), 15, ACCENT, HORIZONTAL_ALIGNMENT_CENTER, size.x, 4, bold)
	label(tr("siegeKeys") + "   ·   " + tr("siegeUse"), Vector2(0, y), 12, DIM, HORIZONTAL_ALIGNMENT_CENTER, size.x, 4)


func shop_menu(i: int) -> Array:
	var sg: Dictionary = state.siege
	var m: Dictionary = state.mechs[i]
	var w: int = sg.wallets[i]
	var tier := func(slot: String) -> Dictionary:
		var c := Siege.price_of(sg, m, "tier:" + slot)
		var t: int = sg.tiers[i][slot]
		var note: String = tr("noteMax") if c < 0 else tr("noteTier").format({"a": t, "b": t + 1}) + " · " + tr("fx_" + ("hand" if slot in ["left", "right"] else slot))
		return {"id": "tier:" + slot, "label_key": "tier_" + slot, "cost": c, "enabled": c >= 0 and w >= c, "sub": [], "note": note}
	var wallet := func(id: String) -> Dictionary:
		var c := Siege.price_of(sg, m, id)
		return {"id": id, "label_key": "shop_" + id, "cost": c, "enabled": w >= c or (id == "reinforce" and sg.tokens[i] > 0), "sub": [], "note": ""}
	var parts := []
	for slot in Siege.S.PART_SLOTS:
		var keys := []
		for key in Sim.CATALOG[slot]:
			var c := Siege.price_of(sg, m, "swap:%s:%s" % [slot, key])
			if c >= 0:
				keys.append({"id": "swap:%s:%s" % [slot, key], "label_key": "p_" + key, "cost": c, "enabled": w >= c, "sub": [], "note": tr("noteLevel").format({"n": Siege.owned_level(sg, i, slot, key)})})
		if not keys.is_empty():
			parts.append({"id": "parts:" + slot, "label_key": "tierShort_" + slot, "cost": -1, "enabled": true, "sub": keys.slice(0, 8), "note": ""})
	var team := []
	for k in ["gate", "rebuild", "ring", "wall", "mine", "laser", "post", "garrison"]:
		var c: int = Siege.next_cost(sg) if k == "garrison" else Siege.SHOP[k]
		team.append({"id": k, "label_key": "shop_" + k, "cost": c, "enabled": c >= 0 and not sg.wave.live and sg.fund >= c, "sub": [], "note": tr("noteFund").format({"n": sg.fund}) if k == "gate" else ""})
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


func siege_tiers(at: Vector2) -> void:
	var t: Dictionary = state.siege.tiers[0]
	plate(Rect2(at, Vector2(PANEL_SIZE.x, 18 + TIER_ROWS.size() * 15)))
	label(tr("siegeTiers"), at + Vector2(10, 14), 11, DIM)
	for r in TIER_ROWS.size():
		var y: float = at.y + 30 + r * 15
		label(tr("tierShort_" + TIER_ROWS[r]), Vector2(at.x + 10, y), 11, TEXT)
		for k in 5:
			canvas.draw_rect(Rect2(at.x + 96 + k * 22, y - 9, 18, 8), ACCENT if k < t[TIER_ROWS[r]] else SEG_OFF)
	var rc = null
	for c in state.siege.recall:
		if c.player == 0:
			rc = c
	if rc != null:
		label(tr("siegeRecall"), at + Vector2(0, 30 + TIER_ROWS.size() * 15 + 12), 13, WIRE, HORIZONTAL_ALIGNMENT_LEFT, -1, 4, bold)
		canvas.draw_rect(Rect2(at + Vector2(0, 30 + TIER_ROWS.size() * 15 + 18), Vector2(PANEL_SIZE.x * rc.t / float(rc.max), 6)), WIRE)


func siege_crate(size: Vector2) -> void:
	for y in state.siege.yards:
		for c in y.crates:
			if c.progress > 0.0:
				var r := Rect2(size.x / 2.0 - 90, size.y * 0.62, 180, 14)
				canvas.draw_rect(r, SEG_OFF)
				canvas.draw_rect(Rect2(r.position, Vector2(r.size.x * c.progress, r.size.y)), SURGE_C)
				label(tr("siegeCrate"), Vector2(r.position.x, r.position.y - 4), 13, TEXT, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 4, bold)


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
			marker(cam, size, spots[key], HEAT_C, "", true)
	for f in state.fx:
		if f.k == "warn":
			var g: Dictionary = sg.gates[f.lane]
			marker(cam, size, Vector3(g.x, 4.0, g.y), HEAT_C if f.boss else ACCENT, tr("siegeIncoming").format({"bot": tr("bot_" + f.kind), "n": f.n}), int(f.t / 15) % 2 == 0)


func marker(cam: Camera3D, size: Vector2, at: Vector3, c: Color, text: String, lit: bool) -> void:
	var inset := 48.0
	var p := cam.unproject_position(at)
	var behind := cam.is_position_behind(at)
	var box := Rect2(Vector2(inset, inset + 90), size - Vector2(inset * 2, inset * 2 + 270))
	if behind or not box.has_point(p):
		var mid := size / 2.0
		var d := (p - mid) * (-1.0 if behind else 1.0)
		var k := minf(absf(box.size.x / 2.0 / d.x) if d.x != 0 else 1e9, absf(box.size.y / 2.0 / d.y) if d.y != 0 else 1e9)
		var e := mid + d * k
		var u := d.normalized()
		var n := Vector2(-u.y, u.x)
		canvas.draw_colored_polygon(PackedVector2Array([e + u * 16, e - u * 8 + n * 11, e - u * 8 - n * 11]), Color(c, 1.0 if lit else 0.45))
		p = e - u * 30
	elif text == "":
		canvas.draw_arc(p, 22, 0, TAU, 24, Color(c, 0.9 if lit else 0.4), 3)
		return
	if text == "":
		return
	var tw := bold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 40.0
	var r := Rect2(p.x - tw / 2.0, p.y - 40, tw, 28)
	canvas.draw_style_box(Garage.plate(PANEL, c if lit else EDGE, 2, 6), r)
	var h := r.position + Vector2(10, 7)
	canvas.draw_rect(Rect2(h + Vector2(0, 4), Vector2(14, 12)), c)
	canvas.draw_colored_polygon(PackedVector2Array([h + Vector2(9, 4), h + Vector2(14, 4), h + Vector2(16, -3)]), c)
	canvas.draw_rect(Rect2(h + Vector2(3, 8), Vector2(8, 3)), Color8(80, 190, 255))
	label(text, Vector2(r.position.x + 30, r.position.y + 20), 15, TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, 4, bold)


func siege_calls(size: Vector2) -> void:
	var cy := size.y * 0.3
	var shown := {}
	for f in state.fx:
		var text := ""
		var sub := ""
		var c := TEXT
		match f.k:
			"cleared":
				text = tr("siegeCleared")
				sub = tr("siegeBonus").format({"n": f.n}) if f.n > 0 else ""
				c = Look.POP.heal
			"call":
				text = tr("siegeBonus").format({"n": f.n})
				c = WIRE
			"ring":
				text = tr("siegeRing")
				c = HEAT_C
			"raid":
				text = tr("siegeRaid").format({"yard": Siege.S.QUADS[f.q].name})
				c = HEAT_C
			"mutator":
				text = tr("siegeMutator").format({"name": tr("mut_" + f.id)})
				sub = tr("mutd_" + f.id)
				c = SURGE_C
			"tactic":
				var names: Array = f.lanes.map(func(l): return Siege.S.LANES[l].name)
				var air: Array = Siege.S.AIR[f.get("corner", 0)]
				var yard: Array = Siege.S.QUADS.filter(func(q): return q.sx == signi(int(air[0])) and q.sy == signi(int(air[1])))
				var parts: PackedStringArray = tr("dir_" + f.id).format({"a": names[0] if names.size() > 0 else "", "b": names[1] if names.size() > 1 else "", "lane": names[0] if names.size() > 0 else "", "corner": yard[0].name}).split("|")
				text = parts[0]
				sub = parts[1] if parts.size() > 1 else ""
				c = WIRE if f.id == "breather" else HEAT_C
			"warn":
				if f.boss:
					text = tr("siegeBoss")
					c = HEAT_C
		if text != "" and not shown.has(text):
			shown[text] = true
			label(text, Vector2(0, cy), 54, c, HORIZONTAL_ALIGNMENT_CENTER, size.x, 10, heavy, 20)
			if sub != "":
				label(sub, Vector2(0, cy + 36), 24, TEXT, HORIZONTAL_ALIGNMENT_CENTER, size.x, 6, bold)
			cy += 70


func cd_frac(key: String, cur: float) -> float:
	if cur > last.get(key, 0.0):
		top[key] = cur
	last[key] = cur
	return cur / top.get(key, 1.0) if cur > 0 else 0.0


func slots(size: Vector2) -> void:
	var m = state.mechs[0]
	var w := SLOT.x
	var gap := 6.0
	var x0 := size.x / 2.0 - (SLOTS.size() * w + (SLOTS.size() - 1) * gap) / 2.0
	var y := size.y - SLOT.y - 14
	for i in SLOTS.size():
		var key: String = SLOTS[i][0]
		var r := Rect2(x0 + i * (w + gap), y, w, SLOT.y)
		plate(r)
		if key == "hook" and Sim.e_skill(m) == "":
			continue
		var frac := 0.0
		var lit := false
		var accent := DIM
		var name := ""
		match key:
			"left", "right":
				frac = cd_frac(key, m.cd[key])
				accent = Color8(110, 190, 255) if Sim.is_gun(Sim.weapon(m, key)) else Color8(255, 160, 80)
				name = tr("p_" + m.loadout[key])
			"shield":
				frac = cd_frac(key, m.cd.shield)
				lit = Sim.shield_up(m)
				name = tr("slotShield")
			"hook":
				frac = cd_frac(key, m.cd.hook)
				lit = Sim.e_active(m)
				name = tr("e_" + Sim.e_skill(m))
			"dash":
				frac = cd_frac(key, m.cd.dash) if m.dashes == 0 else 0.0
				name = tr("slotDash")
			"ult":
				frac = 1.0 - m.surge / float(Sim.SURGE.max)
				lit = m.surge >= Sim.SURGE.max
				accent = SURGE_C
				name = tr("slotUlt")
		canvas.draw_rect(Rect2(r.position + Vector2(8, SLOT.y - 4), Vector2(w - 16, 3)), accent)
		if frac > 0:
			var shade := Garage.plate(Color(0, 0, 0, 0.6), Color.TRANSPARENT, 0, 8)
			shade.corner_radius_bottom_right = 0
			canvas.draw_style_box(shade, Rect2(r.position, Vector2(w, SLOT.y * frac)))
		if lit:
			canvas.draw_style_box(Garage.plate(Color.TRANSPARENT, SURGE_C if key == "ult" else Color8(140, 200, 255), 2, 9), r.grow(2))
		label(tr(SLOTS[i][2 if pad else 1]), r.position + Vector2(0, 22), 15, TEXT, HORIZONTAL_ALIGNMENT_CENTER, w, 4, bold)
		var fs := 11
		while fs > 8 and font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w - 6:
			fs -= 1
		label(name, r.position + Vector2(0, 39), fs, DIM, HORIZONTAL_ALIGNMENT_CENTER, w, 3)
		if key == "dash":
			var n := Sim.charges(m.loadout)
			for k in n:
				canvas.draw_circle(r.position + Vector2(w / 2.0 + (k - (n - 1) / 2.0) * 10, 47), 3.0, TEXT if k < m.dashes else Color(1, 1, 1, 0.2))


func has_fx(kind: String):
	for f in state.fx:
		if f.k == kind:
			return f
	return null


