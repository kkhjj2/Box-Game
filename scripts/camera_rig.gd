class_name CameraRig
extends Node3D
## Over-the-shoulder camera on a fixed rail (Path3D).
## The camera rides the rail between a few "stops" behind the player and always
## looks at a point between the two heads, biased toward the opponent.
## Shake and FOV kicks run on real time so they keep moving during hit-stop.

# Rail stops in world space. The player stands at z = 1.25, the opponent at z = 0.
# Edit these to re-frame the fight.
const STOPS := [
	Vector3(0.62, 1.85, 2.75),  # right shoulder
	Vector3(0.95, 1.55, 2.3),  # low, wide right
	Vector3(0.2, 2.25, 3.05),  # high, centred
	Vector3(-0.62, 1.9, 2.75),  # left shoulder
	Vector3(-0.95, 1.6, 2.3),  # low, wide left
]
const FOV := 55.0  # horizontal, because the screen is portrait
const MOVE_TIME := 0.9

var cam: Camera3D

var _path: Path3D
var _follow: PathFollow3D
var _offsets: Array[float] = []
var _stop := 0
var _dir := 1
var _player: Fighter
var _opponent: Fighter
var _focus_bias := 0.68
var _trauma := 0.0
var _fov_kick := 0.0
var _t := 0.0
var _last_us := 0
var _noise := FastNoiseLite.new()
var _move_tw: Tween


func track(player: Fighter, opponent: Fighter) -> void:
	_player = player
	_opponent = opponent


func _ready() -> void:
	var curve := Curve3D.new()
	var n := STOPS.size()
	for i in n:
		var p: Vector3 = STOPS[i]
		var tangent := Vector3.ZERO
		if i > 0 and i < n - 1:
			var nxt: Vector3 = STOPS[i + 1]
			var prv: Vector3 = STOPS[i - 1]
			tangent = (nxt - prv) * 0.25
		curve.add_point(p, -tangent, tangent)
	_path = Path3D.new()
	_path.curve = curve
	add_child(_path)
	_follow = PathFollow3D.new()
	_follow.rotation_mode = PathFollow3D.ROTATION_NONE
	_follow.loop = false
	_path.add_child(_follow)
	for i in n:
		_offsets.append(curve.get_closest_offset(STOPS[i]))
	_follow.progress = _offsets[0]

	cam = Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.fov = FOV
	add_child(cam)
	cam.make_current()

	_noise.frequency = 1.0
	_last_us = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	if _player == null:
		return
	var now := Time.get_ticks_usec()
	var rd := minf((now - _last_us) / 1_000_000.0, 0.1)
	_last_us = now
	_t += rd
	_trauma = maxf(_trauma - rd * 1.6, 0.0)
	_fov_kick = move_toward(_fov_kick, 0.0, rd * 30.0)

	var focus := _player.head_global().lerp(_opponent.head_global(), _focus_bias)
	var sway := Vector3(sin(_t * 0.7) * 0.03, sin(_t * 1.1) * 0.02, 0.0)
	var s: float = Tuning.v("shake") * _trauma * _trauma
	var nt := _t * 25.0
	var jitter := Vector3(_noise.get_noise_2d(nt, 0.0), _noise.get_noise_2d(0.0, nt), 0.0) * 0.12 * s
	cam.global_position = _follow.global_position + sway + jitter
	cam.look_at(focus, Vector3.UP)
	cam.rotate_object_local(Vector3.BACK, _noise.get_noise_2d(nt, 100.0) * 0.08 * s)
	cam.fov = FOV - _fov_kick


func shake(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)


func punch_zoom(amount := 5.0) -> void:
	_fov_kick = maxf(_fov_kick, amount)


## Glide to the next rail stop (ping-pongs along the rail).
func advance() -> void:
	var nxt := _stop + _dir
	if nxt < 0 or nxt >= _offsets.size():
		_dir = -_dir
		nxt = _stop + _dir
	_go_to(nxt, MOVE_TIME)


func ko_shot() -> void:
	_focus_bias = 0.85
	_go_to(1, 1.5)


func _go_to(index: int, t: float) -> void:
	_stop = index
	if _move_tw and _move_tw.is_valid():
		_move_tw.kill()
	_move_tw = create_tween()
	_move_tw.tween_property(_follow, "progress", _offsets[index], t) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
