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
		if absf(at.x) <= 5.0 or absf(at.z) <= 5.0 or Vector2(at.x, at.z).length() <= SiegeState.RING_OUT + 8.5 or at.y < 1.5:
			stray += 1
	check(v.fans.size() > 2000 and v.fans.size() == v.crowd.multimesh.instance_count and stray == 0, "%d fans, all on the blocks: none in a lane, on the ring road or under the block top (%d stray)" % [v.fans.size(), stray])
	check(v.towers.size() == 4 and v.towers.all(func(t): return t.spot is SpotLight3D), "4 floodlight spots, in the duel's tower shape so its follow code can drive them")
	for n in [4, 3, 2, 1, 0]:
		s.core.rings = SiegeState.ring_hp(n)
		v.update(s)
		check(v.rings.filter(func(r): return r.visible).size() == n, "%d rings up shows %d rings" % [n, n])
	s.core.rings = SiegeState.ring_hp(2)
	v.update(s)
	check(v.rings.map(func(r): return r.visible) == [false, false, true, true], "outer rings break first, inner last")
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
	s.core.repairing = true
	v.update(s)
	check(v.mend.visible, "a repairing core shows the repair glow")
	s.gates[0].hp = s.gates[0].max / 2.0
	v.update(s)
	check(v.gates[0].bar.visible and is_equal_approx(v.gates[0].fill.scale.z, 5.0), "a hurt gate shows half an HP bar")
	s.gates[0].hp = 0.0
	v.update(s)
	check(v.gates[0].broken.visible and not v.gates[0].door.visible and not v.gates[0].bar.visible, "a gate at 0 HP shows its broken look")
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
