extends RefCounted
## Atmosphere (visual plan M4): scorch marks, grime at the wall bases, floor grates, metal scraps and
## floating dust. Placed once from a fixed seed, so every match shows the same arena. Nothing on the
## floor moves, and nothing sits within `D.keep` m of a pad, a spawn, a trap warning or an oil slick.

const Sim = preload("res://src/sim.gd")
const Mech = preload("res://src/mech.gd")
const Look = preload("res://src/look.gd")

const D := {
	"seed": 4, "keep": 1.5, "tries": 600, "y": 0.02,
	"pad": 1.4, "spawn": 4.7, "crush": 2.0, "pillar": 0.5,
	"scorch": 18, "scorch_r": Vector2(1.0, 2.2), "alpha": 0.8,
	"grime": Vector2(1.4, 1.0), "grime_step": 1.2,
	"grates": 6, "grate": Vector2(1.6, 1.0), "plate": 4.0, "bar": 0.15,
	"scraps": 5, "scrap": Vector3(0.26, 0.05, 0.16), "scrap_r": 0.25, "scrap_out": 0.8,
	"dust": 160, "dust_life": 12.0, "dust_size": 0.06, "dust_alpha": 0.3, "dust_y": Vector2(0.6, 4.0), "dust_speed": 0.15,
}

const SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;
uniform vec3 soot : source_color;
uniform vec3 grime : source_color;
uniform vec3 slot : source_color;
uniform vec3 metal : source_color;
uniform float alpha = 0.8;
uniform float bar = 0.15;
varying vec4 kind;
%s
void vertex() { kind = INSTANCE_CUSTOM; }
void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float n = fbm(uv * 2.5 + kind.y * 97.0);
	ROUGHNESS = 0.9;
	METALLIC = 0.2;
	if (kind.x < 0.5) {
		float r = length(uv);
		vec2 dir = uv / max(r, 1e-4);
		float spike = pow(noise(dir * 3.0 + kind.y * 97.0), 3.0) + 0.6 * pow(noise(dir * 9.0 - kind.y * 53.0), 4.0);
		float edge = 0.3 + spike * 0.7 + (n - 0.5) * 0.15;
		float core = 1.0 - smoothstep(0.0, 0.45, r);
		float fleck = step(0.8, noise(uv * 16.0 + kind.y * 31.0)) * (1.0 - smoothstep(0.7, 1.0, r));
		ALBEDO = mix(grime * 0.5, soot, max(core, 0.7));
		ALPHA = max((1.0 - smoothstep(edge - 0.06, edge, r)) * mix(alpha, 1.0, core), fleck * alpha);
	} else if (kind.x < 1.5) {
		float t = UV.y + (n - 0.5) * 0.6;
		ALBEDO = mix(soot, grime, t);
		ALPHA = alpha * (1.0 - smoothstep(0.1, 1.0, t)) * smoothstep(0.0, 0.3, min(UV.x, 1.0 - UV.x));
	} else {
		vec2 m = (1.0 - abs(uv)) * kind.zw;
		bool rim = min(m.x, m.y) < 0.07;
		vec2 g = fract(UV * kind.zw * 2.0 / bar);
		ALBEDO = rim ? metal : (min(g.x, g.y) < 0.3 ? metal * 0.6 : slot);
		METALLIC = 0.7;
		ROUGHNESS = 0.45;
		ALPHA = 1.0;
	}
}
"""


## Adds the decor under `parent` (the arena view).
static func build(parent: Node3D) -> void:
	var all := spots()
	var flat := all.filter(func(s): return s.kind != "scrap")
	var mm := multimesh(PlaneMesh.new(), flat.size())
	(mm.mesh as PlaneMesh).size = Vector2.ONE
	for i in flat.size():
		mm.set_instance_transform(i, flat[i].at)
		mm.set_instance_custom_data(i, flat[i].data)
	var mat := Look.shader(SHADER % Look.NOISE, {"soot": Look.PAL.void, "grime": Look.PAL.grime, "slot": Look.PAL.void, "metal": Look.PAL.steel, "alpha": D.alpha, "bar": D.bar})
	add(parent, mm, mat)
	var bits := all.filter(func(s): return s.kind == "scrap")
	var sm := multimesh(Mech.box(Vector3.ONE), bits.size())
	for i in bits.size():
		sm.set_instance_transform(i, bits[i].at)
	add(parent, sm, Look.ARENA.trim)
	parent.add_child(dust())


## Every decor piece: kind, floor spot `p`, footprint radius `r`, transform `at` and shader data.
static func spots() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = D.seed
	var out := []
	var burns := []
	for i in D.tries:
		if burns.size() == D.scorch:
			break
		var r := rng.randf_range(D.scorch_r.x, D.scorch_r.y)
		var p := Vector2(rng.randf_range(0, Sim.AW), rng.randf_range(0, Sim.AH))
		if not clear(p, r):
			continue
		burns.append(p)
		out.append(piece("scorch", p, r, rng.randf() * TAU, Vector2(r, r) * 2.0, Color(0, rng.randf(), 0, 0)))
		for k in D.scraps:
			var q := p + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.3, r + D.scrap_out)
			if clear(q, D.scrap_r):
				var s: Vector3 = D.scrap * rng.randf_range(0.5, 1.0)
				var b := Basis.from_euler(Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, 0)).scaled(s)
				out.append({"kind": "scrap", "p": q, "r": D.scrap_r, "at": Transform3D(b, Vector3(q.x, s.y * 0.5, q.y))})
	var cells := []
	for x in int(Sim.AW / D.plate):
		for y in int(Sim.AH / D.plate):
			cells.append(Vector2(x + 0.5, y + 0.5) * D.plate)
	var grates := 0
	for k in cells.size():
		var j := rng.randi_range(k, cells.size() - 1)
		var c: Vector2 = cells[j]
		cells[j] = cells[k]
		var r: float = D.grate.length() / 2.0
		if grates < D.grates and clear(c, r) and burns.all(func(b): return b.distance_to(c) > r + D.scorch_r.y):
			grates += 1
			var turn := PI / 2.0 if rng.randf() < 0.5 else 0.0
			out.append(piece("grate", c, r, turn, D.grate, Color(2, 0, D.grate.x / 2.0, D.grate.y / 2.0)))
	var corners := Sim.arena_corners()
	for i in Sim.WALLS.size():
		var w = Sim.WALLS[i]
		var a := Vector2(corners[(i + corners.size() - 1) % corners.size()].x, corners[(i + corners.size() - 1) % corners.size()].y)
		var b := Vector2(corners[i].x, corners[i].y)
		var inward := -Vector2(w.nx, w.ny)
		var count := floori(a.distance_to(b) / D.grime_step)
		for k in count:
			var p := a.lerp(b, (k + 0.5) / count) + inward * D.grime.y / 2.0
			var r: float = D.grime.length() / 2.0
			if clear(p, r, true):
				out.append(piece("grime", p, r, -inward.angle() + PI / 2.0, D.grime, Color(1, rng.randf(), 0, 0)))
	return out


## True when a piece of radius `r` at `p` is inside the walls and `D.keep` m off every pad, spawn,
## crusher, tesla reach, vent jet and oil slick (pillars only must not cover it). `wall` lets it
## touch the walls.
static func clear(p: Vector2, r: float, wall := false) -> bool:
	var k: float = D.keep + r
	for w in Sim.WALLS:
		if p.x * w.nx + p.y * w.ny > w.d - (0.0 if wall else r):
			return false
	for o in Sim.PADS + [Sim.HEAL]:
		if p.distance_to(Vector2(o.x, o.y)) < D.pad + k:
			return false
	for o in Sim.SPAWNS:
		if p.distance_to(Vector2(o.x, o.y)) < D.spawn + k:
			return false
	for o in Sim.TRAPS.crush.at:
		var q := (p - Vector2(o.x, o.y)).abs()
		if maxf(q.x, q.y) < D.crush + k:
			return false
	for o in Sim.TRAPS.tesla.at:
		if p.distance_to(Vector2(o.x, o.y)) < Sim.TRAPS.tesla.reach + k:
			return false
	for o in Sim.TRAPS.oil.at:
		if p.distance_to(Vector2(o.x, o.y)) < Sim.TRAPS.oil.r + k:
			return false
	for o in Sim.PILLARS:
		if p.distance_to(Vector2(o.x, o.y)) < o.r + D.pillar + r:
			return false
	for g in Sim.vents(0.0):
		var q := p - Vector2(g.x, g.y)
		var d := Vector2(g.dx, g.dy)
		var along := q.dot(d)
		if along > -k and along < Sim.HAZARDS.reach + k and absf(q.cross(d)) < Sim.HAZARDS.half + k:
			return false
	return true


static func piece(kind: String, p: Vector2, r: float, turn: float, size: Vector2, data: Color) -> Dictionary:
	var b := Basis(Vector3.UP, turn).scaled(Vector3(size.x, 1, size.y))
	return {"kind": kind, "p": p, "r": r, "at": Transform3D(b, Vector3(p.x, D.y, p.y)), "data": data}


static func multimesh(mesh: Mesh, count: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = count
	return mm


static func add(parent: Node3D, mm: MultiMesh, mat: Material) -> void:
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


## Pale specks drifting slowly over the whole arena, above the floor.
static func dust() -> CPUParticles3D:
	var y: Vector2 = D.dust_y
	var p := CPUParticles3D.new()
	p.amount = D.dust
	p.lifetime = D.dust_life
	p.preprocess = D.dust_life
	p.use_fixed_seed = true
	p.seed = D.seed
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(Sim.AW / 2.0, (y.y - y.x) / 2.0, Sim.AH / 2.0)
	p.position = Vector3(Sim.CX, (y.x + y.y) / 2.0, Sim.CY)
	p.direction = Vector3(1, 0.2, 0)
	p.spread = 180.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = D.dust_speed * 0.5
	p.initial_velocity_max = D.dust_speed
	p.scale_amount_min = 0.5
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.2, Color.WHITE)
	fade.add_point(0.8, Color.WHITE)
	p.color_ramp = fade
	p.color = Color(Look.PAL.steel_hi, D.dust_alpha)
	var q := QuadMesh.new()
	q.size = Vector2.ONE * D.dust_size
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = m
	p.mesh = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p
