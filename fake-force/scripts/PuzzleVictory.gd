extends Node2D
## 解密版胜利演出：白闪 → 哲学文字 → 3秒后返回选关页
## 挂载于 CanvasLayer(layer=100) 下，坐标为视口坐标

var _active : bool = false
var _t : float = 0.0


func _ready() -> void:
	add_to_group("PuzzleVictory")
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func start() -> void:
	if _active:
		return
	_active = true
	visible = true
	_t = 0.0
	get_tree().paused = true


func _process(delta: float) -> void:
	if not _active:
		return
	_t += delta
	queue_redraw()
	if _t >= 3.5:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://LevelSelect.tscn")


func _draw() -> void:
	var vp := get_viewport_rect().size
	var font := ThemeDB.fallback_font
	# 白闪
	if _t < 0.5:
		draw_rect(Rect2(Vector2.ZERO, vp), Color(1.0, 1.0, 1.0, 1.0 - _t / 0.5))
		return
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.0, 0.0, 0.0, 0.88))
	var a : float = clampf((_t - 0.5) * 1.5, 0.0, 1.0)
	draw_string(font, vp * 0.5 + Vector2(-400, 0), \
		"所谓力，不过是参考系中加速度的幻觉。", \
		HORIZONTAL_ALIGNMENT_CENTER, 800, 26, Color(0.85, 0.92, 1.0, a))
	draw_string(font, vp * 0.5 + Vector2(-300, 60), "你过关！", \
		HORIZONTAL_ALIGNMENT_CENTER, 600, 16, Color(0.6, 0.7, 0.8, a))
