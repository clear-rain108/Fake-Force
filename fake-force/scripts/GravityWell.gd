extends Area2D
## 引力陷阱区（Stage3 结局触发）：位于黑洞核心周围（半径120）。
## 碰撞始终启用；玩家进入后：
##   - 剧情（第9~12页）全部已读 → 吸附玩家（禁用其物理）并拉向核心，距离 < 50px 触发结局；
##   - 未读全 → 仅提示"请先完成所有记录"，不禁用玩家物理（玩家可自由操作/逃离）。
## 触发结局动画前先做 2s 黑屏渐入（黑屏铺满后再 start_ending）。

const ENDING_FADE_TIME : float = 2.0   # 结局动画前的黑屏渐入时长（秒）

var _fade_t : float = -1.0              # 黑屏渐入计时（-1=未开始）
var _fade_rect : ColorRect = null


func _ready() -> void:
	add_to_group("GravityWell")
	body_entered.connect(_on_body_entered)


var _active : bool = false   # 是否已吸附玩家（防止重复/多体触发）
var _core : Node2D = null


func _on_body_entered(body: Node2D) -> void:
	if _active or not body.is_in_group("Player"):
		return
	# 剧情（第9~12页）全部已读才激活结局吸入；未读全只提示、不禁用玩家物理
	var nb := get_tree().get_first_node_in_group("Notebook")
	var story_done : bool = nb != null and nb.has_method("are_pages_read") \
			and nb.are_pages_read([9, 10, 11, 12])
	if not story_done:
		var hud := get_tree().get_first_node_in_group("HUD")
		if hud and hud.has_method("show_system_message"):
			hud.show_system_message("请先完成所有记录")
		return
	_active = true
	body.set_physics_process(false)   # 禁用玩家输入/物理（GravityWell 接管移动）
	_core = get_tree().get_first_node_in_group("RotatingCore")
	# 清空玩家残留速度（避免高速滑入的惯性把玩家带离核心），由 GravityWell 直接控制移动
	body.velocity = Vector2.ZERO


func _physics_process(delta: float) -> void:
	if not _active or not is_instance_valid(_core):
		return
	var player := get_tree().get_first_node_in_group("Player")
	if not is_instance_valid(player):
		return
	# 直接向核心移动（不受玩家进入时的残留速度影响）：吸入速度 400px/s
	var to_core : Vector2 = _core.global_position - player.global_position
	var dist : float = to_core.length()
	if dist < 0.001:
		return
	to_core /= dist
	player.global_position += to_core * 400.0 * delta
	player.velocity = to_core * 400.0
	# 距离 < 50px → 开始结局动画前的黑屏渐入
	if player.global_position.distance_to(_core.global_position) < 50.0:
		_active = false
		_begin_ending_fade()


## 开始结局前的 2s 黑屏渐入（黑屏铺满后由 _process 启动结局演出）
func _begin_ending_fade() -> void:
	if _fade_t >= 0.0:
		return
	_fade_t = 0.0
	var layer := CanvasLayer.new()
	layer.layer = 90   # 高于 HUD/GrimVignette(40)，低于 Ending(100)
	add_child(layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade_rect)


func _process(delta: float) -> void:
	if _fade_t < 0.0:
		return
	_fade_t += delta
	if _fade_rect:
		_fade_rect.color.a = clampf(_fade_t / ENDING_FADE_TIME, 0.0, 1.0)
	if _fade_t >= ENDING_FADE_TIME:
		_fade_t = -1.0
		var ending := get_tree().get_first_node_in_group("Ending")
		if ending and ending.has_method("start_ending"):
			ending.start_ending()

