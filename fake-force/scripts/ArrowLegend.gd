extends Node2D
## 全局教学：洞察模式箭头图例
##
## 玩家按住 Shift（洞察模式）时，在屏幕左下角淡入各箭头的含义。
## 按当前参考系显示对应条目（与 Player._draw 的箭头绘制保持一致）：
## - 横向参考系：蓝=输入、红=虚假力、绿=重力
## - 旋转参考系：蓝=输入（A/D切向、W/S径向）、红=惯性力（离心+科里奥利）
## - 切换洞察：额外显示金=目标向心力
## 由 PuzzleHUD / HUD 自动挂载（挂于 CanvasLayer 下，坐标为视口坐标）。

var _alpha : float = 0.0
var _player : CharacterBody2D = null


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("Player")


func _process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("Player")
		if not is_instance_valid(_player):
			return
	# 洞察时淡入，否则淡出
	var target : float = 1.0 if _player.is_insight else 0.0
	_alpha = move_toward(_alpha, target, delta * 6.0)
	queue_redraw()


func _draw() -> void:
	if _alpha <= 0.01 or not is_instance_valid(_player):
		return
	var vp := get_viewport_rect().size
	var x : float = 16.0
	var y : float = vp.y - 240.0
	var a : float = _alpha
	# 切换洞察（同步中）：金色目标向心力置顶
	if _player.rot_state == _player.ROT_SWITCHING:
		_draw_item(x, y, Vector2(36, 0), Color(1.0, 0.84, 0.0, a), false, "金色实线 = 目标向心力（同步后维持圆周）")
		y += 38.0
		_draw_item(x, y, Vector2(36, 0), Color(0.25, 0.6, 1.0, a), false, "蓝色实线 = 你的输入方向（A/D切向、W/S径向）")
		y += 38.0
		_draw_item(x, y, Vector2(36, 0), Color(1.0, 0.3, 0.25, a), true, "红色虚线 = 惯性力（离心+科里奥利）")
		return
	# 旋转参考系
	if _player.rot_state != _player.ROT_NONE:
		_draw_item(x, y, Vector2(36, 0), Color(0.25, 0.6, 1.0, a), false, "蓝色实线 = 你的输入方向（A/D切向、W/S径向）")
		y += 38.0
		_draw_item(x, y, Vector2(36, 0), Color(1.0, 0.3, 0.25, a), true, "红色虚线 = 惯性力（离心+科里奥利，系统在推你）")
		return
	# 横向参考系
	_draw_item(x, y, Vector2(36, 0), Color(0.25, 0.6, 1.0, a), false, "蓝色实线 = 你的输入方向")
	y += 38.0
	_draw_item(x, y, Vector2(36, 0), Color(1.0, 0.3, 0.25, a), true, "红色虚线 = 虚假力（系统在推你）")
	y += 38.0
	_draw_item(x, y, Vector2(0, 36), Color(0.3, 1.0, 0.4, a), false, "绿色实线 = 重力（向下）")


func _draw_item(x: float, y: float, vec: Vector2, color: Color, dashed: bool, text: String) -> void:
	var font := ThemeDB.fallback_font
	var from : Vector2 = Vector2(x, y)
	var to : Vector2 = from + vec
	# 虚线/实线
	if dashed:
		var dir_n : Vector2 = vec.normalized()
		var dash_len : float = 6.0
		var gap_len : float = 4.0
		var total : float = vec.length()
		var dist : float = 0.0
		while dist < total:
			var seg_end : float = minf(dist + dash_len, total)
			draw_line(from + dir_n * dist, from + dir_n * seg_end, color, 2.5)
			dist = seg_end + gap_len
	else:
		draw_line(from, to, color, 2.5)
	# 箭头头部
	if vec.length() > 6.0:
		var dir_n : Vector2 = vec.normalized()
		var head_len : float = 9.0
		var head_base : Vector2 = to - dir_n * head_len
		var perp : Vector2 = dir_n.orthogonal() * head_len * 0.5
		draw_line(to, head_base + perp, color, 2.5)
		draw_line(to, head_base - perp, color, 2.5)
	# 文字
	draw_string(font, Vector2(x + vec.length() + 14.0, y + 4.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
