extends Node2D
## 解密关卡根节点：进入时确保解密模式（G_TO_ACCEL=10，即时重生）
## 若玩家处于旋转模式，自动绑定场景中的旋转核心

func _ready() -> void:
	IllusionManager.set_mode("puzzle")
	# 动态星空背景（CanvasLayer -1：星云/尘埃/扭曲层 + 背景音乐）
	add_child(load("res://scenes/background.tscn").instantiate())
	var player := get_tree().get_first_node_in_group("Player")
	var core := get_tree().get_first_node_in_group("RotatingCore")
	if player and core and player.rotating_mode:
		player.setup_rotating(core)
	# 暂停菜单（Esc：继续/返回主菜单/退出）
	var pm = load("res://scripts/PauseMenu.gd").new()
	add_child(pm)
