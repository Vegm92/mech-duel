extends SceneTree

const Mech = preload("res://src/mech.gd")
const Look = preload("res://src/look.gd")
const SiegeBots = preload("res://src/siege_bots.gd")

const GAME := {"pitch": deg_to_rad(60.0), "fov": 40.0, "dist": 32.0}
const LINEUP := {"pitch": 0.32, "fov": 30.0, "gap": 0.4, "turn": 0.6, "speed": 1.2}
const WIDTH := {"scout": 1.4, "swarm": 1.0, "spider": 2.4, "flyer": 2.6, "turret": 2.4, "walker": 3.2, "tripod": 4.2, "quadheavy": 3.0, "heavy": 3.4, "jugg": 2.6}
const SPEED := {"scout": 3.0, "swarm": 2.5, "spider": 2.4, "flyer": 2.2, "turret": 1.2, "walker": 1.6, "tripod": 1.1, "quadheavy": 0.9, "heavy": 0.9, "jugg": 2.6}
const SIGNATURE := {"turret": "plant", "jugg": "roll"}
const CROWD := {"swarm": 18, "scout": 10, "spider": 8, "flyer": 6, "turret": 4, "walker": 4, "tripod": 3, "quadheavy": 3, "heavy": 2, "jugg": 2}
const FIELD := Vector2(15.0, 10.0)
const CYCLE := {"attack": 40, "windup": 40, "hit": 30, "die": 70, "wake": 70}
const CAMP := ["swarm", "scout", "spider", "turret", "walker", "heavy"]
const ROWS := [["dormant", true], ["idle", true], ["idle", false]]
const SPACE := Vector2(5.5, 7.0)
const PERF := [120, 600]

var bots: SiegeBots
var cam: Camera3D
var siege := {"tick": 0, "enemies": []}
var opt := {"bot": "", "act": "", "shot": "", "at": 90, "mk": 0, "crowd": 0, "perf": false, "neutral": false, "camp": false}
var acts := []
var frame := 0
var acc := {"gpu": 0.0, "cpu": 0.0, "draws": 0.0, "prims": 0.0, "objs": 0.0, "n": 0}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		if kv.size() == 2 and opt.has(kv[0]):
			opt[kv[0]] = kv[1].to_int() if opt[kv[0]] is int else kv[1]
		elif kv[0] in ["perf", "neutral", "camp"]:
			opt[kv[0]] = true
	var w := WorldEnvironment.new()
	w.environment = Look.env()
	root.add_child(w)
	var sun := DirectionalLight3D.new()
	sun.basis = Basis.looking_at(-Look.STAGE.key_from)
	sun.light_energy = Look.STAGE.garage_key
	sun.light_color = Look.STAGE.key_color
	sun.shadow_enabled = true
	root.add_child(sun)
	var floor := Node3D.new()
	root.add_child(floor)
	Mech.add(floor, Mech.box(Vector3(400, 0.1, 400)), Look.paint("floor", Look.PAL.floor), Vector3(0, -0.05, 0))
	bots = SiegeBots.new()
	root.add_child(bots)
	cam = Camera3D.new()
	cam.far = 400.0
	root.add_child(cam)
	if opt.camp:
		for j in ROWS.size():
			for i in CAMP.size():
				add(CAMP[i], Vector2((i - (CAMP.size() - 1) / 2.0) * SPACE.x, (j - 1) * SPACE.y), PI / 2, ROWS[j][0], 1, 1.0, ROWS[j][1])
	elif opt.crowd > 0:
		crowd(opt.crowd)
	elif opt.bot != "":
		add(opt.bot, Vector2.ZERO, PI / 2 + LINEUP.turn)
	else:
		var x := 0.0
		for kind in SiegeBots.KINDS:
			x += WIDTH[kind] / 2.0
			add(kind, Vector2(x, 0), PI / 2 + LINEUP.turn)
			x += WIDTH[kind] / 2.0 + LINEUP.gap
		for e in siege.enemies:
			e.x -= (x - LINEUP.gap) / 2.0
	if opt.perf:
		RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	RenderingServer.frame_post_draw.connect(drawn)


func add(kind: String, at: Vector2, face: float, act := "", mk := 0, hp := 1.0, calm := false) -> void:
	var i: int = siege.enemies.size()
	var a: String = opt.act if opt.act != "" else (act if act != "" else SIGNATURE.get(kind, "walk"))
	siege.enemies.append({"id": i, "kind": kind, "lane": 0, "x": at.x, "y": at.y, "face": face, "hp": 100.0 * hp, "max": 100.0, "act": a, "t": 0, "mk": mk if mk > 0 else maxi(opt.mk, 1), "neutral": calm or opt.neutral})
	acts.append(a)


func crowd(n: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var kinds := []
	for kind in CROWD:
		for i in CROWD[kind]:
			kinds.append(kind)
	var cluster := Vector2.ZERO
	for i in n:
		var kind: String = kinds[i % kinds.size()]
		var at := Vector2(rng.randf_range(-FIELD.x, FIELD.x), rng.randf_range(-FIELD.y, FIELD.y))
		if kind == "swarm":
			if i % 6 == 0:
				cluster = at
			at = cluster + Vector2(rng.randf_range(-1.2, 1.2), rng.randf_range(-1.2, 1.2))
		var act: String = ["walk", "walk", "walk", "windup", "attack", "hit"][i % 6] if not SIGNATURE.has(kind) else SIGNATURE[kind]
		add(kind, at, PI / 2 + rng.randf_range(-0.4, 0.4), act, 1 + i % 3, 1.0 if i % 2 else rng.randf_range(0.25, 0.9))


func _physics_process(dt: float) -> bool:
	siege.tick += 1
	for i in siege.enemies.size():
		var e: Dictionary = siege.enemies[i]
		var a: String = acts[i]
		var cyc: int = CYCLE.get(a, 0)
		e.t = siege.tick % cyc if cyc else siege.tick
		if a == "die" and e.t == 0:
			e.id += 1000
		if a == "hit" and e.t == 0:
			e.hp = e.max if e.hp <= e.max * 0.3 else e.hp - e.max * 0.15
		if a in ["walk", "roll"]:
			var v: float = LINEUP.speed if opt.crowd == 0 else SPEED[e.kind]
			e.x += cos(e.face) * v * dt
			e.y += sin(e.face) * v * dt
			if opt.crowd > 0 and e.y > FIELD.y + 2.0:
				e.y -= 2.0 * FIELD.y + 4.0
	bots.sync(siege, dt)
	aim()
	return false


func aim() -> void:
	if opt.crowd > 0 or opt.camp:
		cam.fov = GAME.fov
		cam.position = Vector3(0, sin(GAME.pitch), cos(GAME.pitch)) * GAME.dist
		cam.rotation = Vector3(-GAME.pitch, 0, 0)
		return
	var e: Dictionary = siege.enemies[0]
	var at := Vector3(e.x, 0, e.y)
	var h: float = SiegeBots.SIZE[opt.bot] if opt.bot != "" else 2.6
	var dist := h * 2.4 + 1.6
	if opt.bot == "":
		at = Vector3((siege.enemies[0].x + siege.enemies[-1].x) / 2.0, 0, e.y)
		dist = 36.0
	elif opt.bot == "flyer":
		at.y += SiegeBots.LIFT.flyer
	cam.fov = LINEUP.fov
	cam.position = at + Vector3(0, h * 0.5 + sin(LINEUP.pitch) * dist, cos(LINEUP.pitch) * dist)
	cam.look_at(at + Vector3(0, h * 0.5, 0))


func _process(_dt: float) -> bool:
	frame += 1
	if opt.perf and frame > PERF[0]:
		var rid := root.get_viewport_rid()
		acc.gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
		acc.cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid) + RenderingServer.get_frame_setup_time_cpu()
		acc.draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		acc.prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		acc.objs += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		acc.n += 1
		if frame > PERF[1]:
			var n: float = acc.n
			print("PERF enemies=%d frames=%d gpu_ms=%.2f render_cpu_ms=%.2f draws=%d prims=%d objects=%d nodes=%d" % [siege.enemies.size(), acc.n, acc.gpu / n, acc.cpu / n, acc.draws / n, acc.prims / n, acc.objs / n, Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
			quit()
	return false


func drawn() -> void:
	if opt.shot != "" and frame >= opt.at:
		root.get_texture().get_image().save_png(opt.shot)
		quit()
