# Box Game (prototype)

A swipe-driven mobile boxing prototype in **Godot 4.3+** (portrait, Mobile renderer).
One fight, about 45 seconds, over-the-shoulder camera on a rail. The only goal right now is
to find out whether hitting feels good on a real phone.

## Run it

1. Open this folder in Godot 4.3 or newer (Standard edition, not .NET).
2. Press F5 to play on desktop. The mouse acts as a finger.
3. For Android, add an export preset and **tick `Permissions > Vibrate`**, or haptics silently do nothing.
   Then use one-click deploy.

## Controls

| Swipe | Action |
|-------|--------|
| Up | Jab (fast, light) |
| Left / Right | Hook (slower, heavy). By default the glove travels the way you swipe, so swiping right throws the left hook. Flip it in TUNE. |
| Down | Block (raises your guard for about 0.5 s) |

A swipe fires as soon as your finger has moved far enough, not when you lift it.
Swipes made during recovery are buffered briefly.

## How the fight works

- **His guard is up** while he's waiting. Punches into it only chip (20% damage).
- **He telegraphs every punch:** the glove pulls back, grows and glows orange, and you hear a tick.
  Hooks take longer to wind up than jabs.
- **Block it** (swipe down): his guard drops (`OPEN!`) and your punches count as counters (1.6x).
- **Or hook him during the wind-up:** this interrupts him (`STAGGER!`) and opens him up too.
  If your hook doesn't land before his punch does, you take the hit.
- If he lands, you're stunned for a moment. Drain his bar before the clock runs out.

## Tuning on the device

Tap **TUNE** (top right) to pause the fight and open sliders for:
- hit-stop
- shake
- vibration
- swipe distance
- telegraph time
- guard and opening windows
- damage
- round length
- how often the camera moves

Values are saved on the device in `user://tuning.cfg`.
When something feels right, copy the numbers into the defaults in `scripts/tuning.gd`.

## Code map

| File | What it does |
|------|--------------|
| `scripts/fight.gd` | Main scene script. Builds everything, handles player action timing, damage, hit-stop and haptics. |
| `scripts/opponent_ai.gd` | Opponent state machine (guard → wind-up → punch → open/recover). |
| `scripts/fighter.gd` | Primitive-mesh boxer and all its procedural animation. |
| `scripts/camera_rig.gd` | Path3D rail, look-at framing, shake and FOV kick. Edit `STOPS` to re-frame the shot. |
| `scripts/swipe_input.gd` | Touch-drag to action classification. |
| `scripts/hud.gd`, `scripts/tuning_panel.gd` | UI. |
| `scripts/sfx.gd` | Placeholder sounds synthesised at startup (no audio files yet). |
| `scripts/tuning.gd` | Autoload holding every tunable value. |

All art is placeholder (capsules and spheres) on purpose.
