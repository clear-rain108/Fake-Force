extends Area2D
## 提示触发区：玩家进入时通过 HUD 显示一次提示文字

@export_multiline var hint_text : String = ""
@export var hint_duration : float = 6.0

var _shown : bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _shown:
		return
	if body.is_in_group("Player"):
		_shown = true
		var hud := get_tree().get_first_node_in_group("HUD")
		if hud:
			hud.show_message(hint_text, hint_duration)
