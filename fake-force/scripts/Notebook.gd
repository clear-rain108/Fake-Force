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
## 阶段2 迷宫剧情为第 4~7 页（由 L2~L5 剧情触发区按 F 解锁）。
var pages : Array = [
	{
		"title": "（第一页）",
		"text": "陨石还在划过大气层，可月球工厂连一刻都不愿多等...",
		"require_g": 1.0,
		"require_g_time": 1.5,
	},
	{
		"title": "（第二页）",
		"text": "我们失败了，他们把人运回地球了，连带着我们出师不利的消息。",
		"require_g": 1.0,
		"require_g_time": 1.5,
	},
	{
		"title": "（第三页）",
		"text": "所有人都在看，所有人都在骂，连联合国都通过的那个沟槽的临时方案。难道，我们真的要在这止步吗...",
		"require_g": 1.0,
		"require_g_time": 1.5,
	},
	{
		"title": "（第四页·异常状况其一）",
		"text": "【异常状况收录】其一：部分操作员出现特殊记忆，如梦见自己成为资本巨鳄等。\n为保证稳定，已自动启动强制休眠",
		"require_g": 0.0,
		"require_g_time": 0.0,
	},
	{
		"title": "（第五页·异常状况其二）",
		"text": "【异常状况收录】其二：有多名船员反馈“出现噩梦，看见自己同飞船冲向陨石群。”申请全员记忆重启。\n状态：被否决。",
		"require_g": 0.0,
		"require_g_time": 0.0,
	},
	{
		"title": "（第六页·航路图）",
		"text": "一本记事本，其中有一些潦草的笔记，且在航路图上画有两个方向。\n第一条：从地外轨道指向近地轨道，标注“梦”。\n第二条：从地外轨道指向太阳系外，经由木星加速。",
		"require_g": 0.0,
		"require_g_time": 0.0,
	},
	{
		"title": "（第七页·凡·赫特克·上）",
		"text": "一段来自凡·赫特克的语音：\n“很抱歉把你们带上这条不归路。可是，谁能面对人类的存亡，苦痛，大我的消失而置之不理呢？",
		"require_g": 0.0,
		"require_g_time": 0.0,
	},
	{
		"title": "（第八页·凡·赫特克·下）",
		"text": "可能未来，人们会把我们从穹顶上取回来。但在那之前，请现在的我们不要停止设想未来，请未来的我们不要停止回望过去。”",
		"require_g": 0.0,
		"require_g_time": 0.0,
	},
]

var unlocked : int = 0       # 已解锁的碎片数
var page_index : int = 0     # 当前阅读位置
var reading : bool = false
var glowing : bool = false

var _g_high_time : float = 0.0
var _font_size : int = 16
var _font : Font = null
var _floating_text : String = ""
var _float_time : float = 0.0


func _ready() -> void:
	add_to_group("Notebook")
	process_mode = Node.PROCESS_MODE_ALWAYS   # 阅读时游戏暂停，记事本仍需响应输入
	# 跨场景持久化解锁进度（阶段2→阶段3 切换后仍可阅读已解锁页）
	unlocked = IllusionManager.notebook_unlocked
	# 屏幕左下角（自适应视口高度）
	position = Vector2(24, get_viewport_rect().size.y - 62)


## 由 NotebookTrigger 区域事件调用：解锁前 n 页（可逐页翻看）
func unlock_pages(n: int) -> void:
	unlocked = maxi(unlocked, mini(n, pages.size()))
	IllusionManager.notebook_unlocked = unlocked
	_g_high_time = 0.0


## 由剧情触发区调用：解锁到指定页（按顺序解锁前 n 页；与 unlock_pages 一致，语义为"解锁第 n 页"）
func unlock_page(n: int) -> void:
	unlock_pages(n)


## 剧情触发区：解锁第 n 页并直接翻开该页（一次 F 即可阅读到新碎片）
func reveal_page(n: int) -> void:
	unlock_pages(n)
	if page_index < unlocked:
		page_index = mini(unlocked - 1, pages.size() - 1)   # 直接定位到最新解锁页
		reading = true
		get_tree().paused = true
		AudioManager.play_notebook_reveal()


## 显示悬浮提示（剧情触发区调用，如"📖 按 F 阅读档案碎片"）；duration<=0 时清除
func show_floating_text(text: String, duration: float = 5.0) -> void:
	_floating_text = text
	_float_time = duration if duration > 0.0 else 0.0
	queue_redraw()


func _next_page() -> void:
	if page_index + 1 < unlocked:
		page_index += 1


func _prev_page() -> void:
	if page_index > 0:
		page_index -= 1


func _process(delta: float) -> void:
	_update_unlock(delta)
	if _float_time > 0.0:
		_float_time -= delta
		if _float_time <= 0.0:
			_floating_text = ""
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_F:
			if reading:
				_close_page()
			elif glowing and page_index < unlocked and not get_tree().paused:
				reading = true
				get_tree().paused = true   # 阅读时暂停游戏（记事本 PROCESS_MODE_ALWAYS）
				AudioManager.play_notebook_reveal()  # 档案解锁拍频音
		KEY_RIGHT, KEY_D:
			if reading:
				_next_page()
		KEY_LEFT, KEY_A:
			if reading:
				_prev_page()


func _update_unlock(_delta: float) -> void:
	# 有"已解锁但未读"的碎片 → 持续发光（直到阅读）
	glowing = unlocked > page_index
	if page_index >= pages.size():
		return
	if page_index < unlocked:
		return  # 当前页已解锁，等待阅读
	# —— 事件驱动解锁（v3.0 约束4：由物理/区域事件触发，非计时器）——
	var player := get_tree().get_first_node_in_group("Player")
	# 第1页：阶段1 收集第一枚马赫尘埃（老人数据碎片）
	if unlocked < 1 and is_instance_valid(player) and player.dust_collected >= 1:
		unlock_pages(1)
	# 第3页：阶段2 穿越多个加速度场 + 完成旋转参考系同步
	if unlocked < 3 and is_instance_valid(player) \
			and IllusionManager.zone_count >= 3 and player.rot_switch_count >= 1:
		unlock_pages(3)


func _close_page() -> void:
	reading = false
	glowing = false
	page_index += 1
	get_tree().paused = false   # 关闭阅读恢复游戏
	_g_high_time = 0.0


func _draw() -> void:
	var font : Font = _font
	if font == null:
		font = load("res://fusion-pixel.ttf")
		_font = font
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
	# 剧情触发区悬浮提示（如"📖 按 F 阅读档案碎片"）
	if not _floating_text.is_empty():
		draw_string(font, Vector2(-24, -34), _floating_text, \
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.95, 0.85, 0.6))
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
		draw_string(font, panel_origin + Vector2(20, PANEL_SIZE.y - 18), "← → 翻页 ｜ F 关闭", \
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
