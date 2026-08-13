extends Node2D
## 主菜单背景星空：缓慢自转；按住 Shift 时星星轨迹拉长

@export var star_count : int = 120
@export var field_radius : float = 720.0
@export var rotation_speed : float = 0.12
@export var star_color : Color = Color(1.0, 1.0, 1.0, 0.85)

var _stars : PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	for i in star_count:
		_stars.append(Vector2(randf_range(-field_radius, field_radius),
			randf_range(-field_radius, field_radius)))


func _process(delta: float) -> void:
	rotation += rotation_speed * delta
	queue_redraw()


func _draw() -> void:
	var shift : bool = Input.is_key_pressed(KEY_SHIFT)
	for s in _stars:
		if shift:
			# 轨迹拉长：沿旋转切向延伸
			var dir : Vector2 = s.orthogonal().normalized()
			var track_len : float = 10.0 + s.length() * 0.05
			draw_line(s, s + dir * track_len, Color(star_color, 0.65), 2.0)
		else:
			draw_circle(s, 1.7, star_color)
