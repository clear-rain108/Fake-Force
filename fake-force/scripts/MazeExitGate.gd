extends Area2D
## 条件出口门（阶段2 迷宫出口）
##
## 初始锁闭：碰撞禁用 + 红色半透明表示。仅物理结构，解锁/开启条件由后续剧情触发任务绑定。
## set_locked(false) 可切换为"开启"外观（绿色），供后续逻辑调用。

@export var locked : bool = true


func _ready() -> void:
	queue_redraw()


## 切换锁闭状态（false = 开启，供后续剧情触发调用）
func set_locked(value: bool) -> void:
	locked = value
	queue_redraw()


func _draw() -> void:
	var c : Color = Color(1.0, 0.2, 0.2, 0.35) if locked else Color(0.3, 1.0, 0.4, 0.35)
	draw_rect(Rect2(-20.0, -60.0, 40.0, 120.0), c)
	draw_rect(Rect2(-20.0, -60.0, 40.0, 120.0), c.lightened(0.25), false, 2.0)
