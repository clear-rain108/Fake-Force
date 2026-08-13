extends Control
## 选关页：解密模式 7 个关卡

const LEVELS : Array = [
	["res://levels/puzzle_1_1.tscn", "1-1  初识偏转"],
	["res://levels/puzzle_1_2.tscn", "1-2  变向偏转"],
	["res://levels/puzzle_1_3.tscn", "1-3  双向往返"],
	["res://levels/puzzle_2_1.tscn", "2-1  幻灵垫脚"],
	["res://levels/puzzle_2_2.tscn", "2-2  尘埃轻重"],
	["res://levels/puzzle_3_1.tscn", "3-1  离心抛射"],
	["res://levels/puzzle_3_2.tscn", "3-2  科里奥利"],
]


func _ready() -> void:
	$BackButton.pressed.connect(_on_back)
	for i in LEVELS.size():
		var btn := Button.new()
		btn.text = String(LEVELS[i][1])
		btn.custom_minimum_size = Vector2(260, 70)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var scene_path : String = String(LEVELS[i][0])
		btn.pressed.connect(_on_level.bind(scene_path))
		$Grid.add_child(btn)


func _on_level(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)


func _on_back() -> void:
	get_tree().change_scene_to_file("res://MainMenu.tscn")
