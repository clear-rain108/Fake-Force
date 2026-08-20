extends Area2D
## 记事本解锁触发区：玩家进入时**只**解锁本处对应的第 unlock_count 页（1-based），
## 不连带解锁前面的页。触发方式为"区域进入事件"（v3.0 §5.1 约束4 允许）。

@export var unlock_count : int = 3

var _triggered : bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _triggered:
		return
	if body.is_in_group("Player"):
		_triggered = true
		var nb := get_tree().get_first_node_in_group("Notebook")
		if nb and nb.has_method("unlock_page_only"):
			nb.unlock_page_only(unlock_count)   # 只解锁本处对应页（不连带前面的页）
