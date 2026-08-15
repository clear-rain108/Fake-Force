extends Node2D
## 老人的记事本（v3.0 叙事核心道具）
##
## 常驻屏幕左下角（位于 HUD 的 CanvasLayer 下，屏幕坐标）。
## - 剧情碎片由物理耦合触发（G值持续、区域事件等），不可简单计时器
## - 条件满足时图标发光，按 F 阅读；再按 F / Esc 关闭并翻至下一页
## - 碎片逐段解锁，不重复

const PAGE_TITLE_COLOR := Color(0.6, 0.9, 1.0)
const PAGE_TEXT_COLOR := Color(0.92, 0.96, 1.0)
const GLOW_COLOR := Color(0.5, 0.85, 1.0)
const PANEL_BG := Color(0.06, 0.08, 0.12, 0.93)
const PANEL_BORDER := Color(0.5, 0.85, 1.0, 0.6)
const PANEL_SIZE := Vector2(520, 200)
const PANEL_OFFSET := Vector2(-PANEL_SIZE.x * 0.5, -PANEL_SIZE.y - 40)

## 剧情碎片表（顺序解锁）。require_g / require_g_time：
## 需要有效幻觉强度持续高于 require_g 达 require_g_time 秒才解锁。
## 也可由 NotebookTrigger 区域进入事件直接解锁（v3.0 约束4 允许）。
var pages : Array = [
	{
		"title": "（第一页）",
		"text": "陨石还在划过大气层，可月球工厂连一刻都不愿多等...",
		"require_g": 1.0,
		"require_g_time": 1.5,
	},
	{
		"title": "（第二页）",
		"text": "我们还是失败了，他们把人运回地球了，连带着我们出师不利的消息。",
		"require_g": 1.0,
		"require_g_time": 1.5,
	},
	{
		"title": "（第三页）",
		"text": "所有人都在看，所有人都在骂，连联合国都通过的那个xx的临时方案。难道，我们真的要在这止步吗...",
		"require_g": 1.0,
		"require_g_time": 1.5,
	},
	{
		"title": "（第四页·黑洞前）",
		"text": "引力是时空告诉物质如何弯曲。虚假力是系统告诉船员如何移动。黑洞是引力把光压回原点。你是系统把记忆压回原点的那个点。",
		"require_g": 0.0,
		"require_g_time": 0.0,
	},
	{
		"title": "（最后一页）",
		"text": "不是逃出去。是跳进去。",
		"require_g": 0.0,
		"require_g_time": 0.0,
	},
]

var unlocked : int = 0       # 已解锁的碎片数
var page_index : int = 0     # 当前阅读位置
var reading : bool = false
var glowing : bool = false

var _g_high_time : float = 0.0
var _font_size : int = 15


func _ready() -> void:
	add_to_group("Notebook")
	# 屏幕左下角（自适应视口高度）
	position = Vector2(24, get_viewport_rect().size.y - 62)


## 由 NotebookTrigger 区域事件调用：解锁前 n 页（可逐页翻看）
func unlock_pages(n: int) -> void:
	unlocked = maxi(unlocked, mini(n, pages.size()))
	_g_high_time = 0.0


func _next_page() -> void:
	if page_index + 1 < unlocked:
		page_index += 1


func _prev_page() -> void:
	if page_index > 0:
		page_index -= 1


func _process(delta: float) -> void:
	_update_unlock(delta)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_F, KEY_ESCAPE:
			if reading:
				_close_page()
			elif glowing and page_index < unlocked:
				reading = true
				AudioManager.play_notebook_reveal()  # 档案解锁拍频音
		KEY_RIGHT, KEY_D:
			if reading:
				_next_page()
		KEY_LEFT, KEY_A:
			if reading:
				_prev_page()


func _update_unlock(delta: float) -> void:
	# 有"已解锁但未读"的碎片 → 持续发光（直到阅读）
	glowing = unlocked > page_index
	if page_index >= pages.size():
		return
	if page_index < unlocked:
		return  # 当前页已解锁，等待阅读
	var p : Dictionary = pages[page_index]
	var g : float = IllusionManager.get_current_effective_g()
	if g > float(p.get("require_g", 0.0)):
		_g_high_time += delta
		if _g_high_time >= float(p.get("require_g_time", 0.0)):
			unlocked += 1
			_g_high_time = 0.0
	else:
		# 匀速间歇等情况下缓慢衰减而非立即清零，避免相位切换瞬间丢失进度
		_g_high_time = maxf(_g_high_time - delta * 2.0, 0.0)


func _close_page() -> void:
	reading = false
	glowing = false
	page_index += 1
	_g_high_time = 0.0


func _draw() -> void:
	var font := ThemeDB.fallback_font
	# 发光提示环
	if glowing and not reading:
		draw_circle(Vector2.ZERO, 34.0, Color(GLOW_COLOR, 0.14))
		draw_circle(Vector2.ZERO, 34.0, Color(GLOW_COLOR, 0.5), false, 1.5)
	# 记事本图标（苍蓝封皮）
	var r := Rect2(Vector2(-18, -14), Vector2(36, 28))
	draw_rect(r, Color(0.32, 0.5, 0.66, 0.95))
	draw_rect(r, Color(0.7, 0.9, 1.0), false, 2.0)
	draw_line(Vector2(-2, -14), Vector2(-2, 14), Color(0.7, 0.9, 1.0, 0.6), 1.0)
	# 提示文字
	if glowing and not reading:
		draw_string(font, Vector2(-24, 44), "按 F 阅读", \
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.8, 0.95, 1.0))
	# 阅读面板：视口居中（保证完整落在屏幕范围内）
	if reading and page_index < pages.size():
		var p : Dictionary = pages[page_index]
		var vp := get_viewport_rect().size
		var panel_origin : Vector2 = (vp - PANEL_SIZE) * 0.5 - position
		draw_rect(Rect2(panel_origin, PANEL_SIZE), PANEL_BG)
		draw_rect(Rect2(panel_origin, PANEL_SIZE), PANEL_BORDER, false, 2.0)
		var title : String = String(p.get("title", ""))
		draw_string(font, panel_origin + Vector2(20, 40), title, \
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20, PAGE_TITLE_COLOR)
		var lines : PackedStringArray = _wrap_text(String(p.get("text", "")), 30)
		for i in lines.size():
			draw_string(font, panel_origin + Vector2(20, 92 + i * 27), lines[i], \
				HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, PAGE_TEXT_COLOR)
		draw_string(font, panel_origin + Vector2(20, PANEL_SIZE.y - 18), "← → 翻页 ｜ F / Esc 关闭", \
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.6, 0.7, 0.8))


## 折行（支持 \n 分段）
func _wrap_text(text: String, chars_per_line: int) -> PackedStringArray:
	var out := PackedStringArray()
	for para in text.split("\n"):
		var line := ""
		for ch in para:
			line += ch
			if line.length() >= chars_per_line:
				out.append(line)
				line = ""
		if line.length() > 0:
			out.append(line)
	return out
