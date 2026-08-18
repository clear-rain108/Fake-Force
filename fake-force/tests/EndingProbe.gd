extends Node2D
## 结局演出验证（v3.7）：加载真实 Stage3，触发 start_ending，确认结局背景音乐
## "The thinking of star.ogg" 播放（Music 总线、关卡背景音乐停止）、时间轴按音乐时长
## 等比缩放（演出结束 = 音乐结束）、感谢字幕阶段与自动退出。
## 写盘 user://ending_probe_result.txt。

var level : Node2D
var t : float = 0.0
var started : bool = false
var stage1_done : bool = false
var ending : Node = null
var lines : Array[String] = []
var stage1_pass : bool = false
var aligned : bool = false
var thanks_seen : bool = false
var self_quit : bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	level = load("res://scenes/Stage3.tscn").instantiate()
	add_child(level)
	get_viewport().size = Vector2i(1280, 720)


func _process(delta: float) -> void:
	t += delta
	if not started and t > 1.0:
		started = true
		ending = get_tree().get_first_node_in_group("Ending")
		if ending:
			ending.start_ending()
			lines.append("[start] ending.start_ending() 已调用，t=" + str(t))
	# 阶段1：进入逐段文字阶段后检查（TEXT_START 已按音乐时长缩放，~11.2s）
	if started and not stage1_done and ending and ending._active \
			and ending._t >= ending.TEXT_START + 0.5:
		stage1_done = true
		var music_bus : int = AudioServer.get_bus_index("Music")
		var music_muted : bool = music_bus >= 0 and AudioServer.is_bus_mute(music_bus)
		var m : AudioStreamPlayer = ending._music if ending else null
		lines.append("[check] ending active=" + str(ending._active) \
				+ " _t=" + str(ending._t) + " paused=" + str(get_tree().paused))
		lines.append("[check] SEGMENTS.size=" + str(ending.SEGMENTS.size()))
		lines.append("[check] 音乐总线静音 = " + str(music_muted) + "（应 false：结局曲占 Music 总线）")
		lines.append("[check] 结局曲 length=" + str(ending._music_length if ending else -1.0) \
				+ "（The thinking of star ≈110.55s）")
		aligned = ending != null and absf(ending._narration_end_time() + ending.THANKS_DURATION \
				- ending._music_length) < 0.05
		lines.append("[check] 时间轴对齐：narration_end=" + str(ending._narration_end_time()) \
				+ " THANKS=" + str(ending.THANKS_DURATION) \
				+ " 演出总长=" + str(ending._narration_end_time() + ending.THANKS_DURATION) \
				+ " ≈ 音乐长=" + str(ending._music_length) \
				+ " → " + ("PASS" if aligned else "FAIL"))
		var stage_music : AudioStreamPlayer = ending._find_music_player(level)
		lines.append("[check] 关卡背景音乐已停止 = " + str(not stage_music.is_playing() if stage_music else false))
		lines.append("[check] 结局曲已播放 = " + str(m.is_playing() if m else false))
		stage1_pass = ending != null and ending._active and ending._t > ending.TEXT_START \
				and not music_muted and aligned and m != null and m.is_playing() \
				and stage_music != null and not stage_music.is_playing()
		lines.append("========== [EndingProbe] ==========")
		lines.append("结局演出进入文字阶段 = " + ("PASS" if stage1_pass else "FAIL"))
		lines.append("结局背景音乐播放（关卡曲停止） = " + ("PASS" if stage1_pass else "FAIL"))
		lines.append("演出时间对齐音乐时长 = " + ("PASS" if aligned else "FAIL"))
		_write()
	# 感谢字幕阶段：旁白播完后（narration_end，~101.3s）应进入致谢字幕
	if started and ending and not thanks_seen \
			and ending._t >= ending._narration_end_time() + 1.0:
		thanks_seen = true
		lines.append("[check] 感谢字幕阶段：_t=" + str(ending._t) \
				+ " ≥ narration_end=" + str(ending._narration_end_time()))
	# 兜底：120s 仍未自动退出则判失败（音乐 110.55s + 探针 1s 启动）
	if started and t > 120.0:
		self_quit = true
		lines.append("感谢字幕进入 = " + ("PASS" if thanks_seen else "FAIL"))
		lines.append("结局自动退出 = FAIL（120s 内未自动退出）")
		_write()
		get_tree().quit()


func _write() -> void:
	for line in lines:
		print(line)
	var f := FileAccess.open("user://ending_probe_result.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lines) + "\n")
		f.close()


func _exit_tree() -> void:
	# 探针从未主动退出却走到了这里 → 结局在致谢后自动结束了游戏
	if stage1_done and not self_quit:
		lines.append("感谢字幕进入 = " + ("PASS" if thanks_seen else "FAIL"))
		lines.append("结局自动退出 = PASS（游戏在致谢字幕结束后自行退出，对齐音乐结尾）")
		_write()
