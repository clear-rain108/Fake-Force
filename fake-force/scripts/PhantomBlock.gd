extends RigidBody2D
## 幻灵方块（阶段2）
##
## is_phantom = true  ：受幻觉影响（按 global_influence_strength 比例受力）
## is_phantom = false ：绝对方块（绝缘体），纹丝不动

@export var is_phantom : bool = true


func _ready() -> void:
	add_to_group("IllusionGroup")


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if not is_phantom:
		return
	var fake_accel : Vector2 = IllusionManager.get_current_fake_vector()
	if fake_accel == Vector2.ZERO:
		return
	var strength : float = IllusionManager.global_influence_strength
	state.apply_central_force(fake_accel * strength * mass)
