extends Area3D

# 玩家子弹（3D）：5 种元素染色 + 命中特效 + 波浪/追踪弹道
# 性能：材质/网格按元素静态共享（网格与渐变缓存在 fx.gd）；子弹死亡后回池复用（见 take / _recycle），
#       高射速下不再每发新建材质与粒子发射器
# 元素命中 / 反应特效统一走 fx.gd 的 burst 工厂（一份模板，参数化色带 / 速度 / 收缩曲线）

const PG := preload("res://scripts/projectile_geometry.gd")
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
static var _pool: Array = []

# 从池里取一颗可复用的子弹（仍在场景树中）；空池返回 null，由调用方实例化新弹
static func take() -> Node:
	while _pool.size() > 0:
		var b = _pool.pop_back()
		if is_instance_valid(b) and b.is_inside_tree():
			return b
	return null

static func _body_mat(element: String) -> StandardMaterial3D:
	return PG.material(element,false)

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
var pierce_left := 0
var struck := {}
var source_player: Node = null
var damage_channel:="main"
var projectile_role:=""
var modules := {}
var return_after := -1.0
var bounces := 0
var flight_age := 0.0
var _active := false             # 池中休眠的子弹不参与逻辑
var _fx_element := ""            # 当前特效所属元素（判断是否需要重建拖尾）
var _low_fx := false
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
	$Mesh.mesh = PG.mesh("homing",false)
	return true

static func _homing_mat() -> StandardMaterial3D:
	return PG.material("homing",false)

# 发射 / 复用：由 player.shoot 调用，一次性配置全部飞行参数
func launch(p_damage: int, p_element: String, p_speed_mul: float, p_wave: float, p_homing: float, p_homing_time: float, p_element_lv: int, p_pos: Vector3, p_dir: Vector3):
	damage = p_damage
	source_player=null
	damage_channel="main"
	projectile_role=""
	modules.clear()
	return_after=-1
	bounces=0
	flight_age=0
	pierce_left=0
	struck.clear()
	crit=0
	reaction_boost=1.0
	mark_boost=1.0
	$Mesh.scale=Vector3.ONE
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
	set_process(true)
	set_deferred("monitoring", true)
	$Mesh.mesh = Fx.fire_head() if element=="fire" else PG.mesh(element,false)
	rotation.z = Vector2(dir.x,dir.y).angle()-PI/2
	$Mesh.rotation.z = 0
	$Mesh.material_override = null if element=="fire" else _body_mat(element)
	# 元素 / 弹道没变就只恢复发射，变了才重建拖尾（复用路径零分配）
	var world=get_tree().current_scene
	var low: bool=world!=null and (world.get("reduce_fx")==true or world.get("performance_limited")==true)
	if element != _fx_element or (wave_amp > 0.0) != _has_water_fx or low!=_low_fx:
		_low_fx=low
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
	if _low_fx:
		$Trail.emitting=false
		$Splash.emitting=false
		_fx_all.clear()
		return
	var c: Color = ELEMENT_COLORS[element]
	$Trail.mesh = Fx.soft_particle(c, 0.85)
	$Trail.amount = 4
	$Trail.lifetime = 0.16
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
	var f := _add_emitter(4, 0.22)
	f.spread = 14.0
	f.direction = Vector3(0, -1, 0)
	f.gravity = Vector3(0, 160, 0)
	f.initial_velocity_min = 40.0
	f.initial_velocity_max = 130.0
	f.scale_amount_min = 1.5
	f.scale_amount_max = 2.8
	f.scale_amount_curve = Fx.shrink_curve()
	f.color_ramp = Fx.gradient([Color(1, 0.95, 0.55, 0.95), Color(1, 0.55, 0.15, 0.8), Color(0.85, 0.12, 0.05, 0.0)])
	f.mesh = Fx.soft_particle(Color(1, 0.62, 0.2), 1.9,true)
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
	w.mesh = Fx.soft_particle(Color(.5,.85,.7),.8)
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
	s.mesh = Fx.soft_particle(Color(.7,.95,.8),.7)
	s.emitting = true

# 雷电：弹体四周噼啪爆裂的白色电火花
func _attach_crackle_trail():
	var k := _add_emitter(4, 0.12)
	k.spread = 180.0
	k.direction = Vector3(0, 1, 0)
	k.gravity = Vector3.ZERO
	k.initial_velocity_min = 80.0
	k.initial_velocity_max = 210.0
	k.scale_amount_min = 0.5
	k.scale_amount_max = 1.0
	k.color_ramp = Fx.gradient([Color(1, 1, 1, 1), Color(0.82, 0.62, 1.0, 0.0)])
	k.mesh = Fx.soft_particle(Color(0.88, 0.78, 1.0), 1.2)
	k.emitting = true

# 波浪：定向喷溅水花 + 向后拖出的白色水痕尾流
func _attach_water_trail():
	$Splash.mesh = Fx.soft_particle(Color(0.75, 0.95, 1.0), 1.1)
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
	wk.mesh = Fx.soft_particle(Color(0.9, 0.97, 1.0), 1.3)
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
	flight_age+=delta
	if projectile_role=="mine" and flight_age>.5:
		speed=0
		for target in get_tree().get_nodes_in_group("mobs"):
			if not target.dead and target.position.distance_to(position)<60:
				_on_body_entered(target)
				return
	if return_after>0 and flight_age>=return_after:
		dir=-dir
		return_after=-1
		struck.clear()
	if bounces>0 and absf(position.x)>530:
		dir.x=-dir.x
		position.x=clampf(position.x,-530,530)
		bounces-=1
	if flight_age>3.8:
		_recycle()
		return
	var move = dir * speed * delta
	if wave_amp > 0.0:
		# 波浪弹道：垂直于航向叠加正弦摆动
		wave_t += delta * 9.0
		move += Vector3(-dir.y, dir.x, 0.0) * sin(wave_t) * wave_amp * delta
	position += move
	$Mesh.rotation.z = 0
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
	set_process(false)
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
	if not _active or not is_instance_valid(body) or struck.has(body.get_instance_id()):
		return
	if body.has_method("take_damage"):
		struck[body.get_instance_id()]=true
		var world = get_tree().current_scene
		if world.has_method("spawn_hit_spark"):
			world.spawn_hit_spark(global_position,element,damage,dir)
		# 暴击：双倍伤害 + 金色进溅
		var dmg: int = damage
		if crit > 0.0 and randf() < crit:
			dmg = damage * 2
			_crit_flash(world)
		if wave_amp > 0.0:
			_splash_burst(world)
			if world.has_method("spawn_ring"):
				world.spawn_ring(global_position, Color(0.75, 0.95, 1.0), 0.15, 1.8, 0.3)
		if body.get("kind")=="shield" and global_position.y < body.global_position.y and pierce_left==0:
			dmg=maxi(1,roundi(dmg*0.45))
		elif body.get("kind")!=null and pierce_left==0:
			for guard in get_tree().get_nodes_in_group("mobs"):
				if guard!=body and guard.get("kind")=="shield" and not guard.dead and guard.position.y<body.position.y and guard.position.distance_to(body.position)<115:
					dmg=maxi(1,roundi(dmg*0.6))
					break
		if modules.has("execute") and float(body.get("hp") if body.get("hp")!=null else body.get("health"))<float(body.max_hp)*.3: dmg=roundi(dmg*1.6)
		preload("res://scripts/arsenal.gd").hit(self,body,world)
		_apply_element(body, world)
		var exposed=preload("res://scripts/element_reactions.gd").state(body).has("exposed")
		var dealt: float=float(dmg)*(1.18 if exposed else 1.0)
		if world.get("campaign")!=null: world.campaign.record_damage(damage_channel,body,dealt)
		body.take_damage(dealt)
		if pierce_left>0:
			pierce_left-=1
		else:
			_recycle()

# Shared status resolution also applies to Bosses; secondary hits cannot recurse.
func _apply_element(hit_body, world):
	preload("res://scripts/element_reactions.gd").apply(hit_body,element,damage,maxi(element_lv,1),reaction_boost,mark_boost,world)

# --- 元素命中 / 反应特效（统一走 Fx.burst 工厂；ring/flash/sfx 组合留在原位） ---

# 波浪弹命中：绽开一圈水花
func _splash_burst(world):
	Fx.burst(world, global_position, {
		"amount": 12, "lifetime": 0.5, "gravity": Vector3(0, -500, 0),
		"vel_min": 120.0, "vel_max": 280.0, "scale_min": 0.6, "scale_max": 1.4,
		"colors": [Color(1, 1, 1, 0.95), Color(0.55, 0.85, 1.0, 0.7), Color(0.4, 0.7, 1.0, 0.0)],
		"mesh": Fx.drop(Color(0.75, 0.95, 1.0), 1.3),
	})

func _crit_flash(world):
	Fx.burst(world, global_position, {
		"amount": 12, "lifetime": 0.35,
		"vel_min": 140.0, "vel_max": 300.0, "scale_min": 0.8, "scale_max": 1.6,
		"colors": [Color(1, 0.9, 0.4, 1.0), Color(1, 0.65, 0.15, 0.0)],
		"mesh": Fx.drop(Color(1, 0.85, 0.35), 1.6),
	})
