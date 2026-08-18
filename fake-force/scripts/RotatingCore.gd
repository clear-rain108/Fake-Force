extends Node2D
## 旋转核心（阶段3：真相的折叠）
##
## 旋转参考系的虚假力（离心 ω²r + 科里奥利 2ω×v）由 Player._rotating_physics
## 全权计算，并经 IllusionManager.set_rot_inertia 写入 current_fake_vector
## （驱动 HUD G 值 / 洞察红箭 / 幻灵方块 / 星空漂移）。
## 本节点只负责：组注册 + 视觉自转 + 圆盘绘制。

@export_group("旋转参数")
@export var omega : float = 1.5            # rad/s（试玩校准）
@export var influence_radius : float = 300.0  # 影响/圆盘半径
@export var core_radius : float = 60.0     # 视觉半径
@export var core_color : Color = Color(0.2, 0.42, 0.95)


func _ready() -> void:
	add_to_group("RotatingCore")
	z_index = -1   # 核心绘制在玩家之下（玩家精灵有效 z=0，避免玩家被核心掩盖）


func _process(delta: float) -> void:
	rotation += omega * delta  # 视觉自转
	queue_redraw()


func _draw() -> void:
	# 核心本体
	draw_circle(Vector2.ZERO, core_radius, core_color)
	draw_arc(Vector2.ZERO, core_radius - 12.0, 0.0, TAU, 48, Color(0.8, 0.9, 1.0, 0.8), 3.0)
	# 苍蓝外晕
	draw_arc(Vector2.ZERO, core_radius + 26.0, 0.0, TAU, 64, Color(core_color, 0.35), 2.0)
	# 旋转指示线（随时间转动）
	var a : float = rotation
	draw_line(Vector2.ZERO, Vector2.from_angle(a) * (core_radius + 40.0), Color(0.9, 0.95, 1.0, 0.7), 2.0)
	# 公转小点（随核心旋转，强化旋转感）
	var n := 4
	for i in n:
		var da : float = rotation + TAU * float(i) / float(n)
		draw_circle(Vector2.from_angle(da) * (core_radius + 62.0), 4.5, Color(0.75, 0.9, 1.0, 0.85))