extends Area3D

# 玩家子弹（3D）：5 种元素染色 + 命中特效 + 波浪/追踪弹道

var speed = 800.0
var damage = 1
var element = "normal"   # normal / fire / ice / lightning / wind
var wave_amp = 0.0       # 波浪弹道摆动幅度（0 = 直线）
var wave_t = 0.0
var dir = Vector3.ZERO   # 飞行方向（发射时设置）
var homing = 0.0         # 转向速率（弧度/秒），0 = 无追踪
var homing_time = 0.0    # 追踪持续时间

const ELEMENT_COLORS := {
	"normal": Color(1, 1, 1),
	"fire": Color(1, 0.62, 0.35),
	"ice": Color(0.6, 0.9, 1),
	"lightning": Color(0.78, 0.62, 1),
	"wind": Color(0.62, 1, 0.62),
}

func _ready():
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1, 1, 1)
	m.emission_enabled = true
	m.emission = Color(1, 1, 1)
	m.emission_energy_multiplier = 2.6
	$Mesh.material_override = m
	body_entered.connect(_on_body_entered)

func set_element(e):
	element = e
	var c: Color = ELEMENT_COLORS[e]
	$Mesh.material_override.emission = c
	$Mesh.material_override.albedo_color = c

func _process(delta):
	if dir == Vector3.ZERO:
		dir = Vector3.UP
	# 追踪：自动转向最近的存活目标（敌机 / Boss）
	if homing > 0.0 and homing_time > 0.0:
		homing_time -= delta
		_steer(delta)
	var move = dir * speed * delta
	if wave_amp > 0.0:
		# 波浪弹道：垂直于航向叠加正弦摆动
		wave_t += delta * 9.0
		move += Vector3(-dir.y, dir.x, 0.0) * sin(wave_t) * wave_amp * delta
	position += move
	rotation.z = Vector2(dir.x, dir.y).angle() - PI / 2
	# 飞出游戏区域自动销毁
	if position.y > 420.0 or position.y < -420.0 or absf(position.x) > 660.0:
		queue_free()

# 转向最近的存活目标
func _steer(delta):
	var target = null
	var best = INF
	for m in get_tree().get_nodes_in_group("mobs"):
		if m.dead:
			continue
		var dx = global_position.x - m.global_position.x
		var dy = global_position.y - m.global_position.y
		var dd = dx * dx + dy * dy
		if dd < best:
			best = dd
			target = m
	if target:
		var to = target.global_position - global_position
		var want = Vector3(to.x, to.y, 0.0).normalized()
		var cur = atan2(dir.y, dir.x)
		var tgt = atan2(want.y, want.x)
		var diff = wrapf(tgt - cur, -PI, PI)
		cur += clampf(diff, -homing * delta, homing * delta)
		dir = Vector3(cos(cur), sin(cur), 0.0)

# 当有物体进入子弹的检测范围时
func _on_body_entered(body):
	if body.has_method("take_damage"):
		var world = get_tree().current_scene
		if world.has_method("spawn_hit_spark"):
			world.spawn_hit_spark(global_position)
		body.take_damage(damage)
		_apply_element(body, world)
		queue_free()
	elif body.is_in_group("mobs"):
		body.queue_free()
		queue_free()

# --- 元素命中特效 ---
func _apply_element(hit_body, world):
	match element:
		"fire":
			for m in _nearby_others(hit_body, 90.0, 4):
				m.take_damage(maxi(1, roundi(damage * 0.5)))
		"ice":
			if hit_body.has_method("slow_down"):
				hit_body.slow_down(1.6)
		"lightning":
			for m in _nearby_others(hit_body, 140.0, 2):
				if world.has_method("spawn_lightning"):
					world.spawn_lightning(global_position, m.global_position)
				m.take_damage(maxi(1, roundi(damage * 0.5)))
		"wind":
			if hit_body.has_method("knockback"):
				hit_body.knockback(Vector3(-dir.y, dir.x, 0.0) * 70.0)

# 查找命中点附近的其他敌机（按距离排序取前 count 个）
func _nearby_others(hit_body, radius: float, count: int):
	var list = []
	for m in get_tree().get_nodes_in_group("mobs"):
		if m != hit_body and not m.dead and global_position.distance_to(m.global_position) <= radius:
			list.append(m)
	list.sort_custom(func(a, b): return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position))
	return list.slice(0, count)
