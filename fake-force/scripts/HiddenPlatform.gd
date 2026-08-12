extends StaticBody2D
## 隐藏平台（阶段3）：常态近乎不可见，洞察模式（time_scale<1）下半透明可见
## 物理碰撞始终存在，玩家需借洞察发现它。

@export var platform_width : float = 320.0
@export var platform_height : float = 30.0
@export var platform_color : Color = Color(0.55, 0.75, 1.0)
@export var hidden_alpha : float = 0.05
@export var revealed_alpha : float = 0.5


func _ready() -> void:
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(platform_width, platform_height)
	col.shape = shape
	add_child(col)


func _process(_delta: float) -> void:
	# 洞察模式（子弹时间）下可见，常态近乎隐形
	modulate.a = revealed_alpha if Engine.time_scale < 0.999 else hidden_alpha
	queue_redraw()


func _draw() -> void:
	var hw : float = platform_width * 0.5
	var hh : float = platform_height * 0.5
	draw_rect(Rect2(-hw, -hh, platform_width, platform_height), Color(platform_color, 1.0))
	draw_rect(Rect2(-hw, -hh, platform_width, platform_height), Color(0.8, 0.92, 1.0, 0.7), false, 2.0)
