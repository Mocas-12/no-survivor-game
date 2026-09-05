extends CharacterBody2D

# 20 种形态贴图（每次吃核心进化一号：体型/翼型/引擎/武装渐进成长）
const FORM_TEXTURES := [
	preload("res://assets/player_form1.png"),
	preload("res://assets/player_form2.png"),
	preload("res://assets/player_form3.png"),
	preload("res://assets/player_form4.png"),
	preload("res://assets/player_form5.png"),
	preload("res://assets/player_form6.png"),
	preload("res://assets/player_form7.png"),
	preload("res://assets/player_form8.png"),
	preload("res://assets/player_form9.png"),
	preload("res://assets/player_form10.png"),
	preload("res://assets/player_form11.png"),
	preload("res://assets/player_form12.png"),
	preload("res://assets/player_form13.png"),
	preload("res://assets/player_form14.png"),
	preload("res://assets/player_form15.png"),
	preload("res://assets/player_form16.png"),
	preload("res://assets/player_form17.png"),
	preload("res://assets/player_form18.png"),
	preload("res://assets/player_form19.png"),
	preload("res://assets/player_form20.png"),
]

@export var follow_speed = 1300    # 鼠标跟随速度（越大跟得越紧）
@export var speed = 400            # 移动速度（摇杆移动 / 疾跑强化用）
@export var fire_cooldown = 0.25   # 射击间隔（秒），强化可缩短
var damage = 1                     # 每发子弹的伤害
var bullet_count = 3               # 同时发射的弹道数量
var form = 0                       # 当前形态 0-3
var element = "normal"             # 弹头元素：normal / fire / ice / lightning / wind
var pattern = "spread"             # 弹道模式：spread 扇形 / stream 平行直射 / wave 波浪
var spacing_scale = 1.0            # 扇形张开系数（扩散弹幕会增大）
var touch_move = Vector2.ZERO      # 手机虚拟摇杆输入
var base_scale = 0.60              # 机体基准尺寸：随形态等级成长（0.60 → 1.0）

var bullet_scene = preload("res://bullet.tscn")
var fire_timer = 0.0

func _ready():
	_update_base_scale()
	scale = Vector2.ONE * base_scale

func _physics_process(delta):
	# 移动：手机摇杆优先，否则平滑跟随鼠标
	if touch_move.length() > 0.1:
		global_position += touch_move * speed * 1.15 * delta
	else:
		global_position = global_position.move_toward(get_global_mouse_position(), follow_speed * delta)
	var screen = get_viewport_rect().size
	global_position = global_position.clamp(Vector2(26, 26), screen - Vector2(26, 26))

	# 按住射击（鼠标左键或右侧开火按钮）
	fire_timer -= delta
	if Input.is_action_pressed("shoot") and fire_timer <= 0:
		shoot()
		fire_timer = fire_cooldown

func shoot():
	var speed_mul = 1.4 if element == "wind" else 1.0
	var spacing = 0.18 * spacing_scale
	var start = -(bullet_count - 1) / 2.0 * spacing

	for i in bullet_count:
		var b = bullet_scene.instantiate()
		b.damage = damage
		b.set_element(element)
		b.speed *= speed_mul
		if pattern == "wave":
			b.wave_amp = 220.0
		get_tree().current_scene.add_child(b)

		if pattern == "stream":
			# 平行直射：弹道不散开，横向错位排列
			b.global_position = global_position + Vector2((i - (bullet_count - 1) / 2.0) * 12.0, -44)
			b.global_rotation = -PI / 2
		else:
			# 扇形弹道（机头朝上 = -90°）
			b.global_position = global_position + Vector2(0, -44)
			b.global_rotation = -PI / 2 + start + i * spacing
	$MuzzleFlash.restart()

	# 射击音效
	var world = get_tree().current_scene
	if world.has_method("play_sfx"):
		world.play_sfx("shoot", -14.0, 0.04)

func set_form(n):
	# 只换贴图并更新基准尺寸（变形演出由 world 驱动）
	form = n
	$Sprite2D.texture = FORM_TEXTURES[n]
	_update_base_scale()

func _update_base_scale():
	base_scale = 0.60 + 0.021 * form   # 形态越高机体越大：0.60 → 1.0
