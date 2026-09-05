extends Area2D

# 敌方子弹（Boss 弹幕 / 炮手机）：直线或追踪，碰到玩家造成伤害

var dir = Vector2.DOWN
var speed = 240.0
var damage = 1
var homing = 0.0        # 转向速率（弧度/秒），0 为直线弹
var homing_time = 0.0   # 追踪持续时间

func _physics_process(delta):
	# 追踪弹：向玩家方向缓慢转向
	if homing > 0.0 and homing_time > 0.0:
		homing_time -= delta
		var player = get_tree().get_first_node_in_group("player")
		if player:
			var want = (player.global_position - global_position).normalized()
			dir = dir.rotated(clampf(want.angle_to(dir), -homing * delta, homing * delta))
	position += dir * speed * delta
	# 飞出屏幕自动销毁
	if position.y > 720 or position.y < -120 or position.x < -120 or position.x > 1272:
		queue_free()

func _on_body_entered(body):
	if body.is_in_group("player"):
		var world = get_tree().current_scene
		if world.has_method("take_damage"):
			world.take_damage(damage)
		queue_free()
