extends RefCounted

const Mech = preload("res://src/mech.gd")

const HIT := {
	"full": 40.0, "w_min": 0.2, "w_max": 1.5,
	"face": 0.45,
	"flash": 0.55, "flash_secs": 0.05,
	"streaks": Vector2(6, 16), "streak_speed": Vector2(8.0, 16.0), "streak_life": 0.34, "spread": 28.0,
	"smoke": Vector2(2, 4), "smoke_life": 1.1,
	"chips_at": 0.6, "chips": Vector2(3, 6),
	"heavy": 1.0, "stop_head": 3, "stop_heavy": 2,
	"shake": Vector2(0.05, 0.17), "shake_head": 0.15,
}
const RAMPS := {
	"spark": [Color(1, 1, 0.92), Color8(255, 225, 120), Color8(255, 150, 50), Color8(255, 100, 30, 0)],
	"smoke": [Color(0.62, 0.62, 0.66, 0.75), Color(0.36, 0.36, 0.4, 0.7), Color(0.2, 0.2, 0.23, 0)],
	"chip": [Color8(78, 82, 92), Color8(78, 82, 92), Color8(40, 42, 48, 0)],
}

static var _ramps := {}


static func weight(dmg: float) -> float:
	return clampf(dmg / HIT.full, HIT.w_min, HIT.w_max)


static func ramp(name: String) -> Gradient:
	if not _ramps.has(name):
		var cs: Array = RAMPS[name]
		var g := Gradient.new()
		var at := PackedFloat32Array()
		for i in cs.size():
			at.append(float(i) / (cs.size() - 1))
		g.offsets = at
		g.colors = PackedColorArray(cs)
		_ramps[name] = g
	return _ramps[name]


static func flash(parent: Node3D, p: Vector3, size: float, secs: float) -> void:
	var mi := MeshInstance3D.new()
	mi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	mi.mesh = Mech.ball(1.0, 10)
	mi.material_override = Mech.flat(Color.WHITE)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = p
	mi.scale = Vector3.ONE * size
	parent.add_child(mi)
	var tw := mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3.ONE * size * 1.6, secs)
	tw.tween_property(mi, "transparency", 1.0, secs).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)


static func burst(parent: Node3D, p: Vector3, dir: Vector3, n: int, mesh: Mesh, colors: String, speed: Vector2, life: float, spread: float, gravity: float, align := false, grow := 1.0, damping := 0.0) -> void:
	var s := CPUParticles3D.new()
	s.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	s.one_shot = true
	s.explosiveness = 1.0
	s.amount = maxi(1, n)
	s.lifetime = life
	s.lifetime_randomness = 0.4
	s.mesh = mesh
	s.material_override = Mech.flat(Color.WHITE)
	s.color_ramp = ramp(colors)
	s.direction = dir
	s.spread = spread
	s.initial_velocity_min = speed.x
	s.initial_velocity_max = speed.y
	s.gravity = Vector3(0, gravity, 0)
	s.damping_min = damping
	s.damping_max = damping
	s.particle_flag_align_y = align
	s.scale_amount_min = 0.7 * grow
	s.scale_amount_max = 1.2 * grow
	if grow != 1.0:
		var c := Curve.new()
		c.add_point(Vector2(0, 1.0 / grow))
		c.add_point(Vector2(1, 1))
		s.scale_amount_curve = c
	s.position = p
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(s)
	s.emitting = true
	s.finished.connect(s.queue_free)


static func hit(parent: Node3D, f: Dictionary) -> void:
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
		spread = HIT.spread
	flash(parent, p, HIT.flash * (0.7 + 0.3 * t), HIT.flash_secs)
	var sp: Vector2 = HIT.streak_speed * (0.75 + 0.25 * t)
	burst(parent, p, dir, roundi(lerpf(HIT.streaks.x, HIT.streaks.y, t)), Mech.box(Vector3(0.11, 0.75, 0.11)), "spark", sp, HIT.streak_life, spread, -18.0, true)
	burst(parent, p, (dir + Vector3.UP).normalized(), roundi(lerpf(HIT.smoke.x, HIT.smoke.y, t)), Mech.ball(0.42, 14), "smoke", Vector2(0.8, 2.0), HIT.smoke_life, 50.0, 1.5, false, 1.6 + t, 2.5)
	if w > HIT.chips_at:
		burst(parent, p, dir, roundi(lerpf(HIT.chips.x, HIT.chips.y, t)), Mech.box(Vector3(0.14, 0.14, 0.14)), "chip", Vector2(3.0, 7.0), 0.7, spread + 25.0, -24.0)


static func stop_of(f: Dictionary) -> int:
	if f.get("head", false):
		return HIT.stop_head
	return HIT.stop_heavy if weight(f.n) >= HIT.heavy else 0


static func shake_of(f: Dictionary) -> float:
	var t := weight(f.n) / HIT.w_max
	return lerpf(HIT.shake.x, HIT.shake.y, t) + (HIT.shake_head if f.get("head", false) else 0.0)
