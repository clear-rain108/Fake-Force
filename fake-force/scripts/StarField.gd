extends Node2D
## 粒子星空（v3.0 视觉）
## - 跟随玩家：星空相对玩家铺开，走到哪里都能看到
## - G=0：相对静止或轻微摆动（≤5px）
## - 幻觉场加速度改变时：星空向参考系加速度方向拖曳后衰减（短暂视觉）
## - 黑洞附近：星星被切向拉伸成弧线（旋转拖曳感）

@export var star_count : int = 140
@export var field_radius : float = 1400.0
@export var star_radius : float = 1.6
@export var star_color : Color = Color(1.0, 1.0, 1.0, 0.85)
@export var warp_radius : float = 900.0
@export var warp_amount : float = 70.0
@export var drag_strength : float = 260.0

var _stars : PackedVector2Array = PackedVector2Array()
var _core : Node2D = null
var _t : float = 0.0
var _drag_vel : Vector2 = Vector2.ZERO
var _offset : Vector2 = Vector2.ZERO
var _last_fake : Vector2 = Vector2.ZERO


func _ready() -> void:
	for i in star_count:
		_stars.append(Vector2(
			randf_range(-field_radius, field_radius),
			randf_range(-field_radius, field_radius)))


func _process(delta: float) -> void:
	_t += delta
	# 跟随玩家
	var player := get_tree().get_first_node_in_group("Player")
	var base : Vector2 = player.global_position if is_instance_valid(player) else Vector2.ZERO

	# 幻觉场加速度改变 → 星空向参考系加速度方向拖曳（短暂视觉）
	var fake : Vector2 = IllusionManager.get_current_fake_vector()
	var a_ref : Vector2 = -fake
	var change : Vector2 = a_ref - _last_fake
	if change.length_squared() > 4.0:
		_drag_vel += change.normalized() * drag_strength
	_last_fake = a_ref
	_drag_vel = _drag_vel.lerp(Vector2.ZERO, 3.0 * delta)
	_offset = _offset.lerp(Vector2.ZERO, 1.8 * delta)
	_offset += _drag_vel * delta
	# G=0 时轻微摆动（≤5px）
	var g : float = IllusionManager.get_current_effective_g()
	if g <= 0.01:
		_offset += Vector2(sin(_t * 0.7), cos(_t * 0.5)) * 5.0 * delta

	global_position = base + _offset
	queue_redraw()


func _draw() -> void:
	if _core == null or not is_instance_valid(_core):
		_core = get_tree().get_first_node_in_group("RotatingCore")
	for s in _stars:
		# 黑洞附近：星星被切向拉伸成弧线
		if is_instance_valid(_core):
			var star_global : Vector2 = global_position + s
			var dir : Vector2 = star_global - _core.global_position
			var dist : float = dir.length()
			if dist < warp_radius:
				var k : float = (1.0 - dist / warp_radius)
				var tangent : Vector2 = dir.orthogonal().normalized()
				var seg : float = 2.0 + k * k * 9.0
				var warp : float = k * k * warp_amount
				var cpos : Vector2 = s + tangent * warp
				draw_line(cpos - tangent * seg, cpos + tangent * seg, star_color)
				continue
		draw_circle(s, star_radius, star_color)

