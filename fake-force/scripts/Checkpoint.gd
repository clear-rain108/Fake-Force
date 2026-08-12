extends Area2D
## 存档点：玩家触碰后更新复活点并提示"已存档"
## 玩家坠落时回到最近存档点，而非关卡起点。

@export var checkpoint_color : Color = Color(0.2, 1.0, 0.4)

var _activated : bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _activated:
		return
	if body.is_in_group("Player"):
		_activated = true
		body.set_checkpoint(global_position)
		var hud := get_tree().get_first_node_in_group("HUD")
		if hud:
			hud.show_message("已存档", 2.0)
		queue_redraw()


func _draw() -> void:
	var c : Color = checkpoint_color.lightened(0.3) if _activated else checkpoint_color
	draw_line(Vector2(0.0, 30.0), Vector2(0.0, -60.0), c, 3.0)
	draw_circle(Vector2(0.0, -60.0), 10.0, c)
