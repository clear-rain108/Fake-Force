extends Area2D
## 记事本解锁触发区：玩家进入时解锁前 N 页剧情碎片
## 触发方式为"区域进入事件"（v3.0 §5.1 约束4 允许），保证叙事推进稳定。

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
		if nb:
			nb.unlock_pages(unlock_count)
