extends StaticBody2D
## 条件出口门（阶段2 迷宫出口）
##
## 初始锁闭：物理碰撞开启（StaticBody2D 阻挡玩家穿过）+ 红色半透明表示。
## 解锁/开启条件由后续剧情触发任务绑定（MazeTopExit 检查通过后调用 set_locked(false)）。
## set_locked(false) 切换为"开启"外观（绿色）并关闭碰撞放行。

@export var locked : bool = true

@onready var _col : CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_apply_collision()
	queue_redraw()


## 切换锁闭状态（false = 开启，供后续剧情触发调用）
func set_locked(value: bool) -> void:
	locked = value
	_apply_collision()
	queue_redraw()


## 锁闭时开启碰撞阻挡玩家；开启后关闭碰撞放行
func _apply_collision() -> void:
	if _col:
		_col.disabled = not locked


func _draw() -> void:
	var c : Color = Color(1.0, 0.2, 0.2, 0.35) if locked else Color(0.3, 1.0, 0.4, 0.35)
	draw_rect(Rect2(-15.0, -10.0, 15.0, 15.0), c)
	draw_rect(Rect2(-15.0, -10.0, 15.0, 15.0), c.lightened(0.25), false, 2.0)
