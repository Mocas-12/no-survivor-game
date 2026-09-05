extends Area2D

var speed = 800
var damage = 1   # 伤害由玩家射出时设置

func _process(delta):
	# 子弹向前飞行
	position += transform.x * speed * delta

# 当有物体进入子弹的检测范围时
func _on_body_entered(body):
	# 有 take_damage 函数的就能被打（敌人）
	if body.has_method("take_damage"):
		# 命中小火花
		var world = get_tree().current_scene
		if world.has_method("spawn_hit_spark"):
			world.spawn_hit_spark(global_position)
		body.take_damage(damage)  # 调用敌人的受伤函数
		queue_free()              # 销毁子弹自己

# 飞出屏幕后自动销毁，防止子弹无限积累拖慢游戏
func _on_screen_exited():
	queue_free()
