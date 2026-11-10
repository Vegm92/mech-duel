extends Node

const Sfx = preload("res://src/sfx.gd")
const Look = preload("res://src/look.gd")
const DIR := "res://assets/music/"
const STATIONS := [
	{"name": "radioHouse", "songs": [
		{"title": "Ethernight Club", "by": "Kevin MacLeod", "files": ["house_ethernight_club.mp3"]},
		{"title": "Raving Energy", "by": "Kevin MacLeod", "files": ["house_raving_energy.mp3"]},
		{"title": "Special Spotlight", "by": "Kevin MacLeod", "files": ["house_special_spotlight.mp3"]},
		{"title": "Laserpack", "by": "Kevin MacLeod", "files": ["house_laserpack.mp3"]},
		{"title": "Presenterator", "by": "Kevin MacLeod", "files": ["house_presenterator.mp3"]},
		{"title": "DriftMaster", "by": "Shane Ivers", "files": ["house_driftmaster.mp3"]},
		{"title": "Slampe", "by": "Fupi", "files": ["house_slampe.ogg"]},
		{"title": "Private Party", "by": "Fato Shadow", "files": ["house_private_party.mp3"]},
	]},
	{"name": "radioTechno", "songs": [
		{"title": "Deep and Dirty", "by": "Kevin MacLeod", "files": ["techno_deep_and_dirty.mp3"]},
		{"title": "EDM Detection Mode", "by": "Kevin MacLeod", "files": ["techno_edm_detection_mode.mp3"]},
		{"title": "Brain Dance", "by": "Kevin MacLeod", "files": ["techno_brain_dance.mp3"]},
		{"title": "Misuse", "by": "Kevin MacLeod", "files": ["techno_misuse.mp3"]},
		{"title": "Nightchaser", "by": "Shane Ivers", "files": ["techno_nightchaser.mp3"]},
		{"title": "Cybermatic Pulse", "by": "Alexandr Zhelanov", "files": ["techno_cybermatic_pulse.mp3"]},
		{"title": "Industria", "by": "Alexandr Zhelanov", "lic": "CC BY 3.0", "files": ["techno_industria.mp3"]},
		{"title": "Things Got a Bit Ravey in Wuffly Land Tonight", "by": "Spring", "files": ["techno_wuffly_land.ogg"]},
		{"title": "Techno", "by": "Pro Sensory", "files": ["techno_1.mp3"]},
		{"title": "Techno 2", "by": "Pro Sensory", "files": ["techno_2.mp3"]},
		{"title": "Techno 3", "by": "Pro Sensory", "files": ["techno_3.mp3"]},
		{"title": "Techno 4", "by": "Pro Sensory", "files": ["techno_4.mp3"]},
		{"title": "Techno 5", "by": "Pro Sensory", "files": ["techno_5.mp3"]},
		{"title": "Techno 6", "by": "Pro Sensory", "files": ["techno_6.mp3"]},
		{"title": "Techno 7", "by": "Pro Sensory", "files": ["techno_7.mp3"]},
	]},
	{"name": "radioAcid", "songs": [
		{"title": "Acid Trance", "by": "Shane Ivers", "files": ["acid_trance.mp3"]},
		{"title": "Dirty Acid", "by": "Bogart VGM", "files": ["dirty_acid.mp3"]},
		{"title": "The Lift", "by": "Kevin MacLeod", "files": ["acid_the_lift.mp3"]},
		{"title": "Cut Trance", "by": "Kevin MacLeod", "files": ["acid_cut_trance.mp3"]},
		{"title": "Beauty Flow", "by": "Kevin MacLeod", "files": ["acid_beauty_flow.mp3"]},
		{"title": "Intuit", "by": "Kevin MacLeod", "files": ["acid_intuit.mp3"]},
		{"title": "Pulsar", "by": "Shane Ivers", "files": ["acid_pulsar.mp3"]},
		{"title": "Posteriosis", "by": "Shane Ivers", "files": ["acid_posteriosis.mp3"]},
		{"title": "Fly", "by": "Alexandr Zhelanov", "lic": "CC BY 3.0", "files": ["acid_fly.mp3"]},
	]},
	{"name": "radioDeep", "songs": [
		{"title": "Algate", "by": "cinameng", "files": [["algate_no_kick.wav", 4], ["algate.wav", 8], ["algate_bass.wav", 4], ["algate_low.wav", 4], ["algate.wav", 8]]},
		{"title": "Limit 70", "by": "Kevin MacLeod", "files": ["deep_limit_70.mp3"]},
		{"title": "Hypnothis", "by": "Kevin MacLeod", "files": ["deep_hypnothis.mp3"]},
		{"title": "Babylon", "by": "Kevin MacLeod", "files": ["deep_babylon.mp3"]},
		{"title": "Equatorial Complex", "by": "Kevin MacLeod", "files": ["deep_equatorial_complex.mp3"]},
		{"title": "Severe Tire Damage", "by": "Kevin MacLeod", "files": ["deep_severe_tire_damage.mp3"]},
		{"title": "Half Mystery", "by": "Kevin MacLeod", "files": ["deep_half_mystery.mp3"]},
		{"title": "Spacedman", "by": "Shane Ivers", "files": ["deep_spacedman.mp3"]},
		{"title": "Synapse", "by": "Shane Ivers", "files": ["deep_synapse.mp3"]},
		{"title": "Hypnotic Chill", "by": "cynicmusic", "files": ["deep_hypnotic_chill.mp3"]},
		{"title": "Deep Care", "by": "Of Far Different Nature", "files": ["deep_deep_care.mp3"]},
	]},
]
const ARTISTS := {
	"Kevin MacLeod": ["incompetech.com", "CC BY 4.0"],
	"Shane Ivers": ["silvermansound.com", "CC BY 4.0"],
	"Alexandr Zhelanov": ["soundcloud.com/alexandr-zhelanov", "CC BY 4.0"],
	"Bogart VGM": ["facebook.com/BogartVGM", "CC BY 3.0"],
	"Fato Shadow": ["opengameart.org/content/private-party-edm-disco", "CC BY 4.0"],
	"Of Far Different Nature": ["opengameart.org/content/escape-album-14-tracks-deep-massive", "CC BY 4.0"],
	"Pro Sensory": ["opengameart.org/content/electronic", "CC0"],
	"cinameng": ["opengameart.org/content/algate", "CC0"],
	"Fupi": ["opengameart.org/content/slampe-synthwave-house", "CC0"],
	"Spring": ["opengameart.org/content/things-got-a-bit-ravey-in-wuffly-land-tonight", "CC0"],
	"cynicmusic": ["opengameart.org/content/hypnotic-chill-extended-4-minute-mix", "CC0"],
}
const LICENSES := "CC BY 4.0: creativecommons.org/licenses/by/4.0   ·   CC BY 3.0: creativecommons.org/licenses/by/3.0"
const RADIO := {"db": -8.0, "show": 10.0, "fade": 0.6, "width": 310, "margin": Vector2(16, 16), "art": 64, "bars": 4}

var sfx: Node
var station := 0
var order := []
var pos := -1
var song := {}
var length := 0.0
var elapsed := 0.0
var shown := -INF
var player := AudioStreamPlayer.new()
var streams := {}
var card := PanelContainer.new()
var station_label := Label.new()
var title := Label.new()
var artist := Label.new()
var time_label := Label.new()
var hint := Label.new()
var bar := ProgressBar.new()
var eq := []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player.bus = "Music"
	player.volume_db = RADIO.db
	add_child(player)
	build()
	tune(randi() % STATIONS.size())


## N: the next song; after the station's last one, the next station.
func next() -> void:
	if pos + 1 >= order.size():
		tune((station + 1) % STATIONS.size())
	else:
		next_song()
	if sfx:
		sfx.ui("tune")


## Shift+N: the next station.
func next_station() -> void:
	tune((station + 1) % STATIONS.size())
	if sfx:
		sfx.ui("tune")


## Switches to station `i` and plays a random song from it.
func tune(i: int) -> void:
	station = i
	order = range(STATIONS[i].songs.size())
	order.shuffle()
	pos = -1
	next_song()


## The next song of the station's shuffled order; shows the card.
func next_song() -> void:
	pos = (pos + 1) % order.size()
	song = STATIONS[station].songs[order[pos]]
	var s: Array = stream(song)
	player.stream = s[0]
	length = s[1]
	elapsed = 0.0
	player.play()
	shown = now()


## [stream, seconds] for a song; a [file, n] entry repeats that file n times with no gap.
func stream(s: Dictionary) -> Array:
	if streams.has(s.title):
		return streams[s.title]
	var parts := []
	for f in s.files:
		for n in (1 if f is String else f[1]):
			parts.append(load(DIR + (f if f is String else f[0])))
	var out: AudioStream = parts[0]
	if parts.size() > 1:
		var p := AudioStreamPlaylist.new()
		p.stream_count = parts.size()
		for k in parts.size():
			p.set_list_stream(k, parts[k])
		p.fade_time = 0.0
		p.loop = false
		out = p
	streams[s.title] = [out, parts.reduce(func(a, x): return a + x.get_length(), 0.0)]
	return streams[s.title]


## One row per artist for the credits screen: [artist, site, license, quoted track titles].
static func credits() -> Array:
	var out := []
	for a in ARTISTS:
		var tracks := []
		for st in STATIONS:
			for s in st.songs:
				if s.by == a:
					tracks.append("\"%s\"%s" % [s.title, " (%s)" % s.lic if s.has("lic") else ""])
		out.append([a, ARTISTS[a][0], ARTISTS[a][1], "   ·   ".join(tracks)])
	return out


func build() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var box := StyleBoxFlat.new()
	box.bg_color = Look.ARCADE.panel
	box.border_color = Look.ARCADE.hazard
	box.border_width_left = 3
	box.set_corner_radius_all(6)
	box.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", box)
	card.custom_minimum_size.x = RADIO.width
	card.modulate.a = 0.0
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var art := ColorRect.new()
	art.color = Look.ARCADE.raised
	art.custom_minimum_size = Vector2.ONE * RADIO.art
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(art)
	for i in RADIO.bars:
		var b := ColorRect.new()
		b.color = Look.ARCADE.hazard
		art.add_child(b)
		eq.append(b)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	for l in [[station_label, Look.FONT.heavy, 12, Look.ARCADE.hazard], [title, Look.FONT.heavy, 20, Color.WHITE],
			[artist, Look.FONT.text, 14, Look.ARCADE.soft]]:
		style(l[0], l[1], l[2], l[3])
		col.add_child(l[0])
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	col.add_child(line)
	for k in ["background", "fill"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Look.ARCADE.hazard if k == "fill" else Look.ARCADE.line
		sb.set_corner_radius_all(2)
		bar.add_theme_stylebox_override(k, sb)
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.custom_minimum_size.y = 4
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(bar)
	style(time_label, Look.FONT.text, 12, Look.ARCADE.dim)
	line.add_child(time_label)
	style(hint, Look.FONT.bold, 12, Look.ARCADE.dim)
	col.add_child(hint)


func style(l: Label, weight: int, px: int, color: Color) -> void:
	l.add_theme_font_override("font", Look.font(weight, weight == Look.FONT.heavy, Look.FONT.impact if weight == Look.FONT.heavy else Look.FONT.family))
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", color)


func clock(t: float) -> String:
	return "%d:%02d" % [int(t) / 60, int(t) % 60]


func now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _process(dt: float) -> void:
	if not player.playing:
		next_song()
	elapsed = minf(elapsed + dt, length)
	card.modulate.a = clampf((RADIO.show - (now() - shown)) / RADIO.fade, 0.0, 1.0)
	if card.modulate.a <= 0.0:
		return
	station_label.text = tr(STATIONS[station].name)
	title.text = song.title
	artist.text = song.by
	hint.text = tr("radioHint")
	bar.value = elapsed / length if length > 0.0 else 0.0
	time_label.text = "%s / %s" % [clock(elapsed), clock(length)]
	var w := (RADIO.art - 12.0) / RADIO.bars
	for i in eq.size():
		var h := 0.25 + 0.75 * absf(sin(now() * (3.0 + i * 1.7) + i))
		eq[i].size = Vector2(w - 3.0, h * (RADIO.art - 16.0))
		eq[i].position = Vector2(6.0 + i * w, RADIO.art - 8.0 - eq[i].size.y)
	card.reset_size()
	card.position = Vector2(RADIO.margin.x, card.get_viewport_rect().size.y - RADIO.margin.y - card.size.y)
