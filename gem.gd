extends Area2D

var xp_value = 1          # 拾取后获得的经验
var magnet_range = 180.0  # 玩家靠近多少像素时开始吸附
var magnet_speed = 700.0  # 吸附时飞向玩家的速度

@onready var player = get_tree().get_first_node_in_group("player")

var t = randf() * TAU  # 每颗水晶的闪烁节奏错开

func _process(delta):
	t += delta * 5.0
	# 缓缓旋转 + 呼吸缩放，提示这是可以拾取的东西
	rotation += 2.0 * delta
	scale = Vector2.ONE * (1.0 + 0.12 * sin(t))

	# 磁吸：玩家靠近时水晶自动飞过去
	if player and global_position.distance_to(player.global_position) < magnet_range:
		global_position = global_position.move_toward(player.global_position, magnet_speed * delta)

func _on_body_entered(body):
	# 撞到玩家就上交经验并消失
	if body.is_in_group("player"):
		var world = get_tree().current_scene
		if world.has_method("add_xp"):
			world.add_xp(xp_value)
		queue_free()
