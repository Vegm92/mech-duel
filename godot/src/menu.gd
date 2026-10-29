extends CanvasLayer
## The first screens: players join (one device each, up to 4), then pick a mode. A mode opens the garage.

signal picked(mode: String)
signal ui(kind: String)

const Garage = preload("res://src/garage.gd")
const I18n = preload("res://src/i18n.gd")
const Look = preload("res://src/look.gd")
const Mech = preload("res://src/mech.gd")
const Bot = preload("res://src/bot.gd")
const MODES := [["duel", "menuDuel", "menuDuelSub"], ["siege", "siegeBtn", "menuSiegeSub"], ["back", "backBtn", ""]]
const MAX := 4
const TEAMS := {"1v1": [0, 1], "2v2": [0, 0, 1, 1], "ffa": [0, 1, 2, 3]}
const FORMATS := ["1v1", "2v2", "ffa"]
const LEVELS := ["easy", "normal", "hard"]

var root: Control
var bold: FontVariation
var buttons := []
var page := "players"
## One input device per player, in join order; -1 = keyboard + mouse, else a gamepad id.
var players := []
## The Duel setup: format, one slot per mech ({who: player index or -1 = bot, level}), ladder on/off.
var setup := {}
var bot_level := "normal"
var focus_at := 0


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
func open(at := "") -> void:
	visible = true
	page = at if at != "" and not players.is_empty() else ("modes" if not players.is_empty() else "players")
	if page == "duel" and not valid(setup):
		setup = fresh_setup("1v1" if players.size() <= 2 else "ffa")
	build()


func build() -> void:
	for c in root.get_children():
		c.queue_free()
	buttons.clear()
	if page == "duel":
		build_duel()
		return
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
	b.add_theme_stylebox_override("focus", Garage.plate(Color.TRANSPARENT, Garage.GUN, 3, 12))
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
	if players.is_empty():
		players.append(-1)
	if mode in ["back", "modes", "duel"]:
		page = {"back": "players", "modes": "modes", "duel": "duel"}[mode]
		focus_at = 0
		if page == "duel" and not valid(setup):
			setup = fresh_setup("1v1" if players.size() <= 2 else "ffa")
		ui.emit("tab" if mode != "duel" else "select")
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
	if page != "players":
		if no:
			choose("back" if page == "modes" else "modes")
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


## A fresh Duel setup: players fill the slots in join order, bots the rest.
func fresh_setup(fmt: String) -> Dictionary:
	var slots := []
	for k in TEAMS[fmt].size():
		slots.append({"who": k if k < players.size() else -1, "level": bot_level})
	return {"format": fmt, "slots": slots, "ladder": setup.get("ladder", true)}


func valid(s: Dictionary) -> bool:
	if not TEAMS.has(s.get("format", "")) or s.get("slots", []).size() != TEAMS[s.format].size():
		return false
	var seen := []
	for slot in s.slots:
		var w: int = slot.get("who", -1)
		if w >= players.size() or (w >= 0 and w in seen) or not Bot.LEVELS.has(slot.get("level", "")):
			return false
		if w >= 0:
			seen.append(w)
	return true


## True when every player is on one team and at least one bot is on another: the ladder only runs then.
static func pve(s: Dictionary) -> bool:
	var teams: Array = TEAMS[s.format]
	var mine := []
	var foes := []
	for k in s.slots.size():
		(mine if s.slots[k].who >= 0 else foes).append(teams[k])
	return not mine.is_empty() and mine.all(func(t): return t == mine[0]) and foes.any(func(t): return t != mine[0])


func humans(s: Dictionary) -> int:
	return s.slots.filter(func(sl): return sl.who >= 0).size()


func build_duel() -> void:
	label(root, tr("menuDuel"), Rect2(0, 28, Garage.SIZE.x, 50), 40, Garage.TEXT)
	label(root, tr("setupSub"), Rect2(0, 78, Garage.SIZE.x, 22), 14, Garage.DIM, false)
	for i in FORMATS.size():
		var f: String = FORMATS[i]
		var b := button(Rect2(Garage.SIZE.x / 2.0 - 330 + i * 225, 116, 210, 46), set_format.bind(f))
		pick(b, setup.format == f)
		label(b, tr("fmt_" + f), Rect2(0, 0, 210, 46), 18, Garage.TEXT)
	var teams: Array = TEAMS[setup.format]
	var n: int = teams.size()
	for k in n:
		var r := slot_rect(setup.format, k)
		var slot: Dictionary = setup.slots[k]
		var bot: bool = slot.who < 0
		var b := button(Rect2(r.position, Vector2(r.size.x - (110 if bot else 0), r.size.y)), cycle_who.bind(k))
		b.add_theme_stylebox_override("normal", Garage.plate(Garage.CARD, Mech.TEAM_LIGHT[teams[k]], 2, 12))
		var name := tr("botSlot") if bot else tr("playerN").format({"n": slot.who + 1})
		label(b, name, Rect2(0, 8, b.size.x, 40), 30, Garage.TEXT if bot else Mech.TEAM_LIGHT[teams[k]])
		var sub := tr("slotHint")
		if not bot:
			sub = tr("devKeys") if players[slot.who] < 0 else tr("devPad").format({"n": players[slot.who] + 1})
		label(b, sub, Rect2(0, 48, b.size.x, 22), 12, Garage.DIM, false)
		if bot:
			var lv := button(Rect2(r.end.x - 104, r.position.y, 104, r.size.y), cycle_level.bind(k))
			label(lv, tr("diffLabel"), Rect2(0, 14, 104, 16), 10, Garage.DIM)
			label(lv, tr("lv_" + slot.level), Rect2(0, 32, 104, 26), 17, {"easy": Garage.GOOD, "normal": Garage.TEXT, "hard": Garage.BAD}[slot.level])
	if setup.format != "ffa":
		label(root, "VS", Rect2(Garage.SIZE.x / 2.0 - 40, 280, 80, 40), 30, Garage.HOLO)
	var ok := pve(setup)
	for i in 2:
		var b := button(Rect2(Garage.SIZE.x / 2.0 - 270 + i * 280, 470, 260, 48), set_ladder.bind(i == 1))
		pick(b, (i == 1) == (setup.ladder and ok))
		label(b, tr("ladderBtn" if i == 1 else "freeMatch"), Rect2(0, 0, 260, 48), 18, Garage.TEXT if ok or i == 0 else Garage.LABEL)
		b.disabled = i == 1 and not ok
	var note := tr("freeDesc")
	if setup.ladder and ok:
		note = tr("ladderDesc")
	elif setup.ladder:
		note = tr("ladderPve")
	label(root, note, Rect2(140, 526, Garage.SIZE.x - 280, 40), 13, Garage.DIM, false)
	var back := button(Rect2(Garage.SIZE.x / 2.0 - 270, 590, 200, 56), choose.bind("modes"))
	label(back, tr("backBtn"), Rect2(0, 0, 200, 56), 18, Garage.TEXT)
	var go := button(Rect2(Garage.SIZE.x / 2.0 - 50, 590, 320, 56), go_duel)
	label(go, tr("menuGo"), Rect2(0, 0, 320, 56), 22, Garage.TEXT if humans(setup) > 0 else Garage.LABEL)
	go.disabled = humans(setup) == 0
	buttons[clampi(focus_at, 0, buttons.size() - 1)].grab_focus.call_deferred()


## Slot cards: two facing columns for 1v1 and 2v2 (team A left), a row of four for FFA.
static func slot_rect(fmt: String, k: int) -> Rect2:
	if fmt == "ffa":
		return Rect2(Garage.SIZE.x / 2.0 - 610 + k * 308, 250, 296, 84)
	var x := Garage.SIZE.x / 2.0 - 420 if TEAMS[fmt][k] == 0 else Garage.SIZE.x / 2.0 + 60
	var row: int = TEAMS[fmt].slice(0, k).count(TEAMS[fmt][k])
	var y := 256.0 if fmt == "1v1" else 200.0 + row * 112.0
	return Rect2(x, y, 360, 84)


func pick(b: Button, on: bool) -> void:
	if on:
		b.add_theme_stylebox_override("normal", Garage.plate(Garage.SEL, Color.WHITE, 2, 12))


func set_format(f: String) -> void:
	focus_at = FORMATS.find(f)
	setup = fresh_setup(f)
	ui.emit("tab")
	build()


func cycle_who(k: int) -> void:
	var used := []
	for i in setup.slots.size():
		if i != k and setup.slots[i].who >= 0:
			used.append(setup.slots[i].who)
	var opts := range(players.size()).filter(func(p): return not p in used)
	opts.append(-1)
	setup.slots[k].who = opts[(opts.find(setup.slots[k].who) + 1) % opts.size()]
	ui.emit("equip")
	focus_at = FORMATS.size() + setup.slots.slice(0, k).reduce(func(a, sl): return a + (2 if sl.who < 0 else 1), 0)
	build()


func cycle_level(k: int) -> void:
	var lv: String = setup.slots[k].level
	setup.slots[k].level = LEVELS[(LEVELS.find(lv) + 1) % LEVELS.size()]
	ui.emit("tab")
	focus_at = FORMATS.size() + setup.slots.slice(0, k).reduce(func(a, sl): return a + (2 if sl.who < 0 else 1), 0) + 1
	build()


func set_ladder(on: bool) -> void:
	setup.ladder = on
	ui.emit("tab")
	focus_at = buttons.size() - 4 + int(on)
	build()


func go_duel() -> void:
	if humans(setup) == 0:
		return
	setup.ladder = setup.ladder and pve(setup)
	ui.emit("select")
	picked.emit("duel")


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
