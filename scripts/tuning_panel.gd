class_name TuningPanel
extends PanelContainer
## On-device tuning: one slider per value in the Tuning autoload.
## Opening it pauses the fight; closing it saves the values.

signal restart_requested

const FONT := 26

var _labels := {}
var _sliders := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 20
	offset_right = -20
	offset_top = 90
	offset_bottom = -40
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.08, 0.94)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(16)
	add_theme_stylebox_override("panel", sb)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	add_child(col)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	col.add_child(buttons)
	_button(buttons, "Defaults", _on_defaults)
	_button(buttons, "Restart", _on_restart)
	_button(buttons, "Close", close)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	var spec: Dictionary = Tuning.spec()
	for key: String in spec:
		var s: Array = spec[key]
		var label := Label.new()
		label.add_theme_font_size_override("font_size", FONT)
		list.add_child(label)
		var slider := HSlider.new()
		slider.min_value = s[1]
		slider.max_value = s[2]
		slider.step = s[3]
		slider.custom_minimum_size = Vector2(0, 52)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.value_changed.connect(_on_slider.bind(key))
		list.add_child(slider)
		_labels[key] = label
		_sliders[key] = slider
	_sync()


func open() -> void:
	_sync()
	visible = true
	get_tree().paused = true


func close() -> void:
	visible = false
	get_tree().paused = false
	Tuning.save_values()


func _on_slider(value: float, key: String) -> void:
	Tuning.set_value(key, value)
	_update_label(key)


func _on_defaults() -> void:
	Tuning.reset_defaults()
	_sync()


func _on_restart() -> void:
	Tuning.save_values()
	visible = false
	restart_requested.emit()


func _sync() -> void:
	for key: String in _sliders:
		var slider: HSlider = _sliders[key]
		slider.set_value_no_signal(Tuning.v(key))
		_update_label(key)


func _update_label(key: String) -> void:
	var s: Array = Tuning.spec()[key]
	var label: Label = _labels[key]
	label.text = "%s:  %s" % [s[4], str(snappedf(Tuning.v(key), s[3]))]


func _button(parent: Control, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 64)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", FONT)
	b.pressed.connect(cb)
	parent.add_child(b)
