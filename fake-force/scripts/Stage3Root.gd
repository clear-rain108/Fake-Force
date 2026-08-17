extends Node2D
## 阶段3 根节点（真相的折叠）：
## - 强制剧情模式
## - 宇宙背景（星云 + 黑洞弧线）
## - 无重旋转环带：绑定旋转核心，全局旋转参考系物理（无跳跃重力）
## - 结局演出随场景自带

const THEME_SPACE : int = 0


func _ready() -> void:
	IllusionManager.set_mode("story")
	var bg := get_node_or_null("Background")
	if bg and bg.has_method("set_theme"):
		bg.set_theme(THEME_SPACE)
	var player := get_tree().get_first_node_in_group("Player")
	var core := get_tree().get_first_node_in_group("RotatingCore")
	if player and core and player.rotating_mode:
		player.setup_rotating(core)
	# 剧情模式暂停菜单（Esc）
	var pm = load("res://scripts/PauseMenu.gd").new()
	add_child(pm)
