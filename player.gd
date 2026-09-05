extends CharacterBody2D

@export var speed = 400
@export var fire_cooldown = 0.25   # 射击间隔（秒），升级强化可以缩短
var damage = 1                     # 每发子弹的伤害
var bullet_count = 3               # 同时发射的弹道数量

# 预加载子弹场景
var bullet_scene = preload("res://bullet.tscn")
var fire_timer = 0.0

func _physics_process(delta):
	# 获取 WASD 移动方向
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = direction * speed
	move_and_slide()

	# 把玩家限制在屏幕范围内，防止跑出画面
	var screen = get_viewport_rect().size
	global_position = global_position.clamp(Vector2(24, 24), screen - Vector2(24, 24))

	# 玩家面朝鼠标
	look_at(get_global_mouse_position())

	# 按住鼠标左键连续射击（间隔由 fire_cooldown 控制）
	fire_timer -= delta
	if Input.is_action_pressed("shoot") and fire_timer <= 0:
		shoot()
		fire_timer = fire_cooldown

func shoot():
	# 根据弹道数量均匀计算每发子弹的角度偏移
	# 例如 3 发 → -0.22, 0, +0.22
	var spacing = 0.22
	var start = -(bullet_count - 1) / 2.0 * spacing

	for i in bullet_count:
		var b = bullet_scene.instantiate()
		b.damage = damage
		# 挂到当前场景下，这样“重新开始”时子弹会跟着一起被清掉
		get_tree().current_scene.add_child(b)

		# 设置子弹的初始位置和角度（玩家朝向 + 偏移）
		b.global_position = global_position
		b.global_rotation = global_rotation + start + i * spacing

	# 枪口火光
	$MuzzleFlash.restart()
