extends Node2D
## 探测三首背景音乐的时长与循环设置，并验证 background.tscn 运行时强制循环，
## 写盘 user://audio_dur_probe.txt 并退出。

func _ready() -> void:
	var lines : Array[String] = []
	for path in ["res://The thinking of star.ogg", "res://LOOP1sp.test.ogg", "res://Out of the spaxe.ogg"]:
		if ResourceLoader.exists(path):
			var s : AudioStream = load(path)
			var loop_str : String = "n/a"
			if s is AudioStreamOggVorbis:
				loop_str = str((s as AudioStreamOggVorbis).loop)
			lines.append(path + " -> get_length()=" + str(s.get_length()) + " loop=" + loop_str)
		else:
			lines.append(path + " -> 不存在")
	# 关卡背景音乐运行时强制循环验证：实例化 background.tscn，_ready 中应把 Music.stream.loop 置 true
	var bg : Node = load("res://scenes/background.tscn").instantiate()
	add_child(bg)
	var m : AudioStreamPlayer = bg.get_node_or_null("Music") as AudioStreamPlayer
	if m and m.stream is AudioStreamOggVorbis:
		lines.append("[runtime] background.tscn Music.stream.loop = " + str((m.stream as AudioStreamOggVorbis).loop))
	else:
		lines.append("[runtime] background.tscn 未找到 Music 节点或流类型不符")
	for line in lines:
		print(line)
	var f := FileAccess.open("user://audio_dur_probe.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lines) + "\n")
		f.close()
	# 停留片刻让调试输出可被捕获，然后退出
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()