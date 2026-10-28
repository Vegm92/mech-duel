extends SceneTree

const Mech = preload("res://src/mech.gd")
const SiegeBots = preload("res://src/siege_bots.gd")

const LEGS := {"scout": 2, "swarm": 0, "spider": 6, "flyer": 0, "turret": 4, "walker": 4, "tripod": 3, "quadheavy": 0, "heavy": 2, "jugg": 0}
const RODS := {"tripod": 3}
const TURRET := ["turret", "tripod", "quadheavy", "heavy"]
const SPIN := ["jugg"]
const MATS := ["body", "trim", "joint", "glow"]
const DT := 1.0 / 60.0

var failed := 0


func _process(_dt: float) -> bool:
	models()
	view()
	print("FAILED" if failed else "ALL PASSED")
	quit(1 if failed else 0)
	return true


func models() -> void:
	var all := Mech.models("bots")
	var known := {}
	for kind in SiegeBots.KINDS:
		var names: Array = all.keys().filter(func(n): return n == kind or n.begins_with(kind + "_"))
		var legs := names.filter(func(n): return n.begins_with(kind + "_leg"))
		var want := [kind] + range(1, LEGS[kind] + 1).map(func(i): return "%s_leg%d" % [kind, i]) + range(1, RODS.get(kind, 0) + 1).map(func(i): return "%s_rod%d" % [kind, i])
		if kind in TURRET:
			want.append(kind + "_turret")
		if kind in SPIN:
			want.append(kind + "_spin")
		if kind != "swarm":
			want.append(kind + "_mk")
		want.sort()
		names.sort()
		check(names == want, "%s has exactly %s" % [kind, want])
		check(legs.size() == LEGS[kind], "%s has %d legs" % [kind, LEGS[kind]])
		var top := 0.0
		var mats := {}
		for n in names:
			known[n] = true
			var mesh: Mesh = all[n][0]
			if not n.ends_with("_mk"):
				top = maxf(top, all[n][1].y + mesh.get_aabb().end.y)
			for i in mesh.get_surface_count():
				mats[mesh.surface_get_material(i).resource_name] = true
		check(mats.keys().all(func(m): return m in MATS), "%s uses only body/trim/joint/glow (%s)" % [kind, mats.keys()])
		check(mats.has("body") and mats.has("glow"), "%s has body paint and glowing eyes" % kind)
		check(absf(top - SiegeBots.SIZE[kind]) <= SiegeBots.SIZE[kind] * 0.15, "%s is about %.1f m tall (%.2f)" % [kind, SiegeBots.SIZE[kind], top])
	check(all.keys().all(func(n): return known.has(n)), "bots.glb holds nothing but the 10 bots")
	check(not all.keys().any(func(n): return n.ends_with("_wheel")), "no part is named *_wheel")


func view() -> void:
	var bots := SiegeBots.new()
	root.add_child(bots)
	var siege := {"enemies": []}
	for i in SiegeBots.KINDS.size():
		siege.enemies.append(enemy(i, SiegeBots.KINDS[i], Vector2(i * 4.0, 0), "walk"))
	for t in 30:
		for e in siege.enemies:
			e.t = t
			e.y += 0.04
		bots.sync(siege, DT)
	check(bots.rigs.size() == 10, "one rig per enemy")
	var scout: Dictionary = bots.rigs[0]
	check(absf(scout.legs[0][0].rotation.z) > 0.05, "walking swings the legs")
	var spider: Dictionary = bots.rigs[2]
	check(not spider.legs[0][0].basis.is_equal_approx(Basis.IDENTITY), "splayed legs step too")
	var tripod: Dictionary = bots.rigs[6]
	check(tripod.legs.all(func(leg): return leg.size() == 3 and leg[2][0].get_parent() == leg[0]), "each tripod piston rod rides on its own leg")
	check(tripod.legs.any(func(leg): return not leg[2][0].position.is_equal_approx(leg[2][1])), "walking pulls a piston rod in")
	var nodes := bots.get_child_count()
	var gone: Array = siege.enemies.slice(6)
	siege.enemies = siege.enemies.slice(0, 6)
	bots.sync(siege, DT)
	check(bots.rigs.size() == 6 and not gone.any(func(e): return bots.rigs.has(e.id)), "removed enemies leave")
	check(gone.all(func(e): return e.kind == "swarm" or not bots.pool[e.kind][0].root.visible), "their rigs are parked")
	for e in gone:
		e.id += 100
	siege.enemies += gone
	bots.sync(siege, DT)
	check(bots.get_child_count() == nodes, "new enemies reuse parked rigs")

	var turret: Dictionary = bots.rigs[4]
	var te: Dictionary = siege.enemies[4]
	te.act = "plant"
	te.face = 1.0
	for t in 40:
		te.t = t
		bots.sync(siege, DT)
	check(absf(wrapf(turret.root.rotation.y + turret.turret.rotation.y + 1.0, -PI, PI)) < 0.05, "a planted turret yaws to its face")
	check(turret.lean.position.y < -0.1, "a planted turret crouches")

	var walker: Dictionary = bots.rigs[5]
	var we: Dictionary = siege.enemies[5]
	check(not bots.bars.has(we.id) or not bots.bars[we.id].visible, "no HP bar at full health")
	we.hp = 40.0
	we.act = "hit"
	we.t = 0
	bots.sync(siege, DT)
	check(bots.bars.has(we.id) and bots.bars[we.id].visible, "a damaged bot shows its HP bar")
	check(walker.body.emission.r > 0.5, "a hit flashes the body")
	we.mk = 3
	we.id += 1000
	bots.sync(siege, DT)
	check(bots.rigs[we.id].mk.visible and bots.rigs[we.id].body.albedo_color == SiegeBots.MK[2], "Mk 3 gets the add-on and the dark tint")
	we.act = "die"
	for t in SiegeBots.POSE.die + 1:
		we.t = t
		bots.sync(siege, DT)
	check(not bots.rigs[we.id].root.visible, "a dead bot sinks away")
	check(not bots.bars[we.id].visible, "the dead have no HP bar")

	var swarm := {"enemies": []}
	for i in 40:
		swarm.enemies.append(enemy(500 + i, "swarm", Vector2(i, 3), "walk"))
	bots.sync(swarm, DT)
	var slots := {}
	for r in bots.rigs.values():
		slots[r.slot] = true
	check(slots.size() == 40 and bots.swarm.multimesh.instance_count >= 40, "40 swarm cubes take 40 MultiMesh slots")
	swarm.enemies = swarm.enemies.slice(0, 10)
	bots.sync(swarm, DT)
	check(bots.free_slots.size() == bots.swarm.multimesh.instance_count - 10, "dropped swarm cubes free their slots")
	bots.free()


func enemy(id: int, kind: String, at: Vector2, act: String) -> Dictionary:
	return {"id": id, "kind": kind, "lane": 0, "x": at.x, "y": at.y, "face": PI / 2, "hp": 100.0, "max": 100.0, "act": act, "t": 0, "mk": 1}


func check(ok: bool, what: String) -> void:
	print(("test passed: " if ok else "test failed: ") + what)
	if not ok:
		failed += 1
