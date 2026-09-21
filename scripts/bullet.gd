extends Area3D

# 玩家子弹（3D）：5 种元素染色 + 命中特效 + 波浪/追踪弹道
# 性能：材质/网格按元素静态共享（网格与渐变缓存在 fx.gd）；子弹死亡后回池复用（见 take / _recycle），
#       高射速下不再每发新建材质与粒子发射器
# 元素命中 / 反应特效统一走 fx.gd 的 burst 工厂（一份模板，参数化色带 / 速度 / 收缩曲线）

const Fx := preload("res://scripts/fx.gd")

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

# --- 运行时状态 ---
var speed = 800.0
var damage = 1
var element = "normal"   # normal / fire / ice / lightning / wind
var element_lv = 1       # 元素等级（效果随升级卡增强）
var crit := 0.0           # 暴击概率（暴击强化卡），命中翻倍
var reaction_boost := 1.0 # 元素反应伤害倍率（连锁反应卡）
var mark_boost := 1.0     # 元素标记时长倍率（元素延续卡）
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
	add_to_group("player_bullets")   # 追踪导弹道具按此分组把全场子弹转为追踪
	body_entered.connect(_on_body_entered)

# 追踪导弹道具：把飞行中的这颗子弹转为追踪弹（镀金标识），返回是否生效
func make_homing() -> bool:
	if not _active:
		return false
	homing = maxf(homing, 5.0)
	homing_time = maxf(homing_time, 4.0)
	_retarget = 0.0
	_target = null
	$Mesh.material_override = _homing_mat()
	return true

static func _homing_mat() -> StandardMaterial3D:
	if not _body_mats.has("homing"):
		var c := Color(1.0, 0.85, 0.35)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = c
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 3.0
		_body_mats["homing"] = m
	return _body_mats["homing"]

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
	$Trail.mesh = Fx.drop(c, 1.4)
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
	f.scale_amount_curve = Fx.shrink_curve()
	f.color_ramp = Fx.gradient([Color(1, 0.95, 0.55, 0.95), Color(1, 0.55, 0.15, 0.8), Color(0.85, 0.12, 0.05, 0.0)])
	f.mesh = Fx.drop(Color(1, 0.62, 0.2), 1.9)
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
	w.color_ramp = Fx.gradient([Color(0.6, 0.92, 0.35, 0.95), Color(0.35, 0.72, 0.25, 0.75), Color(0.25, 0.6, 0.2, 0.0)])
	w.mesh = Fx.leaf()
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
	s.color_ramp = Fx.gradient([Color(0.8, 1.0, 0.75, 0.8), Color(0.7, 0.95, 0.65, 0.0)])
	s.mesh = Fx.streak()
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
	k.color_ramp = Fx.gradient([Color(1, 1, 1, 1), Color(0.82, 0.62, 1.0, 0.0)])
	k.mesh = Fx.drop(Color(0.88, 0.78, 1.0), 1.2)
	k.emitting = true

# 波浪：定向喷溅水花 + 向后拖出的白色水痕尾流
func _attach_water_trail():
	$Splash.mesh = Fx.drop(Color(0.75, 0.95, 1.0), 1.1)
	$Splash.color_ramp = Fx.gradient([Color(1, 1, 1, 0.95), Color(0.55, 0.85, 1.0, 0.75), Color(0.4, 0.7, 1.0, 0.0)])
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
	wk.color_ramp = Fx.gradient([Color(0.92, 0.98, 1.0, 0.85), Color(0.6, 0.88, 1.0, 0.0)])
	wk.mesh = Fx.drop(Color(0.9, 0.97, 1.0), 1.3)
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
		# 暴击：双倍伤害 + 金色进溅
		var dmg: int = damage
		if crit > 0.0 and randf() < crit:
			dmg = damage * 2
			_crit_flash(world)
		if wave_amp > 0.0:
			_splash_burst(world)
			if world.has_method("spawn_ring"):
				world.spawn_ring(global_position, Color(0.75, 0.95, 1.0), 0.15, 1.8, 0.3)
		if element == "fire":
			_fire_burst(world)
		elif element == "wind":
			_leaf_burst(world)
		body.take_damage(dmg)
		_apply_element(body, world)
		_recycle()

# --- 元素命中特效与元素反应（随元素等级 / 连锁反应 / 元素延续增强） ---
# 反应矩阵（先手留下标记，后手触发并消耗标记）：
#   火+水=蒸汽        雷+火=超载        冰+水=冻结        雷+水=感电
#   风+火=火龙卷      风+水=龙卷        火+冰缓=融化      雷+风=雷暴
func _apply_element(hit_body, world):
	var lv := maxi(element_lv, 1)
	var is_mob: bool = "wet_timer" in hit_body   # Boss 无元素标记，不吃反应但吃基础元素效果
	match element:
		"fire":
			_fire_burst(world)
			if is_mob:
				if hit_body.wet_timer > 0.0:
					# 火 + 水 = 蒸汽
					hit_body.wet_timer = 0.0
					_reaction(world, "react_steam", Color(0.95, 1.0, 1.0))
					_steam_burst(world)
					_aoe(hit_body, world, (110.0 + 20.0 * lv) * (0.75 + 0.25 * reaction_boost), maxi(2, roundi(damage * reaction_boost)))
				elif hit_body.slow_timer > 0.0:
					# 火 + 冰缓 = 融化：单体重创
					_reaction(world, "react_melt", Color(1, 0.6, 0.3))
					_melt_flash(world)
					hit_body.take_damage(roundi(damage * 2.0 * reaction_boost))
				elif hit_body.gust_timer > 0.0:
					# 风 + 火 = 火龙卷
					hit_body.gust_timer = 0.0
					_reaction(world, "react_firestorm", Color(1, 0.45, 0.15))
					_firestorm(world)
					_aoe(hit_body, world, 150.0 * (0.75 + 0.25 * reaction_boost), roundi(damage * 1.2 * reaction_boost))
				hit_body.burn_timer = 2.0 * mark_boost   # 灼烧标记：供超载/蒸汽反应
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
					_reaction(world, "react_steam", Color(0.95, 1.0, 1.0))
					_steam_burst(world)
					_aoe(hit_body, world, (110.0 + 20.0 * lv) * (0.75 + 0.25 * reaction_boost), maxi(2, roundi(damage * reaction_boost)))
				elif hit_body.gust_timer > 0.0:
					# 风 + 水 = 龙卷：牵引周围敌机
					hit_body.gust_timer = 0.0
					_reaction(world, "react_tornado", Color(0.5, 0.85, 1.0))
					_tornado(world, hit_body)
					_aoe(hit_body, world, 130.0 * (0.75 + 0.25 * reaction_boost), roundi(damage * 0.8 * reaction_boost))
				hit_body.wet_timer = (1.6 + 0.5 * (lv - 1)) * mark_boost   # 浸润标记
				# 水流击退：把命中目标推离主角
				if hit_body.has_method("knockback"):
					var pl = get_tree().get_first_node_in_group("player")
					var away := Vector3(dir.x, dir.y, 0.0)
					if pl:
						var to = hit_body.global_position - pl.global_position
						if to.length() > 1.0:
							away = to.normalized()
					hit_body.knockback(away * (60.0 + 20.0 * lv))
		"ice":
			if is_mob and hit_body.wet_timer > 0.0:
				# 冰 + 水 = 冻结
				hit_body.wet_timer = 0.0
				hit_body.slow_down(1.2, 0.92)
				_reaction(world, "react_freeze", Color(0.75, 0.93, 1.0))
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
				_reaction(world, "react_overload", Color(1, 0.55, 0.2))
				_overload(world)
				_aoe(hit_body, world, 130.0 * (0.75 + 0.25 * reaction_boost), roundi(damage * reaction_boost))
			elif is_mob and hit_body.gust_timer > 0.0:
				# 雷 + 风 = 雷暴：三道落雷轰击周围
				hit_body.gust_timer = 0.0
				_reaction(world, "react_storm", Color(0.85, 0.7, 1.0))
				_storm(world)
				_aoe(hit_body, world, 160.0 * (0.75 + 0.25 * reaction_boost), roundi(damage * 0.8 * reaction_boost))
			var chain_dmg := maxi(1, roundi(damage * (0.5 + 0.25 * (lv - 1))))
			var chain_radius := 200.0 if conduct else 140.0
			for m in _nearby_others(hit_body, chain_radius, chains):
				if world.has_method("spawn_lightning"):
					world.spawn_lightning(global_position, m.global_position)
				m.take_damage(chain_dmg)
		"wind":
			if is_mob:
				if hit_body.burn_timer > 0.0:
					# 风 + 火 = 火龙卷
					hit_body.burn_timer = 0.0
					_reaction(world, "react_firestorm", Color(1, 0.45, 0.15))
					_firestorm(world)
					_aoe(hit_body, world, 150.0 * (0.75 + 0.25 * reaction_boost), roundi(damage * 1.2 * reaction_boost))
				elif hit_body.wet_timer > 0.0:
					# 风 + 水 = 龙卷
					hit_body.wet_timer = 0.0
					_reaction(world, "react_tornado", Color(0.5, 0.85, 1.0))
					_tornado(world, hit_body)
					_aoe(hit_body, world, 130.0 * (0.75 + 0.25 * reaction_boost), roundi(damage * 0.8 * reaction_boost))
				hit_body.gust_timer = 2.0 * mark_boost   # 气旋标记
			# 疾风聚拢：把命中点周围的敌机吸向一点（风元素的独特功能）
			var pull := 55.0 + 15.0 * lv
			for m in _nearby_others(hit_body, 150.0 + 20.0 * lv, 6):
				if m.has_method("knockback"):
					var to_center = global_position - m.global_position
					if to_center.length() > 1.0:
						m.knockback(to_center.normalized() * pull)

# 反应提示：命中点浮起反应名
func _reaction(world, key: String, color: Color):
	if world.has_method("spawn_reaction_text"):
		world.spawn_reaction_text(global_position, key, color)

# 反应范围伤害
func _aoe(hit_body, world, radius: float, dmg: int):
	for m in _nearby_others(hit_body, radius, 6):
		m.take_damage(maxi(1, dmg))

# --- 元素命中 / 反应特效（统一走 Fx.burst 工厂；ring/flash/sfx 组合留在原位） ---

# 波浪弹命中：绽开一圈水花
func _splash_burst(world):
	Fx.burst(world, global_position, {
		"amount": 12, "lifetime": 0.5, "gravity": Vector3(0, -500, 0),
		"vel_min": 120.0, "vel_max": 280.0, "scale_min": 0.6, "scale_max": 1.4,
		"colors": [Color(1, 1, 1, 0.95), Color(0.55, 0.85, 1.0, 0.7), Color(0.4, 0.7, 1.0, 0.0)],
		"mesh": Fx.drop(Color(0.75, 0.95, 1.0), 1.3),
	})

# 火焰命中：黄→红爆燃火团上腾
func _fire_burst(world):
	Fx.burst(world, global_position, {
		"amount": 16, "lifetime": 0.55, "gravity": Vector3(0, 180, 0),
		"vel_min": 90.0, "vel_max": 250.0, "scale_min": 1.6, "scale_max": 3.2, "shrink": true,
		"colors": [Color(1, 0.93, 0.5, 0.95), Color(1, 0.45, 0.1, 0.75), Color(0.7, 0.08, 0.02, 0.0)],
		"mesh": Fx.drop(Color(1, 0.6, 0.2), 1.9),
	})

# 疾风命中：树叶四散卷起
func _leaf_burst(world):
	Fx.burst(world, global_position, {
		"amount": 12, "lifetime": 0.8, "gravity": Vector3(0, -110, 0),
		"vel_min": 120.0, "vel_max": 300.0, "scale_min": 0.8, "scale_max": 1.4, "angle": 360.0,
		"colors": [Color(0.6, 0.92, 0.35, 0.95), Color(0.3, 0.68, 0.22, 0.0)],
		"mesh": Fx.leaf(),
	})

# 蒸汽反应：白色水雾腾起
func _steam_burst(world):
	Fx.burst(world, global_position, {
		"amount": 14, "lifetime": 0.7, "spread": 40.0, "direction": Vector3(0, 1, 0),
		"gravity": Vector3(0, 120, 0), "vel_min": 60.0, "vel_max": 180.0,
		"scale_min": 1.6, "scale_max": 3.0, "shrink": true,
		"colors": [Color(1, 1, 1, 0.9), Color(0.82, 0.88, 0.95, 0.5), Color(0.75, 0.82, 0.9, 0.0)],
		"mesh": Fx.drop(Color(0.9, 0.94, 1.0), 2.2),
	})

# 超载反应：橙红大爆炸 + 冲击波
func _overload(world):
	if world.has_method("spawn_ring"):
		world.spawn_ring(global_position, Color(1, 0.55, 0.2), 0.25, 2.4, 0.45)
	if world.has_method("play_sfx"):
		world.play_sfx("explode", -6.0, 0.1)
	Fx.burst(world, global_position, {
		"amount": 22, "lifetime": 0.5,
		"vel_min": 160.0, "vel_max": 340.0, "scale_min": 1.4, "scale_max": 2.8, "shrink": true,
		"colors": [Color(1, 0.9, 0.6, 0.95), Color(1, 0.45, 0.1, 0.7), Color(0.6, 0.1, 0.05, 0.0)],
		"mesh": Fx.drop(Color(1, 0.55, 0.2), 2.0),
	})

# 冻结反应：寒冰闪光环 + 冰晶四散
func _freeze_flash(world):
	if world.has_method("spawn_ring"):
		world.spawn_ring(global_position, Color(0.75, 0.93, 1.0), 0.2, 1.6, 0.4)
	Fx.burst(world, global_position, {
		"amount": 8, "lifetime": 0.5, "gravity": Vector3(0, -160, 0),
		"vel_min": 60.0, "vel_max": 160.0, "scale_min": 0.6, "scale_max": 1.2,
		"colors": [Color(0.85, 0.96, 1.0, 0.95), Color(0.55, 0.85, 1.0, 0.0)],
		"mesh": Fx.drop(Color(0.85, 0.96, 1.0), 1.4),
	})

# 火龙卷：橙红火柱螺旋上腾 + 双层冲击波
func _firestorm(world):
	if world.has_method("spawn_ring"):
		world.spawn_ring(global_position, Color(1, 0.45, 0.15), 0.3, 2.8, 0.55)
		world.spawn_ring(global_position, Color(1, 0.7, 0.3), 0.2, 2.0, 0.4)
	if world.has_method("flash_ui"):
		world.flash_ui(Color(1, 0.5, 0.2), 0.12)
	if world.has_method("play_sfx"):
		world.play_sfx("explode", -5.0, 0.1)
	Fx.burst(world, global_position, {
		"amount": 30, "lifetime": 0.6, "spread": 25.0, "direction": Vector3(0, 1, 0),
		"gravity": Vector3(0, 220, 0), "vel_min": 120.0, "vel_max": 300.0,
		"scale_min": 1.6, "scale_max": 3.2, "shrink": true,
		"colors": [Color(1, 0.95, 0.6, 0.95), Color(1, 0.4, 0.08, 0.75), Color(0.55, 0.08, 0.02, 0.0)],
		"mesh": Fx.drop(Color(1, 0.5, 0.15), 2.2),
	})

# 龙卷：青白漩涡把周围敌机往中心牵引
func _tornado(world, hit_body):
	if world.has_method("spawn_ring"):
		world.spawn_ring(global_position, Color(0.5, 0.85, 1.0), 0.4, 0.2, 0.5)
	if world.has_method("flash_ui"):
		world.flash_ui(Color(0.5, 0.85, 1.0), 0.08)
	Fx.burst(world, global_position, {
		"amount": 24, "lifetime": 0.7, "gravity": Vector3(0, -80, 0),
		"vel_min": 100.0, "vel_max": 240.0, "scale_min": 1.2, "scale_max": 2.6, "shrink": true,
		"colors": [Color(0.85, 0.96, 1.0, 0.95), Color(0.45, 0.8, 1.0, 0.6), Color(0.3, 0.6, 1.0, 0.0)],
		"mesh": Fx.drop(Color(0.6, 0.85, 1.0), 1.9),
	})
	# 牵引：周围敌机被吸向反应中心
	for m in _nearby_others(hit_body, 200.0, 5):
		if m.has_method("knockback"):
			var pull = (global_position - m.global_position).normalized()
			m.knockback(pull * 60.0)

# 融化：目标处白橙闪光
func _melt_flash(world):
	if world.has_method("spawn_ring"):
		world.spawn_ring(global_position, Color(1, 0.75, 0.4), 0.15, 1.2, 0.3)
	Fx.burst(world, global_position, {
		"amount": 10, "lifetime": 0.4, "gravity": Vector3(0, 100, 0),
		"vel_min": 80.0, "vel_max": 200.0, "scale_min": 1.2, "scale_max": 2.4, "shrink": true,
		"colors": [Color(1, 1, 1, 0.95), Color(1, 0.6, 0.3, 0.6), Color(0.8, 0.3, 0.1, 0.0)],
		"mesh": Fx.drop(Color(1, 0.75, 0.4), 1.8),
	})

# 雷暴：三道落雷劈在目标周围
func _storm(world):
	if world.has_method("flash_ui"):
		world.flash_ui(Color(0.85, 0.7, 1.0), 0.1)
	if world.has_method("play_sfx"):
		world.play_sfx("hit", -2.0, 0.15)
	for i in 3:
		var off = Vector3(randf_range(-120, 120), randf_range(-80, 80), 0.0)
		if world.has_method("spawn_lightning"):
			world.spawn_lightning(global_position + off + Vector3(0, 60, 0), global_position + off)

# 暴击：金色进溅
func _crit_flash(world):
	Fx.burst(world, global_position, {
		"amount": 12, "lifetime": 0.35,
		"vel_min": 140.0, "vel_max": 300.0, "scale_min": 0.8, "scale_max": 1.6,
		"colors": [Color(1, 0.9, 0.4, 1.0), Color(1, 0.65, 0.15, 0.0)],
		"mesh": Fx.drop(Color(1, 0.85, 0.35), 1.6),
	})

# 查找命中点附近的其他敌机（按距离排序取前 count 个）
func _nearby_others(hit_body, radius: float, count: int):
	var list = []
	for m in get_tree().get_nodes_in_group("mobs"):
		if m != hit_body and not m.dead and global_position.distance_to(m.global_position) <= radius:
			list.append(m)
	list.sort_custom(func(a, b): return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position))
	return list.slice(0, count)
