extends CanvasLayer
## 动态星空背景控制器（CanvasLayer layer=-1）
## 每帧从 Autoload IllusionManager 读取参数并驱动：
## - 背景着色器：g_strength / insight_mode（洞察定格、G 增大变暗）
## - 飞船内部层：set_theme 平滑淡化切换（太空/飞船内部，与选关页按钮一致）
## - 尘埃粒子：整体旋转，使流向与虚假力方向一致（角度乘以系数 0.5）
## - 扭曲层：current_omega 映射为引力透镜强度（clamp 到 0~0.08，默认隐藏）

const THEME_SPACE : int = 0
const THEME_SHIP : int = 1
const SHIP_FADE : float = 2.5   # 飞船层淡化速度（alpha/秒）

@onready var _dust : GPUParticles2D = $Dust
@onready var _warp : ColorRect = $WarpLayer
@onready var _bg_mat : ShaderMaterial = $Nebula.material
@onready var _warp_mat : ShaderMaterial = $WarpLayer.material
@onready var _ship : ColorRect = get_node_or_null("ShipBG") as ColorRect
@onready var _ship_mat : ShaderMaterial = $ShipBG.material if _ship else null

var _dust_angle : float = 0.0
var _ship_alpha : float = 0.0
var _target_ship : float = 0.0


func _ready() -> void:
	# 尘埃发射器置于视口中心（CanvasLayer 屏幕坐标系，左上角为原点）
	_dust.position = get_viewport().get_visible_rect().size * 0.5


func _process(delta: float) -> void:
	var mgr := IllusionManager
	# 0) 飞船内部层：平滑淡化（太空=透明 / 飞船内部=不透明）
	if _ship:
		if absf(_ship_alpha - _target_ship) < 0.002:
			_ship_alpha = _target_ship
		else:
			_ship_alpha = move_toward(_ship_alpha, _target_ship, SHIP_FADE * delta)
		_ship.modulate = Color(1.0, 1.0, 1.0, _ship_alpha)
	# 1) 传递 G 值与洞察状态给背景着色器
	if _bg_mat:
		_bg_mat.set_shader_parameter("g_strength", mgr.current_g_value)
		_bg_mat.set_shader_parameter("insight_mode", 1 if mgr.is_insight_mode else 0)
	if _ship_mat:
		_ship_mat.set_shader_parameter("g_strength", mgr.current_g_value)
	# 2) 尘埃流向 = 虚假力方向（平滑旋转，系数 0.5）
	var fake : Vector2 = mgr.get_current_fake_vector()
	if fake.length_squared() > 0.0001:
		_dust_angle = lerp_angle(_dust_angle, fake.angle() * 0.5, delta * 2.5)
		_dust.rotation = _dust_angle
	# 3) 扭曲层：current_omega → 0~0.08 引力透镜
	var warp : float = clampf(mgr.current_omega * 0.04, 0.0, 0.08)
	if _warp_mat:
		_warp_mat.set_shader_parameter("warp_amount", warp)
	_warp.visible = warp > 0.001


## 设置关卡背景主题（0=太空 1=飞船内部），平滑交叉淡化
func set_theme(theme: int) -> void:
	_target_ship = 1.0 if theme == THEME_SHIP else 0.0

