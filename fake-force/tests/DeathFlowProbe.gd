extends Node2D
## 死亡演出结束 → 回开始页 流程探针
## 加载真实 Main.tscn（跳过开场），强制死亡，监控死亡演出结束后能否切到 MainMenu。
## 写盘 user://death_flow_probe_result.txt（每阶段追加）。

var level : Node2D
var t : float = 0.0
var triggered : bool = false
var f : FileAccess = null


func _log(msg: String) -> void:
	print("[DeathFlowProbe] " + msg)
	if f:
		f.store_line(msg)
		f.flush()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	f = FileAccess.open("user://death_flow_probe_result.txt", FileAccess.WRITE)
	level = load("res://Main.tscn").instantiate()
	add_child(level)
	var opening := level.get_node_or_null("Opening")
	if opening:
		opening.queue_free()
	get_viewport().size = Vector2i(1280, 720)
	_log("Main.tscn loaded, opening skipped")


func _process(delta: float) -> void:
	t += delta
	if not triggered and t > 1.0:
		triggered = true
		var p : CharacterBody2D = get_tree().get_first_node_in_group("Player")
		if p:
			p.fall_count = p.max_falls + 1
			p._on_fallen()
			_log("death triggered at t=" + str(t))
	# 死亡演出 _t 推进采样
	var seq : Node = null
	for child in level.get_children():
		if child is CanvasLayer:
			for sub in child.get_children():
				if sub.get_script() and sub.get_script().resource_path.contains("DeathSequence"):
					seq = sub
	if seq and int(t * 10.0) % 30 == 0:
		_log("death seq _t=" + str(seq._t))
	if t > 34.0:
		_log("probe still alive at t=34 (death seq should have finished at ~29.8s)")
		_log("CURRENT_SCENE=" + (get_tree().current_scene.scene_file_path if get_tree().current_scene else "null"))
