extends Node
## Live-tunable feel values (autoload "Tuning").
## Edited from the in-game TUNE panel and saved to user://tuning.cfg so a
## good setting survives restarts on the phone. Use Defaults in the panel to reset.

signal changed(key: String)

const SAVE_PATH := "user://tuning.cfg"

# key: [default, min, max, step, label]
const SPEC := {
	"hit_stop_ms": [80.0, 0.0, 200.0, 5.0, "Hit-stop light (ms)"],
	"hit_stop_heavy_ms": [130.0, 0.0, 300.0, 5.0, "Hit-stop heavy (ms)"],
	"shake": [1.0, 0.0, 3.0, 0.1, "Camera shake"],
	"haptic_ms": [35.0, 0.0, 100.0, 5.0, "Vibration (ms)"],
	"swipe_dist": [0.06, 0.02, 0.2, 0.01, "Swipe distance (screen %)"],
	"hook_swipe_mirror": [0.0, 0.0, 1.0, 1.0, "Swipe right = right hook (0/1)"],
	"buffer_time": [0.15, 0.0, 0.4, 0.01, "Input buffer (s)"],
	"punch_speed": [1.0, 0.5, 2.0, 0.05, "Player punch speed"],
	"guard_time": [0.5, 0.2, 1.2, 0.05, "Guard duration (s)"],
	"telegraph": [0.6, 0.2, 1.5, 0.05, "Opponent telegraph (s)"],
	"open_time": [1.0, 0.3, 2.5, 0.05, "Opening after block (s)"],
	"gap_min": [0.9, 0.3, 3.0, 0.1, "Opponent gap min (s)"],
	"gap_max": [1.8, 0.5, 4.0, 0.1, "Opponent gap max (s)"],
	"jab_dmg": [5.0, 1.0, 20.0, 1.0, "Jab damage"],
	"hook_dmg": [11.0, 1.0, 30.0, 1.0, "Hook damage"],
	"open_mult": [1.6, 1.0, 3.0, 0.1, "Counter multiplier"],
	"guarded_mult": [0.2, 0.0, 1.0, 0.05, "Damage into guard"],
	"opp_dmg": [12.0, 1.0, 40.0, 1.0, "Opponent damage"],
	"round_time": [45.0, 15.0, 90.0, 5.0, "Round length (s)"],
	"rail_every": [2.0, 1.0, 6.0, 1.0, "Camera moves every N exchanges"],
}

var _values := {}


func _ready() -> void:
	reset_defaults()
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		for key: String in SPEC:
			_values[key] = float(cfg.get_value("tuning", key, _values[key]))


func spec() -> Dictionary:
	return SPEC


func v(key: String) -> float:
	return _values[key]


func set_value(key: String, value: float) -> void:
	_values[key] = value
	changed.emit(key)


func reset_defaults() -> void:
	for key: String in SPEC:
		_values[key] = float(SPEC[key][0])
		changed.emit(key)


func save_values() -> void:
	var cfg := ConfigFile.new()
	for key: String in SPEC:
		cfg.set_value("tuning", key, _values[key])
	cfg.save(SAVE_PATH)
