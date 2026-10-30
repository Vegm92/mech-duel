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
	"oil": [0.0, 0.05],
}

const STAGE := {
	"exposure": 1.0, "white": 16.29, "contrast": 1.25, "glow": 0.5, "glow_threshold": 2.2, "fx_peak": 2.2,
	"ambient": 1.0, "ambient_color": PAL.navy,
	"key": 0.5, "key_color": Color(1.0, 0.96, 0.9), "key_from": Vector3(-0.5, 3.0, 1.0), "garage_key": 2.2,
	"spot": 10.0, "spot_angle": 7.0, "spot_color": Color(0.85, 0.9, 1.0),
	"tower_out": 14.0, "tower_height": 14.0, "follow": 3.5, "damp": 0.4, "aim_y": 1.0,
	"accent": 4.0, "accent_range": 4.5, "accent_y": 0.8, "accent_in": 1.5,
}

const FLOOR := {
	"base": PAL.steel, "paint": PAL.hazard, "black": PAL.void, "mark": PAL.steel_hi,
	"metal": FAMILY.floor[0], "rough": Vector2(0.35, 0.6), "tint": 0.3, "dirt": 0.8, "split": 0.35,
	"seam": Vector2(0.03, 0.1), "tilt": 0.15, "polish": 0.35, "stripe": 0.22, "wear": 0.38,
	"ring": Vector2(1.1, 1.4), "box": Vector2(1.65, 2.0), "edge": Vector2(1.0, 1.15),
	"oil": PAL.grime, "slick": Vector2(FAMILY.oil[0], FAMILY.oil[1]), "film": 0.08,
}

const NEON := {"cyan": 0.75, "orange": 0.75}

const FONT := {"family": "saira", "impact": "exo2", "width": 87.5, "text": 600, "bold": 800, "heavy": 900}

const POP := {"hit": Color("#ffffff"), "head": Color("#ff8c28"), "block": Color("#2ba7ff"), "heal": Color("#2dd66b")}

const ARCADE := {
	"ground": Color("#0B0A12"), "panel": Color("#17141F"), "raised": Color("#221E2E"), "line": Color("#34304A"),
	"dim": Color("#B3ACCB"), "soft": Color("#D9D4EA"), "hazard": Color("#FFC93C"), "surge": Color("#C86BFF"), "danger": Color("#FF4D5E"),
	"team": [Color("#FF6B1A"), Color("#2F9BFF"), Color("#39D98A"), Color("#FF4FA3")],
	"core": Color("#4A4462"), "heat": Color("#FF6B3D"), "heat_text": Color("#FF8A6A"), "jam_text": Color("#FF8A95"),
	"jam_dark": Color("#3A1620"), "surge_text": Color("#E3C2FF"), "good": Color("#39D98A"), "orange": Color("#FF8A1F"), "track": Color("#2A2540"),
}

const HAZARD := {"paint": PAL.hazard, "black": PAL.void, "metal": FAMILY.hazard[0], "rough": FAMILY.hazard[1], "width": 0.16, "wear": 0.3, "warn_color": PAL.warn}

const NOISE := """
float hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) { return noise(p) * 0.5 + noise(p * 2.03) * 0.25 + noise(p * 4.1) * 0.125; }
"""

const HAZARD_SHADER := """
shader_type spatial;
""" + NOISE + """
uniform vec3 paint : source_color;
uniform vec3 black : source_color;
uniform float metal;
uniform float rough;
uniform float width;
uniform float wear;
uniform vec3 warn_color : source_color;
uniform float warn = 0.0;
varying vec3 wp;
varying vec3 wn;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	vec2 t = abs(wn.y) > 0.7 ? wp.xz : vec2(dot(wp.xz, normalize(vec2(-wn.z, wn.x))), wp.y);
	float x = abs(fract((t.x + t.y) / (2.0 * width)) - 0.5);
	float aa = fwidth(x);
	float s = smoothstep(0.25 - aa, 0.25 + aa, x);
	float chip = smoothstep(wear - 0.08, wear + 0.08, noise(t * 6.0));
	ALBEDO = mix(black, paint, s * chip);
	METALLIC = metal;
	ROUGHNESS = rough;
	EMISSION = warn_color * warn;
}
"""

const RIM := {"strength": 0.7, "px": 2.0, "gap": 0.6}

const RIM_SHADER := """
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec3 color : source_color;
uniform float strength;
uniform float px;
uniform float gap;
void fragment() {
	float edge = 0.0;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.785398;
		vec2 uv = SCREEN_UV + vec2(cos(a), sin(a)) * px / VIEWPORT_SIZE;
		vec4 v = INV_PROJECTION_MATRIX * vec4(uv * 2.0 - 1.0, texture(depth_tex, uv).r, 1.0);
		edge += step(gap, VERTEX.z - v.z / v.w);
	}
	ALBEDO = color * strength * min(edge / 3.0, 1.0);
}
"""

static var ARENA := {
	"steel": paint("painted", PAL.navy), "dark": paint("gunmetal", PAL.gunmetal),
	"trim": paint("gunmetal", PAL.steel), "hazard": shader(HAZARD_SHADER, HAZARD),
	"amber": neon(PAL.orange, NEON.orange), "zap": neon(PAL.cyan, NEON.cyan), "strip": neon(PAL.cyan, NEON.cyan),
	"pad": neon(PAL.cyan, NEON.cyan), "heal": Mech.glow(PAL.heal, 2.0), "vent": neon(PAL.cyan, NEON.cyan),
	"concrete": paint("painted", PAL.navy), "tread": paint("painted", PAL.gunmetal),
	"aisle": paint("painted", PAL.steel), "roof": paint("gunmetal", PAL.void),
	"flood": Mech.glow(STAGE.spot_color, 2.5), "screen": Mech.glow(PAL.blue, 0.6),
	"seat_a": paint("painted", Mech.TEAM[0].darkened(0.45)), "seat_b": paint("painted", Mech.TEAM[1].darkened(0.45)),
	"seat_n": paint("painted", PAL.steel),
	"led_a": Mech.glow(Mech.TEAM[0], 1.5), "led_b": Mech.glow(Mech.TEAM[1], 1.5), "led_n": Mech.glow(PAL.cyan, 1.2),
}


static var _fonts := {}


## A UI typeface at `weight` (100–900): `FONT.family` for the HUD and the garage, `FONT.impact` for in-game feedback. Digits are tabular.
static func font(weight: int, italic := false, family: String = FONT.family) -> FontVariation:
	var key := "%s%d%s" % [family, weight, "i" if italic else ""]
	if not _fonts.has(key):
		var f := FontVariation.new()
		f.base_font = load("res://assets/fonts/%s/%s%s.ttf" % [family, family, "-italic" if italic else ""])
		f.variation_opentype = {"weight": weight, "width": FONT.width}
		f.opentype_features = {"tnum": 1}
		_fonts[key] = f
	return _fonts[key]


## Makes `font(FONT.text)` the default font of every Control and Label3D.
static func ui() -> void:
	ThemeDB.fallback_font = font(FONT.text)
	ThemeDB.get_default_theme().default_font = font(FONT.text)


static func paint(family: String, c: Color) -> StandardMaterial3D:
	return Mech.mat(c, 0.0, FAMILY[family][0], FAMILY[family][1])


## Light only: a black surface that emits `c`, so the scene's lights never wash it out.
static func neon(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.BLACK
	m.roughness = 1.0
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


## A shader material with its knobs set by name (hazard stripes, the floor).
static func shader(code: String, knobs: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = Shader.new()
	m.shader.code = code
	for k in knobs:
		m.set_shader_parameter(k, knobs[k])
	return m


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
