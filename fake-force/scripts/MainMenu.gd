extends Control
## 主菜单：区分解密模式 / 剧情模式

@onready var _music : AudioStreamPlayer = $Music


func _ready() -> void:
	$PuzzleButton.pressed.connect(_on_puzzle)
	$TeachingButton.pressed.connect(_on_teaching)
	$StoryButton.pressed.connect(_on_story)
	# 开始页音乐：每次进入主菜单时播放，不循环
	_play_menu_music()


func _play_menu_music() -> void:
	var s : AudioStream = _music.stream
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = false  # 兜底确保不循环
	_music.play()


func _on_puzzle() -> void:
	IllusionManager.set_mode("puzzle")
	get_tree().change_scene_to_file("res://LevelSelect.tscn")


func _on_teaching() -> void:
	IllusionManager.set_mode("puzzle")
	get_tree().change_scene_to_file("res://TeachingSelect.tscn")


func _on_story() -> void:
	IllusionManager.set_mode("story")
	get_tree().change_scene_to_file("res://Main.tscn")
