extends Area2D
## 幻觉区域（IllusionZone）
##
## 策划案 v2.0 §5.5：四个参数全部作为 Area2D 导出变量，
## 关卡设计师在 Inspector 直接调参，无需碰代码。
## 进入区域的 IllusionGroup 物体（玩家/幻灵方块）受区域参数影响。

@export_group("幻觉参数")
@export var g_value : float = 0.0
@export var eta : float = 1.0
@export var damping : float = 0.5
@export var omega : float = 0.0
@export var direction : Vector2 = Vector2.LEFT

var _occupants : int = 0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("IllusionGroup"):
		_occupants += 1
		_apply_zone()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("IllusionGroup"):
		_occupants = maxi(_occupants - 1, 0)
		if _occupants <= 0:
			IllusionManager.reset_zone_params()
		else:
			_apply_zone()


func _apply_zone() -> void:
	IllusionManager.set_zone_params(g_value, omega, eta, damping, direction)
