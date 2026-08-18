extends Node2D
## 结局演出（v3.7：以 "The thinking of star" 为背景音乐，演出时间按音乐时长等比缩放对齐）
##
## 时间轴（设计总长 54.2s，运行时按音乐实际时长等比缩放 k=音乐长/54.2）：
##   白闪 → 黑洞特写（旋转光晕+吸积粒子）→ 角色滑入黑洞 → 老人遗言（黑洞在底）
##   → 遗言结束黑洞消失 → 黑屏 → 旁白逐段（黑屏）→ 致谢字幕 → 音乐结束同时自动退出。
## 不再绘制老人面孔；不再显示"Demo 结束"；结局背景音乐 = The thinking of star.ogg（Music 总线）。
## 挂载于 CanvasLayer(layer=100) 下，坐标为视口坐标。

const MUSIC_PATH : String = "res://The thinking of star.ogg"

# —— 设计时间轴（设计总长 54.2s），运行时按音乐时长等比缩放 ——
const WHITE_FLASH_D : float = 1.5        # 屏幕白闪（设计秒）
const SHIP_START_D : float = 2.0         # 角色光点滑入起点
const SHIP_END_D : float = 5.5           # 滑入结束 / 遗言起点
const TEXT_START_D : float = 5.5         # 老人遗言起点
const SEG_DURATION_D : float = 3.6       # 每段时长
const FADE_TIME_D : float = 0.9          # 每段淡入淡出
const OLD_MAN_COUNT : int = 4            # 前 4 段为老人遗言（期间显示黑洞）
const GAP_TIME_D : float = 1.0           # 遗言结束后黑屏间隔（秒）
const THANKS_TEXT : String = "感谢游玩《Fake Forces 善假于物》"   # 通关致谢字幕
const THANKS_DURATION_D : float = 4.5    # 致谢字幕停留时长（含淡入淡出），随后自动退出

# —— 运行时时间轴（start_ending 时按 _music_length 等比缩放；默认=设计值）——
var WHITE_FLASH : float = WHITE_FLASH_D
var SHIP_START : float = SHIP_START_D
var SHIP_END : float = SHIP_END_D
var TEXT_START : float = TEXT_START_D
var SEG_DURATION : float = SEG_DURATION_D
var FADE_TIME : float = FADE_TIME_D
var GAP_TIME : float = GAP_TIME_D
var THANKS_DURATION : float = THANKS_DURATION_D

## 每项为一个数组（段内多行）；以“ ”开头的段为老人遗言（暖色）
const SEGMENTS : Array = [
	["“该说些什么呢，呵呵...”"],
	["“恭喜你，小伙子，你看见了我留下的记号，", "来到了这里，看到了‘真相’”"],
	["“你究竟是谁呢？我的同僚，还是，我曾经的敌人？”"],
	["“不过这些都已无关紧要了。”"],
	["一位老人，被流放亦是流放之人，", "带领一群孩童来到一片蛮荒之地"],
	["他教会他们驻营，生火，留下生存的必须技能，", "随后用最无情的死亡——继续放逐来耗尽他的生命"],
	["或许会有一天，人们会找到他们"],
	["但这与他们已经无关。"],
	["可那又如何？"],
	["对于流放者而言，那些孩子并不重要，", "因为他确信后来者能在那星空的驱引下，", "用尸骸与人力开辟这片荒原"],
	["对于孩子们而言，流放者也不重要，", "因为所谓引路之人，早已是不可及之人。"],
	["所谓使命，也只不过是那参考系中的幻影。"],
]

var _active : bool = false
var _t : float = 0.0
var _quit_triggered : bool = false
var _font : Font = null
var _music : AudioStreamPlayer = null
var _music_length : float = 0.0


func _ready() -> void:
	add_to_group("Ending")
	# 树暂停（start_ending 会 get_tree().paused = true）时结局仍要播放与响应输入
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	# 结局背景音乐：The thinking of star.ogg（Music 总线），暂停期间照常播放
	_music = AudioStreamPlayer.new()
	_music.name = "EndingMusic"
	_music.stream = load(MUSIC_PATH)
	_music.bus = "Music"
	_music.process_mode = Node.PROCESS_MODE_ALWAYS
	_music.volume_db = -6.0   # 与关卡背景音乐默认音量一致
	add_child(_music)
	_music_length = _music.stream.get_length()


func start_ending() -> void:
	if _active:
		return
	_active = true
	visible = true
	_t = 0.0
	_quit_triggered = false
	Engine.time_scale = 1.0   # 玩家可能在洞察(0.2x)中通关：复位全局时间
	get_tree().paused = true
	_apply_music_timing()     # 时间轴按音乐时长等比缩放：演出结束=音乐结束
	_stop_stage_music()       # 停止关卡背景音乐（同 Music 总线），换结局曲
	_music.play()


## 将整个演出时间轴等比缩放到音乐时长：自动退出时刻 = 音乐结束时刻
func _apply_music_timing() -> void:
	var design_total : float = TEXT_START_D + float(OLD_MAN_COUNT) * SEG_DURATION_D + GAP_TIME_D \
			+ float(SEGMENTS.size() - OLD_MAN_COUNT) * SEG_DURATION_D + THANKS_DURATION_D
	var k : float = _music_length / design_total if _music_length > 0.0 else 1.0
	WHITE_FLASH = WHITE_FLASH_D * k
	SHIP_START = SHIP_START_D * k
	SHIP_END = SHIP_END_D * k
	TEXT_START = TEXT_START_D * k
	SEG_DURATION = SEG_DURATION_D * k
	FADE_TIME = FADE_TIME_D * k
	GAP_TIME = GAP_TIME_D * k
	THANKS_DURATION = THANKS_DURATION_D * k


## 停止关卡背景音乐节点（background.tscn 的 Music，占同一 Music 总线）
func _stop_stage_music() -> void:
	var scene : Node = get_tree().current_scene
	if scene:
		var m : AudioStreamPlayer = _find_music_player(scene)
		if m:
			m.stop()


func _find_music_player(n: Node) -> AudioStreamPlayer:
	if n is AudioStreamPlayer and n.name == "Music":
		return n
	for c in n.get_children():
		var r : AudioStreamPlayer = _find_music_player(c)
		if r:
			return r
	return null


func _process(delta: float) -> void:
	if not _active:
		return
	_t += delta
	# 旁白播完后（感谢字幕停留结束）自动结束游戏
	if _t >= _narration_end_time() + THANKS_DURATION and not _quit_triggered:
		_quit_triggered = true
		get_tree().paused = false
		get_tree().quit()
	queue_redraw()


## 旁白（非老人遗言段）结束的全局时刻
func _narration_end_time() -> float:
	return TEXT_START + float(OLD_MAN_COUNT) * SEG_DURATION + GAP_TIME \
		+ float(SEGMENTS.size() - OLD_MAN_COUNT) * SEG_DURATION


func _unhandled_input(event: InputEvent) -> void:
	if _active and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			get_tree().paused = false
			get_tree().quit()


func _draw() -> void:
	var vp := get_viewport_rect().size
	var font : Font = _font
	if font == null:
		font = load("res://fusion-pixel.ttf")
		_font = font
	var center : Vector2 = vp * 0.5
	# 黑底
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.0, 0.0, 0.0))
	# 0~1.5s 屏幕白闪
	if _t < WHITE_FLASH:
		draw_rect(Rect2(Vector2.ZERO, vp), Color(1.0, 1.0, 1.0, 1.0 - _t / WHITE_FLASH))

	# 黑洞：仅在老人遗言阶段及之前显示；遗言结束后不再绘制（黑屏）
	var old_man_end : float = TEXT_START + float(OLD_MAN_COUNT) * SEG_DURATION
	if _t < old_man_end:
		var pulse : float = 0.5 + 0.5 * sin(_t * 0.7)
		var radius : float = 80.0 + pulse * 16.0
		draw_circle(center, radius, Color(0.02, 0.03, 0.06))
		var glow : float = radius + 40.0 + pulse * 24.0
		draw_arc(center, glow, 0.0, TAU, 64, Color(0.4, 0.72, 1.0, 0.45), 3.0)
		var arc_start : float = _t * 0.8
		draw_arc(center, glow, arc_start, arc_start + 0.7, 64, Color(0.7, 0.9, 1.0, 0.85), 4.0)
		for i in 6:
			var a : float = _t * 1.2 + TAU * float(i) / 6.0
			var r2 : float = glow + 26.0 + 14.0 * sin(_t * 0.5 + float(i))
			draw_circle(center + Vector2.from_angle(a) * r2, 3.0, Color(0.8, 0.95, 1.0, 0.7))

	# 2~5.5s：角色（光点）滑入黑洞
	if _t >= SHIP_START and _t < SHIP_END:
		var k : float = (_t - SHIP_START) / (SHIP_END - SHIP_START)
		var ship : Vector2 = center + Vector2(320.0 * (1.0 - k), 60.0 - 60.0 * k)
		var ship_r : float = 12.0 * (1.0 - k * 0.8)
		draw_circle(ship, ship_r, Color(0.85, 0.95, 1.0, 1.0 - k * 0.6))
		draw_line(ship, center, Color(0.5, 0.8, 1.0, 0.3 * (1.0 - k)), 1.0)

	# 5.5s~：逐段文字（老人遗言段=黑洞在底；遗言结束后黑屏 1s 再播旁白）
	if _t >= TEXT_START:
		var seg_t : float = _t - TEXT_START
		var old_man_total : float = float(OLD_MAN_COUNT) * SEG_DURATION
		var idx : int = -1
		var local : float = 0.0
		if seg_t < old_man_total:
			idx = int(seg_t / SEG_DURATION)
			local = seg_t - float(idx) * SEG_DURATION
		elif seg_t >= old_man_total + GAP_TIME:
			idx = OLD_MAN_COUNT + int((seg_t - old_man_total - GAP_TIME) / SEG_DURATION)
			local = seg_t - old_man_total - GAP_TIME - float(idx - OLD_MAN_COUNT) * SEG_DURATION
		if idx >= 0 and idx < SEGMENTS.size():
			var alpha : float = clampf(local / FADE_TIME, 0.0, 1.0) * clampf((SEG_DURATION - local) / FADE_TIME, 0.0, 1.0)
			var lines : Array = SEGMENTS[idx]
			var is_old_man : bool = idx < OLD_MAN_COUNT
			var col : Color = Color(0.95, 0.9, 0.78, alpha) if is_old_man else Color(0.9, 0.95, 1.0, alpha)
			var start_y : float = -18.0 * float(lines.size() - 1)
			for i in lines.size():
				draw_string(font, center + Vector2(-400, start_y + float(i) * 34.0), String(lines[i]),
					HORIZONTAL_ALIGNMENT_CENTER, 800, 24, col)
		# 旁白结束后：感谢游玩字幕（停留 THANKS_DURATION 后自动退出）
		var narration_end : float = _narration_end_time()
		if _t >= narration_end:
			var thanks_t : float = _t - narration_end
			var talpha : float = clampf(thanks_t / FADE_TIME, 0.0, 1.0) \
					* clampf((THANKS_DURATION - thanks_t) / FADE_TIME, 0.0, 1.0)
			if talpha > 0.001:
				draw_string(font, center + Vector2(-360, 0), THANKS_TEXT,
					HORIZONTAL_ALIGNMENT_CENTER, 720, 28, Color(0.9, 0.95, 1.0, talpha))


