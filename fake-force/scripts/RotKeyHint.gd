extends Node2D
## 旋转参考系按键方向图例：进入旋转系显示 WASD 对应方向，脱离自动消失
## 挂于 HUD（CanvasLayer）下，屏幕下方居中显示。

var _player : CharacterBody2D = null
var _alpha : float = 0.0
var _font : Font = null


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("Player")


func _process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("Player")
		if not is_instance_valid(_player):
			return
	var in_rot : bool = _player.rot_state != _player.ROT_NONE
	var target : float = 1.0 if in_rot else 0.0
	_alpha = move_toward(_alpha, target, delta * 6.0)
	queue_redraw()


func _draw() -> void:
	if _alpha <= 0.01 or not is_instance_valid(_player):
		return
	var vp := get_viewport_rect().size
	var font : Font = _font
	if font == null:
		font = load("res://fusion-pixel.ttf")
		_font = font
	var a : float = _alpha
	var cx : float = vp.x * 0.5
	var y : float = vp.y - 44.0
	var c : Color = Color(0.85, 0.92, 1.0, a)
	draw_string(font, Vector2(cx - 240.0, y), "W 向心（朝向核心）", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, c)
	draw_string(font, Vector2(cx + 40.0, y), "S 离心（远离核心）", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, c)
	draw_string(font, Vector2(cx - 240.0, y + 22.0), "A ↻ 顺时针", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, c)
	draw_string(font, Vector2(cx + 40.0, y + 22.0), "D ↺ 逆时针", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, c)
	draw_string(font, Vector2(cx - 240.0, y + 44.0), "滚轮 缩放视野", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, c)
