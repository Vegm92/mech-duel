extends Node3D

const Sim = preload("res://src/sim.gd")

static var TEAM := [Color8(255, 122, 47), Color8(79, 157, 255), Color8(86, 214, 96), Color8(214, 84, 230)]
static var TEAM_LIGHT := [Color8(255, 196, 150), Color8(170, 210, 255), Color8(180, 245, 172), Color8(242, 178, 250)]
static var TEAM_DARK := [Color8(110, 40, 10), Color8(20, 55, 115), Color8(22, 88, 30), Color8(84, 24, 100)]
static var EYES := [Color8(255, 214, 120), Color8(150, 235, 255), Color8(215, 255, 150), Color8(255, 175, 245)]
static var BOOST_C := {"arc": Color8(150, 205, 255), "flame": Color8(255, 150, 60), "frost": Color8(170, 240, 255), "smoke": Color8(190, 190, 200), "magnet": Color8(205, 125, 255), "clean": Color8(255, 232, 170)}
static var STEEL := Color8(170, 180, 198)
static var DARK := Color8(44, 48, 58)
static var CORE_C := {"furnace": Color8(255, 150, 60), "coolant": Color8(110, 230, 255), "reactor": Color8(190, 255, 90), "leech": Color8(225, 40, 80), "titan": Color8(190, 202, 220), "volt": Color8(255, 230, 70), "fury": Color8(255, 64, 48), "flywheel": Color8(228, 232, 242), "aegis": Color8(90, 150, 255), "glass": Color8(255, 140, 210), "phantom": Color8(200, 220, 255), "gravity": Color8(150, 90, 255), "bastion": Color8(255, 210, 90), "meltdown": Color8(255, 90, 40), "deflector": Color8(90, 255, 230), "mirror": Color8(235, 245, 255), "rail": Color8(90, 200, 255), "shroud": Color8(160, 160, 175)}
static var SHOULDER := {"light": 0.41, "standard": 0.46, "heavy": 0.52}
static var BACK := {"light": 0.279, "standard": 0.313, "heavy": 0.349}
static var WHIRL := {"flywheel": ["flywheel_disc", Vector3(0.346, 1.22, 0), Vector3.RIGHT, 8.0], "gravity": ["gravity_ring", Vector3(0.4085, 1.22, 0), Vector3(0.35, 1, 0.5).normalized(), 3.0]}
static var _mats := {}
static var _meshes := {}
static var _glb := {}

const ARM_UP := 0.2
const ELBOW := Vector3(0.048, -0.235, 0)
const FIST := Vector3(0.438, -0.235, 0)
const MOUNT := {"rivet": "arm", "scatter": "arm", "gatling": "arm", "tesla": "arm", "flamer": "shoulder", "missiles": "shoulder", "mortar": "shoulder"}
const THRUST := ["drill", "bunker", "fist", "whip"]
const TRAIL := {"saw": [Vector3(0.85, 0, 0), Vector3(1.28, 0, 0)], "hammer": [Vector3(0.8, 0, 0), Vector3(1.12, 0, 0)], "claws": [Vector3(0.55, 0, 0), Vector3(0.92, -0.06, 0)], "katana": [Vector3(0.8, 0, 0), Vector3(1.47, -0.04, 0)], "bash": [Vector3(0.42, 0, -0.45), Vector3(0.42, 0, 0.45)], "flail": [Vector3(0.95, 0, 0), Vector3(1.42, 0, 0)], "drill": [Vector3(1.3, 0, -0.08), Vector3(1.3, 0, 0.08)], "bunker": [Vector3(1.15, 0, -0.08), Vector3(1.15, 0, 0.08)], "fist": [Vector3(0.66, 0, -0.14), Vector3(0.66, 0, 0.14)], "whip": [Vector3(1.75, 0, -0.06), Vector3(1.75, 0, 0.06)]}
const TAIL := 1.6
const TRAIL_LIFE := 0.16

var team := 0
var body_mat: StandardMaterial3D
var gem_mat: StandardMaterial3D
var boost_mat: StandardMaterial3D
var torso: Node3D
var hips: Node3D
var hands := {}
var held := {}
var shown := {}
var trail: MeshInstance3D
var strokes := []
var live := {}
var spun := {}
var turned := {}
var legs_kind := ""
var swing := []
var spin := []
var whirl := []
var shoulder := 0.41
var shield: Node3D
var shield_mesh: MeshInstance3D
var bubble: MeshInstance3D
var aim_line: MeshInstance3D
var smoke: CPUParticles3D
var saw: Node3D
var walk := 0.0
var clock := 0.0
var src = null
var dead := false


static func mat(c: Color, emit := 0.0, metal := 0.25, rough := 0.55, cull := true) -> StandardMaterial3D:
	var key := "%s/%s/%s/%s/%s" % [c.to_html(), emit, metal, rough, cull]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = Color(c.r, c.g, c.b)
		m.emission_energy_multiplier = emit
	if not cull:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[key] = m
	return m


static func glow(c: Color, emit := 4.0, alpha := 1.0) -> StandardMaterial3D:
	return mat(Color(c, alpha), emit, 0.0, 1.0, false)


static func flat(c: Color, add := false) -> StandardMaterial3D:
	var key := "flat/%s/%s" % [c.to_html(), add]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if add:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mats[key] = m
	return m


static func box(size: Vector3) -> Mesh:
	var key := "b%s" % size
	if not _meshes.has(key):
		var b := BoxMesh.new()
		b.size = size
		_meshes[key] = b
	return _meshes[key]


static func cyl(top: float, bottom: float, h: float, segs := 12) -> Mesh:
	var key := "c%s/%s/%s/%s" % [top, bottom, h, segs]
	if not _meshes.has(key):
		var c := CylinderMesh.new()
		c.top_radius = top
		c.bottom_radius = bottom
		c.height = h
		c.radial_segments = segs
		c.rings = 1
		_meshes[key] = c
	return _meshes[key]


static func ball(r: float, segs := 12) -> Mesh:
	var key := "s%s/%s" % [r, segs]
	if not _meshes.has(key):
		var s := SphereMesh.new()
		s.radius = r
		s.height = r * 2
		s.radial_segments = segs
		s.rings = segs / 2
		_meshes[key] = s
	return _meshes[key]


static func ring(inner: float, outer: float) -> Mesh:
	var key := "t%s/%s" % [inner, outer]
	if not _meshes.has(key):
		var t := TorusMesh.new()
		t.inner_radius = inner
		t.outer_radius = outer
		t.rings = 24
		t.ring_segments = 8
		_meshes[key] = t
	return _meshes[key]


static func add(parent: Node3D, mesh: Mesh, m: Material, pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	if m is StandardMaterial3D and (m.emission_enabled or m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func models(file: String) -> Dictionary:
	if not _glb.has(file):
		var s: Node = load("res://assets/models/%s.glb" % file).instantiate()
		var found := {}
		for c in s.get_children():
			found[String(c.name)] = [c.mesh, c.position]
		s.free()
		_glb[file] = found
	return _glb[file]


static func add_part(parent: Node3D, part: String, mats: Dictionary, file := "light") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = models(file)[part][0]
	for i in mi.mesh.get_surface_count():
		mi.set_surface_override_material(i, mats[mi.mesh.surface_get_material(i).resource_name])
	parent.add_child(mi)
	return mi


static func weapon_node(name: String, mats: Dictionary) -> Node3D:
	var n := Node3D.new()
	add_part(n, name, mats, "guns")
	if name == "saw":
		var disc := add_part(n, "saw_disc", mats, "guns")
		disc.position = Vector3(0.75, 0, 0)
		disc.set_meta("spin", true)
	return n


static func paints(lo: Dictionary, t: int) -> Dictionary:
	var body := StandardMaterial3D.new()
	body.albedo_color = TEAM[t]
	body.metallic = 0.3
	body.roughness = 0.5
	body.emission_enabled = true
	body.emission = Color.BLACK
	var gem := StandardMaterial3D.new()
	gem.albedo_color = EYES[t]
	gem.emission_enabled = true
	gem.emission = EYES[t]
	gem.emission_energy_multiplier = 3.0
	var boost := StandardMaterial3D.new()
	var bc: Color = BOOST_C[Sim.BOOSTERS[lo.booster].trail]
	boost.albedo_color = bc
	boost.emission_enabled = true
	boost.emission = bc
	return {"body": body, "trim": mat(STEEL, 0.0, 0.55, 0.5), "joint": mat(DARK, 0.0, 0.4, 0.6), "gem": gem, "boost": boost, "core": glow(CORE_C[lo.core], 3.0), "heal": glow(Color8(90, 255, 150), 3.0), "glow": glow(TEAM_LIGHT[t], 1.6), "flame": glow(Color8(255, 150, 60), 5.0), "laser": glow(Color8(255, 80, 120), 6.0), "arc": glow(Color8(170, 210, 255), 4.0), "bounce": glow(Color8(120, 255, 150), 4.0)}


static func arm(p: Node3D, kind: String, s: String, parts: Dictionary) -> MeshInstance3D:
	add_part(p, kind + "_upper" + s, parts, "arms").rotation.z = ARM_UP
	var fore := add_part(p, kind + "_fore" + s, parts, "arms")
	fore.position = ELBOW
	fore.rotation.z = PI / 2
	return fore


func add_core(core: String, parts: Dictionary) -> void:
	add_part(torso, "Chest_" + Sim.CORES[core].series, parts)
	add_part(torso, core, parts, "cores")
	if WHIRL.has(core):
		var wh: Array = WHIRL[core]
		whirl.append([add_part(torso, wh[0], parts, "cores"), wh[2], wh[3]])
		whirl[-1][0].position = wh[1]


func build_part(slot: String, key: String, t: int) -> void:
	var lo: Dictionary = Sim.DEFAULT_LOADOUT.duplicate()
	lo[slot] = key
	var parts := paints(lo, t)
	torso = self
	hips = self
	match slot:
		"head":
			add_part(self, key, parts, "heads")
		"core":
			add_core(key, parts)
		"arms":
			arm(self, key, "_R", parts)
		"legs":
			build_legs(key, parts)
		"booster":
			add_part(self, key, parts, "boosters")
		_:
			add_child(weapon_node(key, parts))


func build(lo: Dictionary, t: int) -> void:
	team = t
	var parts := paints(lo, t)
	body_mat = parts.body
	gem_mat = parts.gem
	boost_mat = parts.boost
	hips = Node3D.new()
	add_child(hips)
	torso = Node3D.new()
	add_child(torso)
	build_legs(lo.legs, parts)
	add_part(hips, "Hips", parts)
	var size: String = Sim.CORES[lo.core].series
	shoulder = SHOULDER[size]
	add_core(lo.core, parts)
	add_part(torso, lo.booster, parts, "boosters").position.x = -BACK[size]
	add_part(torso, lo.head, parts, "heads").position.y = 1.44
	for hand in Sim.HANDS:
		var side := -1.0 if hand == "left" else 1.0
		var p := Node3D.new()
		p.position = Vector3(0, 1.32, side * shoulder)
		torso.add_child(p)
		var fore := arm(p, lo.arms, "_L" if hand == "left" else "_R", parts)
		var mount: String = MOUNT.get(lo[hand], "hand")
		fore.visible = mount != "arm"
		var w := weapon_node(lo[hand], parts)
		w.position = ELBOW if mount == "arm" else (Vector3(0, 0.15, side * 0.02) if mount == "shoulder" else FIST)
		p.add_child(w)
		for c in w.get_children():
			if c.has_meta("spin"):
				spin.append(c)
		hands[hand] = p
		held[hand] = w
	shield = Node3D.new()
	add_child(shield)
	shield_mesh = add(shield, box(Vector3(0.12, 1.4, 2.3)), glow(Color8(120, 190, 255), 2.5, 0.55), Vector3(1.25, 1.05, 0))
	shield.visible = false
	bubble = add(self, ball(1.35, 20), glow(Color8(110, 170, 255), 1.2, 0.18), Vector3(0, 1.0, 0))
	bubble.visible = false
	aim_line = add(torso, box(Vector3(1, 0.06, 1)), glow(Color8(255, 190, 90), 4.0, 0.6), Vector3(0, 1.08, 0))
	aim_line.visible = false
	var tm := StandardMaterial3D.new()
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.vertex_color_use_as_albedo = true
	tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	tm.cull_mode = BaseMaterial3D.CULL_DISABLED
	tm.albedo_color = Color(1.3, 1.3, 1.3)
	trail = MeshInstance3D.new()
	trail.mesh = ImmediateMesh.new()
	trail.material_override = tm
	trail.top_level = true
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trail.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(trail)


func build_legs(kind: String, parts: Dictionary) -> void:
	legs_kind = kind
	var all := models("legs")
	var names: Array = all.keys().filter(func(n): return n == kind or n.begins_with(kind + "_"))
	names.sort()
	for n in names:
		var p := Node3D.new()
		p.position = all[n][1]
		hips.add_child(p)
		add_part(p, n, parts, "legs")
		if "_tire" in n:
			spin.append(p)
		elif "_leg" in n:
			swing.append(p)


func sync(m: Dictionary, tick: int, dt: float) -> void:
	var fresh := not is_same(src, m)
	src = m
	position = Vector3(m.x, Sim.height_of(m), m.y)
	clock += dt
	torso.rotation.y = -m.aim
	var sp := sqrt(m.vx * m.vx + m.vy * m.vy)
	if sp > 0.4:
		hips.rotation.y = lerp_angle(hips.rotation.y, -atan2(m.vy, m.vx), 0.35)
	walk += sp * dt * 2.4
	var k := minf(sp / 6.0, 1.0) * (0.55 if legs_kind == "quad" else 1.0)
	for i in swing.size():
		swing[i].rotation.z = sin(walk + i * PI * (0.5 if swing.size() == 4 else 1.0)) * 0.55 * k
	for w in spin:
		if w.get_parent() == hips:
			w.rotation.z -= sp * dt / 0.36
		else:
			w.rotation.y += dt * 18.0
	for w in whirl:
		w[0].rotate_object_local(w[1], w[2] * dt)
	if legs_kind == "hover":
		hips.position.y = 0.06 * sin(clock * 3.0)
	var dashing: bool = m.act != null and m.act.k == "dash" and m.act.ph == "go"
	boost_mat.emission_energy_multiplier = 7.0 if dashing else (3.0 if m.afterburn > 0 else 1.0)
	if not m.ko:
		gem_mat.emission_energy_multiplier = 2.0 + 5.0 * clampf(m.heat / 100.0, 0.0, 1.0)
		gem_mat.emission = EYES[team].lerp(Color8(255, 70, 40), clampf((m.heat - 40.0) / 60.0, 0.0, 1.0))
	shield.visible = Sim.shield_up(m)
	if shield.visible:
		shield.rotation.y = -m.act.angle
		shield_mesh.transparency = 0.0 if m.act.t < Sim.perfect_of(m) else 0.35
	bubble.visible = m.buffs.bubble > 0 and m.buffs.bubbleHp > 0
	var winding: bool = m.act != null and m.act.k == "ult" and m.act.ph == "wind" and Sim.ult(m).kind in ["lance", "rail"]
	aim_line.visible = winding
	if winding:
		var length: float = Sim.LANCE.length if Sim.ult(m).kind == "lance" else Sim.ULTS.rail.length
		var full: float = Sim.ult(m).windup
		var p: float = 1.0 - m.act.t / full
		aim_line.scale = Vector3(length, 1.0, 0.25 + 1.2 * p)
		aim_line.position = Vector3(length / 2.0 + Sim.MECH_R, 1.08, 0)
		aim_line.transparency = 0.8 - 0.6 * p
	if fresh:
		strokes.clear()
		live.clear()
	for hand in Sim.HANDS:
		var key: String = m.loadout[hand]
		var r := reach(m, hand)
		var prev: float = shown.get(hand, 0.0)
		var cur := r if r <= prev else lerpf(prev, r, 0.6)
		shown[hand] = cur
		var droop := -0.55 if Sim.jammed(m, Sim.ARM_OF[hand]) else 0.0
		var turn := spin_of(m, hand)
		var turn0: float = turned.get(hand, 0.0)
		turned[hand] = turn
		pose(hand, key, cur, droop)
		torso.rotation.y += turn
		if TRAIL.has(key) and cur > -0.3 and (cur > prev + 0.01 or absf(turn) > absf(turn0) + 0.001 or (key in THRUST and r >= 1.0)):
			streak(hand, key, maxf(prev, -0.3), cur, turn0 if absf(turn) >= absf(turn0) else turn, turn, droop, -m.aim, dt)
		else:
			live.erase(hand)
	draw_trail(dt)
	var flash := 0.0
	if m.stagger > 0 and (tick / 3) % 2 == 0:
		flash = 0.9
	if m.buffs.berserk > 0:
		body_mat.emission = Color(1, 0.15, 0.1) * 0.6
	elif m.buffs.overdrive > 0:
		body_mat.emission = Color(0.7, 0.4, 1.0) * 0.5
	else:
		body_mat.emission = Color(flash, flash, flash)
	if m.ko != dead:
		dead = m.ko
		smoke.emitting = dead
		rotation.z = 0.5 if dead else 0.0
		rotation.x = 0.2 if dead else 0.0
		body_mat.albedo_color = TEAM_DARK[team].darkened(0.3) if dead else TEAM[team]
		gem_mat.emission_energy_multiplier = 0.0
	if fresh and is_inside_tree():
		reset_physics_interpolation()


static func reach(m: Dictionary, hand: String) -> float:
	var a = m.act
	if a == null or a.k != hand:
		return 0.0
	if a.ph == "rec":
		return minf(1.0, a.t / (Sim.recovery_of(m, hand) * 0.55))
	var full: float = Sim.WEAPONS[m.loadout[hand]].gap if a.ph == "combo" else Sim.windup_of(m, hand)
	return -clampf(1.0 - a.t / full, 0.0, 1.0)


func pose(hand: String, key: String, r: float, droop: float) -> void:
	var p: Node3D = hands[hand]
	if Sim.WEAPONS[key].kind != "melee":
		p.rotation = Vector3(0, 0, droop)
		return
	var q := pose_of(hand, key, r, droop)
	p.rotation = q[0]
	p.position.x = q[1]
	held[hand].rotation = q[2]
	torso.rotation.y += q[3]


func spin_of(m: Dictionary, hand: String) -> float:
	var a = m.act
	if a == null or a.k != hand:
		return 0.0
	if a.ph == "wind":
		spun[hand] = a.get("follow", false) and Sim.WEAPONS[m.loadout[hand]].kind == "melee"
	if a.ph != "rec" or not spun.get(hand, false):
		return 0.0
	return (-1.0 if hand == "left" else 1.0) * TAU * clampf((1.0 - a.t / Sim.recovery_of(m, hand)) / 0.5, 0.0, 1.0)


func streak(hand: String, key: String, r0: float, r1: float, sp0: float, sp1: float, droop: float, yaw: float, dt: float) -> void:
	var spinning := sp1 != 0.0
	var thrust := key in THRUST and not spinning
	var edge: Array = TRAIL[key]
	if key in THRUST and spinning:
		edge = [Vector3(edge[0].x - 0.5, 0, 0), Vector3(edge[0].x, 0, 0)]
		if live.has(hand) and not live[hand].spin:
			live.erase(hand)
	var fresh_stroke := not live.has(hand)
	if fresh_stroke:
		live[hand] = {"pts": [], "soft": 1.0 if thrust else 0.0, "spin": spinning}
		strokes.append(live[hand])
	var s := -1.0 if hand == "left" else 1.0
	var n := maxi(1, maxi(ceili(absf(r1 - r0) / 0.08), ceili(absf(sp1 - sp0) / 0.2)))
	for i in range(0 if fresh_stroke else 1, n + 1):
		var t := float(i) / n
		var q := pose_of(hand, key, lerpf(r0, r1, t), droop)
		var tf := global_transform * Transform3D(Basis.from_euler(Vector3(0, yaw + q[3] + lerpf(sp0, sp1, t), 0))) * Transform3D(Basis.from_euler(q[0]), Vector3(q[1], 1.32, s * shoulder)) * Transform3D(Basis.from_euler(q[2]), FIST)
		if thrust and i == 0:
			live[hand].pts.append([tf * (edge[0] - Vector3(TAIL, 0, 0)), tf * (edge[1] - Vector3(TAIL, 0, 0)), TRAIL_LIFE * 0.5])
		live[hand].pts.append([tf * edge[0], tf * edge[1], dt * (n - i) / n])


func draw_trail(dt: float) -> void:
	var im: ImmediateMesh = trail.mesh
	im.clear_surfaces()
	var c: Color = TEAM_LIGHT[team]
	var hot := c.lerp(Color.WHITE, 0.6)
	for st in strokes:
		for pt in st.pts:
			pt[2] += dt
		while not st.pts.is_empty() and st.pts[0][2] > TRAIL_LIFE:
			st.pts.pop_front()
		if st.pts.size() < 2:
			continue
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for pt in st.pts:
			var a: float = 1.0 - pt[2] / TRAIL_LIFE
			im.surface_set_color(Color(c, a * st.soft))
			im.surface_add_vertex(pt[0])
			im.surface_set_color(Color(hot, a))
			im.surface_add_vertex(pt[1])
		im.surface_end()
	strokes = strokes.filter(func(st): return not st.pts.is_empty())


func pose_of(hand: String, key: String, r: float, droop: float) -> Array:
	var back := r < 0
	if key in THRUST:
		return [Vector3(0, 0, droop), r * (0.14 if back else 0.32), Vector3.ZERO, 0.0]
	var s := -1.0 if hand == "left" else 1.0
	var arm: Vector3
	var x: float
	var tool: Vector3
	var twist: float
	if key == "hammer":
		arm = Vector3(0, -0.2 * s, 0.5) if back else Vector3(0, 0.2 * s, -0.25)
		x = -0.05 if back else 0.15
		tool = Vector3(0, -0.2 * s, 1.5) if back else Vector3(0, 0.2 * s, -0.6)
		twist = 0.1
	else:
		arm = Vector3(0, -0.6 * s, 0.1) if back else Vector3(0, 0.45 * s, -0.05)
		x = -0.05 if back else 0.12
		tool = Vector3(0, -1.2 * s, 0.9) if back else Vector3(0, Sim.WEAPONS[key].arc * 0.5 * s, 0.05)
		twist = 0.3
	var k := absf(r)
	return [arm * k + Vector3(0, 0, droop), x * k, Vector3(0, -s * 0.5, 0.6).lerp(tool, k), twist * s * r]
