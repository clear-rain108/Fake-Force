extends Area2D
## 存档点：玩家触碰后更新复活点并提示"已存档"
## 玩家坠落时回到最近存档点，而非关卡起点。
## unlock_pages_only 非空时：到达该存档点只解锁本处对应的剧情页
## （迷宫五层塔剧情"严格判定、只在存档点触发"；1-based，如 [4] 或 [7, 8]）。

@export var checkpoint_color : Color = Color(0.2, 1.0, 0.4)
@export var unlock_pages_only : Array = []   # 本存档点对应的剧情页（仅解锁这些页）

var _activated : bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _activated:
		return
	if body.is_in_group("Player"):
		_activated = true
		body.set_checkpoint(global_position)
		# 迷宫剧情碎片只在存档点解锁（严格判定；只更新本处对应页）
		if not unlock_pages_only.is_empty():
			var nb := get_tree().get_first_node_in_group("Notebook")
			if nb:
				if nb.has_method("unlock_pages_only"):
					nb.unlock_pages_only(unlock_pages_only)
				if nb.has_method("show_floating_text"):
					nb.show_floating_text("📖 按 F 阅读档案碎片", 6.0)
		var hud := get_tree().get_first_node_in_group("HUD")
		if hud:
			hud.show_message("已存档", 2.0)
		queue_redraw()


func _draw() -> void:
	var c : Color = checkpoint_color.lightened(0.3) if _activated else checkpoint_color
	draw_line(Vector2(0.0, 30.0), Vector2(0.0, -60.0), c, 3.0)
	draw_circle(Vector2(0.0, -60.0), 10.0, c)
