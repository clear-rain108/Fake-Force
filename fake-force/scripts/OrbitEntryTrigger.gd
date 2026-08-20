extends Area2D
## 轨道入口触发器（Stage3 环形轨道）：玩家跳上 Seg0 时初始化旋转参考系
## （绑定核心 + 脚指向核心视角）。由于 start_in_rot=false，
## 玩家需在核心影响范围内按 Shift 完成参考系同步（ROT_SWITCHING→ROT_SYNCED）。


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	var core := get_tree().get_first_node_in_group("RotatingCore")
	if core and body.has_method("setup_rotating"):
		body.setup_rotating(core)   # 绑定旋转核心（物理切换仍由 Shift 同步触发）
	if body.has_method("set_feet_to_core"):
		body.set_feet_to_core(true)   # 轨道段：脚指向核心
