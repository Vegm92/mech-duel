extends CanvasLayer

const Sim = preload("res://src/sim.gd")
const Mech = preload("res://src/mech.gd")

const PANEL := Color(0.04, 0.11, 0.23, 0.82)
const EDGE := Color(0.31, 0.59, 0.9, 0.5)
const TEXT := Color(0.91, 0.95, 1.0)
const DIM := Color(0.5, 0.65, 0.84)
const SURGE_C := Color(0.77, 0.55, 1.0)
const HEAT_C := Color(1.0, 0.36, 0.24)
const PARTS := ["head", "larm", "rarm", "legs"]
const SLOTS := [["left", "capLmb"], ["right", "capRmb"], ["shield", "capQ"], ["hook", "capE"], ["dash", "capSpace"], ["ult", "capR"]]

var state: Dictionary
var paused := false
var canvas: Control
var font: Font
var top := {}
var last := {}


func _ready() -> void:
	font = ThemeDB.fallback_font
	canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(paint)
	add_child(canvas)


func _process(_dt: float) -> void:
	canvas.queue_redraw()


func plate(r: Rect2, fill := PANEL) -> void:
	canvas.draw_rect(r, fill)
	canvas.draw_rect(r, EDGE, false, 1.5)


func label(s: String, pos: Vector2, size: int, c: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, outline := 0) -> void:
	if outline > 0:
		canvas.draw_string_outline(font, pos, s, align, width, size, outline, Color(0, 0, 0, 0.85))
	canvas.draw_string(font, pos, s, align, width, size, c)


func bar(r: Rect2, frac: float, c: Color) -> void:
	canvas.draw_rect(r, Color(0, 0, 0, 0.45))
	canvas.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(frac, 0.0, 1.0), r.size.y)), c)


func hp_color(f: float) -> Color:
	if f <= 0:
		return Color8(58, 63, 72)
	if f > 0.5:
		return Color8(111, 211, 138)
	return Color8(216, 176, 74) if f > 0.25 else Color8(224, 96, 63)


func paint() -> void:
	if state.is_empty():
		return
	var size := canvas.size
	mech_panel(state.mechs[0], Vector2(16, 16), tr("you"))
	mech_panel(state.mechs[1], Vector2(size.x - 16 - 290, 16), tr("rivalBot"))
	clock(size)
	slots(size)
	callouts(size)
	if paused:
		canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.5))
		label(tr("mPaused"), Vector2(0, size.y * 0.45), 72, TEXT, HORIZONTAL_ALIGNMENT_CENTER, size.x, 10)
		label(tr("pauseHint"), Vector2(0, size.y * 0.45 + 46), 22, DIM, HORIZONTAL_ALIGNMENT_CENTER, size.x, 6)


func mech_panel(m: Dictionary, at: Vector2, title: String) -> void:
	var t: int = m.team
	plate(Rect2(at, Vector2(290, 186)))
	canvas.draw_rect(Rect2(at, Vector2(4, 186)), Mech.TEAM[t])
	label(title, at + Vector2(16, 28), 19, Mech.TEAM_LIGHT[t])
	for i in PARTS.size():
		var p: String = PARTS[i]
		var y := at.y + 46 + i * 22
		var f: float = maxf(0.0, m.armor[p]) / float(m.max[p])
		label(tr(p), Vector2(at.x + 16, y + 12), 14, DIM)
		bar(Rect2(at.x + 96, y + 2, 140, 12), f, hp_color(f))
		label(str(int(maxf(0.0, m.armor[p]))), Vector2(at.x + 240, y + 13), 13, TEXT, HORIZONTAL_ALIGNMENT_RIGHT, 38)
	var hy := at.y + 152
	var hot := Sim.hot_of(m)
	label(tr("heat"), Vector2(at.x + 16, hy), 14, DIM)
	var hc := HEAT_C if hot or m.overheat > 0 else Color8(255, 170, 90)
	bar(Rect2(at.x + 70, hy - 10, 74, 10), m.heat / 100.0, hc)
	if m.overheat > 0:
		label(tr("overheat"), Vector2(at.x + 16, hy + 20), 12, HEAT_C)
	elif hot:
		label(tr("hot"), Vector2(at.x + 16, hy + 20), 12, HEAT_C)
	label(tr("surge"), Vector2(at.x + 156, hy), 14, DIM)
	var full: bool = m.surge >= Sim.SURGE.max
	bar(Rect2(at.x + 206, hy - 10, 72, 10), m.surge / float(Sim.SURGE.max), SURGE_C if not full else SURGE_C.lightened(0.4))


func clock(size: Vector2) -> void:
	var cx := size.x / 2.0
	var r := Rect2(cx - 72, 12, 144, 70)
	plate(r)
	var secs := int(ceil(maxf(0.0, state.clock) / Sim.TICKS))
	label(str(secs), Vector2(cx - 72, 56), 40, TEXT if secs > 10 else HEAT_C, HORIZONTAL_ALIGNMENT_CENTER, 144)
	label(tr("round").format({"n": state.round}), Vector2(cx - 72, 76), 13, DIM, HORIZONTAL_ALIGNMENT_CENTER, 144)
	for side in 2:
		for i in Sim.MATCH.wins:
			var x: float = cx - 92 - i * 22 if side == 0 else cx + 92 + i * 22
			var on: bool = state.score[side] > i
			canvas.draw_circle(Vector2(x, 47), 8, Mech.TEAM[side] if on else Color(0, 0, 0, 0.5))
			canvas.draw_arc(Vector2(x, 47), 8, 0, TAU, 20, Mech.TEAM_LIGHT[side], 1.5)


func cd_frac(key: String, cur: float) -> float:
	if cur > last.get(key, 0.0):
		top[key] = cur
	last[key] = cur
	return cur / top.get(key, 1.0) if cur > 0 else 0.0


func slots(size: Vector2) -> void:
	var m = state.mechs[0]
	var w := 104.0
	var gap := 8.0
	var x0 := size.x / 2.0 - (SLOTS.size() * w + (SLOTS.size() - 1) * gap) / 2.0
	var y := size.y - w - 18
	for i in SLOTS.size():
		var key: String = SLOTS[i][0]
		var r := Rect2(x0 + i * (w + gap), y, w, w)
		plate(r)
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
				name = tr("slotHook")
			"dash":
				frac = cd_frac(key, m.cd.dash) if m.dashes == 0 else 0.0
				name = tr("slotDash")
			"ult":
				frac = 1.0 - m.surge / float(Sim.SURGE.max)
				lit = m.surge >= Sim.SURGE.max
				accent = SURGE_C
				name = tr("slotUlt")
		canvas.draw_rect(Rect2(r.position + Vector2(0, w - 5), Vector2(w, 5)), accent)
		if frac > 0:
			canvas.draw_rect(Rect2(r.position, Vector2(w, w * frac)), Color(0, 0, 0, 0.6))
		if lit:
			canvas.draw_rect(r.grow(2), SURGE_C if key == "ult" else Color8(140, 200, 255), false, 3.0)
		label(tr(SLOTS[i][1]), r.position + Vector2(0, 30), 15, TEXT, HORIZONTAL_ALIGNMENT_CENTER, w, 4)
		var fs := 12
		while fs > 9 and font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w - 8:
			fs -= 1
		label(name, r.position + Vector2(0, 54), fs, DIM, HORIZONTAL_ALIGNMENT_CENTER, w, 3)
		if key == "dash":
			var n := Sim.charges(m.loadout)
			for k in n:
				canvas.draw_circle(r.position + Vector2(w / 2.0 + (k - (n - 1) / 2.0) * 12, 64), 3.5, TEXT if k < m.dashes else Color(1, 1, 1, 0.2))


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
			label(tr("round").format({"n": state.round}), Vector2(0, cy - 40), 34, TEXT, HORIZONTAL_ALIGNMENT_CENTER, w, 8)
			if state.timer > 0:
				label(str(int(ceil(state.timer / float(Sim.TICKS)))), Vector2(0, cy + 70), 120, Color8(255, 214, 120), HORIZONTAL_ALIGNMENT_CENTER, w, 14)
		"ko":
			var title: String = tr("timeUp") if state.finalKo < 0 else tr("ko")
			label(title, Vector2(0, cy + 30), 120, Color8(255, 214, 120), HORIZONTAL_ALIGNMENT_CENTER, w, 14)
			var sub: String = tr("draw") if state.winner < 0 else (tr("youWin") if state.winner == state.mechs[0].team else tr("rivalWins"))
			var c: Color = TEXT if state.winner < 0 else Mech.TEAM_LIGHT[state.winner]
			label(sub, Vector2(0, cy + 80), 30, c, HORIZONTAL_ALIGNMENT_CENTER, w, 8)
		"over":
			var won: bool = state.score[0] > state.score[1]
			label(tr("victory") if won else tr("defeat"), Vector2(0, cy + 30), 120, Mech.TEAM_LIGHT[0] if won else Mech.TEAM_LIGHT[1], HORIZONTAL_ALIGNMENT_CENTER, w, 14)
			label(tr("again"), Vector2(0, cy + 84), 26, TEXT, HORIZONTAL_ALIGNMENT_CENTER, w, 8)
		"fight":
			var go = has_fx("fight")
			if go != null:
				label(tr("go"), Vector2(0, cy + 40), 110, Color(1, 0.84, 0.47, go.t / 50.0), HORIZONTAL_ALIGNMENT_CENTER, w, 14)
	var y := 112.0
	for f in state.fx:
		var text := ""
		var c := TEXT
		match f.k:
			"closing":
				text = tr("closing")
				c = HEAT_C
			"ventsOn":
				text = tr("ventsOn")
				c = Color8(255, 150, 60)
			"healUp":
				text = tr("healReady")
				c = Color8(90, 255, 150)
			"break":
				text = tr("broke_" + f.part)
				c = Mech.TEAM_LIGHT[state.mechs[f.id].team]
		if text != "":
			label(text, Vector2(0, y), 24, c, HORIZONTAL_ALIGNMENT_CENTER, w, 6)
			y += 30
