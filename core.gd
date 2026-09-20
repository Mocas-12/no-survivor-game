extends Area3D

# Boss 掉落的核心装备（3D）：缓缓下落，玩家接住后飞机渐进变形

const MB := preload("res://model_builder.gd")

var form_target = 1
var fall_speed = 70.0
var magnet_range = 240.0
var magnet_speed = 640.0
var t = 0.0

@onready var player = get_tree().get_first_node_in_group("player")

func _ready():
	add_child(MB.build_core())
	body_entered.connect(_on_body_entered)

func _physics_process(delta):
	t += delta * 4.0
	rotation.z += 1.5 * delta
	scale = Vector3.ONE * (1.0 + 0.15 * sin(t))

	# 缓缓下落 + 磁吸（磁力核心能力 × 磁力强化卡的倍率共同放大磁吸范围）
	var magnet_mul: float = player.get_meta("magnet_mul", 1.0) if player else 1.0
	var world = get_tree().current_scene
	var stat_mul: float = world.magnet_range_mul if world != null and world.get("magnet_range_mul") != null else 1.0
	position.y -= fall_speed * delta
	if player and global_position.distance_to(player.global_position) < magnet_range * magnet_mul * stat_mul:
		global_position = global_position.move_toward(player.global_position, magnet_speed * delta)

	# 落到屏幕下缘就悬停等待，绝不没收（形态是最重要的成长线，漏接太伤）
	if position.y < -286.0:
		position.y = -286.0

func _on_body_entered(body):
	if body.is_in_group("player"):
		var world = get_tree().current_scene
		if world.has_method("apply_core"):
			world.apply_core(form_target)
		queue_free()
