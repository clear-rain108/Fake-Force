extends CanvasLayer
## 解密模式 HUD（§5.3）：左上 G / 右上能量 / 左下尘埃 / 右下 η + 系统提示

@onready var g_label : Label = $TopLeft/GValue
@onready var energy_bar : ProgressBar = $TopRight/EnergyBar
@onready var dust_label : Label = $BottomLeft/DustInfo
@onready var eta_label : Label = $BottomRight/EtaInfo
@onready var sys_msg : Label = $SysMsg

var _player : CharacterBody2D = null
var _sys_time : float = 0.0
var _persistent_text : String = ""


func _ready() -> void:
	add_to_group("HUD")
	_player = get_tree().get_first_node_in_group("Player")
	sys_msg.text = ""
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
	var g : float = IllusionManager.get_current_effective_g()
	g_label.text = "当前幻觉强度：%.1f G" % g
	g_label.modulate = Color.from_hsv(0.33 * (1.0 - clampf(g / 3.0, 0.0, 1.0)), 1.0, 1.0)
	if is_instance_valid(_player):
		energy_bar.value = _player.insight_energy
		dust_label.text = "尘埃：%d" % _player.dust_count
		eta_label.text = "η = %.2f" % _player.player_eta
		var c := Color.WHITE
		if _player.player_eta > 1.2:
			c = Color(1.0, 0.3, 0.25)
		elif _player.player_eta < 0.8:
			c = Color(0.25, 0.6, 1.0)
		eta_label.modulate = c
	if _sys_time > 0.0:
		_sys_time -= delta
		if _sys_time <= 0.0:
			sys_msg.text = _persistent_text   # 临时提示结束 → 恢复持续显示的教学提示


func show_system_message(text: String) -> void:
	sys_msg.text = text
	_sys_time = 4.5


## 持续显示的提示（教学关卡）：不随计时消失；临时提示结束后恢复
func show_system_message_persistent(text: String) -> void:
	_persistent_text = text
	sys_msg.text = text
	_sys_time = 0.0
