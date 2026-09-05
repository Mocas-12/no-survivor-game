extends Area2D

# Boss 掉落的核心装备：缓缓下落，玩家接住后飞机变形

var form_target = 1
var fall_speed = 70.0
var magnet_range = 240.0
var magnet_speed = 640.0
var t = 0.0

@onready var player = get_tree().get_first_node_in_group("player")

func _physics_process(delta):
	t += delta * 4.0
	rotation += 1.5 * delta
	scale = Vector2.ONE * (1.0 + 0.15 * sin(t))

	# 缓缓下落 + 磁吸
	position.y += fall_speed * delta
	if player and global_position.distance_to(player.global_position) < magnet_range:
		global_position = global_position.move_toward(player.global_position, magnet_speed * delta)

	# 掉出屏幕就没收了
	if position.y > 720:
		queue_free()

func _on_body_entered(body):
	if body.is_in_group("player"):
		var world = get_tree().current_scene
		if world.has_method("apply_core"):
			world.apply_core(form_target)
		queue_free()
