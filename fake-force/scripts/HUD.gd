extends CanvasLayer
## 极简 HUD
## 左上角：当前幻觉强度 X.X G（颜色 绿→黄→红）
## 其下：洞察能量条

@onready var g_label : Label = $GValue
@onready var energy_bar : ProgressBar = $EnergyBar

var _player : CharacterBody2D = null


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("Player")


func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("Player")

	var g : float = IllusionManager.get_current_g()
	g_label.text = "当前幻觉强度：%.1f G" % g
	var ratio : float = clampf(g / 3.0, 0.0, 1.0)
	g_label.modulate = Color.from_hsv(0.33 * (1.0 - ratio), 1.0, 1.0)

	if is_instance_valid(_player):
		energy_bar.value = _player.insight_energy
