extends Area2D
## 出口触发（阶段3）：玩家触碰时，若环形轨道剧情（第9~12页）已全部读完 → 启动结局演出；
## 未读全 → 提示"请先完成所有记录"。

var _triggered : bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _triggered or not body.is_in_group("Player"):
		return
	var nb := get_tree().get_first_node_in_group("Notebook")
	if nb and nb.has_method("are_pages_read") and nb.are_pages_read([9, 10, 11, 12]):
		_triggered = true
		AudioManager.play_blackhole_sequence()  # 黑洞跃迁音效序列
		var ending := get_tree().get_first_node_in_group("Ending")
		if ending:
			ending.start_ending()
	else:
		var hud := get_tree().get_first_node_in_group("HUD")
		if hud and hud.has_method("show_system_message"):
			hud.show_system_message("请先完成所有记录")
