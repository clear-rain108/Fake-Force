extends Area2D
## 出口触发（阶段3）：玩家触碰后启动结局演出

var _triggered : bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _triggered:
		return
	if body.is_in_group("Player"):
		_triggered = true
		AudioManager.play_blackhole_sequence()  # 黑洞跃迁音效序列
		var ending := get_tree().get_first_node_in_group("Ending")
		if ending:
			ending.start_ending()
