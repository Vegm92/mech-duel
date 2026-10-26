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
const SHIELD_C := Color8(110, 220, 255)

const LAYERS := {
	"hit_sparks": {"mesh": "needle", "ramp": "spark", "n": Vector2(8, 18), "speed": Vector2(10, 24), "life": 0.34, "spread": 28.0, "gravity": -10.0, "damp": 25.0, "align": true, "shrink": true, "add": true},
	"hit_smoke": {"mesh": "puff_s", "ramp": "smoke_late", "n": Vector2(1, 3), "speed": Vector2(0.8, 2.0), "life": 1.1, "spread": 50.0, "gravity": 1.5, "damp": 2.5, "grow": 2.2},
	"hit_chips": {"mesh": "chip", "ramp": "chip", "n": Vector2(3, 6), "speed": Vector2(3, 7), "life": 0.7, "spread": 55.0, "gravity": -24.0, "spin": 540.0},
	"muzzle_sparks": {"mesh": "needle_s", "ramp": "spark", "n": Vector2(5, 5), "speed": Vector2(10, 18), "life": 0.13, "spread": 16.0, "gravity": 0.0, "damp": 40.0, "align": true, "shrink": true, "add": true},
	"muzzle_smoke": {"mesh": "puff_s", "ramp": "smoke_thin", "n": Vector2(1, 1), "speed": Vector2(0.6, 1.4), "life": 0.7, "spread": 25.0, "gravity": 1.0, "damp": 3.0, "grow": 2.0},
	"boom_fire": {"mesh": "puff", "ramp": "fire", "n": Vector2(8, 16), "speed": Vector2(2, 6), "life": 0.5, "spread": 180.0, "gravity": 2.0, "damp": 7.0, "grow": 1.8, "sphere": 0.45, "add": true},
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
	"missile_trail": {"mesh": "puff_s", "ramp": "smoke_thin", "n": Vector2(48, 48), "speed": Vector2(1, 2), "life": 0.55, "spread": 15.0, "gravity": 0.6, "damp": 3.0, "grow": 2.5},
}
const MESHES := {
	"needle": [Vector3(0.08, 0.9, 0.08), 0], "needle_s": [Vector3(0.065, 0.55, 0.065), 0],
	"chip": [Vector3(0.14, 0.14, 0.14), 0], "chunk": [Vector3(0.26, 0.18, 0.22), 0], "puff": [0.42, 14], "puff_s": [0.2, 10],
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
	var mi := MeshInstance3D.new()
	mi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	mi.mesh = m
	mi.material_override = Mech.flat(c, add)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = p
	mi.rotation = rot
	mi.scale = scale_
	parent.add_child(mi)
	return mi


static func fade(mi: Node3D, secs: float, to_scale: Vector3, ease_ := Tween.EASE_IN) -> void:
	var tw := mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", to_scale, secs).set_ease(ease_).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mi, "transparency", 1.0, secs).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)


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
	s.amount = maxi(1, roundi(lerpf(L.n.x, L.n.y, t)))
	s.lifetime = L.life
	s.lifetime_randomness = 0.4
	s.mesh = mesh(L.mesh)
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
	if grow != 1.0:
		s.scale_amount_curve = curve([Vector2(0, 1.0 / grow), Vector2(1, 1)])
	elif L.get("shrink", false):
		s.scale_amount_curve = curve([Vector2(0, 1), Vector2(0.6, 0.8), Vector2(1, 0)])
	if L.has("spin"):
		s.particle_flag_rotate_y = true
		s.angle_min = 0.0
		s.angle_max = 360.0
		s.angular_velocity_min = -L.spin
		s.angular_velocity_max = L.spin
	if L.has("sphere"):
		s.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		s.emission_sphere_radius = L.sphere * k
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return s


static func fire(parent: Node3D, s: CPUParticles3D) -> CPUParticles3D:
	s.one_shot = true
	s.explosiveness = 1.0
	parent.add_child(s)
	s.emitting = true
	s.finished.connect(s.queue_free)
	return s


static func burst(parent: Node3D, p: Vector3, dir: Vector3, L: Dictionary, t := 1.0, k := 1.0, g: Gradient = null) -> CPUParticles3D:
	var s := emitter(L, t, k, g)
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
		var s := emitter(LAYERS.beam_sparks, 1.0, 1.0, ramp(ramp_name))
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
	var g := mech.duplicate(0) as Node3D
	var m := Mech.flat(Color(c, DASH.ghost_alpha), true).duplicate() as StandardMaterial3D
	for n in g.find_children("*", "", true, false):
		if n is CPUParticles3D or (n is Node3D and n.top_level):
			n.queue_free()
		elif n is GeometryInstance3D:
			n.material_override = m
			n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	parent.add_child(g)
	g.global_transform = mech.global_transform
	var tw := g.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, DASH.ghost_secs)
	tw.tween_callback(g.queue_free)


static func trail(parent: Node3D) -> CPUParticles3D:
	var s := emitter(LAYERS.missile_trail)
	s.direction = Vector3(-1, 0, 0)
	s.local_coords = false
	parent.add_child(s)
	return s
