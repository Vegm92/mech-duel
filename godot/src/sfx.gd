extends Node

const Fx = preload("res://src/fx.gd")
const DIR := "res://assets/sounds/"
const SAVE := "user://settings.cfg"
const VOLUME := {"Master": 1.0, "Music": 1.0, "SFX": 1.0, "Env": 0.5, "Crowd": 1.0}
const MIX := {"master": 0.9, "music": 0.16, "stem": 0.5, "verb": 0.08, "rate": 22050, "voices": 28, "flat": 12,
	"reach": 30.0, "pan": 0.7, "foe": 0.75, "crowd_foe": 0.6, "slow": 0.55, "chip": 0.09, "alarm": 0.9, "fade": 2.0}
const MUSIC := {"bpm": 112.0, "bars": [[110.0, 1.189], [87.31, 1.26], [130.81, 1.26], [98.0, 1.26]]}
const BANKS := {
	"zap": ["laserSmall", 5], "laser": ["laserLarge", 5], "crunch": ["explosionCrunch", 5], "field": ["forceField", 5],
	"thruster": ["thrusterFire", 2], "rumble": ["lowFrequency_explosion", 2], "launch": ["doorOpen", 3],
	"whine": ["engineCircular", 1], "hover": ["spaceEngineSmall", 1], "tread": ["spaceEngineLow", 1],
	"plate": ["impactPlate_heavy", 5], "clank": ["impactMetal_heavy", 5], "ting": ["impactMetal_light", 5],
	"tin": ["impactTin_medium", 5], "punch": ["impactPunch_heavy", 5], "punchMid": ["impactPunch_medium", 5],
	"thud": ["impactSoft_medium", 5], "scrape": ["impactMining", 5], "click": ["impactGeneric_light", 3],
	"step": ["footstep_concrete", 5],
}
const SILENT := ["zap"]
const ENV := ["crush", "crushWarn", "pylon", "pylonWarn", "vent", "ventsOn", "closing", "padsUp", "healUp"]
const SIDE := ["break", "blink", "magnet", "land", "dash", "hookOut", "hooked", "charge"]
const LOOPS := {"hover": "hover", "jets": "hover", "treads": "tread", "wheels": "tread", "skates": "tread", "mono": "tread"}
const STEPS := {"greaves": [1.15, 0.65, 1.0], "spider": [0.55, 1.1, 0.45], "quad": [0.8, 0.9, 0.7], "stompers": [1.5, 0.45, 1.4]}
const RECIPES := {
	"muzzle_rivet": [{"bank": "zap", "vol": 0.65, "rate": 1.1}, {"bank": "thud", "vol": 0.4}],
	"muzzle_needle": [{"bank": "laser", "vol": 0.5}, {"bank": "thud", "vol": 0.5, "rate": 0.7}],
	"muzzle_scatter": [{"bank": "crunch", "vol": 0.4, "rate": 1.25, "dur": 0.32}, {"bank": "punchMid", "vol": 0.45, "rate": 0.9}],
	"muzzle_gatling": [{"bank": "zap", "vol": 0.32, "rate": 1.7, "dur": 0.12}, {"bank": "click", "vol": 0.25, "rate": 0.8}],
	"muzzle_flamer": [{"bank": "thruster", "vol": 0.2, "rate": 1.3, "dur": 0.2, "offset": -1.0}],
	"muzzle_missiles": [{"bank": "launch", "vol": 0.4, "rate": 1.8, "dur": 0.3},
		{"synth": {"wave": "noise", "a": 0.1225, "dur": 0.35, "filter": ["bandpass", 400.0, 2400.0, 1.4]}, "vol": 0.18}],
	"muzzle_mortar": [{"bank": "punch", "vol": 0.7, "rate": 0.6}, {"bank": "thud", "vol": 0.5, "rate": 0.5}],
	"muzzle_laser": [{"bank": "laser", "vol": 0.5, "rate": 1.4, "dur": 0.4}],
	"muzzle_tesla": [{"bank": "field", "vol": 0.35, "rate": 2.6, "dur": 0.25},
		{"synth": {"wave": "noise", "a": 0.002, "dur": 0.15, "filter": ["highpass", 3000.0, 0.0, 1.0]}, "vol": 0.22}],
	"muzzle_ricochet": [{"bank": "zap", "vol": 0.55, "rate": 0.85}, {"bank": "ting", "vol": 0.2, "rate": 1.6}],
	"slash_saw": [{"synth": {"wave": "noise", "a": 0.07, "dur": 0.2, "filter": ["bandpass", 900.0, 4200.0, 1.4]}, "vol": 0.25},
		{"bank": "whine", "vol": 0.14, "rate": 2.2, "dur": 0.22, "offset": -1.0}],
	"slash_drill": [{"bank": "whine", "vol": 0.22, "rate": 1.2, "dur": 0.35, "offset": -1.0},
		{"synth": {"wave": "noise", "a": 0.0875, "dur": 0.25, "filter": ["bandpass", 500.0, 1800.0, 1.4]}, "vol": 0.15}],
	"slash_hammer": [{"synth": {"wave": "noise", "a": 0.0875, "dur": 0.25, "filter": ["bandpass", 250.0, 1200.0, 1.4]}, "vol": 0.3},
		{"bank": "field", "vol": 0.25, "rate": 2.0, "dur": 0.3, "offset": 0.1}],
	"slash_claws": [{"synth": {"wave": "noise", "a": 0.042, "dur": 0.12, "filter": ["bandpass", 1500.0, 5000.0, 1.4]}, "vol": 0.22},
		{"bank": "scrape", "vol": 0.15, "rate": 1.8}],
	"slash_whip": [{"synth": {"wave": "noise", "a": 0.105, "dur": 0.3, "filter": ["bandpass", 600.0, 3500.0, 1.4]}, "vol": 0.25},
		{"bank": "tin", "vol": 0.3, "rate": 1.4, "at": 0.15}],
	"slash_bunker": [{"bank": "punch", "vol": 0.75, "rate": 0.75}, {"bank": "clank", "vol": 0.5, "rate": 0.8, "at": 0.04}],
	"slash_katana": [{"synth": {"wave": "noise", "a": 0.063, "dur": 0.18, "filter": ["bandpass", 1200.0, 5200.0, 1.4]}, "vol": 0.22},
		{"bank": "field", "vol": 0.2, "rate": 3.0, "dur": 0.25}],
	"slash_bash": [{"bank": "plate", "vol": 0.5, "rate": 0.9}, {"bank": "thud", "vol": 0.5, "rate": 0.7}],
	"slash_fist": [{"bank": "thruster", "vol": 0.35, "rate": 1.2, "dur": 0.25, "offset": -1.0}, {"bank": "punch", "vol": 0.6, "at": 0.06}],
	"slash_flail": [{"synth": {"wave": "noise", "a": 0.14, "dur": 0.4, "filter": ["bandpass", 200.0, 900.0, 1.4]}, "vol": 0.3},
		{"bank": "clank", "vol": 0.25, "rate": 0.7, "at": 0.1}],
	"hit": [{"synth": {"wave": "square", "f": 320.0, "to": 192.0, "a": 0.002, "dur": 0.07}, "vol": 0.06},
		{"synth": {"wave": "noise", "a": 0.002, "dur": 0.06, "filter": ["bandpass", 2500.0, 0.0, 1.0]}, "vol": 0.2}],
	"hitHead": [{"synth": {"wave": "saw", "f": 90.0, "to": 45.0, "a": 0.002, "dur": 0.35}, "vol": 0.12},
		{"synth": {"wave": "noise", "a": 0.002, "dur": 0.3, "filter": ["bandpass", 600.0, 0.0, 1.0]}, "vol": 0.35}],
	"break": [{"bank": "plate", "vol": 0.9}, {"bank": "crunch", "vol": 0.35, "rate": 1.3, "dur": 0.45},
		{"bank": "scrape", "vol": 0.35, "rate": 1.2, "at": 0.08}],
	"parry": [{"bank": "field", "vol": 0.3, "rate": 1.5, "dur": 0.45}, {"synth": {"wave": "sine", "f": 1760.0, "dur": 0.5}, "vol": 0.08}],
	"blink": [{"bank": "launch", "vol": 0.4, "rate": 1.8, "dur": 0.3}, {"bank": "field", "vol": 0.25, "rate": 2.0, "dur": 0.3}],
	"magnet": [{"bank": "field", "vol": 0.35, "rate": 0.8, "dur": 0.4}],
	"land": [{"bank": "thud", "vol": 0.75, "rate": 0.85}, {"bank": "rumble", "vol": 0.35, "dur": 0.5}],
	"dash": [{"bank": "thruster", "vol": 0.55, "dur": 0.35, "offset": -1.0}],
	"hookOut": [{"bank": "launch", "vol": 0.3, "rate": 1.5, "dur": 0.3}],
	"hooked": [{"bank": "clank", "vol": 0.8}, {"bank": "tin", "vol": 0.4, "at": 0.05}],
	"charge": [{"bank": "field", "vol": 0.35, "rate": 1.55}],
	"beam": [{"bank": "laser", "vol": 0.75, "rate": 0.55}, {"bank": "rumble", "vol": 0.7, "dur": 1.2}, {"bank": "crunch", "vol": 0.35, "rate": 0.8}],
	"boom": [{"bank": "crunch", "vol": 0.5}, {"bank": "rumble", "vol": 0.45, "dur": 0.6}],
	"boomBig": [{"bank": "crunch", "vol": 0.75, "rate": 0.7}, {"bank": "rumble", "vol": 0.9, "dur": 1.2}],
	"emp": [{"bank": "field", "vol": 0.5, "rate": 0.7}, {"bank": "rumble", "vol": 0.4, "dur": 0.6},
		{"synth": {"wave": "noise", "a": 0.002, "dur": 0.3, "filter": ["highpass", 2500.0, 0.0, 1.0]}, "vol": 0.2}],
	"soak": [{"bank": "field", "vol": 0.15, "rate": 2.2, "dur": 0.2}],
	"brace": [{"bank": "plate", "vol": 0.5, "rate": 0.8}, {"bank": "field", "vol": 0.3, "rate": 0.6, "dur": 0.4}],
	"cleanse": [{"synth": {"wave": "sine", "f": 880.0, "dur": 0.35}, "vol": 0.05}, {"synth": {"wave": "sine", "f": 1320.0, "dur": 0.35}, "vol": 0.05, "at": 0.07},
		{"bank": "field", "vol": 0.25, "rate": 1.8, "dur": 0.3}],
	"focus": [{"bank": "ting", "vol": 0.3, "rate": 1.2}, {"bank": "field", "vol": 0.25, "rate": 2.0, "dur": 0.3}],
	"pulse": [{"bank": "field", "vol": 0.2, "rate": 1.6, "dur": 0.3}],
	"xray": [{"bank": "ting", "vol": 0.25, "rate": 1.6}, {"bank": "field", "vol": 0.25, "rate": 2.4, "dur": 0.25}],
	"frost": [{"bank": "field", "vol": 0.4, "rate": 1.2, "dur": 0.4}, {"bank": "ting", "vol": 0.2, "rate": 2.0}],
	"arcwall": [{"bank": "field", "vol": 0.4, "rate": 0.9, "dur": 0.4}, {"bank": "launch", "vol": 0.2, "rate": 2.0, "dur": 0.2}],
	"trap": [{"bank": "thud", "vol": 0.3, "rate": 1.4}],
	"ult": [{"bank": "field", "vol": 0.4, "rate": 1.1},
		{"synth": {"wave": "saw", "f": 330.0, "a": 0.01, "dur": 0.4, "filter": ["lowpass", 2000.0, 0.0, 1.0]}, "vol": 0.035},
		{"synth": {"wave": "saw", "f": 495.0, "a": 0.01, "dur": 0.4, "filter": ["lowpass", 2000.0, 0.0, 1.0]}, "vol": 0.035}],
	"ko": [{"bank": "rumble", "vol": 0.9}, {"bank": "crunch", "vol": 0.55, "rate": 0.7}, {"bank": "plate", "vol": 0.6, "at": 0.15}],
	"ping": [{"bank": "ting", "vol": 0.18, "rate": 1.4, "vary": 0.3}],
	"count": [{"synth": {"wave": "square", "f": 660.0, "dur": 0.14, "filter": ["lowpass", 3000.0, 0.0, 1.0]}, "vol": 0.05}],
	"countGo": [{"synth": {"wave": "square", "f": 990.0, "dur": 0.14, "filter": ["lowpass", 3000.0, 0.0, 1.0]}, "vol": 0.05}],
	"fight": [{"synth": {"wave": "saw", "f": 220.0, "a": 0.02, "dur": 0.7, "filter": ["lowpass", 900.0, 3500.0, 1.0]}, "vol": 0.04},
		{"synth": {"wave": "saw", "f": 277.2, "a": 0.02, "dur": 0.7, "filter": ["lowpass", 900.0, 3500.0, 1.0]}, "vol": 0.04},
		{"synth": {"wave": "saw", "f": 330.0, "a": 0.02, "dur": 0.7, "filter": ["lowpass", 900.0, 3500.0, 1.0]}, "vol": 0.04},
		{"synth": {"wave": "saw", "f": 440.0, "a": 0.02, "dur": 0.7, "filter": ["lowpass", 900.0, 3500.0, 1.0]}, "vol": 0.04},
		{"bank": "punch", "vol": 0.6}],
	"time": [{"synth": {"wave": "square", "f": 180.0, "dur": 0.8, "filter": ["lowpass", 1200.0, 0.0, 1.0]}, "vol": 0.045},
		{"synth": {"wave": "square", "f": 190.8, "dur": 0.8, "filter": ["lowpass", 1200.0, 0.0, 1.0]}, "vol": 0.045}],
	"heal": [{"synth": {"wave": "sine", "f": 523.0, "dur": 0.5}, "vol": 0.05}, {"synth": {"wave": "sine", "f": 659.0, "dur": 0.5}, "vol": 0.05, "at": 0.06},
		{"synth": {"wave": "sine", "f": 784.0, "dur": 0.5}, "vol": 0.05, "at": 0.12}, {"synth": {"wave": "sine", "f": 1047.0, "dur": 0.5}, "vol": 0.05, "at": 0.18},
		{"synth": {"wave": "sine", "f": 1319.0, "dur": 0.5}, "vol": 0.05, "at": 0.24}, {"bank": "field", "vol": 0.15, "rate": 2.2, "dur": 0.5}],
	"pickup": [{"synth": {"wave": "sine", "f": 784.0, "dur": 0.3}, "vol": 0.045}, {"synth": {"wave": "sine", "f": 988.0, "dur": 0.3}, "vol": 0.045, "at": 0.05},
		{"synth": {"wave": "sine", "f": 1319.0, "dur": 0.3}, "vol": 0.045, "at": 0.1}, {"bank": "field", "vol": 0.12, "rate": 2.6, "dur": 0.3}],
	"crush": [{"bank": "thud", "vol": 0.5, "rate": 0.7}, {"bank": "rumble", "vol": 0.25, "dur": 0.6}, {"bank": "plate", "vol": 0.25, "rate": 0.8, "at": 0.04}],
	"crushWarn": [{"synth": {"wave": "square", "f": 520.0, "dur": 0.1, "filter": ["lowpass", 2000.0, 0.0, 1.0]}, "vol": 0.03},
		{"synth": {"wave": "square", "f": 520.0, "dur": 0.1, "filter": ["lowpass", 2000.0, 0.0, 1.0]}, "vol": 0.03, "at": 0.3},
		{"synth": {"wave": "square", "f": 520.0, "dur": 0.1, "filter": ["lowpass", 2000.0, 0.0, 1.0]}, "vol": 0.03, "at": 0.6}],
	"pylon": [{"bank": "zap", "vol": 0.35, "rate": 0.85}],
	"pylonWarn": [{"bank": "whine", "vol": 0.12, "rate": 1.3, "dur": 0.8}],
	"vent": [{"bank": "field", "vol": 0.3, "rate": 1.3, "dur": 1.4}, {"bank": "zap", "vol": 0.2, "rate": 0.6}],
	"ventsOn": [{"synth": {"wave": "square", "f": 740.0, "dur": 0.16, "filter": ["lowpass", 2500.0, 0.0, 1.0]}, "vol": 0.04},
		{"synth": {"wave": "square", "f": 740.0, "dur": 0.16, "filter": ["lowpass", 2500.0, 0.0, 1.0]}, "vol": 0.04, "at": 0.22}],
	"closing": [{"synth": {"wave": "square", "f": 880.0, "dur": 0.18, "filter": ["lowpass", 2500.0, 0.0, 1.0]}, "vol": 0.05},
		{"synth": {"wave": "square", "f": 620.0, "dur": 0.18, "filter": ["lowpass", 2500.0, 0.0, 1.0]}, "vol": 0.05, "at": 0.25},
		{"synth": {"wave": "square", "f": 880.0, "dur": 0.18, "filter": ["lowpass", 2500.0, 0.0, 1.0]}, "vol": 0.05, "at": 0.5},
		{"synth": {"wave": "square", "f": 620.0, "dur": 0.18, "filter": ["lowpass", 2500.0, 0.0, 1.0]}, "vol": 0.05, "at": 0.75}],
	"padsUp": [{"synth": {"wave": "sine", "f": 880.0, "dur": 0.18}, "vol": 0.03}, {"synth": {"wave": "sine", "f": 1320.0, "dur": 0.22}, "vol": 0.025, "at": 0.07}],
	"healUp": [{"synth": {"wave": "sine", "f": 1175.0, "dur": 0.4}, "vol": 0.045}, {"synth": {"wave": "sine", "f": 1568.0, "dur": 0.5}, "vol": 0.035, "at": 0.08}],
	"overheat": [{"bank": "thruster", "vol": 0.35, "rate": 1.4, "dur": 0.9, "offset": -1.0}],
	"overheatYou": [{"synth": {"wave": "square", "f": 880.0, "dur": 0.07, "filter": ["lowpass", 2000.0, 0.0, 1.0]}, "vol": 0.035},
		{"synth": {"wave": "square", "f": 880.0, "dur": 0.07, "filter": ["lowpass", 2000.0, 0.0, 1.0]}, "vol": 0.035, "at": 0.16},
		{"synth": {"wave": "square", "f": 880.0, "dur": 0.07, "filter": ["lowpass", 2000.0, 0.0, 1.0]}, "vol": 0.035, "at": 0.32}],
	"cooled": [{"bank": "click", "vol": 0.45, "rate": 1.3}, {"synth": {"wave": "sine", "f": 1320.0, "dur": 0.09}, "vol": 0.04, "at": 0.03}],
	"shieldUp": [{"bank": "field", "vol": 0.3, "rate": 1.8, "dur": 0.3}],
	"absorb": [{"bank": "field", "vol": 0.25, "rate": 2.4, "dur": 0.15}, {"bank": "ting", "vol": 0.2, "rate": 1.2}],
	"lowHead": [{"synth": {"wave": "sine", "f": 740.0, "dur": 0.12}, "vol": 0.03}],
	"warn": [{"synth": {"wave": "square", "f": 660.0, "dur": 0.2, "filter": ["lowpass", 2200.0, 0.0, 1.0]}, "vol": 0.05},
		{"synth": {"wave": "square", "f": 494.0, "dur": 0.2, "filter": ["lowpass", 2200.0, 0.0, 1.0]}, "vol": 0.05, "at": 0.3},
		{"synth": {"wave": "square", "f": 660.0, "dur": 0.2, "filter": ["lowpass", 2200.0, 0.0, 1.0]}, "vol": 0.05, "at": 0.6}],
	"sight": [{"bank": "whine", "vol": 0.18, "rate": 0.8, "dur": 1.8}],
	"ring": [{"bank": "plate", "vol": 0.9}, {"bank": "crunch", "vol": 0.45, "rate": 0.9, "dur": 0.5}, {"synth": {"wave": "sine", "f": 880.0, "to": 220.0, "dur": 0.6}, "vol": 0.06}],
	"coreDown": [{"bank": "rumble", "vol": 1.0}, {"bank": "crunch", "vol": 0.6, "rate": 0.6}, {"bank": "plate", "vol": 0.7, "at": 0.2}],
	"scrap": [{"bank": "clank", "vol": 0.2, "rate": 1.7}, {"bank": "ting", "vol": 0.12, "rate": 1.5, "at": 0.04}],
	"cleared": [{"synth": {"wave": "sine", "f": 784.0, "dur": 0.25}, "vol": 0.05}, {"synth": {"wave": "sine", "f": 1047.0, "dur": 0.35}, "vol": 0.05, "at": 0.12}],
	"call": [{"bank": "launch", "vol": 0.35, "rate": 0.9, "dur": 0.6}, {"synth": {"wave": "square", "f": 440.0, "dur": 0.15, "filter": ["lowpass", 2000.0, 0.0, 1.0]}, "vol": 0.04}],
	"build": [{"bank": "clank", "vol": 0.5}, {"bank": "plate", "vol": 0.35, "at": 0.1}],
	"laserWarn": [{"bank": "whine", "vol": 0.12, "rate": 1.6, "dur": 0.9}],
	"milestone": [{"bank": "launch", "vol": 0.3, "rate": 1.2, "dur": 0.5}, {"synth": {"wave": "sine", "f": 1047.0, "dur": 0.4}, "vol": 0.05, "at": 0.1}, {"synth": {"wave": "sine", "f": 1319.0, "dur": 0.5}, "vol": 0.05, "at": 0.25}],
	"mutator": [{"bank": "whine", "vol": 0.2, "rate": 0.6, "dur": 1.2}, {"bank": "rumble", "vol": 0.4, "dur": 0.8}],
	"laneLaser": [{"bank": "laser", "vol": 0.55, "rate": 0.7}, {"bank": "zap", "vol": 0.3, "rate": 0.6}],
	"ui_hover": [{"synth": {"wave": "square", "f": 600.0, "to": 900.0, "a": 0.003, "dur": 0.035, "filter": ["bandpass", 1800.0, 0.0, 3.0]}, "vol": 0.03}],
	"ui_tab": [{"synth": {"wave": "noise", "a": 0.028, "dur": 0.08, "filter": ["bandpass", 2500.0, 6000.0, 1.4]}, "vol": 0.05},
		{"synth": {"wave": "sine", "f": 1568.0, "dur": 0.05}, "vol": 0.035, "at": 0.03}],
	"ui_equip": [{"synth": {"wave": "saw", "f": 200.0, "to": 500.0, "a": 0.005, "dur": 0.12, "filter": ["bandpass", 600.0, 0.0, 3.0]}, "vol": 0.05},
		{"bank": "clank", "vol": 0.35, "rate": 1.5, "at": 0.12},
		{"synth": {"wave": "noise", "dur": 0.1, "filter": ["highpass", 4000.0, 0.0, 1.0]}, "vol": 0.04, "at": 0.13}],
	"ui_set": [{"bank": "launch", "vol": 0.25, "rate": 1.3, "dur": 0.35}, {"bank": "plate", "vol": 0.5, "at": 0.18}, {"bank": "clank", "vol": 0.3, "rate": 1.4, "at": 0.26}],
	"ui_select": [{"bank": "ting", "vol": 0.35, "rate": 1.25}],
	"ui_start": [{"bank": "punch", "vol": 0.7}, {"bank": "field", "vol": 0.3, "rate": 1.2, "dur": 0.7}],
	"ui_rewind": [{"synth": {"wave": "noise", "a": 0.15, "dur": 0.45, "filter": ["bandpass", 3200.0, 300.0, 1.4]}, "vol": 0.25}],
}

static var save_path := SAVE

var banks := {}
var shortest := {}
var loop_streams := {}
var synths := {}
var voices: Array[AudioStreamPlayer3D] = []
var flats: Array[AudioStreamPlayer] = []
var fades := {}
var next_voice := 0
var next_flat := 0
var pending := []
var music := AudioStreamPlayer.new()
var song: AudioStreamSynchronized
var stems := [0.0, 0.0, 0.0]
var level := 0
var mode := "garage"
var engines := {}
var heat := {}
var guards := {}
var last_state: Dictionary
var last_tick := -1
var chip_at := 0.0
var alarm_at := 0.0
var task := -1


func _init() -> void:
	buses()
	apply(volumes())


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for g in BANKS:
		var r := AudioStreamRandomizer.new()
		r.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
		r.random_pitch = 1.0
		shortest[g] = INF
		for i in BANKS[g][1]:
			var s: AudioStream = load(DIR + "%s_%03d.ogg" % [BANKS[g][0], i])
			r.add_stream(i, s)
			shortest[g] = minf(shortest[g], s.get_length())
		banks[g] = r
	for g in ["hover", "tread"]:
		var s: AudioStreamOggVorbis = load(DIR + "%s_000.ogg" % BANKS[g][0]).duplicate()
		s.loop = true
		loop_streams[g] = s
	for i in MIX.voices:
		var p := AudioStreamPlayer3D.new()
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.unit_size = MIX.reach
		p.max_db = 0.0
		p.panning_strength = MIX.pan
		p.attenuation_filter_db = 0.0
		add_child(p)
		voices.append(p)
	for i in MIX.flat:
		var p := AudioStreamPlayer.new()
		add_child(p)
		flats.append(p)
	music.bus = "Music"
	music.volume_db = linear_to_db(MIX.music / MIX.stem)
	add_child(music)
	task = WorkerThreadPool.add_task(bake_all)


func _exit_tree() -> void:
	WorkerThreadPool.wait_for_task_completion(task)


## Bakes every synth layer and the music stems off the main thread, then hands them over.
func bake_all() -> void:
	var out := {}
	for key in RECIPES:
		for l in RECIPES[key]:
			if l.has("synth") and not out.has(str(l.synth)):
				out[str(l.synth)] = wav(render(l.synth))
	var s := AudioStreamSynchronized.new()
	var parts := song_stems()
	s.stream_count = parts.size()
	for i in parts.size():
		s.set_sync_stream(i, wav(parts[i], true))
		s.set_sync_stream_volume(i, -80.0)
	baked.call_deferred(out, s)


func baked(out: Dictionary, s: AudioStreamSynchronized) -> void:
	synths = out
	song = s
	music.stream = song
	music.play()


## Feed this physics frame: new fx, and whether the match is paused.
func update(state: Dictionary, fresh: Array, paused: bool) -> void:
	mode = "match"
	var live: bool = state.phase == "fight" and not paused
	level = 0 if paused else (2 if state.phase == "fight" else 1)
	if not is_same(state, last_state):
		stop_engines()
		heat.clear()
		guards.clear()
		last_state = state
		last_tick = state.tick
	var moved: bool = state.tick != last_tick
	last_tick = state.tick
	run_engines(state, live, moved)
	if not paused:
		alarms(state)
	for f in fresh:
		var key := key_of(f)
		if key == "":
			continue
		if key == "hit" and f.n < 15:
			if now() - chip_at < MIX.chip:
				continue
			chip_at = now()
		var v := side(state, f) if (f.k in SIDE or f.k == "muzzle" or f.k == "slash") else 1.0
		cue(key, pos_of(f), v)


## Back to the garage: engines stop, music goes calm.
func menu() -> void:
	mode = "garage"
	level = 0
	stop_engines()


## A menu sound: hover, tab, equip, set, select, start.
func ui(kind: String) -> void:
	cue("ui_" + kind, null, 1.0)


static func key_of(f: Dictionary) -> String:
	var k: String
	match f.k:
		"muzzle":
			k = "muzzle_" + str(f.gun)
		"slash":
			k = "slash_" + str(f.blade)
		"hit":
			k = "hitHead" if f.head else "hit"
		"boom":
			k = "boomBig" if f.big else "boom"
		"count":
			k = "countGo" if f.n == 1 else "count"
		_:
			k = f.k
	return k if RECIPES.has(k) else ""


static func side(state: Dictionary, f: Dictionary) -> float:
	if f.get("id", 0) == 0:
		return 1.0
	return MIX.crowd_foe if state.mechs.size() > 2 else MIX.foe


static func pos_of(f: Dictionary):
	if f.has("x"):
		return Vector3(f.x, 1.0, f.y)
	if f.has("x1"):
		return Vector3((f.x1 + f.x2) / 2.0, 1.0, (f.y1 + f.y2) / 2.0)
	return null


func cue(key: String, pos, v: float) -> void:
	var bus := "Env" if key in ENV else "SFX"
	for l in RECIPES[key]:
		var o: Dictionary = l.duplicate()
		o.vol = l.vol * v
		o.bus = bus
		o.pos = pos
		if o.get("at", 0.0) > 0.0:
			pending.append([now() + o.at, o])
		else:
			sound(o)


func sound(o: Dictionary) -> void:
	var stream: AudioStream = banks.get(o.bank) if o.has("bank") else synths.get(str(o.synth))
	if stream == null:
		return
	var p = flats[next_flat] if o.pos == null else voices[next_voice]
	if o.pos == null:
		next_flat = (next_flat + 1) % flats.size()
	else:
		next_voice = (next_voice + 1) % voices.size()
		p.position = o.pos
	if fades.has(p):
		fades[p].kill()
		fades.erase(p)
	var rate: float = o.get("rate", 1.0)
	if o.has("bank"):
		rate *= 1.0 + randf_range(-0.5, 0.5) * o.get("vary", 0.1)
	p.stream = stream
	p.bus = o.bus
	p.volume_db = linear_to_db(maxf(o.vol, 0.0001))
	p.pitch_scale = rate
	var from: float = o.get("offset", 0.0)
	if from < 0.0:
		from = randf() * maxf(0.0, shortest[o.bank] - o.get("dur", 0.0) * rate - 0.05)
	p.play(from)
	if o.has("dur"):
		var tw := create_tween()
		tw.tween_interval(o.dur * 0.6)
		tw.tween_property(p, "volume_db", -60.0, o.dur * 0.4)
		tw.tween_callback(p.stop)
		fades[p] = tw


func run_engines(state: Dictionary, live: bool, moved: bool) -> void:
	for m in state.mechs:
		if m.has("bot"):
			continue
		var kind: String = m.loadout.legs
		var e: Dictionary = engines.get(m.id, {})
		if e.get("kind", "") != kind:
			if e.has("p"):
				e.p.queue_free()
			e = {"kind": kind, "dist": 0.0, "level": 0.0}
			if LOOPS.has(kind):
				var p := AudioStreamPlayer3D.new()
				p.stream = loop_streams[LOOPS[kind]]
				p.unit_size = MIX.reach
				p.max_db = 0.0
				p.panning_strength = MIX.pan
				p.attenuation_filter_db = 0.0
				p.bus = "SFX"
				p.volume_db = -80.0
				add_child(p)
				p.play(randf() * p.stream.get_length())
				e.p = p
			engines[m.id] = e
		var sp := Vector2(m.vx, m.vy).length()
		var on: bool = live and not m.ko
		var v := (1.0 if m.id == 0 else side(state, m)) * (1.0 if on else 0.0)
		var at := Vector3(m.x, 0.5, m.y)
		if e.has("p"):
			var target: float = (0.05 + sp * 0.012 if LOOPS[kind] == "hover" else 0.03 + sp * 0.018) * v
			e.level = lerpf(e.level, target, 0.2)
			e.p.volume_db = linear_to_db(maxf(e.level, 0.0001))
			e.p.pitch_scale = lerpf(e.p.pitch_scale, 0.8 + sp * 0.05, 0.15)
			e.p.position = at
		if not (on and moved and sp >= 0.5 and STEPS.has(kind)):
			continue
		var st: Array = STEPS[kind]
		e.dist += sp / 60.0
		if e.dist < st[0]:
			continue
		e.dist = 0.0
		sound({"bank": "step", "vol": 0.4 * v * st[2], "rate": st[1], "bus": "SFX", "pos": at})
		sound({"bank": "thud", "vol": 0.2 * v * st[2], "rate": st[1] + 0.15, "bus": "SFX", "pos": at})


func stop_engines() -> void:
	for e in engines.values():
		if e.has("p"):
			e.p.queue_free()
	engines.clear()


func alarms(state: Dictionary) -> void:
	for m in state.mechs:
		if m.has("bot"):
			continue
		var hot: bool = m.overheat > 0
		var was: bool = heat.get(m.id, false)
		var at := Vector3(m.x, 1.0, m.y)
		if hot and not was:
			cue("overheat", at, 1.0)
			if m.id == 0:
				cue("overheatYou", null, 1.0)
		elif was and not hot and m.id == 0:
			cue("cooled", null, 1.0)
		heat[m.id] = hot
		var act = m.act
		var up: bool = act != null and act.k == "shield" and act.ph == "up"
		var soaked: float = act.absorbed if up else 0.0
		var g: Array = guards.get(m.id, [false, 0.0])
		if up and not g[0]:
			cue("shieldUp", at, side(state, m))
		elif up and soaked > g[1]:
			cue("absorb", at, side(state, m))
		guards[m.id] = [up, soaked]
	var me = state.mechs[0]
	if state.phase == "fight" and not me.ko and me.armor.head < me.max.head * 0.25 and now() - alarm_at > MIX.alarm:
		alarm_at = now()
		cue("lowHead", null, 1.0)


func _process(delta: float) -> void:
	var t := now()
	for p in pending.duplicate():
		if p[0] <= t:
			pending.erase(p)
			sound(p[1])
	var ts := Engine.time_scale
	AudioServer.playback_speed_scale = lerpf(MIX.slow, 1.0, clampf(inverse_lerp(Fx.KO.slow, 1.0, ts), 0.0, 1.0)) if ts < 1.0 else 1.0
	if song == null:
		return
	for i in stems.size():
		var want := 1.0 if level >= i else 0.0
		stems[i] = move_toward(stems[i], want, delta * MIX.fade)
		song.set_sync_stream_volume(i, linear_to_db(maxf(stems[i], 0.0001)))


func now() -> float:
	return Time.get_ticks_msec() / 1000.0


## Master, SFX, Env, Crowd and Music buses with their effects. Safe to call twice.
static func buses() -> void:
	if AudioServer.get_bus_index("SFX") >= 0:
		return
	var comp := AudioEffectCompressor.new()
	comp.threshold = -14.0
	comp.ratio = 3.5
	comp.attack_us = 4000.0
	comp.release_ms = 200.0
	AudioServer.add_bus_effect(0, comp)
	AudioServer.add_bus_effect(0, AudioEffectHardLimiter.new())
	for name in ["SFX", "Env", "Crowd", "Music"]:
		var i := AudioServer.bus_count
		AudioServer.add_bus(i)
		AudioServer.set_bus_name(i, name)
		AudioServer.set_bus_send(i, "Master")
		if name == "Music":
			var duck := AudioEffectCompressor.new()
			duck.sidechain = "SFX"
			duck.threshold = -24.0
			duck.ratio = 4.0
			duck.release_ms = 300.0
			AudioServer.add_bus_effect(i, duck)
		else:
			var verb := AudioEffectReverb.new()
			verb.room_size = 0.35
			verb.damping = 0.6
			verb.wet = MIX.verb
			verb.dry = 1.0
			verb.hipass = 0.2
			AudioServer.add_bus_effect(i, verb)


static func volumes() -> Dictionary:
	var cfg := ConfigFile.new()
	cfg.load(save_path)
	var out := {}
	for k in VOLUME:
		out[k] = clampf(float(cfg.get_value("audio", k, VOLUME[k])), 0.0, 1.0)
	out.muted = bool(cfg.get_value("audio", "muted", false))
	out.music_on = bool(cfg.get_value("audio", "music_on", true))
	return out


static func apply(v: Dictionary) -> void:
	for k in VOLUME:
		var i := AudioServer.get_bus_index(k)
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v[k] * (MIX.master if k == "Master" else 1.0), 0.0001)))
	AudioServer.set_bus_mute(0, v.muted)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not v.music_on)


static func store(v: Dictionary) -> void:
	var cfg := ConfigFile.new()
	for k in v:
		cfg.set_value("audio", k, v[k])
	cfg.save(save_path)
	apply(v)


static func set_volume(bus: String, x: float) -> void:
	var v := volumes()
	v[bus] = clampf(x, 0.0, 1.0)
	store(v)


## Flips "muted" (M) or "music_on" (N).
static func toggle(key: String) -> void:
	var v := volumes()
	v[key] = not v[key]
	store(v)


## One synth voice as samples: oscillator or noise, pitch glide, filter sweep, exp envelope.
static func render(o: Dictionary) -> PackedFloat32Array:
	var rate: float = MIX.rate
	var a: float = o.get("a", 0.004)
	var dur: float = o.dur
	var n := int((a + dur + 0.05) * rate)
	var out := PackedFloat32Array()
	out.resize(n)
	var wave: String = o.wave
	var f: float = o.get("f", 0.0)
	var glide := pow(o.get("to", f) / f, 1.0 / ((a + dur) * rate)) if f > 0.0 else 1.0
	var flt: Array = o.get("filter", [])
	var ff: float = flt[1] if flt else 0.0
	var sweep := pow(flt[2] / flt[1], 1.0 / ((a + dur) * rate)) if flt and flt[2] > 0.0 else 1.0
	var c := PackedFloat32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(o))
	var ph := 0.0
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	var env := 0.0001
	var rise := pow(10000.0, 1.0 / maxf(a * rate, 1.0))
	var fall := pow(0.0001, 1.0 / (dur * rate))
	var top := int(a * rate)
	var end := int((a + dur) * rate)
	for i in n:
		var s: float
		if wave == "noise":
			s = rng.randf() * 2.0 - 1.0
		else:
			ph = fposmod(ph + f / rate, 1.0)
			if wave == "square":
				s = 1.0 if ph < 0.5 else -1.0
			elif wave == "saw":
				s = 2.0 * ph - 1.0
			elif wave == "tri":
				s = 1.0 - 4.0 * absf(ph - 0.5)
			else:
				s = sin(TAU * ph)
			if i < end:
				f *= glide
		if flt:
			if i % 16 == 0:
				c = coefs(flt[0], ff, flt[3], rate)
			var y := c[0] * s + c[1] * x1 + c[2] * x2 - c[3] * y1 - c[4] * y2
			x2 = x1
			x1 = s
			y2 = y1
			y1 = y
			s = y
			if i < end:
				ff *= sweep
		if i < top:
			env = minf(env * rise, 1.0)
		elif i < end:
			env *= fall
		else:
			env = 0.0
		out[i] = s * env
	return out


static func coefs(kind: String, f: float, q: float, rate: float) -> PackedFloat32Array:
	var w := TAU * minf(f, rate * 0.45) / rate
	var cw := cos(w)
	var al := sin(w) / (2.0 * q)
	var a0 := 1.0 + al
	var b: Array
	if kind == "lowpass":
		b = [(1.0 - cw) / 2.0, 1.0 - cw, (1.0 - cw) / 2.0]
	elif kind == "highpass":
		b = [(1.0 + cw) / 2.0, -(1.0 + cw), (1.0 + cw) / 2.0]
	else:
		b = [al, 0.0, -al]
	return PackedFloat32Array([b[0] / a0, b[1] / a0, b[2] / a0, -2.0 * cw / a0, (1.0 - al) / a0])


static func wav(data: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(data.size() * 2)
	for i in data.size():
		bytes.encode_s16(i * 2, int(clampf(data[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = int(MIX.rate)
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = data.size()
	return w


## The JS menu/fight music as 3 looping stems: 0 calm (pad, arp, hat), 1 drive (bass), 2 fight (drums, fast arp).
static func song_stems() -> Array:
	var step: float = 60.0 / MUSIC.bpm / 4.0
	var steps: int = 16 * MUSIC.bars.size()
	var length := int(steps * step * MIX.rate)
	var out := []
	for i in 3:
		var p := PackedFloat32Array()
		p.resize(length)
		out.append(p)
	var cache := {}
	for i in steps:
		var t := i * step
		for note in notes(MUSIC.bars[i / 16], i % 16, step):
			var k := str(note[1])
			if not cache.has(k):
				cache[k] = render(note[1])
			var src: PackedFloat32Array = cache[k]
			var dst: PackedFloat32Array = out[note[0]]
			var start := int(t * MIX.rate)
			var g: float = note[2] * MIX.stem
			for j in src.size():
				dst[(start + j) % length] += src[j] * g
			out[note[0]] = dst
	return out


## [stem, synth spec, volume] for one 16th step of the JS music (playStep).
static func notes(bar: Array, s: int, step: float) -> Array:
	var root: float = bar[0]
	var third: float = bar[1]
	var out := []
	if s == 0:
		for det in [-9.0, 9.0]:
			for k in [2.0, 2.0 * third, 3.0]:
				out.append([0, {"wave": "saw", "f": root * k * pow(2.0, det / 1200.0), "a": 0.6, "dur": step * 16.0, "filter": ["lowpass", 900.0, 0.0, 1.0]}, 0.027])
	var arp: float = [4.0, 4.0 * third, 6.0, 8.0, 6.0, 4.0 * third][s % 6]
	var note := {"wave": "tri", "f": root * arp, "dur": step * 1.5}
	out.append([0, note, 0.03] if s % 2 == 0 else [2, note, 0.035])
	if s % 4 == 2:
		out.append([0, {"wave": "noise", "dur": 0.025, "filter": ["highpass", 7500.0, 0.0, 1.0]}, 0.09])
	if s % 2 == 0:
		out.append([1, {"wave": "saw", "f": root * (2.0 if s % 8 == 6 else 1.0) * 0.5, "dur": step * 1.6, "filter": ["lowpass", 450.0, 0.0, 1.0]}, 0.1])
	if s % 4 == 0:
		out.append([2, {"wave": "sine", "f": 150.0, "to": 42.0, "dur": 0.16}, 0.9])
		out.append([2, {"wave": "noise", "dur": 0.01, "filter": ["highpass", 3000.0, 0.0, 1.0]}, 0.25])
	if s == 4 or s == 12:
		out.append([2, {"wave": "noise", "dur": 0.16, "filter": ["bandpass", 1900.0, 0.0, 0.7]}, 0.32])
		out.append([2, {"wave": "tri", "f": 200.0, "to": 140.0, "dur": 0.08}, 0.25])
	if s % 2 == 1:
		out.append([2, {"wave": "noise", "dur": 0.015, "filter": ["highpass", 9000.0, 0.0, 1.0]}, 0.035])
	return out
