extends Node2D
## 关卡生成器（剧情模式 阶段1+2）：偏转回廊 → 机关/迷宫 → 多场走廊 → 旋转环廊 → 黑洞舱门
## 阶段3 已拆分为独立 Stage3.tscn（无重力旋转环带）
## 平台高度差 ≈ 120px（配合跳跃高度225px）。坐标可在此手调。

@export var platform_height : float = 30.0
@export var platform_color : Color = Color(0.4, 0.4, 0.4)

## 平台配置：[中心x, 中心y, 宽度]
var layout : Array = [
	# —— 阶段1：偏转回廊（缺口教学） ——
	[0.0,   700.0, 500.0],   # P1 起始平台（右侧留缺口）
	[420.0, 700.0, 160.0],   # P2 缺口对岸（教学洞察补偿）
	[700.0, 580.0, 220.0],   # P3
	[1000.0, 580.0, 220.0],  # P4
	[1280.0, 460.0, 240.0],  # P5（上方有第1枚尘埃）
	[1600.0, 460.0, 260.0],  # P6
	[1900.0, 340.0, 280.0],  # P7
	[2240.0, 340.0, 300.0],  # P8
	[2600.0, 220.0, 400.0],  # P9 阶段1终点
	[3200.0, 220.0, 300.0],  # P10 机关台（Switch 在此）
	# —— 迷宫地面（分段 + 幻灵方块垫脚） ——
	[3520.0, 560.0, 240.0],  # Maze1 (x3400..3640)
	[3900.0, 560.0, 240.0],  # Maze2 (x3780..4020)
	[4260.0, 560.0, 240.0],  # Maze3 (x4140..4380)
	[4900.0, 560.0, 200.0],  # Maze4 出口 (x4800..5000)
	# —— 阶段2：多场走廊 ——
	[5200.0, 500.0, 500.0],  # Corr1
	[5700.0, 500.0, 500.0],  # Corr2
	[6200.0, 500.0, 500.0],  # Corr3
	[6700.0, 400.0, 500.0],  # Corr4
	[7250.0, 400.0, 300.0],  # Corr5（入环衔接）
	# —— 阶段2：旋转环廊 ——
	[7900.0, 600.0, 800.0],  # RingGround（安全网）
	[7900.0, 560.0, 560.0],  # CorePlatform（圆盘，跳上后切换参考系）
	[7900.0, 470.0, 300.0],  # Step1
	[8200.0, 340.0, 300.0],  # Step2
	[8550.0, 210.0, 260.0],  # Step3
	[8900.0, 180.0, 300.0],  # Transition（黑洞舱门平台）
]


func _ready() -> void:
	for p in layout:
		_add_platform(p[0], p[1], p[2])


func _add_platform(cx: float, cy: float, w: float) -> void:
	var body := StaticBody2D.new()
	body.position = Vector2(cx, cy)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(w, platform_height)
	col.shape = shape
	body.add_child(col)
	var poly := Polygon2D.new()
	var hw : float = w * 0.5
	var hh : float = platform_height * 0.5
	poly.polygon = PackedVector2Array([
		Vector2(-hw, -hh), Vector2(hw, -hh),
		Vector2(hw, hh), Vector2(-hw, hh)])
	poly.color = platform_color
	body.add_child(poly)
	add_child(body)
