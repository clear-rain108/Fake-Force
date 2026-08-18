extends Node2D
## 黑洞（阶段3"真相的折叠"）——替代旋转核心（RotatingCore）的视觉本体。
##
## 保留旋转参考系参数（omega / influence_radius）并加入 "RotatingCore" 组，
## 供 Player.setup_rotating / 背景控制器 / 旋转物理无缝复用。
## 绘制：暗黑事件视界 + 吸积盘亮环 + 引力透镜光弧 + 绕转粒子（随 rotation 流动）。
## 准备阶段3重构与结局动画联动。

@export var omega : float = 1.0            # rad/s（旋转参考系角速度，阶段3=1.0）
@export var influence_radius : float = 10000.0  # 影响/黑洞半径
@export var core_radius : float = 180.0    # 黑洞视觉半径
@export var core_color : Color = Color(0.02, 0.03, 0.06)


func _ready() -> void:
	add_to_group("RotatingCore")
	z_index = -1   # 玩家绘制在黑洞之上（避免玩家被掩盖）


func _process(delta: float) -> void:
	rotation += omega * delta  # 吸积盘/光弧随时间旋转
	queue_redraw()


func _draw() -> void:
	# 黑洞本体（暗色事件视界）
	draw_circle(Vector2.ZERO, core_radius, core_color)
	# 视界亮边
	draw_arc(Vector2.ZERO, core_radius, 0.0, TAU, 64, Color(0.4, 0.72, 1.0, 0.8), 3.0)
	# 吸积盘外环（苍蓝）
	var glow : float = core_radius + 34.0
	draw_arc(Vector2.ZERO, glow, 0.0, TAU, 64, Color(0.6, 0.8, 1.0, 0.4), 2.0)
	# 引力透镜光弧（随 rotation 旋转）
	var arc_start : float = rotation
	draw_arc(Vector2.ZERO, glow, arc_start, arc_start + 0.85, 48, Color(0.8, 0.9, 1.0, 0.85), 4.0)
	# 绕转粒子（吸积盘碎屑）
	for i in 8:
		var a : float = rotation * 1.4 + TAU * float(i) / 8.0
		var r : float = glow + 18.0 + 8.0 * sin(rotation * 0.7 + float(i))
		draw_circle(Vector2.from_angle(a) * r, 3.0, Color(0.85, 0.95, 1.0, 0.7))
