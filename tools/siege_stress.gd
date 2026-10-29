extends SceneTree

const Sim = preload("res://src/sim.gd")
const Siege = preload("res://src/siege.gd")
const KINDS := ["scout", "swarm", "spider", "flyer", "turret", "walker", "tripod", "heavy", "scout", "spider"]

var main: Node
var from := 20
var step := 10
var top := 200
var hold := 240
var target := 0
var ticks := 0
var acc := {}
var frames := 0
var frame_worst := 0.0
var last_us := 0
var spawned := 0
var since := 0
var spike_tick := 0


func arg(name: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + name + "="):
			return a.substr(name.length() + 3)
	return fallback


func _initialize() -> void:
	from = arg("from", "20").to_int()
	step = arg("step", "10").to_int()
	top = arg("top", "200").to_int()
	hold = arg("hold", "240").to_int()
	target = from
	if arg("steps", "") != "":
		Engine.max_physics_steps_per_frame = arg("steps", "8").to_int()
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	print("STRESS from=%d step=+%d every %d ticks top=%d (budget per tick 16.7 ms)" % [from, step, hold, top])


func lap(k: String, t0: int) -> int:
	var t := Time.get_ticks_usec()
	acc[k] = acc.get(k, 0.0) + (t - t0) / 1000.0
	return t


func lane_bots(sg: Dictionary) -> int:
	var n := 0
	for e in sg.enemies:
		if e.act != "die" and not e.neutral:
			n += 1
	return n


func refill(state: Dictionary) -> void:
	var sg: Dictionary = state.siege
	sg.wave.next_in = 1 << 30
	sg.core.hp = sg.core.max
	for i in sg.team:
		state.mechs[i].armor = state.mechs[i].max.duplicate()
	var n := lane_bots(sg)
	while n < target:
		var kind: String = KINDS[spawned % KINDS.size()]
		if arg("near", "0") == "1":
			var me = state.mechs[0]
			var a := spawned * 2.39996
			var d := 8.0 + fmod(spawned * 3.7, 16.0)
			Siege.spawn(state, kind, spawned % 4, 0.0, 1, {"x": me.x + cos(a) * d, "y": me.y + sin(a) * d * 0.6})
		else:
			Siege.spawn(state, kind, spawned % 4, fmod(spawned * 1.7, 6.0) - 3.0)
		spawned += 1
		n = lane_bots(sg)


func _physics_process(delta: float) -> bool:
	if main == null or not (main.get("state") is Dictionary) or not main.state.has("siege") or main.garage.visible:
		return false
	var state: Dictionary = main.state
	var sg: Dictionary = state.siege
	refill(state)
	if arg("own", "1") == "0":
		ticks += 1
		if ticks % hold == 0:
			report(state)
			target += step
			if target > top:
				quit()
		return false
	if main.is_physics_processing():
		main.set_physics_process(false)
	var t := Time.get_ticks_usec()
	for i in main.seats.size():
		main.seats[i].aim = main.aim_point(i)
	var ins := []
	for i in sg.team:
		ins.append(Siege.ally_input(state, main.pilot if i == 0 else main.allies[i], i))
	t = lap("ally_ai", t)
	t = timed_step(state, ins, t)
	if arg("hide", "") == "fxspawn":
		for f in state.fx:
			f["seen"] = true
	main.view.sync(state, main.aim, delta, main.seats.slice(1).map(func(s): return s.aim))
	t = lap("view.sync", t)
	main.siege_view.update(sg)
	t = lap("siege_view", t)
	t = bots_sync(main.siege_bots, sg, delta, t)
	main.track()
	main.crowd_sound.update(main.view.fresh_fx, 0.0, false, true)
	main.sfx.update(state, main.view.fresh_fx, false)
	t = lap("sound", t)
	acc["fx_events"] = acc.get("fx_events", 0.0) + main.view.fresh_fx.size()
	for f in main.view.fresh_fx:
		var key: String = "fx:" + f.k + ("@bot" if f.has("id") and f.id is int and f.id < state.mechs.size() and state.mechs[f.id].has("bot") else ("@you" if f.has("id") else ""))
		acc[key] = acc.get(key, 0.0) + 1
	main.view.fresh_fx = []
	main.view.shake = 0.0
	main.view.kick = Vector3.ZERO
	main.view.stop = 0
	ticks += 1
	if ticks % hold == 0:
		report(state)
		target += step
		if target > top:
			quit()
	return false


func bots_sync(sb, siege: Dictionary, dt: float, t: int) -> int:
	sb.clock += dt
	var seen := {}
	for e in siege.enemies:
		seen[e.id] = true
		if not sb.rigs.has(e.id):
			sb.rigs[e.id] = sb.take(e)
	for id in sb.rigs.keys():
		if not seen.has(id):
			sb.drop(id)
	t = lap("bots.take_drop", t)
	for e in siege.enemies:
		sb.move(sb.rigs[e.id], e, dt)
	t = lap("bots.move", t)
	for e in siege.enemies:
		if e.kind == "swarm":
			sb.cube(sb.rigs[e.id], e)
	t = lap("bots.cube", t)
	for e in siege.enemies:
		if e.kind != "swarm":
			sb.pose(sb.rigs[e.id], e)
	t = lap("bots.pose", t)
	for e in siege.enemies:
		sb.bar(e)
	t = lap("bots.bar", t)
	return t


func timed_step(state: Dictionary, ins: Array, t: int) -> int:
	var sg: Dictionary = state.siege
	state.tick += 1
	sg.tick = state.tick
	Sim.age_fx(state)
	state.hitstop = 0
	for i in sg.team:
		if not state.mechs[i].ko:
			Sim.think(state, state.mechs[i], ins[i])
	var gm = state.mechs[sg.guard]
	if not gm.ko:
		Sim.think(state, gm, Siege.guard_input(state, sg))
	for i in sg.team:
		Siege.use(state, sg, i, false)
		Siege.recall(state, sg, i, false)
	t = lap("rules.players", t)
	Siege.modules(state, sg)
	Siege.hazards(state, sg)
	t = lap("rules.traps", t)
	for e in sg.enemies:
		if e.act != "die":
			Siege.drive(state, sg, e, state.mechs[e.m])
	t = lap("rules.enemy_ai", t)
	Siege.shell_land(state, sg)
	Sim.world(state)
	t = lap("rules.world", t)
	var live := []
	for m in state.mechs:
		if not m.ko and not m.get("fly", false) and not m.get("sleep", false):
			Sim.collide(m, 0.0, state.geo)
			live.append(m)
	t = lap("rules.collide", t)
	Siege.push_apart(live)
	t = lap("rules.separate", t)
	Siege.settle(state, sg)
	Siege.sense(state, sg)
	Siege.direct(state, sg)
	t = lap("rules.settle", t)
	return t


func hide_pass(n: Node, mode: String) -> void:
	if mode == "particles" and n is CPUParticles3D:
		(n as CPUParticles3D).visible = false
	if mode == "shadows" and n is DirectionalLight3D:
		(n as DirectionalLight3D).shadow_enabled = false
	for k in n.get_children():
		hide_pass(k, mode)


func _process(_dt: float) -> bool:
	var mode := arg("hide", "none")
	if mode == "bots" and main != null and main.get("siege_bots") != null:
		main.siege_bots.visible = false
	elif mode == "interp":
		physics_interpolation = false
	elif mode == "botshadow" and main != null and Engine.get_process_frames() % 30 == 0:
		for n in main.siege_bots.find_children("*", "GeometryInstance3D", true, false):
			(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	elif mode == "sharemat" and main != null and Engine.get_process_frames() % 30 == 0:
		var one := {}
		for mi in main.siege_bots.find_children("*", "MeshInstance3D", true, false):
			for i in (mi as MeshInstance3D).get_surface_override_material_count():
				var m = mi.get_surface_override_material(i)
				if m == null:
					continue
				var key: String = m.resource_name if m.resource_name != "" else str(i)
				if not one.has(key):
					one[key] = m.duplicate()
				mi.set_surface_override_material(i, one[key])
	elif mode == "legs" and main != null:
		for r in main.siege_bots.rigs.values():
			for leg in r.get("legs", []):
				leg[0].visible = false
	elif mode == "bars" and main != null:
		for b in main.siege_bots.bars.values():
			b.visible = false
	elif mode == "hud" and main != null:
		main.hud.visible = false
	elif mode == "sound" and main != null:
		main.sfx.set_process(false)
		main.crowd_sound.set_process(false)
	elif mode in ["particles", "shadows"] and Engine.get_process_frames() % 2 == 0:
		hide_pass(root, mode)
	var now := Time.get_ticks_usec()
	if last_us > 0:
		frame_worst = maxf(frame_worst, (now - last_us) / 1000.0)
		if arg("spikes", "0") == "1" and (now - last_us) / 1000.0 > 40.0 and main != null and main.get("siege_bots") != null:
			var sb = main.siege_bots
			var inst := 0
			for b in sb.batches.values():
				inst += b.mm.instance_count
			var pooled := 0
			for k in sb.pool:
				pooled += sb.pool[k].size()
			print("SPIKE %.1f ms tick=%d ticks_this_frame=%d rigs=%d pooled=%d batch_slots=%d nodes=%d fx=%d" % [(now - last_us) / 1000.0, main.state.tick, main.state.tick - spike_tick, sb.rigs.size(), pooled, inst, Performance.get_monitor(Performance.OBJECT_NODE_COUNT), main.state.fx.size()])
	if main != null and main.get("state") is Dictionary and main.state.has("tick"):
		spike_tick = main.state.tick
	last_us = now
	frames += 1
	var rid := root.get_viewport_rid()
	acc["gpu"] = acc.get("gpu", 0.0) + RenderingServer.viewport_get_measured_render_time_gpu(rid)
	acc["render_cpu"] = acc.get("render_cpu", 0.0) + RenderingServer.viewport_get_measured_render_time_cpu(rid) + RenderingServer.get_frame_setup_time_cpu()
	acc["draws"] = acc.get("draws", 0.0) + Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	acc["process"] = acc.get("process", 0.0) + Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	acc["physics"] = acc.get("physics", 0.0) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	return false


func count_particles(n: Node) -> int:
	var c := 1 if n is CPUParticles3D and (n as CPUParticles3D).emitting and n.is_visible_in_tree() else 0
	for k in n.get_children():
		c += count_particles(k)
	return c


func report(state: Dictionary) -> void:
	var shot := arg("shot", "")
	if shot != "" and not FileAccess.file_exists(shot):
		root.get_viewport().get_texture().get_image().save_png(shot)
		print("SHOT ", shot)
	var tick_keys := ["ally_ai", "rules.players", "rules.traps", "rules.enemy_ai", "rules.world", "rules.collide", "rules.separate", "rules.settle", "view.sync", "siege_view", "bots.take_drop", "bots.move", "bots.cube", "bots.pose", "bots.bar", "sound"]
	var per_tick := 0.0
	var parts := []
	for k in tick_keys:
		var v: float = acc.get(k, 0.0) / hold
		per_tick += v
		parts.append("%s=%.2f" % [k, v])
	var f := maxf(1.0, frames)
	var now := Time.get_ticks_usec()
	var frame_avg := (now - since) / 1000.0 / f if since > 0 else 0.0
	since = now
	var seen := 0
	for e in state.siege.enemies:
		if e.act != "die" and main.cam.is_position_in_frustum(Vector3(e.x, 0.5, e.y)):
			seen += 1
	print("BOTS=%d on_screen=%d frame_avg_ms=%.2f mechs=%d tick_ms=%.2f %s | fps=%d frame_worst_ms=%.1f gpu_ms=%.2f render_cpu_ms=%.2f process_ms=%.2f physics_ms=%.2f draws=%d | shots=%d lobs=%d fx_per_tick=%.1f particles=%d nodes=%d" % [
		lane_bots(state.siege), seen, frame_avg, state.mechs.size(), per_tick, " ".join(parts),
		Engine.get_frames_per_second(), frame_worst, acc.get("gpu", 0.0) / f, acc.get("render_cpu", 0.0) / f, acc.get("process", 0.0) / f, acc.get("physics", 0.0) / f, acc.get("draws", 0.0) / f,
		state.shots.size(), state.lobs.size(), acc.get("fx_events", 0.0) / hold, count_particles(root), Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	if arg("fxcount", "0") == "1":
		var kinds := acc.keys().filter(func(k): return String(k).begins_with("fx:"))
		kinds.sort_custom(func(a, b): return acc[a] > acc[b])
		print("FX per second: " + ", ".join(kinds.slice(0, 12).map(func(k): return "%s=%.1f" % [k.substr(3), acc[k] / hold * 60.0])))
	acc.clear()
	frames = 0
	frame_worst = 0.0
