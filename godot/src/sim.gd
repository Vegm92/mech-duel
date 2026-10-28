extends RefCounted

const TICKS := 60
const DT := 1.0 / TICKS
const DEG := PI / 180.0

const AW := 76
const AH := 60
const ACUT := 18
const ARENA := {"w": AW, "h": AH, "cut": ACUT}
const CX := 38.0
const CY := 30.0
const MECH_R := 0.8
const PILLARS := [
	{"x": CX - 6.5, "y": CY - 5.5, "r": 1.5},
	{"x": CX + 6.5, "y": CY - 5.5, "r": 1.5},
	{"x": CX - 6.5, "y": CY + 5.5, "r": 1.5},
	{"x": CX + 6.5, "y": CY + 5.5, "r": 1.5},
	{"x": CX - 17, "y": CY - 14, "r": 2.0},
	{"x": CX + 17, "y": CY - 14, "r": 2.0},
	{"x": CX - 17, "y": CY + 14, "r": 2.0},
	{"x": CX + 17, "y": CY + 14, "r": 2.0},
]
const SPAWNS := [{"x": CX - 15, "y": CY, "aim": 0.0}, {"x": CX + 15, "y": CY, "aim": PI}]
const FORMATS := {"1v1": [0, 1], "ffa": [0, 1, 2, 3], "2v2": [0, 1, 0, 1]}
const CORNERS := [[-15, -10], [15, 10], [15, -10], [-15, 10]]
const Q := 0.7071067811865476
const WALLS := [
	{"nx": 0.0, "ny": -1.0, "d": 0.0},
	{"nx": Q, "ny": -Q, "d": (AW - ACUT) * Q},
	{"nx": 1.0, "ny": 0.0, "d": float(AW)},
	{"nx": Q, "ny": Q, "d": (AW + AH - ACUT) * Q},
	{"nx": 0.0, "ny": 1.0, "d": float(AH)},
	{"nx": -Q, "ny": Q, "d": (AH - ACUT) * Q},
	{"nx": -1.0, "ny": 0.0, "d": 0.0},
	{"nx": -Q, "ny": -Q, "d": -ACUT * Q},
]

const HEAD_ARMOR := 300
const DECEL := 6.5 / 0.12
const MOVE := {"cast": 0.7, "shield": 0.6, "overheat": 0.7, "jammed": 0.7, "brake": 0.7, "slow": 0.4}
const BUFFER := 6
const MUZZLE := 0.25
const JAM := {"cd": 2, "dmg": 0.6, "dash": 0.6, "dashCd": 1.5}
const HIT := {"rear": 1.25, "rearArc": 135 * DEG, "split": 15 * DEG}
const STAGGER := {"perPoint": 12, "knockback": 0.6}
const HEAT := {"vent": 15, "ventDelay": 30, "hot": 60, "max": 100, "overheat": 60, "hotDmg": 1.3}
const SURGE := {"max": 100, "perHit": 6, "dealt": 0.08, "taken": 0.12, "perfect": 15, "carry": 0.5}

const WEAPONS := {
	"rivet": {"kind": "bolt", "shot": "bolt", "pellets": 1, "spread": 0, "jitter": 0, "speed": 60, "radius": 0.3, "range": 40, "dmg": 42, "impact": 1, "windup": 6, "recovery": 12, "cd": 48, "load": 16, "recoil": 0.2, "band": [12, 16], "fan": {"pellets": 3, "spread": 12 * DEG, "dmg": 29}},
	"needle": {"kind": "bolt", "shot": "bolt", "pellets": 1, "spread": 0, "jitter": 0, "speed": 95, "radius": 0.22, "range": 40, "dmg": 69, "impact": 2, "windup": 14, "recovery": 16, "cd": 96, "load": 26, "recoil": 0.5, "band": [16, 22], "fan": {"pellets": 1, "spread": 0, "dmg": 102}},
	"scatter": {"kind": "bolt", "shot": "bolt", "pellets": 5, "spread": 7 * DEG, "jitter": 0, "speed": 48, "radius": 0.25, "range": 12, "dmg": 21, "impact": 1, "windup": 8, "recovery": 14, "cd": 54, "load": 18, "recoil": 0.4, "band": [4, 7], "fan": {"pellets": 8, "spread": 6 * DEG, "dmg": 18}},
	"gatling": {"kind": "bolt", "auto": true, "shot": "bolt", "pellets": 1, "spread": 0, "jitter": 5 * DEG, "speed": 55, "radius": 0.2, "range": 30, "dmg": 11, "impact": 0, "windup": 2, "recovery": 4, "cd": 10, "load": 7, "recoil": 0.05, "band": [8, 13], "fan": {"pellets": 4, "spread": 4 * DEG, "dmg": 13}},
	"flamer": {"kind": "bolt", "auto": true, "shot": "flame", "pellets": 2, "spread": 9 * DEG, "jitter": 6 * DEG, "speed": 16, "radius": 0.45, "range": 6.5, "dmg": 11, "impact": 0, "windup": 2, "recovery": 4, "cd": 8, "load": 5, "recoil": 0, "band": [3, 5.5], "fan": {"pellets": 6, "spread": 8 * DEG, "dmg": 9}},
	"missiles": {"kind": "bolt", "shot": "missile", "pellets": 2, "spread": 10 * DEG, "jitter": 0, "speed": 24, "radius": 0.3, "range": 40, "dmg": 34, "impact": 1, "windup": 10, "recovery": 14, "cd": 108, "load": 20, "recoil": 0.3, "band": [10, 15], "homing": 3.2, "fan": {"pellets": 4, "spread": 14 * DEG, "dmg": 32}},
	"mortar": {"kind": "lob", "range": 16, "dmg": 154, "impact": 2, "windup": 10, "recovery": 16, "cd": 108, "load": 22, "recoil": 0.6, "band": [9, 15], "delay": 36, "splash": 1.8, "fan": {"pellets": 3, "spread": 2.6, "dmg": 98}},
	"laser": {"kind": "ray", "range": 18, "halfWidth": 0.3, "dmg": 26, "impact": 1, "windup": 8, "recovery": 12, "cd": 40, "load": 18, "recoil": 0.1, "band": [11, 17], "fan": {"pellets": 3, "spread": 8 * DEG, "dmg": 22}},
	"tesla": {"kind": "cone", "range": 7, "arc": 22 * DEG, "dmg": 71, "impact": 2, "windup": 10, "recovery": 14, "cd": 54, "load": 20, "recoil": 0, "band": [4, 6.5], "fan": {"pellets": 1, "spread": 0, "dmg": 92}},
	"ricochet": {"kind": "bolt", "shot": "bolt", "pellets": 1, "spread": 0, "jitter": 0, "speed": 45, "radius": 0.28, "range": 40, "dmg": 44, "impact": 1, "windup": 6, "recovery": 12, "cd": 52, "load": 16, "recoil": 0.2, "band": [10, 15], "bounces": 2, "fan": {"pellets": 3, "spread": 12 * DEG, "dmg": 32}},
	"saw": {"kind": "melee", "range": 2.8, "arc": 60 * DEG, "dmg": 77, "spinDmg": 66, "impact": 2, "windup": 8, "recovery": 16, "cd": 42, "load": 14, "lunge": 0.8},
	"drill": {"kind": "melee", "range": 4.2, "arc": 24 * DEG, "dmg": 116, "spinDmg": 77, "impact": 3, "windup": 10, "recovery": 18, "cd": 60, "load": 16, "lunge": 1.4},
	"hammer": {"kind": "melee", "range": 2.5, "arc": 85 * DEG, "dmg": 84, "spinDmg": 72, "impact": 4, "windup": 14, "recovery": 20, "cd": 72, "load": 18, "lunge": 0.4},
	"claws": {"kind": "melee", "range": 2.3, "arc": 50 * DEG, "dmg": 40, "spinDmg": 32, "impact": 1, "windup": 6, "recovery": 12, "cd": 34, "load": 12, "lunge": 0.6, "hits": 2, "gap": 7},
	"whip": {"kind": "melee", "range": 5, "arc": 26 * DEG, "dmg": 108, "spinDmg": 74, "impact": 2, "windup": 8, "recovery": 16, "cd": 48, "load": 14, "lunge": 0.3, "yank": 2.5},
	"bunker": {"kind": "melee", "range": 1.9, "arc": 30 * DEG, "dmg": 168, "spinDmg": 101, "impact": 4, "windup": 16, "recovery": 26, "cd": 100, "load": 24, "lunge": 2},
	"katana": {"kind": "melee", "range": 3, "arc": 70 * DEG, "dmg": 63, "spinDmg": 62, "impact": 2, "windup": 6, "recovery": 12, "cd": 34, "load": 12, "lunge": 1},
	"bash": {"kind": "melee", "range": 2.2, "arc": 95 * DEG, "dmg": 65, "spinDmg": 42, "impact": 3, "windup": 10, "recovery": 16, "cd": 50, "load": 12, "lunge": 1.2},
	"fist": {"kind": "melee", "range": 4.4, "arc": 34 * DEG, "dmg": 112, "spinDmg": 75, "impact": 3, "windup": 9, "recovery": 18, "cd": 66, "load": 16, "lunge": 3},
	"flail": {"kind": "melee", "range": 3.4, "arc": PI, "dmg": 86, "spinDmg": 86, "impact": 2, "windup": 9, "recovery": 18, "cd": 66, "load": 16, "lunge": 0.2},
}
const ARMS := {
	"wire": {"series": "light", "armor": 155, "handling": 0.88},
	"reed": {"series": "light", "armor": 168, "handling": 0.93},
	"frame": {"series": "standard", "armor": 190, "handling": 1},
	"brace": {"series": "standard", "armor": 205, "handling": 1.04},
	"bulwark": {"series": "heavy", "armor": 230, "handling": 1.08},
	"anvil": {"series": "heavy", "armor": 258, "handling": 1.13},
}
const LEG_PARTS := {
	"greaves": {"series": "standard", "move": "dash", "armor": 190, "top": 6.5, "accel": 0.12, "poise": 2},
	"hover": {"series": "light", "move": "glide", "armor": 175, "top": 8, "accel": 0.22, "poise": 2},
	"treads": {"series": "heavy", "move": "ram", "armor": 235, "top": 5.2, "accel": 0.1, "poise": 3},
	"spider": {"series": "standard", "move": "skitter", "armor": 185, "top": 6.8, "accel": 0.07, "poise": 2},
	"wheels": {"series": "light", "move": "drift", "armor": 185, "top": 9, "accel": 0.35, "poise": 2},
	"jets": {"series": "light", "move": "leap", "armor": 180, "top": 7.6, "accel": 0.16, "poise": 1},
	"stompers": {"series": "heavy", "move": "slam", "armor": 255, "top": 4.6, "accel": 0.12, "poise": 4},
	"skates": {"series": "light", "move": "double", "armor": 190, "top": 8.5, "accel": 0.3, "poise": 2},
	"quad": {"series": "standard", "move": "pounce", "armor": 182, "top": 7.4, "accel": 0.1, "poise": 2},
	"mono": {"series": "standard", "move": "roll", "armor": 195, "top": 7.8, "accel": 0.22, "poise": 2},
}
const BOOSTERS := {
	"flicker": {"series": "light", "trail": "arc", "dash": 3.8, "dashCd": 200},
	"wisp": {"series": "light", "trail": "frost", "dash": 4.5, "dashCd": 240},
	"thruster": {"series": "standard", "trail": "flame", "dash": 5, "dashCd": 300},
	"twin": {"series": "standard", "trail": "smoke", "dash": 6, "dashCd": 320},
	"comet": {"series": "heavy", "trail": "magnet", "dash": 7, "dashCd": 330},
	"rocket": {"series": "heavy", "trail": "clean", "dash": 8.5, "dashCd": 390},
}
const HEADS := {
	"rookie": {"series": "standard", "armor": 305, "surge": 1, "e": ""},
	"horn": {"series": "standard", "armor": 310, "surge": 1, "e": "lunge"},
	"pincer": {"series": "standard", "armor": 292, "surge": 1.08, "e": "hook"},
	"crest": {"series": "light", "armor": 295, "surge": 1.3, "e": "cleanse"},
	"dish": {"series": "standard", "armor": 296, "surge": 1.04, "e": "xray"},
	"visor": {"series": "light", "armor": 288, "surge": 1.4, "e": "focus"},
	"medic": {"series": "heavy", "armor": 310, "surge": 0.86, "e": "pulse"},
	"orb": {"series": "standard", "armor": 308, "surge": 0.92, "e": "frost"},
	"antenna": {"series": "standard", "armor": 290, "surge": 1.12, "e": "arcwall"},
	"dispenser": {"series": "standard", "armor": 304, "surge": 0.94, "e": "trap"},
	"demon": {"series": "heavy", "armor": 305, "surge": 0.8, "e": "brace"},
}
const ULTS := {
	"lance": {"kind": "lance", "windup": 36},
	"swarm": {"kind": "swarm", "windup": 12, "count": 8, "spread": 80 * DEG, "dmg": 28, "speed": 20, "homing": 3},
	"overdrive": {"kind": "overdrive", "windup": 6, "time": 720},
	"emp": {"kind": "emp", "windup": 24, "radius": 6, "dmg": 75, "jam": 120},
	"orbital": {"kind": "orbital", "windup": 10, "range": 20, "delay": 36, "radius": 4.2, "dmg": 160, "impact": 3},
	"repair": {"kind": "repair", "windup": 18, "amount": 50},
	"bubble": {"kind": "bubble", "windup": 6, "time": 240, "absorb": 180},
	"stasis": {"kind": "stasis", "windup": 12, "range": 14, "radius": 4.5, "time": 240, "dmg": 70},
	"mines": {"kind": "mines", "windup": 14, "count": 6, "ring": 2.5, "dmg": 55, "impact": 2, "arm": 30, "life": 720, "trigger": 1},
	"berserk": {"kind": "berserk", "windup": 6, "time": 360, "meleeDmg": 1.4, "speed": 1.25, "meleeCd": 0.6},
	"blink": {"kind": "blink", "windup": 6, "range": 9, "delay": 36, "radius": 2.2, "dmg": 110, "impact": 2},
	"well": {"kind": "well", "windup": 12, "range": 14, "radius": 5, "time": 240, "dmg": 70, "pull": 4},
	"wall": {"kind": "wall", "windup": 8, "len": 4, "dist": 2.5, "time": 240},
	"meltdown": {"kind": "meltdown", "windup": 10, "radius": 3.5, "base": 40, "perHeat": 1.4, "impact": 3},
	"deflect": {"kind": "deflect", "windup": 6, "time": 180, "radius": 3, "turn": 0.4},
	"mirror": {"kind": "mirror", "windup": 4, "time": 120, "arc": 70 * DEG},
	"rail": {"kind": "rail", "windup": 22, "length": 40, "halfWidth": 0.35, "dmg": 200, "impact": 3},
	"shroud": {"kind": "shroud", "windup": 6, "radius": 4, "time": 240},
}
const CORES := {
	"furnace": {"series": "standard", "ult": "lance", "hotAt": 50},
	"coolant": {"series": "standard", "ult": "stasis", "vent": 2, "heatGain": 0.6, "armor": 1.04},
	"reactor": {"series": "standard", "ult": "overdrive", "surgeGain": 2.0, "surgeStart": 60},
	"leech": {"series": "standard", "ult": "repair", "leech": 0.03},
	"titan": {"series": "heavy", "ult": "mines", "armor": 1.14, "speed": 0.92},
	"volt": {"series": "light", "ult": "emp", "dashCd": 0.45, "dashVentAll": true, "dashDist": 1.3},
	"fury": {"series": "standard", "ult": "berserk", "fury": 0.25},
	"flywheel": {"series": "light", "ult": "swarm", "momentum": 0.12},
	"aegis": {"series": "heavy", "ult": "bubble", "shieldCd": 0.5, "absorb": 190, "armor": 1.05},
	"glass": {"series": "light", "ult": "orbital", "dmg": 1.15, "armor": 0.88},
	"phantom": {"series": "light", "ult": "blink", "afterburn": 2, "armor": 1.08},
	"gravity": {"series": "standard", "ult": "well", "hookRange": 1.6},
	"bastion": {"series": "heavy", "ult": "wall", "absorb": 210, "armor": 1.08},
	"meltdown": {"series": "standard", "ult": "meltdown", "hotDmg": 1.5},
	"deflector": {"series": "standard", "ult": "deflect", "perfect": 1.5},
	"mirror": {"series": "standard", "ult": "mirror", "reflectDmg": 1.15},
	"rail": {"series": "standard", "ult": "rail", "boltSpeed": 1.15, "armor": 1.06},
	"shroud": {"series": "light", "ult": "shroud", "speed": 1.12, "armor": 1.12},
}
const SERIES := {"light": 1, "standard": 2, "heavy": 3}
const WEIGHT := {"base": 10, "speed": 0.025}
const BODY := ["head", "core", "arms", "legs", "booster"]
const HANDS := ["left", "right"]
const ARM_OF := {"left": "larm", "right": "rarm"}
const CATALOG := {"head": HEADS, "core": CORES, "arms": ARMS, "legs": LEG_PARTS, "booster": BOOSTERS, "left": WEAPONS, "right": WEAPONS}
const MAX_LEVEL := 3
const TWIST := {"head": ["surge", 0.06], "core": ["vent", 0.1], "arms": ["handling", -0.04], "legs": ["top", 0.03], "booster": ["dashCd", -0.06], "weapon": ["cd", -0.04]}
const DEFAULT_LOADOUT := {"head": "rookie", "core": "furnace", "arms": "frame", "legs": "greaves", "booster": "thruster", "left": "rivet", "right": "saw"}
const SETS := {
	"duelist": {"head": "horn", "core": "furnace", "arms": "frame", "legs": "greaves", "booster": "twin", "left": "rivet", "right": "drill"},
	"sniper": {"head": "visor", "core": "rail", "arms": "reed", "legs": "hover", "booster": "wisp", "left": "needle", "right": "laser"},
	"brawler": {"head": "demon", "core": "fury", "arms": "brace", "legs": "quad", "booster": "comet", "left": "claws", "right": "katana"},
	"tank": {"head": "medic", "core": "aegis", "arms": "anvil", "legs": "stompers", "booster": "rocket", "left": "scatter", "right": "hammer"},
	"speedster": {"head": "crest", "core": "volt", "arms": "wire", "legs": "wheels", "booster": "flicker", "left": "gatling", "right": "saw"},
	"artillery": {"head": "antenna", "core": "coolant", "arms": "bulwark", "legs": "treads", "booster": "thruster", "left": "mortar", "right": "missiles"},
	"assassin": {"head": "crest", "core": "phantom", "arms": "reed", "legs": "skates", "booster": "wisp", "left": "katana", "right": "whip"},
	"pyro": {"head": "pincer", "core": "meltdown", "arms": "brace", "legs": "spider", "booster": "thruster", "left": "flamer", "right": "flail"},
	"controller": {"head": "dish", "core": "gravity", "arms": "frame", "legs": "mono", "booster": "comet", "left": "tesla", "right": "ricochet"},
	"vampire": {"head": "dispenser", "core": "leech", "arms": "reed", "legs": "hover", "booster": "twin", "left": "ricochet", "right": "claws"},
	"reflector": {"head": "orb", "core": "mirror", "arms": "bulwark", "legs": "treads", "booster": "twin", "left": "bash", "right": "bunker"},
	"glasscannon": {"head": "visor", "core": "glass", "arms": "wire", "legs": "jets", "booster": "flicker", "left": "rivet", "right": "mortar"},
}
const DASH := {"ticks": 10, "endLag": 6, "slide": 0.4, "vent": 25, "afterburn": 48, "feintRefund": 0.7}
const TRAILS := {
	"arc": {"life": 72, "width": 0.5, "dmg": 25, "impact": 1, "jam": 30},
	"flame": {"life": 120, "width": 0.55, "dmg": 8, "every": 15, "heat": 6},
	"frost": {"life": 150, "width": 0.7},
	"smoke": {"life": 180, "width": 1.6},
	"magnet": {"reach": 7, "pull": 2.5},
	"clean": {},
}
const DASH_MOVES := {
	"dash": {},
	"glide": {"time": 1.6, "dist": 1.4, "steer": 0.09},
	"ram": {"hit": {"dmg": 45, "impact": 3, "push": 2.5}},
	"skitter": {"dist": 0.6, "charges": 2, "cd": 0.65},
	"drift": {"dist": 1.1, "steer": 0.06, "slide": 0.85},
	"leap": {"time": 2.2, "dist": 1.1, "air": 1.6, "land": {"r": 2.2, "dmg": 20, "stun": 30, "lift": true}},
	"slam": {"time": 1.6, "dist": 0.5, "air": 0.9, "land": {"r": 3, "dmg": 30, "impact": 3, "stun": 36}},
	"double": {"dist": 0.85, "charges": 2, "cd": 1},
	"pounce": {"time": 2, "dist": 1.3, "air": 1.4, "toCursor": true, "land": {"r": 1.6, "dmg": 28, "impact": 3}},
	"roll": {"hit": {"dmg": 35, "impact": 2, "push": 1.2, "through": true}},
	"lunge": {"hit": {"dmg": 70, "impact": 2, "push": 0}},
}
const SHIELD := {"arc": 50 * DEG, "turn": (540 * DEG) / TICKS, "perfect": 8, "minHold": 20, "maxHold": 90, "recovery": 10, "cd": 240, "perfectCd": 120, "absorb": 160, "breakStagger": 24, "breakCd": 540, "load": 20}
const BRACE := {"time": 120, "cut": 0.5, "move": 0.5, "cd": 720}
const CLEANSE := {"time": 120, "cd": 840}
const FOCUS := {"time": 180, "dmg": 1.35, "speed": 1.3, "move": 0.5, "cd": 600}
const PULSE := {"time": 180, "cd": 840, "amount": 60}
const XRAY := {"time": 90, "cd": 960}
const FROST := {"range": 10, "r": 3.0, "time": 240, "cd": 720}
const ARCWALL := {"range": 8, "len": 4, "time": 150, "cd": 720, "dmg": 10, "slow": 90}
const TRAP := {"dist": 2, "arm": 30, "life": 720, "dmg": 35, "root": 90, "cd": 540}
const LUNGE := {"dist": 6, "ticks": 15, "cd": 420}
const E_SPEC := {"brace": BRACE, "focus": FOCUS, "pulse": PULSE, "xray": XRAY, "frost": FROST, "arcwall": ARCWALL, "trap": TRAP}
const HOOK := {"range": 13, "speed": 40, "radius": 0.4, "dmg": 30, "windup": 6, "recovery": 14, "cd": 480, "load": 10, "pull": 24, "pullSpeed": 22, "stop": 1.8, "stun": 12}
const LANCE := {"windup": 36, "turn": (120 * DEG) / TICKS, "length": 16, "halfWidth": 0.7, "base": 100, "perHeat": 2, "impact": 4, "poise": 1, "recoil": 2, "recovery": 24, "stuffRefund": 50, "perfectCut": 0.5}
const ULT_RECOVERY := 20
const HEAL := {"x": CX, "y": CY, "radius": 0.9, "amount": 60, "first": 8 * TICKS, "respawn": 15 * TICKS}
const PICKUP := {"first": 5 * TICKS, "every": 12 * TICKS, "warn": 2 * TICKS, "radius": 0.7}
const PADS := [
	{"x": CX - 23, "y": CY - 10}, {"x": CX + 23, "y": CY - 10},
	{"x": CX - 23, "y": CY + 10}, {"x": CX + 23, "y": CY + 10},
	{"x": CX, "y": CY - 12}, {"x": CX, "y": CY + 12},
	{"x": CX - 28, "y": CY}, {"x": CX + 28, "y": CY},
]
const ITEMS := {
	"repair": {"amount": 40},
	"shield": {"absorb": 120, "time": 8 * TICKS},
	"speed": {"time": 6 * TICKS, "speed": 1.35, "dashCd": 0.5},
	"power": {"time": 6 * TICKS, "dmg": 1.25},
	"coolant": {"time": 5 * TICKS},
	"surge": {"amount": 35},
}
const TRAPS := {
	"crush": {"at": [{"x": CX - 10, "y": 8}, {"x": CX + 10, "y": AH - 8}, {"x": CX + 10, "y": 8}, {"x": CX - 10, "y": AH - 8}], "half": 1.5, "every": 6 * TICKS, "warn": TICKS, "dmg": 55, "impact": 3},
	"tesla": {"at": [{"x": CX, "y": CY - 5.5}, {"x": CX, "y": CY + 5.5}, {"x": CX, "y": CY - 18}, {"x": CX, "y": CY + 18}], "r": 0.45, "reach": 3, "every": 4 * TICKS, "warn": 48, "dmg": 40, "impact": 1},
	"oil": {"at": [{"x": CX - 6.5, "y": CY}, {"x": CX + 6.5, "y": CY}], "r": 2, "grip": 0.2},
}
const HAZARDS := {"vents": 20 * TICKS, "slot": 3 * TICKS, "warn": TICKS, "burn": 90, "reach": 5, "half": 1, "dmg": 12, "slow": 40, "every": 30, "close": 45 * TICKS, "shrink": 18, "wallDmg": 4, "wallEvery": 15}
const SOLIDS := [
	{"x": CX - 6.5, "y": CY - 5.5, "r": 1.5}, {"x": CX + 6.5, "y": CY - 5.5, "r": 1.5},
	{"x": CX - 6.5, "y": CY + 5.5, "r": 1.5}, {"x": CX + 6.5, "y": CY + 5.5, "r": 1.5},
	{"x": CX - 17, "y": CY - 14, "r": 2.0}, {"x": CX + 17, "y": CY - 14, "r": 2.0},
	{"x": CX - 17, "y": CY + 14, "r": 2.0}, {"x": CX + 17, "y": CY + 14, "r": 2.0},
	{"x": CX, "y": CY - 5.5, "r": 0.45}, {"x": CX, "y": CY + 5.5, "r": 0.45},
	{"x": CX, "y": CY - 18, "r": 0.45}, {"x": CX, "y": CY + 18, "r": 0.45},
]
const DUEL_GEO := {"walls": WALLS, "pillars": PILLARS, "solids": SOLIDS}
const MATCH := {"wins": 3, "countdown": 3 * TICKS, "time": 60 * TICKS, "ko": 150, "hitstop": 5, "breakStop": 7, "koStop": 24}
const IDLE := {"mx": 0, "my": 0, "ax": 0, "ay": 0, "left": false, "right": false, "hook": false, "shield": false, "dash": false, "ult": false}


static func hypot(x: float, y: float) -> float:
	var ax := absf(x)
	var ay := absf(y)
	var top := maxf(ax, ay)
	if top == 0.0:
		return 0.0
	var a := ax / top
	var b := ay / top
	return sqrt(a * a + b * b) * top


static func jround(v: float) -> float:
	var c := ceilf(v)
	return c if c - 0.5 <= v else c - 1.0


static func imul(a: int, b: int) -> int:
	a &= 0xFFFFFFFF
	b &= 0xFFFFFFFF
	return ((a & 0xFFFF) * b + ((((a >> 16) * b) & 0xFFFF) << 16)) & 0xFFFFFFFF


static func rng(holder: Dictionary) -> float:
	holder.seed = (int(holder.seed) + 0x6d2b79f5) & 0xFFFFFFFF
	var t: int = holder.seed
	t = imul(t ^ (t >> 15), t | 1)
	t ^= (t + imul(t ^ (t >> 7), t | 61)) & 0xFFFFFFFF
	return float((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0


static func uniq(a: Array) -> Array:
	var out := []
	for v in a:
		if not out.has(v):
			out.append(v)
	return out


static func spawns_of(teams: Array) -> Array:
	if teams.size() == 2:
		return SPAWNS
	var duo := uniq(teams).size() == 2
	var out := []
	for i in teams.size():
		var team = teams[i]
		var dx: float
		var dy: float
		if duo:
			dx = 15.0 if team else -15.0
			dy = -6.0 if teams.find(team) == i else 6.0
		else:
			dx = CORNERS[i][0]
			dy = CORNERS[i][1]
		out.append({"x": CX + dx, "y": CY + dy, "aim": atan2(-dy, -dx)})
	return out


static func arena_corners(o := 0.0) -> Array:
	var out := []
	var n := WALLS.size()
	for i in n:
		var a = WALLS[i]
		var b = WALLS[(i + 1) % n]
		var det: float = a.nx * b.ny - a.ny * b.nx
		out.append({"x": ((a.d + o) * b.ny - (b.d + o) * a.ny) / det, "y": (a.nx * (b.d + o) - b.nx * (a.d + o)) / det})
	return out


static func clamp_arena(x: float, y: float, pad := 0.0, walls: Array = WALLS) -> Dictionary:
	for _pass in 2:
		for w in walls:
			var o: float = x * w.nx + y * w.ny - (w.d - pad)
			if o > 0:
				x -= w.nx * o
				y -= w.ny * o
	return {"x": x, "y": y}


static func geo(state) -> Dictionary:
	return state.geo if state.has("geo") else DUEL_GEO


static func in_gap(ring: Dictionary, x: float, y: float, pad: float) -> bool:
	for gp in ring.gaps:
		if x * gp.dx + y * gp.dy > 0 and absf(y * gp.dx - x * gp.dy) < gp.get("half", ring.half) - pad:
			return true
	return false


static func struck(state, g: Dictionary, s) -> bool:
	var team = state.mechs[s.owner].team
	for b in g.boxes:
		if b.get("only", team) != team or b.get("hp", 1) <= 0:
			continue
		if s.x < b.x0 - s.r or s.x > b.x1 + s.r or s.y < b.y0 - s.r or s.y > b.y1 + s.r:
			continue
		if b.has("hp"):
			b.hp = maxf(0, b.hp - s.dmg * b.get("soak", 1.0))
		state.fx.append({"k": "ping", "x": s.x, "y": s.y, "a": atan2(s.vy, s.vx), "t": 8})
		return true
	for p in g.pillars:
		if p.has("hp") and p.get("only", team) == team and hypot(s.x - p.x, s.y - p.y) < p.r + s.r:
			p.hp = maxf(0, p.hp - s.dmg)
			state.fx.append({"k": "ping", "x": s.x, "y": s.y, "a": atan2(s.vy, s.vx), "t": 8})
			return true
	if not s.get("high", false):
		var d := hypot(s.x, s.y)
		for r in g.get("rings", []):
			if d > r.r0 - s.r and d < r.r1 + s.r and not in_gap(r, s.x, s.y, 0.0):
				state.fx.append({"k": "ping", "x": s.x, "y": s.y, "a": atan2(s.vy, s.vx), "t": 8})
				return true
	return false


static func elapsed(state) -> int:
	return MATCH.time - int(state.clock)


static func cycle(state, every: int, i: int) -> int:
	return (elapsed(state) + (i * every) / 2) % every


static func until_slam(state, i: int) -> int:
	return TRAPS.crush.every - cycle(state, TRAPS.crush.every, i)


static func until_zap(state, i: int) -> int:
	return TRAPS.tesla.every - cycle(state, TRAPS.tesla.every, i)


static func shrink_of(state) -> float:
	return maxf(0.0, minf(1.0, float(elapsed(state) - HAZARDS.close) / float(MATCH.time - HAZARDS.close))) * HAZARDS.shrink


static func on_oil(m) -> bool:
	if m.loadout.legs == "hover":
		return false
	for p in TRAPS.oil.at:
		if hypot(m.x - p.x, m.y - p.y) < TRAPS.oil.r:
			return true
	return false


static func vent_phase(state):
	var e := elapsed(state) - HAZARDS.vents
	if e < 0:
		return null
	var p := e % HAZARDS.slot
	return {"set": (e / HAZARDS.slot) % 2, "p": p, "warn": p < HAZARDS.warn, "burn": p >= HAZARDS.warn and p < HAZARDS.warn + HAZARDS.burn}


static func vents(shrink := 0.0) -> Array:
	var c := arena_corners(-shrink)
	var out := []
	var n := WALLS.size()
	for i in n:
		var w = WALLS[i]
		var a = c[(i + n - 1) % n]
		for f in [0.25, 0.5, 0.75]:
			out.append({"wall": i, "x": a.x + (c[i].x - a.x) * f, "y": a.y + (c[i].y - a.y) * f, "dx": -w.nx, "dy": -w.ny})
	return out


static func normalize(lo) -> Dictionary:
	var out := {}
	for slot in DEFAULT_LOADOUT:
		var ok: bool = lo is Dictionary and lo.has(slot) and lo[slot] is String and CATALOG[slot].has(lo[slot])
		out[slot] = lo[slot] if ok else DEFAULT_LOADOUT[slot]
	if lo is Dictionary and lo.get("lv") is Dictionary:
		var lv := {}
		for slot in DEFAULT_LOADOUT:
			var n = lo.lv.get(slot, 1)
			if (n is int or n is float) and n > 1:
				lv[slot] = clampi(int(n), 1, MAX_LEVEL)
		if not lv.is_empty():
			out.lv = lv
	return out


static func tuned(slot: String, key: String, lv: int) -> Dictionary:
	var row: Dictionary = CATALOG[slot][key]
	if lv <= 1:
		return row
	var t: Array = TWIST[slot if BODY.has(slot) else "weapon"]
	var out := row.duplicate()
	out[t[0]] = out.get(t[0], 1) * (1 + t[1] * (lv - 1))
	return out


static func max_armor(lo) -> Dictionary:
	var l := normalize(lo)
	var k: float = CORES[l.core].get("armor", 1)
	return {"head": jround(HEADS[l.head].armor * k), "rarm": jround(ARMS[l.arms].armor * k), "larm": jround(ARMS[l.arms].armor * k), "legs": jround(LEG_PARTS[l.legs].armor * k)}


static func weight_of(lo) -> int:
	var n := 0
	for slot in BODY:
		n += SERIES[CATALOG[slot][lo[slot]].series]
	return n


static func speed_of(lo) -> float:
	return 1 + (WEIGHT.base - weight_of(lo)) * WEIGHT.speed


static func weapon(m, hand):
	return m.rows[hand] if m.has("rows") else WEAPONS[m.loadout[hand]]


static func is_gun(w) -> bool:
	return w.kind != "melee"


static func arms(m):
	return m.rows.arms if m.has("rows") else ARMS[m.loadout.arms]


static func feet(m):
	return m.rows.legs if m.has("rows") else LEG_PARTS[m.loadout.legs]


static func booster(m):
	return m.rows.booster if m.has("rows") else BOOSTERS[m.loadout.booster]


static func move_of(m):
	return DASH_MOVES[feet(m).move]


static func ak(m) -> String:
	return m.act.k if m.act != null else ""


static func hidden(state, m) -> bool:
	if state.has("geo"):
		for st in state.geo.get("steam", []):
			if hypot(m.x - st.x, m.y - st.y) < st.r:
				return true
	for tr in state.trails:
		if tr.kind == "smoke" and seg_dist(tr.x1, tr.y1, tr.x2, tr.y2, m.x, m.y) < tr.get("w", TRAILS.smoke.width):
			return true
	return false


static func rad(m) -> float:
	return m.get("r", MECH_R)


static func airborne(m) -> bool:
	return m.act != null and m.act.k == "dash" and m.act.ph == "go" and DASH_MOVES[m.act.move].has("air")


static func height_of(m) -> float:
	if airborne(m):
		return sin(PI * (1 - float(m.act.t) / float(m.act.T))) * DASH_MOVES[m.act.move].air
	if m.lift > 0:
		return sin((PI * m.lift) / float(m.liftT)) * 0.9
	return 0.0


static func charges(lo) -> int:
	return DASH_MOVES[LEG_PARTS[lo.legs].move].get("charges", 1)


static func head(m):
	return m.rows.head if m.has("rows") else HEADS[m.loadout.head]


static func core(m):
	return m.rows.core if m.has("rows") else CORES[m.loadout.core]


static func e_skill(m) -> String:
	return head(m).e


static func e_active(m) -> bool:
	return m.buffs.get(e_skill(m), 0) > 0


static func ult_of(lo) -> String:
	return CORES[lo.core].ult


static func ult(m):
	return ULTS[core(m).ult]


static func surge_k(m) -> float:
	return core(m).get("surgeGain", 1) * head(m).surge


static func angle_diff(a: float, b: float) -> float:
	var d := fmod(a - b, TAU)
	if d > PI:
		d -= TAU
	if d < -PI:
		d += TAU
	return d


static func turn_toward(from: float, to: float, most: float) -> float:
	return from + clampf(angle_diff(to, from), -most, most)


static func in_arc(center: float, half: float, dx: float, dy: float) -> bool:
	return absf(angle_diff(atan2(dy, dx), center)) <= half


static func seg_dist(x0: float, y0: float, x1: float, y1: float, px: float, py: float) -> float:
	var dx := x1 - x0
	var dy := y1 - y0
	var den := dx * dx + dy * dy
	if den == 0:
		den = 1
	var k := clampf(((px - x0) * dx + (py - y0) * dy) / den, 0, 1)
	return hypot(x0 + dx * k - px, y0 + dy * k - py)


static func clear_line(x0: float, y0: float, x1: float, y1: float, pillars: Array = PILLARS) -> bool:
	for p in pillars:
		if seg_dist(x0, y0, x1, y1, p.x, p.y) <= p.r:
			return false
	return true


static func jammed(m, part: String) -> bool:
	return m.armor[part] <= 0


static func arm_cd(m, part: String, cd: float) -> float:
	return cd * JAM.cd if jammed(m, part) else cd


static func skill_cd(m, k: String) -> float:
	if k == "hook":
		return HOOK.cd
	var w = weapon(m, k)
	return jround(arm_cd(m, ARM_OF[k], w.cd * arms(m).handling) * (ULTS.berserk.meleeCd if not is_gun(w) and m.buffs.berserk > 0 else 1))


static func hand_time(m, ticks) -> float:
	return jround(ticks * arms(m).handling)


static func windup_of(m, k: String) -> float:
	if ARM_OF.has(k):
		return hand_time(m, weapon(m, k).windup)
	return HOOK.windup if k == "hook" else ult(m).windup


static func recovery_of(m, k: String) -> float:
	if ARM_OF.has(k):
		return hand_time(m, weapon(m, k).recovery)
	if k == "hook":
		return HOOK.recovery
	return LANCE.recovery if ult(m).kind == "lance" else ULT_RECOVERY


static func shield_up(m) -> bool:
	return m.act != null and m.act.k == "shield" and m.act.ph == "up"


static func lancing(m) -> bool:
	return m.act != null and m.act.k == "ult" and m.act.ph == "wind" and ult(m).kind == "lance"


static func poise_of(m) -> int:
	return feet(m).poise + (LANCE.poise if lancing(m) else 0)


static func hot_of(m) -> bool:
	return m.heat >= core(m).get("hotAt", HEAT.hot)


static func next_cast(state) -> int:
	var c: int = state.nextCast
	state.nextCast = c + 1
	return c


static func power(m, melee: bool) -> float:
	var c = core(m)
	var k: float = c.get("dmg", 1) * (ITEMS.power.dmg if m.buffs.power > 0 else 1)
	if c.has("fury"):
		k *= 1 + c.fury * clampf((1 - m.armor.head / float(m.max.head)) / 0.75, 0, 1)
	if c.has("momentum"):
		k *= 1 + c.momentum * minf(1, hypot(m.vx, m.vy) / feet(m).top)
	if melee and m.buffs.berserk > 0:
		k *= ULTS.berserk.meleeDmg
	return k


static func make_mech(id: int, loadout, team: int, s) -> Dictionary:
	var lo := normalize(loadout)
	var mx := max_armor(lo)
	var m := {
		"id": id, "team": team, "loadout": lo, "max": mx, "x": float(s.x), "y": float(s.y), "vx": 0.0, "vy": 0.0, "aim": float(s.aim), "tx": float(s.x), "ty": float(s.y),
		"armor": mx.duplicate(), "heat": 0.0, "ventDelay": 0, "overheat": 0, "surge": CORES[lo.core].get("surgeStart", 0),
		"cd": {"left": 0, "right": 0, "hook": 0, "shield": 0, "dash": 0},
		"buf": {"left": 0, "right": 0, "hook": 0, "dash": 0, "ult": 0},
		"held": {"left": false, "right": false, "hook": false, "shield": false, "dash": false, "ult": false},
		"buffs": {"overdrive": 0, "berserk": 0, "bubble": 0, "bubbleHp": 0, "jam": 0, "slow": 0, "speed": 0, "power": 0, "cool": 0, "deflect": 0, "mirror": 0, "brace": 0, "cleanse": 0, "focus": 0, "pulse": 0, "xray": 0, "root": 0},
		"act": null, "stagger": 0, "pull": null, "afterburn": 0, "lastHitCast": 0, "ko": false, "dashes": charges(lo), "lift": 0, "liftT": 1,
	}
	if lo.has("lv"):
		var rows := {}
		for slot in DEFAULT_LOADOUT:
			rows[slot] = tuned(slot, lo[slot], lo.lv.get(slot, 1))
		m.rows = rows
	return m


static func create_state(loadouts: Array = [], teams: Array = FORMATS["1v1"]) -> Dictionary:
	var spawns := spawns_of(teams)
	var mechs := []
	for i in teams.size():
		mechs.append(make_mech(i, loadouts[i] if i < loadouts.size() else null, teams[i], spawns[i]))
	var score := []
	score.resize(teams.max() + 1)
	score.fill(0)
	var state := {
		"tick": 0, "seed": 0x2545f491, "mechs": mechs,
		"shots": [], "lobs": [], "mines": [], "fields": [], "trails": [], "walls": [], "fx": [],
		"phase": "countdown", "timer": MATCH.countdown, "clock": MATCH.time, "round": 1, "hitstop": 0,
		"heal": {"ready": false, "timer": HEAL.first},
		"score": score, "winner": -1, "nextCast": 1, "shrink": 0.0, "finalKo": -1,
	}
	return reset_pads(state)


static func foes(state, id) -> Array:
	var team = state.mechs[id].team
	return state.mechs.filter(func(t): return not t.ko and t.team != team)


static func turns(state) -> Array:
	var n: int = state.mechs.size()
	var out := []
	for i in n:
		out.append(state.mechs[(i + int(state.tick)) % n])
	return out


static func reset_pads(state) -> Dictionary:
	var pads := []
	pads.resize(PADS.size())
	state.pads = pads
	state.wave = {"t": PICKUP.first, "next": roll_wave(state)}
	return state


static func roll_wave(state) -> Array:
	var kinds := ITEMS.keys()
	var out := []
	for i in PADS.size():
		if i % 2 == 0:
			out.append(kinds.pop_at(int(floor(rng(state) * kinds.size()))))
	return out


static func step(state, inputs: Array):
	state.tick += 1
	age_fx(state)
	var ins := []
	for i in state.mechs.size():
		ins.append(inputs[i] if i < inputs.size() and inputs[i] != null else IDLE)
	if state.hitstop > 0:
		state.hitstop -= 1
		for i in state.mechs.size():
			read_buttons(state.mechs[i], ins[i], false)
		return state
	if state.phase == "countdown":
		if int(state.timer) % TICKS == 0:
			state.fx.append({"k": "count", "n": int(state.timer) / TICKS, "t": 50} if state.timer > 0 else {"k": "fight", "t": 50})
		for i in state.mechs.size():
			var m = state.mechs[i]
			read_buttons(m, ins[i], true)
			m.tx = ins[i].ax
			m.ty = ins[i].ay
			m.aim = atan2(m.ty - m.y, m.tx - m.x)
		var was = state.timer
		state.timer -= 1
		if was == 0:
			state.phase = "fight"
		return state
	if state.phase == "ko":
		state.timer -= 1
		if state.timer > 0:
			return state
		if state.score.max() >= MATCH.wins:
			state.phase = "over"
		else:
			reset_round(state)
		return state
	if state.phase == "over":
		return state
	state.shrink = shrink_of(state)
	for m in turns(state):
		if not m.ko:
			think(state, m, ins[m.id])
	world(state)
	for m in state.mechs:
		collide(m, state.shrink, geo(state))
	var live = state.mechs.filter(func(m): return not m.ko)
	for i in live.size():
		for j in range(i + 1, live.size()):
			separate(live[i], live[j])
	pickups(state)
	traps(state)
	check_ko(state)
	if state.phase == "fight":
		state.clock -= 1
		if state.clock <= 0:
			time_up(state)
	return state


static func world(state) -> void:
	move_shots(state)
	update_lobs(state)
	update_mines(state)
	update_fields(state)
	update_trails(state)
	zap_walls(state)
	var walls := []
	for w in state.walls:
		w.t -= 1
		if w.t > 0:
			walls.append(w)
	state.walls = walls


static func age_fx(state) -> void:
	var fx := []
	for f in state.fx:
		f.t -= 1
		if f.t > 0:
			fx.append(f)
	state.fx = fx


static func hash_state(state) -> int:
	return JSON.stringify(state, "", true, true).hash()


static func read_buttons(m, inp, decay: bool) -> void:
	for k in m.buf:
		if inp.get(k, false) and not m.held[k]:
			m.buf[k] = BUFFER
		elif decay and m.buf[k] > 0 and m.stagger == 0:
			m.buf[k] -= 1
	for k in m.held:
		m.held[k] = true if inp.get(k, false) else false


static func think(state, m, inp) -> void:
	read_buttons(m, inp, true)
	m.tx = inp.ax
	m.ty = inp.ay
	tick_timers(m)
	pulse_tick(state, m)
	var aim_to := atan2(inp.ay - m.y, inp.ax - m.x)
	if not lancing(m):
		m.aim = aim_to
	advance(state, m, inp, aim_to)
	start(state, m, inp)
	if lancing(m):
		m.aim = m.act.angle
	move(state, m, inp)


static func tick_timers(m) -> void:
	var n := 2 if m.buffs.overdrive > 0 else 1
	for k in m.cd:
		m.cd[k] = max(0, m.cd[k] - n)
	if m.cd.dash == 0 and m.dashes < charges(m.loadout):
		m.dashes += 1
		if m.dashes < charges(m.loadout):
			m.cd.dash = dash_recharge(m)
	if m.lift > 0:
		m.lift -= 1
	for k in m.buffs:
		if k != "bubbleHp" and m.buffs[k] > 0:
			m.buffs[k] -= 1
	if m.afterburn > 0:
		m.afterburn -= 1
	if m.stagger > 0:
		m.stagger -= 1
	if m.overheat > 0:
		m.overheat -= 1
		m.heat = (HEAT.max * m.overheat) / float(HEAT.overheat)
	elif m.ventDelay > 0:
		m.ventDelay -= 1
	else:
		m.heat = maxf(0.0, m.heat - HEAT.vent * core(m).get("vent", 1) * DT)


static func add_heat(m, n) -> void:
	if m.buffs.overdrive > 0 or m.buffs.cool > 0:
		return
	m.heat += n * core(m).get("heatGain", 1)
	m.ventDelay = HEAT.ventDelay
	if m.heat >= HEAT.max:
		m.heat = HEAT.max
		m.overheat = HEAT.overheat


static func push(m, dx: float, dy: float, meters: float) -> void:
	var v := sqrt(2 * DECEL * meters)
	m.vx += dx * v
	m.vy += dy * v


static func advance(state, m, inp, aim_to: float) -> void:
	var a = m.act
	if a == null:
		return
	if shield_up(m):
		a.t += 1
		a.angle = turn_toward(a.angle, aim_to, SHIELD.turn)
		if (not inp.shield and a.t >= SHIELD.minHold) or a.t >= SHIELD.maxHold:
			m.cd.shield = jround((SHIELD.perfectCd if a.perfect else SHIELD.cd) * core(m).get("shieldCd", 1))
			m.act = {"k": "shield", "ph": "rec", "t": SHIELD.recovery}
		return
	if lancing(m):
		a.angle = turn_toward(a.angle, aim_to, LANCE.turn)
	if a.k == "dash" and a.ph == "go":
		var mv = DASH_MOVES[a.move]
		if mv.has("steer") and (inp.mx or inp.my):
			var ang := turn_toward(atan2(a.dy, a.dx), atan2(inp.my, inp.mx), mv.steer)
			a.dx = cos(ang)
			a.dy = sin(ang)
		m.vx = a.dx * a.speed
		m.vy = a.dy * a.speed
		if a.trail != null:
			a.trail.x2 = m.x
			a.trail.y2 = m.y
		if mv.has("hit") and not a.hit:
			bump(state, m, a, mv.hit)
	a.t -= 1
	if a.t > 0:
		return
	if a.ph == "wind":
		var w = weapon(m, a.k) if ARM_OF.has(a.k) else null
		if a.k == "hook":
			throw_hook(state, m)
		elif w == null:
			fire_ult(state, m, a)
		elif is_gun(w):
			fire(state, m, a.k, a.follow)
		else:
			swing(state, m, a.k, a.follow)
		var more = w.get("hits", 1) - 1 if w != null and not is_gun(w) and not a.follow else 0
		m.act = {"k": a.k, "ph": "combo", "t": w.gap, "n": more} if more > 0 else {"k": a.k, "ph": "rec", "t": recovery_of(m, a.k)}
	elif a.ph == "combo":
		swing(state, m, a.k, false)
		m.act = {"k": a.k, "ph": "combo", "t": weapon(m, a.k).gap, "n": a.n - 1} if a.n > 1 else {"k": a.k, "ph": "rec", "t": recovery_of(m, a.k)}
	elif a.k == "dash" and a.ph == "go":
		var mv = DASH_MOVES[a.move]
		m.vx *= mv.get("slide", DASH.slide)
		m.vy *= mv.get("slide", DASH.slide)
		if mv.has("land"):
			land(state, m, mv.land)
		if booster(m).trail == "magnet" and a.move != "lunge":
			magnetize(state, m)
		m.act = {"k": "dash", "ph": "lag", "t": DASH.endLag}
	else:
		if a.k == "dash":
			m.afterburn = jround(DASH.afterburn * core(m).get("afterburn", 1))
		m.act = null


static func start(state, m, inp) -> void:
	if e_skill(m) == "cleanse" and m.buf.hook and m.cd.hook == 0:
		m.buf.hook = 0
		m.cd.hook = CLEANSE.cd
		m.buffs.cleanse = CLEANSE.time
		m.buffs.jam = 0
		m.buffs.slow = 0
		m.buffs.root = 0
		m.stagger = 0
		m.pull = null
		state.fx.append({"k": "cleanse", "id": m.id, "x": m.x, "y": m.y, "t": 14})
	if m.stagger > 0 or m.overheat > 0 or m.pull != null or m.buffs.jam > 0:
		return
	var a = m.act
	var windup: bool = a != null and a.ph == "wind"
	var attack_rec: bool = a != null and a.ph == "rec" and (ARM_OF.has(a.k) or a.k == "hook")
	if m.buf.dash and m.dashes > 0 and m.buffs.slow == 0 and m.buffs.root == 0 and (a == null or windup or attack_rec):
		dash(state, m, inp, a if windup else null)
		return
	var spec = E_SPEC.get(e_skill(m))
	if spec != null and m.buf.hook and m.cd.hook == 0:
		m.buf.hook = 0
		m.cd.hook = spec.cd
		cast_e(state, m, e_skill(m), spec)
	if a != null:
		return
	if e_skill(m) == "lunge" and m.buf.hook and m.cd.hook == 0:
		m.buf.hook = 0
		m.cd.hook = LUNGE.cd
		lunge(state, m)
		return
	if m.buf.ult and m.surge >= SURGE.max:
		m.buf.ult = 0
		m.surge -= SURGE.max
		m.act = {"k": "ult", "ph": "wind", "t": ult(m).windup, "angle": m.aim}
		state.fx.append({"k": "charge", "id": m.id, "ult": ult(m).kind, "x": m.x, "y": m.y, "t": ult(m).windup})
		return
	if inp.shield and m.cd.shield == 0:
		add_heat(m, SHIELD.load)
		m.act = {"k": "shield", "ph": "up", "t": 0, "angle": m.aim, "absorbed": 0, "perfect": false}
		return
	var guns := []
	var order := []
	for h in HANDS:
		if is_gun(weapon(m, h)):
			guns.append(h)
		else:
			order.append(h)
	if e_skill(m) == "hook":
		order.append("hook")
	order.append_array(guns)
	for k in order:
		var want: bool = m.buf[k] or (k != "hook" and weapon(m, k).get("auto", false) and m.held[k])
		if not want or m.cd[k] > 0:
			continue
		m.buf[k] = 0
		m.cd[k] = skill_cd(m, k)
		m.act = {"k": k, "ph": "wind", "t": windup_of(m, k), "follow": k != "hook" and m.afterburn > 0}
		if k != "hook":
			m.afterburn = 0
		return


static func dash_recharge(m) -> float:
	return jround(booster(m).dashCd * move_of(m).get("cd", 1) * (JAM.dashCd if jammed(m, "legs") else 1) * core(m).get("dashCd", 1) * (ITEMS.speed.dashCd if m.buffs.speed > 0 else 1))


static func dash(state, m, inp, feinted) -> void:
	if feinted != null and feinted.k == "ult":
		m.surge += SURGE.max * DASH.feintRefund
	elif feinted != null:
		m.cd[feinted.k] = floor(skill_cd(m, feinted.k) * (1 - DASH.feintRefund))
	var mv = move_of(m)
	var to_cursor: bool = mv.get("toCursor", false)
	var dx: float = 0.0 if to_cursor else inp.mx
	var dy: float = 0.0 if to_cursor else inp.my
	var ln := hypot(dx, dy)
	if ln == 0:
		dx = inp.ax - m.x
		dy = inp.ay - m.y
		ln = hypot(dx, dy)
		if ln == 0:
			ln = 1
	var legs := jammed(m, "legs")
	m.buf.dash = 0
	m.dashes -= 1
	if m.cd.dash == 0:
		m.cd.dash = dash_recharge(m)
	m.heat = 0.0 if core(m).get("dashVentAll", false) else maxf(0.0, m.heat - DASH.vent)
	var ticks := jround(DASH.ticks * mv.get("time", 1))
	var dist: float = booster(m).dash * core(m).get("dashDist", 1) * mv.get("dist", 1) * (JAM.dash if legs else 1)
	if to_cursor:
		dist = minf(dist, maxf(1, ln))
	var ux := dx / ln
	var uy := dy / ln
	var end := clamp_arena(m.x + ux * dist, m.y + uy * dist, MECH_R + state.shrink, geo(state).walls)
	var kind = booster(m).trail
	var trail = null
	if TRAILS[kind].has("life"):
		trail = {"kind": kind, "owner": m.id, "x1": m.x, "y1": m.y, "x2": m.x, "y2": m.y, "t": TRAILS[kind].life, "T": TRAILS[kind].life, "cast": 0, "hit": false}
		state.trails.append(trail)
	m.act = {"k": "dash", "ph": "go", "t": ticks, "T": ticks, "move": feet(m).move, "dx": ux, "dy": uy, "speed": (dist / ticks) * TICKS, "lx": end.x, "ly": end.y, "hit": false, "trail": trail}
	state.fx.append({"k": "dash", "id": m.id, "x": m.x, "y": m.y, "t": 6})


static func magnetize(state, m) -> void:
	var M = TRAILS.magnet
	for t in foes(state, m.id):
		var d := hypot(m.x - t.x, m.y - t.y)
		if airborne(t) or d > M.reach or d < 2 * rad(t):
			continue
		push(t, (m.x - t.x) / d, (m.y - t.y) / d, M.pull)
		state.fx.append({"k": "magnet", "id": m.id, "x": m.x, "y": m.y, "x1": m.x, "y1": m.y, "x2": t.x, "y2": t.y, "t": 18})


static func update_trails(state) -> void:
	var keep := []
	for tr in state.trails:
		var T = TRAILS[tr.kind]
		var atk = state.mechs[tr.owner]
		for t in foes(state, tr.owner):
			if airborne(t) or seg_dist(tr.x1, tr.y1, tr.x2, tr.y2, t.x, t.y) >= T.width + rad(t):
				continue
			var frm := atan2((tr.y1 + tr.y2) / 2.0 - t.y, (tr.x1 + tr.x2) / 2.0 - t.x)
			if not tr.cast:
				tr.cast = next_cast(state)
			if tr.kind == "arc" and not tr.hit:
				tr.hit = true
				hit(state, atk, t, floor(T.dmg * power(atk, false)), "ARMS", T.impact, frm, tr.cast)
				if not warded(t):
					t.buffs.jam = max(t.buffs.jam, T.jam)
				state.fx.append({"k": "zap", "kind": "tesla", "id": atk.id, "x1": (tr.x1 + tr.x2) / 2.0, "y1": (tr.y1 + tr.y2) / 2.0, "x2": t.x, "y2": t.y, "t": 10})
			elif tr.kind == "flame" and int(tr.t) % T.every == 0:
				hit(state, atk, t, floor(T.dmg * power(atk, false)), "LEGS", 0, frm, tr.cast)
				add_heat(t, T.heat)
			elif tr.kind == "frost" and not warded(t):
				t.buffs.slow = max(t.buffs.slow, 2)
		tr.t -= 1
		if tr.t > 0:
			keep.append(tr)
	state.trails = keep


static func bump(state, m, a, h) -> void:
	var target = null
	for t in foes(state, m.id):
		if not airborne(t) and hypot(t.x - m.x, t.y - m.y) <= 2 * rad(t) + 0.25:
			target = t
			break
	if target == null:
		return
	a.hit = true
	hit(state, m, target, floor(h.dmg * power(m, true)), "ARMS", h.impact, atan2(m.y - target.y, m.x - target.x), next_cast(state))
	push(target, a.dx, a.dy, h.push)
	if not h.get("through", false):
		a.t = 1


static func land(state, m, L) -> void:
	state.fx.append({"k": "land", "id": m.id, "x": m.x, "y": m.y, "r": L.r, "t": 20})
	for t in foes(state, m.id):
		if airborne(t) or hypot(t.x - m.x, t.y - m.y) > L.r + rad(t):
			continue
		hit(state, m, t, floor(L.dmg * power(m, true)), "LEGS", L.get("impact", 0), atan2(m.y - t.y, m.x - t.x), next_cast(state))
		if not L.has("stun") or warded(t):
			continue
		interrupt(t)
		t.stagger = max(t.stagger, L.stun)
		if L.get("lift", false):
			t.lift = L.stun
			t.liftT = L.stun


static func aim_from(m, x: float, y: float) -> float:
	return atan2(m.ty - y, m.tx - x) if hypot(m.tx - x, m.ty - y) > 1.5 else m.aim


static func fire(state, m, hand: String, follow: bool) -> void:
	var g = weapon(m, hand)
	var p = g.fan if follow else g
	var cast := next_cast(state)
	var jam = JAM.dmg if jammed(m, ARM_OF[hand]) else 1
	var hot := hot_of(m)
	var dmg = floor(p.dmg * (core(m).get("hotDmg", HEAT.hotDmg) if hot else 1) * jam * power(m, false) * (FOCUS.dmg if m.buffs.focus > 0 else 1))
	var impact = g.impact + (1 if hot else 0)
	var fx := cos(m.aim)
	var fy := sin(m.aim)
	var side := MUZZLE if hand == "right" else -MUZZLE
	var mx: float = m.x + fx * MECH_R - fy * side
	var my: float = m.y + fy * MECH_R + fx * side
	var dir := aim_from(m, mx, my)
	var n: int = p.get("pellets", 1)
	var spread: float = p.get("spread", 0)
	if g.kind == "lob":
		var d := minf(g.range, hypot(m.tx - m.x, m.ty - m.y))
		var a := atan2(m.ty - m.y, m.tx - m.x)
		for i in n:
			var off := (i - (n - 1) / 2.0) * spread
			var c := clamp_arena(m.x + cos(a) * d - sin(a) * off, m.y + sin(a) * d + cos(a) * off, state.shrink, geo(state).walls)
			state.lobs.append({"kind": "shell", "owner": m.id, "sx": mx, "sy": my, "x": c.x, "y": c.y, "t": g.delay, "T": g.delay, "r": g.splash, "dmg": dmg, "impact": impact, "cast": cast})
	elif g.kind == "ray":
		for i in n:
			line_attack(state, m, mx, my, dir + (i - (n - 1) / 2.0) * spread, g.range, g.halfWidth, dmg, impact, "ARMS", cast, "laser", {"perfectCut": 0})
	elif g.kind == "cone":
		cone_attack(state, m, dir, g, dmg, impact, cast)
	else:
		var spec = g
		var speed_k: float = core(m).get("boltSpeed", 1) * (FOCUS.speed if m.buffs.focus > 0 else 1)
		if speed_k != 1:
			spec = g.duplicate()
			spec.speed = g.speed * speed_k
		for i in n:
			var off: float = (i - (n - 1) / 2.0) * spread + ((rng(state) - 0.5) * 2 * g.jitter if g.jitter else 0.0)
			spawn_shot(state, m, cast, mx, my, dir + off, spec, dmg, impact, g.shot, {"homing": g.get("homing", 0), "bounces": g.get("bounces", 0)})
	state.fx.append({"k": "muzzle", "id": m.id, "hand": hand, "gun": m.loadout[hand], "x": mx, "y": my, "a": dir, "t": 8})
	add_heat(m, g.load)
	push(m, -fx, -fy, g.recoil)


static func throw_hook(state, m) -> void:
	var fx := cos(m.aim)
	var fy := sin(m.aim)
	var x: float = m.x + fx * MECH_R
	var y: float = m.y + fy * MECH_R
	var spec := HOOK.duplicate()
	spec.range = HOOK.range * core(m).get("hookRange", 1)
	spawn_shot(state, m, next_cast(state), x, y, aim_from(m, x, y), spec, HOOK.dmg, 0, "hook")
	state.fx.append({"k": "hookOut", "id": m.id, "x": x, "y": y, "t": 6})
	add_heat(m, HOOK.load)


static func spawn_shot(state, m, cast, x: float, y: float, angle: float, spec, dmg, impact, kind: String, extra := {}) -> void:
	state.shots.append({
		"kind": kind, "owner": m.id, "cast": cast, "x": x, "y": y, "vx": cos(angle) * spec.speed, "vy": sin(angle) * spec.speed,
		"r": spec.radius, "left": spec.range - MECH_R, "dmg": dmg, "impact": impact, "reflected": false,
		"homing": extra.get("homing", 0), "bounces": extra.get("bounces", 0),
	})


static func swing(state, m, hand: String, spin: bool) -> void:
	var b = weapon(m, hand)
	var cast := next_cast(state)
	var hot := hot_of(m)
	var jam = JAM.dmg if jammed(m, ARM_OF[hand]) else 1
	var arc: float = PI if spin else b.arc
	for t in foes(state, m.id):
		var dx: float = t.x - m.x
		var dy: float = t.y - m.y
		if airborne(t) or t.get("fly", false) or hypot(dx, dy) > b.range + rad(t) or not in_arc(m.aim, arc, dx, dy):
			continue
		var dmg = floor((b.spinDmg if spin else b.dmg) * (core(m).get("hotDmg", HEAT.hotDmg) if hot else 1) * jam * power(m, true))
		hit(state, m, t, dmg, "LEGS", b.impact + (1 if hot else 0), atan2(-dy, -dx), cast)
		if b.has("yank"):
			push(t, -dx / hypot(dx, dy), -dy / hypot(dx, dy), b.yank)
	state.fx.append({"k": "slash", "id": m.id, "hand": hand, "blade": m.loadout[hand], "x": m.x, "y": m.y, "a": m.aim, "arc": arc, "range": b.range, "t": 12})
	add_heat(m, b.load)
	push(m, cos(m.aim), sin(m.aim), b.lunge)


static func near_foes(state, m, x: float, y: float, r: float) -> Array:
	return foes(state, m.id).filter(func(t): return hypot(t.x - x, t.y - y) <= r)


static func ult_target(state, m, reach: float) -> Dictionary:
	var d := minf(reach, hypot(m.tx - m.x, m.ty - m.y))
	var ang := atan2(m.ty - m.y, m.tx - m.x)
	return clamp_arena(m.x + cos(ang) * d, m.y + sin(ang) * d, state.shrink, geo(state).walls)


static func fire_ult(state, m, a) -> void:
	var h = ult(m)
	var cast := next_cast(state)
	state.fx.append({"k": "ult", "id": m.id, "ult": h.kind, "x": m.x, "y": m.y, "t": 30})
	match h.kind:
		"lance":
			fire_lance(state, m, a.angle)
		"swarm":
			for i in h.count:
				var ang: float = m.aim + (float(i) / (h.count - 1) - 0.5) * h.spread
				spawn_shot(state, m, cast, m.x + cos(ang) * MECH_R, m.y + sin(ang) * MECH_R, ang, {"speed": h.speed, "radius": 0.3, "range": 40}, floor(h.dmg * power(m, false)), 1, "missile", {"homing": h.homing})
		"overdrive":
			m.buffs.overdrive = h.time
		"berserk":
			m.buffs.berserk = h.time
		"bubble":
			m.buffs.bubble = h.time
			m.buffs.bubbleHp = h.absorb
		"repair":
			for p in m.armor:
				m.armor[p] = minf(m.max[p], maxf(0, m.armor[p]) + h.amount)
			m.heat = 0.0
			state.fx.append({"k": "heal", "id": m.id, "x": m.x, "y": m.y, "n": h.amount, "t": 40})
		"emp":
			state.fx.append({"k": "emp", "id": m.id, "x": m.x, "y": m.y, "r": h.radius, "t": 24})
			for t in near_foes(state, m, m.x, m.y, h.radius + MECH_R):
				hit(state, m, t, floor(h.dmg * power(m, false)), "ARMS", 0, atan2(m.y - t.y, m.x - t.x), cast)
				if not warded(t):
					interrupt(t)
					t.buffs.jam = h.jam
		"orbital":
			var p := ult_target(state, m, h.range)
			state.lobs.append({"kind": "strike", "owner": m.id, "sx": m.x, "sy": m.y, "x": p.x, "y": p.y, "t": h.delay, "T": h.delay, "r": h.radius, "dmg": floor(h.dmg * power(m, false)), "impact": h.impact, "cast": cast})
		"stasis":
			var p := ult_target(state, m, h.range)
			state.fields.append({"kind": "stasis", "owner": m.id, "x": p.x, "y": p.y, "r": h.radius, "t": h.time, "T": h.time})
			for t in near_foes(state, m, p.x, p.y, h.radius):
				hit(state, m, t, floor(h.dmg * power(m, false)), "ARMS", 0, atan2(p.y - t.y, p.x - t.x), cast)
		"mines":
			for i in h.count:
				var ang: float = (float(i) / h.count) * TAU
				var c := clamp_arena(m.x + cos(ang) * h.ring, m.y + sin(ang) * h.ring, 1 + state.shrink, geo(state).walls)
				var dmg = floor(h.dmg * power(m, false))
				state.mines.append({"owner": m.id, "x": c.x, "y": c.y, "arm": h.arm, "life": h.life, "dmg": dmg, "cast": next_cast(state)})
		"blink":
			var p := ult_target(state, m, h.range)
			state.lobs.append({"kind": "decoy", "owner": m.id, "sx": m.x, "sy": m.y, "x": m.x, "y": m.y, "t": h.delay, "T": h.delay, "r": h.radius, "dmg": floor(h.dmg * power(m, false)), "impact": h.impact, "cast": cast})
			state.fx.append({"k": "blink", "id": m.id, "x": m.x, "y": m.y, "x2": p.x, "y2": p.y, "a": m.aim, "t": 20})
			m.x = p.x
			m.y = p.y
			m.vx = 0.0
			m.vy = 0.0
		"well":
			var p := ult_target(state, m, h.range)
			state.fields.append({"kind": "well", "owner": m.id, "x": p.x, "y": p.y, "r": h.radius, "t": h.time, "T": h.time})
			for t in near_foes(state, m, p.x, p.y, h.radius):
				hit(state, m, t, floor(h.dmg * power(m, false)), "ARMS", 0, atan2(p.y - t.y, p.x - t.x), cast)
		"wall":
			var fx := cos(m.aim)
			var fy := sin(m.aim)
			var cx: float = m.x + fx * h.dist
			var cy: float = m.y + fy * h.dist
			state.walls.append({"owner": m.id, "x1": cx - (fy * h.len) / 2.0, "y1": cy + (fx * h.len) / 2.0, "x2": cx + (fy * h.len) / 2.0, "y2": cy - (fx * h.len) / 2.0, "t": h.time, "T": h.time})
		"meltdown":
			state.fx.append({"k": "boom", "x": m.x, "y": m.y, "r": h.radius, "big": true, "t": 22})
			for t in near_foes(state, m, m.x, m.y, h.radius + MECH_R):
				hit(state, m, t, floor((h.base + h.perHeat * m.heat) * power(m, false)), "ARMS", h.impact, atan2(m.y - t.y, m.x - t.x), cast)
			m.heat = 0.0
			m.overheat = 0
			m.ventDelay = 0
		"deflect":
			m.buffs.deflect = h.time
		"mirror":
			m.buffs.mirror = h.time
		"rail":
			line_attack(state, m, m.x + cos(m.aim) * MECH_R, m.y + sin(m.aim) * MECH_R, m.aim, h.length, h.halfWidth, floor(h.dmg * power(m, false)), h.impact, "ARMS", cast, "rail", {"perfectCut": 0.5, "through": true})
		"shroud":
			state.trails.append({"kind": "smoke", "owner": m.id, "x1": m.x, "y1": m.y, "x2": m.x, "y2": m.y, "t": h.time, "T": h.time, "cast": 0, "hit": false, "w": h.radius})


static func cross_t(ax: float, ay: float, bx: float, by: float, w):
	var rx := bx - ax
	var ry := by - ay
	var sx: float = w.x2 - w.x1
	var sy: float = w.y2 - w.y1
	var den := rx * sy - ry * sx
	if absf(den) < 1e-9:
		return null
	var qx: float = w.x1 - ax
	var qy: float = w.y1 - ay
	var k := (qx * sy - qy * sx) / den
	var j := (qx * ry - qy * rx) / den
	return k if k >= 0 and k <= 1 and j >= 0 and j <= 1 else null


static func perfect_of(t) -> float:
	return SHIELD.perfect * core(t).get("perfect", 1)


static func reflect(state, s, t) -> void:
	s.owner = t.id
	s.vx = -s.vx
	s.vy = -s.vy
	s.left = 40
	s.homing = 0
	s.reflected = true
	s.cast = next_cast(state)
	s.dmg = floor(s.dmg * core(t).get("reflectDmg", 1))
	state.fx.append({"k": "parry", "x": s.x, "y": s.y, "t": 14})


static func enemy_missile(state, s, team) -> bool:
	return s.kind == "missile" and state.mechs[s.owner].team != team


static func shoot_down(state, s) -> bool:
	state.fx.append({"k": "boom", "x": s.x, "y": s.y, "r": 0.7, "big": false, "t": 22})
	return false


static func intercept(state) -> void:
	var any := false
	for m in state.shots:
		if m.kind != "missile" or m.has("_dead"):
			continue
		var mx: float = m.fx0
		var my: float = m.fy0
		var b = null
		for c in state.shots:
			if is_same(c, m) or c.kind == "hook" or c.has("_dead"):
				continue
			if enemy_missile(state, m, state.mechs[c.owner].team) and seg_dist(c.fx0 - mx, c.fy0 - my, c.x - m.x, c.y - m.y, 0, 0) < m.r + c.r:
				b = c
				break
		if b == null:
			continue
		m["_dead"] = true
		b["_dead"] = true
		any = true
		shoot_down(state, m)
	if any:
		state.shots = state.shots.filter(func(s): return not s.has("_dead"))


static func move_shots(state) -> void:
	for s in state.shots:
		s.fx0 = s.x
		s.fy0 = s.y
	var keep := []
	for s in state.shots:
		if move_shot(state, s):
			keep.append(s)
	state.shots = keep
	intercept(state)


static func move_shot(state, s) -> bool:
	var enemies := foes(state, s.owner)
	var prey = null
	for t in enemies:
		if prey == null or hypot(t.x - s.x, t.y - s.y) < hypot(prey.x - s.x, prey.y - s.y):
			prey = t
	if s.homing and prey != null:
		var sp := hypot(s.vx, s.vy)
		var a := turn_toward(atan2(s.vy, s.vx), atan2(prey.y - s.y, prey.x - s.x), s.homing * DT)
		s.vx = cos(a) * sp
		s.vy = sin(a) * sp
	for t in enemies:
		if not (t.buffs.deflect > 0 and hypot(t.x - s.x, t.y - s.y) < ULTS.deflect.radius):
			continue
		var sp := hypot(s.vx, s.vy)
		var a := turn_toward(atan2(s.vy, s.vx), atan2(s.y - t.y, s.x - t.x), ULTS.deflect.turn)
		s.vx = cos(a) * sp
		s.vy = sin(a) * sp
	var x0: float = s.x
	var y0: float = s.y
	s.x += s.vx * DT
	s.y += s.vy * DT
	s.left -= hypot(s.vx, s.vy) * DT
	for w in state.walls:
		if wall_blocks(state, s.owner, w) and cross_t(x0, y0, s.x, s.y, w) != null:
			state.fx.append({"k": "ping", "x": s.x, "y": s.y, "a": atan2(s.vy, s.vx), "t": 8})
			return false
	var best = null
	for t in enemies:
		if airborne(t) or seg_dist(x0, y0, s.x, s.y, t.x, t.y) >= rad(t) + s.r:
			continue
		if best == null or hypot(t.x - x0, t.y - y0) < hypot(best.x - x0, best.y - y0):
			best = t
	if best != null:
		return shot_hits(state, s, best)
	var g := geo(state)
	if g.has("boxes") and struck(state, g, s):
		return false
	var wall = null
	for w in g.walls:
		if s.x * w.nx + s.y * w.ny >= w.d - state.shrink:
			wall = w
			break
	var pillar = null
	var team = state.mechs[s.owner].team
	for p in g.pillars:
		if p.get("only", team) == team and state.mechs[s.owner].buffs.xray == 0 and seg_dist(x0, y0, s.x, s.y, p.x, p.y) < p.r + s.r:
			pillar = p
			break
	if wall != null or pillar != null:
		var c := clamp_arena(s.x, s.y, state.shrink, geo(state).walls)
		state.fx.append({"k": "ping", "x": c.x, "y": c.y, "a": atan2(s.vy, s.vx), "t": 8})
		if s.bounces <= 0:
			return false
		s.bounces -= 1
		if wall != null:
			var dot: float = s.vx * wall.nx + s.vy * wall.ny
			s.vx -= 2 * dot * wall.nx
			s.vy -= 2 * dot * wall.ny
		if pillar != null:
			var hd := hypot(s.x - pillar.x, s.y - pillar.y)
			if hd == 0:
				hd = 1
			var nx: float = (s.x - pillar.x) / hd
			var ny: float = (s.y - pillar.y) / hd
			var dot: float = s.vx * nx + s.vy * ny
			s.vx -= 2 * dot * nx
			s.vy -= 2 * dot * ny
			s.x = pillar.x + nx * (pillar.r + s.r + 0.05)
			s.y = pillar.y + ny * (pillar.r + s.r + 0.05)
		var c2 := clamp_arena(s.x, s.y, 0.01 + state.shrink, geo(state).walls)
		s.x = c2.x
		s.y = c2.y
		return true
	return s.left > 0


static func shot_hits(state, s, t) -> bool:
	var atk = state.mechs[s.owner]
	var frm := atan2(-s.vy, -s.vx)
	var mirror: bool = t.buffs.mirror > 0 and in_arc(t.aim, ULTS.mirror.arc, -s.vx, -s.vy)
	if mirror or (shield_up(t) and in_arc(t.act.angle, SHIELD.arc, -s.vx, -s.vy)):
		if s.kind == "hook" or s.kind == "flame":
			state.fx.append({"k": "ping", "x": s.x, "y": s.y, "a": atan2(s.vy, s.vx), "t": 8})
			return false
		if mirror or t.act.t < perfect_of(t):
			if not mirror:
				perfect_guard(t)
			reflect(state, s, t)
			return true
		var through = block(t, s.dmg)
		if through > 0:
			hit(state, atk, t, through, "ARMS", s.impact, frm, s.cast)
		return false
	hit(state, atk, t, s.dmg, "ARMS", s.impact, frm, s.cast)
	if s.kind == "hook" and not t.ko and not warded(t):
		interrupt(t)
		t.pull = {"by": atk.id, "t": HOOK.pull}
		t.stagger = max(t.stagger, HOOK.pull + HOOK.stun)
		state.fx.append({"k": "hooked", "id": t.id, "by": atk.id, "x": t.x, "y": t.y, "t": 12})
	return false


static func perfect_guard(t) -> void:
	t.act.perfect = true
	t.surge = minf(SURGE.max, t.surge + SURGE.perfect)


static func block(t, dmg):
	var cap = core(t).get("absorb", SHIELD.absorb)
	t.act.absorbed += dmg
	if t.act.absorbed <= cap:
		return 0
	var through = t.act.absorbed - cap
	guard_break(t)
	return through


static func guard_break(t) -> void:
	t.act = null
	t.cd.shield = jround(SHIELD.breakCd * core(t).get("shieldCd", 1))
	t.stagger = max(t.stagger, SHIELD.breakStagger)


static func line_attack(state, m, sx: float, sy: float, angle: float, length: float, half_width: float, dmg, impact, tag: String, cast, kind: String, guard: Dictionary) -> void:
	var dx := cos(angle)
	var dy := sin(angle)
	var ln := length
	if not guard.get("through", false) and m.buffs.xray == 0:
		for p in geo(state).pillars:
			if p.get("only", m.team) != m.team:
				continue
			var d = ray_circle(sx, sy, dx, dy, p)
			if d != null and d < ln:
				ln = d
		for w in state.walls:
			if not wall_blocks(state, m.id, w):
				continue
			var k = cross_t(sx, sy, sx + dx * ln, sy + dy * ln, w)
			if k != null:
				ln *= k
	for t in foes(state, m.id):
		var px: float = t.x - sx
		var py: float = t.y - sy
		var along := px * dx + py * dy
		if airborne(t) or along <= -rad(t) or along - rad(t) >= ln or absf(px * dy - py * dx) >= half_width + rad(t):
			continue
		var d = dmg
		if t.buffs.mirror > 0 and in_arc(t.aim, ULTS.mirror.arc, -dx, -dy):
			d = 0
		elif shield_up(t) and in_arc(t.act.angle, SHIELD.arc, -dx, -dy):
			if t.act.t < perfect_of(t):
				perfect_guard(t)
				d *= guard.perfectCut
			else:
				d = block(t, d)
				if guard.get("breaks", false) and shield_up(t):
					guard_break(t)
		if d > 0:
			hit(state, m, t, d, tag, impact, atan2(-dy, -dx), cast)
	var team = m.team
	state.shots = state.shots.filter(func(s): return not enemy_missile(state, s, team) or seg_dist(sx, sy, sx + dx * ln, sy + dy * ln, s.x, s.y) >= half_width + s.r or shoot_down(state, s))
	state.fx.append({"k": "zap" if kind == "laser" else "beam", "kind": kind, "id": m.id, "x1": sx, "y1": sy, "x2": sx + dx * ln, "y2": sy + dy * ln, "t": 10 if kind == "laser" else 18})


static func cone_attack(state, m, dir: float, g, dmg, impact, cast) -> void:
	var inside := []
	for t in foes(state, m.id):
		var dx: float = t.x - m.x
		var dy: float = t.y - m.y
		if airborne(t) or hypot(dx, dy) > g.range + rad(t) or not in_arc(dir, g.arc, dx, dy) or (m.buffs.xray == 0 and not clear_line(m.x, m.y, t.x, t.y, geo(state).pillars)):
			continue
		if state.walls.any(func(w): return wall_blocks(state, m.id, w) and cross_t(m.x, m.y, t.x, t.y, w) != null):
			continue
		if t.buffs.mirror > 0 and in_arc(t.aim, ULTS.mirror.arc, -dx, -dy):
			continue
		inside.append(t)
	for t in inside:
		var dx: float = t.x - m.x
		var dy: float = t.y - m.y
		var frm := atan2(-dy, -dx)
		if shield_up(t) and in_arc(t.act.angle, SHIELD.arc, -dx, -dy):
			var through = 0 if t.act.t < perfect_of(t) else block(t, dmg)
			if t.act != null and t.act.t < perfect_of(t):
				perfect_guard(t)
			if through > 0:
				hit(state, m, t, through, "ARMS", impact, frm, cast)
		else:
			hit(state, m, t, dmg, "ARMS", impact, frm, cast)
	var ends = inside if inside.size() else [{"x": m.x + cos(dir) * g.range, "y": m.y + sin(dir) * g.range}]
	for e in ends:
		state.fx.append({"k": "zap", "kind": "tesla", "id": m.id, "x1": m.x, "y1": m.y, "x2": e.x, "y2": e.y, "t": 10})


static func fire_lance(state, m, angle: float) -> void:
	var sx: float = m.x + cos(angle) * MECH_R
	var sy: float = m.y + sin(angle) * MECH_R
	line_attack(state, m, sx, sy, angle, LANCE.length, LANCE.halfWidth, (LANCE.base + LANCE.perHeat * m.heat) * power(m, false), LANCE.impact, "HEAD", next_cast(state), "lance", {"perfectCut": LANCE.perfectCut, "breaks": true})
	m.heat = 0.0
	m.ventDelay = 0
	push(m, -cos(angle), -sin(angle), LANCE.recoil)


static func ray_circle(sx: float, sy: float, dx: float, dy: float, p):
	var fx: float = sx - p.x
	var fy: float = sy - p.y
	var b := fx * dx + fy * dy
	var disc: float = b * b - (fx * fx + fy * fy - p.r * p.r)
	if disc < 0:
		return null
	var d := -b - sqrt(disc)
	return d if d >= 0 else null


static func hit(state, atk, t, raw, tag: String, impact, frm: float, cast) -> void:
	var rel := angle_diff(frm, t.aim)
	var dmg = jround(raw * (HIT.rear if absf(rel) >= HIT.rearArc else 1))
	dmg = soak(state, t, braced(t, dmg))
	if dmg <= 0:
		return
	var front := absf(rel) <= HIT.split or absf(rel) >= PI - HIT.split
	var side: String
	if front:
		side = "larm" if t.armor.larm < t.armor.rarm else "rarm"
	else:
		side = "larm" if rel < 0 else "rarm"
	hurt(state, t, "head" if tag == "HEAD" else ("legs" if tag == "LEGS" else side), dmg)
	var c = core(atk)
	if c.has("leech"):
		heal_weakest(atk, dmg * c.leech)
	var gain := surge_k(atk)
	if atk.lastHitCast != cast:
		atk.lastHitCast = cast
		atk.surge += SURGE.perHit * gain
	atk.surge = minf(SURGE.max, atk.surge + dmg * SURGE.dealt * gain)
	t.surge = minf(SURGE.max, t.surge + dmg * SURGE.taken * surge_k(t))
	var poise := poise_of(t)
	if impact >= poise:
		stagger(t, impact, poise, frm)
		state.hitstop = max(state.hitstop, MATCH.hitstop)
	state.fx.append({"k": "hit", "id": t.id, "x": t.x, "y": t.y, "n": dmg, "head": tag == "HEAD", "from": frm, "t": 10})


static func heal_weakest(m, n) -> void:
	var worst = null
	for p in m.armor:
		if worst == null or m.armor[p] / float(m.max[p]) < m.armor[worst] / float(m.max[worst]):
			worst = p
	m.armor[worst] = minf(m.max[worst], maxf(0, m.armor[worst]) + n)


static func pulse_tick(state, m) -> void:
	if m.buffs.pulse <= 0 or m.ko:
		return
	heal_weakest(m, PULSE.amount / float(PULSE.time))
	if m.buffs.pulse % 30 == 0:
		state.fx.append({"k": "heal", "id": m.id, "x": m.x, "y": m.y, "n": PULSE.amount / 6.0, "t": 40})


static func cast_e(state, m, skill: String, spec) -> void:
	var at := {"x": m.x, "y": m.y}
	match skill:
		"frost":
			at = ult_target(state, m, spec.range)
			state.fields.append({"kind": "stasis", "owner": m.id, "x": at.x, "y": at.y, "r": spec.r, "t": spec.time, "T": spec.time})
		"arcwall":
			at = ult_target(state, m, spec.range)
			var fx := cos(m.aim)
			var fy := sin(m.aim)
			state.walls.append({"owner": m.id, "zap": true, "zapped": [], "x1": at.x - (fy * spec.len) / 2.0, "y1": at.y + (fx * spec.len) / 2.0, "x2": at.x + (fy * spec.len) / 2.0, "y2": at.y - (fx * spec.len) / 2.0, "t": spec.time, "T": spec.time})
		"trap":
			at = clamp_arena(m.x + cos(m.aim) * spec.dist, m.y + sin(m.aim) * spec.dist, 1 + state.shrink, geo(state).walls)
			state.mines.append({"owner": m.id, "x": at.x, "y": at.y, "arm": spec.arm, "life": spec.life, "dmg": floor(spec.dmg * power(m, false)), "cast": next_cast(state), "root": spec.root})
		_:
			m.buffs[skill] = spec.time
	state.fx.append({"k": skill, "id": m.id, "x": at.x, "y": at.y, "t": 14})


static func lunge(state, m) -> void:
	var dx: float = m.tx - m.x
	var dy: float = m.ty - m.y
	var ln := hypot(dx, dy)
	if ln == 0:
		dx = cos(m.aim)
		dy = sin(m.aim)
		ln = 1.0
	var ux := dx / ln
	var uy := dy / ln
	var end := clamp_arena(m.x + ux * LUNGE.dist, m.y + uy * LUNGE.dist, MECH_R + state.shrink, geo(state).walls)
	m.act = {"k": "dash", "ph": "go", "t": LUNGE.ticks, "T": LUNGE.ticks, "move": "lunge", "dx": ux, "dy": uy, "speed": (LUNGE.dist / float(LUNGE.ticks)) * TICKS, "lx": end.x, "ly": end.y, "hit": false, "trail": null}
	state.fx.append({"k": "dash", "id": m.id, "x": m.x, "y": m.y, "t": 6})


static func wall_blocks(state, owner: int, w) -> bool:
	return state.mechs[owner].buffs.xray == 0 and not (w.get("zap", false) and w.owner == owner)


static func zap_walls(state) -> void:
	for w in state.walls:
		if not w.get("zap", false):
			continue
		for t in foes(state, w.owner):
			if t.id in w.zapped or airborne(t) or seg_dist(w.x1, w.y1, w.x2, w.y2, t.x, t.y) >= rad(t) + 0.2:
				continue
			w.zapped.append(t.id)
			if warded(t):
				continue
			env_hit(state, t, ARCWALL.dmg, "legs", 0, atan2((w.y1 + w.y2) / 2.0 - t.y, (w.x1 + w.x2) / 2.0 - t.x))
			t.buffs.slow = max(t.buffs.slow, ARCWALL.slow)
			state.fx.append({"k": "zap", "kind": "tesla", "id": w.owner, "x1": w.x1, "y1": w.y1, "x2": t.x, "y2": t.y, "t": 10})


static func warded(t) -> bool:
	return t.buffs.cleanse > 0


static func braced(t, dmg):
	return jround(dmg * BRACE.cut) if t.buffs.brace > 0 else dmg


static func soak(state, t, dmg):
	if not (t.buffs.bubble > 0 and t.buffs.bubbleHp > 0):
		return dmg
	var n = min(dmg, t.buffs.bubbleHp)
	t.buffs.bubbleHp -= n
	state.fx.append({"k": "soak", "id": t.id, "x": t.x, "y": t.y, "t": 10})
	return dmg - n


static func env_hit(state, t, raw, part: String, impact, frm: float) -> void:
	var dmg = soak(state, t, braced(t, raw))
	if dmg <= 0:
		return
	hurt(state, t, ("larm" if angle_diff(frm, t.aim) < 0 else "rarm") if part == "arms" else part, dmg)
	t.surge = minf(SURGE.max, t.surge + dmg * SURGE.taken * surge_k(t))
	var poise := poise_of(t)
	if impact >= poise:
		stagger(t, impact, poise, frm)
	state.fx.append({"k": "hit", "id": t.id, "x": t.x, "y": t.y, "n": dmg, "head": false, "from": frm, "t": 10})


static func hurt(state, t, part: String, n) -> void:
	t.buffs.pulse = 0
	if part != "head" and t.armor[part] <= 0:
		part = "head"
	var was = t.armor[part]
	t.armor[part] -= n
	if part == "head" or t.armor[part] > 0:
		return
	t.armor.head += t.armor[part]
	t.armor[part] = 0
	if was <= 0:
		return
	state.fx.append({"k": "break", "id": t.id, "part": part, "x": t.x, "y": t.y, "t": 70})
	state.hitstop = max(state.hitstop, MATCH.breakStop)


static func interrupt(t) -> void:
	var a = t.act
	if a == null:
		return
	if (a.ph == "wind" or a.ph == "combo") and a.k != "ult":
		t.cd[a.k] = floor(skill_cd(t, a.k) / 2.0)
	if lancing(t):
		t.surge = minf(SURGE.max, t.surge + LANCE.stuffRefund)
	if shield_up(t):
		t.cd.shield = SHIELD.cd
	t.act = null


static func stagger(t, impact, poise, frm: float) -> void:
	t.stagger = max(t.stagger, STAGGER.perPoint * (impact - poise + 1))
	push(t, -cos(frm), -sin(frm), STAGGER.knockback * impact)
	interrupt(t)


static func move(state, m, inp) -> void:
	var a = m.act
	if m.pull != null:
		var c = state.mechs[m.pull.by]
		var dx: float = c.x - m.x
		var dy: float = c.y - m.y
		var d := hypot(dx, dy)
		if d == 0:
			d = 1
		var stop := d <= HOOK.stop
		if not stop:
			m.pull.t -= 1
			stop = m.pull.t <= 0
		if stop:
			m.pull = null
			m.vx *= 0.2
			m.vy *= 0.2
		else:
			m.vx = (dx / d) * HOOK.pullSpeed
			m.vy = (dy / d) * HOOK.pullSpeed
	elif not (a != null and a.k == "dash" and a.ph == "go"):
		var mx: float = inp.mx
		var my: float = inp.my
		var ln := hypot(mx, my)
		if ln > 1:
			mx /= ln
			my /= ln
		var legs = feet(m)
		var top: float = legs.top * speed_of(m.loadout) * (MOVE.jammed if jammed(m, "legs") else 1) * core(m).get("speed", 1) * (ULTS.berserk.speed if m.buffs.berserk > 0 else 1) * (MOVE.slow if m.buffs.slow > 0 else 1) * (ITEMS.speed.speed if m.buffs.speed > 0 else 1) * (BRACE.move if m.buffs.brace > 0 else 1) * (FOCUS.move if m.buffs.focus > 0 else 1)
		if m.stagger > 0 or m.buffs.root > 0 or lancing(m) or (a != null and a.k == "dash"):
			top = 0
		elif shield_up(m):
			top *= MOVE.shield
		elif a != null:
			top *= MOVE.cast
		if m.overheat > 0:
			top *= MOVE.overheat
		var dvx: float = mx * top - m.vx
		var dvy: float = my * top - m.vy
		var dv := hypot(dvx, dvy)
		var rate: float = (legs.top / legs.accel if top > 0 and ln > 0 else legs.top / (legs.accel * MOVE.brake)) * DT * (TRAPS.oil.grip if not state.has("geo") and on_oil(m) else 1)
		var k := 1.0 if dv <= rate else rate / dv
		m.vx += dvx * k
		m.vy += dvy * k
	m.x += m.vx * DT
	m.y += m.vy * DT


static func update_lobs(state) -> void:
	var keep := []
	for l in state.lobs:
		l.t -= 1
		if l.t > 0:
			keep.append(l)
			continue
		state.fx.append({"k": "boom", "x": l.x, "y": l.y, "r": l.r, "big": l.kind == "strike", "t": 22})
		for t in foes(state, l.owner):
			if hypot(t.x - l.x, t.y - l.y) <= l.r + rad(t):
				hit(state, state.mechs[l.owner], t, l.dmg, "LEGS", l.impact, atan2(l.sy - t.y, l.sx - t.x), l.cast)
	state.lobs = keep


static func update_mines(state) -> void:
	var h = ULTS.mines
	var keep := []
	for mi in state.mines:
		if mi.arm > 0:
			mi.arm -= 1
		mi.life -= 1
		if mi.life <= 0:
			continue
		var caught := []
		if mi.arm <= 0:
			for t in foes(state, mi.owner):
				if not airborne(t) and not t.get("fly", false) and hypot(t.x - mi.x, t.y - mi.y) <= h.trigger + rad(t):
					caught.append(t)
		if caught.is_empty():
			keep.append(mi)
			continue
		state.fx.append({"k": "boom", "x": mi.x, "y": mi.y, "r": 1.4, "big": false, "t": 22})
		for t in caught:
			hit(state, state.mechs[mi.owner], t, mi.dmg, "LEGS", 0 if mi.has("root") else h.impact, atan2(mi.y - t.y, mi.x - t.x), mi.cast)
			if mi.has("root") and not warded(t):
				t.buffs.root = max(t.buffs.root, mi.root)
	state.mines = keep


static func update_fields(state) -> void:
	var keep := []
	for f in state.fields:
		for t in foes(state, f.owner):
			var d := hypot(t.x - f.x, t.y - f.y)
			if airborne(t) or d > f.r:
				continue
			if f.kind != "well":
				if not warded(t):
					t.buffs.slow = max(t.buffs.slow, 2)
			elif d > 0.3:
				t.x += ((f.x - t.x) / d) * ULTS.well.pull * DT
				t.y += ((f.y - t.y) / d) * ULTS.well.pull * DT
		f.t -= 1
		if f.t > 0:
			keep.append(f)
	state.fields = keep


static func collide(m, shrink: float, g: Dictionary = DUEL_GEO) -> void:
	for p in g.solids:
		var dx: float = m.x - p.x
		var dy: float = m.y - p.y
		var d := hypot(dx, dy)
		var lim: float = p.r + rad(m)
		if d >= lim or d == 0:
			continue
		var nx := dx / d
		var ny := dy / d
		m.x = p.x + nx * lim
		m.y = p.y + ny * lim
		var vn: float = m.vx * nx + m.vy * ny
		if vn < 0:
			m.vx -= vn * nx
			m.vy -= vn * ny
	for b in g.get("boxes", []):
		if b.get("only", m.team) != m.team or b.get("hp", 1) <= 0:
			continue
		var cx := clampf(m.x, b.x0, b.x1)
		var cy := clampf(m.y, b.y0, b.y1)
		var bx: float = m.x - cx
		var by: float = m.y - cy
		var bd := hypot(bx, by)
		if bd >= rad(m):
			continue
		if bd == 0:
			var out := [m.x - b.x0, b.x1 - m.x, m.y - b.y0, b.y1 - m.y]
			var k: int = out.find(out.min())
			bx = [-1.0, 1.0, 0.0, 0.0][k]
			by = [0.0, 0.0, -1.0, 1.0][k]
			cx = [b.x0, b.x1, m.x, m.x][k]
			cy = [m.y, m.y, b.y0, b.y1][k]
			bd = 1.0
		m.x = cx + bx / bd * rad(m)
		m.y = cy + by / bd * rad(m)
		var vb: float = (m.vx * bx + m.vy * by) / bd
		if vb < 0:
			m.vx -= vb * bx / bd
			m.vy -= vb * by / bd
	for r in g.get("rings", []):
		var d := hypot(m.x, m.y)
		if d > 0 and d > r.r0 - rad(m) and d < r.r1 + rad(m) and not in_gap(r, m.x, m.y, 0.0):
			var to: float = r.r0 - rad(m) if d < (r.r0 + r.r1) / 2.0 else r.r1 + rad(m)
			m.x *= to / d
			m.y *= to / d
	for w in g.walls:
		var o: float = m.x * w.nx + m.y * w.ny + rad(m) - (w.d - shrink)
		if o <= 0:
			continue
		m.x -= w.nx * o
		m.y -= w.ny * o
		var vn: float = m.vx * w.nx + m.vy * w.ny
		if vn > 0:
			m.vx -= vn * w.nx
			m.vy -= vn * w.ny


static func separate(a, b) -> void:
	var dx: float = b.x - a.x
	var dy: float = b.y - a.y
	var d := hypot(dx, dy)
	if d >= (rad(a) + rad(b)) or d == 0:
		return
	var k := ((rad(a) + rad(b)) - d) / 2.0 / d
	a.x -= dx * k
	a.y -= dy * k
	b.x += dx * k
	b.y += dy * k


static func repair(m, n) -> void:
	for p in m.armor:
		m.armor[p] = minf(m.max[p], maxf(0, m.armor[p]) + n)


static func first_near(order: Array, x: float, y: float, r: float):
	for m in order:
		if not m.ko and hypot(m.x - x, m.y - y) <= r + MECH_R:
			return m
	return null


static func pickups(state) -> void:
	var order := turns(state)
	var h = state.heal
	if not h.ready:
		h.timer -= 1
		if h.timer <= 0:
			h.ready = true
			state.fx.append({"k": "healUp", "t": 30})
	var healer = first_near(order, HEAL.x, HEAL.y, HEAL.radius) if h.ready else null
	if healer != null:
		repair(healer, HEAL.amount)
		h.ready = false
		h.timer = HEAL.respawn
		state.fx.append({"k": "heal", "id": healer.id, "x": healer.x, "y": healer.y, "n": HEAL.amount, "t": 40})
	var w = state.wave
	w.t -= 1
	if w.t <= 0:
		for i in state.pads.size():
			if state.pads[i] == null:
				state.pads[i] = w.next[i >> 1]
		w.next = roll_wave(state)
		w.t = PICKUP.every
		state.fx.append({"k": "padsUp", "t": 30})
	for i in state.pads.size():
		var kind = state.pads[i]
		if kind == null:
			continue
		var m = first_near(order, PADS[i].x, PADS[i].y, PICKUP.radius)
		if m == null:
			continue
		grab(m, kind)
		state.pads[i] = null
		state.fx.append({"k": "pickup", "id": m.id, "item": kind, "x": PADS[i].x, "y": PADS[i].y, "n": ITEMS.repair.amount, "t": 40})


static func grab(m, kind: String) -> void:
	var it = ITEMS[kind]
	var b = m.buffs
	if kind == "repair":
		repair(m, it.amount)
	elif kind == "shield":
		b.bubble = max(b.bubble, it.time)
		b.bubbleHp = max(b.bubbleHp, it.absorb)
	elif kind == "coolant":
		m.heat = 0.0
		m.overheat = 0
		m.ventDelay = 0
		b.cool = it.time
	elif kind == "surge":
		m.surge = minf(SURGE.max, m.surge + it.amount)
	else:
		b[kind] = it.time


static func traps(state) -> void:
	var e := elapsed(state)
	var live = state.mechs.filter(func(m): return not m.ko)
	if e == HAZARDS.vents:
		state.fx.append({"k": "ventsOn", "t": 90})
	if e == HAZARDS.close:
		state.fx.append({"k": "closing", "t": 90})
	var C = TRAPS.crush
	for i in C.at.size():
		var p = C.at[i]
		var u := until_slam(state, i)
		if u == C.warn:
			state.fx.append({"k": "crushWarn", "x": p.x, "y": p.y, "t": 20})
		if e == 0 or u != C.every:
			continue
		state.fx.append({"k": "crush", "x": p.x, "y": p.y, "t": 30})
		for m in live:
			if absf(m.x - p.x) < C.half + MECH_R / 2 and absf(m.y - p.y) < C.half + MECH_R / 2:
				env_hit(state, m, C.dmg, "legs", C.impact, atan2(p.y - m.y, p.x - m.x))
	var Z = TRAPS.tesla
	for i in Z.at.size():
		var p = Z.at[i]
		var u := until_zap(state, i)
		if u == Z.warn:
			state.fx.append({"k": "pylonWarn", "x": p.x, "y": p.y, "t": 20})
		if e == 0 or u != Z.every:
			continue
		state.fx.append({"k": "pylon", "x": p.x, "y": p.y, "t": 20})
		for m in live:
			if hypot(m.x - p.x, m.y - p.y) > Z.reach + MECH_R:
				continue
			state.fx.append({"k": "zap", "kind": "tesla", "x1": p.x, "y1": p.y, "x2": m.x, "y2": m.y, "t": 10})
			env_hit(state, m, Z.dmg, "arms", Z.impact, atan2(p.y - m.y, p.x - m.x))
	var v = vent_phase(state)
	if v != null and v.p == HAZARDS.warn:
		state.fx.append({"k": "vent", "set": v["set"], "t": 20})
	if v != null and v.burn and (v.p - HAZARDS.warn) % HAZARDS.every == 0:
		for g in vents(state.shrink):
			if g.wall % 2 != v["set"]:
				continue
			for m in live:
				var rx: float = m.x - g.x
				var ry: float = m.y - g.y
				var along: float = rx * g.dx + ry * g.dy
				if along < -MECH_R or along > HAZARDS.reach + MECH_R or absf(rx * g.dy - ry * g.dx) > HAZARDS.half + MECH_R:
					continue
				env_hit(state, m, HAZARDS.dmg, "legs", 0, atan2(-g.dy, -g.dx))
				m.buffs.slow = maxi(m.buffs.slow, HAZARDS.slow)
	if state.shrink <= 0 or int(state.tick) % HAZARDS.wallEvery != 0:
		return
	for m in live:
		for w in WALLS:
			if m.x * w.nx + m.y * w.ny + MECH_R >= w.d - state.shrink - 0.05:
				env_hit(state, m, HAZARDS.wallDmg, "legs", 0, atan2(w.ny, w.nx))
				break


static func check_ko(state) -> void:
	var down = state.mechs.filter(func(m): return not m.ko and m.armor.head <= 0)
	if down.is_empty():
		return
	for m in down:
		m.ko = true
		state.fx.append({"k": "ko", "id": m.id, "x": m.x, "y": m.y, "t": MATCH.ko})
	state.hitstop = MATCH.koStop
	var left := uniq(state.mechs.filter(func(m): return not m.ko).map(func(m): return m.team))
	if left.size() < 2:
		state.finalKo = down[0].id
		end_round(state, left[0] if left.size() else -1)
		return
	for m in down:
		m.act = null
		m.vx = 0.0
		m.vy = 0.0
		m.pull = null


static func total_armor(m) -> float:
	var s := 0.0
	for v in m.armor.values():
		s += maxf(0, v)
	return s


static func rank_cmp(a, b) -> float:
	var ra: float = a.armor.head / float(a.max.head)
	var rb: float = b.armor.head / float(b.max.head)
	var d := ra - rb
	return d if d != 0 else total_armor(a) - total_armor(b)


static func time_up(state) -> void:
	var live = state.mechs.filter(func(m): return not m.ko)
	var best = live[0]
	for m in live:
		if rank_cmp(m, best) > 0:
			best = m
	var tie := false
	for m in live:
		if m.team != best.team and rank_cmp(m, best) == 0:
			tie = true
	state.fx.append({"k": "time", "t": MATCH.ko})
	end_round(state, -1 if tie else best.team)


static func end_round(state, winner: int) -> void:
	state.winner = winner
	if winner >= 0:
		state.score[winner] += 1
	state.phase = "ko"
	state.timer = MATCH.ko


static func reset_round(state) -> void:
	var spawns := spawns_of(state.mechs.map(func(m): return m.team))
	var mechs := []
	for old in state.mechs:
		var m := make_mech(old.id, old.loadout, old.team, spawns[old.id])
		m.surge = max(floor(old.surge * SURGE.carry), core(m).get("surgeStart", 0))
		m.held = old.held
		mechs.append(m)
	state.mechs = mechs
	state.shots = []
	state.lobs = []
	state.mines = []
	state.fields = []
	state.trails = []
	state.walls = []
	state.heal = {"ready": false, "timer": HEAL.first}
	reset_pads(state)
	state.shrink = 0.0
	state.winner = -1
	state.finalKo = -1
	state.round += 1
	state.phase = "countdown"
	state.timer = MATCH.countdown
	state.clock = MATCH.time
