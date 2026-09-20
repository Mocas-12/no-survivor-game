extends Area3D

# 玩家子弹（3D）：5 种元素染色 + 命中特效 + 波浪/追踪弹道
# 性能：材质/网格按元素静态共享；子弹死亡后回池复用（见 take / _recycle），
#       高射速下不再每发新建材质与粒子发射器

const ELEMENT_COLORS := {
	"normal": Color(1, 1, 1),
	"fire": Color(1, 0.62, 0.35),
	"water": Color(0.45, 0.8, 1.0),
	"ice": Color(0.6, 0.9, 1),
	"lightning": Color(0.78, 0.62, 1),
	"wind": Color(0.62, 1, 0.62),
}

# --- 静态共享缓存与对象池 ---
static var _body_mats := {}
static var _meshes := {}
static var _pool: Array = []

# 从池里取一颗可复用的子弹（仍在场景树中）；空池返回 null，由调用方实例化新弹
static func take() -> Node:
	while _pool.size() > 0:
		var b = _pool.pop_back()
		if is_instance_valid(b) and b.is_inside_tree():
			return b
	return null

static func _body_mat(element: String) -> StandardMaterial3D:
	if not _body_mats.has(element):
		var c: Color = ELEMENT_COLORS[element]
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = c
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 2.6
		_body_mats[element] = m
	return _body_mats[element]

static func _drop(c: Color, r: float) -> SphereMesh:
	var key := "d|%s|%.1f" % [c.to_html(), r]
	if not _meshes.has(key):
		var sm := SphereMesh.new()
		sm.radius = r
		sm.height = r * 2.0
		var mm := StandardMaterial3D.new()
		mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mm.albedo_color = c
		mm.emission_enabled = true
		mm.emission = c
		mm.emission_energy_multiplier = 1.8
		sm.material = mm
		_meshes[key] = sm
	return _meshes[key]

static func _leaf() -> BoxMesh:
	if not _meshes.has("leaf"):
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
		_meshes["leaf"] = bm
	return _meshes["leaf"]

static func _streak() -> BoxMesh:
	if not _meshes.has("streak"):
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
		_meshes["streak"] = bm
	return _meshes["streak"]

# --- 运行时状态 ---
var speed = 800.0
var damage = 1
var element = "normal"   # normal / fire / ice / lightning / wind
var element_lv = 1       # 元素等级（效果随升级卡增强）
var wave_amp = 0.0       # 波浪弹道摆动幅度（0 = 直线）
var wave_t = 0.0
var dir = Vector3.ZERO   # 飞行方向（发射时设置）
var homing = 0.0         # 转向速率（弧度/秒），0 = 无追踪
var homing_time = 0.0    # 追踪持续时间
var _retarget := 0.0     # 目标重扫描计时（避免每帧全组扫描）
var _target: Node3D = null
var _active := false             # 池中休眠的子弹不参与逻辑
var _fx_element := ""            # 当前特效所属元素（判断是否需要重建拖尾）
var _has_water_fx := false       # 当前是否带波浪水花尾
var _created: Array = []         # 动态创建的粒子发射器（重建时销毁）
var _fx_all: Array = []          # 全部发射器（回收时统一停发）

func _ready():
	body_entered.connect(_on_body_entered)

# 发射 / 复用：由 player.shoot 调用，一次性配置全部飞行参数
func launch(p_damage: int, p_element: String, p_speed_mul: float, p_wave: float, p_homing: float, p_homing_time: float, p_element_lv: int, p_pos: Vector3, p_dir: Vector3):
	damage = p_damage
	element = p_element
	element_lv = maxi(p_element_lv, 1)
	speed = 800.0 * p_speed_mul
	wave_amp = p_wave
	homing = p_homing
	homing_time = p_homing_time
	wave_t = 0.0
	_retarget = 0.0
	_target = null
	dir = p_dir
	global_position = p_pos
	visible = true
	_active = true
	set_deferred("monitoring", true)
	$Mesh.material_override = _body_mat(element)
	# 元素 / 弹道没变就只恢复发射，变了才重建拖尾（复用路径零分配）
	if element != _fx_element or (wave_amp > 0.0) != _has_water_fx:
		_rebuild_fx()
	else:
		for e in _fx_all:
			if is_instance_valid(e):
				e.emitting = true

func _rebuild_fx():
	for c in _created:
		if is_instance_valid(c):
			c.queue_free()
	_created.clear()
	_fx_all = [$Trail]
	_fx_element = element
	_has_water_fx = wave_amp > 0.0
	var c: Color = ELEMENT_COLORS[element]
	$Trail.mesh = _drop(c, 1.4)
	$Trail.emitting = true
	match element:
		"fire":
			_attach_flame_trail()
		"water":
			_attach_water_trail()
		"wind":
			_attach_leaf_trail()
			_attach_gust_trail()
		"lightning":
			_attach_crackle_trail()
	if wave_amp > 0.0:
		_attach_water_trail()
	else:
		$Splash.emitting = false

func _add_emitter(amount: int, lifetime: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.emitting = false
	add_child(p)
	_created.append(p)
	_fx_all.append(p)
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
	var f := _add_emitter(8, 0.5)
	f.spread = 14.0
	f.direction = Vector3(0, -1, 0)
	f.gravity = Vector3(0, 160, 0)
	f.initial_velocity_min = 40.0
	f.initial_velocity_max = 130.0
	f.scale_amount_min = 1.5
	f.scale_amount_max = 2.8
	f.scale_amount_curve = _shrink_curve()
	f.color_ramp = _gradient([Color(1, 0.95, 0.55, 0.95), Color(1, 0.55, 0.15, 0.8), Color(0.85, 0.12, 0.05, 0.0)])
	f.mesh = _drop(Color(1, 0.62, 0.2), 1.9)
	f.emitting = true

# 疾风：绿色树叶侧向卷落
func _attach_leaf_trail():
	var w := _add_emitter(5, 0.9)
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
	w.mesh = _leaf()
	w.emitting = true

# 疾风：白绿风痕向后高速拉出，表现风的流向
func _attach_gust_trail():
	var s := _add_emitter(4, 0.3)
	s.spread = 5.0
	s.direction = Vector3(0, -1, 0)
	s.gravity = Vector3.ZERO
	s.initial_velocity_min = 220.0
	s.initial_velocity_max = 340.0
	s.scale_amount_min = 0.8
	s.scale_amount_max = 1.3
	s.color_ramp = _gradient([Color(0.8, 1.0, 0.75, 0.8), Color(0.7, 0.95, 0.65, 0.0)])
	s.mesh = _streak()
	s.emitting = true

# 雷电：弹体四周噼啪爆裂的白色电火花
func _attach_crackle_trail():
	var k := _add_emitter(8, 0.16)
	k.spread = 180.0
	k.direction = Vector3(0, 1, 0)
	k.gravity = Vector3.ZERO
	k.initial_velocity_min = 80.0
	k.initial_velocity_max = 210.0
	k.scale_amount_min = 0.5
	k.scale_amount_max = 1.0
	k.color_ramp = _gradient([Color(1, 1, 1, 1), Color(0.82, 0.62, 1.0, 0.0)])
	k.mesh = _drop(Color(0.88, 0.78, 1.0), 1.2)
	k.emitting = true

# 波浪：定向喷溅水花 + 向后拖出的白色水痕尾流
func _attach_water_trail():
	$Splash.mesh = _drop(Color(0.75, 0.95, 1.0), 1.1)
	$Splash.color_ramp = _gradient([Color(1, 1, 1, 0.95), Color(0.55, 0.85, 1.0, 0.75), Color(0.4, 0.7, 1.0, 0.0)])
	$Splash.amount = 10
	$Splash.lifetime = 0.6
	$Splash.emitting = true
	_fx_all.append($Splash)
	var wk := _add_emitter(5, 0.55)
	wk.spread = 9.0
	wk.direction = Vector3(0, -1, 0)
	wk.gravity = Vector3(0, -240, 0)
	wk.initial_velocity_min = 190.0
	wk.initial_velocity_max = 310.0
	wk.scale_amount_min = 0.7
	wk.scale_amount_max = 1.3
	wk.color_ramp = _gradient([Color(0.92, 0.98, 1.0, 0.85), Color(0.6, 0.88, 1.0, 0.0)])
	wk.mesh = _drop(Color(0.9, 0.97, 1.0), 1.3)
	wk.emitting = true

func _process(delta):
	if not _active:
		return
	if dir == Vector3.ZERO:
		dir = Vector3.UP
	# 追踪：周期性重锁最近目标，逐帧只做转向计算
	if homing > 0.0 and homing_time > 0.0:
		homing_time -= delta
		_retarget -= delta
		if _retarget <= 0.0 or _target == null or _target.dead:
			_retarget = 0.15
			_target = _find_target()
		if _target:
			_steer_toward(_target, delta)
	var move = dir * speed * delta
	if wave_amp > 0.0:
		# 波浪弹道：垂直于航向叠加正弦摆动
		wave_t += delta * 9.0
		move += Vector3(-dir.y, dir.x, 0.0) * sin(wave_t) * wave_amp * delta
	position += move
	rotation.z = Vector2(dir.x, dir.y).angle() - PI / 2
	# 飞出游戏区域自动回池
	if position.y > 420.0 or position.y < -420.0 or absf(position.x) > 660.0:
		_recycle()

# 扫描最近的存活目标（每 0.15 秒一次）
func _find_target() -> Node3D:
	var target: Node3D = null
	var best := INF
	for m in get_tree().get_nodes_in_group("mobs"):
		if m.dead:
			continue
		var dx = global_position.x - m.global_position.x
		var dy = global_position.y - m.global_position.y
		var dd = dx * dx + dy * dy
		if dd < best:
			best = dd
			target = m
	return target

func _steer_toward(target: Node3D, delta: float):
	var to = target.global_position - global_position
	var want = Vector3(to.x, to.y, 0.0).normalized()
	var cur = atan2(dir.y, dir.x)
	var tgt = atan2(want.y, want.x)
	var diff = wrapf(tgt - cur, -PI, PI)
	cur += clampf(diff, -homing * delta, homing * delta)
	dir = Vector3(cos(cur), sin(cur), 0.0)

# 回池：隐身 + 停碰撞 + 停发射器，等待下次 launch
func _recycle():
	if not _active:
		return
	_active = false
	visible = false
	homing_time = 0.0
	set_deferred("monitoring", false)
	for e in _fx_all:
		if is_instance_valid(e):
			e.emitting = false
	if _pool.size() < 160:
		_pool.append(self)
	else:
		queue_free()

# 当有物体进入子弹的检测范围时
func _on_body_entered(body):
	if not _active:
		return
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
		_recycle()

# 波浪弹命中：绽开一圈水花后自毁
func _splash_burst(world):
	var p := CPUParticles3D.new()
	p.amount = 12
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
	p.mesh = _drop(Color(0.75, 0.95, 1.0), 1.3)
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
	p.mesh = _drop(Color(1, 0.6, 0.2), 1.9)
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
	p.mesh = _leaf()
	p.position = global_position
	world.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)

# --- 元素命中特效与元素反应（随元素等级增强） ---
# 元素反应（先手标记 + 后手触发，均消耗标记）：
#   火 + 水 = 蒸汽：白雾爆发，小范围灼伤      雷 + 火 = 超载：橙红大爆炸，范围重创
#   冰 + 水 = 冻结：目标近乎静止 1.2 秒       雷 + 水 = 感电：链式电击 +2 目标
func _apply_element(hit_body, world):
	var lv := maxi(element_lv, 1)
	var is_mob: bool = "wet_timer" in hit_body   # Boss 无元素标记，不吃反应但吃基础元素效果
	match element:
		"fire":
			_fire_burst(world)
			if is_mob:
				if hit_body.wet_timer > 0.0:
					hit_body.wet_timer = 0.0
					_steam_burst(world)
					for m in _nearby_others(hit_body, 110.0 + 20.0 * lv, 5):
						m.take_damage(maxi(2, damage))
				hit_body.burn_timer = 2.0   # 灼烧标记：供超载反应
			# 溅射：Lv.N 半径 90+30(N-1)，溅射伤害 50%+1/级
			var radius := 90.0 + 30.0 * (lv - 1)
			var splash_dmg := maxi(1, roundi(damage * 0.5)) + (lv - 1)
			for m in _nearby_others(hit_body, radius, 4):
				m.take_damage(splash_dmg)
		"water":
			_splash_burst(world)
			if is_mob:
				if hit_body.burn_timer > 0.0:
					# 水 + 火 = 蒸汽
					hit_body.burn_timer = 0.0
					_steam_burst(world)
					for m in _nearby_others(hit_body, 110.0 + 20.0 * lv, 5):
						m.take_damage(maxi(2, damage))
				hit_body.wet_timer = 1.6 + 0.5 * (lv - 1)   # 浸润标记
				if hit_body.has_method("knockback"):
					hit_body.knockback(Vector3(-dir.y, dir.x, 0.0) * (30.0 + 15.0 * lv))
		"ice":
			if is_mob and hit_body.wet_timer > 0.0:
				# 冰 + 水 = 冻结
				hit_body.wet_timer = 0.0
				hit_body.slow_down(1.2, 0.92)
				_freeze_flash(world)
			elif hit_body.has_method("slow_down"):
				hit_body.slow_down(1.6 + 0.4 * (lv - 1), minf(0.45 + 0.1 * (lv - 1), 0.85))
		"lightning":
			var chains := mini(2 + (lv - 1), 5)
			var conduct: bool = is_mob and hit_body.wet_timer > 0.0
			if conduct:
				chains = mini(chains + 2, 7)   # 雷 + 水 = 感电：链式 +2
			if is_mob and hit_body.burn_timer > 0.0:
				# 雷 + 火 = 超载
				hit_body.burn_timer = 0.0
				_overload(world)
				for m in _nearby_others(hit_body, 130.0, 6):
					m.take_damage(damage)
			var chain_dmg := maxi(1, roundi(damage * (0.5 + 0.25 * (lv - 1))))
			var chain_radius := 200.0 if conduct else 140.0
			for m in _nearby_others(hit_body, chain_radius, chains):
				if world.has_method("spawn_lightning"):
					world.spawn_lightning(global_position, m.global_position)
				m.take_damage(chain_dmg)
		"wind":
			if hit_body.has_method("knockback"):
				hit_body.knockback(Vector3(-dir.y, dir.x, 0.0) * (70.0 + 40.0 * (lv - 1)))

# 蒸汽反应：白色水雾腾起
func _steam_burst(world):
	var p := CPUParticles3D.new()
	p.amount = 14
	p.lifetime = 0.7
	p.one_shot = true
	p.explosiveness = 1.0
	p.spread = 40.0
	p.direction = Vector3(0, 1, 0)
	p.gravity = Vector3(0, 120, 0)
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 180.0
	p.scale_amount_min = 1.6
	p.scale_amount_max = 3.0
	p.scale_amount_curve = _shrink_curve()
	p.color_ramp = _gradient([Color(1, 1, 1, 0.9), Color(0.82, 0.88, 0.95, 0.5), Color(0.75, 0.82, 0.9, 0.0)])
	p.mesh = _drop(Color(0.9, 0.94, 1.0), 2.2)
	p.position = global_position
	world.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.1).timeout.connect(p.queue_free)

# 超载反应：橙红大爆炸 + 冲击波
func _overload(world):
	if world.has_method("spawn_ring"):
		world.spawn_ring(global_position, Color(1, 0.55, 0.2), 0.25, 2.4, 0.45)
	if world.has_method("play_sfx"):
		world.play_sfx("explode", -6.0, 0.1)
	var p := CPUParticles3D.new()
	p.amount = 22
	p.lifetime = 0.5
	p.one_shot = true
	p.explosiveness = 1.0
	p.spread = 180.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 160.0
	p.initial_velocity_max = 340.0
	p.scale_amount_min = 1.4
	p.scale_amount_max = 2.8
	p.scale_amount_curve = _shrink_curve()
	p.color_ramp = _gradient([Color(1, 0.9, 0.6, 0.95), Color(1, 0.45, 0.1, 0.7), Color(0.6, 0.1, 0.05, 0.0)])
	p.mesh = _drop(Color(1, 0.55, 0.2), 2.0)
	p.position = global_position
	world.add_child(p)
	p.emitting = true
	get_tree().create_timer(0.9).timeout.connect(p.queue_free)

# 冻结反应：寒冰闪光环 + 冰晶四散
func _freeze_flash(world):
	if world.has_method("spawn_ring"):
		world.spawn_ring(global_position, Color(0.75, 0.93, 1.0), 0.2, 1.6, 0.4)
	var p := CPUParticles3D.new()
	p.amount = 8
	p.lifetime = 0.5
	p.one_shot = true
	p.explosiveness = 1.0
	p.spread = 180.0
	p.gravity = Vector3(0, -160, 0)
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 160.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	p.color_ramp = _gradient([Color(0.85, 0.96, 1.0, 0.95), Color(0.55, 0.85, 1.0, 0.0)])
	p.mesh = _drop(Color(0.85, 0.96, 1.0), 1.4)
	p.position = global_position
	world.add_child(p)
	p.emitting = true
	get_tree().create_timer(0.9).timeout.connect(p.queue_free)

# 查找命中点附近的其他敌机（按距离排序取前 count 个）
func _nearby_others(hit_body, radius: float, count: int):
	var list = []
	for m in get_tree().get_nodes_in_group("mobs"):
		if m != hit_body and not m.dead and global_position.distance_to(m.global_position) <= radius:
			list.append(m)
	list.sort_custom(func(a, b): return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position))
	return list.slice(0, count)
