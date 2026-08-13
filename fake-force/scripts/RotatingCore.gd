extends Node2D
## 旋转核心（阶段3：真相的折叠）
##
## 产生旋转参考系的虚假力：
##   离心力（加速度）   = ω² × r（r = 物体相对核心的位置矢量，指向外）
##   科里奥利力（加速度）= 2ω×v 的 2D 分量 = (2ω·vy, -2ω·vx)（跑得越快偏得越狠）
##
## 玩家位置的合成加速度写入 IllusionManager.rotating_accel，
## 玩家经 get_current_fake_vector() 统一读取（与区域幻觉力叠加）。

@export_group("旋转参数")
@export var omega : float = 1.5            # rad/s（试玩校准）
@export var gravity_in : float = 250.0     # 向核心的引力加速度（旋转圆盘模型）
@export var coriolis_scale : float = 0.0   # 科里奥利（剧情模式阶段3已关闭）
@export var influence_radius : float = 300.0  # 影响/圆盘半径
@export var core_radius : float = 60.0     # 视觉半径
@export var core_color : Color = Color(0.2, 0.42, 0.95)


func _ready() -> void:
	add_to_group("RotatingCore")


func _physics_process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("Player")
	if is_instance_valid(player):
		var r : Vector2 = player.global_position - global_position
		var dist : float = r.length()
		if dist < influence_radius and dist > 1.0:
			var v : Vector2 = player.velocity
			IllusionManager.rotating_accel = \
				omega * omega * r + Vector2(2.0 * omega * v.y, -2.0 * omega * v.x) * coriolis_scale
			return
	IllusionManager.rotating_accel = Vector2.ZERO


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