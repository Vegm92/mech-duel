# Netcode design

Status: core built and tested headless (`godot/tests/net_test.gd`). Not wired into the menus or `main.gd` yet.
Code: `godot/src/net/`. Victor's goal (2026-10-31): the duel ships on Steam, up to 4 seats, each seat local, online or a bot.

## Model: delay-based lockstep (not rollback)

1. `Sim.step` is pure and deterministic, so every machine can run the same sim on the same inputs. Only inputs travel, never state.
2. A tick runs only when every seat's input for it has arrived. No guessing, no corrections, no visible rewinds.
3. Rollback needs snapshots of the state. `state.duplicate(true)` is **not** safe mid-fight: a dash trail is shared by `state.trails` and `m.act.trail`, and a deep copy splits them. In a probe of 135 snapshots taken with a live trail, 75 ran differently afterwards. Lockstep needs no snapshots.
4. Input delay hides the network: 6 ticks (100 ms) by default. The cost is that every action starts 100 ms late, for everyone alike. Aim is a free cursor and the camera is calm, so that is playable. Not tried by hand yet.
5. If a game ever feels too laggy, rollback can be added later on top of the same session (frames, hashes, bots stay), once the sim gets a snapshot function that keeps the trail link.

## Numbers

- Tick rate: 60 (`Sim.TICKS`). One session `pump()` per physics frame.
- Input delay: `delay` = 6 ticks. The link must carry host to client to host in about that time. A client-to-client path is two hops through the host, so two legs of ~50 ms fit. Tunable per match (`cfg.delay`); an adaptive delay is future work.
- Bandwidth (estimate, 4 seats): a client sends ~6 KB/s and gets ~20 KB/s. The host sends ~60 KB/s with 3 clients.

## Who talks to whom

Star: the host is relay and sequencer, clients talk only to the host. The host is also a player. Peer id 1 is always the host.

- **Seat input.** One tick of one seat is 9 bytes (`net_input.gd`): button bits, move x/y, aim x/y. Move is snapped to 1/1000, aim to 1/64 m. Everyone, the sender too, runs the sim on the unpacked values, so there is no float drift on the wire.
- **Client to host** (`IN`, unreliable, every pump): all inputs the host has not acked yet, plus an ack of the frames the client has. Resending until acked is how packet loss is handled, with no waiting for a retransmit timer.
- **Host to clients** (`FR`, unreliable, every pump): all frames the client has not acked yet. A frame is one tick: a bot mask plus every seat's input.
- **Reliable messages** (rare): `HELLO`, `WELCOME`, `REFUSE`, `START`, `HASH`, `DESYNC`.
- A client samples its input for tick `t` right after it ran tick `t - delay`. That keeps every peer within `delay` ticks of the others. If a frame is missing, the sim waits (it simply does not step).
- Match start (`START`): teams, loadouts of all seats, seed, delay, which seats are bots. Everyone builds the same `Sim.create_state`.
- One seat per remote machine. More local seats (couch play) live on the host machine.

## Desync detection

Every `hash_every` ticks (30) each peer hashes its state with `Sim.hash_state` and sends it to the host. The host compares the hashes of one tick. A mismatch makes a `desync` event on the host, and the host tells every client. The game decides what to do (show it, end the match). The hash drops the view's `seen` and `_n` tags first (`NetSession.state_hash`), because the view writes them into the live state. The hash catches a drift of 1e-14 in a position.

## Disconnect: the seat becomes a bot

- The host drops a client when the transport says it left, when the host has waited for its input for `silence` polls (180, about 3 s), or when it falls `lag` frames behind.
- The host sets the seat in the bot mask from the next frame it makes. The mask travels inside the frames, so every peer switches on the **same tick**.
- From then on every peer plays that seat with `Bot.bot_input`, using a brain seeded by `NetSession.brain_seed(seed, seat)`. Bots are a pure function of the state, so they agree too.
- Events: `left` (host, with why), `bot` (everyone, with tick). A bot seat from the start of the match works the same way.
- A client that hears nothing from the host for `silence` polls ends the session (`ended`, `host_silent` / `host_lost`). No host migration: if the host leaves, the match is over.
- Polls count frames, not seconds, so tests have no wall-clock. The game must call `pump()` or `poll()` every frame, also while a menu is open.

## Swapping the transport (Steam)

The session only knows `net_transport.gd`: `id`, `poll`, `send(peer, bytes, reliable)`, `recv`, `events` (`up` / `down`), `kick`, `close`. `net_enet.gd` and the test `net_fake.gd` are two implementations of it. For GodotSteam (Steam Networking Sockets or Steam P2P), write `net_steam.gd` with the same seven functions: map Steam IDs to int peer ids, make the lobby owner peer 1, use the reliable and unreliable send flags. The session, the protocol and the tests do not change. `net_test.gd` can run the same scenarios on the new class. Needs Victor's Steam app ID; out of scope now.

## How the game will use it (later step)

```gdscript
var net := NetSession.new(NetEnet.new() (served or joined), is_host, cfg, my_loadout)
# lobby: net.poll(), net.take_events(), host calls net.begin()
# match, every physics frame:
var steps := net.pump(func(seat, tick): return my_input_for(seat))
# net.state is the Sim state to draw; fx events come from it as today.
```

`pump` returns how many ticks ran (0 to 3). The view should draw `net.state`, not step it itself. Local input is read by the caller and handed over in the sampler, so the session does not care how local input works.

## Determinism check of `Sim.step` (what would break two machines)

Looked at on 2026-10-31. Nothing here is fixed, `sim.gd` is untouched.

1. **Needed: `sin`, `cos`, `atan2` differ between platforms.** 83 call sites use Godot's built-ins, which call the platform's math library. Results can differ in the last bit between Windows, Linux, macOS and ARM. One last-bit difference grows into a different match within seconds. `sqrt`, `floor`, `fmod`, `+ - * /` are exact IEEE and safe. Two copies of the same build on the same OS and CPU family agree, so same-platform play works today (the golden hash already depends on the platform for this reason). For cross-play (Windows with Steam Deck) the sim needs its own trig. Exact change in `sim.gd`: add `dsin`, `dcos`, `datan2` below and replace every `sin(`, `cos(`, `atan2(` inside `sim.gd`, `bot.gd` (the bot runs in the lockstep too) and `siege.gd` if it ever runs online. Then `GOLDEN` changes once. Measured error against the built-ins is under 1e-12 for sin/cos and 6e-11 for atan2, which is invisible in play.
2. **Needed: the view must not touch the state that gets hashed or snapshotted.** `view.gd` writes `seen` (fx) and `_n` (nodes) into the live state. Harmless to the sim, but a plain `hash_state` of the live state differs per machine. Use `NetSession.state_hash`. This is also why a raw `duplicate(true)` of the live state is not a snapshot.
3. **Good to know: dash trails are shared (`state.trails` and `m.act.trail`).** `duplicate(true)` breaks the link, so a copied state plays on differently in 75 of 135 probes. Needed only if rollback is ever wanted: a `Sim.snapshot(state)` that rebuilds the link, or make `act.trail` an index.
4. **OK: randomness.** There is no `randf`, `randi` or time in `sim.gd`. `Sim.rng(state)` keeps its seed in `state.seed`, so it is part of the state and part of the hash. The bot brain keeps its own seed, set in `NetSession.brain_seed`.
5. **OK: dictionary order.** GDScript dictionaries keep insertion order and the sim inserts keys in the same order on every peer. `hash_state` sorts keys, so it does not depend on it. It would only matter if a state were rebuilt from JSON or another source in a different order.
6. **OK: input types.** The sim reads `inp.mx` and friends as numbers. Local raw inputs (ints like `IDLE`) and unpacked wire inputs (floats) hash differently, so every peer, including the sender, feeds `NetInput.unpack` values. `NetInput.snap` does this for local reference runs.
7. **OK: float printing in the hash.** `JSON.stringify` keeps 15+ digits. Probe: a 1e-14 change flips the hash.

```gdscript
static func dsin(x: float) -> float:
	var k := roundf(x * 0.6366197723675814)
	var r := (x - k * 1.5707963267948966) - k * 6.123233995736766e-17
	var q := int(k) & 3
	var r2 := r * r
	if q == 0 or q == 2:
		var s := r * (1.0 + r2 * (-1.0 / 6 + r2 * (1.0 / 120 + r2 * (-1.0 / 5040 + r2 * (1.0 / 362880 + r2 * (-1.0 / 39916800 + r2 * (1.0 / 6227020800.0)))))))
		return s if q == 0 else -s
	var c := 1.0 + r2 * (-0.5 + r2 * (1.0 / 24 + r2 * (-1.0 / 720 + r2 * (1.0 / 40320 + r2 * (-1.0 / 3628800 + r2 * (1.0 / 479001600.0))))))
	return c if q == 1 else -c


static func dcos(x: float) -> float:
	return dsin(x + 1.5707963267948966)


static func datan(x: float) -> float:
	var ax := absf(x)
	var inv := ax > 1.0
	var z := 1.0 / ax if inv else ax
	var shrunk := z > 0.4142135623730951
	if shrunk:
		z = (z - 1.0) / (z + 1.0)
	var z2 := z * z
	var p := z * (1.0 + z2 * (-1.0 / 3 + z2 * (1.0 / 5 + z2 * (-1.0 / 7 + z2 * (1.0 / 9 + z2 * (-1.0 / 11 + z2 * (1.0 / 13 + z2 * (-1.0 / 15 + z2 * (1.0 / 17 + z2 * (-1.0 / 19 + z2 * (1.0 / 21)))))))))))
	if shrunk:
		p += 0.7853981633974483
	if inv:
		p = 1.5707963267948966 - p
	return p if x >= 0.0 else -p


static func datan2(y: float, x: float) -> float:
	if x == 0.0 and y == 0.0:
		return 0.0
	if absf(y) > absf(x):
		return 1.5707963267948966 - datan(x / y) if y > 0.0 else -1.5707963267948966 - datan(x / y)
	var b := datan(y / x)
	if x > 0.0:
		return b
	return b + PI if y >= 0.0 else b - PI
```

Only `+ - * /`, `roundf`, `absf` and `int` are used, so they give the same bits everywhere. One thing to check on each shipped build: that the compiler does not fuse multiply-add differently per platform (not verified).

## What is tested (`godot/tests/net_test.gd`)

2 and 4 peers (1v1, FFA, 2v2 with 2 bots) play 1000 to 1500 ticks over the fake network and end on the same `Sim.hash_state` as one local `Sim.step` run with the same inputs. Same with 2 ticks of delay, 2 of jitter and 10% loss. A leaving client and a silent client turn into a bot on the same tick for everyone, and the rest still match a local run that uses the bot from that tick. A lost host ends the clients. A forced state change on one client is caught at the next hash tick. One ENet smoke test runs host and client on 127.0.0.1 in one process.

## Not done (on purpose)

- Menus, lobby UI, joining by address, Steam lobbies (needs the app ID).
- Host migration, spectators, reconnecting a dropped player into their seat.
- Adaptive input delay, a ping display, "waiting for player" UI (`pump()` returning 0 for a while is the signal).
- Cheat protection: the host trusts the clients' inputs and a client trusts the host's frames.
- Core Siege online.
