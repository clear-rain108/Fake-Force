extends Node2D
## 临时开发工具（调试用）：按 P 键传送到下一个存档点（按关卡流程顺序，从当前复活点开始）。
## 用途：快速跳关测试关卡各段（走廊 → 环廊 → 迷宫各层存档点）。
## 临时脚本——正式发布请删除本节点（Main.tscn 中名为 DebugTeleport 的节点）与其脚本。

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.physical_keycode != KEY_P:
		return
	var player := get_tree().get_first_node_in_group("Player")
	if player == null:
		return
	var cps : Array = []
	_collect_checkpoints(get_parent(), cps)
	if cps.is_empty():
		return
	# 当前存档点：玩家复活点匹配的存档点（未匹配则从列表开头之前开始，即跳到第一个）
	var spawn : Vector2 = player.get("_spawn_point")
	var idx : int = -1
	for i in cps.size():
		if (cps[i] as Node2D).position.distance_to(spawn) < 10.0:
			idx = i
			break
	var target : Node2D = cps[(idx + 1) % cps.size()]
	player.global_position = target.global_position
	player.velocity = Vector2.ZERO
	var hud := get_tree().get_first_node_in_group("HUD")
	if hud and hud.has_method("show_system_message"):
		hud.show_system_message("[DEBUG] P：传送到存档点 " + target.name)


func _collect_checkpoints(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is Area2D and c.script != null and c.script.resource_path == "res://scripts/Checkpoint.gd":
			out.append(c)
		_collect_checkpoints(c, out)

