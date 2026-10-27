extends Node

const Hype = preload("res://src/hype.gd")
const DIR := "res://assets/sounds/"
const BUS := 0.8
const KINDS := {
	"gasp": {"rank": 1, "group": "crowdGasp", "vol": 0.25, "len": 1.4},
	"ooh": {"rank": 1, "group": "crowdOoh", "vol": 0.18, "len": 1.6},
	"cheer": {"rank": 2, "group": "crowdCheer", "vol": 0.3, "len": 1.8},
	"roar": {"rank": 3, "group": "crowdRoar", "vol": 0.5, "len": 3.5},
	"ko": {"rank": 4, "group": "crowdRoar", "vol": 0.5, "len": 3.5},
}
const BANKS := {"crowdGasp": 3, "crowdOoh": 1, "crowdCheer": 3, "crowdRoar": 3, "crowdChant": 1}
const BED := {"base": 0.06, "hype": 0.08, "rise": 0.8, "fall": 0.3}
const CHANT := {"after": 3.0, "every": 22.0, "vol": 0.16}
const STACK := 0.6
const VARY := 0.03
const VOICES := 6

var streams := {}
var last := {}
var voices := []
var next_voice := 0
var bed: AudioStreamPlayer
var bed_level := 0.0
var bed_target := 0.0
var pending := []
var until := 0.0
var rank := 0
var stack_at := 0.0
var wild_since := -1.0
var chant_at := 0.0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	for g in BANKS:
		streams[g] = []
		for i in BANKS[g]:
			streams[g].append(load(DIR + "%s_%03d.ogg" % [g, i]))
	var loop: AudioStreamOggVorbis = load(DIR + "crowdBed_000.ogg").duplicate()
	loop.loop = true
	bed = AudioStreamPlayer.new()
	bed.stream = loop
	bed.volume_db = -80.0
	add_child(bed)
	bed.play(rng.randf() * loop.get_length())
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		voices.append(p)


## Feed this frame's new fx. live = a fight is on screen and running; on = a match is on screen.
func update(fresh: Array, hype: float, live: bool, on: bool) -> void:
	var t := now()
	bed_target = BED.base + BED.hype * hype / 100.0 if on else 0.0
	for f in fresh:
		match f.k:
			"break":
				moment(t + 0.1, true, hype)
			"parry", "hooked":
				moment(t + 0.05, false, hype)
			"boom":
				if f.big:
					moment(t + 0.1, false, hype)
			"ult":
				react("ooh", t)
			"ko":
				react("ko", t + 0.1)
				react("cheer", t + 1.0, 0.7, true)
			"fight":
				react("cheer", t + 0.15)
	if not live or Hype.mood(hype) < 2:
		wild_since = -1.0
	else:
		if wild_since < 0.0:
			wild_since = t
		if t - wild_since >= CHANT.after and t >= chant_at:
			chant_at = t + CHANT.every
			pending.append([t, "crowdChant", CHANT.vol])


## A big or small moment: louder kinds as the crowd gets wilder.
func moment(t: float, big: bool, hype: float) -> void:
	var m := Hype.mood(hype)
	if m < 2:
		react("cheer" if big else "gasp", t, 1.0 if big or m > 0 else 0.6)
		return
	react("roar" if big else "cheer", t, 1.0, true)
	if rng.randf() < 0.5:
		react("cheer" if big else "gasp", t + 0.6 + rng.randf() * 0.4, 0.7, true)


## Queue one crowd clip. A busy crowd skips weaker reactions; stacked ones only need a short gap.
func react(kind: String, t: float, k := 1.0, stack := false) -> void:
	var o: Dictionary = KINDS[kind]
	if (t < stack_at) if stack else (t < until and o.rank <= rank):
		return
	stack_at = t + STACK
	if t >= until or o.rank >= rank:
		until = t + o.len
		rank = o.rank
	pending.append([t, o.group, o.vol * k])


func now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _process(delta: float) -> void:
	var t := now()
	for p in pending.duplicate():
		if p[0] <= t:
			pending.erase(p)
			play(p[1], p[2])
	var tc: float = BED.rise if bed_target > bed_level else BED.fall
	bed_level += (bed_target - bed_level) * (1.0 - exp(-delta / tc))
	bed.volume_db = linear_to_db(maxf(bed_level * BUS, 0.0001))


func play(group: String, vol: float) -> void:
	var names: Array = streams[group]
	var pick := 0
	if names.size() > 1:
		pick = (last.get(group, 0) + 1 + rng.randi_range(0, names.size() - 2)) % names.size()
	last[group] = pick
	var v: AudioStreamPlayer = voices[next_voice]
	next_voice = (next_voice + 1) % VOICES
	v.stream = names[pick]
	v.volume_db = linear_to_db(vol * BUS)
	v.pitch_scale = 1.0 + rng.randf_range(-VARY, VARY)
	v.play()
