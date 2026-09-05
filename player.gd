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
const BulletScript := preload("res://bullet.gd")
const LASER_LOOP := preload("res://assets/sounds/laser.wav")
var fire_timer = 0.0
var use_touch = false   # 触屏设备：摇杆专属移动，不回退到鼠标跟随
var beam: Node2D = null           # 激光束节点（精准直射模式）
var beam_glow: Line2D = null
var beam_core: Line2D = null
var beam_audio: AudioStreamPlayer = null
var beam_cd = 0.0                 # 激光伤害节拍（10Hz）
var beam_spark_t = 0.0            # 激光命中火花节拍

const ELEMENT_COLORS := {
	"normal": Color(1, 1, 1),
	"fire": Color(1, 0.62, 0.35),
	"ice": Color(0.6, 0.9, 1),
	"lightning": Color(0.78, 0.62, 1),
	"wind": Color(0.62, 1, 0.62),
}

func _ready():
	use_touch = DisplayServer.is_touchscreen_available()
	_update_base_scale()
	scale = Vector2.ONE * base_scale
	_build_beam()
	# 激光循环音
	beam_audio = AudioStreamPlayer.new()
	var laser_stream: AudioStreamWAV = LASER_LOOP
	laser_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	laser_stream.loop_begin = 0
	laser_stream.loop_end = laser_stream.data.size() / 2
	beam_audio.stream = laser_stream
	beam_audio.volume_db = -16.0
	add_child(beam_audio)

func _build_beam():
	# 激光束：双层加法发光线（外层辉光 + 内层白芯）
	var add = CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	beam = Node2D.new()
	beam.position = Vector2(0, -44)
	beam.visible = false
	beam_glow = Line2D.new()
	beam_glow.points = PackedVector2Array([Vector2.ZERO, Vector2(0, -1200)])
	beam_glow.width = 44.0
	beam_glow.default_color = Color(0.6, 0.9, 1, 0.3)
	beam_glow.material = add
	beam_core = Line2D.new()
	beam_core.points = PackedVector2Array([Vector2.ZERO, Vector2(0, -1200)])
	beam_core.width = 10.0
	beam_core.default_color = Color(1, 1, 1, 0.95)
	beam_core.material = add
	beam.add_child(beam_glow)
	beam.add_child(beam_core)
	add_child(beam)

func _physics_process(delta):
	# 移动：触屏设备由摇杆驱动（无输入时悬停）；桌面端平滑跟随鼠标
	if use_touch:
		global_position += touch_move * speed * 1.25 * delta
	else:
		global_position = global_position.move_toward(get_global_mouse_position(), follow_speed * delta)
	var screen = get_viewport_rect().size
	global_position = global_position.clamp(Vector2(26, 26), screen - Vector2(26, 26))

	# 攻击：精准直射为持续激光，其他模式为间隔连射
	var firing = Input.is_action_pressed("shoot")
	if firing and pattern == "stream":
		_fire_beam(delta)
		if not beam_audio.playing:
			beam_audio.play()
	else:
		if beam.visible:
			beam.visible = false
		if beam_audio.playing:
			beam_audio.stop()
		fire_timer -= delta
		if firing and fire_timer <= 0:
			shoot()
			fire_timer = fire_cooldown

# --- 激光射线（贯穿：对走廊内所有目标持续造成伤害） ---
func _fire_beam(delta):
	beam.visible = true
	# 激光颜色随元素变化 + 呼吸脉动；宽度补偿主角缩放，保持屏幕宽度恒定
	var ec: Color = ELEMENT_COLORS[element]
	beam_glow.default_color = Color(ec.r, ec.g, ec.b, 0.4)
	beam_core.default_color = Color(1.0, 1.0, 1.0, 0.95)
	beam_glow.width = 44.0 / player.scale.x
	beam_core.width = 10.0 / player.scale.x
	beam.modulate.a = 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.02)
	beam_cd -= delta
	beam_spark_t -= delta
	var world = get_tree().current_scene
	if beam_cd <= 0.0:
		beam_cd = 0.1
		var origin_x = global_position.x
		var origin_y = global_position.y - 44.0
		var hit_any = false
		for m in get_tree().get_nodes_in_group("mobs"):
			if m.dead:
				continue
			if origin_y - m.global_position.y > 0.0 and absf(m.global_position.x - origin_x) <= 24.0:
				var amt = damage * 0.4
				if m.has_method("take_damage_silent"):
					m.take_damage_silent(amt)
				elif m.has_method("take_damage"):
					m.take_damage(amt)
				if element == "ice" and m.has_method("slow_down"):
					m.slow_down(0.2)
				hit_any = true
				if beam_spark_t <= 0.0 and world.has_method("spawn_hit_spark"):
					world.spawn_hit_spark(m.global_position)
		if hit_any:
			beam_spark_t = 0.18

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
