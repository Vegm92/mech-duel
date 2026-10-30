extends SceneTree

const Mech = preload("res://src/mech.gd")
const View = preload("res://src/view.gd")
const SiegeView = preload("res://src/siege_view.gd")
const SiegeState = preload("res://src/siege_state.gd")

var failed := 0
var done := false


func _process(_dt: float) -> bool:
	if done:
		return false
	done = true
	var models := Mech.models("core_siege")
	var missing := SiegeView.PARTS.filter(func(p): return not models.has(p))
	check(missing.is_empty(), "core_siege.glb has every part the view needs %s" % [missing])
	var unknown := []
	for p in models:
		var mesh: Mesh = models[p][0]
		for i in mesh.get_surface_count():
			var mn := mesh.surface_get_material(i).resource_name
			if not SiegeView.MATS.has(mn):
				unknown.append("%s/%s" % [p, mn])
	check(unknown.is_empty(), "every material in core_siege.glb has a view material %s" % [unknown])
	check(View.FLOOR_SHADER.contains(SiegeView.VIGNETTE), "the duel floor shader still has the vignette the siege floor re-centres")
	check(View.EMP_SHADER.contains(SiegeView.EMP_EDGE), "the duel EMP shader still has the square edge the yard zones make round")
	var duel := Mech.models("arena")
	check(SiegeView.DUEL.all(func(p): return duel.has(p)), "arena.glb still has every duel part the siege arena reuses")

	var v := SiegeView.new()
	root.add_child(v)
	v.build()
	var s := SiegeState.stub(4)
	for k in 3:
		s.pads[k].module = ["wall", "mine", "laser"][k]
	v.update(s)
	check(v.gates.size() == 4 and v.pads.size() == 12, "4 gates and 12 build pads from the state")
	var stray := 0
	for f in v.fans:
		var at: Vector3 = f[0].origin
		if maxf(absf(at.x), absf(at.z)) <= SiegeState.HALF + 2.0 or at.y < 1.0:
			stray += 1
	check(v.fans.size() > 3000 and v.fans.size() == v.crowd.multimesh.instance_count and stray == 0, "%d fans, all in the stands outside the border, none in a yard or a lane (%d stray)" % [v.fans.size(), stray])
	check(v.camps.size() == 4 * SiegeState.CAMPS.size() and v.crates.size() == 4 * SiegeState.CRATES.size(), "a floor marker for every camp and a crate for every crate spot in the 4 yards")
	var camp: Dictionary = s.yards[0].camps[0]
	camp.alive = false
	v.update(s)
	check(is_equal_approx(v.camps[0].mat.emission_energy_multiplier, SiegeView.YARD.dead), "a cleared camp's marker goes dim")
	var lit := v.get_child_count()
	camp.alive = true
	v.update(s)
	check(is_equal_approx(v.camps[0].mat.emission_energy_multiplier, SiegeView.YARD.alive) and v.get_child_count() > lit, "a camp that respawns lights up with a pulse")
	s.yards[0].raided = 0.5
	v.update(s)
	check(v.raids[0].node.visible and v.raids[0].crates.filter(func(m): return m.visible).size() == SiegeView.YARD.raid / 2 and not v.raids[1].node.visible, "a half-raided yard shows half its raid damage, an untouched yard none")
	v.update(s)
	check(is_equal_approx(v.bay.mat.emission_energy_multiplier, SiegeView.BAY.idle), "the Parts Bay counter idles when nobody is in shop range")
	s.shop_open = [true]
	v.update(s)
	check(is_equal_approx(v.bay.mat.emission_energy_multiplier, SiegeView.BAY.open), "the Parts Bay counter glows brighter when a player is in shop range")
	var shop := v.get_child_count()
	s.buys = 1
	v.update(s)
	check(v.get_child_count() > shop, "a purchase makes a buy pulse at the Bay")
	s.recall = [{"player": 0, "t": 120, "max": 240, "x": 0.0, "y": -30.0}]
	v.update(s)
	var rc: Dictionary = v.recalls[0]
	check(rc.node.visible and rc.segs.filter(func(m): return m.visible).size() == SiegeView.RECALL.segs / 2, "a recall half done shows a beam and half its floor ring")
	s.recall[0].t = 240
	v.update(s)
	var before_end := v.get_child_count()
	s.recall = []
	v.update(s)
	check(not rc.node.visible and v.get_child_count() > before_end, "a finished recall hides its beam and flashes at the plaza")
	var crate: Dictionary = s.yards[0].crates[0]
	crate.progress = 0.5
	v.update(s)
	check(v.crates[0].segs.filter(func(m): return m.visible).size() == SiegeView.YARD.segs / 2, "a crate half opened shows half its progress ring")
	crate.taken = true
	v.update(s)
	check(not v.crates[0].node.visible, "a taken crate is gone")
	v.update(s)
	check(v.dock.lamps.all(func(m): return is_equal_approx(m.emission_energy_multiplier, SiegeView.DOCK.off)) and not v.dock.beam.visible, "an unbuilt garrison leaves the dock dark")
	s.garrison.tier = 3
	s.garrison.respawn_in = 120
	v.update(s)
	check(v.dock.lamps.filter(func(m): return is_equal_approx(m.emission_energy_multiplier, SiegeView.DOCK.on)).size() == 3 and v.dock.beam.visible, "a tier 3 garrison lights 3 dock lamps and glows while it rebuilds")
	check(v.towers.size() == 4 and v.towers.all(func(t): return t.spot is SpotLight3D), "4 floodlight spots, in the duel's tower shape so its follow code can drive them")
	for n in [4, 3, 2, 1, 0]:
		s.core.rings = SiegeState.ring_hp(n)
		v.update(s)
		s.tick += SiegeView.CORE.fly.ticks + SiegeView.CORE.rise.ticks
		v.update(s)
		check(v.petals.filter(func(r): return r.visible).size() == n, "%d rings up shows %d petals" % [n, n])
	s.core.rings = SiegeState.ring_hp(2)
	v.update(s)
	s.tick += SiegeView.CORE.fly.ticks + SiegeView.CORE.rise.ticks
	v.update(s)
	check(v.petals.map(func(r): return r.visible) == [false, false, true, true], "outer petals break first, inner last")
	var whole := SiegeView.new()
	var cracked := SiegeView.new()
	for w in [whole, cracked]:
		root.add_child(w)
		w.build()
	whole.update(SiegeState.stub(4))
	var s2 := SiegeState.stub(2)
	cracked.update(s2)
	check(cracked.get_child_count() == whole.get_child_count(), "rings already broken on the first frame make no break burst")
	var before := cracked.get_child_count()
	s2.core.rings = SiegeState.ring_hp(1)
	cracked.update(s2)
	check(cracked.get_child_count() > before, "a ring breaking during play makes a break burst")
	s.core.hp = s.core.max * 0.1
	v.update(s)
	check(v.smoke.emitting, "a core under 25 % smokes")
	check(v.plasma_mat.emission == SiegeView.CORE.red and v.hp_mat.albedo_color == SiegeView.CORE.red, "a core under 25 % turns its plasma and HP ring red")
	check(v.hp_segs.filter(func(m): return m.visible).size() == ceili(0.1 * v.hp_segs.size()), "the HP floor ring drains with the core HP")
	s.core.hp = 0.0
	v.update(s)
	check(v.plasma_mat.emission == SiegeView.CORE.dark and v.core_light.light_energy == 0.0, "a lost core goes dark")
	s.core.hp = s.core.max
	v.update(s)
	check(v.plasma_mat.emission == SiegeView.CORE.yellow and v.hp_segs.all(func(m): return m.visible), "a whole core is yellow with a full HP ring")
	s.core.rings = SiegeState.ring_hp(4)
	v.update(s)
	check(v.petals[0].visible and v.petals[0].position.y < 0.0, "a ring coming back raises its petal out of the floor")
	s.tick += SiegeView.CORE.rise.ticks
	v.update(s)
	check(v.petals[0].position.length() <= SiegeView.CORE.bob + 0.001, "a risen petal sits at its place, give or take its bob")
	s.core.rings = SiegeState.ring_hp(3)
	s.tick += 1
	v.update(s)
	s.tick += SiegeView.CORE.fly.ticks / 2
	v.update(s)
	check(v.petals[0].visible and v.petals[0].position.length() > 0.0, "a petal that just broke is still flying off")
	s.tick += SiegeView.CORE.fly.ticks
	v.update(s)
	check(not v.petals[0].visible, "a flown-off petal is gone")
	s.core.hp = s.core.max * 0.1
	s.core.repairing = true
	v.update(s)
	check(v.mend.visible, "a repairing core shows the repair glow")
	s.gates[0].hp = s.gates[0].max / 2.0
	v.update(s)
	check(v.gates[0].bar.visible and is_equal_approx(v.gates[0].fill.scale.z, 5.0), "a hurt gate shows half an HP bar")
	s.gates[0].hp = 0.0
	v.update(s)
	check(v.gates[0].broken.visible and not v.gates[0].door.visible and not v.gates[0].bar.visible, "a gate at 0 HP shows its broken look")
	check(v.gates[0].light.emission == SiegeView.ALARM.color, "a gate that just lost HP turns its lamp alarm red")
	v.gates[0].hit = -1000
	check(v.pads.slice(0, 3).all(func(p): return p.mods.values().filter(func(m): return m.visible).size() == 1), "lane 0 pads show their modules")
	check(v.pads.slice(3).all(func(p): return p.mods.values().all(func(m): return not m.visible)), "empty pads show no module")
	s.wave.next_in = 300
	s.wave.lanes_open = [false, true, false, false]
	s.tick = 0
	v.update(s)
	check(v.gates[1].light.emission_energy_multiplier > 0.0 and v.gates[0].light.emission_energy_multiplier == 0.0, "the warned lane's gate light is on, a closed lane's is off")
	check(v.spawns[1].emission_energy_multiplier > 0.0 and v.spawns[2].emission_energy_multiplier == 0.0, "the warned lane's spawn light is on")
	s.tick = SiegeView.WARN.blink
	v.update(s)
	check(v.gates[1].light.emission_energy_multiplier == 0.0, "the warning light blinks")
	print("FAILED" if failed else "ALL PASSED")
	quit(1 if failed else 0)
	return false


func check(ok: bool, what: String) -> void:
	print(("test passed: " if ok else "test failed: ") + what)
	if not ok:
		failed += 1
