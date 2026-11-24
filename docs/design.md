# Prototype design: one fight

**Goal:** one playable fight that feels good to hit on a real phone. Career, monetization and
presentation are out of scope until this loop is fun.

**Decisions**
- Godot 4.x, portrait, Mobile renderer.
- 3D over-the-shoulder camera on a fixed rail. Chosen over first-person and 2D side view.

**Mechanics**
- Swipe up = jab, swipe left/right = hook, swipe down = block (about 0.5 s guard).
- The opponent waits with his guard up (punches chip only). He telegraphs each punch with a
  wind-up of about 0.6 s: the glove pulls back, grows and glows, with an audio tick.
- Blocking his punch opens him for about 1 s; hits in that window are counters with bonus damage.
- A hook that lands during his wind-up interrupts it.
- Round of about 45 s. Win by K.O.; lose on your own K.O. or time-out.
- Feel: hit-stop of 60-130 ms, camera shake, flash, FOV kick on heavy hits, vibration,
  and slow motion on the K.O.
- The camera glides to the next rail stop every N exchanges.

**On-device tuning panel** for every feel value, saved per device.

**Left open:** art, real audio, opponent variety, stamina and guard-break (all in the later list).
