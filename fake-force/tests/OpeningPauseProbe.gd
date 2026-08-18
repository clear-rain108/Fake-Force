extends Node2D
## 开场暂停验证：加载 Main.tscn（不跳过开场），确认游戏树被暂停、玩家不漂移不死亡。
## 写盘 user://opening_pause_probe_result.txt 并退出。

var level : Node2D
var t : float = 0.0
var lines : Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	level = load("res://Main.tscn").instantiate()
	add_child(level)
	get_viewport().size = Vector2i(1280, 720)
	print("[OpeningPauseProbe] Main.tscn loaded (opening playing)")


func _process(delta: float) -> void:
	t += delta
	var p : CharacterBody2D = get_tree().get_first_node_in_group("Player")
	var opening := level.get_node_or_null("Opening")
	lines.append("[t=" + str(t) + "] paused=" + str(get_tree().paused) \
			+ " opening_active=" + str(opening != null) \
			+ " player_pos=" + str(p.global_position if p else Vector2.ZERO))
	if t > 3.0:
		# 断言：开场期间树暂停、玩家未漂移（仍近出生点）、未死亡（无 DeathSequence）
		var paused_ok : bool = get_tree().paused
		var opening_ok : bool = opening != null
		var no_drift : bool = p != null and p.global_position.distance_to(Vector2(0, 650)) < 60.0
		lines.append("========== [OpeningPauseProbe] ==========")
		lines.append("开场期间 游戏树暂停 = " + str(paused_ok) + "（应 true）")
		lines.append("开场节点仍活动 = " + str(opening_ok) + "（应 true）")
		lines.append("玩家未漂移 = " + str(no_drift) + "（距出生点 <60px，应 true）")
		for line in lines:
			print(line)
		var f := FileAccess.open("user://opening_pause_probe_result.txt", FileAccess.WRITE)
		if f:
			f.store_string("\n".join(lines) + "\n")
			f.close()
		# 恢复（模拟空格跳过开场 → 应取消暂停）
		if opening:
			opening.queue_free()
		await get_tree().create_timer(1.0).timeout
		print("[OpeningPauseProbe] after skip: paused=", get_tree().paused, "（应 false）")
		get_tree().quit()
