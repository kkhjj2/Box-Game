class_name OpponentAI
extends Node
## Opponent behaviour as a small timed state machine.
## GUARD (waits) -> WINDUP (telegraph) -> PUNCH (travel) -> connect.
## The fight decides whether the punch was blocked:
##   blocked -> OPEN  (guard down; player hits count as counters)
##   landed  -> RECOVER -> GUARD
## A hook landed during WINDUP interrupts it -> STAGGER (also open).

signal windup_started(kind: String, side: int, duration: float)
signal punch_thrown(kind: String, side: int, travel: float)
signal punch_connect(kind: String, side: int)
signal state_changed(state: int)

enum S { IDLE, GUARD, WINDUP, PUNCH, RECOVER, OPEN, STAGGER, DOWN }
enum Vuln { GUARDED, NORMAL, OPEN }

const PUNCH_TRAVEL := 0.09
const RECOVER_TIME := 0.45
const STAGGER_TIME := 0.7
const HOOK_CHANCE := 0.4
const HOOK_TELEGRAPH_MULT := 1.3

var state := S.IDLE
var health_ratio := 1.0  # set by the fight; lower health -> slightly more aggressive

var _timer := 0.0
var _kind := "jab"
var _side := 0


func start() -> void:
	_enter_guard()


func stop() -> void:
	_set_state(S.IDLE)


func knocked_down() -> void:
	_set_state(S.DOWN)


func vulnerability() -> Vuln:
	match state:
		S.GUARD, S.IDLE:
			return Vuln.GUARDED
		S.OPEN, S.STAGGER:
			return Vuln.OPEN
	return Vuln.NORMAL


## Called by the fight when one of the player's punches lands. Returns true if it interrupted.
func on_hit(heavy: bool) -> bool:
	if state == S.WINDUP and heavy:
		_set_state(S.STAGGER)
		_timer = STAGGER_TIME
		return true
	return false


## Called by the fight right after punch_connect.
func punch_result(blocked: bool) -> void:
	if blocked:
		_set_state(S.OPEN)
		_timer = Tuning.v("open_time")


func _process(delta: float) -> void:
	if state == S.IDLE or state == S.DOWN:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	match state:
		S.GUARD:
			_begin_windup()
		S.WINDUP:
			_set_state(S.PUNCH)
			_timer = PUNCH_TRAVEL
			punch_thrown.emit(_kind, _side, PUNCH_TRAVEL)
		S.PUNCH:
			# Default to RECOVER; punch_result(true) switches to OPEN.
			_set_state(S.RECOVER)
			_timer = RECOVER_TIME
			punch_connect.emit(_kind, _side)
		S.RECOVER, S.OPEN, S.STAGGER:
			_enter_guard()


func _enter_guard() -> void:
	_set_state(S.GUARD)
	var lo: float = Tuning.v("gap_min")
	var hi: float = maxf(lo, Tuning.v("gap_max"))
	_timer = randf_range(lo, hi) * lerpf(0.7, 1.0, health_ratio)


func _begin_windup() -> void:
	if randf() < HOOK_CHANCE:
		_kind = "hook"
		_side = randi() % 2
	else:
		_kind = "jab"
		_side = 0
	var dur: float = Tuning.v("telegraph") * lerpf(0.85, 1.0, health_ratio)
	if _kind == "hook":
		dur *= HOOK_TELEGRAPH_MULT
	_set_state(S.WINDUP)
	_timer = dur
	windup_started.emit(_kind, _side, dur)


func _set_state(s: S) -> void:
	state = s
	state_changed.emit(s)
