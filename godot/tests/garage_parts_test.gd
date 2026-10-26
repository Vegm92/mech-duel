extends SceneTree

const Sim = preload("res://src/sim.gd")
const Mech = preload("res://src/mech.gd")
const PartView = preload("res://src/part_view.gd")

var failed := 0


func _init() -> void:
	run("every_part_builds_alone_with_a_model", test_every_part_builds_alone_with_a_model)
	print("FAILED" if failed else "ALL PASSED")
	quit(1 if failed else 0)


func run(name: String, test: Callable) -> void:
	var t0 := Time.get_ticks_msec()
	if test.call():
		failed += 1
		print("test failed: " + name)
	else:
		print("test passed: %s (%d ms)" % [name, Time.get_ticks_msec() - t0])


func has_model(slot: String, key: String) -> bool:
	match slot:
		"head":
			return Mech.models("heads").has(key)
		"core":
			return Mech.models("cores").has(key) and Mech.models("light").has("Chest_" + Sim.CORES[key].series)
		"arms":
			return ["_upper_L", "_upper_R", "_fore_L", "_fore_R"].all(func(s): return Mech.models("arms").has(key + s))
		"legs":
			return Mech.models("legs").keys().any(func(n): return n == key or n.begins_with(key + "_"))
		"booster":
			return Mech.models("boosters").has(key)
	return Mech.models("guns").has(key)


func test_every_part_builds_alone_with_a_model() -> int:
	var bad := []
	for slot in Sim.CATALOG:
		for key in Sim.CATALOG[slot]:
			if not has_model(slot, key):
				bad.append("%s/%s has no model" % [slot, key])
				continue
			var m := Mech.new()
			m.build_part(slot, key, 0)
			var box = PartView.bounds(m)
			if box == null or box.size.length() < 0.05:
				bad.append("%s/%s builds empty" % [slot, key])
			m.queue_free()
	for b in bad:
		print("  " + b)
	return int(not bad.is_empty())
