class_name Hud
extends CanvasLayer
## Health bars, round clock, callouts, damage flash, end screen and the TUNE button.
## Everything except buttons ignores the mouse so touches fall through to SwipeInput.

signal restart_requested

const RED := Color(0.9, 0.22, 0.18)
const BLUE := Color(0.2, 0.45, 0.95)

var _p_bar: ProgressBar
var _p_trail: ProgressBar
var _o_bar: ProgressBar
var _o_trail: ProgressBar
var _time: Label
var _announce: Label
var _popup: Label
var _vignette: ColorRect
var _end: VBoxContainer
var _end_label: Label
var _tune: TuningPanel
var _announce_tw: Tween
var _popup_tw: Tween
var _vignette_tw: Tween


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.color = Color(0.85, 0.0, 0.0, 0.0)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_vignette)

	# Top bar: YOU [bar]  time  [bar] RIVAL
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 20
	top.offset_right = -20
	top.offset_top = 40
	top.add_theme_constant_override("separation", 14)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	var p := _bar_block("YOU", RED, false)
	_p_bar = p[1]
	_p_trail = p[2]
	top.add_child(p[0])
	_time = _label(44)
	_time.custom_minimum_size = Vector2(80, 0)
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_time)
	var o := _bar_block("RIVAL", BLUE, true)
	_o_bar = o[1]
	_o_trail = o[2]
	top.add_child(o[0])

	var tune := Button.new()
	tune.text = "TUNE"
	tune.add_theme_font_size_override("font_size", 24)
	tune.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tune.offset_left = -130
	tune.offset_right = -20
	tune.offset_top = 120
	tune.offset_bottom = 176
	root.add_child(tune)

	_announce = _label(96)
	_centre_band(_announce, 0.3, 140)
	root.add_child(_announce)
	_popup = _label(52)
	_popup.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_centre_band(_popup, 0.42, 80)
	root.add_child(_popup)

	var hint := _label(26)
	hint.text = "SWIPE   UP jab  ·  SIDE hook  ·  DOWN block"
	hint.modulate.a = 0.75
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -90
	hint.offset_bottom = -40
	root.add_child(hint)

	_end = VBoxContainer.new()
	_end.set_anchors_preset(Control.PRESET_CENTER)
	_end.offset_left = -260
	_end.offset_right = 260
	_end.offset_top = -40
	_end.offset_bottom = 200
	_end.add_theme_constant_override("separation", 24)
	_end.visible = false
	root.add_child(_end)
	_end_label = _label(40)
	_end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_end.add_child(_end_label)
	var again := Button.new()
	again.text = "Fight again"
	again.custom_minimum_size = Vector2(0, 90)
	again.add_theme_font_size_override("font_size", 36)
	again.pressed.connect(func() -> void: restart_requested.emit())
	_end.add_child(again)

	_tune = TuningPanel.new()
	root.add_child(_tune)
	_tune.restart_requested.connect(func() -> void: restart_requested.emit())
	tune.pressed.connect(_tune.open)


func set_health(player: float, opponent: float) -> void:
	_set_bar(_p_bar, _p_trail, player)
	_set_bar(_o_bar, _o_trail, opponent)


func set_time(t: float) -> void:
	_time.text = str(maxi(ceili(t), 0))


func announce(text: String, hold := 0.8) -> void:
	_announce.text = text
	_announce.pivot_offset = _announce.size * 0.5
	_announce.scale = Vector2.ONE * 1.6
	_announce.modulate.a = 1.0
	if _announce_tw and _announce_tw.is_valid():
		_announce_tw.kill()
	_announce_tw = create_tween().set_ignore_time_scale(true)
	_announce_tw.tween_property(_announce, "scale", Vector2.ONE, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_announce_tw.tween_interval(hold)
	_announce_tw.tween_property(_announce, "modulate:a", 0.0, 0.25)


func popup(text: String) -> void:
	_popup.text = text
	_popup.pivot_offset = _popup.size * 0.5
	_popup.scale = Vector2.ONE * 1.4
	_popup.modulate.a = 1.0
	_popup.position.y = _popup_base_y()
	if _popup_tw and _popup_tw.is_valid():
		_popup_tw.kill()
	_popup_tw = create_tween().set_ignore_time_scale(true)
	_popup_tw.tween_property(_popup, "scale", Vector2.ONE, 0.12).set_ease(Tween.EASE_OUT)
	_popup_tw.tween_interval(0.35)
	_popup_tw.set_parallel(true)
	_popup_tw.tween_property(_popup, "position:y", _popup_base_y() - 40.0, 0.3)
	_popup_tw.tween_property(_popup, "modulate:a", 0.0, 0.3)


func damage_flash() -> void:
	if _vignette_tw and _vignette_tw.is_valid():
		_vignette_tw.kill()
	_vignette.color.a = 0.38
	_vignette_tw = create_tween().set_ignore_time_scale(true)
	_vignette_tw.tween_property(_vignette, "color:a", 0.0, 0.35)


func show_end(text: String) -> void:
	_end_label.text = text
	_end.visible = true


# --- builders ----------------------------------------------------------------

func _bar_block(title: String, colour: Color, rtl: bool) -> Array:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label := _label(26)
	name_label.text = title
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if rtl else HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(name_label)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, 30)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(holder)
	var trail := _progress(Color(1, 1, 1, 0.85), rtl, true)
	var bar := _progress(colour, rtl, false)
	holder.add_child(trail)
	holder.add_child(bar)
	return [box, bar, trail]


func _progress(colour: Color, rtl: bool, with_bg: bool) -> ProgressBar:
	var b := ProgressBar.new()
	b.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.show_percentage = false
	b.min_value = 0.0
	b.max_value = 1.0
	b.step = 0.001
	b.value = 1.0
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if rtl:
		b.fill_mode = ProgressBar.FILL_END_TO_BEGIN
	var fill := StyleBoxFlat.new()
	fill.bg_color = colour
	fill.set_corner_radius_all(5)
	b.add_theme_stylebox_override("fill", fill)
	if with_bg:
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0, 0, 0, 0.55)
		bg.set_corner_radius_all(5)
		b.add_theme_stylebox_override("background", bg)
	else:
		b.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	return b


func _set_bar(bar: ProgressBar, trail: ProgressBar, value: float) -> void:
	bar.value = value
	var tw := create_tween()
	tw.tween_interval(0.25)
	tw.tween_property(trail, "value", value, 0.3)


func _label(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("outline_size", 10)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _centre_band(l: Label, anchor_y: float, height: float) -> void:
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.anchor_top = anchor_y
	l.anchor_bottom = anchor_y
	l.offset_top = -height * 0.5
	l.offset_bottom = height * 0.5
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.modulate.a = 0.0


func _popup_base_y() -> float:
	return _popup.get_parent_area_size().y * 0.42 - 40.0
