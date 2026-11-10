extends VBoxContainer

signal ui(kind: String)

const Sfx = preload("res://src/sfx.gd")
const I18n = preload("res://src/i18n.gd")
const Garage = preload("res://src/garage.gd")
const Look = preload("res://src/look.gd")

const DEFAULTS := {"fullscreen": false, "vsync": true, "locale": ""}
const SOUND := [["vMaster", "Master"], ["vMusic", "Music"], ["vSfx", "SFX"], ["vEnv", "Env"], ["vCrowd", "Crowd"]]
const LABEL_W := 140.0
const ROW_H := 28.0

var shown := {}
var switches := {}
var sliders := {}


## Saved display and language choices from the settings file; a missing key gives its default.
static func saved() -> Dictionary:
	var cfg := ConfigFile.new()
	cfg.load(Sfx.save_path)
	var out := {}
	for k in DEFAULTS:
		out[k] = type_convert(cfg.get_value("display", k, DEFAULTS[k]), typeof(DEFAULTS[k]))
	return out


static func apply(v: Dictionary) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if v.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if v.vsync else DisplayServer.VSYNC_DISABLED)
	if I18n.STRINGS.has(v.locale):
		TranslationServer.set_locale(v.locale)


## Saves one choice next to the sound volumes and applies it at once.
static func store(key: String, x: Variant) -> void:
	var cfg := ConfigFile.new()
	cfg.load(Sfx.save_path)
	cfg.set_value("display", key, x)
	cfg.save(Sfx.save_path)
	apply(saved())


func _init() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS
	add_theme_constant_override("separation", 14)
	for key in ["fullscreen", "vsync"]:
		switch("set_" + key, key, func() -> void: store(key, not shown[key]))
	switch("set_locale", "locale", func() -> void:
		I18n.toggle()
		store("locale", TranslationServer.get_locale()))
	var img := Image.create_empty(12, 28, false, Image.FORMAT_RGBA8)
	img.fill(Garage.A_HAZARD)
	var grab := ImageTexture.create_from_image(img)
	var track := Garage.box(Garage.A_LINE, 0)
	var fill := Garage.box(Garage.A_HAZARD, 0)
	for st in [track, fill]:
		st.content_margin_top = 4
		st.content_margin_bottom = 4
	for row in SOUND:
		var line := line_of(row[0])
		var s := HSlider.new()
		s.max_value = 1.0
		s.step = 0.05
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		s.custom_minimum_size = Vector2(0, ROW_H)
		s.add_theme_stylebox_override("slider", track)
		s.add_theme_stylebox_override("grabber_area", fill)
		s.add_theme_stylebox_override("grabber_area_highlight", fill)
		for ic in ["grabber", "grabber_highlight", "grabber_disabled"]:
			s.add_theme_icon_override(ic, grab)
		var v: Label = text_of(Label.new(), Color.WHITE)
		v.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		v.custom_minimum_size = Vector2(40, 0)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var bus: String = row[1]
		s.value_changed.connect(func(x: float) -> void:
			Sfx.set_volume(bus, x)
			v.text = str(roundi(x * 100.0)))
		s.drag_ended.connect(func(_c: bool) -> void: ui.emit("select"))
		s.focus_entered.connect(ui.emit.bind("hover"))
		line.add_child(s)
		line.add_child(v)
		sliders[bus] = [s, v]
	sync()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
		sync()


## Shows what the settings file holds now; the menu and the pause screen each have their own copy of this panel.
func sync() -> void:
	shown = saved()
	for key in switches:
		switches[key].text = "langName" if key == "locale" else "setOn" if shown[key] else "setOff"
	var vol := Sfx.volumes()
	for bus in sliders:
		sliders[bus][0].set_value_no_signal(vol[bus])
		sliders[bus][1].text = str(roundi(vol[bus] * 100.0))


func text_of(c: Control, color: Color) -> Control:
	c.add_theme_font_override("font", Look.font(700))
	c.add_theme_font_size_override("font_size", 13)
	c.add_theme_color_override("font_color", color)
	return c


func line_of(key: String) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	var l: Label = text_of(Label.new(), Garage.A_DIM)
	l.text = key
	l.uppercase = true
	l.custom_minimum_size = Vector2(LABEL_W, 0)
	line.add_child(l)
	add_child(line)
	return line


func switch(label: String, key: String, act: Callable) -> void:
	var b: Button = text_of(Button.new(), Color.WHITE)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, ROW_H)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal", Garage.box(Garage.A_RAISED, 8))
	for s in ["hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(s, Garage.box(Garage.A_PICKED, 8))
	var ring := Garage.plate(Color.TRANSPARENT, Color.WHITE, 2, 8)
	ring.set_expand_margin_all(3)
	b.add_theme_stylebox_override("focus", ring)
	b.pressed.connect(func() -> void:
		act.call()
		sync()
		ui.emit("select"))
	b.focus_entered.connect(ui.emit.bind("hover"))
	line_of(label).add_child(b)
	switches[key] = b
