extends Area2D
## 解密模式终点：金色发光菱形，玩家触碰触发胜利演出

var _triggered : bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _triggered:
		return
	if body.is_in_group("Player"):
		_triggered = true
		var v := get_tree().get_first_node_in_group("PuzzleVictory")
		if v:
			v.start()
		else:
			get_tree().change_scene_to_file("res://LevelSelect.tscn")


func _draw() -> void:
	# 金色菱形 + 光晕
	draw_circle(Vector2.ZERO, 20.0, Color(1.0, 0.9, 0.4, 0.22))
	var pts := PackedVector2Array([
		Vector2(0.0, -24.0), Vector2(17.0, 0.0),
		Vector2(0.0, 24.0), Vector2(-17.0, 0.0)])
	draw_colored_polygon(pts, Color(1.0, 0.84, 0.0, 1.0))
	draw_polyline(pts, Color(1.0, 0.97, 0.6), 2.0)
