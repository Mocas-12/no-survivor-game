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
	# 元素在 add_child 前已由 set_element 设定，这里直接按元素取色
	# （否则此处的白色新材质会覆盖 set_element 染过的场景材质，元素弹体永远发白）
	var c: Color = ELEMENT_COLORS[element]
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 2.6
	$Mesh.material_override = m
	_setup_fx()
	body_entered.connect(_on_body_entered)

# 弹丸特效：基础元素拖尾 + 各元素专属粒子（火焰/疾风/雷电），波浪弹道附加水花尾流
func _setup_fx():
	var c: Color = ELEMENT_COLORS[element]
	$Trail.mesh = _droplet_mesh(c, 1.4)
	$Trail.emitting = true
	match element:
		"fire":
			_attach_flame_trail()
		"wind":
			_attach_leaf_trail()
			_attach_gust_trail()
		"lightning":
			_attach_crackle_trail()
	if wave_amp > 0.0:
		_attach_water_trail()

func _add_emitter(amount: int, lifetime: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.emitting = false
	add_child(p)
	return p

func _gradient(colors: Array) -> Gradient:
	var g := Gradient.new()
	var offsets := PackedFloat32Array()
	for i in colors.size():
		offsets.append(float(i) / maxf(colors.size() - 1, 1.0))
	g.offsets = offsets
	g.colors = PackedColorArray(colors)
	return g

func _shrink_curve() -> Curve:
	var cur := Curve.new()
	cur.add_point(Vector2(0.0, 1.0))
	cur.add_point(Vector2(1.0, 0.15))
	return cur

# 火焰：火舌拖尾（火苗向上飘蹿 + 黄→橙→红渐隐），烧灼感更明显
func _attach_flame_trail():
	var f := _add_emitter(12, 0.5)
	f.spread = 14.0
	f.direction = Vector3(0, -1, 0)
	f.gravity = Vector3(0, 160, 0)
	f.initial_velocity_min = 40.0
	f.initial_velocity_max = 130.0
	f.scale_amount_min = 1.5
	f.scale_amount_max = 2.8
	f.scale_amount_curve = _shrink_curve()
	f.color_ramp = _gradient([Color(1, 0.95, 0.55, 0.95), Color(1, 0.55, 0.15, 0.8), Color(0.85, 0.12, 0.05, 0.0)])
	f.mesh = _droplet_mesh(Color(1, 0.62, 0.2), 1.9)
	f.emitting = true

# 疾风：绿色树叶侧向卷落
func _attach_leaf_trail():
	var w := _add_emitter(7, 0.9)
	w.spread = 70.0
	w.direction = Vector3(1, 0, 0)
	w.gravity = Vector3(0, -90, 0)
	w.initial_velocity_min = 40.0
	w.initial_velocity_max = 140.0
	w.angle_min = 0.0
	w.angle_max = 360.0
	w.scale_amount_min = 0.7
	w.scale_amount_max = 1.2
	w.color_ramp = _gradient([Color(0.6, 0.92, 0.35, 0.95), Color(0.35, 0.72, 0.25, 0.75), Color(0.25, 0.6, 0.2, 0.0)])
	w.mesh = _leaf_mesh()
	w.emitting = true

# 疾风：白绿风痕向后高速拉出，表现风的流向
func _attach_gust_trail():
	var s := _add_emitter(6, 0.3)
	s.spread = 5.0
	s.direction = Vector3(0, -1, 0)
	s.gravity = Vector3.ZERO
	s.initial_velocity_min = 220.0
	s.initial_velocity_max = 340.0
	s.scale_amount_min = 0.8
	s.scale_amount_max = 1.3
	s.color_ramp = _gradient([Color(0.8, 1.0, 0.75, 0.8), Color(0.7, 0.95, 0.65, 0.0)])
	s.mesh = _streak_mesh()
	s.emitting = true

# 雷电：弹体四周噼啪爆裂的白色电火花
func _attach_crackle_trail():
	var k := _add_emitter(12, 0.16)
	k.spread = 180.0
	k.direction = Vector3(0, 1, 0)
	k.gravity = Vector3.ZERO
	k.initial_velocity_min = 80.0
	k.initial_velocity_max = 210.0
	k.scale_amount_min = 0.5
	k.scale_amount_max = 1.0
	k.color_ramp = _gradient([Color(1, 1, 1, 1), Color(0.82, 0.62, 1.0, 0.0)])
	k.mesh = _droplet_mesh(Color(0.88, 0.78, 1.0), 1.2)
	k.emitting = true

# 波浪：定向喷溅水花 + 向后拖出的白色水痕尾流
func _attach_water_trail():
	$Splash.mesh = _droplet_mesh(Color(0.75, 0.95, 1.0), 1.1)
	$Splash.color_ramp = _gradient([Color(1, 1, 1, 0.95), Color(0.55, 0.85, 1.0, 0.75), Color(0.4, 0.7, 1.0, 0.0)])
	$Splash.amount = 16
	$Splash.lifetime = 0.6
	$Splash.emitting = true
	var wk := _add_emitter(8, 0.55)
	wk.spread = 9.0
	wk.direction = Vector3(0, -1, 0)
	wk.gravity = Vector3(0, -240, 0)
	wk.initial_velocity_min = 190.0
	wk.initial_velocity_max = 310.0
	wk.scale_amount_min = 0.7
	wk.scale_amount_max = 1.3
	wk.color_ramp = _gradient([Color(0.92, 0.98, 1.0, 0.85), Color(0.6, 0.88, 1.0, 0.0)])
	wk.mesh = _droplet_mesh(Color(0.9, 0.97, 1.0), 1.3)
	wk.emitting = true

func _leaf_mesh() -> BoxMesh:
	var bm := BoxMesh.new()
	bm.size = Vector3(5.0, 0.6, 3.0)
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.albedo_color = Color(0.55, 0.9, 0.35)
	mm.emission_enabled = true
	mm.emission = Color(0.35, 0.75, 0.25)
	mm.emission_energy_multiplier = 1.1
	bm.material = mm
	return bm

func _streak_mesh() -> BoxMesh:
	var bm := BoxMesh.new()
	bm.size = Vector3(0.9, 0.9, 16.0)
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.albedo_color = Color(0.8, 1.0, 0.75)
	mm.emission_enabled = true
	mm.emission = Color(0.6, 0.9, 0.55)
	mm.emission_energy_multiplier = 1.2
	bm.material = mm
	return bm

func _droplet_mesh(c: Color, radius: float) -> SphereMesh:
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.albedo_color = c
	mm.emission_enabled = true
	mm.emission = c
	mm.emission_energy_multiplier = 1.8
	sm.material = mm
	return sm

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
		if wave_amp > 0.0:
			_splash_burst(world)
			if world.has_method("spawn_ring"):
				world.spawn_ring(global_position, Color(0.75, 0.95, 1.0), 0.15, 1.8, 0.3)
		if element == "fire":
			_fire_burst(world)
		elif element == "wind":
			_leaf_burst(world)
		body.take_damage(damage)
		_apply_element(body, world)
		queue_free()

# 波浪弹命中：绽开一圈水花后自毁
func _splash_burst(world):
	var p := CPUParticles3D.new()
	p.amount = 18
	p.lifetime = 0.5
	p.one_shot = true
	p.explosiveness = 1.0
	p.spread = 180.0
	p.gravity = Vector3(0, -500, 0)
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 280.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	p.color_ramp = _gradient([Color(1, 1, 1, 0.95), Color(0.55, 0.85, 1.0, 0.7), Color(0.4, 0.7, 1.0, 0.0)])
	p.mesh = _droplet_mesh(Color(0.75, 0.95, 1.0), 1.3)
	p.position = global_position
	world.add_child(p)
	p.emitting = true
	get_tree().create_timer(0.9).timeout.connect(p.queue_free)

# 火焰命中：黄→红爆燃火团上腾
func _fire_burst(world):
	var p := CPUParticles3D.new()
	p.amount = 16
	p.lifetime = 0.55
	p.one_shot = true
	p.explosiveness = 1.0
	p.spread = 180.0
	p.gravity = Vector3(0, 180, 0)
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 250.0
	p.scale_amount_min = 1.6
	p.scale_amount_max = 3.2
	p.scale_amount_curve = _shrink_curve()
	p.color_ramp = _gradient([Color(1, 0.93, 0.5, 0.95), Color(1, 0.45, 0.1, 0.75), Color(0.7, 0.08, 0.02, 0.0)])
	p.mesh = _droplet_mesh(Color(1, 0.6, 0.2), 1.9)
	p.position = global_position
	world.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)

# 疾风命中：树叶四散卷起
func _leaf_burst(world):
	var p := CPUParticles3D.new()
	p.amount = 12
	p.lifetime = 0.8
	p.one_shot = true
	p.explosiveness = 1.0
	p.spread = 180.0
	p.gravity = Vector3(0, -110, 0)
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 300.0
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.4
	p.color_ramp = _gradient([Color(0.6, 0.92, 0.35, 0.95), Color(0.3, 0.68, 0.22, 0.0)])
	p.mesh = _leaf_mesh()
	p.position = global_position
	world.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)

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
