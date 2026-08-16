extends CanvasLayer
## 暂停菜单：Esc 开/关；含 继续游戏 / 返回主菜单 / 退出游戏
## 挂载于关卡根节点；process_mode=ALWAYS 使暂停时仍可交互

var _open : bool = false
var _panel : Control = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			if _open:
				resume()
			else:
				pause()


func pause() -> void:
	if _open:
		return
	_open = true
	get_tree().paused = true
	_panel.visible = true


func resume() -> void:
	_open = false
	get_tree().paused = false
	_panel.visible = false


func _to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://MainMenu.tscn")


func _quit() -> void:
	get_tree().quit()


func _build_ui() -> void:
	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.visible = false
	add_child(_panel)

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(bg)

	var box := VBoxContainer.new()
	box.anchor_left = 0.5
	box.anchor_top = 0.5
	box.anchor_right = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = -130.0
	box.offset_top = -240.0
	box.offset_right = 130.0
	box.offset_bottom = 240.0
	box.add_theme_constant_override("separation", 22)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(box)

	var title := Label.new()
	title.text = "—— 暂停 ——"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	box.add_child(title)

	var resume_btn := _make_button("继续游戏")
	resume_btn.pressed.connect(resume)
	box.add_child(resume_btn)

	var menu_btn := _make_button("返回主菜单")
	menu_btn.pressed.connect(_to_menu)
	box.add_child(menu_btn)

	var quit_btn := _make_button("退出游戏")
	quit_btn.pressed.connect(_quit)
	box.add_child(quit_btn)

	# —— 音量控制（音乐 / 游戏内音效） ——
	var music_lbl := Label.new()
	music_lbl.text = "音乐音量"
	music_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	music_lbl.add_theme_font_size_override("font_size", 16)
	box.add_child(music_lbl)

	var music_slider := HSlider.new()
	music_slider.min_value = 0.0
	music_slider.max_value = 1.0
	music_slider.step = 0.05
	music_slider.custom_minimum_size = Vector2(210, 0)
	music_slider.value = AudioManager.music_volume
	music_slider.value_changed.connect(func(v: float) -> void: AudioManager.set_music_volume(v))
	box.add_child(music_slider)

	var sfx_lbl := Label.new()
	sfx_lbl.text = "音效音量"
	sfx_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sfx_lbl.add_theme_font_size_override("font_size", 16)
	box.add_child(sfx_lbl)

	var sfx_slider := HSlider.new()
	sfx_slider.min_value = 0.0
	sfx_slider.max_value = 1.0
	sfx_slider.step = 0.05
	sfx_slider.custom_minimum_size = Vector2(210, 0)
	sfx_slider.value = AudioManager.sfx_volume
	sfx_slider.value_changed.connect(func(v: float) -> void: AudioManager.set_sfx_volume(v))
	box.add_child(sfx_slider)


func _make_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(200, 50)
	return btn
