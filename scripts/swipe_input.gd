class_name SwipeInput
extends Node
## Turns touch drags into fight actions.
## A swipe fires as soon as the finger has travelled far enough, not on release,
## so the punch starts while the thumb is still moving. Each touch fires once.
##   up            -> jab (lead hand)
##   down          -> block
##   left / right  -> hook (which hand depends on Tuning "hook_swipe_mirror")

signal swiped(kind: String, side: int)

const JAB_CONE_DEG := 40.0
const BLOCK_CONE_DEG := 50.0

var _touches := {}  # touch index -> {"start": Vector2, "done": bool}


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_touches[touch.index] = {"start": touch.position, "done": false}
		else:
			_touches.erase(touch.index)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if not _touches.has(drag.index):
			return
		var t: Dictionary = _touches[drag.index]
		if t["done"]:
			return
		var start: Vector2 = t["start"]
		var d := drag.position - start
		var min_px: float = Tuning.v("swipe_dist") * get_viewport().get_visible_rect().size.x
		if d.length() < min_px:
			return
		t["done"] = true
		_classify(d)


func _classify(d: Vector2) -> void:
	# 0 deg = straight up, +90 = right, +/-180 = down.
	var ang := rad_to_deg(atan2(d.x, -d.y))
	if absf(ang) <= JAB_CONE_DEG:
		swiped.emit("jab", 0)
	elif absf(ang) >= 180.0 - BLOCK_CONE_DEG:
		swiped.emit("block", 0)
	else:
		var right := ang > 0.0
		var mirrored: bool = Tuning.v("hook_swipe_mirror") >= 0.5
		# Default: the glove travels the way you swipe, so swiping right throws the LEFT hook.
		var side := 0 if right else 1
		if mirrored:
			side = 1 - side
		swiped.emit("hook", side)
