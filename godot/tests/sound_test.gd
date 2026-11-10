extends SceneTree

const Sim = preload("res://src/sim.gd")
const Sfx = preload("res://src/sfx.gd")
const Radio = preload("res://src/radio.gd")
const Seats = preload("res://src/seats.gd")
const I18n = preload("res://src/i18n.gd")
const BRANCHED := ["muzzle", "slash", "hit", "boom", "count", "beam"]

var failed := 0
var watch = preload("res://tests/error_watch.gd").new()


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
	check(AudioServer.get_bus_effect_count(AudioServer.get_bus_index("Music")) == 0, "game sounds never turn the music down (no duck on the Music bus)")
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
	check(sfx.engines.is_empty(), "the garage stops engines")
	var bad_tracks := []
	for st in Radio.STATIONS:
		for s in st.songs:
			for f in s.files:
				if not load(Radio.DIR + (f if f is String else f[0])) is AudioStream:
					bad_tracks.append(f)
	check(bad_tracks.is_empty(), "every radio song loads (bad: %s)" % [bad_tracks])
	var radio := Radio.new()
	radio.sfx = sfx
	root.add_child(radio)
	check(radio.song in Radio.STATIONS[radio.station].songs and radio.player.playing, "the radio starts on its own with a song from its station")
	radio.tune(1)
	var first: Dictionary = radio.song
	radio.next_song()
	check(radio.song != first and radio.song in Radio.STATIONS[1].songs, "when a song ends the next one is a different song from the same station")
	radio.tune(1)
	var heard := [radio.song.title]
	for k in Radio.STATIONS[1].songs.size() - 1:
		radio.next()
		heard.append(radio.song.title if radio.station == 1 else "")
	radio.next()
	var unique := {}
	for t in heard:
		unique[t] = true
	check(unique.size() == Radio.STATIONS[1].songs.size() and not unique.has("") and radio.station == 2, "N plays every song of a station once, then moves to the next station (got %s)" % [heard])
	var seen := []
	for k in Radio.STATIONS.size():
		radio.next_station()
		seen.append(radio.station)
	check(seen == [3, 0, 1, 2], "Shift+N steps through the stations and wraps around (got %s)" % [seen])
	var dub: Array = radio.stream(Radio.STATIONS[3].songs[0])
	check(dub[0] is AudioStreamPlaylist and dub[0].stream_count == 28 and absf(dub[1] - 28 * 15.12) < 1.0, "the dub loop repeats into one 28-part song of about 7 minutes")
	radio.tune(3)
	await process_frame
	check(radio.card.modulate.a == 1.0 and radio.title.text == radio.song.title and radio.artist.text == radio.song.by and radio.hint.text != "", "the now-playing card shows the song, the artist and how to change it")
	I18n.setup()
	var seats = Seats.new()
	root.add_child(seats)
	var covered := []
	for loc in I18n.STRINGS:
		TranslationServer.set_locale(loc)
		seats.open(["kb", 0], "2v2", Sim.DEFAULT_LOADOUT, "versus")
		await process_frame
		await process_frame
		var edge: float = radio.card.global_position.x + radio.card.size.x
		for l in seats.ui_box.get_children():
			if l is Label and l.text in [seats.tr("seatsHint"), seats.tr("seatsJoin")]:
				var w: float = l.get_theme_font("font").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x
				if l.global_position.x + (l.size.x - w) / 2.0 < edge:
					covered.append("%s %s" % [loc, l.text.left(12)])
	check(radio.card.size.x > 0.0 and covered.is_empty(), "the now-playing card covers no hint on the seat screen (covered: %s)" % [covered])
	seats.queue_free()
	radio.shown = radio.now() - Radio.RADIO.show - Radio.RADIO.fade
	await process_frame
	check(radio.card.modulate.a == 0.0, "the card fades away after %d s without a switch" % Radio.RADIO.show)
	radio.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Sfx.save_path))
	sfx.queue_free()
	failed += watch.report()
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
