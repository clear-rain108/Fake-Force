extends Area2D
## 轨道出口触发器（Stage3 环形轨道）：玩家跳下轨道（Seg3 底部外侧）时
## 关闭"脚指向核心"视角（切回横向参考系视角），并启用核心引力陷阱区（GravityWell）。
## 仅用于视角切换，不改变物理参考系。


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	if body.has_method("set_feet_to_core"):
		body.set_feet_to_core(false)   # 脱离轨道：脚不再指向核心
	# body_entered 回调处于物理查询冲刷期（flushing queries），
	# 禁止直接修改碰撞形状的 disabled 状态；用 call_deferred 延迟到安全时机执行。
	call_deferred("_enable_gravity_well")


## 启用核心引力陷阱区（GravityWell 碰撞初始禁用，玩家跳下轨道后才激活）
func _enable_gravity_well() -> void:
	var well := get_tree().get_first_node_in_group("GravityWell")
	if well:
		var col := well.get_node_or_null("CollisionShape2D")
		if col:
			col.disabled = false
