extends Node2D
## "脚指向核心"几何验证探针（真实关卡 Q5.tscn，rot_feet_to_core=true）
## 预期（同步稳态）：
##   - 核心在摄像机空间中恒为 (0, +R)：正下方（脚指向核心）
##   - 精灵屏显旋转 = 0：头朝上
##   - 摄像机全局旋转 == 玩家旋转（局部≈0，无 2 倍角速度）
##   - 转盘指示线屏显角恒定（屏显静止）
## 写盘 user://feet_core_probe_result.txt 并退出。

var level : Node2D
var t : float = 0.0
var frames : int = 0
var done : bool = false
var based : bool = false

var max_core_x_abs : float = 0.0    # |核心屏显 X|（应≈0：正下方）
var min_core_y : float = 1e9        # 核心屏显 Y（应>0：下方）
var max_sprite_screen : float = 0.0 # 精灵屏显旋转（应≈0：头朝上）
var max_cam_local : float = 0.0     # 摄像机局部旋转（应≈0）
var max_err_cam_player : float = 0.0# 摄像机全局−玩家旋转（应≈0）
var max_ind_dev : float = 0.0       # 指示线屏显角漂移（应≈0）
var ind_base : float = 0.0
var ind_measured : bool = false
var samples : Array[String] = []


func _ready() -> void:
	level = load("res://levels/Q5.tscn").instantiate()
	add_child(level)
	get_viewport().size = Vector2i(1280, 720)
	print("[FeetCoreProbe] Q5.tscn loaded")


func _process(delta: float) -> void:
	t += delta
	frames += 1
	if done:
		return
	if t < 3.0:
		return
	var player : CharacterBody2D = get_tree().get_first_node_in_group("Player")
	if player == null:
		print("[FeetCoreProbe] no player")
		done = true
		return
	var cam : Camera2D = player.get_node_or_null("Camera2D")
	var sprite : Sprite2D = player.get_node_or_null("Sprite2D")
	var core : Node2D = get_tree().get_first_node_in_group("RotatingCore")
	if cam == null or core == null:
		print("[FeetCoreProbe] missing nodes")
		done = true
		return
	var core_camlocal : Vector2 = cam.global_transform.affine_inverse() * core.global_position
	var sprite_screen : float = wrapf(sprite.global_rotation - cam.global_rotation, -PI, PI)
	var cam_local : float = cam.rotation
	var err_cam_player : float = wrapf(cam.global_rotation - player.rotation, -PI, PI)
	var ind_ang : float = wrapf(core.rotation - cam.global_rotation, -PI, PI)
	if not ind_measured:
		ind_measured = true
		ind_base = ind_ang
	max_core_x_abs = maxf(max_core_x_abs, absf(core_camlocal.x))
	min_core_y = minf(min_core_y, core_camlocal.y)
	max_sprite_screen = maxf(max_sprite_screen, absf(sprite_screen))
	max_cam_local = maxf(max_cam_local, absf(cam_local))
	max_err_cam_player = maxf(max_err_cam_player, absf(err_cam_player))
	max_ind_dev = maxf(max_ind_dev, absf(ind_ang - ind_base))
	if frames % 30 == 0:
		var line := "[FeetCoreProbe] t=" + str(t) + " core_camlocal=" + str(core_camlocal) \
				+ " sprite_screen=" + str(sprite_screen) + " cam_local=" + str(cam_local) \
				+ " cam_rot=" + str(cam.global_rotation) + " player_rot=" + str(player.rotation) \
				+ " core_rot=" + str(core.rotation) + " ind=" + str(ind_ang)
		print(line)
		samples.append(line)
	if t >= 4.5:
		done = true
		_print_result()
		get_tree().quit()


func _print_result() -> void:
	var lines : Array[String] = []
	lines.append("========== [FeetCoreProbe] 真实关卡 Q5 脚指向核心验证 ==========")
	lines.append("核心屏显 X 绝对值最大 = " + str(max_core_x_abs) + " px（<12 可接受：≈2.3° 平滑滞后；0 为理想正下方）")
	lines.append("核心屏显 Y 最小 = " + str(min_core_y) + " px（应>0：在玩家下方）")
	lines.append("精灵屏显旋转最大 = " + str(max_sprite_screen) + " rad（应<0.01：头朝上）")
	lines.append("摄像机局部旋转最大 = " + str(max_cam_local) + " rad（应<0.01：无 2 倍角速度叠加）")
	lines.append("摄像机全局−玩家旋转最大 = " + str(max_err_cam_player) + " rad（应≈0）")
	lines.append("转盘指示线屏显角漂移最大 = " + str(max_ind_dev) + " rad（应<0.02：屏显静止）")
	lines.append("---- 采样 ----")
	lines.append_array(samples)
	for line in lines:
		print(line)
	var f := FileAccess.open("user://feet_core_probe_result.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lines) + "\n")
		f.close()
