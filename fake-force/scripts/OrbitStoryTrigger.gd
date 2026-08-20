extends Area2D
## 阶段3 剧情触发区（η 档位 + 半径区判定）：
## 玩家进入该触发区，且惯性系数 η 达到本页要求（abs(η - require_eta) < 0.1）→ 解锁对应页。
## η 要求越大 → 触发区越靠近黑洞核心（利用马赫尘埃调整 η）。

@export var page_number : int = 9       # 解锁的记事本页（9~12）
@export var require_eta : float = 0.3    # 需要的惯性系数档位（0.3 / 1.0 / 1.7 / 2.5）
@export var hint_fail : String = ""      # η 未达标时的系统提示

var _triggered : bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	queue_redraw()   # 确保标识环（按 η 档位变色）绘制


func _on_body_entered(body: Node2D) -> void:
	if _triggered or not body.is_in_group("Player"):
		return
	var eta : float = float(body.player_eta)
	if absf(eta - require_eta) < 0.1:
		_triggered = true
		var nb := get_tree().get_first_node_in_group("Notebook")
		if nb and nb.has_method("unlock_page_only"):
			nb.unlock_page_only(page_number)   # 只解锁本处对应页
			if nb.has_method("show_floating_text"):
				nb.show_floating_text("📖 按 F 阅读档案碎片", 6.0)
		var hud := get_tree().get_first_node_in_group("HUD")
		if hud and hud.has_method("show_system_message"):
			hud.show_system_message("【系统】：已捕获该半径的残影记录。")
	else:
		var hud := get_tree().get_first_node_in_group("HUD")
		if hud and hud.has_method("show_system_message"):
			hud.show_system_message(hint_fail)


func _draw() -> void:
	# 标识环：按 η 档位变色（η 越大越靠近核心，用暖色）
	var c : Color
	if absf(require_eta - 0.3) < 0.05:
		c = Color(0.3, 0.7, 1.0, 0.5)     # 外圈：冷蓝
	elif absf(require_eta - 1.0) < 0.05:
		c = Color(0.4, 0.85, 1.0, 0.5)    # 次外圈：青蓝
	elif absf(require_eta - 1.7) < 0.05:
		c = Color(1.0, 0.7, 0.4, 0.5)     # 内圈：橙
	else:
		c = Color(1.0, 0.35, 0.3, 0.55)   # 最内圈：红（近核心）
	draw_arc(Vector2.ZERO, 60.0, 0.0, TAU, 48, c, 2.5)
	draw_arc(Vector2.ZERO, 72.0, 0.0, TAU, 48, Color(c, 0.25), 2.0)
