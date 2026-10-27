extends RefCounted

const Mech = preload("res://src/mech.gd")

const PAL := {
	"void": Color("#09080d"),
	"floor": Color("#141418"),
	"gunmetal": Color("#29262d"),
	"steel": Color("#54586c"),
	"steel_hi": Color("#7090a1"),
	"navy": Color("#273149"),
	"grime": Color("#332426"),
	"cyan": Color("#2bb6dd"),
	"blue": Color("#2e84da"),
	"orange": Color("#d38c42"),
	"hazard": Color("#c9a23e"),
	"heal": Color("#4edb69"),
	"warn": Color("#ff3c28"),
}

const FAMILY := {
	"gunmetal": [0.7, 0.45],
	"floor": [0.6, 0.45],
	"painted": [0.2, 0.6],
	"hazard": [0.15, 0.7],
}

const STAGE := {
	"exposure": 1.0, "white": 16.29, "contrast": 1.25, "glow": 0.5, "glow_threshold": 2.2, "fx_peak": 2.2,
	"ambient": 1.0, "ambient_color": PAL.navy,
	"key": 0.5, "key_color": Color(1.0, 0.96, 0.9), "key_from": Vector3(-0.5, 3.0, 1.0), "garage_key": 2.2,
	"spot": 10.0, "spot_angle": 7.0, "spot_color": Color(0.85, 0.9, 1.0),
	"tower_out": 14.0, "tower_height": 14.0, "follow": 3.5, "damp": 0.4, "aim_y": 1.0,
	"accent": 3.0, "accent_range": 5.0, "accent_y": 0.8, "accent_in": 1.5,
}

const FLOOR := {"base": PAL.steel, "line": PAL.steel, "metal": FAMILY.floor[0], "rough": Vector2(0.35, 0.6), "tint": 0.45, "dirt": 0.75}

static var ARENA := {
	"steel": paint("painted", PAL.navy), "dark": paint("gunmetal", PAL.gunmetal),
	"trim": paint("gunmetal", PAL.steel), "hazard": paint("hazard", PAL.hazard),
	"amber": Mech.glow(PAL.orange, 3.0), "zap": Mech.glow(PAL.cyan, 2.0),
	"pad": Mech.glow(PAL.cyan, 1.5), "heal": Mech.glow(PAL.heal, 2.0), "vent": Mech.glow(PAL.cyan, 1.5),
	"oil": Mech.mat(Color8(30, 24, 44), 0.0, 0.3, 0.3),
	"concrete": Mech.mat(Color8(48, 54, 70), 0.0, 0.0, 0.85), "tread": Mech.mat(Color8(32, 36, 48), 0.0, 0.1, 0.8),
	"aisle": Mech.mat(Color8(72, 78, 94), 0.0, 0.2, 0.7), "roof": Mech.mat(Color8(13, 15, 21), 0.0, 0.3, 0.8),
	"flood": Mech.glow(Color8(235, 240, 255), 2.5), "screen": Mech.glow(Color8(40, 90, 170), 0.8),
	"seat_a": Mech.mat(Mech.TEAM[0].darkened(0.45), 0.0, 0.0, 0.7), "seat_b": Mech.mat(Mech.TEAM[1].darkened(0.45), 0.0, 0.0, 0.7),
	"seat_n": Mech.mat(Color8(70, 76, 92), 0.0, 0.0, 0.7),
	"led_a": Mech.glow(Mech.TEAM[0], 1.5), "led_b": Mech.glow(Mech.TEAM[1], 1.5), "led_n": Mech.glow(Color8(200, 200, 210), 1.2),
}


static func paint(family: String, c: Color) -> StandardMaterial3D:
	return Mech.mat(c, 0.0, FAMILY[family][0], FAMILY[family][1])


## The one Environment for the arena and the garage previews (`clear` = see-through background).
static func env(clear := false) -> Environment:
	assert(STAGE.glow_threshold >= STAGE.fx_peak * STAGE.exposure, "stacked effects would bloom")
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR if clear else Environment.BG_COLOR
	e.background_color = PAL.void
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = STAGE.ambient_color
	e.ambient_light_energy = STAGE.ambient
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.tonemap_exposure = STAGE.exposure
	e.tonemap_agx_white = STAGE.white
	e.tonemap_agx_contrast = STAGE.contrast
	e.glow_enabled = true
	e.glow_intensity = STAGE.glow
	e.glow_hdr_threshold = STAGE.glow_threshold
	e.ssao_enabled = true
	return e
