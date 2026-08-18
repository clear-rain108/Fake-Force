extends CanvasLayer
## HUD：有效幻觉强度 + 洞察能量条 + 尘埃/η信息 + 教学/失败提示

@onready var g_label : Label = $GValue
@onready var energy_bar : ProgressBar = $EnergyBar
@onready var msg_label : Label = $Message
@onready var dust_label : Label = $DustInfo
@onready var eta_label : Label = $EtaInfo

var _player : CharacterBody2D = null
var _hint_shown : bool = false
var _msg_time : float = 0.0
var _persistent_text : String = ""


func _ready() -> void:
	add_to_group("HUD")
	_player = get_tree().get_first_node_in_group("Player")
	msg_label.text = ""
	# 全局箭头图例（洞察模式下显示受力说明，各关统一）
	if not has_node("ArrowLegend"):
		var legend : Node = load("res://scripts/ArrowLegend.gd").new()
		legend.name = "ArrowLegend"
		add_child(legend)
	# 旋转参考系按键方向图例（进入旋转系显示，脱离消失）
	if not has_node("RotKeyHint"):
		var kh : Node = load("res://scripts/RotKeyHint.gd").new()
		kh.name = "RotKeyHint"
		add_child(kh)


func _process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("Player")

	# 有效幻觉强度（匀速间歇时为 0）
	var g : float = IllusionManager.get_current_effective_g()
	g_label.text = "当前幻觉强度：%.1f G" % g
	# 颜色按参考系校准的满强度参考（普通=1.5G 变红；旋转=rot_g_visual_ref 十余G 才变红）
	var ref : float = maxf(IllusionManager.vignette_g_ref, 0.05)
	g_label.modulate = Color.from_hsv(0.33 * (1.0 - clampf(g / ref, 0.0, 1.0)), 1.0, 1.0)

	if is_instance_valid(_player):
		energy_bar.value = _player.insight_energy
		dust_label.text = "马赫尘埃：%d" % _player.dust_count
		eta_label.text = "η：%.2f  (Q变重 / Z变轻)" % _player.player_eta
		if _player.is_insight and not _hint_shown:
			_hint_shown = true
			_show_message("没有人在推你。你看到的红色箭头，是你所在参考系正在加速的证明——或者说，是系统在推你。", 6.0)
		# 失败处理：剧情模式坠落过多由 Player 生成 DeathSequence 剧情演出接管，
		# HUD 不得清除 failed（否则每帧重触发、黑屏永远淡不下去）。

	if _msg_time > 0.0:
		_msg_time -= delta
		if _msg_time <= 0.0:
			msg_label.text = _persistent_text   # 临时提示结束 → 恢复持续显示的教学提示


func _show_message(text: String, duration: float) -> void:
	msg_label.text = text
	_msg_time = duration


## 供外部（如提示触发区）调用
func show_message(text: String, duration: float) -> void:
	_show_message(text, duration)


## 供玩家/系统事件调用（与解密 HUD 接口一致）
func show_system_message(text: String) -> void:
	_show_message(text, 5.0)


## 持续显示的提示（教学）：不随计时消失；临时提示结束后恢复
func show_system_message_persistent(text: String) -> void:
	_persistent_text = text
	msg_label.text = text
	_msg_time = 0.0

