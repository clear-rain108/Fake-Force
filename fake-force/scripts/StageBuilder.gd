extends Node2D
## 关卡生成器：阶段1（唯我幻觉）+ 阶段2（唯物过渡）
## 平台高度差 ≈ 120px（配合跳跃高度144px）。坐标可在此手调。

@export var platform_height : float = 30.0
@export var platform_color : Color = Color(0.4, 0.4, 0.4)

## 平台配置：[中心x, 中心y, 宽度]
var layout : Array = [
	# —— 阶段1：唯我幻觉 ——
	[0.0,   700.0, 600.0],   # P1 起始平台
	[450.0, 700.0, 200.0],   # P2 水平
	[700.0, 580.0, 220.0],   # P3 上升
	[1000.0, 580.0, 220.0],  # P4 水平
	[1280.0, 460.0, 240.0],  # P5 上升
	[1600.0, 460.0, 260.0],  # P6 水平
	[1900.0, 340.0, 280.0],  # P7 上升
	[2240.0, 340.0, 300.0],  # P8 水平
	[2600.0, 220.0, 400.0],  # P9 阶段1终点
	# —— 阶段2：唯物过渡（深渊 x3350~4050，幻灵方块垫脚）——
	[3200.0, 220.0, 300.0],  # P10 起跳平台
	[4200.0, 220.0, 300.0],  # P11 对岸平台
	[4650.0, 220.0, 300.0],  # P12
	[5100.0, 100.0, 300.0],  # P13 上升
	# —— 阶段3：真相的折叠（黑洞 · 旋转核心）——
	[5600.0, 150.0, 400.0],  # P14 过渡
	[6400.0, 560.0, 1000.0], # P15 核心地面
	[6400.0, 390.0, 140.0],  # P16 核心顶平台（起跳点）
	[6400.0, 200.0, 260.0],  # 出口平台（高处，离心力甩入）
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
