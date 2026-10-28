extends SceneTree

const Sim = preload("res://src/sim.gd")
const Sfx = preload("res://src/sfx.gd")
const BRANCHED := ["muzzle", "slash", "hit", "boom", "count", "beam"]

var failed := 0


func _initialize() -> void:
	Sfx.buses()
	check(["SFX", "Env", "Crowd", "Music"].all(func(b): return AudioServer.get_bus_index(b) > 0), "the four buses exist")
	var src := FileAccess.get_file_as_string("res://src/sim.gd") + FileAccess.get_file_as_string("res://src/siege.gd")
	var re := RegEx.create_from_string("\"k\": \"(\\w+)\"")
	var kinds := {"beam": true}
	for line in src.split("\n"):
		if line.contains("fx.append"):
			for m in re.search_all(line):
				kinds[m.get_string(1)] = true
	var missing := kinds.keys().filter(func(k): return not (k in Sfx.SILENT or k in BRANCHED or Sfx.RECIPES.has(k)))
	check(kinds.size() > 30 and missing.is_empty(), "every fx kind the sim emits has a sound (missing: %s)" % [missing])
	var quiet := Sim.WEAPONS.keys().filter(func(w): return Sfx.key_of({"k": "slash", "blade": w} if Sim.WEAPONS[w].kind == "melee" else {"k": "muzzle", "gun": w}) == "")
	check(quiet.is_empty(), "every weapon has a sound (missing: %s)" % [quiet])
	check(Sfx.key_of({"k": "hit", "head": true}) == "hitHead" and Sfx.key_of({"k": "boom", "big": true}) == "boomBig", "head hits and big booms get their own sound")
	var bad := []
	for g in Sfx.BANKS:
		for i in Sfx.BANKS[g][1]:
			if not load(Sfx.DIR + "%s_%03d.ogg" % [Sfx.BANKS[g][0], i]) is AudioStream:
				bad.append("%s_%d" % [g, i])
	check(bad.is_empty(), "every sample loads (bad: %s)" % [bad])
	var silent := []
	for key in Sfx.RECIPES:
		for l in Sfx.RECIPES[key]:
			if l.has("synth") and peak(Sfx.render(l.synth)) < 0.05:
				silent.append(key)
			if l.has("bank") and not Sfx.BANKS.has(l.bank):
				silent.append(key + ":" + l.bank)
	check(silent.is_empty(), "every synth layer makes sound and every bank exists (bad: %s)" % [silent])
	var stems := Sfx.song_stems()
	var loop := int(16 * Sfx.MUSIC.bars.size() * 60.0 / Sfx.MUSIC.bpm / 4.0 * Sfx.MIX.rate)
	check(stems.size() == 3 and stems.all(func(s): return s.size() == loop and peak(s) > 0.02 and peak(s) <= 1.0), "music: 3 looping stems, audible, no clipping")
	var state := Sim.create_state()
	check(Sfx.side(state, {"id": 1}) < Sfx.side(state, {"id": 0}), "a rival's sounds are quieter than yours")
	Sfx.save_path = "user://settings_test.cfg"
	Sfx.set_volume("Music", 0.3)
	check(is_equal_approx(Sfx.volumes().Music, 0.3) and is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")), linear_to_db(0.3)), "a volume is saved and applied")
	Sfx.toggle("muted")
	check(AudioServer.is_bus_mute(0), "M mutes the master bus")
	Sfx.toggle("muted")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Sfx.save_path))
	var sfx := Sfx.new()
	root.add_child(sfx)
	await process_frame
	check(sfx.banks.size() == Sfx.BANKS.size(), "the node loads every bank when it enters the tree")
	state.phase = "fight"
	var fresh := []
	for k in kinds:
		fresh.append({"k": k, "id": 0, "x": 30.0, "y": 30.0, "gun": "rivet", "blade": "saw", "n": 40, "head": false, "big": true})
	sfx.update(state, fresh, false)
	check(sfx.voices.all(func(v): return v.stream != null), "a fight's events fill the voice pool")
	var flat := sfx.next_flat
	sfx.ui("select")
	check(sfx.next_flat == flat + 1, "a menu sound plays without a 3D spot")
	state.mechs[1].act = {"k": "shield", "ph": "up", "absorbed": 0}
	sfx.update(state, [], false)
	state.mechs[1].act.absorbed = 30
	var before := sfx.next_voice
	sfx.update(state, [], false)
	check(sfx.next_voice != before, "a shield blocking a hit makes a sound")
	sfx.ui("hover")
	sfx.menu()
	check(sfx.engines.is_empty() and sfx.level == 0, "the garage stops engines and calms the music")
	sfx.queue_free()
	print("FAILED" if failed else "ALL PASSED")
	quit(1 if failed else 0)


func peak(s: PackedFloat32Array) -> float:
	var p := 0.0
	for x in s:
		p = maxf(p, absf(x))
	return p


func check(ok: bool, what: String) -> void:
	print(("test passed: " if ok else "test failed: ") + what)
	if not ok:
		failed += 1
