extends Node3D

const Sim = preload("res://src/sim.gd")
const Mech = preload("res://src/mech.gd")
const Fx = preload("res://src/fx.gd")
const TRACER := 0.028
const DASHES := [0.4, 0.25, 0.15]

const FLOOR_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 base : source_color = vec3(0.34, 0.36, 0.42);
uniform vec3 line : source_color = vec3(0.42, 0.5, 0.64);
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
float grid(vec2 p, float s) {
	vec2 q = p / s;
	vec2 g = abs(fract(q - 0.5) - 0.5) / fwidth(q);
	return 1.0 - min(min(g.x, g.y), 1.0);
}
void fragment() {
	float l = max(grid(wp.xz, 2.0) * 0.45, grid(wp.xz, 10.0));
	float r = length(wp.xz - vec2(38.0, 30.0));
	vec3 c = mix(base, line, l) * (1.15 - 0.35 * smoothstep(0.0, 40.0, r));
	ALBEDO = c;
	ROUGHNESS = 0.7;
	METALLIC = 0.25;
}
"""

var mechs := []
var pool := {}
var active := []
var tick := 0
var shake := 0.0
var stop := 0
var slow := 0.0
var marks: Node3D
var pylons := []
var crushers := []
var items := []
var heal_ring: MeshInstance3D
var heal_cross: Node3D
var jets := []
var cones := {}
var labels := []
var kick := Vector3.ZERO
var reticle: MeshInstance3D
var danger: MeshInstance3D
var danger_mesh := ImmediateMesh.new()
var last_shrink := -1.0


func build() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.025, 0.045)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.5, 0.7)
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_hdr_threshold = 2.2
	env.ssao_enabled = true
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.06, 0.1)
	env.fog_density = 0.004
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	marks = Node3D.new()
	add_child(marks)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 2.4
	sun.light_color = Color(1.0, 0.95, 0.88)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 110.0
	add_child(sun)
	sun.look_at_from_position(Vector3(-1.0, 2.2, -1.2), Vector3.ZERO)
	var corners := Sim.arena_corners()
	for i in [1, 3, 5, 7]:
		var c = corners[i]
		var out := Vector3(c.x - Sim.CX, 0, c.y - Sim.CY).normalized()
		var spot := SpotLight3D.new()
		spot.light_energy = 4.0
		spot.spot_attenuation = 0.6
		spot.spot_range = 90.0
		spot.spot_angle = 32.0
		spot.light_color = Color(0.85, 0.9, 1.0)
		add_child(spot)
		spot.look_at_from_position(Vector3(c.x, 0, c.y) + out * 6.0 + Vector3(0, 26, 0), Vector3(Sim.CX, 0, Sim.CY) - out * 6.0)
	build_floor(corners)
	build_walls(corners)
	build_stands(corners)
	for p in Sim.PILLARS:
		Mech.add(self, Mech.cyl(p.r, p.r * 1.08, 2.0, 8), Mech.mat(Color8(62, 70, 88), 0.0, 0.6, 0.4), Vector3(p.x, 1.0, p.y))
		Mech.add(self, Mech.ring(p.r * 0.92, p.r * 1.02), Mech.glow(Color8(255, 176, 60), 0.6), Vector3(p.x, 2.02, p.y))
	for p in Sim.TRAPS.tesla.at:
		Mech.add(self, Mech.cyl(0.3, 0.45, 1.7, 10), Mech.mat(Color8(52, 58, 72), 0.0, 0.7, 0.35), Vector3(p.x, 0.85, p.y))
		var m := StandardMaterial3D.new()
		m.albedo_color = Color8(170, 210, 255)
		m.emission_enabled = true
		m.emission = Color8(170, 210, 255)
		var top := Mech.add(self, Mech.ball(0.32), m, Vector3(p.x, 1.95, p.y))
		top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pylons.append(m)
	for p in Sim.TRAPS.crush.at:
		var h: float = Sim.TRAPS.crush.half * 2
		var warn := StandardMaterial3D.new()
		warn.albedo_color = Color8(214, 168, 44)
		warn.emission_enabled = true
		warn.emission = Color8(255, 60, 40)
		warn.emission_energy_multiplier = 0.0
		Mech.add(self, Mech.box(Vector3(h, 0.06, h)), warn, Vector3(p.x, 0.03, p.y))
		Mech.add(self, Mech.box(Vector3(h - 0.5, 0.07, h - 0.5)), Mech.mat(Color8(34, 30, 20), 0.0, 0.4, 0.6), Vector3(p.x, 0.04, p.y))
		var piston := Node3D.new()
		add_child(piston)
		Mech.add(piston, Mech.box(Vector3(h - 0.2, 0.7, h - 0.2)), Mech.mat(Color8(80, 86, 100), 0.0, 0.7, 0.35))
		Mech.add(piston, Mech.box(Vector3(0.4, 6.0, 0.4)), Mech.mat(Color8(50, 54, 64), 0.0, 0.6, 0.4), Vector3(0, 3.3, 0))
		piston.position = Vector3(p.x, 3.0, p.y)
		crushers.append([piston, warn])
	for p in Sim.TRAPS.oil.at:
		Mech.add(self, Mech.cyl(Sim.TRAPS.oil.r, Sim.TRAPS.oil.r, 0.02, 24), Mech.mat(Color8(30, 24, 44), 0.0, 0.3, 0.3), Vector3(p.x, 0.012, p.y))
	heal_ring = Mech.add(self, Mech.ring(0.7, 0.95), Mech.glow(Color8(90, 255, 150), 3.0), Vector3(Sim.HEAL.x, 0.05, Sim.HEAL.y))
	heal_cross = Node3D.new()
	heal_cross.position = Vector3(Sim.HEAL.x, 1.0, Sim.HEAL.y)
	add_child(heal_cross)
	Mech.add(heal_cross, Mech.box(Vector3(0.18, 0.6, 0.18)), Mech.glow(Color8(90, 255, 150), 4.0))
	Mech.add(heal_cross, Mech.box(Vector3(0.6, 0.18, 0.18)), Mech.glow(Color8(90, 255, 150), 4.0))
	for p in Sim.PADS:
		Mech.add(self, Mech.cyl(0.75, 0.8, 0.08, 16), Mech.mat(Color8(48, 54, 70), 0.0, 0.6, 0.4), Vector3(p.x, 0.04, p.y))
		Mech.add(self, Mech.ring(0.62, 0.74), Mech.glow(Color8(95, 180, 255), 1.0), Vector3(p.x, 0.09, p.y))
		var it := Mech.add(self, Mech.box(Vector3(0.45, 0.45, 0.45)), null, Vector3(p.x, 1.0, p.y))
		it.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		it.visible = false
		items.append(it)
	for g in Sim.vents(0.0):
		Mech.add(self, Mech.box(Vector3(0.9, 0.3, 0.5)), Mech.mat(Color8(30, 30, 34), 0.0, 0.5, 0.5), Vector3(g.x, 0.3, g.y), Vector3(0, -atan2(g.dy, g.dx), 0))
		Mech.add(self, Mech.box(Vector3(0.1, 0.12, 1.4)), Mech.glow(Color8(255, 90, 40), 1.5), Vector3(g.x + g.dx * 0.3, 0.32, g.y + g.dy * 0.3), Vector3(0, -atan2(g.dy, g.dx), 0))
		var jet := Mech.add(self, Mech.box(Vector3(1, 1, 1)), Mech.glow(Color8(255, 120, 40), 4.0, 0.7))
		jet.visible = false
		jets.append(jet)
	danger = MeshInstance3D.new()
	danger.mesh = danger_mesh
	danger.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(danger)
	reticle = Mech.add(self, Mech.ring(0.35, 0.45), Mech.glow(Mech.TEAM_LIGHT[0], 3.0, 0.8))


func build_floor(corners: Array) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var n := corners.size()
	for i in n:
		var a = corners[i]
		var b = corners[(i + 1) % n]
		st.add_vertex(Vector3(Sim.CX, 0, Sim.CY))
		st.add_vertex(Vector3(b.x, 0, b.y))
		st.add_vertex(Vector3(a.x, 0, a.y))
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = FLOOR_SHADER
	sm.shader = sh
	var floor := MeshInstance3D.new()
	floor.mesh = st.commit()
	floor.material_override = sm
	add_child(floor)
	Mech.add(self, Mech.box(Vector3(400, 0.1, 400)), Mech.mat(Color8(10, 12, 18), 0.0, 0.0, 0.9), Vector3(Sim.CX, -0.08, Sim.CY))


func edge(corners: Array, i: int) -> Array:
	var n := corners.size()
	var a = corners[(i + n - 1) % n]
	var b = corners[i]
	return [Vector3(a.x, 0, a.y), Vector3(b.x, 0, b.y), Vector3(Sim.WALLS[i].nx, 0, Sim.WALLS[i].ny)]


func build_walls(corners: Array) -> void:
	var wall := Mech.mat(Color8(44, 50, 62), 0.0, 0.5, 0.45)
	var strip := Mech.glow(Color8(255, 168, 44), 3.0)
	for i in Sim.WALLS.size():
		var e := edge(corners, i)
		var a: Vector3 = e[0]
		var b: Vector3 = e[1]
		var nrm: Vector3 = e[2]
		var mid := (a + b) / 2.0
		var length := a.distance_to(b)
		var rot := Vector3(0, -atan2(b.z - a.z, b.x - a.x), 0)
		Mech.add(self, Mech.box(Vector3(length + 0.8, 1.3, 0.8)), wall, mid + nrm * 0.4 + Vector3(0, 0.65, 0), rot)
		Mech.add(self, Mech.box(Vector3(length, 0.08, 0.1)), strip, mid + nrm * 0.02 + Vector3(0, 1.3, 0), rot)


func build_stands(corners: Array) -> void:
	var tier := Mech.mat(Color8(20, 23, 32), 0.0, 0.2, 0.8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var spots := []
	for i in Sim.WALLS.size():
		var e := edge(corners, i)
		var a: Vector3 = e[0]
		var b: Vector3 = e[1]
		var nrm: Vector3 = e[2]
		var dir := (b - a).normalized()
		var rot := Vector3(0, -atan2(dir.z, dir.x), 0)
		var fan: Color = Mech.TEAM[0] if nrm.x < -0.1 else (Mech.TEAM[1] if nrm.x > 0.1 else Color8(200, 200, 210))
		for k in 3:
			var off := 2.4 + k * 2.6
			var length := a.distance_to(b) + 2.0 * (off + 1.3) * 0.414
			var h := 1.4 + k * 1.3
			Mech.add(self, Mech.box(Vector3(length, h, 2.6)), tier, (a + b) / 2.0 + nrm * (off + 1.3) + Vector3(0, h / 2.0, 0), rot)
			Mech.add(self, Mech.box(Vector3(length, 0.06, 0.08)), Mech.glow(fan, 1.2), (a + b) / 2.0 + nrm * off + Vector3(0, h + 0.03, 0), rot)
			var count := int(length / 0.75)
			for j in count:
				if rng.randf() < 0.25:
					continue
				var along := (j + 0.5) / count - 0.5
				var pos: Vector3 = (a + b) / 2.0 + dir * along * (length - 1.0) + nrm * (off + 0.6 + rng.randf() * 1.2) + Vector3(0, h + 0.35, 0)
				var c: Color = fan if rng.randf() < 0.55 else Color.from_hsv(rng.randf(), 0.15, 0.35 + rng.randf() * 0.3)
				spots.append([pos, c])
	mm.instance_count = spots.size()
	for i in spots.size():
		mm.set_instance_transform(i, Transform3D(Basis(), spots[i][0]))
		mm.set_instance_color(i, spots[i][1])
	var person := CapsuleMesh.new()
	person.radius = 0.2
	person.height = 0.7
	person.radial_segments = 6
	person.rings = 2
	var pm := StandardMaterial3D.new()
	pm.vertex_color_use_as_albedo = true
	pm.roughness = 0.8
	person.material = pm
	mm.mesh = person
	var crowd := MultiMeshInstance3D.new()
	crowd.multimesh = mm
	crowd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(crowd)


func reset(state: Dictionary) -> void:
	for m in mechs:
		for g in m.get_meta("ghosts", []):
			g.queue_free()
		m.queue_free()
	mechs.clear()
	for m in state.mechs:
		var node := Mech.new()
		add_child(node)
		node.build(m.loadout, m.team)
		node.smoke = Fx.wreck(node)
		mechs.append(node)
	for n in active:
		n.visible = false
		pool[n.get_meta("kind")].append(n)
	active.clear()
	for c in marks.get_children():
		c.queue_free()


func team_of(state: Dictionary, id) -> int:
	return state.mechs[id].team if id != null and id >= 0 and id < state.mechs.size() else 0


func shooter_color(state: Dictionary, f: Dictionary) -> Color:
	if state.score.size() == 2:
		return Mech.TEAM[1 - team_of(state, f.id)]
	return Color8(255, 210, 120)


func sync(state: Dictionary, aim: Vector3, dt: float) -> void:
	tick += 1
	for i in mechs.size():
		mechs[i].sync(state.mechs[i], tick, dt)
		var act = state.mechs[i].act
		if act != null and act.k == "dash" and act.get("ph") == "go" and tick % Fx.DASH.every == 0:
			Fx.ghost(self, mechs[i], Mech.TEAM[state.mechs[i].team])
		guard(state.mechs[i], mechs[i])
		var pull = state.mechs[i].pull
		if pull != null:
			var by = state.mechs[pull.by]
			var cab := node_for(pull, "cable")
			var d := Vector2(state.mechs[i].x - by.x, state.mechs[i].y - by.y)
			cab.position = Vector3(state.mechs[i].x, 1.05, state.mechs[i].y)
			cab.rotation = Vector3(0, -d.angle(), 0)
			tether(cab, d.length(), Mech.TEAM[by.team])
			settle(cab)
	reticle.position = aim + Vector3(0, 0.05, 0)
	reticle.visible = state.phase == "fight" and not state.mechs[0].ko
	for f in state.fx:
		if not f.has("seen"):
			f["seen"] = true
			spawn(state, f)
	var flames := {}
	for s in state.shots:
		if s.kind == "flame":
			if not flames.has(s.owner):
				flames[s.owner] = []
			flames[s.owner].append(s)
		else:
			shot(state, s)
	for id in cones:
		cones[id].visible = flames.has(id)
	for id in flames:
		cone(state, id, flames[id])
	for l in state.lobs:
		lob(state, l)
	for mi in state.mines:
		var n := node_for(mi, "mine")
		n.position = Vector3(mi.x, 0.06, mi.y)
		var armed: bool = mi.arm <= 0
		n.get_child(1).visible = not armed or (tick / 8) % 2 == 0
		settle(n)
	for f in state.fields:
		var n := node_for(f, "field_" + f.kind)
		n.position = Vector3(f.x, 0.04, f.y)
		n.scale = Vector3(f.r, 1, f.r)
		n.get_child(0).transparency = 1.0 - clampf(f.t / 30.0, 0.0, 1.0)
		settle(n)
	for tr in state.trails:
		trail(state, tr)
	for w in state.walls:
		var n := node_for(w, "wall")
		var d := Vector2(w.x2 - w.x1, w.y2 - w.y1)
		n.position = Vector3((w.x1 + w.x2) / 2.0, 1.1, (w.y1 + w.y2) / 2.0)
		n.rotation = Vector3(0, -d.angle(), 0)
		n.scale = Vector3(d.length(), 1, 1)
		n.material_override = Mech.glow(Mech.TEAM_LIGHT[team_of(state, w.owner)], 2.0, 0.55)
		settle(n)
	var keep := []
	for n in active:
		if n.get_meta("seen") == tick:
			keep.append(n)
		else:
			n.visible = false
			if n.get_meta("kind") == "missile":
				n.get_child(2).emitting = false
			pool[n.get_meta("kind")].append(n)
	active = keep
	arena(state)


func guard(m: Dictionary, node) -> void:
	var was: float = node.get_meta("soaked", 0.0)
	var got: float = m.act.get("absorbed", 0.0) if Sim.shield_up(m) else 0.0
	if got > was:
		Fx.ripple(self, node.shield.global_transform, got - was, false)
	elif was > 0.0 and m.act == null and m.cd.shield > Sim.SHIELD.cd:
		Fx.ripple(self, node.shield.global_transform, was, true)
	node.set_meta("soaked", got)


func tether(n: Node3D, ln: float, c: Color) -> void:
	var w := 1.0 + 0.3 * sin(tick * 1.7)
	for i in 2:
		var b: MeshInstance3D = n.get_child(i)
		b.position = Vector3(-ln / 2.0, 0, 0)
		b.scale = Vector3(ln, w, w)
	n.get_child(0).material_override = Mech.flat(Color(c, 0.85), true)


func node_for(o: Dictionary, kind: String) -> Node3D:
	var n = o.get("_n")
	if n == null:
		if not pool.has(kind):
			pool[kind] = []
		n = pool[kind].pop_back() if pool[kind].size() else make(kind)
		o["_n"] = n
		n.set_meta("kind", kind)
		n.set_meta("fresh", true)
		n.visible = true
		active.append(n)
	n.set_meta("seen", tick)
	return n


func settle(n: Node3D) -> void:
	if n.get_meta("fresh"):
		n.set_meta("fresh", false)
		n.reset_physics_interpolation()


func make(kind: String) -> Node3D:
	var n: Node3D
	match kind:
		"bolt":
			n = Node3D.new()
			add_child(n)
			Mech.add(n, Mech.ball(1.0, 10), null)
			for i in DASHES.size():
				Mech.add(n, Mech.box(Vector3.ONE), null)
		"missile":
			n = Node3D.new()
			add_child(n)
			Mech.add(n, Mech.box(Vector3(0.6, 0.18, 0.18)), Mech.mat(Mech.STEEL, 0.0, 0.7, 0.3))
			Mech.add(n, Mech.ball(0.14, 8), Mech.flat(Color8(255, 200, 110), true), Vector3(-0.38, 0, 0))
			Fx.trail(n).position = Vector3(-0.42, 0, 0)
		"hook":
			n = Node3D.new()
			add_child(n)
			Mech.add(n, Mech.box(Vector3(0.4, 0.2, 0.4)), Mech.mat(Mech.STEEL, 0.0, 0.8, 0.3))
			make("cable").reparent(n, false)
		"cable":
			n = Node3D.new()
			add_child(n)
			for w in [0.08, 0.03]:
				var b := Mech.add(n, Mech.box(Vector3(1, w, w)), Mech.flat(Color.WHITE, true))
				b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		"lob":
			n = Node3D.new()
			add_child(n)
			Mech.add(n, Mech.ring(0.9, 1.0), Mech.flat(Color8(255, 100, 55, 230)))
			Mech.add(n, Mech.cyl(1.0, 1.0, 0.02, 24), Mech.flat(Color8(255, 90, 50, 80)))
			Mech.add(n, Mech.ball(0.25, 8), Mech.flat(Color8(255, 210, 130)))
		"mine":
			n = Node3D.new()
			add_child(n)
			Mech.add(n, Mech.cyl(0.3, 0.34, 0.12, 10), Mech.mat(Mech.DARK, 0.0, 0.6, 0.4))
			Mech.add(n, Mech.ball(0.09, 8), Mech.glow(Color8(255, 60, 40), 6.0), Vector3(0, 0.1, 0))
		"field_stasis", "field_well":
			var c := Color8(110, 235, 255) if kind == "field_stasis" else Color8(205, 125, 255)
			n = Node3D.new()
			add_child(n)
			Mech.add(n, Mech.cyl(1.0, 1.0, 0.03, 32), Mech.glow(c, 1.2, 0.3))
			Mech.add(n, Mech.ring(0.94, 1.0), Mech.glow(c, 3.0))
		"ribbon":
			var mi := MeshInstance3D.new()
			mi.mesh = ImmediateMesh.new()
			mi.material_override = Mech.flat(Color.WHITE, true)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
			add_child(mi)
			n = mi
		"smoke":
			n = Node3D.new()
			n.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
			add_child(n)
		"wall":
			n = Mech.add(self, Mech.box(Vector3(1, 2.2, 0.35)), null)
		_:
			n = Mech.add(self, Mech.box(Vector3(1, 1, 1)), null)
	return n


func cone(state: Dictionary, id: int, shots: Array) -> void:
	if not cones.has(id):
		cones[id] = Fx.flame_cone(self)
	var C := Fx.CONE
	var m = state.mechs[id]
	var o := Vector2(m.x, m.y)
	var sum := Vector2.ZERO
	var near := INF
	var far := 0.0
	for s in shots:
		var d := Vector2(s.x, s.y) - o
		sum += d
		near = minf(near, d.length())
		far = maxf(far, d.length())
	var dir := sum.normalized()
	var a: float = near - C.back if near > C.snap else C.muzzle
	var b: float = far + C.reach
	var r: float = C.r0 + b * C.widen
	var mid := o + dir * (a + b) / 2.0
	var y := Vector3(-dir.x, 0, -dir.y)
	var x := y.cross(Vector3.UP)
	var n: MeshInstance3D = cones[id]
	n.visible = true
	n.transform = Transform3D(Basis(x * r, y * maxf(b - a, 0.1), Vector3.UP * r), Vector3(mid.x, C.y, mid.y))


func shot(state: Dictionary, s: Dictionary) -> void:
	var kind: String = s.kind if s.kind in ["bolt", "missile", "hook"] else "bolt"
	var n := node_for(s, kind)
	var ang := atan2(s.vy, s.vx)
	n.position = Vector3(s.x, 1.05, s.y)
	n.rotation = Vector3(0, -ang, 0)
	var team := team_of(state, s.owner)
	match kind:
		"bolt":
			var head: MeshInstance3D = n.get_child(0)
			var ln := clampf(Vector2(s.vx, s.vy).length() * TRACER, 0.8, 2.4)
			var c: Color = Mech.TEAM[team]
			head.scale = Vector3(s.r * 1.6, s.r * 0.7, s.r * 0.7)
			head.material_override = Mech.flat(c.lightened(0.7), true)
			var x: float = -s.r
			for i in DASHES.size():
				var dash: MeshInstance3D = n.get_child(i + 1)
				var dl: float = ln * DASHES[i]
				dash.scale = Vector3(dl, s.r * 0.5, s.r * 0.6)
				dash.position = Vector3(x - dl / 2.0, 0, 0)
				dash.material_override = Mech.flat(Color(c, 1.0 - 0.3 * i), true)
				x -= dl + ln * 0.12
		"missile":
			var tr: CPUParticles3D = n.get_child(2)
			if n.get_meta("fresh"):
				tr.restart()
			tr.emitting = true
		"hook":
			var o = state.mechs[s.owner]
			var back := Vector2(o.x - s.x, o.y - s.y)
			n.rotation = Vector3(0, -(-back).angle(), 0)
			tether(n.get_child(1), back.length(), Mech.TEAM[team])
	settle(n)


func lob(state: Dictionary, l: Dictionary) -> void:
	var n := node_for(l, "lob")
	n.position = Vector3(l.x, 0.06, l.y)
	var p: float = 1.0 - float(l.t) / float(l.T)
	n.get_child(0).scale = Vector3(l.r, 1, l.r)
	n.get_child(1).scale = Vector3(l.r * p, 1, l.r * p)
	var shell: MeshInstance3D = n.get_child(2)
	shell.visible = l.kind != "decoy"
	var arc := 7.0 if l.kind == "shell" else 14.0
	var from := Vector3(l.sx - l.x, 1.1, l.sy - l.y)
	if l.kind == "strike":
		from = Vector3(0, 30, 0)
	shell.position = from.lerp(Vector3.ZERO, p) + Vector3(0, arc * 4.0 * p * (1.0 - p) if l.kind == "shell" else 0.0, 0)
	settle(n)


func trail(state: Dictionary, tr: Dictionary) -> void:
	var w: float = tr.get("w", Sim.TRAILS[tr.kind].width)
	if tr.kind == "smoke":
		var s := node_for(tr, "smoke")
		Fx.smoke(s, tr, w, s.get_meta("fresh"))
		settle(s)
		return
	var n := node_for(tr, "ribbon") as MeshInstance3D
	var life := sqrt(clampf(float(tr.t) / float(tr.T), 0.0, 1.0))
	Fx.ribbon(n.mesh, Vector2(tr.x1, tr.y1), Vector2(tr.x2, tr.y2), w, Mech.BOOST_C[tr.kind], life)
	settle(n)


func arena(state: Dictionary) -> void:
	var Z = Sim.TRAPS.tesla
	for i in pylons.size():
		var u := Sim.until_zap(state, i)
		pylons[i].emission_energy_multiplier = (2.0 + 4.0 * absf(sin(tick * 0.5))) if u <= Z.warn else 0.35
	var C = Sim.TRAPS.crush
	for i in crushers.size():
		var u := Sim.until_slam(state, i)
		var since: int = C.every - u
		var y := 3.0
		if Sim.elapsed(state) > 0 and since < 10:
			y = 0.4
		elif Sim.elapsed(state) > 0 and since < 70:
			y = lerpf(0.4, 3.0, (since - 10) / 60.0)
		var warn: bool = u <= C.warn
		if warn:
			y += 0.05 * sin(tick * 1.7)
		crushers[i][0].position.y = y
		crushers[i][1].emission_energy_multiplier = (2.0 + 2.0 * sin(tick * 0.6)) if warn else 0.0
	heal_ring.transparency = 0.0 if state.heal.ready else 0.75
	heal_cross.visible = state.heal.ready
	heal_cross.rotation.y += 0.03
	for i in items.size():
		var kind = state.pads[i]
		items[i].visible = kind != null
		if kind != null:
			var c: Color = item_color(kind)
			items[i].material_override = Mech.glow(c, 1.1)
			items[i].rotation = Vector3(0.6, tick * 0.04, 0.3)
			items[i].position.y = 1.0 + 0.15 * sin(tick * 0.06 + i)
	var v = Sim.vent_phase(state)
	var list := Sim.vents(state.shrink)
	for i in jets.size():
		var g = list[i]
		var on: bool = v != null and (v.burn or v.warn) and g.wall % 2 == v["set"]
		var jet: MeshInstance3D = jets[i]
		jet.visible = on
		if on:
			var reach: float = Sim.HAZARDS.reach
			var flick := 1.0 + 0.08 * sin(tick * 2.3 + i)
			jet.position = Vector3(g.x + g.dx * reach / 2.0, 0.35 if v.burn else 0.03, g.y + g.dy * reach / 2.0)
			jet.rotation = Vector3(0, -atan2(g.dy, g.dx), 0)
			jet.scale = Vector3(reach * flick, 0.7 if v.burn else 0.02, Sim.HAZARDS.half * 2.0 * flick)
			jet.transparency = 0.15 if v.burn else 0.55
	if state.shrink != last_shrink:
		last_shrink = state.shrink
		danger_mesh.clear_surfaces()
		if state.shrink > 0:
			var outer := Sim.arena_corners()
			var inner := Sim.arena_corners(-state.shrink)
			danger_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, Mech.glow(Color8(255, 50, 40), 1.5, 0.35))
			var n := outer.size()
			for i in n:
				var j := (i + 1) % n
				var a := Vector3(outer[i].x, 0.03, outer[i].y)
				var b := Vector3(outer[j].x, 0.03, outer[j].y)
				var c := Vector3(inner[i].x, 0.03, inner[i].y)
				var d := Vector3(inner[j].x, 0.03, inner[j].y)
				for p in [a, b, c, b, d, c]:
					danger_mesh.surface_add_vertex(p)
			danger_mesh.surface_end()


func item_color(kind: String) -> Color:
	match kind:
		"repair":
			return Color8(90, 255, 150)
		"shield":
			return Color8(110, 170, 255)
		"speed":
			return Color8(255, 220, 70)
		"power":
			return Color8(255, 80, 60)
		"coolant":
			return Color8(110, 235, 255)
	return Color8(197, 139, 255)








func number(p: Vector3, text: String, c: Color, size: int) -> void:
	var l := Fx.take(labels) as Label3D
	if l == null:
		l = Label3D.new()
		l.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		l.outline_size = 14
		l.outline_modulate = Color(0, 0, 0, 0.85)
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.pixel_size = 0.012
	Fx.place(l, self)
	l.text = text
	l.font_size = size
	l.modulate = c
	l.transparency = 0.0
	l.position = p
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", p.y + 1.6, 0.75).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(l, "transparency", 1.0, 0.45).set_delay(0.3)
	tw.chain().tween_callback(Fx.park.bind(l, labels))






func spawn(state: Dictionary, f: Dictionary) -> void:
	var p := Vector3(f.get("x", 0.0), 1.0, f.get("y", 0.0))
	match f.k:
		"hit":
			var head: bool = f.get("head", false)
			Fx.hit(self, f, shooter_color(state, f))
			number(p + Vector3(0, 1.3, 0), str(int(f.n)), Color8(255, 230, 120) if head else Color.WHITE, 80 if head else 60)
			var push := Fx.kick_of(f)
			if push == Vector3.ZERO:
				shake = maxf(shake, Fx.shake_of(f))
			elif push.length() > kick.length():
				kick = push
			stop = maxi(stop, Fx.stop_of(f))
		"boom":
			var big: bool = f.get("big", false)
			stop = maxi(stop, Fx.boom(self, marks, f))
			shake = maxf(shake, 0.6 if big else 0.2)
		"muzzle":
			Fx.muzzle(self, f, Mech.TEAM[team_of(state, f.id)])
		"zap":
			if f.kind == "laser":
				Fx.ray(self, f, 0.35, "laser", 0.16)
			else:
				Fx.arc(self, f)
		"beam":
			if f.kind == "lance":
				Fx.ray(self, f, Sim.LANCE.halfWidth * 2.0, "lance", 0.35, true)
			else:
				Fx.ray(self, f, Sim.ULTS.rail.halfWidth * 2.0, "rail", 0.35, true)
			shake = maxf(shake, 0.35)
		"parry":
			stop = maxi(stop, Fx.parry(self, f))
			shake = maxf(shake, 0.2)
		"break":
			stop = maxi(stop, Fx.shatter(self, mechs[f.id] if f.id < mechs.size() else null, f, Mech.TEAM[team_of(state, f.id)]))
			shake = maxf(shake, 0.45)
		"ko":
			stop = maxi(stop, Fx.ko(self, marks, f, Mech.TEAM[team_of(state, f.id)]))
			slow = Fx.KO.slow_secs
			shake = maxf(shake, 1.2)
		"dash":
			var act = state.mechs[f.id].act
			var dir := Vector2(act.dx, act.dy) if act != null and act.has("dx") else Vector2.RIGHT
			Fx.dash(self, f, Mech.TEAM[team_of(state, f.id)], dir)
		"land":
			Fx.land(self, marks, f, Mech.TEAM[team_of(state, f.id)])
			shake = maxf(shake, 0.25)
		"emp":
			var inside := []
			for m in state.mechs:
				if m.id != f.id and not m.ko and Vector2(m.x - f.x, m.y - f.y).length() <= f.r:
					inside.append(Vector3(m.x, 1.05, m.y))
			Fx.emp(self, f, inside)
		"blink":
			Fx.blink(self, f)
		"heal", "pickup":
			Fx.heal(self, f)
			if f.k == "heal":
				number(p + Vector3(0, 1.3, 0), "+%d" % int(f.n), Color8(120, 255, 170), 60)
		"hooked":
			Fx.hooked(self, f, Mech.TEAM[team_of(state, f.by)])
		"soak":
			Fx.soak(self, f)
		"magnet":
			Fx.magnet(self, f)
		"crush":
			Fx.crush(self, marks, f)
			shake = maxf(shake, 0.3)
		"ping":
			Fx.ping(self, f)
		"charge":
			Fx.charge(self, f, Mech.TEAM[team_of(state, f.id)])
