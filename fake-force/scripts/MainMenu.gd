extends Control
## 主菜单：区分解密模式 / 剧情模式

func _ready() -> void:
	$PuzzleButton.pressed.connect(_on_puzzle)
	$StoryButton.pressed.connect(_on_story)


func _on_puzzle() -> void:
	IllusionManager.set_mode("puzzle")
	get_tree().change_scene_to_file("res://LevelSelect.tscn")


func _on_story() -> void:
	IllusionManager.set_mode("story")
	get_tree().change_scene_to_file("res://Main.tscn")
