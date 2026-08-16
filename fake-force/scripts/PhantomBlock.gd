extends RigidBody2D
## 幻灵方块（阶段2）
##
## is_phantom = true  ：受幻觉影响（按 global_influence_strength 比例受力）
## is_phantom = false ：绝对方块（绝缘体），纹丝不动
##
## 方块为"无重力"悬浮物，在 x_min~x_max 范围内被幻觉力来回推动，
## 玩家可踩其垫脚。视觉：幻灵=半透明蓝，绝对=实心橙。

@export var is_phantom : bool = true
@export var size_x : float = 100.0
@export var size_y : float = 40.0
@export var x_min : float = -INF
@export var x_max : float = INF
@export var bounce : float = 0.0
## bounce>0 时撞到漂移边界按该系数反弹（往复摆动，供综合关“移动浮桥”使用）；默认 0=撞边停（原行为）
@export var counts_as_occupant : bool = true
## false 时不作为 IllusionZone 的占用体计数（避免多区域关卡中“无人区”的方块干扰当前幻觉场写入）


func _ready() -> void:
	if counts_as_occupant:
		add_to_group("IllusionGroup")


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if is_phantom:
		var fake_accel : Vector2 = IllusionManager.get_current_fake_vector()
		var k : float = IllusionManager.get_current_damping()
		var strength : float = IllusionManager.global_influence_strength
		# 幻觉力 + 阻尼（力 = m×a）
		var f : Vector2 = fake_accel * strength * mass - k * state.linear_velocity * mass
		state.apply_central_force(f)
	# 漂移范围限制（无重力悬浮物的"边界"；bounce>0 时反弹往复）
	var p : Vector2 = state.transform.origin
	var moved : bool = false
	if p.x < x_min:
		p.x = x_min
		moved = true
	elif p.x > x_max:
		p.x = x_max
		moved = true
	if moved:
		state.transform.origin = p
		state.linear_velocity.x = -state.linear_velocity.x * bounce if bounce > 0.0 else 0.0


func _draw() -> void:
	var c : Color = Color(0.27, 0.53, 1.0, 0.5) if is_phantom else Color(1.0, 0.53, 0.0, 1.0)
	var hx : float = size_x * 0.5
	var hy : float = size_y * 0.5
	draw_rect(Rect2(-hx, -hy, size_x, size_y), c)
	draw_rect(Rect2(-hx, -hy, size_x, size_y), c.lightened(0.35), false, 2.0)
