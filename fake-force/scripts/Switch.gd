extends Area2D
## 机关（阶段1）：玩家触碰 → 解锁记事本页 + 开启舱门（gate_path 指向的节点被释放）
## 视觉：未触发=蓝绿光点，已触发=亮绿（queue_redraw 刷新）

@export var unlock_page : int = 2          # 解锁前 N 页（1 起）
@export var gate_path : NodePath = NodePath()
@export var hint : String = ""

var _triggered : bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _triggered or not body.is_in_group("Player"):
		return
	_triggered = true
	var nb := get_tree().get_first_node_in_group("Notebook")
	if nb and nb.has_method("unlock_page_only"):
		nb.unlock_page_only(unlock_page)   # 只解锁本机关对应页（不连带前面的页）
	if gate_path != NodePath():
		var gate := get_node_or_null(gate_path)
		if gate:
			gate.queue_free()
	if not hint.is_empty():
		var hud := get_tree().get_first_node_in_group("HUD")
		if hud and hud.has_method("show_message"):
			hud.show_message(hint, 6.0)
	queue_redraw()


func _draw() -> void:
	var c : Color = Color(0.45, 0.95, 0.5, 0.9) if _triggered else Color(0.4, 0.75, 1.0, 0.9)
	draw_circle(Vector2.ZERO, 22.0, Color(c, 0.28))
	draw_circle(Vector2.ZERO, 22.0, c, false, 2.5)
	draw_line(Vector2(-9, 0), Vector2(9, 0), c, 2.0)
	draw_line(Vector2(0, -9), Vector2(0, 9), c, 2.0)
