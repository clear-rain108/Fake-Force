extends Node2D
## 初始位置安全性验证：
## 跳过开场（取消暂停）后，玩家被 Stage1Zone(G=0.6) 推力向左漂移，
## 应被 RoomWallLeft(x=0) 挡住而不坠出走廊死亡。
## 写盘 user://spawn_safety_probe_result.txt 并退出。

var level : Node2D
var t : float = 0.0
var skipped : bool = false
var min_x : float = 1e9
var alive : bool = true
var lines : Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	level = load("res://Main.tscn").instantiate()
	add_child(level)
	get_viewport().size = Vector2i(1280, 720)


func _process(delta: float) -> void:
	t += delta
	var p : CharacterBody2D = get_tree().get_first_node_in_group("Player")
	if p:
		min_x = minf(min_x, p.global_position.x)
		if p.global_position.y > p.kill_y:
			alive = false
	if not skipped and t > 1.0:
		skipped = true
		var opening := level.get_node_or_null("Opening")
		if opening:
			opening.queue_free()   # 取消暂停，游戏开始，玩家受 G 推力
		lines.append("[skip] 开场已跳过（游戏恢复，玩家开始受推力）")
	if skipped and t > 6.0:
		lines.append("========== [SpawnSafetyProbe] ==========")
		var wall_ok : bool = level.get_node_or_null("RoomWallLeft") != null
		var left_blocked : bool = alive and min_x >= -5.0
		lines.append("RoomWallLeft 存在 = " + str(wall_ok))
		lines.append("玩家存活 = " + str(alive) + "（应 true）")
		lines.append("玩家最小 x = " + str(min_x) + "（应 >= -5：被左墙挡住）")
		for line in lines:
			print(line)
		var f := FileAccess.open("user://spawn_safety_probe_result.txt", FileAccess.WRITE)
		if f:
			f.store_string("\n".join(lines) + "\n")
			f.close()
		get_tree().quit()
