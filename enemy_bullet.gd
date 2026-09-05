extends Area2D

# 敌方子弹（Boss 弹幕）：直线飞行，碰到玩家造成伤害

var dir = Vector2.DOWN
var speed = 240.0

func _physics_process(delta):
	position += dir * speed * delta
	# 飞出屏幕自动销毁
	if position.y > 720 or position.y < -120 or position.x < -120 or position.x > 1272:
		queue_free()

func _on_body_entered(body):
	if body.is_in_group("player"):
		var world = get_tree().current_scene
		if world.has_method("take_damage"):
			world.take_damage(1)
		queue_free()
