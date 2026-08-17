extends Area2D
## 提示触发区：玩家进入时通过 HUD 显示一次提示文字

@export_multiline var hint_text : String = ""
@export var hint_duration : float = 6.0
@export var persistent : bool = false   # true=持续显示（教学关卡），不随计时消失

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
			if persistent and hud.has_method("show_system_message_persistent"):
				hud.show_system_message_persistent(hint_text)
			elif hud.has_method("show_system_message"):
				hud.show_system_message(hint_text)
			elif hud.has_method("show_message"):
				hud.show_message(hint_text, hint_duration)
