extends Node2D
## 旋转弧形挡板（3-2）：绕旋转核心同步旋转；玩家接触即重生
## 位置 = 旋转核心位置，绕其公转

@export var orbit_radius : float = 200.0
@export var omega : float = 1.5
@export var arc_size : float = 0.8
@export var start_angle : float = 0.0
@export var bar_color : Color = Color(1.0, 0.27, 0.27, 0.4)

var _angle : float = 0.0


func _ready() -> void:
	_angle = start_angle


func _process(delta: float) -> void:
	_angle += omega * delta
	var player := get_tree().get_first_node_in_group("Player")
	if is_instance_valid(player):
		var rel : Vector2 = player.global_position - global_position
		var dist : float = rel.length()
		if absf(dist - orbit_radius) < 13.0:
			var a : float = wrapf(rel.angle() - _angle, 0.0, TAU)
			if a < arc_size:
				player.on_hazard()
	queue_redraw()


func _draw() -> void:
	draw_arc(Vector2.ZERO, orbit_radius, _angle, _angle + arc_size, 32, bar_color, 18.0)
