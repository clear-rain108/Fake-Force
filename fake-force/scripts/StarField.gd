extends Node2D
## 粒子星空背景（极简）
## 白色小点随机分布，整体缓慢旋转。
## 洞察模式下（Engine.time_scale < 1）星空定格。

@export var star_count : int = 140
@export var rotation_speed : float = 0.04   # rad/s
@export var field_radius : float = 1600.0
@export var star_radius : float = 1.6
@export var star_color : Color = Color(1.0, 1.0, 1.0, 0.85)

var _stars : PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	for i in star_count:
		_stars.append(Vector2(
			randf_range(-field_radius, field_radius),
			randf_range(-field_radius, field_radius)))


func _process(delta: float) -> void:
	if Engine.time_scale >= 0.999:
		rotation += rotation_speed * delta


func _draw() -> void:
	for s in _stars:
		draw_circle(s, star_radius, star_color)
