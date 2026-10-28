extends SceneTree

const Mech = preload("res://src/mech.gd")
const View = preload("res://src/view.gd")
const SiegeView = preload("res://src/siege_view.gd")

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
	var s := SiegeView.demo(4)
	v.update(s)
	check(v.gates.size() == 4 and v.pads.size() == 12, "4 gates and 12 build pads from the state")
	for n in [4, 3, 2, 1, 0]:
		s.core.rings = SiegeView.demo(n).core.rings
		v.update(s)
		check(v.rings.filter(func(r): return r.visible).size() == n, "%d rings up shows %d rings" % [n, n])
	check(v.rings[3].visible == false and v.rings[0].visible == false, "outer ring breaks first, inner last")
	s.core.hp = 100.0
	v.update(s)
	check(v.smoke.emitting, "a core under 25 % smokes")
	s.core.repairing = true
	v.update(s)
	check(v.mend.visible, "a repairing core shows the repair glow")
	s.gates[0].hp = 300.0
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
