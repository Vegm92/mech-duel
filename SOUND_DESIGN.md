# Mech Duel — Sound

Goal (Victor, 2026-10-27): a full sound system for weapons, effects and the game itself, modular,
modern, in the same spirit as `FX_DESIGN.md`. Applies to the Godot view. The sim is untouched:
every sound is driven by the `state.fx` events the view already reads, plus mech state (speed,
heat, head armor) for loops and alarms.

## The rule: punch, not mush

The sound twin of "punch, not glow".

1. **Three beats per hit.** Click (0–30 ms, bright transient) → body (thud or crunch, the
   weight) → tail (short ring, debris). Tails stay short; one small room reverb, low wet.
2. **Weight scales the sound.** Your own events play at full level, a rival's at
   `MIX.foe` (`MIX.crowd_foe` with 3+ mechs). Same level for both sides was Victor's pick in JS.
3. **Each weapon family sounds different.** Energy = laser zaps, kinetic = metal impacts, fire =
   thruster roar, melee = whooshes and scrapes. One recipe per weapon in `Sfx.MUZZLE` /
   `Sfx.SLASH`; a new weapon = one row.
4. **Tells first.** Warnings (hazard beeps, overheat, low head) are short, distinct synth beeps
   that never share a sound with an attack.
5. **Slow-mo slows the sound.** `AudioServer.playback_speed_scale` follows `Engine.time_scale`
   (0.3× time → `MIX.slow` pitch), so the K.O. slow-mo sounds slow too.
6. **Music keeps its level.** No duck on the Music bus: game sounds never turn the radio down
   (Victor 2026-10-31, he disliked the pumping). Set it with `RADIO.db` and the music slider.

## Parts (Godot's own tools first)

| Part | What |
|---|---|
| Buses | Master (compressor + hard limiter) ← SFX, Env, Crowd, Music. Built in code by `Sfx.buses()`; SFX and Env carry a small reverb. |
| `src/sfx.gd` | Recipes keyed by fx event `k` (`RECIPES`), per weapon (`MUZZLE`, `SLASH`), menu sounds (`UI`). |
| Variety | One `AudioStreamRandomizer` per sample bank (no-repeat pick); per-recipe pitch jitter `vary`. |
| Position | Pooled `AudioStreamPlayer3D` voices at the event spot, the camera is the listener: pan and distance for free. `MIX.reach` is the full-volume radius. Events without a spot use the flat pool. |
| Synth | Beeps, the hit tick, chimes and whooshes are baked once into `AudioStreamWAV` (`bake`) from the JS recipes. |
| Loops | Per mech: hover/tread hum (pitch and level follow speed), footsteps for walking legs. |
| Alarms | Overheat hiss + 3 beeps, "ready" click when it clears, low-head beep (you only). |
| Crowd | `src/crowd_sound.gd` (hype-driven), on the Crowd bus. |
| Music | The radio, `src/radio.gd` (Victor 2026-10-31; the old procedural JS loop is gone). Starts on a random station. N = next song (after the station's last song, the next station), Shift+N = next station; no off step (music slider to 0 turns it off). Each station is a list of songs (title, artist, files in `assets/music/`) played one at a time in shuffled order on the Music bus at `RADIO.db`. The 15 s Algate loop repeats per version (`[file, n]` entries) into one 28-part gapless song. A switch plays a hiss (`ui_tune`). |
| Now playing | Card in the bottom-left corner, beside the mech panel (`RADIO.margin`): station, title, artist, progress bar and time, hint "N next song · Shift+N next station". Pops up on each new song or N press and fades after `RADIO.show` (10) s with no new one. |
| Menus | Garage and pause menu: hover, tab, equip, set, select, FIGHT. |
| Settings | Pause menu sliders (master, music, effects, arena, crowd), M mute, N next song, Shift+N next station (not saved: the station is random each launch). Saved in `user://settings.cfg`. |

Samples: Kenney "Sci-fi Sounds" + "Impact Sounds" (CC0) and the crowd clips, same files as the JS
version (`assets/sounds/LICENSE.txt`). Radio music: 43 CC0 and CC BY tracks (about 3 hours, 4 stations: HOUSE FM, TECHNO 909,
ACID FM, DEEP CHILL); sources and every required credit line in `assets/music/LICENSE.txt` (the
credits screen / store page must carry them).

## Checks

- `tests/sound_test.gd`: every fx kind the sim emits has a recipe (or is listed in `SILENT`),
  every weapon has a muzzle or slash recipe, every bank loads, synth bakes are not silent,
  the buses exist, volumes round-trip through the settings file.
- Ears: `--sandbox=<weapon>` fires one weapon on a loop. Sound can't be screenshotted: Victor's
  ear is the evidence.

## Build order

1. Buses, settings, sample banks, voice pools.
2. Weapons (muzzle + slash), hits, booms, breaks.
3. Moves and skills: dash, land, hook, parry, charge, R skills, heal, pickups.
4. Arena: crush, pylons, vents, closing, pads.
5. Mech loops, footsteps, alarms.
6. Match flow (count, fight, time, K.O. slow-mo), music.
7. Menus and volume sliders.
