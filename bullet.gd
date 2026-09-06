extends Area2D

# 玩家子弹：支持 5 种元素（染色 + 命中特效）与波浪弹道

var speed = 800.0
var damage = 1
var element = "normal"   # normal / fire / ice / lightning / wind
var wave_amp = 0.0       # 波浪弹道摆动幅度（0 = 直线）
var wave_t = 0.0
var dir = Vector2.ZERO   # 飞行方向（发射时设置）
var homing = 0.0         # 转向速率（弧度/秒），0 = 无追踪
var homing_time = 0.0    # 追踪持续时间

const ELEMENT_COLORS := {
	"normal": Color(1, 1, 1),
	"fire": Color(1, 0.62, 0.35),
	"ice": Color(0.6, 0.9, 1),
	"lightning": Color(0.78, 0.62, 1),
	"wind": Color(0.62, 1, 0.62),
}

func _process(delta):
	if dir == Vector2.ZERO:
		dir = transform.x
	# 追踪：自动转向最近的存活目标（敌机 / Boss）
	if homing > 0.0 and homing_time > 0.0:
		homing_time -= delta
		_steer(delta)
	var move = dir * speed * delta
	if wave_amp > 0.0:
		# 波浪弹道：垂直于航向叠加正弦摆动
		wave_t += delta * 9.0
		move += dir.orthogonal() * sin(wave_t) * wave_amp * delta
	position += move
	rotation = dir.angle()

# 转向最近的存活目标
func _steer(delta):
	var target = null
	var best = INF
	for m in get_tree().get_nodes_in_group("mobs"):
		if m.dead:
			continue
		var d2 = global_position.distance_squared_to(m.global_position)
		if d2 < best:
			best = d2
			target = m
	if target:
		var want = (target.global_position - global_position).normalized()
		dir = dir.rotated(clampf(dir.angle_to(want), -homing * delta, homing * delta))

# 设置元素并给子弹染色
func set_element(e):
	element = e
	var c: Color = ELEMENT_COLORS[e]
	$Sprite2D.modulate = c
	$Trail.color = Color(c.r, c.g, c.b, 0.5)

# 当有物体进入子弹的检测范围时
func _on_body_entered(body):
	# 有 take_damage 函数的就能被打（敌机 / Boss）
	if body.has_method("take_damage"):
		var world = get_tree().current_scene
		if world.has_method("spawn_hit_spark"):
			world.spawn_hit_spark(global_position)
		body.take_damage(damage)
		_apply_element(body, world)
		queue_free()              # 销毁子弹自己

# --- 元素命中特效 ---
func _apply_element(hit_body, world):
	match element:
		"fire":
			# 溅射：波及邻近敌机
			for m in _nearby_others(hit_body, 90.0, 4):
				m.take_damage(maxi(1, roundi(damage * 0.5)))
		"ice":
			# 减速命中目标
			if hit_body.has_method("slow_down"):
				hit_body.slow_down(1.6)
		"lightning":
			# 链式电击：最近的最多 2 个目标
			for m in _nearby_others(hit_body, 140.0, 2):
				if world.has_method("spawn_lightning"):
					world.spawn_lightning(global_position, m.global_position)
				m.take_damage(maxi(1, roundi(damage * 0.5)))
		"wind":
			# 击退命中目标
			if hit_body.has_method("knockback"):
				hit_body.knockback(transform.x * 70.0)

# 查找命中点附近的其他敌机（按距离排序取前 count 个）
func _nearby_others(hit_body, radius: float, count: int):
	var list = []
	for m in get_tree().get_nodes_in_group("mobs"):
		if m != hit_body and not m.dead and global_position.distance_to(m.global_position) <= radius:
			list.append(m)
	list.sort_custom(func(a, b): return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position))
	return list.slice(0, count)

# 飞出屏幕后自动销毁，防止子弹无限积累拖慢游戏
func _on_screen_exited():
	queue_free()
