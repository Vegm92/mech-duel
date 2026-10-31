extends Node3D

const Sim = preload("res://src/sim.gd")
const Mech = preload("res://src/mech.gd")
const Fx = preload("res://src/fx.gd")
const Look = preload("res://src/look.gd")
const Decor = preload("res://src/decor.gd")
const TRACER := 0.028
const DASHES := [0.4, 0.25, 0.15]
const BLEND := 4.0
const Hype = preload("res://src/hype.gd")
const CROWD := {"rows": [0.65, 1.95], "gap": 0.55, "empty": 0.08, "neutral": 0.2,
	"neutrals": [Color8(230, 230, 236), Color8(60, 64, 74), Color8(240, 200, 60), Color8(120, 200, 120)],
	"skins": [Color8(241, 194, 150), Color8(198, 134, 90), Color8(141, 85, 52), Color8(255, 220, 180)]}

const CROWD_SHADER := """
shader_type spatial;
uniform vec3 shirts[8];
uniform vec3 skins[4];
uniform float cheer[4];
varying vec3 col;
void vertex() {
	int slot = int(INSTANCE_CUSTOM.y + 0.5);
	float on = slot < 4 ? cheer[slot] : max(max(cheer[0], cheer[1]), max(cheer[2], cheer[3]));
	float ph = INSTANCE_CUSTOM.x;
	float tag = UV.x;
	if (on > 0.5 && ((tag > 0.2 && tag < 0.4) || (tag > 0.6 && tag < 0.8))) {
		float s = sign(VERTEX.x);
		vec2 p = VERTEX.xy - vec2(s * 0.205, 0.64);
		float a = s * (2.5 + 0.35 * sin(TIME * 8.3 + ph));
		VERTEX.xy = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * p + vec2(s * 0.205, 0.64);
	}
	VERTEX.y += on > 0.5 ? max(0.0, sin(TIME * 8.3 + ph)) * 0.35 : 0.03 * sin(TIME * 2.5 + ph);
	col = tag < 0.4 ? shirts[slot] * INSTANCE_CUSTOM.z : (tag < 0.8 ? skins[int(INSTANCE_CUSTOM.w + 0.5)] : vec3(0.02, 0.025, 0.035));
}
void fragment() {
	ALBEDO = col;
	ROUGHNESS = 0.85;
}
"""

const FLOOR_SHADER := """
shader_type spatial;
render_mode cull_disabled;
""" + Look.NOISE + """
uniform vec3 base : source_color;
uniform vec3 paint : source_color;
uniform vec3 black : source_color;
uniform vec3 mark : source_color;
uniform float metal;
uniform vec2 rough;
uniform float plate = 4.0;
uniform float split;
uniform float tint;
uniform float dirt;
uniform vec2 seam;
uniform float tilt;
uniform float polish;
uniform float stripe;
uniform float wear;
uniform vec2 ring;
uniform vec2 box;
uniform vec2 edge;
uniform vec2 rings[10];
uniform vec2 boxes[4];
uniform vec3 walls[8];
uniform vec3 spawns[2];
uniform vec3 oils[2];
uniform vec3 oil : source_color;
uniform vec2 slick;
uniform float film;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
float band(float x, vec2 r) {
	float w = fwidth(x);
	return smoothstep(r.x - w, r.x + w, x) * (1.0 - smoothstep(r.y - w, r.y + w, x));
}
void fragment() {
	vec2 p = wp.xz;
	vec2 id = floor(p / plate);
	float h = hash(id);
	float s = hash(id + 17.0) < split ? plate * 0.5 : plate;
	vec2 f = fract(p / s) - 0.5;
	vec2 e = (0.5 - abs(f)) * s;
	float d = min(e.x, e.y);
	float gap = 1.0 - band(d, vec2(seam.x, 1e6));
	vec2 b = 1.0 - smoothstep(vec2(seam.x), vec2(seam.y), e);
	float grime = smoothstep(0.35, 0.8, fbm(p * 0.3)) * 0.7 + (1.0 - smoothstep(0.0, 0.5, d)) * 0.3;
	float scuff = noise(p * vec2(6.0, 0.6) + h * 40.0);
	vec3 c = base * (1.0 + (h - 0.5) * tint);
	c *= 1.0 - dirt * grime;
	c *= 0.92 + 0.12 * scuff;
	float haz = 0.0;
	for (int i = 0; i < 10; i++) {
		haz = max(haz, band(length(p - rings[i]), ring));
	}
	for (int i = 0; i < 4; i++) {
		vec2 q = abs(p - boxes[i]);
		haz = max(haz, band(max(q.x, q.y), box));
	}
	float wall = 1e6;
	vec2 along = vec2(1.0, 0.0);
	for (int i = 0; i < 8; i++) {
		float k = walls[i].z - dot(walls[i].xy, p);
		if (k < wall) {
			wall = k;
			along = vec2(-walls[i].y, walls[i].x);
		}
	}
	float lane = band(wall, edge) * band(abs(fract(dot(p, along) / 2.0) - 0.5), vec2(0.15, 1.0));
	float mk = 0.0;
	for (int i = 0; i < 2; i++) {
		vec2 dir = vec2(cos(spawns[i].z), sin(spawns[i].z));
		vec2 q = p - spawns[i].xy;
		float u = dot(q, dir) - 2.0;
		float v = abs(dot(q, vec2(-dir.y, dir.x)));
		mk = max(mk, band(abs(fract((u + v * 0.8) / 0.9) - 0.5), vec2(-1.0, 0.13)) * band(u, vec2(0.0, 2.7)) * band(v, vec2(-1.0, 0.9)));
	}
	float chip = smoothstep(wear - 0.08, wear + 0.08, noise(p * 5.0 + 3.0));
	float st = band(abs(fract((p.x + p.y) / (2.0 * stripe)) - 0.5), vec2(0.25, 1.0));
	float painted = max(haz * st, lane) * chip;
	c = mix(c, black, haz * (1.0 - st) * 0.9);
	c = mix(c, paint, painted);
	c = mix(c, mark, mk * chip * 0.6);
	c *= 1.0 - 0.75 * gap;
	float wet = 0.0;
	float depth = 0.0;
	for (int i = 0; i < 2; i++) {
		vec2 q = p - oils[i].xy;
		if (dot(q, q) < oils[i].z * oils[i].z * 1.21) {
			float in_oil = oils[i].z * (0.92 + 0.16 * fbm(q * 0.8 + float(i) * 7.0)) - length(q);
			wet = max(wet, smoothstep(-0.02, 0.02, in_oil));
			depth = max(depth, clamp(in_oil / 0.4, 0.0, 1.0));
		}
	}
	if (wet > 0.0) {
		vec3 sheen = 0.5 + 0.5 * cos(6.2831 * (depth * 1.5 + fbm(p * 2.0) + vec3(0.0, 0.33, 0.67)));
		c = mix(c, oil + sheen * film * (1.0 - depth), wet);
	}
	ALBEDO = c * (1.15 - 0.35 * smoothstep(0.0, 40.0, length(p - vec2(38.0, 30.0))));
	float gloss = hash(id + 41.0) < polish ? 0.55 : 1.0;
	float coat = max(painted, mk);
	ROUGHNESS = mix(mix(mix(rough.x * gloss, rough.y, grime), 0.65, coat), slick.y, wet);
	METALLIC = mix(mix(metal, 0.15, max(coat, haz)), slick.x, wet);
	vec2 slope = sign(f) * b * tilt * (1.0 - wet);
	vec3 n = normalize(vec3(slope.x, 1.0, slope.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
}
"""

const EMP_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec3 tint : source_color = vec3(0.45, 0.75, 1.0);
uniform float power = 1.0;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec2 q = abs(UV * 2.0 - 1.0);
	float edge = max(smoothstep(0.9, 1.0, q.x), smoothstep(0.8, 1.0, q.y));
	float t = floor(TIME * 15.0);
	float arcs = 0.0;
	for (int i = 0; i < 4; i++) {
		float f = float(i);
		float y = 0.5 + 0.38 * sin(UV.x * (7.0 + f * 3.0) + t * 1.7 + f * 2.1) * h(vec2(t, f));
		arcs += smoothstep(0.035, 0.0, abs(UV.y - y)) * step(0.35, h(vec2(t + 3.0, f)));
	}
	float buzz = 0.6 + 0.4 * h(vec2(t, floor(UV.x * 8.0)));
	ALBEDO = tint * (edge * (0.5 + 0.5 * power) + power * (arcs * 1.4 + 0.14) * buzz + (1.0 - power) * 0.06);
}
"""

const ITEM := {"size": 1.5, "lift": 1.6, "tilt": -0.9, "ring": [0.6, 0.8], "shock": 2.4}
const MARK := {"ring": [0.9, 1.12], "y": 0.1, "dim": 0.3, "alpha": 0.9, "arrow": Vector3(0.75, 0.6, 0.05), "lift": 2.9}
const BLOCK_GAP := 20
const STAND := {"front": 2.4, "depth": 2.6, "base": 1.4, "rise": 1.3, "tiers": 3, "aisle": 0.6}

var crowd: MultiMeshInstance3D
var crowd_mat := ShaderMaterial.new()
var fans := []
var cheer := [0.0, 0.0, 0.0, 0.0]
var hype := 0.0
var hype_tick := 0
var fresh_fx := []
var mechs := []
var squad := 0
var pool := {}
var active := []
var tick := 0
var shake := 0.0
var stop := 0
var slow := 0.0
var marks: Node3D
var towers := []
var pylons := []
var crushers := []
var items := []
var heal_ring: MeshInstance3D
var heal_cross: Node3D
var jets := []
var shocks := []
var emp_mats := [ShaderMaterial.new(), ShaderMaterial.new()]
var cones := {}
var muzzle_off := {}
var pops := []
var replaying := false
var kick := Vector3.ZERO
var reticle: MeshInstance3D
var reticles: Array[MeshInstance3D] = []
var extra_aims: Array = []
var danger: MeshInstance3D
var danger_mesh := ImmediateMesh.new()
var last_shrink := -1.0


func build(siege := false) -> void:
	marks = Node3D.new()
	add_child(marks)
	reticle = Mech.add(self, Mech.ring(0.35, 0.45), Mech.flat(Color(Mech.TEAM_LIGHT[0], 0.8)))
	if siege:
		return
	var S: Dictionary = Look.STAGE
	var we := WorldEnvironment.new()
	we.environment = Look.env()
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_energy = S.key
	sun.light_color = S.key_color
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 110.0
	add_child(sun)
	sun.look_at_from_position(S.key_from, Vector3.ZERO)
	var corners := Sim.arena_corners()
	var mid := Vector3(Sim.CX, 0, Sim.CY)
	for i in [1, 3, 5, 7]:
		var c = corners[i]
		var out := Vector3(c.x - Sim.CX, 0, c.y - Sim.CY).normalized()
		var spot := SpotLight3D.new()
		spot.light_energy = S.spot
		spot.spot_attenuation = 0.6
		spot.spot_range = 120.0
		spot.spot_angle = S.spot_angle
		spot.light_color = S.spot_color
		add_child(spot)
		spot.look_at_from_position(Vector3(c.x, 0, c.y) + out * S.tower_out + Vector3(0, S.tower_height, 0), mid)
		towers.append({"spot": spot, "at": mid, "v": Vector3.ZERO})
	for i in corners.size():
		accent(Vector3(corners[i].x, S.accent_y, corners[i].y).move_toward(mid, S.accent_in), Look.PAL.cyan if i % 2 == 0 else Look.PAL.orange)
	for p in Sim.PILLARS:
		accent(Vector3(p.x, S.accent_y, p.y), Look.PAL.cyan)
	accent(Vector3(Sim.HEAL.x, S.accent_y, Sim.HEAL.y), Look.PAL.cyan)
	for p in Sim.TRAPS.oil.at:
		accent(Vector3(p.x, S.accent_y, p.y), Look.PAL.cyan)
	build_floor(corners)
	Decor.build(self)
	build_walls(corners)
	build_stands(corners)
	for p in Sim.PILLARS:
		var pillar := Mech.add_part(self, "pillar", Look.ARENA, "arena")
		pillar.position = Vector3(p.x, 0, p.y)
		pillar.scale = Vector3(p.r, 1, p.r)
	for p in Sim.TRAPS.tesla.at:
		Mech.add_part(self, "tesla", Look.ARENA, "arena").position = Vector3(p.x, 0, p.y)
		var m: StandardMaterial3D = Look.ARENA.zap.duplicate()
		var top := Mech.add_part(self, "tesla_orb", Look.ARENA.merged({"zap": m}, true), "arena")
		top.position = Vector3(p.x, 2.0, p.y)
		top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pylons.append(m)
	for p in Sim.TRAPS.crush.at:
		var warn: ShaderMaterial = Look.ARENA.hazard.duplicate()
		var hm := Look.ARENA.merged({"hazard": warn}, true)
		Mech.add_part(self, "crush_plate", hm, "arena").position = Vector3(p.x, 0, p.y)
		var piston := Node3D.new()
		add_child(piston)
		Mech.add_part(piston, "crush_head", hm, "arena")
		piston.position = Vector3(p.x, 3.0, p.y)
		crushers.append([piston, warn])
	Mech.add_part(self, "heal_pad", Look.ARENA, "arena").position = Vector3(Sim.HEAL.x, 0, Sim.HEAL.y)
	heal_ring = Mech.add(self, Mech.ring(0.7, 0.95), Mech.glow(Look.PAL.heal, 3.0), Vector3(Sim.HEAL.x, 0.16, Sim.HEAL.y))
	heal_cross = Node3D.new()
	heal_cross.position = Vector3(Sim.HEAL.x, 1.0, Sim.HEAL.y)
	add_child(heal_cross)
	Mech.add(heal_cross, Mech.box(Vector3(0.18, 0.6, 0.18)), Mech.glow(Look.PAL.heal, 4.0))
	Mech.add(heal_cross, Mech.box(Vector3(0.6, 0.18, 0.18)), Mech.glow(Look.PAL.heal, 4.0))
	for p in Sim.PADS:
		Mech.add_part(self, "pad", Look.ARENA, "arena").position = Vector3(p.x, 0, p.y)
		var holder := Node3D.new()
		holder.position = Vector3(p.x, 0, p.y)
		holder.visible = false
		add_child(holder)
		var icon := MeshInstance3D.new()
		icon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		icon.scale = Vector3.ONE * ITEM.size
		holder.add_child(icon)
		var ring := Mech.add(holder, Mech.ring(ITEM.ring[0], ITEM.ring[1]), null, Vector3(0, 0.16, 0))
		items.append({"node": holder, "icon": icon, "ring": ring, "kind": ""})
	for g in Sim.vents(0.0):
		var vent := Mech.add_part(self, "vent", Look.ARENA, "arena")
		vent.position = Vector3(g.x, 0, g.y)
		vent.rotation.y = -atan2(g.dy, g.dx)
		var jet := Mech.add(self, Mech.plane(), emp_mats[0])
		jet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		jet.visible = false
		jets.append(jet)
	var sh := Shader.new()
	sh.code = EMP_SHADER
	for k in 2:
		emp_mats[k].shader = sh
		emp_mats[k].set_shader_parameter("power", float(k))
	danger = MeshInstance3D.new()
	danger.mesh = danger_mesh
	danger.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(danger)


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
	var sm := Look.shader(FLOOR_SHADER, Look.FLOOR)
	sm.set_shader_parameter("rings", PackedVector2Array((Sim.PADS + Sim.SPAWNS).map(func(o): return Vector2(o.x, o.y))))
	sm.set_shader_parameter("boxes", PackedVector2Array(Sim.TRAPS.crush.at.map(func(o): return Vector2(o.x, o.y))))
	sm.set_shader_parameter("walls", PackedVector3Array(Sim.WALLS.map(func(w): return Vector3(w.nx, w.ny, w.d))))
	sm.set_shader_parameter("spawns", PackedVector3Array(Sim.SPAWNS.map(func(o): return Vector3(o.x, o.y, o.aim))))
	sm.set_shader_parameter("oils", PackedVector3Array(Sim.TRAPS.oil.at.map(func(o): return Vector3(o.x, o.y, Sim.TRAPS.oil.r))))
	var floor := MeshInstance3D.new()
	floor.mesh = st.commit()
	floor.material_override = sm
	add_child(floor)
	var night := StandardMaterial3D.new()
	night.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	night.albedo_color = Look.PAL.void
	Mech.add(self, Mech.box(Vector3(400, 0.1, 400)), night, Vector3(Sim.CX, -0.08, Sim.CY))


func accent(at: Vector3, c: Color) -> void:
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = Look.STAGE.accent
	l.omni_range = Look.STAGE.accent_range
	l.position = at
	add_child(l)


func edge(corners: Array, i: int) -> Array:
	var n := corners.size()
	var a = corners[(i + n - 1) % n]
	var b = corners[i]
	return [Vector3(a.x, 0, a.y), Vector3(b.x, 0, b.y), Vector3(Sim.WALLS[i].nx, 0, Sim.WALLS[i].ny)]


func build_walls(corners: Array) -> void:
	for i in Sim.WALLS.size():
		var e := edge(corners, i)
		var a: Vector3 = e[0]
		var b: Vector3 = e[1]
		var nrm: Vector3 = e[2]
		var dir := (b - a).normalized()
		if dir.cross(Vector3.UP).dot(nrm) < 0:
			dir = -dir
		var basis := Basis(dir, Vector3.UP, dir.cross(Vector3.UP))
		var count := maxi(1, roundi(a.distance_to(b) / 4.0))
		var step := a.distance_to(b) / count
		for k in count:
			var panel := Mech.add_part(self, "wall", Look.ARENA, "arena")
			panel.transform = Transform3D(basis.scaled_local(Vector3(step / 4.0, 1, 1)), a.lerp(b, (k + 0.5) / count))
		Mech.add_part(self, "wall_post", Look.ARENA, "arena").position = b + nrm * 0.15


func build_stands(corners: Array) -> void:
	Mech.add_part(self, "stadium", Look.ARENA, "arena")
	Mech.add_part(self, "tower", Look.ARENA, "arena").cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
		for k in STAND.tiers:
			var off: float = STAND.front + k * STAND.depth
			var h: float = STAND.base + k * STAND.rise
			var face := dir if dir.cross(Vector3.UP).dot(nrm) > 0 else -dir
			var basis := Basis(face, Vector3.UP, face.cross(Vector3.UP))
			for row in CROWD.rows:
				var o: float = off + row
				var span := a.distance_to(b) + 2.0 * o * 0.414 - 0.8
				var mid: Vector3 = (a + b) / 2.0 + nrm * o + Vector3(0, h, 0)
				for j in int(span / CROWD.gap):
					var along := (j + 0.5) * CROWD.gap - span / 2.0 + rng.randf_range(-0.08, 0.08)
					if rng.randf() < CROWD.empty or absf(along) < STAND.aisle + 0.2:
						continue
					var pos := mid + dir * along
					var neutral := -1 if rng.randf() >= CROWD.neutral else rng.randi_range(4, 7)
					spots.append([Transform3D(basis.scaled(Vector3.ONE * rng.randf_range(0.9, 1.12)), pos), neutral, Color(rng.randf() * TAU, 0, rng.randf_range(0.75, 1.15), rng.randi_range(0, 3))])
	mm.use_custom_data = true
	mm.instance_count = spots.size()
	for i in spots.size():
		mm.set_instance_transform(i, spots[i][0])
	fans = spots
	mm.mesh = Mech.models("arena")["fan"][0]
	crowd_mat.shader = Shader.new()
	crowd_mat.shader.code = CROWD_SHADER
	var lin := func(cs: Array) -> PackedVector3Array:
		var out := PackedVector3Array()
		for c in cs:
			var l: Color = c.srgb_to_linear()
			out.append(Vector3(l.r, l.g, l.b))
		return out
	crowd_mat.set_shader_parameter("shirts", lin.call(Mech.TEAM + CROWD.neutrals))
	crowd_mat.set_shader_parameter("skins", lin.call(CROWD.skins))
	crowd = MultiMeshInstance3D.new()
	crowd.multimesh = mm
	crowd.material_override = crowd_mat
	crowd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	crowd.extra_cull_margin = 1.0
	add_child(crowd)
	seat_fans(2)


## Who each fan roots for: the team on their side of the arena (like the JS sideOf).
func seat_fans(sides: int) -> void:
	var mm := crowd.multimesh
	for i in fans.size():
		var p: Vector3 = fans[i][0].origin
		var slot: int = fans[i][1]
		if slot < 0:
			slot = (0 if p.x < Sim.CX else 1) if sides <= 2 else ((0 if p.z < Sim.CY else 3) if p.x < Sim.CX else (2 if p.z < Sim.CY else 1))
		var c: Color = fans[i][2]
		mm.set_instance_custom_data(i, Color(c.r, slot, c.b, c.a))


## Fans of every team but the hurt one cheer for big moments; a wild crowd cheers for everyone.
func react(state: Dictionary, fresh: Array) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	fresh_fx.append_array(fresh)
	hype =Hype.next(hype, state, fresh, (state.tick - hype_tick) / float(Sim.TICKS))
	hype_tick = state.tick
	for f in fresh:
		var t := Hype.cheer_for(f)
		if t > 0.0:
			var hurt := team_of(state, f.get("id"))
			for i in 4:
				if i != hurt:
					cheer[i] = maxf(cheer[i], now + t)
	if Hype.mood(hype) == 2:
		for i in 4:
			cheer[i] = maxf(cheer[i], now + 0.3)
	var on := PackedFloat32Array()
	for i in 4:
		on.append(1.0 if cheer[i] > now else 0.0)
	crowd_mat.set_shader_parameter("cheer", on)


func reset(state: Dictionary) -> void:
	squad = state.siege.team if state.has("siege") else 0
	pops.clear()
	for r in reticles:
		r.queue_free()
	reticles.clear()
	for m in mechs:
		for g in m.get_meta("ghosts", []):
			g.queue_free()
		m.queue_free()
	mechs.clear()
	for m in state.mechs:
		if m.has("bot"):
			continue
		var node := Mech.new()
		add_child(node)
		node.build(m.loadout, m.team)
		node.smoke = Fx.wreck(node)
		mark(node, m)
		mechs.append(node)
	for n in active:
		n.visible = false
		pool[n.get_meta("kind")].append(n)
	active.clear()
	for c in marks.get_children():
		c.queue_free()
	var teams := {}
	for m in state.mechs:
		teams[m.team] = true
	if crowd != null:
		seat_fans(teams.size())
	hype = 0.0
	hype_tick = state.tick
	cheer = [0.0, 0.0, 0.0, 0.0]
	for i in towers.size():
		var m = state.mechs[i % state.mechs.size()]
		towers[i].at = Vector3(m.x, Look.STAGE.aim_y, m.y)
		towers[i].v = Vector3.ZERO
	follow(state, 0.0)


func remake(i: int, m: Dictionary, by: int) -> void:
	var old: Node3D = mechs[i]
	for g in old.get_meta("ghosts", []):
		g.queue_free()
	for k in old.get_meta("marks", []):
		if k is Node:
			k.queue_free()
	old.queue_free()
	var node := Mech.new()
	add_child(node)
	node.build(m.loadout, m.team)
	node.smoke = Fx.wreck(node)
	mark(node, m, by)
	node.set_meta("guard", m.guard)
	mechs[i] = node


## Team markers: a ring on the floor, an arrow over the head and a rim on the edges, all in the team color.
func mark_color(m: Dictionary) -> Color:
	return Look.ARCADE.team[m.id] if m.id < squad and m.id < 4 else Mech.TEAM[m.team]


func mark(node: Node3D, m: Dictionary, by := -1) -> void:
	var tc: Color = Look.ARCADE.team[by] if by >= 0 and by < 4 else mark_color(m)
	var c := Mech.flat(Color(tc.darkened(MARK.dim), MARK.alpha))
	var tri := PrismMesh.new()
	tri.size = MARK.arrow
	var ring := Mech.add(node, Mech.ring(MARK.ring[0], MARK.ring[1]), c)
	var arrow := Mech.add(node, tri, c, Vector3.ZERO, Vector3(-PI / 3.0, 0, PI))
	for k in [ring, arrow]:
		k.top_level = true
	place_marks([ring, arrow], m)
	ring.reset_physics_interpolation()
	arrow.reset_physics_interpolation()
	var rim := Look.shader(Look.RIM_SHADER, Look.RIM.merged({"color": tc}))
	if DisplayServer.get_name() != "headless":
		for p in node.find_children("*", "MeshInstance3D", true, false):
			if p.material_override == null:
				p.material_overlay = rim
	node.set_meta("marks", [ring, arrow, rim])


func place_marks(marks_of: Array, m: Dictionary) -> void:
	marks_of[0].position = Vector3(m.x, MARK.y, m.y)
	marks_of[1].position = Vector3(m.x, Sim.height_of(m) + MARK.lift, m.y)


func follow(state: Dictionary, dt: float) -> void:
	var w: float = Look.STAGE.follow
	for i in towers.size():
		var t: Dictionary = towers[i]
		var m = state.mechs[i % state.mechs.size()]
		var goal := Vector3(m.x, Look.STAGE.aim_y, m.y)
		t.v = t.v + (w * w * (goal - t.at) - 2.0 * Look.STAGE.damp * w * t.v) * dt
		t.at = t.at + t.v * dt
		t.spot.look_at(t.at)


func team_of(state: Dictionary, id) -> int:
	return state.mechs[id].team if id != null and id >= 0 and id < state.mechs.size() else 0


func shooter_color(state: Dictionary, f: Dictionary) -> Color:
	if state.score.size() == 2:
		return Mech.TEAM[1 - team_of(state, f.id)]
	return Color8(255, 210, 120)


func sync(state: Dictionary, aim: Vector3, dt: float) -> void:
	tick += 1
	muzzle_off.clear()
	follow(state, dt)
	for i in mechs.size():
		var sm0 = state.mechs[i]
		if sm0.has("guard") and mechs[i].get_meta("guard", -1) != sm0.guard:
			remake(i, sm0, state.siege.garrison.buyer)
		mechs[i].visible = not sm0.get("absent", false)
		mechs[i].sync(state.mechs[i], tick, dt)
		if shocks.size() <= i:
			shocks.append(Mech.add(self, Mech.plane(), emp_mats[1]))
			shocks[i].cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			shocks[i].scale = Vector3.ONE * ITEM.shock
		var sm = state.mechs[i]
		shocks[i].visible = sm.buffs.slow > 2 and not sm.ko
		shocks[i].position = Vector3(sm.x, 0.06, sm.y)
		var marks_of: Array = mechs[i].get_meta("marks")
		var seen := not Sim.hidden(state, sm)
		place_marks(marks_of, sm)
		marks_of[0].visible = seen and not replaying
		marks_of[1].visible = seen and not sm.ko and not replaying and not sm.has("guard")
		marks_of[2].set_shader_parameter("strength", Look.RIM.strength if seen else 0.0)
		var act = state.mechs[i].act
		if act != null and act.k == "dash" and act.get("ph") == "go" and not sm.ko:
			if tick % Fx.DASH.every == 0:
				Fx.ghost(self, mechs[i], Mech.TEAM[sm.team])
			Fx.lines(self, mechs[i].position, Vector2(act.dx, act.dy))
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
	reticle.visible = state.phase == "fight" and not state.mechs[0].ko and not replaying
	while reticles.size() < extra_aims.size():
		reticles.append(Mech.add(self, Mech.ring(0.35, 0.45), Mech.flat(Color(Mech.TEAM_LIGHT[state.mechs[reticles.size() + 1].team], 0.8))))
	for i in reticles.size():
		reticles[i].visible = i < extra_aims.size() and state.phase == "fight" and not state.mechs[i + 1].ko and not replaying
		if i < extra_aims.size():
			reticles[i].position = extra_aims[i] + Vector3(0, 0.05, 0)
	var fresh := []
	for f in state.fx:
		if not f.has("seen"):
			f["seen"] = true
			fresh.append(f)
			spawn(state, f)
	react(state, fresh)
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
		var k := fmod(tick * Fx.FIELD.pulse, 1.0)
		var s := 1.0 - k if f.kind == "well" else k
		var gone := 1.0 - clampf(f.t / 30.0, 0.0, 1.0)
		n.get_child(0).transparency = gone
		n.get_child(1).transparency = gone
		n.get_child(2).scale = Vector3(s, 1, s)
		n.get_child(2).transparency = maxf(gone, 1.0 - sin(PI * k))
		settle(n)
	for tr in state.trails:
		trail(state, tr)
	for w in state.walls:
		var n := node_for(w, "wall")
		var d := Vector2(w.x2 - w.x1, w.y2 - w.y1)
		n.position = Vector3((w.x1 + w.x2) / 2.0, 1.1, (w.y1 + w.y2) / 2.0)
		n.rotation = Vector3(0, -d.angle(), 0)
		n.scale = Vector3(d.length(), 1, 1)
		n.material_override = Mech.glow(Color8(255, 240, 120), 2.0, 0.55) if w.get("zap", false) else Mech.flat(Color(Mech.TEAM[team_of(state, w.owner)].darkened(MARK.dim), 0.6))
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
	if not state.has("siege"):
		arena(state)


func guard(m: Dictionary, node) -> void:
	var was: float = node.get_meta("soaked", 0.0)
	var got: float = m.act.get("absorbed", 0.0) if Sim.shield_up(m) else 0.0
	if got > was:
		Fx.ripple(self, node.shield.global_transform, got - was, false)
		if tick - node.get_meta("blocked", -BLOCK_GAP) >= BLOCK_GAP:
			node.set_meta("blocked", tick)
			number(Vector3(m.x, 2.3, m.y), tr("blocked"), "block")
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
			Mech.add(n, Mech.ball(0.12, 8), Mech.flat(Color8(255, 60, 40), true), Vector3(0, 0.1, 0))
		"field_stasis", "field_well":
			var c: Color = Fx.FIELD[kind.substr(6)]
			n = Node3D.new()
			add_child(n)
			Mech.add(n, Mech.cyl(1.0, 1.0, 0.02, 32), Mech.flat(Color(c, Fx.FIELD.fill), true))
			Mech.add(n, Mech.ring(0.95, 1.0), Mech.flat(c, true))
			Mech.add(n, Mech.ring(0.9, 1.0), Mech.flat(Color(1, 1, 1, Fx.FIELD.inner), true))
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
			Mech.add(n, Mech.box(Vector3(1, 0.08, 0.4)), Mech.flat(Color(1, 1, 1, 0.85), true), Vector3(0, 1.1, 0))
		_:
			n = Mech.add(self, Mech.box(Vector3(1, 1, 1)), null)
	return n


func barrel(state: Dictionary, id, gun: String, hand := "") -> Variant:
	if typeof(id) != TYPE_INT or id < 0 or id >= mechs.size():
		return null
	var m = state.mechs[id]
	if hand == "":
		for h in Sim.HANDS:
			if m.loadout[h] == gun and (hand == "" or (m.act != null and m.act.k == h)):
				hand = h
	if hand == "":
		return null
	return to_local(mechs[id].barrel(hand))


func cone(state: Dictionary, id: int, shots: Array) -> void:
	if not cones.has(id):
		cones[id] = Fx.flame_cone(self)
	var C := Fx.CONE
	var m = state.mechs[id]
	var tip = barrel(state, id, "flamer")
	var o := Vector2(tip.x, tip.z) if tip != null else Vector2(m.x, m.y)
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
	if n.get_meta("fresh"):
		n.set_meta("off", Vector2.ZERO if kind == "hook" else muzzle_off.get(s.owner, Vector2.ZERO))
		n.set_meta("from", Vector2(s.x, s.y))
	var off: Vector2 = n.get_meta("off") * clampf(1.0 - (Vector2(s.x, s.y) - n.get_meta("from")).length() / BLEND, 0.0, 1.0)
	n.position = Vector3(s.x + off.x, 1.05, s.y + off.y)
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
	if n.get_meta("fresh"):
		n.set_meta("off", muzzle_off.get(l.get("owner", -1), Vector2.ZERO))
	var off: Vector2 = n.get_meta("off")
	n.position = Vector3(l.x, 0.06, l.y)
	var p: float = 1.0 - float(l.t) / float(l.T)
	n.get_child(0).scale = Vector3(l.r, 1, l.r)
	n.get_child(1).scale = Vector3(l.r * p, 1, l.r * p)
	var shell: MeshInstance3D = n.get_child(2)
	shell.visible = l.kind != "decoy"
	var arc := 7.0 if l.kind == "shell" else 14.0
	var from := Vector3(l.sx - l.x + off.x, 1.1, l.sy - l.y + off.y)
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
		pylons[i].emission_energy_multiplier = (2.0 + 4.0 * absf(sin(tick * 0.5))) if u <= Z.warn else Look.NEON.cyan
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
		crushers[i][1].set_shader_parameter("warn", (2.0 + 2.0 * sin(tick * 0.6)) if warn else 0.0)
	heal_ring.transparency = 0.0 if state.heal.ready else 0.75
	heal_cross.visible = state.heal.ready
	heal_cross.rotation.y += 0.03
	for i in items.size():
		var kind = state.pads[i]
		var it: Dictionary = items[i]
		it.node.visible = kind != null
		if kind == null:
			continue
		if it.kind != kind:
			it.kind = kind
			var c: Color = item_color(kind)
			it.icon.mesh = Mech.models("arena")["item_" + kind][0]
			for k in it.icon.mesh.get_surface_count():
				var mn: String = it.icon.mesh.surface_get_material(k).resource_name
				it.icon.set_surface_override_material(k, Mech.glow(c, 1.6) if mn == "icon" else Look.ARENA[mn])
			it.ring.material_override = Mech.glow(c, 2.0)
		it.icon.position.y = ITEM.lift + 0.12 * sin(tick * 0.06 + i)
		it.icon.rotation = Vector3(ITEM.tilt, 0.3 * sin(tick * 0.03 + i), 0)
	var v = Sim.vent_phase(state)
	var list := Sim.vents(state.shrink)
	for i in jets.size():
		var g = list[i]
		var on: bool = v != null and (v.burn or v.warn) and g.wall % 2 == v["set"]
		var jet: MeshInstance3D = jets[i]
		jet.visible = on
		if on:
			var reach: float = Sim.HAZARDS.reach
			jet.position = Vector3(g.x + g.dx * reach / 2.0, 0.04, g.y + g.dy * reach / 2.0)
			jet.rotation = Vector3(0, -atan2(g.dy, g.dx), 0)
			jet.scale = Vector3(reach, 1, Sim.HAZARDS.half * 2.0)
			jet.material_override = emp_mats[1 if v.burn else 0]
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








func number(p: Vector3, text: String, kind: String) -> void:
	pops.append({"p": p, "text": text, "k": kind, "at": tick})






func spawn(state: Dictionary, f: Dictionary) -> void:
	var p := Vector3(f.get("x", 0.0), 1.0, f.get("y", 0.0))
	match f.k:
		"hit":
			var head: bool = f.get("head", false)
			Fx.hit(self, f, shooter_color(state, f))
			number(p + Vector3(0, 1.3, 0), str(int(f.n)), "head" if head else "hit")
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
			var g := f.duplicate()
			var b = barrel(state, f.id, f.gun, f.hand)
			if b != null:
				muzzle_off[f.id] = Vector2(b.x - f.x, b.z - f.y)
				g.x = b.x
				g.y = b.z
				g["h"] = b.y
			Fx.muzzle(self, g, Mech.TEAM[team_of(state, f.id)])
		"zap":
			var g := f
			if f.has("id") and f.kind in ["laser", "tesla"]:
				var m = state.mechs[f.id]
				var b = barrel(state, f.id, f.kind)
				if b != null and (f.kind == "laser" or Vector2(f.x1 - m.x, f.y1 - m.y).length() < 0.5):
					g = f.duplicate()
					g.x1 = b.x
					g.y1 = b.z
			if f.kind == "laser":
				Fx.ray(self, g, 0.35, "laser", 0.16)
			else:
				Fx.arc(self, g)
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
		"heal", "pickup", "pulse":
			Fx.heal(self, f)
			if f.k == "heal":
				number(p + Vector3(0, 1.3, 0), "+%d" % int(f.n), "heal")
		"hooked":
			Fx.hooked(self, f, Mech.TEAM[team_of(state, f.by)])
		"soak":
			Fx.soak(self, f)
		"brace":
			Fx.brace(self, f)
		"cleanse":
			Fx.cleanse(self, f)
		"focus":
			Fx.focused(self, f)
		"xray", "frost", "arcwall", "trap":
			Fx.cast(self, f)
		"magnet":
			Fx.magnet(self, f)
		"crush":
			Fx.crush(self, marks, f)
			shake = maxf(shake, 0.3)
		"ping":
			Fx.ping(self, f)
		"charge":
			Fx.charge(self, f, Mech.TEAM[team_of(state, f.id)])
		"ult":
			Fx.ult(self, f, Mech.TEAM[team_of(state, f.id)])
			shake = maxf(shake, Fx.ULT.shake)
