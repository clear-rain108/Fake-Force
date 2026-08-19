extends Area2D
## 迷宫最上层出口检查（阶段2）：
## 玩家靠近时显示"【系统】：正在检查资料完整性，请稍候..."保持 2s；
## 已解锁 7 页剧情 → 开启上层出口（显现条件平台 + 激活 StageTransition + 出口门变绿）；
## 未解锁 → 屏幕中央非法访问警告 + 黑屏约 3s 后重开游戏（跳过开场动画）。

const CHECK_TIME : float = 2.0
const ILLEGAL_TIME : float = 3.0
const BLACK_FADE : float = 0.5

@export var transition_path : NodePath = NodePath()  # StageTransition（检查通过后启用 monitoring）
@export var conditional_paths : Array = []           # 条件平台节点路径（visible + 碰撞开启）
@export var gate_path : NodePath = NodePath()        # MazeExitGate（set_locked(false)）

var _checked : bool = false
var _phase : int = 0     # 0=空闲 1=检查中 2=出口已开启 3=非法访问
var _timer : float = 0.0
var _black : ColorRect = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # 非法访问黑屏期间树被暂停，本节点仍需计时
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _checked or not body.is_in_group("Player"):
		return
	_checked = true
	_phase = 1
	_timer = 0.0
	var hud := get_tree().get_first_node_in_group("HUD")
	if hud and hud.has_method("show_system_message"):
		hud.show_system_message("【系统】：正在检查资料完整性，请稍候...")


func _process(delta: float) -> void:
	if _phase == 1:
		_timer += delta
		if _timer >= CHECK_TIME:
			var nb := get_tree().get_first_node_in_group("Notebook")
			var unlocked : int = int(nb.get("unlocked")) if nb else IllusionManager.notebook_unlocked
			var need : int = int(nb.get("pages").size()) if nb else 8   # 8 页（第7段剧情拆2页）
			if unlocked >= need:
				_open_exit()
			else:
				_start_illegal()
	elif _phase == 3:
		_timer += delta
		if _black:
			_black.color.a = minf(1.0, _timer / BLACK_FADE)
		if _timer >= ILLEGAL_TIME:
			_restart_game()


func _open_exit() -> void:
	_phase = 2
	# 显现条件平台（visible + 碰撞开启）
	for cp_path in conditional_paths:
		var cp := get_node_or_null(cp_path)
		if cp:
			cp.visible = true
			var col := cp.get_node_or_null("CollisionShape2D")
			if col:
				col.disabled = false
	# 激活 StageTransition（允许进入 → Stage3）
	var tr := get_node_or_null(transition_path)
	if tr:
		tr.set("monitoring", true)
	# 出口门变绿（视觉反馈）
	var gate := get_node_or_null(gate_path)
	if gate and gate.has_method("set_locked"):
		gate.set_locked(false)
	var hud := get_tree().get_first_node_in_group("HUD")
	if hud and hud.has_method("show_system_message"):
		hud.show_system_message("【系统】：资料完整性确认。上层出口开启。")


func _start_illegal() -> void:
	_phase = 3
	_timer = 0.0
	Engine.time_scale = 1.0
	get_tree().paused = true   # 冻结游戏（本节点 PROCESS_MODE_ALWAYS 仍计时）
	# 全屏黑幕 + 屏幕中央警告
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_black = ColorRect.new()
	_black.color = Color(0.0, 0.0, 0.0, 0.0)
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_black)
	var lbl := Label.new()
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.text = "【系统】：非法访问！泽舟号%%#&…\n【系统】：深空号拒绝您的访问请求。您尚未收集到足够材料。"
	lbl.modulate = Color(1.0, 0.9, 0.85)
	layer.add_child(lbl)


func _restart_game() -> void:
	# 黑屏结束：重开当前关卡，跳过开场动画
	IllusionManager.skip_opening = true
	get_tree().reload_current_scene()
