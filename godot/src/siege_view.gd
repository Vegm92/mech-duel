extends Node3D

const Sim = preload("res://src/sim.gd")
const Mech = preload("res://src/mech.gd")
const Fx = preload("res://src/fx.gd")
const Look = preload("res://src/look.gd")
const View = preload("res://src/view.gd")

const HALF := 80.0
const FORT := 16.0
const LANES := [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]
const PADS := [26.0, 45.0, 66.0]
const STATIC := ["border", "lanes", "fortress", "plaza"]
const PARTS := ["border", "lanes", "fortress", "plaza", "core_base", "core_crystal", "ring1", "ring2", "ring3", "ring4",
	"gate", "gate_light", "gate_door", "gate_broken", "spawn_gate", "spawn_light", "build_pad", "mod_wall", "mod_mine", "mod_laser"]
const CORE := {"y": 2.8, "spin": 0.35, "bob": 0.12, "glow": 1.6, "flicker": 0.5, "smoke": 0.25, "smoke_size": 2.2,
	"rings": [1.5, 2.2, 2.9, 3.6], "ring_spin": [0.25, -0.35, 0.45, -0.6], "light": 8.0, "light_range": 12.0,
	"mend": [5.9, 6.3], "mend_y": 0.5}
const GATE := {"sink": 2.4, "ease": 0.12, "bar_y": 5.0, "bar": 0.22, "width": 10.0}
const WARN := {"secs": 8, "on": 1.6, "steady": 0.6, "blink": 10}
const VIGNETTE := "smoothstep(0.0, 40.0, length(p - vec2(38.0, 30.0)))"

static var MATS := Look.ARENA.merged({
	"white": Look.neon(Color(0.85, 0.92, 1.0), Look.NEON.cyan),
	"crystal": Mech.glow(Color(0.6, 0.9, 1.0), CORE.glow),
	"shield": Look.neon(Look.PAL.cyan, 1.2),
	"pylon": Look.neon(Look.PAL.cyan, Look.NEON.cyan),
	"warn": Look.neon(Look.PAL.warn, 0.0),
})

var crystal: MeshInstance3D
var crystal_mat: StandardMaterial3D
var core_light: OmniLight3D
var rings := []
var ring_up := [true, true, true, true]
var smoke: CPUParticles3D
var mend: MeshInstance3D
var spawns := []
var gates := []
var pads := []
var tick := 0


static func demo(n := 4) -> Dictionary:
	var hp := maxf(0.25 * n - 0.1, 0.0) * 1000.0
	var s := {
		"tick": 0,
		"wave": {"n": 3, "next_in": 0, "lanes_open": [true, true, true, true]},
		"core": {"x": 0.0, "y": 0.0, "hp": hp, "max": 1000.0, "rings": range(4).map(func(k): return 100.0 if k >= 4 - n else 0.0), "repairing": false},
		"gates": [], "pads": [], "enemies": [],
	}
	for i in 4:
		var d: Vector2 = LANES[i]
		s.gates.append({"lane": i, "x": d.x * FORT, "y": d.y * FORT, "hp": 600.0, "max": 600.0})
		for k in PADS.size():
			s.pads.append({"lane": i, "x": d.x * PADS[k], "y": d.y * PADS[k], "module": ["wall", "mine", "laser"][k] if i == 0 else ""})
	return s


static func yaw(lane: int) -> float:
	return -atan2(LANES[lane].y, LANES[lane].x)


func build(env := true) -> void:
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
	build_floor()
	for p in STATIC:
		Mech.add_part(self, p, MATS, "core_siege")
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
		n.position = Vector3(LANES[i].x * HALF, 0, LANES[i].y * HALF)
		n.rotation.y = yaw(i)
		add_child(n)
		Mech.add_part(n, "spawn_gate", MATS, "core_siege")
		var m: StandardMaterial3D = MATS.warn.duplicate()
		Mech.add_part(n, "spawn_light", MATS.merged({"warn": m}, true), "core_siege").cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		spawns.append(m)
		accent(Vector3(LANES[i].x * (FORT + 3.0), Look.STAGE.accent_y, LANES[i].y * (FORT + 3.0)), Look.PAL.cyan)
	for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		accent(Vector3(c.x * (HALF - 8.0), Look.STAGE.accent_y, c.y * (HALF - 8.0)), Look.PAL.cyan)


func build_floor() -> void:
	var code := View.FLOOR_SHADER.replace(VIGNETTE, "smoothstep(0.0, 90.0, length(p))")
	var sm := Look.shader(code, Look.FLOOR)
	var far := Vector2(1e4, 1e4)
	sm.set_shader_parameter("rings", PackedVector2Array(range(10).map(func(_i): return far)))
	sm.set_shader_parameter("boxes", PackedVector2Array(range(4).map(func(_i): return far)))
	sm.set_shader_parameter("walls", PackedVector3Array(range(8).map(func(i): return Vector3(LANES[i % 4].x, LANES[i % 4].y, HALF))))
	sm.set_shader_parameter("spawns", PackedVector3Array([Vector3(1e4, 1e4, 0), Vector3(1e4, 1e4, 0)]))
	sm.set_shader_parameter("oils", PackedVector3Array([Vector3(1e4, 1e4, 0), Vector3(1e4, 1e4, 0)]))
	var floor := Mech.add(self, Mech.plane(), sm)
	floor.scale = Vector3(HALF * 2 + 2, 1, HALF * 2 + 2)
	var night := StandardMaterial3D.new()
	night.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	night.albedo_color = Look.PAL.void
	Mech.add(self, Mech.box(Vector3(800, 0.1, 800)), night, Vector3(0, -0.08, 0))


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
	Mech.add_part(n, "build_pad", MATS, "core_siege")
	var mods := {}
	for k in ["wall", "mine", "laser"]:
		var mi := Mech.add_part(n, "mod_" + k, MATS, "core_siege")
		mi.visible = false
		mods[k] = mi
	return {"node": n, "mods": mods}


func draw_pad(pv: Dictionary, module: String) -> void:
	for k in pv.mods:
		pv.mods[k].visible = k == module
