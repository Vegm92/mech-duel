extends Node

const Sfx = preload("res://src/sfx.gd")
const Look = preload("res://src/look.gd")
const DIR := "res://assets/music/"
const STATIONS := [
	{"name": "radioArena"},
	{"name": "radioAcid", "tracks": ["acid_trance.mp3", "dirty_acid.mp3"], "shuffle": true, "fade": 2.0},
	{"name": "radioTechno", "tracks": ["techno_1.mp3", "techno_2.mp3", "techno_3.mp3", "techno_4.mp3", "techno_5.mp3", "techno_6.mp3", "techno_7.mp3"], "shuffle": true, "fade": 2.0},
	{"name": "radioDub", "tracks": [["algate_no_kick.wav", 4], ["algate.wav", 8], ["algate_bass.wav", 4], ["algate_low.wav", 4], ["algate.wav", 8]], "fade": 0.0},
]
const RADIO := {"db": -8.0, "show": 2.5, "fade": 0.6, "size": 26, "y": 0.8}

var sfx: Node
var station := 0
var on := true
var player := AudioStreamPlayer.new()
var lists := {}
var toast := Label.new()
var shown := -INF


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player.bus = "Music"
	player.volume_db = RADIO.db
	add_child(player)
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	toast.add_theme_font_override("font", Look.font(Look.FONT.heavy, true, Look.FONT.impact))
	toast.add_theme_font_size_override("font_size", RADIO.size)
	toast.add_theme_color_override("font_color", Look.ARCADE.hazard)
	toast.add_theme_color_override("font_outline_color", Look.ARCADE.ground)
	toast.add_theme_constant_override("outline_size", 8)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.modulate.a = 0.0
	layer.add_child(toast)
	tune(Sfx.volumes(), false)


## N: next station. Arena mix → each radio station → music off → arena mix.
func next() -> void:
	var v := Sfx.volumes()
	if not v.music_on:
		v.music_on = true
		v.station = 0
	else:
		v.station += 1
		if v.station >= STATIONS.size():
			v.music_on = false
			v.station = 0
	Sfx.store(v)
	tune(v, true)


## Plays the saved station; `loud` shows its name and plays the tuning hiss.
func tune(v: Dictionary, loud: bool) -> void:
	station = clampi(v.station, 0, STATIONS.size() - 1)
	on = v.music_on
	if sfx:
		sfx.quiet = station > 0
	if on and station > 0:
		player.stream = playlist(station)
		player.play()
	else:
		player.stop()
	if loud:
		toast.text = tr(STATIONS[station].name if on else "radioOff")
		shown = Time.get_ticks_msec() / 1000.0
		if sfx:
			sfx.ui("tune")


## The station's tracks as one AudioStreamPlaylist; a [file, n] entry repeats that file n times.
func playlist(i: int) -> AudioStreamPlaylist:
	if lists.has(i):
		return lists[i]
	var s := AudioStreamPlaylist.new()
	var files := []
	for t in STATIONS[i].tracks:
		for n in (1 if t is String else t[1]):
			files.append(t if t is String else t[0])
	s.stream_count = files.size()
	for k in files.size():
		s.set_list_stream(k, load(DIR + files[k]))
	s.shuffle = STATIONS[i].get("shuffle", false)
	s.fade_time = STATIONS[i].fade
	s.loop = true
	lists[i] = s
	return s


func _process(_dt: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0 - shown
	toast.modulate.a = clampf((RADIO.show - t) / RADIO.fade, 0.0, 1.0)
	if toast.modulate.a > 0.0:
		var size := toast.get_viewport_rect().size
		toast.size = Vector2(size.x, 0)
		toast.position = Vector2(0, size.y * RADIO.y)
