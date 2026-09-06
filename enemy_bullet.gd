extends Area3D

# 敌方子弹（Boss 弹幕 / 炮手机）：直线或追踪，碰到玩家造成伤害

var dir = Vector3(0, -1, 0)
var speed = 240.0
var damage = 1
var homing = 0.0        # 转向速率（弧度/秒），0 为直线弹
var homing_time = 0.0   # 追踪持续时间

func _ready():
	body_entered.connect(_on_body_entered)

func _physics_process(delta):
	# 追踪弹：向玩家方向缓慢转向
	if homing > 0.0 and homing_time > 0.0:
		homing_time -= delta
		var player = get_tree().get_first_node_in_group("player")
		if player:
			var to = player.global_position - global_position
			var want = Vector3(to.x, to.y, 0.0).normalized()
			var cur = atan2(dir.y, dir.x)
			var tgt = atan2(want.y, want.x)
			var diff = wrapf(tgt - cur, -PI, PI)
			cur += clampf(diff, -homing * delta, homing * delta)
			dir = Vector3(cos(cur), sin(cur), 0.0)
	position += dir * speed * delta
	# 飞出游戏区域自动销毁
	if position.y > 420.0 or position.y < -420.0 or absf(position.x) > 660.0:
		queue_free()

func _on_body_entered(body):
	if body.is_in_group("player"):
		var world = get_tree().current_scene
		if world.has_method("take_damage"):
			world.take_damage(damage)
		queue_free()
