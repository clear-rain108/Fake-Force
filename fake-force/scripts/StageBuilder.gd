extends Node2D
## 关卡生成器（剧情模式 阶段1+2）：偏转回廊 → 机关/迷宫 → 多场走廊 → 旋转环廊 → 黑洞舱门
## 阶段3 已拆分为独立 Stage3.tscn（无重力旋转环带）
## 平台高度差 ≈ 120px（配合跳跃高度225px）。坐标可在此手调。

@export var platform_height : float = 30.0
@export var platform_color : Color = Color(0.4, 0.4, 0.4)

## 平台配置：[中心x, 中心y, 宽度]
var layout : Array = [
	# —— 阶段1：走廊过道（5 间连续房间，薄墙/门洞在 Main.tscn 中定义）——
	[1600.0, 700.0, 3200.0],  # CorridorFloor：x0~3200（房间1~5，原 P1-P10 移除）
	# —— 迷宫（地面分段 + 幻灵/绝对方块垫脚；上两层供"最高层终点"）——
	[3300.0, 640.0, 200.0],   # CorrToMazeStep（x3200..3400，走廊→迷宫过渡台阶）
	[3520.0, 560.0, 240.0],   # Maze1 (x3400..3640)
	[3900.0, 560.0, 240.0],   # Maze2 (x3780..4020)
	[4260.0, 560.0, 240.0],   # Maze3 (x4140..4380)
	[4900.0, 560.0, 200.0],   # Maze4 出口 (x4800..5000)
	[3720.0, 440.0, 200.0],   # MazeMid（第2层，跨 Maze1-2 缺口）
	[4800.0, 330.0, 600.0],   # MazeTop（最高层，x4500..5100，MazeExitSwitch 在此）
	# —— 中控室（操作室；取代原 Corr1/Corr2 平台位置）——
	[5360.0, 330.0, 320.0],   # ControlRoomFloor（x5200..5520，与 MazeTop 同高）
	# —— 阶段2：多场走廊（Corr1/2 移除让位于中控室；Corr3-5 保留）——
	[6200.0, 500.0, 500.0],   # Corr3
	[6700.0, 400.0, 500.0],   # Corr4
	[7250.0, 400.0, 300.0],   # Corr5（入环衔接）
	# —— 阶段2：旋转环廊（重构间距：安全网与圆盘错开 100px，阶梯逐级 +90，避免平台交叠卡住玩家）——
	[7900.0, 640.0, 900.0],   # RingGround（安全网，x7450..8350，顶625）
	[7900.0, 540.0, 600.0],   # CorePlatform（圆盘，顶525；跳上后切换参考系）
	[7900.0, 450.0, 300.0],   # Step1（顶435）
	[8250.0, 360.0, 300.0],   # Step2（顶345）
	[8600.0, 270.0, 260.0],   # Step3（顶255）
	[8900.0, 180.0, 300.0],   # Transition（顶165，黑洞舱门平台）
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
