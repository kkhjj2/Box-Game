class_name Fighter
extends Node3D
## A placeholder boxer built from primitive meshes, plus its procedural animation.
## Faces local -Z. Gloves are children of the root so punches move in root space;
## the upper body (pivot) leans and twists separately. Side 0 = left glove, 1 = right.

const PIVOT_Y := 0.9
const GUARD := [Vector3(-0.16, 1.5, -0.28), Vector3(0.16, 1.5, -0.28)]
const BLOCK := [Vector3(-0.08, 1.64, -0.25), Vector3(0.08, 1.64, -0.25)]
const OPEN := [Vector3(-0.27, 1.08, -0.18), Vector3(0.27, 1.08, -0.18)]
const GLOW := Color(1.0, 0.45, 0.05)

var pivot: Node3D
var head: MeshInstance3D
var gloves: Array[MeshInstance3D] = []

var _glove_mats: Array[StandardMaterial3D] = []
var _flash_mats: Array[StandardMaterial3D] = []
var _glove_tw: Array = [null, null]
var _pivot_tw: Tween
var _flash_tw: Tween
var _head_tw: Tween
var _stance := "guard"
var _bob_t := 0.0
var _down := false


func setup(skin: Color, trunks: Color, glove: Color) -> void:
	pivot = Node3D.new()
	pivot.position.y = PIVOT_Y
	add_child(pivot)
	var skin_m := _mat(skin)
	var trunks_m := _mat(trunks)
	_flash_mats = [skin_m, trunks_m]
	_mesh(_capsule(0.21, 0.72), skin_m, Vector3(0, 0.34, 0), pivot)
	head = _mesh(_sphere(0.13), skin_m, Vector3(0, 0.78, 0), pivot)
	_mesh(_cylinder(0.23, 0.28), trunks_m, Vector3(0, -0.02, 0), pivot)
	for x: float in [-0.11, 0.11]:
		_mesh(_capsule(0.08, 0.9), skin_m, Vector3(x, 0.45, 0), self)
	for i in 2:
		var gm := _mat(glove)
		_glove_mats.append(gm)
		gloves.append(_mesh(_sphere(0.11), gm, GUARD[i], self))


func _process(delta: float) -> void:
	if _down:
		return
	_bob_t += delta
	pivot.position.y = PIVOT_Y + sin(_bob_t * 4.0) * 0.012


func head_global() -> Vector3:
	return head.global_position


func guard_center_global() -> Vector3:
	var a: Vector3 = BLOCK[0]
	var b: Vector3 = BLOCK[1]
	return to_global((a + b) * 0.5)


## World-space direction a punch from this fighter pushes the target.
func punch_push(side: int, kind: String) -> Vector3:
	var local := Vector3(0, 0, -1)
	if kind == "hook":
		local = Vector3(-_sgn(side), 0, -0.5).normalized()
	return global_transform.basis * local


func set_stance(stance: String) -> void:
	_stance = stance
	var t := 0.06 if stance == "block" else 0.12
	for i in 2:
		_clear_glow(i)
		var tw := _new_glove_tween(i)
		tw.tween_property(gloves[i], "position", _stance_pos(i), t).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	var slump := -0.15 if stance == "open" else 0.0
	_tween_pivot(Vector3(slump, 0, 0), 0.15)


func punch(side: int, kind: String, target_global: Vector3, t_out: float, t_back: float) -> void:
	var g := gloves[side]
	var start := g.position
	var tgt := to_local(target_global)
	tgt -= (tgt - start).normalized() * 0.18  # stop at the surface, not inside the head
	var sgn := _sgn(side)
	var tw := _new_glove_tween(side)
	if kind == "hook":
		var ctrl := Vector3(sgn * 0.6, tgt.y, lerpf(start.z, tgt.z, 0.45))
		var arc := func(t: float) -> void:
			g.position = _bezier(start, ctrl, tgt, t)
		tw.tween_method(arc, 0.0, 1.0, t_out).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	else:
		tw.tween_property(g, "position", tgt, t_out).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_callback(_clear_glow.bind(side))
	tw.tween_property(g, "position", _stance_pos(side), t_back).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# Body: lean in and twist the punching shoulder forward, then settle.
	var twist := sgn * (0.45 if kind == "hook" else 0.15)
	_kill(_pivot_tw)
	_pivot_tw = create_tween()
	_pivot_tw.tween_property(pivot, "rotation", Vector3(-0.12, twist, 0), t_out)
	_pivot_tw.tween_property(pivot, "rotation", Vector3.ZERO, t_back).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


## Telegraph: pull the glove back, grow it and make it glow over `duration`.
func windup(side: int, kind: String, duration: float) -> void:
	var g := gloves[side]
	var sgn := _sgn(side)
	var back := Vector3(sgn * 0.3, 1.52, -0.05)
	if kind == "hook":
		back = Vector3(sgn * 0.5, 1.4, 0.05)
	var tw := _new_glove_tween(side)
	tw.set_parallel(true)
	tw.tween_property(g, "position", back, duration * 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(g, "scale", Vector3.ONE * 1.3, duration).set_ease(Tween.EASE_IN)
	tw.tween_property(_glove_mats[side], "emission", GLOW, duration).set_ease(Tween.EASE_IN)
	_tween_pivot(Vector3(0.05, -sgn * 0.3, 0), duration * 0.7)


func hit_react(push_world: Vector3, heavy: bool) -> void:
	var local := global_transform.basis.inverse() * push_world
	var k := 1.6 if heavy else 1.0
	# Snap into the hit pose instantly so it is what hit-stop freezes on, then recover.
	var hit_rot := Vector3(0.22 * local.z, -0.35 * local.x, -0.25 * local.x) * k
	_kill(_pivot_tw)
	pivot.rotation = hit_rot
	_pivot_tw = create_tween()
	_pivot_tw.tween_property(pivot, "rotation", Vector3.ZERO, 0.35 if heavy else 0.22) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_kill(_head_tw)
	head.position = Vector3(0, 0.78, 0) + local * 0.06 * k
	_head_tw = create_tween()
	_head_tw.tween_property(head, "position", Vector3(0, 0.78, 0), 0.2).set_ease(Tween.EASE_OUT)


func flash() -> void:
	_kill(_flash_tw)
	for m in _flash_mats:
		m.emission = Color(1, 1, 1)
	_flash_tw = create_tween().set_parallel(true)
	for m in _flash_mats:
		_flash_tw.tween_property(m, "emission", Color.BLACK, 0.12).set_delay(0.03)


## Gloves knocked back slightly by an absorbed punch.
func block_bump() -> void:
	for i in 2:
		var tw := _new_glove_tween(i)
		var p := _stance_pos(i)
		gloves[i].position = p + Vector3(0, 0, 0.07)
		tw.tween_property(gloves[i], "position", p, 0.15).set_ease(Tween.EASE_OUT)


func knockout() -> void:
	_down = true
	for i in 2:
		_clear_glow(i)
		var tw := _new_glove_tween(i)
		tw.tween_property(gloves[i], "position", OPEN[i], 0.4)
	_tween_pivot(Vector3(0.3, 0, 0.2), 0.4)
	var fall := create_tween()
	fall.tween_property(self, "rotation:x", 1.45, 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)


# --- helpers -----------------------------------------------------------------

func _stance_pos(side: int) -> Vector3:
	match _stance:
		"block":
			return BLOCK[side]
		"open":
			return OPEN[side]
	return GUARD[side]


func _clear_glow(side: int) -> void:
	_glove_mats[side].emission = Color.BLACK
	gloves[side].scale = Vector3.ONE


func _new_glove_tween(side: int) -> Tween:
	_kill(_glove_tw[side])
	var tw := create_tween()
	_glove_tw[side] = tw
	return tw


func _tween_pivot(rot: Vector3, t: float) -> void:
	_kill(_pivot_tw)
	_pivot_tw = create_tween()
	_pivot_tw.tween_property(pivot, "rotation", rot, t).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


func _kill(tw: Variant) -> void:
	if tw is Tween and (tw as Tween).is_valid():
		(tw as Tween).kill()


static func _sgn(side: int) -> float:
	return -1.0 if side == 0 else 1.0


static func _bezier(a: Vector3, b: Vector3, c: Vector3, t: float) -> Vector3:
	var u := 1.0 - t
	return a * u * u + b * 2.0 * u * t + c * t * t


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.55
	m.emission_enabled = true
	m.emission = Color.BLACK
	m.emission_energy_multiplier = 1.5
	return m


static func _mesh(m: Mesh, mat: Material, pos: Vector3, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 24
	s.rings = 12
	return s


static func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	return c


static func _cylinder(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	return c
