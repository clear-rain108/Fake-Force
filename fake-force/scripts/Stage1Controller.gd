extends Node2D
## 阶段1 控制器（Main.tscn 专用，新建脚本；不改动任何核心 .gd）
##
## 叙事触发链：
##  1) 房间5 尘埃（Dust1）收集 → 记事本第1页 + 打开迷宫闸门(MazeEntranceGate) + 启用强推力(PushToMaze)
##     （Dust 无收集信号，收集即 queue_free → 监听 tree_exiting 触发）
##  2) 中控室 LaunchButton：玩家进入显示提示；按 E（现有 collect 键映射）→ 黑屏淡出
##     → 背景切太空(set_theme=THEME_SPACE) + 传送旋转环廊起点 → 淡入
##
## 依赖 Main.tscn 中的节点：Dust1 / MazeEntranceGate / PushToMaze / Background / ControlRoom/LaunchButton

const THEME_SPACE : int = 0
const RING_SPAWN : Vector2 = Vector2(7900.0, 605.0)   # 旋转环廊起点（RingGround 上方，避开圆盘/阶梯）

var _player : CharacterBody2D = null
var _dust_room5 : Area2D = null
var _maze_gate : Node = null
var _push_zone : Area2D = null
var _background : Node = null
var _button_area : Area2D = null
var _button_label : Label = null
var _in_button : bool = false
var _launching : bool = false
var _fade : ColorRect = null


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("Player")
	_dust_room5 = get_node_or_null("../Dust1")
	_maze_gate = get_node_or_null("../MazeEntranceGate")
	_push_zone = get_node_or_null("../PushToMaze")
	_background = get_node_or_null("../Background")
	_button_area = get_node_or_null("../ControlRoom/LaunchButton")
	if _button_area:
		_button_label = _button_area.get_node_or_null("HintLabel")
		_button_area.body_entered.connect(_on_button_entered)
		_button_area.body_exited.connect(_on_button_exited)
	if _dust_room5:
		_dust_room5.tree_exiting.connect(_on_room5_dust_collected)
	# 黑屏跃迁层（layer 80，盖过 HUD/红晕）
	var cl := CanvasLayer.new()
	cl.layer = 80
	_fade = ColorRect.new()
	_fade.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(_fade)
	add_child(cl)


## 房间5尘埃被收集（Dust 收集即 queue_free，tree_exiting 触发）
func _on_room5_dust_collected() -> void:
	# 场景销毁中（死亡演出结束 change_scene → 场景内 Dust 的 tree_exiting 也会触发本回调），
	# 若本控制器已退出场景树则忽略（is_inside_tree 不触碰已销毁的树，避免空树崩溃）。
	if not is_inside_tree():
		return
	var nb := get_tree().get_first_node_in_group("Notebook")
	if nb and nb.has_method("unlock_pages"):
		nb.unlock_pages(1)   # 记事本第1页
	if _maze_gate and is_instance_valid(_maze_gate):
		_maze_gate.queue_free()   # 迷宫闸门打开
	if _push_zone:
		_push_zone.monitoring = true   # 强推力生效（原 disabled → monitoring）
	var hud := get_tree().get_first_node_in_group("HUD")
	if hud and hud.has_method("show_message"):
		hud.show_message("【系统】：检测到高密度尘埃反应——迷宫闸门开启，引擎推力过载。", 5.0)


func _on_button_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		_in_button = true
		if _button_label:
			_button_label.visible = true


func _on_button_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		_in_button = false
		if _button_label:
			_button_label.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _launching or not _in_button:
		return
	# 使用现有 Input 映射（collect = E 键）
	if event is InputEventKey and event.pressed and not event.echo \
			and InputMap.action_has_event("collect", event):
		_do_launch()


func _do_launch() -> void:
	_launching = true
	Engine.time_scale = 1.0
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.9)     # 黑屏淡出
	tw.tween_callback(_switch_to_space)
	tw.tween_interval(0.3)
	tw.tween_property(_fade, "color:a", 0.0, 0.9)     # 淡入


func _switch_to_space() -> void:
	# 背景切太空（飞船层淡出）
	if _background and _background.has_method("set_theme"):
		_background.set_theme(THEME_SPACE)
	# 玩家传送至旋转环廊起点
	if _player:
		_player.global_position = RING_SPAWN
		_player.velocity = Vector2.ZERO
		_player.rot_state = 0
		if _player.has_method("_reset_rot_state"):
			_player._reset_rot_state()
	_launching = false
