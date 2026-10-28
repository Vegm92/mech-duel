extends SceneTree

const Radial = preload("res://src/radial.gd")
const Look = preload("res://src/look.gd")
const I18n = preload("res://src/i18n.gd")
const GROUPS := {"radialModules": "Modules", "radialWallet": "Wallet"}

var r: Radial
var opt := {"out": "", "hover": -1, "sub": -1, "at": 20, "bg": ""}
var frame := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		if kv.size() == 2 and opt.has(kv[0]):
			opt[kv[0]] = kv[1].to_int() if opt[kv[0]] is int else kv[1]
	I18n.setup()
	TranslationServer.set_locale("en")
	var t := Translation.new()
	t.locale = "en"
	for k in GROUPS:
		if TranslationServer.translate(k) == k:
			t.add_message(k, GROUPS[k])
	TranslationServer.add_translation(t)
	Look.ui()
	var bg := ColorRect.new()
	bg.color = Look.PAL.void
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	if opt.bg != "":
		var pic := TextureRect.new()
		pic.texture = ImageTexture.create_from_image(Image.load_from_file(opt.bg))
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pic.set_anchors_preset(Control.PRESET_FULL_RECT)
		root.add_child(pic)
	r = Radial.new()
	root.add_child(r)
	r.open(entries())
	if opt.sub >= 0:
		r.point(Radial.dir(opt.sub * TAU / r.level().size()) * 150.0)
		r.confirm()
	RenderingServer.frame_post_draw.connect(drawn)


func _process(_dt: float) -> bool:
	frame += 1
	if opt.hover >= 0:
		r.point(Radial.dir(opt.hover * TAU / r.level().size()) * 150.0)
	return false


func drawn() -> void:
	if opt.out != "" and frame >= opt.at:
		root.get_texture().get_image().save_png(opt.out)
		quit()


func entries() -> Array:
	var leaf := func(id: String, cost: int, on := true, note := "") -> Dictionary: return {"id": id, "label_key": "shop_" + id, "cost": cost, "enabled": on, "sub": [], "note": note}
	return [
		leaf.call("gate", 40),
		leaf.call("rebuild", 120, false),
		leaf.call("ring", 200),
		{"id": "modules", "label_key": "radialModules", "cost": -1, "enabled": true, "note": "", "sub": [leaf.call("wall", 60), leaf.call("mine", 80), leaf.call("laser", 150, false), leaf.call("post", 120)]},
		leaf.call("repair", 30, true, "▲ Armor 640 → 900"),
		leaf.call("kit", 80, true, "▲ Legs Lv 1 → 2"),
		leaf.call("reinforce", 100, false),
		leaf.call("revive", 50),
	]
