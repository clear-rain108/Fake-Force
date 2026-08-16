extends CanvasLayer
## 选关页背景：太空（默认底层）+ 飞船内部（悬停时淡入覆盖），平滑交叉淡化
## - set_theme(SelectBackground.THEME_SPACE)  → 太空
## - set_theme(SelectBackground.THEME_SHIP)   → 飞船内部

const THEME_SPACE : int = 0
const THEME_SHIP : int = 1

const FADE_SPEED : float = 2.5  # alpha/秒（约 0.4s 完成淡化）

@onready var _ship : ColorRect = $ShipBG

var _ship_alpha : float = 0.0
var _target_alpha : float = 0.0


func _ready() -> void:
	_ship.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_ship_alpha = 0.0
	_target_alpha = 0.0


func _process(delta: float) -> void:
	if absf(_ship_alpha - _target_alpha) < 0.002:
		_ship_alpha = _target_alpha
	else:
		_ship_alpha = move_toward(_ship_alpha, _target_alpha, FADE_SPEED * delta)
	_ship.modulate = Color(1.0, 1.0, 1.0, _ship_alpha)


func set_theme(theme: int) -> void:
	_target_alpha = 1.0 if theme == THEME_SHIP else 0.0
