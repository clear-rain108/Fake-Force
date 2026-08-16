extends Control
## 选关页：解密模式 主线关卡
## 背景：太空（默认）；悬停 Q1/Q2（飞船内部）平滑交叉淡化切换

const THEME_SPACE : int = 0
const THEME_SHIP : int = 1

const LEVELS : Array = [
	["res://levels/Q1.tscn", "Q1  变向偏转", THEME_SHIP],
	["res://levels/Q2.tscn", "Q2  双向往返", THEME_SHIP],
	["res://levels/Q3.tscn", "Q3  参考系登高", THEME_SPACE],
	["res://levels/Q4.tscn", "Q4  离心抛射", THEME_SPACE],
	["res://levels/Q5.tscn", "Q5  科里奥利", THEME_SPACE],
]

var _bg : CanvasLayer = null


func _ready() -> void:
	# 选关背景：默认太空
	_bg = load("res://scenes/select_background.tscn").instantiate()
	add_child(_bg)
	$BackButton.pressed.connect(_on_back)
	for i in LEVELS.size():
		var btn := Button.new()
		btn.text = String(LEVELS[i][1])
		btn.custom_minimum_size = Vector2(260, 70)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var scene_path : String = String(LEVELS[i][0])
		var bg_theme : int = int(LEVELS[i][2])
		btn.mouse_entered.connect(_on_hover.bind(bg_theme))
		btn.mouse_exited.connect(_on_hover.bind(THEME_SPACE))
		btn.pressed.connect(_on_level.bind(scene_path))
		$Grid.add_child(btn)


func _on_hover(bg_theme: int) -> void:
	if _bg:
		_bg.set_theme(bg_theme)


func _on_level(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)


func _on_back() -> void:
	get_tree().change_scene_to_file("res://MainMenu.tscn")
