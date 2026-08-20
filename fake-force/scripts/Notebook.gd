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
const PANEL_SIZE := Vector2(520, 280)
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
	{
		"title": "（第九页）",
		"text": "当光也学会了停留，曾经就不再是遥不可及，而是触手可及",
		"require_g": 0.0,
		"require_g_time": 0.0,
	},
	{
		"title": "（第十页）",
		"text": "我们总是期盼让过去重新显现，但那只是幻觉，是加速度的幻觉\n在加速中，你看到了那颗蓝色的星球--地球\n请将时间校准。",
		"require_g": 0.0,
		"require_g_time": 0.0,
	},
	{
		"title": "（第十一页）",
		"text": "引力把时空弯成了不可思议的形状，光在汇聚，又像是在远离\n一段录音：\n--所以，你真的要这么干？催眠所有人，然后离开地球？\n--月卫的人，我会让他们自行选择的，离开，或是加入这场疯狂的计划。\n--至于那群富豪——那是他们应出的代价。",
		"require_g": 0.0,
		"require_g_time": 0.0,
	},
	{
		"title": "（第十二页）",
		"text": "不是逃出去，是跳进去。",
		"require_g": 0.0,
		"require_g_time": 0.0,
	},
]

var unlocked : int = 0       # 已解锁的碎片数（各页独立解锁，互不连带）
var page_index : int = 0     # 当前阅读位置
var reading : bool = false
var glowing : bool = false

var _page_unlocked : Array[bool] = []   # 逐页解锁标记（非连续：每处剧情只解锁本处对应页）
var _page_read : Array[bool] = []       # 逐页已读标记（仅本次场景内）

var _g_high_time : float = 0.0
var _font_size : int = 16
var _font : Font = null
var _floating_text : String = ""
var _float_time : float = 0.0


func _ready() -> void:
	add_to_group("Notebook")
	process_mode = Node.PROCESS_MODE_ALWAYS   # 阅读时游戏暂停，记事本仍需响应输入
	# 逐页解锁状态（跨场景持久：位掩码 notebook_unlocked_mask）
	_page_unlocked.resize(pages.size())
	_page_read.resize(pages.size())
	_page_read.fill(false)
	var mask : int = IllusionManager.notebook_unlocked_mask
	for i in pages.size():
		_page_unlocked[i] = (mask & (1 << i)) != 0
	unlocked = _count_unlocked()
	# 逐页已读状态（跨场景/重载持久：位掩码 notebook_read_mask）
	# 玩家读过的剧情即使死亡/重载也保持"已读"，避免结局判定（GravityWell）丢失完成状态
	var rmask : int = IllusionManager.notebook_read_mask
	for i in pages.size():
		_page_read[i] = (rmask & (1 << i)) != 0
	# 屏幕左下角（自适应视口高度）
	position = Vector2(24, get_viewport_rect().size.y - 62)


## 只解锁指定页（1-based；可多页，如 [4] 或 [7, 8]）——每处剧情解锁处只更新本处对应剧情
func unlock_pages_only(indices: Array) -> void:
	for idx in indices:
		var i : int = int(idx) - 1
		if i >= 0 and i < _page_unlocked.size():
			_page_unlocked[i] = true
	_refresh_unlocked()
	_g_high_time = 0.0


## 只解锁第 n 页（1-based）
func unlock_page_only(n: int) -> void:
	unlock_pages_only([n])


## 兼容旧调用：解锁前 n 页（仅页1尘埃等场景使用，其余剧情处请用 unlock_pages_only）
func unlock_pages(n: int) -> void:
	var arr : Array = []
	for i in range(1, mini(n, pages.size()) + 1):
		arr.append(i)
	unlock_pages_only(arr)


## 由剧情触发区调用：只解锁第 n 页（不再连带解锁前面的页）
func unlock_page(n: int) -> void:
	unlock_page_only(n)


## 剧情触发区：只解锁第 n 页并直接翻开该页（一次 F 即可阅读到新碎片）
func reveal_page(n: int) -> void:
	unlock_page_only(n)
	var nxt := _first_unread()
	if nxt >= 0:
		page_index = nxt
		reading = true
		get_tree().paused = true
		AudioManager.play_notebook_reveal()


## 指定页（1-based 数组）是否全部已解锁（迷宫出口检查、结局判定等）
func are_pages_unlocked(pages: Array) -> bool:
	for idx in pages:
		var i : int = int(idx) - 1
		if i < 0 or i >= _page_unlocked.size() or not _page_unlocked[i]:
			return false
	return true


## 指定页（1-based 数组）是否全部已读（Stage3 结局触发判定）
func are_pages_read(pages: Array) -> bool:
	for idx in pages:
		var i : int = int(idx) - 1
		if i < 0 or i >= _page_read.size() or not _page_read[i]:
			return false
	return true


func _refresh_unlocked() -> void:
	unlocked = _count_unlocked()
	var mask : int = 0
	for i in _page_unlocked.size():
		if _page_unlocked[i]:
			mask |= 1 << i
	IllusionManager.notebook_unlocked = unlocked
	IllusionManager.notebook_unlocked_mask = mask


func _count_unlocked() -> int:
	var c : int = 0
	for b in _page_unlocked:
		if b:
			c += 1
	return c


## 显示悬浮提示（剧情触发区调用，如"📖 按 F 阅读档案碎片"）；duration<=0 时清除
func show_floating_text(text: String, duration: float = 5.0) -> void:
	_floating_text = text
	_float_time = duration if duration > 0.0 else 0.0
	queue_redraw()


func _next_page() -> void:
	var nxt := _next_unlocked(page_index)
	if nxt >= 0:
		page_index = nxt


func _prev_page() -> void:
	var prv := _prev_unlocked(page_index)
	if prv >= 0:
		page_index = prv


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
			elif glowing and not get_tree().paused:
				var nxt := _first_unread()
				if nxt >= 0:
					page_index = nxt   # 翻开第一个未读的已解锁页
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
	glowing = _has_unread()
	# —— 事件驱动解锁（v3.0 约束4：由物理/区域事件触发，非计时器）——
	var player := get_tree().get_first_node_in_group("Player")
	# 第1页：阶段1 收集第一枚马赫尘埃（老人数据碎片）
	if not _page_unlocked[0] and is_instance_valid(player) and player.dust_collected >= 1:
		unlock_page_only(1)
	# 第2/3页：由机关触发（Switch unlock_page_only）；第4~8页：由迷宫各层存档点触发
	# （Checkpoint unlock_pages_only）。各处只解锁本处对应页，互不连带。


func _close_page() -> void:
	if page_index >= 0 and page_index < _page_read.size():
		_page_read[page_index] = true
	_refresh_read_mask()   # 持久化"已读"标记（跨场景/重载保持）
	reading = false
	glowing = false
	var nxt := _first_unread()
	page_index = nxt if nxt >= 0 else 0
	get_tree().paused = false   # 关闭阅读恢复游戏
	_g_high_time = 0.0


## 把"已读"页状态写回 IllusionManager.notebook_read_mask（跨场景/重载持久）
func _refresh_read_mask() -> void:
	var rmask : int = 0
	for i in _page_read.size():
		if _page_read[i]:
			rmask |= 1 << i
	IllusionManager.notebook_read_mask = rmask


## 第一个未读的已解锁页下标（无则 -1）
func _first_unread() -> int:
	for i in _page_unlocked.size():
		if _page_unlocked[i] and not _page_read[i]:
			return i
	return -1


func _has_unread() -> bool:
	return _first_unread() >= 0


func _next_unlocked(from: int) -> int:
	for i in range(from + 1, _page_unlocked.size()):
		if _page_unlocked[i]:
			return i
	return -1


func _prev_unlocked(from: int) -> int:
	for i in range(from - 1, -1, -1):
		if _page_unlocked[i]:
			return i
	return -1


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
