extends Node3D

const Sim = preload("res://src/sim.gd")

static var TEAM := [Color8(255, 122, 47), Color8(79, 157, 255), Color8(86, 214, 96), Color8(214, 84, 230)]
static var TEAM_LIGHT := [Color8(255, 196, 150), Color8(170, 210, 255), Color8(180, 245, 172), Color8(242, 178, 250)]
static var TEAM_DARK := [Color8(110, 40, 10), Color8(20, 55, 115), Color8(22, 88, 30), Color8(84, 24, 100)]
static var EYES := [Color8(255, 214, 120), Color8(150, 235, 255), Color8(215, 255, 150), Color8(255, 175, 245)]
static var BOOST_C := {"arc": Color8(150, 205, 255), "flame": Color8(255, 150, 60), "frost": Color8(170, 240, 255), "smoke": Color8(190, 190, 200), "magnet": Color8(205, 125, 255), "clean": Color8(255, 232, 170)}
static var STEEL := Color8(170, 180, 198)
static var DARK := Color8(44, 48, 58)
static var _mats := {}
static var _meshes := {}
static var _glb := {}

const TO_X := Vector3(0, 0, -PI / 2)
const TO_Z := Vector3(PI / 2, 0, 0)
const ARM_UP := 0.2
const ELBOW := Vector3(0.048, -0.235, 0)
const FIST := Vector3(0.438, -0.235, 0)
const MOUNT := {"rivet": "arm", "scatter": "arm", "gatling": "arm", "tesla": "arm", "flamer": "shoulder", "missiles": "shoulder", "mortar": "shoulder"}

var team := 0
var body_mat: StandardMaterial3D
var gem_mat: StandardMaterial3D
var boost_mat: StandardMaterial3D
var torso: Node3D
var hips: Node3D
var hands := {}
var hand_dead := {}
var legs_kind := ""
var swing := []
var spin := []
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


static func add_part(parent: Node3D, part: String, mats: Dictionary, file := "light") -> MeshInstance3D:
	if not _glb.has(file):
		var s: Node = load("res://assets/models/%s.glb" % file).instantiate()
		var meshes := {}
		for c in s.get_children():
			meshes[String(c.name)] = c.mesh
		s.free()
		_glb[file] = meshes
	var mi := MeshInstance3D.new()
	mi.mesh = _glb[file][part]
	for i in mi.mesh.get_surface_count():
		mi.set_surface_override_material(i, mats[mi.mesh.surface_get_material(i).resource_name])
	parent.add_child(mi)
	return mi


static func weapon_node(name: String, t: int, mats: Dictionary) -> Node3D:
	var n := Node3D.new()
	if Sim.WEAPONS[name].kind != "melee":
		add_part(n, name, mats, "guns")
		return n
	var steel := mat(STEEL, 0.0, 0.55, 0.5)
	var dark := mat(DARK, 0.0, 0.5, 0.5)
	var hot := glow(TEAM_LIGHT[t], 1.6)
	match name:
		"saw":
			add(n, box(Vector3(0.6, 0.16, 0.16)), dark, Vector3(0.3, 0, 0))
			var disc := Node3D.new()
			disc.position = Vector3(0.75, 0, 0)
			n.add_child(disc)
			add(disc, cyl(0.48, 0.48, 0.05, 16), steel)
			add(disc, ring(0.4, 0.5), hot, Vector3.ZERO)
			disc.set_meta("spin", true)
		"drill":
			add(n, cyl(0.16, 0.16, 0.3), dark, Vector3(0.1, 0, 0), TO_X)
			add(n, cyl(0.0, 0.2, 1.0, 8), steel, Vector3(0.75, 0, 0), TO_X)
		"hammer":
			add(n, cyl(0.05, 0.05, 0.9), dark, Vector3(0.45, 0, 0), TO_X)
			add(n, box(Vector3(0.36, 0.42, 0.62)), steel, Vector3(0.9, 0, 0))
			add(n, box(Vector3(0.38, 0.08, 0.64)), hot, Vector3(0.9, 0.0, 0))
		"claws":
			add(n, box(Vector3(0.3, 0.24, 0.3)), dark, Vector3(0.1, 0, 0))
			for i in 3:
				add(n, box(Vector3(0.7, 0.05, 0.05)), steel, Vector3(0.55, 0, -0.12 + i * 0.12), Vector3(0, (i - 1) * 0.25, 0))
		"whip":
			for i in 6:
				add(n, box(Vector3(0.3, 0.06, 0.06)), steel, Vector3(0.2 + i * 0.27, 0, sin(i * 1.2) * 0.06))
			add(n, ball(0.08, 8), hot, Vector3(1.85, 0, 0))
		"bunker":
			add(n, box(Vector3(0.5, 0.36, 0.36)), dark, Vector3(0.15, 0, 0))
			add(n, cyl(0.0, 0.14, 0.8, 8), steel, Vector3(0.75, 0, 0), TO_X)
		"katana":
			add(n, box(Vector3(0.22, 0.12, 0.12)), dark, Vector3(0.05, 0, 0))
			add(n, box(Vector3(1.3, 0.14, 0.03)), steel, Vector3(0.8, 0, 0))
			add(n, box(Vector3(1.3, 0.03, 0.035)), hot, Vector3(0.8, -0.07, 0))
		"bash":
			add(n, box(Vector3(0.14, 0.85, 0.95)), steel, Vector3(0.4, 0, 0))
			add(n, box(Vector3(0.16, 0.1, 0.8)), hot, Vector3(0.42, 0.15, 0))
		"fist":
			add(n, box(Vector3(0.3, 0.3, 0.3)), dark, Vector3(0.1, 0, 0))
			add(n, box(Vector3(0.55, 0.5, 0.5)), steel, Vector3(0.5, 0, 0))
			add(n, box(Vector3(0.1, 0.4, 0.42)), hot, Vector3(0.79, 0, 0))
		"flail":
			add(n, cyl(0.05, 0.05, 0.6), dark, Vector3(0.3, 0, 0), TO_X)
			add(n, box(Vector3(0.45, 0.04, 0.04)), steel, Vector3(0.8, 0, 0))
			add(n, ball(0.24), steel, Vector3(1.15, 0, 0))
			add(n, ring(0.18, 0.28), hot, Vector3(1.15, 0, 0))
	return n


func build(lo: Dictionary, t: int) -> void:
	team = t
	body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = TEAM[t]
	body_mat.metallic = 0.3
	body_mat.roughness = 0.5
	body_mat.emission_enabled = true
	body_mat.emission = Color.BLACK
	gem_mat = StandardMaterial3D.new()
	gem_mat.albedo_color = EYES[t]
	gem_mat.emission_enabled = true
	gem_mat.emission = EYES[t]
	gem_mat.emission_energy_multiplier = 3.0
	boost_mat = StandardMaterial3D.new()
	var bc: Color = BOOST_C[Sim.BOOSTERS[lo.booster].trail]
	boost_mat.albedo_color = bc
	boost_mat.emission_enabled = true
	boost_mat.emission = bc
	var trim := mat(STEEL, 0.0, 0.55, 0.5)
	var joint := mat(DARK, 0.0, 0.4, 0.6)
	var eye := glow(EYES[t], 5.0)
	var parts := {"body": body_mat, "trim": trim, "joint": joint, "gem": gem_mat, "boost": boost_mat}
	var gun_mats := parts.merged({"glow": glow(TEAM_LIGHT[t], 1.6), "flame": glow(Color8(255, 150, 60), 5.0), "laser": glow(Color8(255, 80, 120), 6.0), "arc": glow(Color8(170, 210, 255), 4.0), "bounce": glow(Color8(120, 255, 150), 4.0)})
	hips = Node3D.new()
	add_child(hips)
	torso = Node3D.new()
	add_child(torso)
	build_legs(lo.legs, joint, trim)
	add_part(hips, "Hips", parts)
	add_part(torso, "Chest", parts)
	build_head(lo.head, eye, trim, parts)
	for hand in Sim.HANDS:
		var side := -1.0 if hand == "left" else 1.0
		var p := Node3D.new()
		p.position = Vector3(0, 1.32, side * 0.41)
		torso.add_child(p)
		var s := "_L" if hand == "left" else "_R"
		add_part(p, "UpperArm" + s, parts).rotation.z = ARM_UP
		var fore := add_part(p, "Forearm" + s, parts)
		fore.position = ELBOW
		fore.rotation.z = PI / 2
		var mount: String = MOUNT.get(lo[hand], "hand")
		fore.visible = mount != "arm"
		var w := weapon_node(lo[hand], t, gun_mats)
		w.position = ELBOW if mount == "arm" else (Vector3(0, 0.15, side * 0.02) if mount == "shoulder" else FIST)
		if Sim.WEAPONS[lo[hand]].kind == "melee":
			w.rotation = Vector3(0, -side * 0.5, 0.6)
		p.add_child(w)
		for c in w.get_children():
			if c.has_meta("spin"):
				spin.append(c)
		hands[hand] = p
		hand_dead[hand] = false
	shield = Node3D.new()
	add_child(shield)
	shield_mesh = add(shield, box(Vector3(0.12, 1.4, 2.3)), glow(Color8(120, 190, 255), 2.5, 0.55), Vector3(1.25, 1.05, 0))
	shield.visible = false
	bubble = add(self, ball(1.35, 20), glow(Color8(110, 170, 255), 1.2, 0.18), Vector3(0, 1.0, 0))
	bubble.visible = false
	aim_line = add(torso, box(Vector3(1, 0.06, 1)), glow(Color8(255, 190, 90), 4.0, 0.6), Vector3(0, 1.08, 0))
	aim_line.visible = false
	smoke = CPUParticles3D.new()
	smoke.amount = 28
	smoke.lifetime = 1.8
	smoke.emitting = false
	smoke.direction = Vector3.UP
	smoke.spread = 20.0
	smoke.initial_velocity_min = 0.8
	smoke.initial_velocity_max = 2.0
	smoke.gravity = Vector3(0.3, 0.8, 0)
	smoke.scale_amount_min = 0.5
	smoke.scale_amount_max = 1.5
	smoke.mesh = ball(0.35, 8)
	smoke.material_override = mat(Color(0.12, 0.12, 0.14, 0.6), 0.0, 0.0, 1.0)
	smoke.position = Vector3(0, 1.2, 0)
	add_child(smoke)


func build_head(kind: String, eye: Material, trim: Material, parts: Dictionary) -> void:
	var base := Node3D.new()
	base.position = Vector3(0, 1.44, 0)
	torso.add_child(base)
	add_part(base, "Head", parts)
	var h := Node3D.new()
	h.position = Vector3(0, 0.33, 0)
	h.scale = Vector3.ONE * 1.1
	base.add_child(h)
	match kind:
		"demon":
			for s in [-1, 1]:
				add(h, cyl(0.0, 0.07, 0.45, 8), trim, Vector3(0.05, 0.32, s * 0.2), Vector3(s * 0.4, 0, -0.3))
		"antenna":
			add(h, cyl(0.02, 0.02, 0.7, 6), trim, Vector3(-0.1, 0.5, 0.15))
			add(h, ball(0.06, 8), eye, Vector3(-0.1, 0.86, 0.15))
		"crest":
			add(h, box(Vector3(0.5, 0.18, 0.06)), trim, Vector3(-0.05, 0.27, 0), Vector3(0, 0, 0.3))
		"dish":
			add(h, cyl(0.25, 0.05, 0.08, 12), trim, Vector3(-0.15, 0.3, -0.2), Vector3(0.5, 0, 0.3))
		"pincer":
			for s in [-1, 1]:
				add(h, box(Vector3(0.35, 0.08, 0.06)), trim, Vector3(0.32, -0.12, s * 0.15), Vector3(0, s * 0.3, 0))
		"medic":
			add(h, box(Vector3(0.12, 0.3, 0.1)), glow(Color8(90, 255, 150), 3.0), Vector3(0, 0.25, 0))
			add(h, box(Vector3(0.12, 0.1, 0.3)), glow(Color8(90, 255, 150), 3.0), Vector3(0, 0.25, 0))
		"dispenser":
			add(h, cyl(0.1, 0.1, 0.25, 8), trim, Vector3(-0.1, 0.28, 0))


func build_legs(kind: String, joint: Material, trim: Material) -> void:
	legs_kind = kind
	match kind:
		"treads":
			for s in [-1, 1]:
				add(hips, box(Vector3(1.5, 0.5, 0.38)), joint, Vector3(0, 0.28, s * 0.5))
				add(hips, box(Vector3(1.3, 0.1, 0.4)), trim, Vector3(0, 0.56, s * 0.5))
		"wheels":
			for s in [-1, 1]:
				var w := Node3D.new()
				w.position = Vector3(0, 0.42, s * 0.58)
				hips.add_child(w)
				add(w, cyl(0.42, 0.42, 0.24, 16), joint, Vector3.ZERO, TO_Z)
				add(w, box(Vector3(0.5, 0.1, 0.26)), trim)
				spin.append(w)
		"mono":
			var w := Node3D.new()
			w.position = Vector3(0, 0.6, 0)
			hips.add_child(w)
			add(w, cyl(0.6, 0.6, 0.44, 18), joint, Vector3.ZERO, TO_Z)
			add(w, box(Vector3(0.9, 0.12, 0.46)), trim)
			spin.append(w)
		"hover":
			add(hips, cyl(0.85, 0.65, 0.26, 16), trim, Vector3(0, 0.42, 0))
			add(hips, cyl(0.6, 0.6, 0.06, 16), boost_mat, Vector3(0, 0.27, 0))
		"spider", "quad":
			for i in 4:
				var sx := 1.0 if i < 2 else -1.0
				var sz := 1.0 if i % 2 == 0 else -1.0
				var p := Node3D.new()
				p.position = Vector3(sx * 0.3, 0.78, sz * 0.32)
				p.rotation = Vector3(-sz * 0.6, 0, sx * 0.35)
				hips.add_child(p)
				add(p, box(Vector3(0.16, 0.95, 0.16)), joint, Vector3(0, -0.42, 0))
				add(p, box(Vector3(0.22, 0.14, 0.22)), trim, Vector3(0, -0.88, 0))
				swing.append(p)
		_:
			var k := 1.35 if kind == "stompers" else (0.8 if kind == "skates" else 1.0)
			for s in [-1, 1]:
				var p := Node3D.new()
				p.position = Vector3(0, 0.8, s * 0.18)
				hips.add_child(p)
				add_part(p, "Leg_L" if s < 0 else "Leg_R", {"body": body_mat, "trim": trim, "joint": joint}).scale = Vector3(k, 1, k)
				if kind == "jets":
					add(p, cyl(0.07, 0.1, 0.18, 10), boost_mat, Vector3(-0.2, -0.45, 0))
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
	var k := minf(sp / 6.0, 1.0)
	for i in swing.size():
		swing[i].rotation.z = sin(walk + i * PI * (0.5 if swing.size() == 4 else 1.0)) * 0.55 * k
	for w in spin:
		if w.get_parent() == hips:
			w.rotation.z -= sp * dt / 0.5
		else:
			w.rotation.y += dt * 18.0
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
	for hand in Sim.HANDS:
		var j := Sim.jammed(m, Sim.ARM_OF[hand])
		if j != hand_dead[hand]:
			hand_dead[hand] = j
			hands[hand].rotation.z = -0.55 if j else 0.0
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
