extends Node2D
## 探测结局背景音乐 "The thinking of star.ogg" 的时长，写盘 user://audio_dur_probe.txt 并退出。

func _ready() -> void:
	var lines : Array[String] = []
	for path in ["res://The thinking of star.ogg", "res://LOOP1sp.test.ogg", "res://Out of the spaxe.ogg"]:
		if ResourceLoader.exists(path):
			var s : AudioStream = load(path)
			lines.append(path + " -> get_length()=" + str(s.get_length()))
		else:
			lines.append(path + " -> 不存在")
	for line in lines:
		print(line)
	var f := FileAccess.open("user://audio_dur_probe.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lines) + "\n")
		f.close()
	get_tree().quit()