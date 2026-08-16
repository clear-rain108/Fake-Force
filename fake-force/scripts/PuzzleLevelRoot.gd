extends Node2D
## 解密关卡根节点：进入时确保解密模式（G_TO_ACCEL=10，即时重生）
## 若玩家处于旋转模式，自动绑定场景中的旋转核心
## bg_theme: 0=太空（Q3~Q5） 1=飞船内部（T1~T4/Q1/Q2），与选关页按钮一致

const THEME_SPACE : int = 0
const THEME_SHIP : int = 1

@export var bg_theme : int = THEME_SPACE


func _ready() -> void:
	IllusionManager.set_mode("puzzle")
	# 关卡背景（CanvasLayer -1：星云/飞船内部/尘埃/扭曲层 + 背景音乐）
	var bg : Node = load("res://scenes/background.tscn").instantiate()
	add_child(bg)
	if bg.has_method("set_theme"):
		bg.set_theme(bg_theme)
	var player := get_tree().get_first_node_in_group("Player")
	var core := get_tree().get_first_node_in_group("RotatingCore")
	if player and core and player.rotating_mode:
		player.setup_rotating(core)
	# 暂停菜单（Esc：继续/返回主菜单/退出）
	var pm = load("res://scripts/PauseMenu.gd").new()
	add_child(pm)
