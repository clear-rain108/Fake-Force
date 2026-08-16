extends Area2D
## 阶段2→3 衔接：玩家进入 → 解锁记事本第5页 → 黑屏淡出切换到 Stage3

@export var unlock_page : int = 5
@export var next_scene : String = "res://scenes/Stage3.tscn"
@export var hint : String = ""

var _triggered : bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _triggered or not body.is_in_group("Player"):
		return
	_triggered = true
	var nb := get_tree().get_first_node_in_group("Notebook")
	if nb and nb.has_method("unlock_pages"):
		nb.unlock_pages(unlock_page)
	if not hint.is_empty():
		var hud := get_tree().get_first_node_in_group("HUD")
		if hud and hud.has_method("show_message"):
			hud.show_message(hint, 6.0)
	StageFade.fade_out_and_change(next_scene)


func _draw() -> void:
	draw_circle(Vector2.ZERO, 26.0, Color(0.5, 0.85, 1.0, 0.25))
	draw_arc(Vector2.ZERO, 26.0, 0.0, TAU, 32, Color(0.7, 0.9, 1.0, 0.85), 2.5)
