extends CharacterBody3D

# 主角战机（3D）：20 种程序化形态，鼠标/摇杆在 x/y 平面驾驶，机头朝上

const BulletScene := preload("res://bullet.tscn")
const BulletScript := preload("res://bullet.gd")
const MB := preload("res://model_builder.gd")

@export var follow_speed = 1300    # 鼠标跟随速度（越大跟得越紧）
@export var speed = 400            # 移动速度（摇杆移动 / 疾跑强化用）
@export var fire_cooldown = 0.25   # 射击间隔（秒），强化可缩短
var damage = 1                     # 每发子弹的伤害
var bullet_count = 3               # 同时发射的弹道数量
var form = 0                       # 当前形态 0-19
var element = "normal"             # 弹头元素：normal / fire / ice / lightning / wind
var pattern = "spread"             # 弹道模式：spread 扇形 / homing 追踪 / wave 波浪
var spacing_scale = 1.0            # 扇形张开系数（扩散弹幕会增大）
var touch_move = Vector2.ZERO      # 手机虚拟摇杆输入
var base_scale = 0.60              # 机体基准尺寸：随形态等级成长（0.60 → 1.0）
var fire_timer = 0.0
var use_touch = false              # 触屏设备：摇杆专属移动
var model: Node3D = null           # 当前 3D 机体模型

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
	if use_touch:
		position += Vector3(touch_move.x, -touch_move.y, 0.0) * speed * 1.25 * delta
	else:
		var target := Vector3(m.x - 576.0, 324.0 - m.y, 0.0)
		position = position.move_toward(target, follow_speed * delta)
	position.x = clampf(position.x, -550.0, 550.0)
	position.y = clampf(position.y, -298.0, 298.0)
	# 转向时轻微侧倾（3D 姿态细节）
	if model:
		var bank := 0.0
		if use_touch:
			bank = -touch_move.x * 0.3
		else:
			bank = clampf((m.x - 576.0 - position.x) * 0.0015, -0.3, 0.3)
		model.rotation.z = lerpf(model.rotation.z, bank, minf(10.0 * delta, 1.0))

	# 呼吸灯：机体自发光与跟随灯同步起伏（0.8Hz），暗星空中始终清晰
	glow_t += delta
	var breath := 0.5 + 0.5 * sin(glow_t * 5.2)
	if _glow_mat:
		_glow_mat.emission_energy_multiplier = 0.75 + 0.7 * breath
	$Glow.light_energy = 1.0 + 0.7 * breath

	# 全自动射击：只需专注走位躲弹幕
	fire_timer -= delta
	if fire_timer <= 0:
		shoot()
		fire_timer = fire_cooldown

func shoot():
	var speed_mul = 1.4 if element == "wind" else 1.0
	var spacing = 0.18 * spacing_scale
	var start = -(bullet_count - 1) / 2.0 * spacing

	for i in bullet_count:
		# 优先从对象池取回子弹（bullet.gd 维护），空池才实例化新弹
		var b = BulletScript.take()
		if b == null:
			b = BulletScene.instantiate()
			get_tree().current_scene.add_child(b)

		var ang: float = PI / 2 + start + i * spacing
		var s_mul: float = speed_mul
		var hom := 0.0
		var h_time := 0.0
		if pattern == "homing":
			# 追踪导弹：先张开射出，随后自动转向最近的敌机 / Boss
			ang = PI / 2 + start + i * spacing * 1.6
			hom = 4.5
			h_time = 4.0
			s_mul = speed_mul * 0.55
		b.launch(damage, element, s_mul, 220.0 if pattern == "wave" else 0.0, hom, h_time,
			global_position + Vector3(0, 44.0 * base_scale, 0.5), Vector3(cos(ang), sin(ang), 0.0))
	$MuzzleFlash.restart()

	# 射击音效
	var world = get_tree().current_scene
	if world.has_method("play_sfx"):
		world.play_sfx("shoot", -14.0, 0.04)

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
