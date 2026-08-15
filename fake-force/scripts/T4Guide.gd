extends Node2D
## T4 教学：状态驱动的参考系提示（保证"进入/脱离"提示出现在正确时机）
## 挂载于 T4 场景根（Main）下。
## - 首次同步完成（真正进入旋转系）→ 操作教学
## - 首次脱离旋转系 → 通关指引
## （靠近圆盘时的"建议切换"提示由 Player 全局逻辑显示）

var _player : CharacterBody2D = null
var _core : Node2D = null
var _notified_enter : bool = false
var _notified_exit : bool = false


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("Player")
	_core = get_tree().get_first_node_in_group("RotatingCore")


func _process(_delta: float) -> void:
	if not is_instance_valid(_player) or not is_instance_valid(_core):
		_player = get_tree().get_first_node_in_group("Player")
		_core = get_tree().get_first_node_in_group("RotatingCore")
		return
	var in_rot : bool = _player.rot_state != _player.ROT_NONE
	# 首次同步完成 → 教学"已进入旋转参考系"
	if in_rot and not _notified_enter:
		_notified_enter = true
		_msg("已进入旋转参考系：A/D 沿圆周移动（切向），W/S 远离/靠近圆心（径向）。灰色平台已隐身！移动到圆盘对侧后，持续切向加速（按住 A/D）甩出圆盘，落到对岸平台。")
	# 首次脱离 → 教学"已脱离旋转参考系"
	elif not in_rot and _notified_enter and not _notified_exit:
		_notified_exit = true
		_msg("已脱离旋转参考系，平台重新现身。抵达金色菱形即可通关。")


func _msg(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("HUD")
	if hud and hud.has_method("show_system_message"):
		hud.show_system_message(text)
