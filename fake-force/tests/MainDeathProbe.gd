extends Node2D
## Main.tscn 真实剧情场景 死亡演出验证探针
## 跳过开场 → 把玩家置到 kill_y 之下触发坠落，凑满 max_falls+1 → 验证：
##   1) failed=true、DeathSequence 层挂载
##   2) DeathSequence._t 随时间推进（process 在跑 → 会渲染黑屏+文字）
## 写盘 user://main_death_probe_result.txt 并退出。

const DeathScript := preload("res://scripts/DeathSequence.gd")

var level : Node2D
var t : float = 0.0
var phase : int = 0
var phase_t : float = 0.0
var seq_ref : Node2D = null
var t0_seq : float = -1.0
var lines : Array[String] = []


func _ready() -> void:
	level = load("res://Main.tscn").instantiate()
	add_child(level)
	# 跳过开场动画（31s 太慢）
	var opening := level.get_node_or_null("Opening")
	if opening:
		opening.queue_free()
	get_viewport().size = Vector2i(1280, 720)
	print("[MainDeathProbe] Main.tscn loaded")


func _process(delta: float) -> void:
	t += delta
	phase_t += delta
	var player : CharacterBody2D = get_tree().get_first_node_in_group("Player")
	if player == null:
		return
	match phase:
		0:  # 等待场景稳定
			if phase_t > 1.0:
				lines.append("[phase0] player pos=" + str(player.global_position) + " game_mode=" + IllusionManager.game_mode + " rot_state=" + str(player.rot_state))
				player.fall_count = player.max_falls   # 下一次坠落即失败
				player.global_position = Vector2(player.global_position.x, 2000.0)  # 低于 kill_y=800
				phase = 1
				phase_t = 0.0
		1:  # 等待物理帧处理坠落 → _on_fallen → failed + DeathSequence
			if phase_t > 0.6:
				lines.append("[phase1] fall_count=" + str(player.fall_count) + " failed=" + str(player.failed))
				for child in get_children():   # DeathSequence 挂到 current_scene（探针根）下
					if child is CanvasLayer:
						for sub in child.get_children():
							if sub.get_script() == DeathScript:
								seq_ref = sub
				lines.append("[phase1] DeathSequence挂载=" + str(seq_ref != null))
				if seq_ref:
					t0_seq = seq_ref._t
				phase = 2
				phase_t = 0.0
		2:  # 验证 _t 推进（process 在跑）
			if phase_t > 0.6:
				if seq_ref:
					lines.append("[phase2] seq._t " + str(t0_seq) + " → " + str(seq_ref._t) + "（Δ=" + str(seq_ref._t - t0_seq) + "，应≈0.6）")
				phase = 3
				phase_t = 0.0
		3:
			_print_result()
			get_tree().quit()


func _print_result() -> void:
	var ok : bool = seq_ref != null and seq_ref._t > t0_seq + 0.2
	lines.append("========== [MainDeathProbe] ==========")
	lines.append("总评：" + ("全部 PASS ✓" if ok else "存在 FAIL ✗"))
	for line in lines:
		print(line)
	var f := FileAccess.open("user://main_death_probe_result.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lines) + "\n")
		f.close()
