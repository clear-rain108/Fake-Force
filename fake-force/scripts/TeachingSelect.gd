extends Control
## 教学关卡：入门教程（T1 初识偏转 / T2 幻灵垫脚 / T3 尘埃轻重 / T4 旋转参考系）
## 背景：整页固定"飞船内部"风格

const THEME_SPACE : int = 0
const THEME_SHIP : int = 1

const LEVELS : Array = [
	["res://levels/T1.tscn", "T1  初识偏转"],
	["res://levels/T2.tscn", "T2  幻灵垫脚"],
	["res://levels/T3.tscn", "T3  尘埃轻重"],
	["res://levels/T4.tscn", "T4  旋转参考系"],
]

var _bg : CanvasLayer = null


func _ready() -> void:
	# 选关背景：固定飞船内部
	_bg = load("res://scenes/select_background.tscn").instantiate()
	add_child(_bg)
	_bg.set_theme(THEME_SHIP)
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
