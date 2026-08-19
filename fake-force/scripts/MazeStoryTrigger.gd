extends Area2D
## 迷宫剧情触发区（阶段2 五层塔 L2~L5）：
## 玩家进入触发区 → 自动解锁该层记事本碎片（无需按键）；
## 按 F 阅读（交由记事本自身处理）；按 X 改变该层幻觉方向。
## 操作提示已写入剧情第 4 页。

@export var page_number : int = 4              # 解锁的记事本页号（4~8）
@export var zone_path : NodePath = NodePath()  # 对应 IllusionZone（X 改变该层方向）
@export var new_direction : Vector2 = Vector2.DOWN

var _in_zone : bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	_in_zone = true
	var nb := get_tree().get_first_node_in_group("Notebook")
	if nb:
		if nb.has_method("unlock_page"):
			nb.unlock_page(page_number)   # 到达自动解锁（幂等）
		if nb.has_method("show_floating_text"):
			nb.show_floating_text("📖 按 F 阅读档案碎片 ｜ 按 X 改变幻觉方向", 6.0)


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		_in_zone = false


func _input(event: InputEvent) -> void:
	# 仅拦截 X（改变该层幻觉方向）；F 不拦截，交给记事本阅读
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.physical_keycode != KEY_X:
		return
	# 玩家在剧情触发区内，或在该层幻觉区内（整层均可按 X 改变方向）
	var zone := get_node_or_null(zone_path)
	var in_layer : bool = zone != null and int(zone.get("_occupants")) > 0
	if not _in_zone and not in_layer:
		return
	_change_direction()
	get_viewport().set_input_as_handled()


func _change_direction() -> void:
	var zone := get_node_or_null(zone_path)
	if zone:
		zone.set("field_directions", [new_direction])
		var field = zone.get("_field")
		if field:
			field.directions = [new_direction]
			field.reset()
	var hud := get_tree().get_first_node_in_group("HUD")
	if hud and hud.has_method("show_system_message"):
		hud.show_system_message("【系统】：已改变该层幻觉方向 → " + _dir_text(new_direction))


## 方向文字：幻觉力 = -参考系加速方向
func _dir_text(d: Vector2) -> String:
	if d == Vector2.DOWN:
		return "↓（参考系向下加速，玩家被向上推，层内变轻）"
	if d == Vector2.UP:
		return "↑（参考系向上加速，玩家被向下压，层内变重）"
	if d == Vector2.RIGHT:
		return "→（参考系向右加速，玩家被向左推）"
	if d == Vector2.LEFT:
		return "←（参考系向左加速，玩家被向右推）"
	return str(d)

