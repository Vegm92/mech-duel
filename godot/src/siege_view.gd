extends Node3D

const Sim = preload("res://src/sim.gd")
const Mech = preload("res://src/mech.gd")
const Fx = preload("res://src/fx.gd")
const Look = preload("res://src/look.gd")
const View = preload("res://src/view.gd")
const Decor = preload("res://src/decor.gd")
const SiegeState = preload("res://src/siege_state.gd")

const HALF := SiegeState.HALF
const W := SiegeState.LANE_W / 2.0
const STATIC := ["markers", "markings", "fortress", "plaza", "stands"]
const PARTS := ["markers", "markings", "fortress", "plaza", "stands", "yard_floor", "yard_arch", "core_base", "core_crystal",
	"ring1", "ring2", "ring3", "ring4", "gate", "gate_light", "gate_door", "gate_broken", "spawn_gate", "spawn_light",
	"mod_wall", "mod_mine", "flood_tower", "crate", "crate_lid", "camp_ring", "camp_pip", "work_light", "heap", "crane",
	"steam_grate", "dock", "dock_lamp", "parts_bay"]
const DUEL := ["wall", "wall_post", "pillar", "vent", "crush_plate", "crush_head", "tesla", "tesla_orb", "fan"]
const JUNK := [["guns", "rivet"], ["guns", "gatling"], ["guns", "mortar"], ["guns", "saw"], ["guns", "missiles"], ["guns", "hammer"],
	["arms", "anvil_fore_R"], ["arms", "bulwark_upper_L"], ["arms", "brace_fore_L"], ["heads", "rookie"], ["heads", "demon"],
	["heads", "visor"], ["legs", "stompers_leg_L"], ["legs", "greaves_leg_R"], ["cores", "titan"], ["light", "Chest_standard"]]
const CORE := {"y": 4.3, "spin": 0.35, "bob": 0.12, "glow": 1.6, "flicker": 0.5, "smoke": 0.25, "smoke_size": 2.2,
	"rings": [3.3, 3.9, 4.5, 5.1], "ring_spin": [0.25, -0.35, 0.45, -0.6], "light": 8.0, "light_range": 12.0,
	"mend": [4.8, 5.2], "mend_y": 0.5}
const GATE := {"sink": 2.4, "ease": 0.12, "bar_y": 5.0, "bar": 0.22, "width": 10.0}
const WARN := {"secs": 8, "on": 1.6, "steady": 0.6, "blink": 10}
const WALL := {"panel": 4.0, "post": 0.15, "vent": 0.7, "spawn": 8.4}
const STAND := {"front": 2.4, "depth": 2.6, "base": 1.4, "rise": 1.3, "tiers": 3, "rows": [0.65, 1.95], "gap": 9.0,
	"aisle": 40.0, "aisle_w": 0.4, "fan_gap": 0.6, "team": 1}
const TOWER := {"out": 94.0, "head": Vector3(0.4, 17.8, 0), "angle": 5.0, "range": 240.0, "energy": 2.0, "aim": 30.0}
const YARD := {"rust": 0.5, "warm": 0.15, "dirt": 0.95, "tint": 0.45, "polish": 0.1, "tiers": {"small": 1, "medium": 2, "big": 3, "elite": 4},
	"size": {"small": 0.8, "medium": 1.0, "big": 1.2, "elite": 1.5}, "pip": 3.6, "pip_gap": 0.6, "alive": 0.75, "dead": 0.06,
	"wake": 2.0, "ring": 1.6, "segs": 16, "lid": 1.17, "lift": 0.3, "lights": [[30.0, -1.0, 0.0, 1.0], [-1.0, 30.0, 1.0, 0.0], [52.0, -1.0, 0.0, 1.0], [-1.0, 54.0, 1.0, 0.0], [60.0, 80.0, 0.0, -1.0], [80.0, 60.0, -1.0, 0.0]],
	"raid": 6,
	"wall_top": 1.3, "crate_h": 1.24, "light": 3.0, "light_range": 16.0, "light_energy": 8.0,
	"debris": 22, "sheet": Vector3(2.0, 0.05, 1.4), "pallet": Vector3(1.2, 0.14, 1.0), "crane": 85.0, "crane_y": 4.0,
	"scorch": 8, "scorch_r": Vector2(1.0, 2.0), "grime": 1.2}
const STEAM := {"amount": 40, "life": 3.0, "size": 2.4, "y": 0.4, "alpha": 0.45}
const DOCK := {"lamps": [-1.2, -0.6, 0.0, 0.6, 1.2], "lamp": Vector2(0.9, 4.45), "on": 1.4, "off": 0.04, "beam": Vector2(1.4, 4.0)}
const BAY_AT := {"x": 0.0, "y": -8.0, "face": PI / 2.0}
const BAY := {"size": 1.8, "idle": 0.75, "open": 2.2, "light": 2.0, "spin": 0.5, "pulse": [2.0, 4.0, 0.3],
	"items": [["heads", "visor", Vector3(0.35, 1.7, -1.28)], ["arms", "brace_fore_R", Vector3(0.35, 2.0, 1.28)], ["guns", "rivet", Vector3(1.15, 1.6, 0)]]}
const RECALL := {"r": 1.0, "h": 6.0, "core": 0.25, "ring": 1.6, "segs": 24, "alpha": 0.3, "done": 0.95, "land": Vector3(0, 1.5, 0), "flash": [3.0, 8.0, 0.4]}
const VIGNETTE := "smoothstep(0.0, 40.0, length(p - vec2(38.0, 30.0)))"
const EMP_EDGE := "float edge = max(smoothstep(0.9, 1.0, q.x), smoothstep(0.8, 1.0, q.y));"

static var MATS := Look.ARENA.merged({
	"white": Look.neon(Color(0.85, 0.92, 1.0), Look.NEON.cyan),
	"crystal": Mech.glow(Color(0.6, 0.9, 1.0), CORE.glow),
	"shield": Look.neon(Look.PAL.cyan, 1.2),
	"pylon": Look.neon(Look.PAL.cyan, Look.NEON.cyan),
	"warn": Look.neon(Look.PAL.warn, 0.0),
	"paint": Look.paint("hazard", Look.PAL.hazard),
	"mark": Look.paint("painted", Look.PAL.steel_hi),
	"rust": Look.paint("painted", Look.PAL.grime.lerp(Look.PAL.orange, 0.3)),
	"yard": Look.ARENA.dark,
	"counter": Look.neon(Look.PAL.cyan, Look.NEON.cyan),
})
static var JUNK_MATS := {
	"body": MATS.rust, "trim": Look.paint("gunmetal", Look.PAL.gunmetal), "joint": Look.paint("gunmetal", Look.PAL.void),
}
static var DISPLAY := {"body": MATS.steel, "trim": MATS.trim, "joint": MATS.dark, "gem": MATS.strip, "glow": MATS.strip, "core": MATS.strip, "boost": MATS.strip}
static var CYAN_LAMPS := MATS.merged({"amber": MATS.strip}, true)

var crystal: MeshInstance3D
var crystal_mat: StandardMaterial3D
var core_light: OmniLight3D
var rings := []
var ring_up := []
var smoke: CPUParticles3D
var mend: MeshInstance3D
var spawns := []
var gates := []
var pads := []
var tick := 0
var crowd: MultiMeshInstance3D
var fans := []
var crowd_mat: ShaderMaterial
var towers := []
var camps := []
var crates := []
var dock := {}
var raids := []
var bay := {}
var recalls := {}


static func dir(lane: int) -> Vector3:
	return Vector3(SiegeState.LANES[lane].dx, 0, SiegeState.LANES[lane].dy)


static func yaw(lane: int) -> float:
	return -atan2(SiegeState.LANES[lane].dy, SiegeState.LANES[lane].dx)


static func yard(q: int, a: float, b: float, y := 0.0) -> Vector3:
	var p := SiegeState.yard_at(q, a, b)
	return Vector3(p.x, y, p.y)


static func contract(key: String, fallback: Variant) -> Variant:
	return (load("res://src/siege_state.gd") as Script).get_script_constant_map().get(key, fallback)


static func facing(fwd: Vector3) -> Basis:
	return Basis(fwd, Vector3.UP, fwd.cross(Vector3.UP))


func build(env := true, shared: ShaderMaterial = null) -> void:
	if env:
		var we := WorldEnvironment.new()
		we.environment = Look.env()
		add_child(we)
		var sun := DirectionalLight3D.new()
		sun.light_energy = Look.STAGE.key
		sun.light_color = Look.STAGE.key_color
		sun.shadow_enabled = true
		sun.directional_shadow_max_distance = 160.0
		add_child(sun)
		sun.look_at_from_position(Look.STAGE.key_from, Vector3.ZERO)
	var ground := floor_mat({})
	var night := StandardMaterial3D.new()
	night.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	night.albedo_color = Look.PAL.void
	Mech.add(self, Mech.plane(), ground).scale = Vector3(HALF * 2 + 2, 1, HALF * 2 + 2)
	Mech.add(self, Mech.box(Vector3(800, 0.1, 800)), night, Vector3(0, -0.08, 0))
	var rust := floor_mat({"base": Look.PAL.steel.lerp(Look.PAL.grime, YARD.rust).lerp(Look.PAL.orange, YARD.warm), "dirt": YARD.dirt, "tint": YARD.tint, "polish": YARD.polish})
	Mech.add_part(self, "yard_floor", MATS.merged({"yard": rust}, true), "core_siege")
	for p in STATIC:
		Mech.add_part(self, p, MATS, "core_siege")
	build_core()
	build_walls()
	build_props()
	build_crowd(shared)
	build_towers()
	build_yards()
	build_dock()
	build_bay()


func floor_mat(knobs: Dictionary) -> ShaderMaterial:
	var sm := Look.shader(View.FLOOR_SHADER.replace(VIGNETTE, "smoothstep(0.0, 90.0, length(p))"), Look.FLOOR.merged(knobs, true))
	var far := Vector2(1e4, 1e4)
	sm.set_shader_parameter("rings", PackedVector2Array(range(10).map(func(_i): return far)))
	sm.set_shader_parameter("boxes", PackedVector2Array(range(4).map(func(_i): return far)))
	sm.set_shader_parameter("walls", PackedVector3Array(range(8).map(func(i): return Vector3(SiegeState.LANES[i % 4].dx, SiegeState.LANES[i % 4].dy, HALF))))
	sm.set_shader_parameter("spawns", PackedVector3Array([Vector3(1e4, 1e4, 0), Vector3(1e4, 1e4, 0)]))
	sm.set_shader_parameter("oils", PackedVector3Array([Vector3(1e4, 1e4, 0), Vector3(1e4, 1e4, 0)]))
	return sm


func build_core() -> void:
	Mech.add_part(self, "core_base", MATS, "core_siege")
	crystal_mat = MATS.crystal.duplicate()
	crystal = Mech.add_part(self, "core_crystal", MATS.merged({"crystal": crystal_mat}, true), "core_siege")
	crystal.position.y = CORE.y
	crystal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for k in 4:
		var r := Mech.add_part(self, "ring%d" % (k + 1), MATS, "core_siege")
		r.position.y = CORE.rings[k]
		r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rings.append(r)
	core_light = accent(Vector3(0, CORE.y, 0), Look.PAL.cyan)
	core_light.omni_range = CORE.light_range
	smoke = Fx.wreck(self)
	smoke.position = Vector3(0, CORE.y, 0)
	smoke.scale = Vector3.ONE * CORE.smoke_size
	mend = Mech.add(self, Mech.ring(CORE.mend[0], CORE.mend[1]), Mech.flat(Color(Look.PAL.heal, 0.8), true), Vector3(0, CORE.mend_y, 0))
	mend.scale.y = 0.05
	mend.visible = false
	for i in 4:
		var n := Node3D.new()
		n.position = dir(i) * HALF
		n.rotation.y = yaw(i)
		add_child(n)
		Mech.add_part(n, "spawn_gate", MATS, "core_siege")
		var m: StandardMaterial3D = MATS.warn.duplicate()
		Mech.add_part(n, "spawn_light", MATS.merged({"warn": m}, true), "core_siege").cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		spawns.append(m)
		accent(dir(i) * (SiegeState.RING_OUT + 3.0) + Vector3(0, Look.STAGE.accent_y, 0), Look.PAL.cyan)
		for c in SiegeState.CHOKES:
			accent(dir(i) * c + Vector3(0, Look.STAGE.accent_y, 0), Look.PAL.cyan)


func batch(file: String, part: String, xf: Array, mats: Dictionary = MATS) -> MultiMeshInstance3D:
	var src: Mesh = Mech.models(file)[part][0]
	var mesh: Mesh = src.duplicate()
	for i in mesh.get_surface_count():
		mesh.surface_set_material(i, mats[src.surface_get_material(i).resource_name])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	add_child(mi)
	return mi


func run(panels: Array, a: Vector3, b: Vector3, out: Vector3) -> void:
	var count := maxi(1, roundi(a.distance_to(b) / WALL.panel))
	var basis := Basis(Vector3.UP.cross(out), Vector3.UP, out)
	for k in count:
		panels.append(Transform3D(basis.scaled_local(Vector3(a.distance_to(b) / count / WALL.panel, 1, 1)), a.lerp(b, (k + 0.5) / count)))


func cuts(r0: float, r1: float, holes: Array) -> Array:
	var out := []
	var r := r0
	for h in holes:
		if h[0] > r:
			out.append([r, h[0]])
		r = maxf(r, h[1])
	if r1 > r:
		out.append([r, r1])
	return out


func build_walls() -> void:
	var cyan := []
	var amber := []
	var posts := []
	var lane_posts := []
	var stacks := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for q in SiegeState.QUADS.size():
		posts.append(Transform3D(Basis(), yard(q, HALF + WALL.post, HALF + WALL.post)))
	for i in 4:
		var d := dir(i)
		var p := Vector3(-d.z, 0, d.x)
		for s in [-1.0, 1.0]:
			run(amber, d * HALF + p * s * WALL.spawn, d * HALF + p * s * HALF, d)
			posts.append(Transform3D(Basis(), d * (HALF + WALL.post) + p * s * WALL.spawn))
			lane_posts.append(Transform3D(Basis(), d * SiegeState.BLOCK + p * s * (W + SiegeState.LANE_WALL / 2.0)))
		var holes := SiegeState.CHOKES.map(func(c): return [c - SiegeState.CHOKE_R, c + SiegeState.CHOKE_R])
		holes += SiegeState.VENTS.map(func(v): return [v - WALL.vent, v + WALL.vent])
		holes.sort_custom(func(x, y): return x[0] < y[0])
		for s in [-1.0, 1.0]:
			for seg in cuts(SiegeState.BLOCK, HALF, holes):
				run(cyan, d * seg[0] + p * s * W, d * seg[1] + p * s * W, p * s)
				run(amber, d * seg[0] + p * s * (W + SiegeState.LANE_WALL), d * seg[1] + p * s * (W + SiegeState.LANE_WALL), -p * s)
				var r: float = seg[0] + rng.randf_range(2.0, 6.0)
				while r < seg[1] - 1.5:
					var base := Basis.from_euler(Vector3(0, yaw(i) + rng.randf_range(-0.15, 0.15), 0))
					for k in rng.randi_range(1, 3):
						stacks.append(Transform3D(base.rotated(Vector3.UP, rng.randf_range(-0.2, 0.2)), d * r + p * s * (W + SiegeState.LANE_WALL / 2.0) + Vector3(0, YARD.wall_top + k * YARD.crate_h, 0)))
					r += rng.randf_range(5.0, 11.0)
	for q in SiegeState.QUADS.size():
		for face in [[SiegeState.BLOCK, 1.0, cyan], [SiegeState.YARD_IN, -1.0, amber]]:
			var r: float = face[0]
			var t0 := asin((W + SiegeState.LANE_WALL) / r)
			var h := asin((SiegeState.ARCH / 2.0 + 0.6) / r)
			for span in [[t0, PI / 4.0 - h], [PI / 4.0 + h, PI / 2.0 - t0]]:
				var n := ceili((span[1] - span[0]) * r / WALL.panel)
				for k in n:
					var u: float = lerpf(span[0], span[1], float(k) / n)
					var v: float = lerpf(span[0], span[1], float(k + 1) / n)
					var a := yard(q, r * cos(u), r * sin(u))
					var b := yard(q, r * cos(v), r * sin(v))
					var mid := yard(q, cos((u + v) / 2.0), sin((u + v) / 2.0)).normalized()
					run(face[2], a, b, mid * face[1])
		var arch := Mech.add_part(self, "yard_arch", MATS, "core_siege")
		var out := yard(q, 1.0, 1.0).normalized()
		arch.position = out * (SiegeState.BLOCK + SiegeState.YARD_IN) / 2.0
		arch.rotation.y = -atan2(out.z, out.x)
		arch.scale.z = SiegeState.ARCH / 6.0
	batch("arena", "wall", cyan, CYAN_LAMPS)
	batch("arena", "wall", amber)
	batch("arena", "wall_post", posts)
	batch("arena", "wall_post", lane_posts, CYAN_LAMPS)
	batch("core_siege", "crate", stacks)
	batch("core_siege", "crate_lid", stacks.map(func(x): return x.translated(Vector3(0, YARD.lid, 0))))


func build_props() -> void:
	var pillars := []
	var vents := []
	for i in 4:
		var d := dir(i)
		var p := Vector3(-d.z, 0, d.x)
		for s in [-1.0, 1.0]:
			for c in SiegeState.CHOKES:
				pillars.append(Transform3D(Basis().scaled(Vector3(SiegeState.CHOKE_R, 1, SiegeState.CHOKE_R)), d * c + p * s * W))
			for v in SiegeState.VENTS:
				vents.append(Transform3D(facing(-p * s), d * v + p * s * W))
				vents.append(Transform3D(facing(p * s), d * v + p * s * (W + SiegeState.LANE_WALL)))
	batch("arena", "pillar", pillars, CYAN_LAMPS)
	batch("arena", "vent", vents, CYAN_LAMPS)


func build_crowd(shared: ShaderMaterial) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var spots := []
	var segs := [[-HALF, -STAND.aisle - STAND.aisle_w], [-STAND.aisle + STAND.aisle_w, -STAND.gap], [STAND.gap, STAND.aisle - STAND.aisle_w], [STAND.aisle + STAND.aisle_w, HALF]]
	for i in 4:
		var d := dir(i)
		var p := Vector3(-d.z, 0, d.x)
		var basis := Basis(Vector3.UP.cross(d), Vector3.UP, d)
		for seg in segs:
			for k in STAND.tiers:
				var h: float = STAND.base + k * STAND.rise
				for row in STAND.rows:
					var o: float = HALF + STAND.front + k * STAND.depth + row
					var l: float = seg[0] + 0.5
					while l < seg[1] - 0.5:
						if rng.randf() >= View.CROWD.empty:
							var slot: int = STAND.team if rng.randf() >= View.CROWD.neutral else rng.randi_range(4, 7)
							var at: Vector3 = d * o + p * (l + rng.randf_range(-0.08, 0.08)) + Vector3(0, h, 0)
							spots.append([Transform3D(basis.scaled(Vector3.ONE * rng.randf_range(0.9, 1.12)), at), Color(rng.randf() * TAU, slot, rng.randf_range(0.75, 1.15), rng.randi_range(0, 3))])
						l += STAND.fan_gap
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = Mech.models("arena")["fan"][0]
	mm.instance_count = spots.size()
	for j in spots.size():
		mm.set_instance_transform(j, spots[j][0])
		mm.set_instance_custom_data(j, spots[j][1])
	fans = spots
	crowd_mat = shared
	if crowd_mat == null:
		crowd_mat = ShaderMaterial.new()
		crowd_mat.shader = Shader.new()
		crowd_mat.shader.code = View.CROWD_SHADER
		var lin := func(cs: Array) -> PackedVector3Array:
			var out := PackedVector3Array()
			for c in cs:
				var l: Color = c.srgb_to_linear()
				out.append(Vector3(l.r, l.g, l.b))
			return out
		crowd_mat.set_shader_parameter("shirts", lin.call(Mech.TEAM + View.CROWD.neutrals))
		crowd_mat.set_shader_parameter("skins", lin.call(View.CROWD.skins))
	crowd = MultiMeshInstance3D.new()
	crowd.multimesh = mm
	crowd.material_override = crowd_mat
	crowd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	crowd.extra_cull_margin = 1.0
	add_child(crowd)


func build_towers() -> void:
	for q in SiegeState.QUADS.size():
		var out := yard(q, 1.0, 1.0).normalized()
		var t := Mech.add_part(self, "flood_tower", MATS, "core_siege")
		t.position = yard(q, TOWER.out, TOWER.out)
		t.rotation.y = -atan2(-out.z, -out.x)
		t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var spot := SpotLight3D.new()
		spot.light_energy = Look.STAGE.spot * TOWER.energy
		spot.spot_attenuation = 0.6
		spot.spot_range = TOWER.range
		spot.spot_angle = TOWER.angle
		spot.light_color = Look.STAGE.spot_color
		add_child(spot)
		var at := dir(q) * TOWER.aim + Vector3(0, Look.STAGE.aim_y, 0)
		spot.look_at_from_position(t.transform * TOWER.head, at)
		towers.append({"spot": spot, "at": at, "v": Vector3.ZERO})
		if not SiegeState.HEAPS.any(func(h): return h.get("kind", "") == "crane"):
			var crane := Mech.add_part(self, "crane", MATS, "core_siege")
			crane.position = yard(q, YARD.crane, YARD.crane, YARD.crane_y)
			crane.rotation.y = t.rotation.y


func junk(parent: Node3D, file: String, part: String, mats: Dictionary, at: Transform3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Mech.models(file)[part][0]
	for i in mi.mesh.get_surface_count():
		mi.set_surface_override_material(i, mats.get(mi.mesh.surface_get_material(i).resource_name, JUNK_MATS.joint))
	mi.transform = at
	parent.add_child(mi)
	return mi


func pile(c: Vector3, r: float, rng: RandomNumberGenerator) -> void:
	for k in rng.randi_range(9, 13):
		var pick: Array = JUNK[rng.randi() % JUNK.size()]
		var off := Vector3.FORWARD.rotated(Vector3.UP, rng.randf() * TAU) * rng.randf_range(0.2, r * 0.85)
		var b := Basis.from_euler(Vector3(rng.randf_range(-1.2, 1.2), rng.randf() * TAU, rng.randf_range(-1.2, 1.2))).scaled(Vector3.ONE * rng.randf_range(1.2, 2.0))
		junk(self, pick[0], pick[1], JUNK_MATS, Transform3D(b, c + off + Vector3(0, rng.randf_range(0.2, r * 0.7), 0)))


func build_yards() -> void:
	var rng := RandomNumberGenerator.new()
	var heaps := []
	var grates := []
	var plates := []
	var heads := []
	var lights := []
	var decor := []
	var scraps := []
	var sheets := []
	var pallets := []
	var yard_crates := []
	var yard_pillars := []
	var decor_mat := Look.shader(Decor.SHADER % Look.NOISE, {"soot": Look.PAL.void, "grime": Look.PAL.grime, "slot": Look.PAL.void, "metal": Look.PAL.steel, "alpha": Decor.D.alpha, "bar": Decor.D.bar})
	var emp := ShaderMaterial.new()
	emp.shader = Shader.new()
	emp.shader.code = View.EMP_SHADER.replace(EMP_EDGE, "float edge = smoothstep(0.85, 1.0, length(UV * 2.0 - 1.0));\n\tif (length(UV * 2.0 - 1.0) > 1.0) { discard; }")
	for q in SiegeState.QUADS.size():
		rng.seed = 100 + q
		var keep := []
		for i in SiegeState.HEAPS.size():
			var h: Dictionary = SiegeState.HEAPS[i]
			var c := yard(q, h.a, h.b)
			var kind: String = h.get("kind", "heap")
			if kind == "stack":
				for k in rng.randi_range(4, 6):
					var off := Vector3((k % 3 - 1) * 1.7, (k / 3) * YARD.crate_h, 0).rotated(Vector3.UP, h.a + h.b) * Vector3(h.r / 2.0, 1, h.r / 2.0)
					yard_crates.append(Transform3D(Basis.from_euler(Vector3(0, h.a + h.b + rng.randf_range(-0.2, 0.2), 0)), c + off))
			elif kind == "pillar":
				yard_pillars.append(Transform3D(Basis().scaled(Vector3(h.r, 1, h.r)), c))
			elif kind == "crane":
				var crane := Mech.add_part(self, "crane", MATS, "core_siege")
				crane.position = c
				var to := (yard(q, 40.0, 40.0) - c).normalized()
				crane.rotation.y = -atan2(to.z, to.x)
			else:
				heaps.append(Transform3D(Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3(h.r, h.r * 1.2, h.r)), c))
				pile(c, h.r, rng)
				if kind == "hulk":
					junk(self, "light", "Chest_heavy", JUNK_MATS, Transform3D(Basis.from_euler(Vector3(PI / 2.0, rng.randf() * TAU, 0.3)).scaled(Vector3.ONE * 1.8), c + Vector3(0, h.r * 0.55, 0)))
			keep.append([Vector2(c.x, c.z), h.r + 0.6])
		var e := yard(q, SiegeState.WRECK.a, SiegeState.WRECK.b)
		var elite := junk(self, "light", "Chest_heavy", JUNK_MATS, Transform3D(Basis.from_euler(Vector3(0.5, rng.randf() * TAU, 0.9)).scaled(Vector3.ONE * 3.5), e + Vector3(0, -0.6, 0)))
		junk(self, "cores", "reactor", JUNK_MATS.merged({"core": Look.neon(Look.PAL.orange, 1.4)}, true), Transform3D(elite.basis, elite.transform * Vector3(0.28, 1.22, 0)))
		junk(self, "heads", "demon", JUNK_MATS, Transform3D(Basis.from_euler(Vector3(1.4, 0.7, 0)).scaled(Vector3.ONE * 3.0), e + Vector3(3.2, 0.6, -2.0)))
		junk(self, "arms", "anvil_upper_R", JUNK_MATS, Transform3D(Basis.from_euler(Vector3(0, 2.2, 1.5)).scaled(Vector3.ONE * 3.0), e + Vector3(-3.0, 0.5, 2.4)))
		keep.append([Vector2(e.x, e.z), SiegeState.WRECK.r + 0.5])
		for s in SiegeState.STEAM:
			var c := yard(q, s.a, s.b)
			grates.append(Transform3D(Basis(), c))
			add_child(steam(c, s.r))
			keep.append([Vector2(c.x, c.z), s.r])
		for z in SiegeState.YARD_HAZARDS:
			var c := yard(q, z.a, z.b)
			if z.kind == "crush":
				plates.append(Transform3D(Basis().scaled(Vector3.ONE * z.half / 1.5), c))
				heads.append(Transform3D(Basis(), c + Vector3(0, 3.0, 0)))
				keep.append([Vector2(c.x, c.z), z.half * 1.5])
			else:
				var mi := Mech.add(self, Mech.plane(), emp, c + Vector3(0, 0.03, 0))
				mi.scale = Vector3(z.r * 2.0, 1, z.r * 2.0)
				keep.append([Vector2(c.x, c.z), z.r])
		for c in SiegeState.CAMPS:
			keep.append([Vector2(yard(q, c.a, c.b).x, yard(q, c.a, c.b).z), 4.0])
		for c in SiegeState.CRATES:
			keep.append([Vector2(yard(q, c[0], c[1]).x, yard(q, c[0], c[1]).z), 2.0])
		for c in SiegeState.CAMPS:
			if c.tier in ["big", "elite"]:
				var off: float = 4.5 * YARD.size[c.tier]
				var at := yard(q, c.a + off, c.b - off)
				lights.append(Transform3D(facing((yard(q, c.a, c.b) - at).normalized()), at))
				var o := accent(at.lerp(yard(q, c.a, c.b), 0.4) + Vector3(0, YARD.light, 0), Look.PAL.orange)
				o.omni_range = YARD.light_range
				o.light_energy = YARD.light_energy
		for l in YARD.lights:
			var wall := W + SiegeState.LANE_WALL / 2.0
			var la: float = wall if l[0] < 0 else l[0]
			var lb: float = wall if l[1] < 0 else l[1]
			var at := yard(q, la, lb, YARD.wall_top)
			var into := (yard(q, la + l[2], lb + l[3]) - yard(q, la, lb)).normalized()
			lights.append(Transform3D(facing(into), at))
			var o := accent(at + into * 1.5 + Vector3(0, YARD.light - YARD.wall_top, 0), Look.PAL.orange)
			o.omni_range = YARD.light_range
			o.light_energy = YARD.light_energy
		var n := 0
		while n < YARD.scorch:
			var r := rng.randf_range(YARD.scorch_r.x, YARD.scorch_r.y)
			var p := Vector2(rng.randf_range(10.0, HALF - 3.0), rng.randf_range(10.0, HALF - 3.0))
			var w := Vector2(yard(q, p.x, p.y).x, yard(q, p.x, p.y).z)
			if p.length() < SiegeState.YARD_IN + r or keep.any(func(k): return w.distance_to(k[0]) < k[1] + r):
				continue
			n += 1
			decor.append(Decor.piece("scorch", w, r, rng.randf() * TAU, Vector2(r, r) * 2.0, Color(0, rng.randf(), 0, 0)))
			for k in 4:
				var s: Vector3 = Decor.D.scrap * rng.randf_range(0.5, 1.0)
				var at := w + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.3, r + 0.8)
				scraps.append(Transform3D(Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(s), Vector3(at.x, s.y * 0.5, at.y)))
		n = 0
		while n < YARD.debris:
			var p := Vector2(rng.randf_range(8.0, HALF - 2.0), rng.randf_range(8.0, HALF - 2.0))
			var w := Vector2(yard(q, p.x, p.y).x, yard(q, p.x, p.y).z)
			if p.length() < SiegeState.YARD_IN + 1.5 or keep.any(func(k): return w.distance_to(k[0]) < k[1] + 1.0):
				continue
			n += 1
			var size: Vector3 = YARD.sheet if rng.randf() < 0.6 else YARD.pallet
			var b := Basis.from_euler(Vector3(rng.randf_range(-0.05, 0.05), rng.randf() * TAU, rng.randf_range(-0.05, 0.05))).scaled(size * rng.randf_range(0.8, 1.3))
			(sheets if size == YARD.sheet else pallets).append(Transform3D(b, Vector3(w.x, size.y * 0.5, w.y)))
		var hold := Node3D.new()
		hold.visible = false
		add_child(hold)
		var burnt := []
		var tipped := []
		n = 0
		while n < YARD.raid:
			var p := Vector2(rng.randf_range(12.0, 60.0), rng.randf_range(12.0, 60.0))
			var w := Vector2(yard(q, p.x, p.y).x, yard(q, p.x, p.y).z)
			if p.length() < SiegeState.YARD_IN + 3.0 or keep.any(func(k): return w.distance_to(k[0]) < k[1] + 1.5):
				continue
			n += 1
			burnt.append(Decor.piece("scorch", w, 2.0, rng.randf() * TAU, Vector2(4.5, 4.5), Color(0, rng.randf(), 0, 0)))
			var box := Mech.add_part(hold, "crate", MATS, "core_siege")
			box.transform = Transform3D(Basis.from_euler(Vector3(rng.randf_range(1.2, 1.6), rng.randf() * TAU, 0)), Vector3(w.x, 0.6, w.y))
			box.visible = false
			tipped.append(box)
		var bm := Decor.multimesh(PlaneMesh.new(), burnt.size())
		(bm.mesh as PlaneMesh).size = Vector2.ONE
		for i in burnt.size():
			bm.set_instance_transform(i, burnt[i].at)
			bm.set_instance_custom_data(i, burnt[i].data)
		Decor.add(hold, bm, decor_mat)
		raids.append({"node": hold, "crates": tipped})
		var Q: Dictionary = SiegeState.QUADS[q]
		var a := YARD.grime / 2.0 + W + SiegeState.LANE_WALL
		while a < HALF:
			for g in [[Vector2(Q.sx * a, Q.sy * (W + SiegeState.LANE_WALL + 0.5)), Vector2(0, Q.sy)], [Vector2(Q.sx * (W + SiegeState.LANE_WALL + 0.5), Q.sy * a), Vector2(Q.sx, 0)]]:
				if g[0].length() > SiegeState.YARD_IN + 1.0:
					decor.append(Decor.piece("grime", g[0], 1.0, -g[1].angle() + PI / 2.0, Vector2(YARD.grime, 1.0), Color(1, rng.randf(), 0, 0)))
			a += YARD.grime
	batch("core_siege", "heap", heaps)
	batch("core_siege", "crate", yard_crates)
	batch("core_siege", "crate_lid", yard_crates.map(func(x): return x.translated(Vector3(0, YARD.lid, 0))))
	batch("arena", "pillar", yard_pillars)
	batch("core_siege", "steam_grate", grates)
	batch("core_siege", "work_light", lights)
	var warn: ShaderMaterial = MATS.hazard.duplicate()
	batch("arena", "crush_plate", plates, MATS.merged({"hazard": warn}, true))
	batch("arena", "crush_head", heads, MATS.merged({"hazard": warn}, true))
	var mm := Decor.multimesh(PlaneMesh.new(), decor.size())
	(mm.mesh as PlaneMesh).size = Vector2.ONE
	for i in decor.size():
		mm.set_instance_transform(i, decor[i].at)
		mm.set_instance_custom_data(i, decor[i].data)
	Decor.add(self, mm, decor_mat)
	var sm := Decor.multimesh(Mech.box(Vector3.ONE), scraps.size())
	for i in scraps.size():
		sm.set_instance_transform(i, scraps[i])
	Decor.add(self, sm, Look.ARENA.trim)
	for f in [[sheets, MATS.rust], [pallets, JUNK_MATS.trim]]:
		var fm := Decor.multimesh(Mech.box(Vector3.ONE), f[0].size())
		for i in f[0].size():
			fm.set_instance_transform(i, f[0][i])
		Decor.add(self, fm, f[1])
	var dust := Decor.dust()
	dust.amount = Decor.D.dust * 4
	dust.position = Vector3(0, dust.position.y, 0)
	dust.emission_box_extents = Vector3(HALF, dust.emission_box_extents.y, HALF)
	add_child(dust)


func steam(c: Vector3, r: float) -> CPUParticles3D:
	var s := Fx.emitter(Fx.LAYERS.wreck_smoke, 1.0, 1.0, Fx.gradient([Color(0.85, 0.88, 0.92, 0.0), Color(0.8, 0.84, 0.9, STEAM.alpha), Color(0.75, 0.8, 0.86, 0.0)]))
	s.amount = STEAM.amount
	s.lifetime = STEAM.life
	s.preprocess = STEAM.life
	s.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	s.emission_sphere_radius = r * 0.7
	s.direction = Vector3.UP
	s.scale_amount_min = STEAM.size
	s.scale_amount_max = STEAM.size * 1.5
	s.position = c + Vector3(0, STEAM.y, 0)
	s.emitting = true
	return s


func build_dock() -> void:
	var n := Node3D.new()
	n.position = Vector3(SiegeState.GARRISON_DOCK.x, 0, SiegeState.GARRISON_DOCK.y)
	n.rotation.y = -SiegeState.GARRISON_DOCK.face
	add_child(n)
	Mech.add_part(n, "dock", MATS, "core_siege")
	var lamps := []
	for z in DOCK.lamps:
		var m: StandardMaterial3D = MATS.pylon.duplicate()
		var mi := Mech.add_part(n, "dock_lamp", MATS.merged({"pylon": m}, true), "core_siege")
		mi.position = Vector3(DOCK.lamp.x, DOCK.lamp.y, z)
		mi.rotation.z = PI / 2.0
		lamps.append(m)
	var beam := Mech.add(n, Mech.cyl(DOCK.beam.x, DOCK.beam.x, DOCK.beam.y), Mech.flat(Color(Look.PAL.cyan, 0.08), true), Vector3(0, DOCK.beam.y / 2.0 + 0.3, 0))
	beam.visible = false
	dock = {"node": n, "lamps": lamps, "beam": beam}


func build_bay() -> void:
	var b: Dictionary = contract("BAY", BAY_AT)
	var n := Node3D.new()
	n.position = Vector3(b.x, 0, b.y)
	n.rotation.y = -b.face
	add_child(n)
	var m: StandardMaterial3D = MATS.counter.duplicate()
	Mech.add_part(n, "parts_bay", MATS.merged({"counter": m}, true), "core_siege")
	var items := []
	for it in BAY.items:
		items.append(junk(n, it[0], it[1], DISPLAY, Transform3D(Basis().scaled(Vector3.ONE * BAY.size), it[2])))
	bay = {"node": n, "mat": m, "items": items, "light": accent(n.transform * Vector3(1.6, 2.0, 0), Look.PAL.cyan), "buys": 0}


func make_recall() -> Dictionary:
	var n := Node3D.new()
	add_child(n)
	var glow := Mech.flat(Color(Look.PAL.cyan, RECALL.alpha), true)
	var beam := Mech.add(n, Mech.cyl(RECALL.r, RECALL.r, 1.0), glow)
	var core := Mech.add(n, Mech.cyl(RECALL.core, RECALL.core, 1.0), Mech.flat(Color(0.85, 0.95, 1.0, 0.8), true))
	var segs := []
	for i in RECALL.segs:
		var a := TAU * i / RECALL.segs
		segs.append(Mech.add(n, Mech.box(Vector3(0.38, 0.04, 0.12)), Mech.flat(Look.PAL.cyan, true), Vector3(cos(a) * RECALL.ring, 0.06, sin(a) * RECALL.ring), Vector3(0, -a + PI / 2.0, 0)))
	return {"node": n, "beam": beam, "core": core, "segs": segs, "f": 0.0}


func accent(at: Vector3, c: Color) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = Look.STAGE.accent
	l.omni_range = Look.STAGE.accent_range
	l.position = at
	add_child(l)
	return l


func update(siege: Dictionary) -> void:
	tick = int(siege.tick)
	var t := tick / float(Sim.TICKS)
	draw_core(siege.core, t)
	var wave: Dictionary = siege.wave
	for i in 4:
		lamp(spawns[i], wave, i)
	while gates.size() < siege.gates.size():
		gates.append(make_gate(siege.gates[gates.size()]))
	for i in siege.gates.size():
		draw_gate(gates[i], siege.gates[i], wave)
	while pads.size() < siege.pads.size():
		pads.append(make_pad(siege.pads[pads.size()]))
	for i in siege.pads.size():
		draw_pad(pads[i], siege.pads[i].module)
	var all_camps := []
	var all_crates := []
	var yards: Array = siege.get("yards", [])
	for q in yards.size():
		all_camps += yards[q].camps
		all_crates += yards[q].crates
		var raid: float = yards[q].get("raided", 0.0)
		raids[q].node.visible = raid > 0.0
		for i in raids[q].crates.size():
			raids[q].crates[i].visible = i < roundi(raid * raids[q].crates.size())
	while camps.size() < all_camps.size():
		camps.append(make_camp(all_camps[camps.size()]))
	for i in all_camps.size():
		draw_camp(camps[i], all_camps[i], t)
	while crates.size() < all_crates.size():
		crates.append(make_crate(all_crates[crates.size()]))
	for i in all_crates.size():
		draw_crate(crates[i], all_crates[i], t)
	if siege.has("garrison"):
		draw_dock(siege.garrison, t)
	draw_bay(siege, t)
	draw_recall(siege.get("recall", []))


func draw_bay(siege: Dictionary, t: float) -> void:
	var open: bool = siege.get("shop_open", []).has(true)
	bay.mat.emission_energy_multiplier = BAY.open if open else BAY.idle
	bay.light.light_energy = Look.STAGE.accent * (BAY.light if open else 1.0)
	for i in bay.items.size():
		bay.items[i].basis = Basis(Vector3.UP, t * BAY.spin * (1.0 if i % 2 == 0 else -1.0)).scaled(Vector3.ONE * BAY.size)
	var buys: int = siege.get("buys", 0)
	if buys > bay.buys:
		Fx.ring(self, bay.node.position + Vector3(0, 0.3, 0), BAY.pulse[0], BAY.pulse[1], BAY.pulse[2], Look.PAL.cyan)
		Fx.flash(self, bay.node.transform * Vector3(1.15, 1.5, 0), 0.8, 0.12, Color(0.85, 0.95, 1.0))
	bay.buys = buys


func draw_recall(list: Array) -> void:
	var seen := {}
	for r in list:
		seen[r.player] = true
		if not recalls.has(r.player):
			recalls[r.player] = make_recall()
		var rv: Dictionary = recalls[r.player]
		var f: float = clampf(float(r.t) / r.max, 0.0, 1.0) if r.max > 0 else 0.0
		rv.node.position = Vector3(r.x, 0, r.y)
		rv.node.visible = true
		var h: float = RECALL.h * maxf(f, 0.05)
		rv.beam.scale = Vector3(0.4 + 0.6 * f, h, 0.4 + 0.6 * f)
		rv.beam.position.y = h / 2.0
		rv.core.scale = Vector3(1, h, 1)
		rv.core.position.y = h / 2.0
		for i in RECALL.segs:
			rv.segs[i].visible = i < ceili(f * RECALL.segs)
		rv.f = f
	for key in recalls:
		var rv: Dictionary = recalls[key]
		if not seen.has(key) and rv.node.visible:
			if rv.f >= RECALL.done:
				Fx.flash(self, rv.node.position + Vector3(0, 1.0, 0), 1.2, 0.15, Color(0.85, 0.95, 1.0))
				Fx.ring(self, RECALL.land, RECALL.flash[0], RECALL.flash[1], RECALL.flash[2], Look.PAL.cyan)
				Fx.flash(self, RECALL.land, 2.0, 0.18, Color(0.85, 0.95, 1.0))
			rv.node.visible = false


func draw_core(core: Dictionary, t: float) -> void:
	var f: float = clampf(core.hp / core.max, 0.0, 1.0) if core.max > 0 else 0.0
	crystal.rotation.y = t * CORE.spin
	crystal.position.y = CORE.y + sin(t * 1.7) * CORE.bob
	var dip := 1.0
	if f < 0.5:
		var hurt := (0.5 - f) * 2.0
		dip = 1.0 - CORE.flicker * hurt * absf(sin(tick * 0.9) * sin(tick * 0.37 + 1.0))
	var c := Color(0.6, 0.9, 1.0).lerp(Look.PAL.heal, 0.6 if core.repairing else 0.0)
	crystal_mat.albedo_color = c
	crystal_mat.emission = c
	crystal_mat.emission_energy_multiplier = CORE.glow * dip * (0.3 + 0.7 * minf(f * 4.0, 1.0))
	core_light.light_color = c
	core_light.light_energy = CORE.light * dip * maxf(f, 0.2)
	smoke.emitting = f < CORE.smoke
	mend.visible = core.repairing
	if core.repairing:
		mend.scale = Vector3(1.0, 0.05, 1.0) * Vector3(1.0 + 0.04 * sin(t * 6.0), 1.0, 1.0 + 0.04 * sin(t * 6.0))
	for k in 4:
		var up: bool = core.rings[k] > 0
		if ring_up.size() < 4:
			ring_up.append(up)
		rings[k].visible = up
		rings[k].rotation.y = t * CORE.ring_spin[k]
		if ring_up[k] and not up:
			var at := Vector3(0, CORE.rings[k], 0)
			var r: float = rings[k].get_aabb().size.x / 2.0
			Fx.ring(self, at, r, r * 1.6, 0.35, Look.PAL.cyan)
			Fx.flash(self, at, 1.2, 0.12, Color(0.85, 0.95, 1.0))
		ring_up[k] = up


func lamp(m: StandardMaterial3D, wave: Dictionary, lane: int) -> void:
	var e := 0.0
	if wave.lanes_open[lane]:
		if wave.next_in > 0 and wave.next_in <= WARN.secs * Sim.TICKS:
			e = WARN.on if (tick / WARN.blink) % 2 == 0 else 0.0
		elif wave.next_in <= 0:
			e = WARN.steady
	m.emission_energy_multiplier = e


func make_gate(g: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.position = Vector3(g.x, 0, g.y)
	n.rotation.y = yaw(g.lane)
	add_child(n)
	Mech.add_part(n, "gate", MATS, "core_siege")
	var m: StandardMaterial3D = MATS.warn.duplicate()
	Mech.add_part(n, "gate_light", MATS.merged({"warn": m}, true), "core_siege").cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bar_mat: StandardMaterial3D = Mech.flat(Look.PAL.cyan).duplicate()
	var back := Mech.add(n, Mech.box(Vector3(GATE.bar, GATE.bar, GATE.width)), Mech.flat(Color(Look.PAL.void, 0.7)), Vector3(0, GATE.bar_y, 0))
	var fill := Mech.add(back, Mech.box(Vector3(GATE.bar * 1.2, GATE.bar * 1.2, 1.0)), bar_mat)
	return {"node": n, "light": m, "door": Mech.add_part(n, "gate_door", MATS, "core_siege"),
		"broken": Mech.add_part(n, "gate_broken", MATS, "core_siege"), "bar": back, "fill": fill, "bar_mat": bar_mat}


func draw_gate(gv: Dictionary, g: Dictionary, wave: Dictionary) -> void:
	var f: float = clampf(g.hp / g.max, 0.0, 1.0) if g.max > 0 else 0.0
	var down := f <= 0.0
	gv.broken.visible = down
	gv.door.visible = not down
	var want := -GATE.sink if g.get("open", false) else 0.0
	gv.door.position.y = lerpf(gv.door.position.y, want, GATE.ease)
	gv.bar.visible = f > 0.0 and f < 1.0
	gv.fill.scale.z = GATE.width * f
	gv.fill.position.z = -GATE.width * (1.0 - f) / 2.0
	gv.bar_mat.albedo_color = Look.PAL.warn.lerp(Look.PAL.cyan, f)
	lamp(gv.light, wave, g.lane)


func make_pad(p: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.position = Vector3(p.x, 0, p.y)
	n.rotation.y = yaw(p.lane)
	add_child(n)
	Mech.add_part(n, "crush_plate", MATS, "arena").scale = Vector3(4.0 / 3.0, 1, 4.0 / 3.0)
	var mods := {}
	for k in ["wall", "mine"]:
		mods[k] = Mech.add_part(n, "mod_" + k, MATS, "core_siege")
	mods.laser = Node3D.new()
	n.add_child(mods.laser)
	Mech.add_part(mods.laser, "tesla", MATS, "arena")
	var orb := Mech.add_part(mods.laser, "tesla_orb", MATS, "arena")
	orb.position.y = 2.0
	for k in mods:
		mods[k].visible = false
	return {"node": n, "mods": mods}


func draw_pad(pv: Dictionary, module: String) -> void:
	for k in pv.mods:
		pv.mods[k].visible = k == module


func make_camp(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.position = Vector3(c.x, 0, c.y)
	n.scale = Vector3.ONE * YARD.size[c.tier]
	add_child(n)
	var m: StandardMaterial3D = MATS.amber.duplicate()
	var mats := MATS.merged({"amber": m}, true)
	Mech.add_part(n, "camp_ring", mats, "core_siege")
	var tiers: int = YARD.tiers[c.tier]
	for i in tiers:
		Mech.add_part(n, "camp_pip", mats, "core_siege").position = Vector3((i - (tiers - 1) / 2.0) * YARD.pip_gap, 0, YARD.pip)
	return {"node": n, "mat": m, "alive": c.alive}


func draw_camp(cv: Dictionary, c: Dictionary, t: float) -> void:
	var e: float = YARD.alive if c.alive else YARD.dead
	if not c.alive and c.respawn_in > 0 and c.respawn_in <= YARD.wake * Sim.TICKS:
		e = lerpf(YARD.dead, YARD.alive, 0.5 + 0.5 * sin(t * 12.0))
	if c.alive and not cv.alive:
		Fx.ring(self, cv.node.position + Vector3(0, 0.1, 0), 2.0, 4.5, 0.4, Look.PAL.orange)
	cv.alive = c.alive
	cv.mat.emission_energy_multiplier = e


func make_crate(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.position = Vector3(c.x, 0, c.y)
	n.rotation.y = fposmod(c.x * 0.37 + c.y * 0.11, TAU)
	add_child(n)
	Mech.add_part(n, "crate", MATS, "core_siege")
	var lid := Mech.add_part(n, "crate_lid", MATS, "core_siege")
	lid.position.y = YARD.lid
	var segs := []
	for i in YARD.segs:
		var a := TAU * i / YARD.segs
		segs.append(Mech.add(n, Mech.box(Vector3(0.5, 0.04, 0.12)), Mech.flat(Look.PAL.orange, true), Vector3(cos(a), 0.05, sin(a)) * Vector3(YARD.ring, 1, YARD.ring), Vector3(0, -a + PI / 2.0, 0)))
	return {"node": n, "lid": lid, "segs": segs}


func draw_crate(cv: Dictionary, c: Dictionary, t: float) -> void:
	cv.node.visible = not c.taken
	var on := ceili(c.progress * YARD.segs) if c.progress > 0.0 and c.progress < 1.0 else 0
	for i in YARD.segs:
		cv.segs[i].visible = i < on
	cv.lid.position.y = YARD.lid + c.progress * YARD.lift
	cv.lid.rotation.z = sin(t * 30.0) * 0.04 if on > 0 else 0.0


func draw_dock(g: Dictionary, t: float) -> void:
	for i in dock.lamps.size():
		dock.lamps[i].emission_energy_multiplier = DOCK.on if i < g.tier else DOCK.off
	dock.beam.visible = g.tier > 0 and g.respawn_in > 0
	if dock.beam.visible:
		dock.beam.scale = Vector3(1.0 + 0.08 * sin(t * 8.0), 1.0, 1.0 + 0.08 * sin(t * 8.0))
