extends Node2D
## 剧情模式 阶段1+2 根节点：
## - 强制剧情模式（G_TO_ACCEL 统一 10，与解密一致）
## - 背景切为"飞船内部"（扫描仪器风，与阶段3宇宙背景区分）
## - 绑定阶段2 旋转环廊的核心（玩家 rotating_mode 时启用参考系切换）

const THEME_SPACE : int = 0
const THEME_SHIP : int = 1


func _ready() -> void:
	IllusionManager.set_mode("story")
	var bg := get_node_or_null("Background")
	if bg and bg.has_method("set_theme"):
		bg.set_theme(THEME_SHIP)
	var player := get_tree().get_first_node_in_group("Player")
	var core := get_tree().get_first_node_in_group("RotatingCore")
	if player and core and player.rotating_mode:
		player.setup_rotating(core)
	# 剧情模式暂停菜单（Esc）
	var pm = load("res://scripts/PauseMenu.gd").new()
	add_child(pm)
