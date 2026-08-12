extends Area2D
## 马赫尘埃（阶段2）：按住 E 时被吸向玩家，接触后收集
## 尘埃 = "遥远星系的引力痕迹"（策划案 v2.0 §5.6）
## 收集后可按 Q（变重 η+）/ Z（变轻 η-）各消耗1份

@export var pull_range : float = 380.0
@export var pull_speed : float = 360.0
@export var collect_radius : float = 26.0
@export var dust_color : Color = Color(1.0, 1.0, 1.0, 0.9)

var collected : bool = false
var _player : CharacterBody2D = null


func _ready() -> void:
	add_to_group("Dust")


func _physics_process(delta: float) -> void:
	if collected:
		return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("Player")
	if not is_instance_valid(_player):
		return
	var to_player : Vector2 = _player.global_position - global_position
	var dist : float = to_player.length()
	if Input.is_action_pressed("collect") and dist < pull_range:
		global_position += to_player.normalized() * pull_speed * delta
		if dist < collect_radius:
			_collect()


func _collect() -> void:
	collected = true
	if is_instance_valid(_player):
		_player.add_dust(1)
	queue_free()


func _draw() -> void:
	# 发光小粒子团（极简）
	draw_circle(Vector2.ZERO, 6.0, dust_color)
	draw_circle(Vector2.ZERO, 10.0, Color(dust_color, 0.25))
