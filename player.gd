extends CharacterBody2D

# 4 种形态贴图（击杀 Boss 掉落核心装备后变形）
const FORM_TEXTURES := [
	preload("res://assets/player_form1.png"),
	preload("res://assets/player_form2.png"),
	preload("res://assets/player_form3.png"),
	preload("res://assets/player_form4.png"),
]

@export var follow_speed = 1300    # 鼠标跟随速度（越大跟得越紧）
@export var fire_cooldown = 0.25   # 射击间隔（秒），强化可缩短
var damage = 1                     # 每发子弹的伤害
var bullet_count = 3               # 同时发射的弹道数量
var form = 0                       # 当前形态 0-3

var bullet_scene = preload("res://bullet.tscn")
var fire_timer = 0.0

func _physics_process(delta):
	# 纯鼠标操控：飞机平滑跟随鼠标，机头固定朝上
	var target = get_global_mouse_position()
	global_position = global_position.move_toward(target, follow_speed * delta)
	var screen = get_viewport_rect().size
	global_position = global_position.clamp(Vector2(26, 26), screen - Vector2(26, 26))

	# 按住鼠标左键连续射击
	fire_timer -= delta
	if Input.is_action_pressed("shoot") and fire_timer <= 0:
		shoot()
		fire_timer = fire_cooldown

func shoot():
	# 扇形弹道（机头朝上 = -90°）
	var spacing = 0.18
	var start = -(bullet_count - 1) / 2.0 * spacing
	for i in bullet_count:
		var b = bullet_scene.instantiate()
		b.damage = damage
		get_tree().current_scene.add_child(b)
		b.global_position = global_position + Vector2(0, -44)
		b.global_rotation = -PI / 2 + start + i * spacing
	$MuzzleFlash.restart()

	# 射击音效
	var world = get_tree().current_scene
	if world.has_method("play_sfx"):
		world.play_sfx("shoot", -14.0, 0.04)

func set_form(n):
	# 变形演出：换贴图 + 白闪 + 膨胀脉冲
	form = n
	$Sprite2D.texture = FORM_TEXTURES[n]
	modulate = Color(6, 6, 8)
	var tw = create_tween()
	tw.tween_property(self, "modulate", Color(1, 1, 1), 0.35)
	tw.parallel().tween_property(self, "scale", Vector2(1.35, 1.35), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, 0.3)
