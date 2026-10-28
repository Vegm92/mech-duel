extends Node3D

const Mech = preload("res://src/mech.gd")
const Fx = preload("res://src/fx.gd")

const KINDS := ["scout", "swarm", "spider", "flyer", "turret", "walker", "tripod", "quadheavy", "heavy", "jugg"]
const SIZE := {"scout": 1.6, "swarm": 0.7, "spider": 1.05, "flyer": 1.55, "turret": 2.05, "walker": 2.45, "tripod": 3.65, "quadheavy": 2.85, "heavy": 4.05, "jugg": 3.05}
const SPLAY := ["spider", "turret", "walker", "tripod"]
const SWING := {"spider": 0.2, "turret": 0.28, "walker": 0.28, "tripod": 0.3}
const HEADING := ["jugg"]
const LIFT := {"flyer": 2.0, "swarm": 0.45}
const ROLL := {"jugg": 1.22, "swarm": 0.36}
const MK := [Color8(118, 121, 128), Color8(78, 81, 90), Color8(44, 44, 50)]
const EYES := [Color8(80, 190, 255), Color8(80, 190, 255), Color8(255, 50, 60)]
const POSE := {"swing": 0.5, "lift": 0.35, "piston": 0.4, "stride": 1.4, "pace": 1.2, "jump": 2.0, "turn": 0.3, "lean": 0.1, "windup": 0.22, "wind_t": 12.0, "lunge": 0.28, "push": 0.12, "recoil": 12.0, "plant": 0.12, "plant_t": 15.0, "shake": 0.14, "hover": 0.15, "float": 0.08, "flash": 6, "die": 45, "sink": 0.35, "tip": 0.6}
const GLOW := {"rest": 3.0, "wind": 9.0, "roll": 6.0}
const NEUTRAL := {"eyes": Color8(255, 165, 40), "rust": Color8(128, 100, 74), "mix": 0.65}
const NAP := {"wake": 30.0, "sink": 0.18, "pitch": 0.12, "roll": 0.28, "spread": 0.3, "droop": 0.35, "kneel": 0.3, "blink": 3, "tilt": 0.35}
const BOOM := {"per_m": 0.55, "min": 0.6, "max": 2.4, "big": 3.0}
const BAR := {"h": 0.12, "y": 0.45, "per_m": 0.35, "min": 0.6, "max": 1.6, "back": Color8(20, 20, 26), "fill": Color8(255, 70, 40)}

var rigs := {}
var pool := {}
var bars := {}
var spare_bars := []
var swarms := {}
var marks := Node3D.new()
var clock := 0.0


func _init() -> void:
	add_child(marks)


## One MultiMesh of swarm cubes per eye look ("lane", "neutral", "off"); the body tint is per cube.
func swarm(look: String) -> Dictionary:
	if not swarms.has(look):
		var mesh: ArrayMesh = Mech.models("bots").swarm[0].duplicate()
		var mats := paints()
		mats.body.vertex_color_use_as_albedo = true
		mats.body.albedo_color = Color.WHITE
		var c: Color = {"lane": EYES[0], "neutral": NEUTRAL.eyes, "off": Mech.DARK}[look]
		mats.glow.albedo_color = c
		mats.glow.emission = c
		mats.glow.emission_energy_multiplier = 0.0 if look == "off" else GLOW.rest
		for i in mesh.get_surface_count():
			mesh.surface_set_material(i, mats[mesh.surface_get_material(i).resource_name])
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mesh
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		add_child(mmi)
		swarms[look] = {"mmi": mmi, "free": [], "used": {}}
	return swarms[look]


static func neutral(e: Dictionary) -> bool:
	return e.get("neutral", false)


static func paint(e: Dictionary) -> Color:
	return MK[e.mk - 1].lerp(NEUTRAL.rust, NEUTRAL.mix) if neutral(e) else MK[e.mk - 1]


static func eyes(e: Dictionary) -> Color:
	return NEUTRAL.eyes if neutral(e) else EYES[e.mk - 1]


## How asleep a bot is: 1 dormant, easing to 0 over a wake.
static func nap(e: Dictionary) -> float:
	match e.act:
		"dormant":
			return 1.0
		"wake":
			return 1.0 - smoothstep(0.0, NAP.wake, e.t)
	return 0.0


## Eyes on (1) or off (0); they flicker through the first half of a wake.
static func lit(e: Dictionary) -> float:
	match e.act:
		"dormant", "die":
			return 0.0
		"wake":
			return 1.0 if e.t >= NAP.wake * 0.5 or (int(e.t) / NAP.blink) % 2 == 1 else 0.0
	return 1.0


## Draws `siege.enemies`; call it once per physics tick.
func sync(siege: Dictionary, dt: float) -> void:
	clock += dt
	var seen := {}
	for e in siege.enemies:
		seen[e.id] = true
		if not rigs.has(e.id):
			rigs[e.id] = take(e)
	for id in rigs.keys():
		if not seen.has(id):
			drop(id)
	for e in siege.enemies:
		var r: Dictionary = rigs[e.id]
		move(r, e, dt)
		if e.kind == "swarm":
			cube(r, e)
		else:
			pose(r, e)
		bar(e)


func paints() -> Dictionary:
	var body := StandardMaterial3D.new()
	body.metallic = Mech.SKIN.body[0]
	body.roughness = Mech.SKIN.body[1]
	body.emission_enabled = true
	body.emission = Color.BLACK
	var glow := StandardMaterial3D.new()
	glow.emission_enabled = true
	glow.emission_energy_multiplier = GLOW.rest
	return {"body": body, "trim": Mech.mat(Mech.STEEL, 0.0, Mech.SKIN.trim[0], Mech.SKIN.trim[1]), "joint": Mech.mat(Mech.DARK, 0.0, Mech.SKIN.joint[0], Mech.SKIN.joint[1]), "glow": glow}


func build(kind: String) -> Dictionary:
	var all := Mech.models("bots")
	var mats := paints()
	var root := Node3D.new()
	add_child(root)
	var lean := Node3D.new()
	root.add_child(lean)
	var r := {"kind": kind, "root": root, "lean": lean, "body": mats.body, "glow": mats.glow, "legs": [], "turret": null, "spin": null, "mk": null}
	Mech.add_part(lean, kind, mats, "bots")
	var names: Array = all.keys().filter(func(n): return n.begins_with(kind + "_"))
	names.sort()
	for n in names:
		var p := Node3D.new()
		p.position = all[n][1]
		lean.add_child(p)
		Mech.add_part(p, n, mats, "bots")
		match n.trim_prefix(kind + "_"):
			"turret":
				r.turret = p
			"spin":
				r.spin = p
			"mk":
				r.mk = p
			var s when s.begins_with("rod"):
				var leg: Array = r.legs[s.trim_prefix("rod").to_int() - 1]
				p.reparent(leg[0], false)
				p.position -= leg[0].position
				leg.append([p, p.position, p.get_child(0).mesh.get_aabb().get_center().normalized()])
			_:
				r.legs.append([p, Vector3(p.position.x, 0, p.position.z).normalized().cross(Vector3.UP).normalized()])
	if r.mk != null and r.turret != null:
		r.mk.reparent(r.turret, false)
		r.mk.position = Vector3.ZERO
	return r


func take(e: Dictionary) -> Dictionary:
	var r: Dictionary
	if e.kind == "swarm":
		r = {"kind": "swarm", "look": "", "slot": -1, "yaw": -e.face, "tumble": 0.0}
	else:
		var spare: Array = pool.get(e.kind, [])
		r = spare.pop_back() if spare.size() else build(e.kind)
		r.root.visible = true
		r.lean.transform = Transform3D.IDENTITY
		r.root.rotation = Vector3(0, -e.face, 0)
		for leg in r.legs:
			leg[0].basis = Basis.IDENTITY
		if r.turret != null:
			r.turret.rotation = Vector3.ZERO
		r.body.emission = Color.BLACK
		if r.mk != null:
			r.mk.visible = e.mk >= 2
	r.merge({"x": e.x, "y": e.y, "hp": e.hp, "speed": 0.0, "walk": 0.0, "flash": 0, "dead": false, "fresh": true, "phase": randf() * TAU}, true)
	return r


func drop(id) -> void:
	var r: Dictionary = rigs[id]
	rigs.erase(id)
	if r.kind == "swarm":
		release(r)
	else:
		r.root.visible = false
		if not pool.has(r.kind):
			pool[r.kind] = []
		pool[r.kind].append(r)
	if bars.has(id):
		bars[id].visible = false
		spare_bars.append(bars[id])
		bars.erase(id)


func release(r: Dictionary) -> void:
	if r.look == "":
		return
	var s: Dictionary = swarms[r.look]
	s.mmi.multimesh.set_instance_transform(r.slot, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
	s.used.erase(r.slot)
	s.free.append(r.slot)
	r.look = ""


func claim(r: Dictionary, look: String) -> void:
	release(r)
	var s := swarm(look)
	if s.free.is_empty():
		var mm: MultiMesh = s.mmi.multimesh
		var n := maxi(mm.instance_count * 2, 32)
		var old: Array = s.used.keys()
		var saved := old.map(func(i): return [mm.get_instance_transform(i), mm.get_instance_color(i)])
		mm.instance_count = n
		for j in old.size():
			mm.set_instance_transform(old[j], saved[j][0])
			mm.set_instance_color(old[j], saved[j][1])
		for i in range(n - 1, -1, -1):
			if not s.used.has(i):
				mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
				s.free.append(i)
	r.slot = s.free.pop_back()
	s.used[r.slot] = true
	r.look = look
	r.fresh = true


func move(r: Dictionary, e: Dictionary, dt: float) -> void:
	var dx: float = e.x - r.x
	var dy: float = e.y - r.y
	var d := sqrt(dx * dx + dy * dy)
	if d > POSE.jump:
		d = 0.0
		r.fresh = true
	r.d = d
	r.dir = atan2(dy, dx) if d > 0.001 else null
	r.x = e.x
	r.y = e.y
	r.speed = lerpf(r.speed, d / dt, 0.2)
	r.walk += d * TAU / (SIZE[e.kind] * POSE.stride)
	if e.hp < r.hp or (e.act == "hit" and e.t == 0):
		r.flash = POSE.flash
	r.hp = e.hp
	r.flash = maxi(r.flash - 1, 0)


func pose(r: Dictionary, e: Dictionary) -> void:
	var h: float = SIZE[e.kind]
	var root: Node3D = r.root
	var lean: Node3D = r.lean
	var t: float = e.t
	var k := clampf(r.speed / POSE.pace, 0.0, 1.0)
	var face := -float(e.face)
	var heading: bool = r.turret != null or e.kind in HEADING
	var turn := 1.0 if r.fresh else POSE.turn
	if heading and r.dir != null and r.speed > 0.3:
		root.rotation.y = lerp_angle(root.rotation.y, -r.dir, turn)
	elif not heading or r.fresh:
		root.rotation.y = lerp_angle(root.rotation.y, face, turn)
	if r.turret != null:
		r.turret.rotation.y = lerp_angle(r.turret.rotation.y, wrapf(face - root.rotation.y, -PI, PI), turn)
	var pitch := -POSE.lean * k
	var roll := 0.0
	var push := 0.0
	var drop := 0.0
	var spread := 0.0
	var glow: float = GLOW.rest
	match e.act:
		"windup":
			var f := minf(t / POSE.wind_t, 1.0)
			pitch = POSE.windup * f
			glow = lerpf(GLOW.rest, GLOW.wind, f)
		"attack":
			var a := maxf(1.0 - t / POSE.recoil, 0.0)
			pitch = -POSE.lunge * a
			push = POSE.push * h * a
		"plant":
			var f := minf(t / POSE.plant_t, 1.0)
			drop = POSE.plant * h * f
			spread = 0.2 * f
			pitch = 0.0
		"hit":
			roll = POSE.shake * sin(t * 1.6) * maxf(1.0 - t / 10.0, 0.0)
		"roll":
			glow = GLOW.roll
	var bob := 0.0
	if LIFT.has(e.kind):
		bob = POSE.hover * sin(clock * 2.5 + r.phase)
		roll += 0.08 * sin(clock * 1.7 + r.phase)
	elif not r.legs.is_empty():
		bob = absf(sin(r.walk)) * 0.025 * h * k
	var z := nap(e)
	if z > 0.0:
		pitch = lerpf(pitch, -NAP.pitch, z)
		roll = lerpf(roll, NAP.roll, z)
		drop = lerpf(drop, NAP.sink * h, z)
		spread = lerpf(spread, NAP.spread, z)
		bob *= 1.0 - z
		k *= 1.0 - z
	if r.turret != null:
		var sag: float = NAP.droop * z
		r.turret.rotation.z = -sag if e.kind == "turret" else 0.0
		r.turret.rotation.x = 0.0 if e.kind == "turret" else sag
	var on := lit(e)
	glow *= on
	r.body.albedo_color = paint(e)
	r.glow.albedo_color = eyes(e).lerp(Mech.DARK, 1.0 - on)
	r.glow.emission = eyes(e)
	if e.act == "die":
		var f := minf(t / POSE.die, 1.0)
		if not r.dead:
			r.dead = true
			blast(e)
		pitch = 0.0
		roll = POSE.tip * f
		drop = POSE.sink * h * f
		r.body.albedo_color = paint(e).darkened(0.75 * f)
		root.visible = t < POSE.die
		k = 0.0
	root.position = Vector3(e.x, LIFT.get(e.kind, 0.0) * (1.0 - z), e.y)
	lean.rotation.z = pitch if r.fresh else lerpf(lean.rotation.z, pitch, 0.35)
	lean.rotation.x = roll
	lean.position = Vector3(push, bob - drop, 0)
	var n: int = r.legs.size()
	for i in n:
		var leg: Array = r.legs[i]
		var ph: float = r.walk + (i * TAU / 3.0 if n == 3 else (i % 2) * PI + floorf(i / 2.0) * 0.4)
		var s: float = sin(ph) * SWING.get(e.kind, POSE.swing) * k
		var up := maxf(cos(ph), 0.0) * k
		if e.kind in SPLAY:
			leg[0].basis = Basis(Vector3.UP, s) * Basis(leg[1], up * POSE.lift + spread)
		else:
			leg[0].rotation.z = s + z * NAP.kneel * (1.0 if i % 2 else -1.0)
		if leg.size() > 2:
			leg[2][0].position = leg[2][1] - leg[2][2] * up * POSE.piston
	if r.spin != null:
		r.spin.rotation.z -= r.d / ROLL[e.kind]
	r.glow.emission_energy_multiplier = glow
	r.body.emission = Color.WHITE * (0.9 * r.flash / POSE.flash)
	if r.fresh:
		r.fresh = false
		root.reset_physics_interpolation()


func cube(r: Dictionary, e: Dictionary) -> void:
	var h: float = SIZE.swarm
	var look := "off" if lit(e) < 0.5 else ("neutral" if neutral(e) else "lane")
	if look != r.look:
		claim(r, look)
	r.yaw = lerp_angle(r.yaw, -float(e.face), 1.0 if r.fresh else POSE.turn)
	var z := nap(e)
	var y: float = (LIFT.swarm + POSE.float * sin(clock * 3.0 + r.phase)) * (1.0 - z) - NAP.sink * h * z
	var s := 1.0
	var c: Color = paint(e)
	if e.act == "roll":
		r.tumble -= r.d / ROLL.swarm
	elif e.act == "windup":
		s = 1.0 + 0.25 * minf(e.t / POSE.wind_t, 1.0)
		c = c.lerp(Color.WHITE, 0.5 * absf(sin(e.t * 0.8)))
	if e.act == "die":
		if not r.dead:
			r.dead = true
			blast(e)
		s = maxf(1.0 - e.t / 8.0, 0.0)
	if r.flash > 0:
		c = Color.WHITE
	var b := Basis(Vector3.UP, r.yaw) * Basis(Vector3.BACK, r.tumble) * Basis(Vector3.RIGHT, NAP.tilt * z)
	var mm: MultiMesh = swarms[r.look].mmi.multimesh
	mm.set_instance_transform(r.slot, Transform3D(b.scaled(Vector3.ONE * s), Vector3(e.x, y + h * 0.5 * (1.0 - s), e.y)))
	mm.set_instance_color(r.slot, c)
	if r.fresh:
		r.fresh = false
		mm.reset_instance_physics_interpolation(r.slot)


func blast(e: Dictionary) -> void:
	var h: float = SIZE[e.kind]
	Fx.boom(self, marks, {"x": e.x, "y": e.y, "r": clampf(h * BOOM.per_m, BOOM.min, BOOM.max), "big": h >= BOOM.big or e.kind == "swarm"})


func bar(e: Dictionary) -> void:
	var show: bool = e.hp < e.max and e.act != "die"
	var b: Node3D = bars.get(e.id)
	if not show:
		if b != null:
			b.visible = false
		return
	var fresh := b == null
	if fresh:
		b = spare_bars.pop_back() if spare_bars.size() else make_bar()
		bars[e.id] = b
	b.visible = true
	var h: float = SIZE[e.kind]
	b.scale = Vector3(clampf(h * BAR.per_m, BAR.min, BAR.max), 1, 1)
	b.position = Vector3(e.x, LIFT.get(e.kind, 0.0) * (1.0 - nap(e)) + h + BAR.y, e.y)
	var f := clampf(float(e.hp) / e.max, 0.0, 1.0)
	var fill: Node3D = b.get_child(1)
	fill.scale.x = maxf(f, 0.001)
	fill.position.x = (f - 1.0) / 2.0
	if fresh:
		b.reset_physics_interpolation()


func make_bar() -> Node3D:
	var b := Node3D.new()
	add_child(b)
	Mech.add(b, Mech.box(Vector3(1, BAR.h, BAR.h)), Mech.flat(BAR.back))
	Mech.add(b, Mech.box(Vector3(1, BAR.h * 1.2, BAR.h * 1.2)), Mech.flat(BAR.fill))
	return b
