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
6. **Music sits under everything.** The Music bus has a compressor side-chained to SFX: big hits
   push the music down by themselves.

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
| Music | Procedural loop from the JS version, baked into 3 stems (calm / drive / fight) in an `AudioStreamSynchronized`. Garage and pause = calm, countdown = + drive, fight = + drums. |
| Radio | `src/radio.gd` (Victor 2026-10-31): N steps Arena mix → ACID FM → TECHNO 7 → DEEP DUB → off. Each station is an `AudioStreamPlaylist` of files in `assets/music/` on the Music bus (so hits still duck it), at `RADIO.db`; a radio station fades the arena stems out (`sfx.quiet`). The 15 s Algate loop repeats per version (`[file, n]` entries) into a 28-part playlist with no crossfade. A switch plays a hiss (`ui_tune`) and shows the station name for 2.5 s. |
| Menus | Garage and pause menu: hover, tab, equip, set, select, FIGHT. |
| Settings | Pause menu sliders (master, music, effects, arena, crowd), M mute, N radio station (`station` + `music_on`). Saved in `user://settings.cfg`. |

Samples: Kenney "Sci-fi Sounds" + "Impact Sounds" (CC0) and the crowd clips, same files as the JS
version (`assets/sounds/LICENSE.txt`). Radio music: CC0 and CC BY tracks, sources and the two required
credit lines in `assets/music/LICENSE.txt` (the credits screen / store page must carry them).

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
