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
const SLOTS := [["left", "capLmb", "capLt"], ["right", "capRmb", "capRt"], ["shield", "capQ", "capRb"], ["hook", "capE", "capL3"], ["dash", "capSpace", "capLb"], ["ult", "capR", "capR3"]]

signal resume
signal restart
signal quit
signal ui(kind: String)

var state: Dictionary
var view: Node3D
var paused := false
var pad := false
var level := ""
## How many of the mechs (the first ones) are people.
var humans := 1
var canvas: Control
var font: Font
var bold: FontVariation
var heavy: FontVariation
var top := {}
var last := {}
var menu: VBoxContainer
var replay := -1.0
var hp_was := {}
var best := 0
var hurt_at := {}


func _ready() -> void:
	font = Look.font(Look.FONT.text)
	bold = Look.font(Look.FONT.bold)
	heavy = Look.font(Look.FONT.heavy, true, Look.FONT.impact)
	canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(paint)
	add_child(canvas)
	menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation", 10)
	menu.set_anchors_preset(Control.PRESET_CENTER)
	menu.grow_horizontal = Control.GROW_DIRECTION_BOTH
	menu.offset_top = -40
	for row in [["mResume", resume], ["mRestart", restart], ["mGarage", quit]]:
		var b := Button.new()
		b.text = row[0]
		b.custom_minimum_size = Vector2(280, 46)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_font_size_override("font_size", 18)
		b.add_theme_stylebox_override("normal", Garage.plate(Garage.CARD, Garage.LINE, 1, 8))
		for s in ["hover", "pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(s, Garage.plate(Garage.SEL, Garage.HI, 2, 8))
		b.add_theme_stylebox_override("focus", Garage.plate(Color.TRANSPARENT, Garage.HI, 3, 8))
		b.pressed.connect(row[1].emit)
		b.pressed.connect(ui.emit.bind("select"))
		b.mouse_entered.connect(ui.emit.bind("hover"))
		b.focus_entered.connect(ui.emit.bind("hover"))
		menu.add_child(b)
	var vol := Sfx.volumes()
	for row in [["vMaster", "Master"], ["vMusic", "Music"], ["vSfx", "SFX"], ["vEnv", "Env"], ["vCrowd", "Crowd"]]:
		var line := HBoxContainer.new()
		var l := Label.new()
		l.text = row[0]
		l.custom_minimum_size = Vector2(100, 0)
		l.add_theme_font_size_override("font_size", 15)
		l.add_theme_color_override("font_color", DIM)
		line.add_child(l)
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		s.value = vol[row[1]]
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var bus: String = row[1]
		s.value_changed.connect(func(v: float) -> void: Sfx.set_volume(bus, v))
		s.drag_ended.connect(func(_c: bool) -> void: ui.emit("select"))
		line.add_child(s)
		menu.add_child(line)
	menu.visible = false
	add_child(menu)


func _process(_dt: float) -> void:
	var was := menu.visible
	menu.visible = paused and visible
	if menu.visible and not was:
		menu.get_child(0).grab_focus()
	while view != null and view.pops.size() and view.tick - view.pops[0].at >= NUMBER.life:
		view.pops.pop_front()
	canvas.queue_redraw()


func plate(r: Rect2, fill := PANEL) -> void:
	canvas.draw_style_box(Garage.plate(fill, EDGE, 1, 8), r)


func tag(r: Rect2, side: int) -> void:
	var s := Garage.plate(Color(Mech.TEAM[side].darkened(0.6), 0.9), Mech.TEAM_LIGHT[side], 2, 0)
	var k := int(r.size.y / 2.0)
	if side == 0:
		s.corner_radius_top_left = k
		s.corner_radius_bottom_left = k
	else:
		s.corner_radius_top_right = k
		s.corner_radius_bottom_right = k
	canvas.draw_style_box(s, r)


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
		for i in humans:
			mech_panel(state.mechs[i], corner(i, size), name_of(i))
		siege_tiers(Vector2(16, 16 + PANEL_SIZE.y + 10))
		siege_top(size)
		siege_marks(size)
		if not paused:
			if humans == 1:
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
		for i in state.mechs.size():
			mech_panel(state.mechs[i], corner(i, size), name_of(i) + ("  ·  %d" % state.score[state.mechs[i].team] if state.score.size() > 2 else ""))
		clock(size)
		if not paused and humans == 1:
			slots(size)
		callouts(size)
	if paused:
		canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.5))
		label(tr("mPaused"), Vector2(0, size.y * 0.3), 72, TEXT, HORIZONTAL_ALIGNMENT_CENTER, size.x, 10, bold)
		label(tr("pauseHint"), Vector2(0, size.y * 0.3 + 46), 20, DIM, HORIZONTAL_ALIGNMENT_CENTER, size.x, 6)


## Panel spots: top left, top right, bottom left, bottom right.
func corner(i: int, size: Vector2) -> Vector2:
	var x := 16.0 if i % 2 == 0 else size.x - 16 - PANEL_SIZE.x
	return Vector2(x, 16.0 if i < 2 else size.y - 36 - PANEL_SIZE.y)


func name_of(i: int) -> String:
	if i < humans:
		return tr("you") if humans == 1 else tr("playerN").format({"n": i + 1})
	if humans == 1 and i == 1 and not state.has("siege"):
		return tr("rivalBot") + ("  ·  " + tr("lv_" + level) if level != "" else "")
	return tr("rivalBot")


## The text for a win by `team`: You win / Rival wins alone, the winner's name with more people.
func win_text(team: int) -> String:
	if humans == 1:
		return tr("youWin") if team == state.mechs[0].team else tr("rivalWins")
	for i in state.mechs.size():
		if state.mechs[i].team == team:
			return tr("wins").format({"name": name_of(i)})
	return ""


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
		label(n.text, Vector2(-200, px * 0.35), px, c, HORIZONTAL_ALIGNMENT_CENTER, 400.0, NUMBER.outline, heavy, NUMBER.glow)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)


func replay_bars(size: Vector2) -> void:
	var bar := roundf(size.y * BARS * minf(1.0, replay * 20.0))
	canvas.draw_rect(Rect2(0, 0, size.x, bar), Color.BLACK)
	canvas.draw_rect(Rect2(0, size.y - bar, size.x, bar), Color.BLACK)
	canvas.draw_rect(Rect2(0, size.y - bar, size.x * replay, 2), Color(REC, 0.85))
	if Time.get_ticks_msec() / 500 % 2 == 1:
		canvas.draw_circle(Vector2(26, bar / 2.0), 6, REC)
	canvas.draw_string(bold, Vector2(40, bar / 2.0 + 7), tr("kcReplay"), HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color.WHITE)
	label(tr("kcSkip"), Vector2(0, size.y - bar / 2.0 + 5), 13, Color(1, 1, 1, 0.5), HORIZONTAL_ALIGNMENT_RIGHT, size.x - 24)


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


func clock(size: Vector2) -> void:
	var r := Rect2(size.x / 2.0 - 60, 12, 120, 52)
	var n: int = Sim.MATCH.wins
	var tw := 30.0 + n * 16.0
	for side in (2 if state.score.size() == 2 else 0):
		var box := Rect2(r.position.x - tw - 4 if side == 0 else r.end.x + 4, r.position.y + 6, tw, 40)
		tag(box, side)
		for i in n:
			var x: float = box.end.x - 22 - i * 16 if side == 0 else box.position.x + 10 + i * 16
			var y := box.position.y + 12
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(x + 5, y), Vector2(x + 12, y), Vector2(x + 7, y + 16), Vector2(x, y + 16)]), Mech.TEAM_LIGHT[side] if state.score[side] > i else Color(Mech.TEAM_LIGHT[side], 0.22))
	plate(r)
	var secs := int(ceil(maxf(0.0, state.clock) / Sim.TICKS))
	label("%d:%02d" % [floori(secs / 60.0), secs % 60], Vector2(r.position.x, r.position.y + 33), 30, TEXT if secs > 10 else HEAT_C, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 0, bold)
	label(tr("round").format({"n": state.round}), Vector2(r.position.x, r.position.y + 47), 11, DIM, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


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


func callouts(size: Vector2) -> void:
	var cy := size.y * 0.38
	var w := size.x
	match state.phase:
		"countdown":
			label(tr("round").format({"n": state.round}), Vector2(0, cy - 40), 34, TEXT, HORIZONTAL_ALIGNMENT_CENTER, w, 8, bold, 16)
			if state.timer > 0:
				label(str(int(ceil(state.timer / float(Sim.TICKS)))), Vector2(0, cy + 70), 120, Color8(255, 214, 120), HORIZONTAL_ALIGNMENT_CENTER, w, 14, heavy, 32)
		"ko":
			var title: String = tr("timeUp") if state.finalKo < 0 else tr("ko")
			label(title, Vector2(0, cy + 30), 120, Color8(255, 214, 120), HORIZONTAL_ALIGNMENT_CENTER, w, 14, heavy, 32)
			var sub: String = tr("draw") if state.winner < 0 else win_text(state.winner)
			var c: Color = TEXT if state.winner < 0 else Mech.TEAM_LIGHT[state.winner]
			label(sub, Vector2(0, cy + 80), 30, c, HORIZONTAL_ALIGNMENT_CENTER, w, 8, bold, 14)
		"over":
			var best := 0
			for t in state.score.size():
				if state.score[t] > state.score[best]:
					best = t
			var big: String = (tr("victory") if best == 0 else tr("defeat")) if humans == 1 else win_text(best)
			label(big, Vector2(0, cy + 30), 120 if humans == 1 else 90, Mech.TEAM_LIGHT[best], HORIZONTAL_ALIGNMENT_CENTER, w, 14, heavy, 32)
			label(tr("rematch"), Vector2(0, cy + 84), 26, TEXT, HORIZONTAL_ALIGNMENT_CENTER, w, 8, bold)
		"fight":
			var go = has_fx("fight")
			if go != null:
				label(tr("go"), Vector2(0, cy + 40), 110, Color(1, 0.84, 0.47, go.t / 50.0), HORIZONTAL_ALIGNMENT_CENTER, w, 14, heavy, 32)
	var at := [Vector2(16, 16 + PANEL_SIZE.y + 28), Vector2(size.x - 16, 16 + PANEL_SIZE.y + 28), Vector2(size.x / 2.0, 72)]
	for f in state.fx:
		var text := ""
		var c := TEXT
		var side := 2
		match f.k:
			"closing":
				text = tr("closing")
				c = Look.POP.head
			"ventsOn":
				text = tr("ventsOn")
				c = Look.POP.block
			"healUp":
				text = tr("healReady")
				c = Look.POP.heal
			"break":
				text = tr("broke_" + f.part)
				c = Mech.TEAM_LIGHT[state.mechs[f.id].team]
				side = f.id % 2
		if text != "":
			var tw := bold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 24.0
			var x: float = at[side].x - [0.0, tw, tw / 2.0][side]
			canvas.draw_style_box(Garage.plate(PANEL, c, 1, 6), Rect2(x, at[side].y, tw, 26))
			label(text, Vector2(x, at[side].y + 19), 16, c, HORIZONTAL_ALIGNMENT_CENTER, tw, 4, bold)
			at[side].y += 30
