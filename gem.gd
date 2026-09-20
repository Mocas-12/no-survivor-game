extends Area3D

# 经验水晶（3D）：随星空下漂 + 磁吸拾取

const MB := preload("res://model_builder.gd")

var xp_value = 1        # 拾取后获得的经验
var magnet_range = 180.0
var magnet_speed = 700.0
var fall_speed = 90.0
var t = randf() * TAU
@onready var player = get_tree().get_first_node_in_group("player")

func _ready():
	add_child(MB.build_gem())
	body_entered.connect(_on_body_entered)

func _process(delta):
	t += delta * 5.0
	rotation.z += 2.0 * delta
	scale = Vector3.ONE * (1.0 + 0.12 * sin(t))

	# 随星空背景向下漂移（磁力核心能力 × 磁力强化卡的倍率共同放大磁吸范围）
	var magnet_mul: float = player.get_meta("magnet_mul", 1.0) if player else 1.0
	var world = get_tree().current_scene
	var stat_mul: float = world.magnet_range_mul if world != null and world.get("magnet_range_mul") != null else 1.0
	position.y -= fall_speed * delta
	if player and global_position.distance_to(player.global_position) < magnet_range * magnet_mul * stat_mul:
		global_position = global_position.move_toward(player.global_position, magnet_speed * delta)

	# 漂出屏幕底部自动回收
	if position.y < -360.0:
		queue_free()

func _on_body_entered(body):
	if body.is_in_group("player"):
		var world = get_tree().current_scene
		if world.has_method("add_xp"):
			world.add_xp(xp_value)
		queue_free()
