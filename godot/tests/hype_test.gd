extends SceneTree

const Sim = preload("res://src/sim.gd")
const Hype = preload("res://src/hype.gd")
const CrowdSound = preload("res://src/crowd_sound.gd")

var failed := 0


func _init() -> void:
	var s := fight()
	var h := Hype.next(0.0, s, [{"k": "hooked"}, {"k": "hit", "n": 40, "head": true}, {"k": "break"}], 0.0)
	check(is_equal_approx(h, 15 + 40 * Hype.HYPE.hit * 2 + 25), "big moments add hype")
	check(is_equal_approx(Hype.next(h, s, [], Hype.HYPE.half), h / 2.0), "quiet time halves it every half-life")
	check(Hype.next(h, s, [{"k": "ko"}], 0.0) == 100.0, "a K.O. maxes it")
	check([0.0, 29.0, 30.0, 69.0, 70.0].map(Hype.mood) == [0, 0, 1, 1, 2], "mood thresholds")
	s.mechs[1].armor.head = s.mechs[1].max.head * 0.2
	check(Hype.next(0.0, s, [], 60.0) == Hype.HYPE.danger, "low head armor keeps a floor")
	var late := fight()
	late.clock = 5 * Sim.TICKS
	late.score = [Sim.MATCH.wins - 1, 0]
	check(Hype.next(0.0, late, [], 60.0) == Hype.HYPE.clutch + Hype.HYPE.matchPoint, "clutch time + match point floor")
	late.phase = "countdown"
	check(Hype.next(0.0, late, [], 60.0) == 0.0, "no floor outside a fight")
	check(Hype.cheer_for({"k": "hit", "n": 12, "head": false}) == 0.0 and Hype.cheer_for({"k": "hit", "n": 12, "head": true}) > 0.0, "only big or head hits cheer")
	var cs := CrowdSound.new()
	cs.react("cheer", 10.0)
	cs.react("gasp", 10.5)
	check(cs.pending.size() == 1, "a cheering crowd skips a weaker gasp")
	cs.react("roar", 10.5)
	check(cs.pending.size() == 2, "a stronger roar cuts in")
	cs.react("cheer", 10.7, 0.7, true)
	cs.react("cheer", 11.2, 0.7, true)
	check(cs.pending.size() == 3, "stacked cheers need a short gap")
	cs.update([{"k": "ko"}], 0.0, true, true)
	check(cs.bed_target > 0.0, "the crowd bed plays during a match")
	cs.update([], 100.0, false, false)
	check(cs.bed_target == 0.0, "the crowd bed goes quiet when paused or in the garage")
	cs.free()
	print("FAILED" if failed else "ALL PASSED")
	quit(1 if failed else 0)


func fight() -> Dictionary:
	var s := Sim.create_state()
	s.phase = "fight"
	return s


func check(ok: bool, what: String) -> void:
	print(("test passed: " if ok else "test failed: ") + what)
	if not ok:
		failed += 1
