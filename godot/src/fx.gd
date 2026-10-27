extends RefCounted

const Mech = preload("res://src/mech.gd")

const HIT := {
	"full": 40.0, "w_min": 0.2, "w_max": 1.5,
	"face": 0.45, "flash": 0.45, "flash_secs": 0.05, "chips_at": 0.6,
	"star": 1.3, "star_secs": 0.09, "marker": 0.9, "marker_secs": 0.2,
	"heavy": 1.0, "stop_head": 3, "stop_heavy": 2,
	"shake": Vector2(0.05, 0.17), "shake_head": 0.15,
}
const BOOM := {"size": 1.4, "small": 0.45, "flash": 0.5, "flash_secs": 0.05, "star": 2.2, "wave": 1.8, "wave_secs": 0.22, "mark": 0.85, "marks": 40, "stop_big": 2}
const RAY := {"core": 0.3, "thin": 0.12, "edge": 0.6}
const ARC := {"segs": 7, "jitter": 0.45, "width": 0.13, "secs": 0.16}
const MUZZLE := {"flash": 0.28, "secs": 0.05, "star": 0.8, "star_secs": 0.06}
const PARRY := {"flash": 0.6, "star": 2.4, "secs": 0.13, "ring": 2.2, "ring_secs": 0.26, "stop": 4}
const BREAK := {"flash": 0.6, "star": 2.0, "smoke_secs": 3.0, "stop": 4}
const KO := {"r": 2.0, "ring": 1.8, "ring_secs": 0.45, "stop": 8, "slow": 0.3, "slow_secs": 0.6}
const LAND := {"ring": 1.15, "ring_secs": 0.3, "spikes": 0.75, "dust": 0.55, "crack": 0.6}
const DASH := {"every": 3, "ghost_secs": 0.22, "ghost_alpha": 0.4}
const RIPPLE := {"panel": 1.25, "face": 1.33, "y": 1.05, "r": 0.75, "secs": 0.22, "card": 0.55, "card_secs": 0.07, "broke": 1.7}
const HOOKED := {"flash": 0.4, "star": 1.4, "ring": 1.1, "secs": 0.18}
const KICK := {"hit": 1.6, "decay": 14.0, "freq": 42.0}
const RIBBON := {"steps": 12, "y": 0.07, "edge": 1.2, "tail": 1.2, "head": 0.4, "tip": 0.35, "fade": 0.35, "hot": 0.1, "gain": 1.0}
const SMOKE := {"step": 0.35, "per": 0.8, "spread": 0.75, "size": Vector2(0.4, 0.75), "grow": 18.0, "swell": 0.35, "rise": 0.7, "fade_in": 6.0, "fade_out": 0.35, "greys": [0.42, 0.34, 0.27], "alpha": 0.65, "gain": 1.3, "segs": 24}
const SMOKE_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, specular_disabled;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform float alpha = 0.85;
uniform float bump = 0.32;
uniform float scale = 1.8;
uniform float churn = 0.35;
uniform float rim = 0.75;
uniform float touch = 0.5;
uniform float anchor = 1.7;
instance uniform float grey = 1.0;
instance uniform float fade = 1.0;
varying float lump;
float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
void vertex() {
	vec3 p = VERTEX * scale + MODEL_MATRIX[3].xyz * anchor + vec3(0.0, TIME * churn, 0.0);
	lump = noise(p) * 0.65 + noise(p * 2.3) * 0.35;
	VERTEX += NORMAL * (lump - 0.5) * 2.0 * bump;
}
void fragment() {
	float edge = smoothstep(0.0, rim, abs(dot(NORMAL, VIEW)));
	float d = texture(depth_tex, SCREEN_UV).r;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	float gap = clamp((VERTEX.z - v.z / v.w) / touch, 0.0, 1.0);
	ALBEDO = COLOR.rgb * grey * (0.8 + 0.4 * lump);
	ROUGHNESS = 1.0;
	ALPHA = clamp(alpha * COLOR.a * fade * edge * gap, 0.0, 1.0);
}
"""

const CONE := {"muzzle": 0.6, "snap": 1.6, "back": 0.4, "reach": 0.4, "r0": 0.3, "widen": 0.22, "tip": 0.2, "y": 1.05, "bump": 0.08, "color": Color(1.0, 0.55, 0.18, 0.9)}
const FIRE_SHADER := """
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_back;
uniform float bump = 0.3;
uniform float scale = 2.2;
uniform float churn = 2.4;
uniform float rim = 0.85;
uniform float core = 0.55;
uniform vec3 hot : source_color = vec3(1.0, 0.92, 0.7);
uniform float anchor = 1.7;
uniform float tail = 0.0;
instance uniform vec4 tint : source_color = vec4(1.0);
varying float lump;
varying float along;
varying vec4 col;
float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
void vertex() {
	along = tail * clamp(0.5 - VERTEX.y, 0.0, 1.0);
	vec3 p = VERTEX * scale + MODEL_MATRIX[3].xyz * anchor - vec3(0.0, TIME * churn, 0.0);
	lump = noise(p) * 0.6 + noise(p * 2.5) * 0.4;
	VERTEX += NORMAL * (lump - 0.5) * 2.0 * bump;
	col = COLOR * tint;
}
void fragment() {
	float f = abs(dot(NORMAL, VIEW));
	float edge = pow(smoothstep(0.0, rim, f), 1.0 + 2.0 * tail) * (0.5 + lump);
	float heat = smoothstep(core, 1.0, f) * lump + tail * (1.0 - along) * 0.8;
	ALBEDO = mix(col.rgb, hot, clamp(heat, 0.0, 1.0));
	ALBEDO *= mix(vec3(1.0), vec3(1.0, 0.45, 0.25), along);
	ALPHA = clamp(col.a * edge * (1.0 - smoothstep(0.55, 1.0, along)), 0.0, 1.0);
}
"""

static var _smoke_mat: ShaderMaterial
static var _fire_mat: ShaderMaterial


static func smoke_mat() -> ShaderMaterial:
	if _smoke_mat == null:
		_smoke_mat = ShaderMaterial.new()
		_smoke_mat.shader = Shader.new()
		_smoke_mat.shader.code = SMOKE_SHADER
		_smoke_mat.set_shader_parameter("alpha", SMOKE.gain)
	return _smoke_mat


static func wreck(mech: Node3D) -> CPUParticles3D:
	var s := emitter(LAYERS.wreck_smoke)
	s.emitting = false
	s.direction = Vector3.UP
	s.position = Vector3(0, 1.2, 0)
	mech.add_child(s)
	return s


static func fire_mat() -> ShaderMaterial:
	if _fire_mat == null:
		_fire_mat = ShaderMaterial.new()
		_fire_mat.shader = Shader.new()
		_fire_mat.shader.code = FIRE_SHADER
	return _fire_mat


static func flame_cone(parent: Node3D) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = CONE.tip
	c.bottom_radius = 1.0
	c.height = 1.0
	c.radial_segments = 24
	c.rings = 12
	c.cap_top = false
	c.cap_bottom = false
	var m := fire_mat().duplicate() as ShaderMaterial
	m.set_shader_parameter("anchor", 0.0)
	m.set_shader_parameter("tail", 1.0)
	m.set_shader_parameter("bump", CONE.bump)
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	mi.set_instance_shader_parameter("tint", CONE.color)
	parent.add_child(mi)
	return mi
const SHIELD_C := Color8(110, 220, 255)

const LAYERS := {
	"hit_sparks": {"mesh": "needle", "ramp": "spark", "n": Vector2(8, 18), "speed": Vector2(10, 24), "life": 0.34, "spread": 28.0, "gravity": -10.0, "damp": 25.0, "align": true, "shrink": true, "add": true},
	"hit_smoke": {"mesh": "puff_s", "ramp": "smoke_late", "n": Vector2(1, 3), "speed": Vector2(0.8, 2.0), "life": 1.1, "spread": 50.0, "gravity": 1.5, "damp": 2.5, "grow": 2.2},
	"hit_chips": {"mesh": "chip", "ramp": "chip", "n": Vector2(3, 6), "speed": Vector2(3, 7), "life": 0.7, "spread": 55.0, "gravity": -24.0, "spin": 540.0},
	"muzzle_sparks": {"mesh": "needle_s", "ramp": "spark", "n": Vector2(5, 5), "speed": Vector2(10, 18), "life": 0.13, "spread": 16.0, "gravity": 0.0, "damp": 40.0, "align": true, "shrink": true, "add": true},
	"muzzle_smoke": {"mesh": "puff_s", "ramp": "smoke_thin", "n": Vector2(1, 1), "speed": Vector2(0.6, 1.4), "life": 0.7, "spread": 25.0, "gravity": 1.0, "damp": 3.0, "grow": 2.0},
	"boom_fire": {"mesh": "fireball", "fire": true, "ramp": "fire", "n": Vector2(8, 16), "speed": Vector2(2, 6), "life": 0.5, "spread": 180.0, "gravity": 2.0, "damp": 7.0, "grow": 1.8, "sphere": 0.45, "add": true},
	"boom_smoke": {"mesh": "puff", "ramp": "smoke_late", "n": Vector2(5, 9), "speed": Vector2(1, 3), "life": 1.8, "spread": 70.0, "gravity": 1.2, "damp": 3.0, "grow": 2.6, "sphere": 0.5},
	"boom_sparks": {"mesh": "needle", "ramp": "spark", "n": Vector2(14, 28), "speed": Vector2(12, 26), "life": 0.45, "spread": 80.0, "gravity": -18.0, "damp": 18.0, "align": true, "shrink": true, "add": true},
	"boom_chips": {"mesh": "chip", "ramp": "chip", "n": Vector2(4, 9), "speed": Vector2(4, 9), "life": 0.8, "spread": 70.0, "gravity": -24.0, "spin": 540.0},
	"ray_sparks": {"mesh": "needle_s", "ramp": "laser", "n": Vector2(7, 7), "speed": Vector2(6, 14), "life": 0.25, "spread": 70.0, "gravity": -10.0, "damp": 20.0, "align": true, "shrink": true, "add": true},
	"beam_sparks": {"mesh": "needle_s", "ramp": "lance", "n": Vector2(28, 28), "speed": Vector2(3, 9), "life": 0.35, "spread": 60.0, "gravity": -8.0, "damp": 12.0, "align": true, "shrink": true, "add": true},
	"parry_sparks": {"mesh": "needle", "ramp": "shield", "n": Vector2(20, 20), "speed": Vector2(10, 22), "life": 0.3, "spread": 180.0, "gravity": 0.0, "damp": 24.0, "align": true, "shrink": true, "add": true},
	"break_sparks": {"mesh": "needle", "ramp": "spark", "n": Vector2(22, 22), "speed": Vector2(10, 22), "life": 0.45, "spread": 180.0, "gravity": -16.0, "damp": 16.0, "align": true, "shrink": true, "add": true},
	"break_chunks": {"mesh": "chunk", "ramp": "chip", "n": Vector2(7, 7), "speed": Vector2(4, 9), "life": 1.0, "spread": 80.0, "gravity": -26.0, "spin": 420.0},
	"break_smoke": {"mesh": "puff_s", "ramp": "smoke_dark", "n": Vector2(36, 36), "speed": Vector2(0.8, 1.8), "life": 1.2, "spread": 20.0, "gravity": 1.6, "damp": 1.5, "grow": 3.0},
	"ko_shards": {"mesh": "needle", "ramp": "spark", "n": Vector2(40, 40), "speed": Vector2(14, 30), "life": 0.55, "spread": 180.0, "gravity": -8.0, "damp": 14.0, "align": true, "shrink": true, "add": true},
	"land_spikes": {"mesh": "needle", "ramp": "spark", "n": Vector2(18, 18), "speed": Vector2(5, 10), "life": 0.3, "spread": 12.0, "gravity": 0.0, "damp": 14.0, "align": true, "shrink": true, "add": true},
	"land_dust": {"mesh": "puff_s", "ramp": "dust", "n": Vector2(14, 14), "speed": Vector2(1, 3), "life": 0.8, "spread": 70.0, "gravity": 0.5, "damp": 4.0, "grow": 2.5},
	"dash_streaks": {"mesh": "needle", "ramp": "spark", "n": Vector2(12, 12), "speed": Vector2(8, 16), "life": 0.25, "spread": 12.0, "gravity": 0.0, "damp": 18.0, "align": true, "shrink": true, "add": true},
	"dash_dust": {"mesh": "puff_s", "ramp": "dust", "n": Vector2(5, 5), "speed": Vector2(0.5, 1.5), "life": 0.6, "spread": 60.0, "gravity": 0.4, "damp": 3.0, "grow": 2.0},
	"wreck_smoke": {"mesh": "puff", "ramp": "smoke_dark", "n": Vector2(28, 28), "speed": Vector2(0.8, 2.0), "life": 1.8, "spread": 20.0, "gravity": 0.8, "damp": 0.5, "grow": 2.0},
	"shield_sparks": {"mesh": "needle_s", "ramp": "shield", "n": Vector2(4, 12), "speed": Vector2(6, 14), "life": 0.2, "spread": 40.0, "gravity": 0.0, "damp": 30.0, "align": true, "shrink": true, "add": true},
	"hook_sparks": {"mesh": "needle_s", "ramp": "spark", "n": Vector2(10, 10), "speed": Vector2(6, 14), "life": 0.22, "spread": 180.0, "gravity": 0.0, "damp": 26.0, "align": true, "shrink": true, "add": true},
	"missile_trail": {"mesh": "puff_s", "ramp": "smoke_thin", "n": Vector2(48, 48), "speed": Vector2(1, 2), "life": 0.55, "spread": 15.0, "gravity": 0.6, "damp": 3.0, "grow": 2.5},
}
const MESHES := {
	"needle": [Vector3(0.08, 0.9, 0.08), 0], "needle_s": [Vector3(0.065, 0.55, 0.065), 0],
	"chip": [Vector3(0.14, 0.14, 0.14), 0], "chunk": [Vector3(0.26, 0.18, 0.22), 0], "puff": [0.42, 20], "puff_s": [0.2, 16], "fireball": [0.42, 24],
}
const RAMPS := {
	"spark": [Color8(255, 240, 180), Color8(255, 190, 80), Color8(255, 120, 40), Color8(255, 90, 30, 0)],
	"smoke": [Color(0.62, 0.62, 0.66, 0.75), Color(0.36, 0.36, 0.4, 0.7), Color(0.2, 0.2, 0.23, 0)],
	"smoke_late": [Color(0.4, 0.4, 0.44, 0), Color(0.36, 0.36, 0.4, 0.75), Color(0.24, 0.24, 0.27, 0.6), Color(0.18, 0.18, 0.2, 0)],
	"smoke_thin": [Color(0.72, 0.72, 0.76, 0.5), Color(0.4, 0.4, 0.44, 0.3), Color(0.25, 0.25, 0.28, 0)],
	"fire": [Color8(255, 225, 130), Color8(255, 150, 50), Color8(235, 85, 30, 120), Color8(120, 30, 15, 0)],
	"chip": [Color8(78, 82, 92), Color8(78, 82, 92), Color8(40, 42, 48, 0)],
	"smoke_dark": [Color(0.16, 0.16, 0.18, 0.0), Color(0.12, 0.12, 0.14, 0.8), Color(0.1, 0.1, 0.12, 0.5), Color(0.08, 0.08, 0.1, 0)],
	"dust": [Color(0.78, 0.74, 0.66, 0.55), Color(0.6, 0.57, 0.52, 0.35), Color(0.45, 0.43, 0.4, 0)],
	"shield": [Color8(200, 245, 255), Color8(110, 220, 255), Color8(70, 160, 255, 0)],
	"laser": [Color8(255, 170, 190), Color8(255, 80, 120), Color8(255, 60, 100, 0)],
	"arc": [Color8(200, 230, 255), Color8(120, 200, 255), Color8(80, 150, 255, 0)],
	"lance": [Color8(255, 225, 160), Color8(255, 190, 90), Color8(255, 140, 50, 0)],
	"rail": [Color8(190, 250, 255), Color8(120, 240, 255), Color8(80, 200, 255, 0)],
}

static var _ramps := {}
static var _curves := {}
static var _bars: Array = []
static var _parts: Array = []


static func take(list: Array) -> Node:
	while list.size():
		var n = list.pop_back()
		if is_instance_valid(n):
			return n
	return null


static func park(n: Node, list: Array) -> void:
	n.visible = false
	list.append(n)


static func place(n: Node3D, parent: Node) -> void:
	var at := n.get_parent()
	if at != parent:
		if at != null:
			at.remove_child(n)
		parent.add_child(n)
	n.visible = true


static func weight(dmg: float) -> float:
	return clampf(dmg / HIT.full, HIT.w_min, HIT.w_max)


static func gradient(cs: Array) -> Gradient:
	var g := Gradient.new()
	var at := PackedFloat32Array()
	for i in cs.size():
		at.append(float(i) / (cs.size() - 1))
	g.offsets = at
	g.colors = PackedColorArray(cs)
	return g


static func ramp(name: String) -> Gradient:
	if not _ramps.has(name):
		_ramps[name] = gradient(RAMPS[name])
	return _ramps[name]


static func tint(c: Color) -> Gradient:
	var key := "tint/" + c.to_html()
	if not _ramps.has(key):
		_ramps[key] = gradient([c.lightened(0.4), c, c.darkened(0.1), Color(c.darkened(0.2), 0)])
	return _ramps[key]


static func mesh(name: String) -> Mesh:
	var m: Array = MESHES[name]
	return Mech.box(m[0]) if m[1] == 0 else Mech.ball(m[0], m[1])


static func curve(points: Array) -> Curve:
	var key := str(points)
	if not _curves.has(key):
		var c := Curve.new()
		for pt in points:
			c.add_point(pt)
		_curves[key] = c
	return _curves[key]


static func bar(parent: Node3D, p: Vector3, m: Mesh, c: Color, scale_ := Vector3.ONE, rot := Vector3.ZERO, add := true) -> MeshInstance3D:
	var mi := take(_bars) as MeshInstance3D
	if mi == null:
		mi = MeshInstance3D.new()
		mi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	place(mi, parent)
	mi.mesh = m
	mi.material_override = Mech.flat(c, add)
	mi.transparency = 0.0
	mi.position = p
	mi.rotation = rot
	mi.scale = scale_
	return mi


static func fade(mi: Node3D, secs: float, to_scale: Vector3, ease_ := Tween.EASE_IN) -> void:
	var tw := mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", to_scale, secs).set_ease(ease_).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mi, "transparency", 1.0, secs).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(park.bind(mi, _bars))


static func flash(parent: Node3D, p: Vector3, size: float, secs: float, c := Color.WHITE) -> void:
	fade(bar(parent, p, Mech.ball(1.0, 10), c, Vector3.ONE * size), secs, Vector3.ONE * size * 1.6, Tween.EASE_OUT)


static func star(parent: Node3D, p: Vector3, size: float, secs: float, c: Color) -> void:
	var turn := randf() * PI
	for i in 4:
		var ln := size * (1.0 if i % 2 == 0 else 0.6)
		var rot := Vector3(0, turn + i * PI / 4.0, 0)
		fade(bar(parent, p, Mech.box(Vector3.ONE), c, Vector3(ln, 0.05, 0.07), rot), secs, Vector3(ln * 1.4, 0.01, 0.01), Tween.EASE_OUT)
		fade(bar(parent, p, Mech.box(Vector3.ONE), Color.WHITE, Vector3(ln * 0.6, 0.03, 0.035), rot), secs, Vector3(ln * 0.9, 0.01, 0.01), Tween.EASE_OUT)


static func ring(parent: Node3D, p: Vector3, r0: float, r1: float, secs: float, c: Color, flat := 0.3) -> void:
	fade(bar(parent, p, Mech.ring(0.9, 1.0), c, Vector3(r0, flat, r0)), secs, Vector3(r1, flat, r1), Tween.EASE_OUT)


static func emitter(L: Dictionary, t := 1.0, k := 1.0, g: Gradient = null) -> CPUParticles3D:
	var s := CPUParticles3D.new()
	s.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return setup(s, L, t, k, g)


static func spare(L: Dictionary, t := 1.0, k := 1.0, g: Gradient = null) -> CPUParticles3D:
	var s := take(_parts) as CPUParticles3D
	if s == null:
		s = emitter(L, t, k, g)
		s.one_shot = true
		s.explosiveness = 1.0
		s.finished.connect(park.bind(s, _parts))
		return s
	return setup(s, L, t, k, g)


static func setup(s: CPUParticles3D, L: Dictionary, t: float, k: float, g: Gradient) -> CPUParticles3D:
	s.amount = maxi(1, roundi(lerpf(L.n.x, L.n.y, t)))
	s.lifetime = L.life
	s.lifetime_randomness = 0.4
	s.mesh = mesh(L.mesh)
	if L.get("fire", false):
		s.material_override = fire_mat()
	elif L.mesh.begins_with("puff"):
		s.material_override = smoke_mat()
	else:
		s.material_override = Mech.flat(Color.WHITE, L.get("add", false))
	s.color_ramp = g if g != null else ramp(L.ramp)
	s.spread = L.spread
	s.initial_velocity_min = L.speed.x * k
	s.initial_velocity_max = L.speed.y * k
	s.gravity = Vector3(0, L.gravity, 0)
	s.damping_min = L.get("damp", 0.0)
	s.damping_max = L.get("damp", 0.0)
	s.particle_flag_align_y = L.get("align", false)
	var size := 0.6 + 0.4 * k
	var grow: float = L.get("grow", 1.0)
	s.scale_amount_min = 0.7 * grow * size
	s.scale_amount_max = 1.2 * grow * size
	s.scale_amount_curve = null
	if grow != 1.0:
		s.scale_amount_curve = curve([Vector2(0, 1.0 / grow), Vector2(1, 1)])
	elif L.get("shrink", false):
		s.scale_amount_curve = curve([Vector2(0, 1), Vector2(0.6, 0.8), Vector2(1, 0)])
	var spin: float = L.get("spin", 0.0)
	s.particle_flag_rotate_y = spin > 0.0
	s.angle_max = 360.0 if spin > 0.0 else 0.0
	s.angular_velocity_min = -spin
	s.angular_velocity_max = spin
	s.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE if L.has("sphere") else CPUParticles3D.EMISSION_SHAPE_POINT
	s.emission_sphere_radius = L.get("sphere", 0.0) * k
	s.rotation = Vector3.ZERO
	return s


static func fire(parent: Node3D, s: CPUParticles3D) -> CPUParticles3D:
	place(s, parent)
	s.restart()
	return s


static func burst(parent: Node3D, p: Vector3, dir: Vector3, L: Dictionary, t := 1.0, k := 1.0, g: Gradient = null) -> CPUParticles3D:
	var s := spare(L, t, k, g)
	s.direction = dir
	s.position = p
	return fire(parent, s)


static func hit(parent: Node3D, f: Dictionary, c: Color) -> void:
	var w := weight(f.n)
	var t := w / HIT.w_max
	var p := Vector3(f.x, 1.0, f.y)
	var dir := Vector3.UP
	var spread := 85.0
	var a = f.get("from")
	if a != null:
		var back := Vector3(cos(a), 0, sin(a))
		p += back * HIT.face
		dir = (-back + Vector3(0, 0.35, 0)).normalized()
		spread = LAYERS.hit_sparks.spread
	var size := 0.7 + 0.3 * t
	flash(parent, p, HIT.flash * size, HIT.flash_secs)
	star(parent, p, HIT.star * size, HIT.star_secs, c)
	ring(parent, p, HIT.marker * 0.4, HIT.marker * size, HIT.marker_secs, c)
	burst(parent, p, dir, LAYERS.hit_sparks, t, 1.0, tint(c)).spread = spread
	burst(parent, p, (dir + Vector3.UP).normalized(), LAYERS.hit_smoke, t)
	if w > HIT.chips_at:
		burst(parent, p, dir, LAYERS.hit_chips, t).spread = spread + 25.0


static func stop_of(f: Dictionary) -> int:
	if f.get("head", false):
		return HIT.stop_head
	return HIT.stop_heavy if weight(f.n) >= HIT.heavy else 0


static func shake_of(f: Dictionary) -> float:
	var t := weight(f.n) / HIT.w_max
	return lerpf(HIT.shake.x, HIT.shake.y, t) + (HIT.shake_head if f.get("head", false) else 0.0)


static func muzzle(parent: Node3D, f: Dictionary, c: Color) -> void:
	var p := Vector3(f.x, 1.05, f.y)
	var dir := Vector3(cos(f.a), 0.05, sin(f.a))
	flash(parent, p, MUZZLE.flash, MUZZLE.secs, c.lightened(0.6))
	star(parent, p, MUZZLE.star, MUZZLE.star_secs, c)
	burst(parent, p, dir, LAYERS.muzzle_sparks, 1.0, 1.0, tint(c))
	burst(parent, p, (dir + Vector3.UP).normalized(), LAYERS.muzzle_smoke)


static func boom(parent: Node3D, marks: Node3D, f: Dictionary) -> int:
	var big: bool = f.get("big", false)
	var k: float = f.r / BOOM.size
	var t: float = 1.0 if big else BOOM.small
	var p := Vector3(f.x, 0.6, f.y)
	var warm := Color8(255, 170, 70)
	flash(parent, p + Vector3(0, 0.4, 0), BOOM.flash * k * (1.3 if big else 1.0), BOOM.flash_secs)
	star(parent, p + Vector3(0, 0.4, 0), BOOM.star * k, HIT.star_secs * 1.5, warm)
	ring(parent, Vector3(f.x, 0.1, f.y), f.r * 0.3, f.r * BOOM.wave, BOOM.wave_secs, Color(1, 0.85, 0.6))
	for name in ["boom_fire", "boom_smoke", "boom_sparks", "boom_chips"]:
		burst(parent, p, Vector3.UP, LAYERS[name], t, k)
	bar(marks, Vector3(f.x, 0.025, f.y), Mech.cyl(1.0, 1.0, 0.01, 20), Color(0.03, 0.03, 0.04, 0.6), Vector3(f.r, 1, f.r) * BOOM.mark, Vector3.ZERO, false)
	if marks.get_child_count() > BOOM.marks:
		marks.get_child(0).queue_free()
	return BOOM.stop_big if big else 0


static func ray(parent: Node3D, f: Dictionary, w: float, ramp_name: String, secs: float, along := false) -> void:
	var b := Vector3(f.x2, 1.05, f.y2)
	var d := Vector2(f.x2 - f.x1, f.y2 - f.y1)
	var mid := Vector3((f.x1 + f.x2) / 2.0, 1.05, (f.y1 + f.y2) / 2.0)
	var rot := Vector3(0, -d.angle(), 0)
	var c: Color = RAMPS[ramp_name][1]
	var edge := Vector3(d.length(), 0.08, w)
	var core := Vector3(d.length(), 0.06, w * RAY.core)
	fade(bar(parent, mid, Mech.box(Vector3.ONE), Color(c, RAY.edge), edge, rot), secs, Vector3(edge.x, edge.y, edge.z * RAY.thin))
	fade(bar(parent, mid + Vector3(0, 0.02, 0), Mech.box(Vector3.ONE), Color.WHITE, core, rot), secs * 1.3, Vector3(core.x, core.y, core.z * RAY.thin))
	star(parent, b, 1.2, 0.1, c)
	burst(parent, b, Vector3.UP, LAYERS.ray_sparks, 1.0, 1.0, ramp(ramp_name))
	if along:
		var s := spare(LAYERS.beam_sparks, 1.0, 1.0, ramp(ramp_name))
		s.direction = Vector3.UP
		s.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		s.emission_box_extents = Vector3(d.length() / 2.0, 0.1, w / 2.0)
		s.position = mid
		s.rotation = rot
		fire(parent, s)


static func arc(parent: Node3D, f: Dictionary) -> void:
	var a := Vector2(f.x1, f.y1)
	var b := Vector2(f.x2, f.y2)
	var side := (b - a).orthogonal().normalized()
	var pts := [a]
	for i in range(1, ARC.segs):
		var u := float(i) / ARC.segs
		pts.append(a.lerp(b, u) + side * randf_range(-1.0, 1.0) * ARC.jitter * sin(PI * u))
	pts.append(b)
	var c: Color = RAMPS.arc[1]
	var w: float = ARC.width
	for i in pts.size() - 1:
		var p0: Vector2 = pts[i]
		var p1: Vector2 = pts[i + 1]
		var d := p1 - p0
		var mid := Vector3((p0.x + p1.x) / 2.0, 1.05, (p0.y + p1.y) / 2.0)
		var rot := Vector3(0, -d.angle(), 0)
		fade(bar(parent, mid, Mech.box(Vector3.ONE), Color(c, 0.8), Vector3(d.length() + w, w, w * 2.0), rot), ARC.secs, Vector3(d.length(), w * 0.3, w * 0.6))
		fade(bar(parent, mid + Vector3(0, 0.01, 0), Mech.box(Vector3.ONE), Color.WHITE, Vector3(d.length(), w * 0.4, w * 0.8), rot), ARC.secs, Vector3(d.length(), w * 0.1, w * 0.2))
	star(parent, Vector3(b.x, 1.05, b.y), 1.0, 0.1, c)
	burst(parent, Vector3(b.x, 1.05, b.y), Vector3.UP, LAYERS.ray_sparks, 1.0, 1.0, ramp("arc"))


static func metal(c: Color) -> Gradient:
	var key := "metal/" + c.to_html()
	if not _ramps.has(key):
		_ramps[key] = gradient([c, c.darkened(0.25), Color(c.darkened(0.5), 0)])
	return _ramps[key]


static func mark(marks: Node3D, p: Vector3, m: Mesh, scale_: Vector3) -> void:
	bar(marks, Vector3(p.x, 0.025, p.z), m, Color(0.03, 0.03, 0.04, 0.6), scale_, Vector3.ZERO, false)
	if marks.get_child_count() > BOOM.marks:
		marks.get_child(0).queue_free()


static func on_ring(s: CPUParticles3D, r: float) -> void:
	s.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	s.emission_ring_axis = Vector3.UP
	s.emission_ring_radius = r
	s.emission_ring_inner_radius = r * 0.85
	s.emission_ring_height = 0.05


static func parry(parent: Node3D, f: Dictionary) -> int:
	var p := Vector3(f.x, 1.05, f.y)
	flash(parent, p, PARRY.flash, 0.06)
	star(parent, p, PARRY.star, PARRY.secs, SHIELD_C)
	ring(parent, p, 0.3, PARRY.ring, PARRY.ring_secs, SHIELD_C)
	ring(parent, p, 0.2, PARRY.ring * 0.6, PARRY.ring_secs * 0.7, Color.WHITE)
	burst(parent, p, Vector3.UP, LAYERS.parry_sparks)
	return PARRY.stop


static func ripple(parent: Node3D, xf: Transform3D, soaked: float, broke: bool) -> void:
	var t := weight(soaked) / HIT.w_max
	var p := xf * Vector3(RIPPLE.face, RIPPLE.y, 0)
	var out := xf.basis.x.normalized()
	var yaw := xf.basis.orthonormalized().get_euler().y
	var size: float = RIPPLE.r * (0.6 + 0.4 * t) * (RIPPLE.broke if broke else 1.0)
	var rot := Vector3(0, yaw, PI / 2.0)
	var card := Vector3(0.13, 1.4, 2.3)
	fade(bar(parent, xf * Vector3(RIPPLE.panel, RIPPLE.y, 0), Mech.box(Vector3.ONE), Color(SHIELD_C, RIPPLE.card), card, Vector3(0, yaw, 0)), RIPPLE.card_secs, card * Vector3(1, 1.08, 1.06))
	fade(bar(parent, p, Mech.ring(0.9, 1.0), SHIELD_C, Vector3(size * 0.25, 0.3, size * 0.25), rot), RIPPLE.secs, Vector3(size, 0.3, size), Tween.EASE_OUT)
	fade(bar(parent, p, Mech.ring(0.9, 1.0), Color.WHITE, Vector3(size * 0.15, 0.3, size * 0.15), rot), RIPPLE.secs * 0.7, Vector3(size * 0.6, 0.3, size * 0.6), Tween.EASE_OUT)
	burst(parent, p, out, LAYERS.shield_sparks, 1.0 if broke else t)
	if broke:
		flash(parent, p, BREAK.flash, 0.06)
		star(parent, p, BREAK.star, HIT.star_secs * 1.5, SHIELD_C)
		burst(parent, p, out, LAYERS.parry_sparks)


static func hooked(parent: Node3D, f: Dictionary, c: Color) -> void:
	var p := Vector3(f.x, 1.05, f.y)
	flash(parent, p, HOOKED.flash, 0.05)
	star(parent, p, HOOKED.star, HOOKED.secs * 0.6, c)
	ring(parent, p, 0.2, HOOKED.ring, HOOKED.secs, c)
	burst(parent, p, Vector3.UP, LAYERS.hook_sparks, 1.0, 1.0, tint(c))


static func kick_of(f: Dictionary) -> Vector3:
	var a = f.get("from")
	if a == null:
		return Vector3.ZERO
	return Vector3(-cos(a), 0, -sin(a)) * shake_of(f) * KICK.hit


static func shatter(parent: Node3D, mech: Node3D, f: Dictionary, c: Color) -> int:
	var p := Vector3(f.x, 1.2, f.y)
	flash(parent, p, BREAK.flash, 0.06)
	star(parent, p, BREAK.star, HIT.star_secs * 1.5, Color8(255, 170, 70))
	burst(parent, p, Vector3.UP, LAYERS.break_sparks)
	burst(parent, p, Vector3.UP, LAYERS.break_chunks, 1.0, 1.0, metal(c))
	burst(parent, p, Vector3.UP, LAYERS.boom_chips)
	if mech != null:
		var s := emitter(LAYERS.break_smoke)
		s.direction = Vector3.UP
		s.local_coords = false
		s.position = Vector3(0, 1.3, 0)
		mech.add_child(s)
		s.emitting = true
		var tw := s.create_tween()
		tw.tween_interval(BREAK.smoke_secs)
		tw.tween_callback(func(): s.emitting = false)
		tw.tween_interval(s.lifetime)
		tw.tween_callback(s.queue_free)
	return BREAK.stop


static func ko(parent: Node3D, marks: Node3D, f: Dictionary, c: Color) -> int:
	var ground := Vector3(f.x, 0.1, f.y)
	boom(parent, marks, {"x": f.x, "y": f.y, "r": KO.r, "big": true})
	ring(parent, ground, 0.5, KO.r * KO.ring, KO.ring_secs, c)
	burst(parent, Vector3(f.x, 1.0, f.y), Vector3.UP, LAYERS.ko_shards, 1.0, 1.0, tint(c))
	return KO.stop


static func land(parent: Node3D, marks: Node3D, f: Dictionary, c: Color) -> void:
	var ground := Vector3(f.x, 0.08, f.y)
	ring(parent, ground, f.r * 0.3, f.r * LAND.ring, LAND.ring_secs, c)
	ring(parent, ground, f.r * 0.2, f.r * LAND.ring * 0.7, LAND.ring_secs * 0.8, Color.WHITE)
	on_ring(burst(parent, ground, Vector3.UP, LAYERS.land_spikes, 1.0, 1.0, tint(c)), f.r * LAND.spikes)
	on_ring(burst(parent, ground, Vector3.UP, LAYERS.land_dust), f.r * LAND.dust)
	mark(marks, ground, Mech.ring(0.8, 1.0), Vector3(f.r * LAND.crack, 0.05, f.r * LAND.crack))


static func dash(parent: Node3D, f: Dictionary, c: Color, dir: Vector2) -> void:
	var p := Vector3(f.x, 0.35, f.y)
	var back := Vector3(-dir.x, 0.05, -dir.y).normalized()
	ring(parent, Vector3(f.x, 0.08, f.y), 0.2, 0.9, 0.2, c)
	burst(parent, p, back, LAYERS.dash_streaks, 1.0, 1.0, tint(c))
	burst(parent, Vector3(f.x, 0.15, f.y), back, LAYERS.dash_dust)


static func ghost(parent: Node3D, mech: Node3D, c: Color) -> void:
	if not mech.has_meta("ghosts"):
		mech.set_meta("ghosts", [])
		mech.set_meta("spare_ghosts", [])
	var g := take(mech.get_meta("spare_ghosts")) as Node3D
	if g == null:
		g = mech.duplicate(0) as Node3D
		var m := Mech.flat(Color(c, DASH.ghost_alpha), true).duplicate() as StandardMaterial3D
		var pairs := []
		var src := mech.find_children("*", "Node3D", true, false)
		var dst := g.find_children("*", "Node3D", true, false)
		for i in dst.size():
			var n: Node3D = dst[i]
			if n is CPUParticles3D or n.top_level:
				n.visible = false
				if n is CPUParticles3D:
					(n as CPUParticles3D).emitting = false
				continue
			if n is GeometryInstance3D:
				n.material_override = m
				n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			pairs.append([src[i], n])
		g.set_meta("pairs", pairs)
		g.set_meta("mat", m)
		g.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		mech.get_meta("ghosts").append(g)
	else:
		for p in g.get_meta("pairs"):
			p[1].transform = p[0].transform
			p[1].visible = p[0].visible
	place(g, parent)
	g.global_transform = mech.global_transform
	var mat: StandardMaterial3D = g.get_meta("mat")
	mat.albedo_color.a = DASH.ghost_alpha
	var tw := g.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, DASH.ghost_secs)
	tw.tween_callback(park.bind(g, mech.get_meta("spare_ghosts")))


static func ribbon(im: ImmediateMesh, a: Vector2, b: Vector2, w: float, c: Color, life: float) -> void:
	im.clear_surfaces()
	var d := b - a
	var ln := d.length()
	if ln < 0.01 or life <= 0.0:
		return
	var side := d.orthogonal() / ln
	var hot: Color = c.lerp(Color.WHITE, RIBBON.hot) * RIBBON.gain
	for s in [-1.0, 1.0]:
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i in RIBBON.steps + 1:
			var u := float(i) / RIBBON.steps
			var at := u * ln
			var hw: float = w * RIBBON.edge * smoothstep(0.0, RIBBON.tail, at) * maxf(RIBBON.tip, smoothstep(0.0, RIBBON.head, ln - at))
			var p := a + d * u
			var q: Vector2 = p + side * s * hw
			im.surface_set_color(Color(hot, life * lerpf(RIBBON.fade, 1.0, u)))
			im.surface_add_vertex(Vector3(p.x, RIBBON.y, p.y))
			im.surface_set_color(Color(c, 0.0))
			im.surface_add_vertex(Vector3(q.x, RIBBON.y, q.y))
		im.surface_end()


static func smoke(n: Node3D, tr: Dictionary, w: float, fresh: bool) -> void:
	if fresh:
		n.set_meta("seed", randi())
		n.set_meta("born", [])
		for p in n.get_children():
			p.visible = false
	var born: Array = n.get_meta("born")
	var a := Vector2(tr.x1, tr.y1)
	var d := Vector2(tr.x2, tr.y2) - a
	var age: int = tr.T - tr.t
	var step: float = w * SMOKE.step
	var per := ceili(w * w * SMOKE.per) + 1
	var want := (floori(d.length() / step) + 1) * per
	var rng := RandomNumberGenerator.new()
	while born.size() < want:
		var i := born.size()
		rng.seed = hash([n.get_meta("seed"), i])
		var along := minf((i / per + rng.randf()) * step, d.length())
		var off := Vector2.from_angle(rng.randf() * TAU) * w * SMOKE.spread * sqrt(rng.randf())
		var p := a + d.normalized() * along + off
		born.append([p, w * rng.randf_range(SMOKE.size.x, SMOKE.size.y), age])
		if n.get_child_count() <= i:
			var mi := Mech.add(n, Mech.ball(1.0, SMOKE.segs), smoke_mat())
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
			mi.set_instance_shader_parameter("grey", SMOKE.greys[i % SMOKE.greys.size()])
	var left := float(tr.t) / float(tr.T)
	var spent := 1.0 - left
	for i in born.size():
		var b: Array = born[i]
		var t := float(age - b[2])
		var k := 1.0 - pow(1.0 - clampf(t / SMOKE.grow, 0.0, 1.0), 2.0)
		var r: float = b[1] * (0.45 + 0.55 * k) * (1.0 + SMOKE.swell * spent)
		var mi := n.get_child(i) as MeshInstance3D
		mi.visible = true
		mi.scale = Vector3.ONE * r
		mi.position = Vector3(b[0].x, r * 0.55 + SMOKE.rise * spent, b[0].y)
		mi.set_instance_shader_parameter("fade", SMOKE.alpha * minf(t / SMOKE.fade_in, 1.0) * minf(left / SMOKE.fade_out, 1.0))


static func trail(parent: Node3D) -> CPUParticles3D:
	var s := emitter(LAYERS.missile_trail)
	s.direction = Vector3(-1, 0, 0)
	s.local_coords = false
	parent.add_child(s)
	return s
