extends Node3D
## One playable fight. Builds the ring, both fighters, camera rail and HUD, then runs
## the player's action timing, damage resolution and the feel layer
## (hit-stop, shake, flash, haptics, sound).

const PLAYER_POS := Vector3(0, 0, 1.25)
const MAX_HP := 100.0
const JAB_STARTUP := 0.07
const JAB_RECOVER := 0.16
const HOOK_STARTUP := 0.16
const HOOK_RECOVER := 0.28
const PLAYER_STUN := 0.35
const OPP_PUNCH_BACK := 0.25
const HOOK_DMG_MULT := 1.4  # opponent hooks hurt more than jabs
const HITSTOP_SCALE := 0.02

enum P { LOCKED, READY, STARTUP, RECOVER, GUARD, STUNNED }

var player: Fighter
var opponent: Fighter
var ai: OpponentAI
var rig: CameraRig
var hud: Hud
var sfx: Sfx
var swipe: SwipeInput

var player_hp := MAX_HP
var opp_hp := MAX_HP
var time_left := 45.0
var fight_on := false

var _p_state := P.LOCKED
var _p_timer := 0.0
var _p_kind := ""
var _p_side := 0
var _buf_kind := ""
var _buf_side := 0
var _buf_timer := 0.0

var _hitstop_until := 0  # msec, real time
var _base_time_scale := 1.0
var _exchanges := 0


func _ready() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	_build_ring()

	player = Fighter.new()
	player.name = "Player"
	player.setup(Color(0.87, 0.66, 0.52), Color(0.75, 0.12, 0.1), Color(0.85, 0.1, 0.08))
	player.position = PLAYER_POS
	add_child(player)

	opponent = Fighter.new()
	opponent.name = "Opponent"
	opponent.setup(Color(0.55, 0.38, 0.28), Color(0.95, 0.95, 0.95), Color(0.15, 0.3, 0.9))
	opponent.rotation.y = PI
	add_child(opponent)

	ai = OpponentAI.new()
	add_child(ai)
	ai.windup_started.connect(_on_windup)
	ai.punch_thrown.connect(_on_opp_punch_thrown)
	ai.punch_connect.connect(_on_opp_punch_connect)
	ai.state_changed.connect(_on_ai_state)

	rig = CameraRig.new()
	add_child(rig)
	rig.track(player, opponent)

	sfx = Sfx.new()
	add_child(sfx)

	swipe = SwipeInput.new()
	add_child(swipe)
	swipe.swiped.connect(_on_swipe)

	hud = Hud.new()
	add_child(hud)
	hud.restart_requested.connect(_restart)

	time_left = Tuning.v("round_time")
	hud.set_time(time_left)
	_intro()


func _intro() -> void:
	await get_tree().process_frame  # let the HUD lay out before animating labels
	hud.announce("ROUND 1", 0.7)
	await get_tree().create_timer(1.1, false).timeout
	hud.announce("FIGHT!", 0.5)
	sfx.play("bell", 0.0)
	fight_on = true
	_p_state = P.READY
	ai.start()


func _process(delta: float) -> void:
	_update_hitstop()
	if not fight_on:
		return
	time_left -= delta
	hud.set_time(time_left)
	if time_left <= 0.0:
		_finish(false, "TIME!", "Time ran out.\nHe's still standing.")
		return
	_update_player(delta)


# --- player ------------------------------------------------------------------

func _on_swipe(kind: String, side: int) -> void:
	if not fight_on:
		return
	match _p_state:
		P.READY:
			_start_action(kind, side)
		P.GUARD:
			if kind == "block":
				_p_timer = Tuning.v("guard_time")  # keep holding
			else:
				_start_action(kind, side)  # punch straight out of guard
		P.RECOVER:
			if kind == "block":
				_start_action(kind, side)  # defence cancels punch recovery
			else:
				_buffer(kind, side)
		_:
			_buffer(kind, side)


func _buffer(kind: String, side: int) -> void:
	_buf_kind = kind
	_buf_side = side
	_buf_timer = Tuning.v("buffer_time")


func _start_action(kind: String, side: int) -> void:
	_p_kind = kind
	_p_side = side
	if kind == "block":
		_p_state = P.GUARD
		_p_timer = Tuning.v("guard_time")
		player.set_stance("block")
		return
	if _p_state == P.GUARD:
		player.set_stance("guard")
	var speed: float = Tuning.v("punch_speed")
	var startup := (HOOK_STARTUP if kind == "hook" else JAB_STARTUP) / speed
	var recover := (HOOK_RECOVER if kind == "hook" else JAB_RECOVER) / speed
	_p_state = P.STARTUP
	_p_timer = startup
	player.punch(side, kind, opponent.head_global(), startup, recover)
	sfx.play("whoosh")


func _update_player(delta: float) -> void:
	if _buf_timer > 0.0:
		_buf_timer -= delta
		if _buf_timer <= 0.0:
			_buf_kind = ""
	match _p_state:
		P.STARTUP:
			_p_timer -= delta
			if _p_timer <= 0.0:
				_resolve_player_hit()
				if _p_state == P.STARTUP:
					_p_state = P.RECOVER
					var speed: float = Tuning.v("punch_speed")
					_p_timer = (HOOK_RECOVER if _p_kind == "hook" else JAB_RECOVER) / speed
		P.RECOVER, P.STUNNED:
			_p_timer -= delta
			if _p_timer <= 0.0:
				_p_state = P.READY
		P.GUARD:
			_p_timer -= delta
			if _p_timer <= 0.0:
				player.set_stance("guard")
				_p_state = P.READY
	if _p_state == P.READY and _buf_kind != "":
		var k := _buf_kind
		_buf_kind = ""
		_start_action(k, _buf_side)


func _resolve_player_hit() -> void:
	var heavy := _p_kind == "hook"
	var dmg: float = Tuning.v("hook_dmg") if heavy else Tuning.v("jab_dmg")
	var vuln := ai.vulnerability()
	if vuln == OpponentAI.Vuln.GUARDED:
		opponent.block_bump()
		sfx.play("block")
		rig.shake(0.12)
		hit_stop(Tuning.v("hit_stop_ms") * 0.25)
		_damage_opponent(dmg * Tuning.v("guarded_mult"))
		return

	var counter := vuln == OpponentAI.Vuln.OPEN
	if counter:
		dmg *= Tuning.v("open_mult")
	var big := heavy or counter
	opponent.hit_react(player.punch_push(_p_side, _p_kind), big)
	opponent.flash()
	sfx.play("hit_heavy" if big else "hit")
	rig.shake(0.3 + (0.3 if heavy else 0.0) + (0.2 if counter else 0.0))
	if big:
		rig.punch_zoom()
	hit_stop(Tuning.v("hit_stop_heavy_ms") if big else Tuning.v("hit_stop_ms"))
	_vibrate(1.5 if big else 1.0)
	if ai.on_hit(heavy):
		hud.popup("STAGGER!")
	elif counter:
		hud.popup("COUNTER!")
	_damage_opponent(dmg)


func _damage_opponent(dmg: float) -> void:
	opp_hp = maxf(opp_hp - dmg, 0.0)
	ai.health_ratio = opp_hp / MAX_HP
	hud.set_health(player_hp / MAX_HP, opp_hp / MAX_HP)
	if opp_hp <= 0.0:
		_knockout_opponent()


# --- opponent ----------------------------------------------------------------

func _on_windup(kind: String, side: int, duration: float) -> void:
	opponent.windup(side, kind, duration)
	sfx.play("tell", 0.0)


func _on_opp_punch_thrown(kind: String, side: int, travel: float) -> void:
	var target := player.guard_center_global() if _p_state == P.GUARD else player.head_global()
	opponent.punch(side, kind, target, travel, OPP_PUNCH_BACK)


func _on_opp_punch_connect(kind: String, side: int) -> void:
	if not fight_on:
		return
	var heavy := kind == "hook"
	if _p_state == P.GUARD:
		ai.punch_result(true)
		player.block_bump()
		sfx.play("block")
		rig.shake(0.2)
		hit_stop(40.0)
		_vibrate(0.5)
		hud.popup("OPEN!")
	else:
		ai.punch_result(false)
		player.hit_react(opponent.punch_push(side, kind), heavy)
		player.flash()
		player.set_stance("guard")
		sfx.play("hit_heavy")
		rig.shake(0.7 if heavy else 0.5)
		hit_stop(Tuning.v("hit_stop_heavy_ms"))
		hud.damage_flash()
		_vibrate(2.0)
		_p_state = P.STUNNED
		_p_timer = PLAYER_STUN
		_buf_kind = ""
		player_hp = maxf(player_hp - Tuning.v("opp_dmg") * (HOOK_DMG_MULT if heavy else 1.0), 0.0)
		hud.set_health(player_hp / MAX_HP, opp_hp / MAX_HP)
		if player_hp <= 0.0:
			player.knockout()
			_finish(false, "DOWN!", "You got knocked down.")
			return
	_exchanges += 1
	if _exchanges % int(Tuning.v("rail_every")) == 0:
		rig.advance()


func _on_ai_state(state: int) -> void:
	match state:
		OpponentAI.S.OPEN, OpponentAI.S.STAGGER:
			opponent.set_stance("open")
		OpponentAI.S.GUARD:
			opponent.set_stance("guard")


# --- end of fight ------------------------------------------------------------

func _knockout_opponent() -> void:
	fight_on = false
	_p_state = P.LOCKED
	ai.knocked_down()
	opponent.knockout()
	rig.ko_shot()
	rig.shake(1.0)
	hud.announce("K.O.!", 1.4)
	sfx.play("bell", 0.0)
	_base_time_scale = 0.3  # slow-motion finish
	if _hitstop_until == 0:
		Engine.time_scale = _base_time_scale
	await get_tree().create_timer(1.6, true, false, true).timeout
	_base_time_scale = 1.0
	Engine.time_scale = 1.0
	hud.show_end("You win by K.O.\n%d s left on the clock." % ceili(time_left))


func _finish(_won: bool, callout: String, text: String) -> void:
	fight_on = false
	_p_state = P.LOCKED
	ai.stop()
	hud.announce(callout, 1.0)
	sfx.play("bell", 0.0)
	await get_tree().create_timer(1.2, true, false, true).timeout
	hud.show_end(text)


func _restart() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().reload_current_scene()


# --- feel --------------------------------------------------------------------

## Freeze the action for `ms` of real time. Sound and camera shake keep running.
func hit_stop(ms: float) -> void:
	if ms <= 0.0:
		return
	_hitstop_until = maxi(_hitstop_until, Time.get_ticks_msec() + int(ms))
	Engine.time_scale = HITSTOP_SCALE


func _update_hitstop() -> void:
	if _hitstop_until > 0 and Time.get_ticks_msec() >= _hitstop_until:
		_hitstop_until = 0
		Engine.time_scale = _base_time_scale


func _vibrate(mult: float) -> void:
	var ms := int(Tuning.v("haptic_ms") * mult)
	if ms > 0 and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


# --- ring --------------------------------------------------------------------

func _build_ring() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.03, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.4, 0.4, 0.5)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var key := SpotLight3D.new()
	key.position = Vector3(0, 5, 0.6)
	key.rotation_degrees = Vector3(-90, 0, 0)
	key.spot_angle = 40.0
	key.spot_range = 9.0
	key.light_energy = 6.0
	key.shadow_enabled = true
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-35, 30, 0)
	fill.light_energy = 0.5
	add_child(fill)

	var centre := Vector3(0, 0, 0.6)
	var half := 2.6
	_box(Vector3(half * 2.2, 0.3, half * 2.2), centre + Vector3(0, -0.15, 0), Color(0.78, 0.75, 0.68))
	_box(Vector3(half * 3.0, 0.2, half * 3.0), centre + Vector3(0, -0.45, 0), Color(0.12, 0.12, 0.15))
	var corners := [Vector3(-half, 0, -half), Vector3(half, 0, -half), Vector3(half, 0, half), Vector3(-half, 0, half)]
	var post_cols := [Color(0.2, 0.35, 0.9), Color(0.9, 0.9, 0.9), Color(0.85, 0.15, 0.1), Color(0.9, 0.9, 0.9)]
	for i in 4:
		var c: Vector3 = corners[i]
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.07
		cyl.bottom_radius = 0.07
		cyl.height = 1.6
		_add_mesh(cyl, centre + c + Vector3(0, 0.8, 0), post_cols[i])
		var nxt: Vector3 = corners[(i + 1) % 4]
		for h: float in [0.55, 0.95, 1.35]:
			var a := centre + c + Vector3(0, h, 0)
			var b := centre + nxt + Vector3(0, h, 0)
			var along_x := absf(b.x - a.x) > 0.01
			var size := Vector3(half * 2.0, 0.04, 0.04) if along_x else Vector3(0.04, 0.04, half * 2.0)
			_box(size, (a + b) * 0.5, Color(0.85, 0.1, 0.1))


func _box(size: Vector3, pos: Vector3, colour: Color) -> void:
	var b := BoxMesh.new()
	b.size = size
	_add_mesh(b, pos, colour)


func _add_mesh(m: Mesh, pos: Vector3, colour: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.8
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
