extends CharacterBody3D

# 主角战机（3D）：20 种程序化形态，鼠标/摇杆在 x/y 平面驾驶，机头朝上

const BulletScene := preload("res://scenes/bullet.tscn")
const BulletScript := preload("res://scripts/bullet.gd")
const MB := preload("res://scripts/model_builder.gd")

@export var follow_speed = 1300    # 鼠标跟随速度（越大跟得越紧）
@export var speed = 400            # 移动速度（摇杆移动 / 疾跑强化用）
@export var fire_cooldown = 0.25   # 射击间隔（秒），强化可缩短
var damage = 1                     # 每发子弹的伤害
var bullet_count = 3               # 同时发射的弹道数量
var form = 0                       # 当前形态 0-19
var element = "normal"             # 弹头元素：normal / fire / ice / lightning / wind
var element_levels := {"fire": 0, "water": 0, "ice": 0, "lightning": 0, "wind": 0}  # 各元素等级（切换时各自保留）
var pattern = "spread"             # 弹道模式：spread 扇形 / homing 追踪 / wave 波浪
var pattern_levels := {"homing": 0, "wave": 0}  # 特殊弹道等级（切换时各自保留）
var spacing_scale = 1.0            # 扇形张开系数（扩散弹幕会增大）
var touch_move = Vector2.ZERO      # 手机虚拟摇杆输入
var crit_chance := 0.0             # 暴击概率（暴击强化卡）
var proj_speed_mul := 1.0          # 弹速倍率（弹速强化卡）
var reaction_boost := 1.0          # 元素反应伤害倍率（连锁反应卡）
var mark_boost := 1.0              # 元素标记时长倍率（元素延续卡）
var base_scale = 0.60              # 机体基准尺寸：随形态等级成长（0.60 → 1.0）
var auxiliary := ""
var auxiliary_level := 0
var auxiliary_timer := 0.25
var heavy_timer := 1.5
var pierce_level := 0
var branch := ""
var fire_timer = 0.0
var use_touch = false              # 触屏设备：摇杆专属移动
var model: Node3D = null           # 当前 3D 机体模型
var autopilot := false             # 无头平衡测试钩子（tools/balance_test.gd）：接管移动，默认关闭
var autopilot_target := Vector3.ZERO

var glow_t := 0.0                   # 呼吸灯计时
var _glow_mat: StandardMaterial3D = null

func _ready():
	use_touch = DisplayServer.is_touchscreen_available()
	_update_base_scale()
	scale = Vector3.ONE * base_scale
	_set_model(0)

func _update_base_scale():
	base_scale = 0.60 + 0.021 * form   # 形态越高机体越大：0.60 → 1.0

func _set_model(n: int, prebuilt: Node3D = null):
	if model:
		model.queue_free()
	model = prebuilt if prebuilt else MB.build_player_form(n)
	add_child(model)
	preload("res://scripts/branch_visual.gd").decorate(model,branch)
	# 呼吸灯：拾取机体材质引用，每帧调制自发光强度
	_glow_mat = model.get_meta("glow_mat") if model.has_meta("glow_mat") else null

func set_form(n: int, prebuilt: Node3D = null):
	# 只换 3D 模型（变形演出由 world 驱动）；prebuilt 为提前构建好的新机体
	form = n
	_set_model(n, prebuilt)
	_update_base_scale()

func _physics_process(delta):
	# 移动（游戏平面：x 左右、y 上下、z 恒 0）
	var m = get_viewport().get_mouse_position()
	if autopilot:
		# 平衡测试的自动驾驶：与鼠标同速飞向目标点
		position = position.move_toward(autopilot_target, follow_speed * delta)
	elif use_touch:
		# 手机端移速加成 1.9x（≈760px/s）：旧值 1.25x 只有桌面鼠标跟随 1300px/s 的 38%，
		# 同屏弹幕下实质更难；手感以真机复核为准（评估结论：平台机动性对等化）
		position += Vector3(touch_move.x, -touch_move.y, 0.0) * speed * 1.9 * delta
	else:
		var target := Vector3(m.x - 576.0, 324.0 - m.y, 0.0)
		position = position.move_toward(target, follow_speed * delta)
	position.x = clampf(position.x, -550.0, 550.0)
	position.y = clampf(position.y, -298.0, 298.0)
	# 转向时轻微侧倾（3D 姿态细节）
	if model:
		var bank := 0.0
		if autopilot:
			bank = clampf((autopilot_target.x - position.x) * 0.0015, -0.3, 0.3)
		elif use_touch:
			bank = -touch_move.x * 0.3
		else:
			bank = clampf((m.x - 576.0 - position.x) * 0.0015, -0.3, 0.3)
		model.rotation.z = lerpf(model.rotation.z, bank, minf(10.0 * delta, 1.0))
		if preload("res://scripts/blender_fleet.gd").enabled:
			model.rotation.y=lerpf(model.rotation.y,-bank*.55,minf(8.0*delta,1.0))

	# 呼吸灯：机体自发光与跟随灯同步起伏（幅度调低，不遮盖机体本体细节）
	glow_t += delta
	var breath := 0.5 + 0.5 * sin(glow_t * 5.2)
	if _glow_mat:
		_glow_mat.emission_energy_multiplier = 0.9 + 0.22 * breath
	$Glow.light_energy = 1.0 + 0.22 * breath

	auxiliary_timer -= delta
	heavy_timer -= delta
	if auxiliary != "" and auxiliary_timer <= 0:
		fire_auxiliary()
		auxiliary_timer = maxf(0.65,1.15-auxiliary_level*0.12)
	if branch == "siege" and heavy_timer <= 0:
		_hull_fire(true)
		var heavy = new_round()
		heavy.launch(damage*3,"normal",0.65,0,0,0,1,global_position+Vector3(0,35,1),Vector3.UP)
		heavy.pierce_left = 3
		heavy.get_node("Mesh").scale=Vector3(1.8,2.8,1.8)
		heavy_timer=1.6
	# 全自动射击：只需专注走位躲弹幕
	fire_timer -= delta
	if fire_timer <= 0:
		shoot()
		fire_timer = fire_cooldown

func _hull_fire(heavy:=false) -> void:
	if not is_instance_valid(model): return
	var hull: Node3D=model.get_meta("fleet_motion",model)
	if hull.has_method("fire"): hull.fire(heavy)

func shoot():
	_hull_fire()
	var speed_mul = 1.4 if element == "wind" else 1.0
	var spacing = (0.1 if branch=="assault" else 0.18) * spacing_scale
	var shots: int = mini(bullet_count + (1 if branch=="assault" else 0),9)
	var start = -(shots - 1) / 2.0 * spacing

	for i in shots:
		# 优先从对象池取回子弹（bullet.gd 维护），空池才实例化新弹
		var b = BulletScript.take()
		if b == null:
			b = BulletScene.instantiate()
			get_tree().current_scene.add_child(b)

		var ang: float = PI / 2 + start + i * spacing
		var s_mul: float = speed_mul * proj_speed_mul
		var hom := 0.0
		var h_time := 0.0
		var el_lv := 0
		if element != "normal":
			el_lv = maxi(1, int(element_levels.get(element, 1)))
		var w_amp := 0.0
		if pattern == "homing":
			# 追踪导弹：先张开射出，随后自动转向最近的敌机 / Boss（等级提升转向与续航）
			var hl := maxi(1, int(pattern_levels.get("homing", 1)))
			ang = PI / 2 + start + i * spacing * 1.6
			hom = 3.5 + hl
			h_time = 3.0 + hl
			s_mul = speed_mul * proj_speed_mul * 0.55
		elif pattern == "wave":
			w_amp = 220.0 + 80.0 * (maxi(1, int(pattern_levels.get("wave", 1))) - 1)
		b.launch(damage, element, s_mul, w_amp, hom, h_time, el_lv,
			global_position + Vector3(0, 44.0 * base_scale, 0.5), Vector3(cos(ang), sin(ang), 0.0))
		b.pierce_left=pierce_level
		b.crit = crit_chance
		b.reaction_boost = reaction_boost
		b.mark_boost = mark_boost
	$MuzzleFlash.restart()

	# 射击音效
	var world = get_tree().current_scene
	if world.has_method("play_sfx"):
		world.play_sfx("shoot", -14.0, 0.04)

func new_round():
	var b = BulletScript.take()
	if b == null:
		b=BulletScene.instantiate()
		get_tree().current_scene.add_child(b)
	return b

func fire_auxiliary():
	if is_instance_valid(model):
		var hull: Node3D=model.get_meta("fleet_motion",model)
		if hull.has_method("launch_bay"): hull.launch_bay()
	var targets: Array = get_tree().get_nodes_in_group("mobs").filter(func(m): return not m.dead and m.position.y > position.y-20 and m.position.y < 340)
	if targets.is_empty(): return
	targets.sort_custom(func(a,b): return global_position.distance_squared_to(a.global_position)<global_position.distance_squared_to(b.global_position))
	var target: Node3D=targets[0]
	for i in (2 if branch=="escort" else 1):
		var origin: Vector3=global_position+Vector3((-25 if i==0 else 25),10,1)
		var toward: Vector3=(target.global_position-origin).normalized()
		var b=new_round()
		var el: String="normal" if auxiliary=="homing" else auxiliary
		b.launch(maxi(1,roundi(damage*0.5)),el,0.8,0,5.0,2.0,auxiliary_level,origin,toward)
		b.reaction_boost=reaction_boost
		b.mark_boost=mark_boost
		if auxiliary=="homing": b.make_homing()

# 阵亡演出第一步：机体熄火隐去（由 world 驱动爆炸与慢动作）
func play_death():
	set_physics_process(false)
	$Collision.set_deferred("disabled", true)
	$Glow.visible = false
	$EngineTrail.emitting = false
	$MuzzleFlash.emitting = false
	if model:
		model.visible = false

# 凤凰模块复活：熄火部件全部复位
func revive():
	set_physics_process(true)
	$Collision.set_deferred("disabled", false)
	$Glow.visible = true
	$EngineTrail.emitting = true
	if model:
		model.visible = true
