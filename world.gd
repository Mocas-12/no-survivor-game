extends Node2D

# 1. 模板场景
@export var enemy_scene: PackedScene = preload("res://enemy.tscn")
@export var gem_scene: PackedScene = preload("res://gem.tscn")
@export var hit_spark_scene: PackedScene = preload("res://hit_spk.tscn")
@export var core_scene: PackedScene = preload("res://core.tscn")
@export var enemy_bullet_scene: PackedScene = preload("res://enemy_bullet.tscn")
@export var boss_scene: PackedScene = preload("res://boss.tscn")

const RING_TEX := preload("res://assets/ring.png")
const SOFT_TEX := preload("res://assets/particle_soft.png")
const SPARK_TEX := preload("res://assets/particle_spark.png")
const BGM := preload("res://assets/sounds/bgm.wav")
const GOLD := Color(1, 0.84, 0.35)
const CYAN := Color(0.55, 0.9, 1)

# 音效表（tools/gen_sounds.py 程序化合成）
const SFX := {
	"shoot": preload("res://assets/sounds/shoot.wav"),
	"hit": preload("res://assets/sounds/hit.wav"),
	"explode": preload("res://assets/sounds/explode.wav"),
	"pickup": preload("res://assets/sounds/pickup.wav"),
	"levelup": preload("res://assets/sounds/levelup.wav"),
	"transform": preload("res://assets/sounds/transform.wav"),
	"warning": preload("res://assets/sounds/warning.wav"),
	"boss_die": preload("res://assets/sounds/boss_die.wav"),
	"gameover": preload("res://assets/sounds/gameover.wav"),
}

# 2. 核心变量
var score = 0              # 积分
var health = 10            # 当前血量
var max_health = 10        # 血量上限
var xp = 0                 # 当前经验
var level = 1              # 当前等级
var xp_to_next = 5         # 升到下一级需要的经验
var pending_level_ups = 0  # 待选择的升级次数

# 3. 波次与 Boss
var kill_count = 0         # 累计击杀数
var next_boss_at = 25      # 击杀数达到该值触发 Boss 战
var boss_tier = 0          # 已出现的 Boss 次数（血量伤害递增）
var boss_active = false    # Boss 战进行中（停止刷小怪）
var last_hurt_ms = -10000  # 受伤无敌帧计时

# 4. 引用节点
@onready var player = $Player
@onready var camera = $Camera
@onready var flash_rect = $UI/LevelUpFlash
@onready var score_label = $UI/ScoreLabel
@onready var level_label = $UI/LevelLabel
@onready var xp_bar = $UI/XpBar
@onready var health_bar = $UI/HealthBar
@onready var warning_label = $UI/WarningLabel
@onready var boss_name_label = $UI/BossName
@onready var boss_bar = $UI/BossBar
@onready var start_panel = $UI/StartPanel
@onready var start_button = $UI/StartPanel/StartButton
@onready var game_over_panel = $UI/GameOverPanel
@onready var final_score_label = $UI/GameOverPanel/FinalScoreLabel
@onready var levelup_panel = $UI/LevelUpPanel
@onready var upgrade_buttons = [
	$UI/LevelUpPanel/Box/Buttons/Btn0,
	$UI/LevelUpPanel/Box/Buttons/Btn1,
	$UI/LevelUpPanel/Box/Buttons/Btn2,
]

# 升级强化池（12 张：基础 5 + 元素 4 + 弹道 3），每次升级随机抽 3 张
var upgrade_pool = []
var add_mat: CanvasItemMaterial
var bgm_player: AudioStreamPlayer

func _ready():
	add_mat = CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	upgrade_pool = [
		{"title": "射速强化", "desc": "射击间隔 -20%", "apply": _upgrade_fire_rate, "can": func(): return player.fire_cooldown > 0.06},
		{"title": "威力强化", "desc": "子弹伤害 +1", "apply": _upgrade_damage, "can": func(): return true},
		{"title": "多重弹道", "desc": "同时多射一发", "apply": _upgrade_multishot, "can": func(): return player.bullet_count < 7},
		{"title": "疾跑强化", "desc": "移动速度 +12%", "apply": _upgrade_speed, "can": func(): return true},
		{"title": "装甲强化", "desc": "生命上限 +2，回复 4 点", "apply": _upgrade_health, "can": func(): return true},
		{"title": "火焰弹头", "desc": "火元素：命中溅射邻近敌机", "apply": _upgrade_fire_element, "can": func(): return player.element != "fire"},
		{"title": "寒冰弹头", "desc": "冰元素：命中减速敌机", "apply": _upgrade_ice_element, "can": func(): return player.element != "ice"},
		{"title": "雷电弹头", "desc": "雷元素：链式电击邻近目标", "apply": _upgrade_lightning_element, "can": func(): return player.element != "lightning"},
		{"title": "疾风弹头", "desc": "风元素：弹速 +40% 并击退", "apply": _upgrade_wind_element, "can": func(): return player.element != "wind"},
		{"title": "精准直射", "desc": "切换为贯穿激光射线", "apply": _upgrade_stream, "can": func(): return player.pattern != "stream"},
		{"title": "扩散弹幕", "desc": "扇形张开，弹道 +1", "apply": _upgrade_wide, "can": func(): return player.spacing_scale < 1.6 and player.pattern != "stream"},
		{"title": "波浪弹道", "desc": "子弹蛇行，覆盖更广", "apply": _upgrade_wave, "can": func(): return player.pattern != "wave"},
	]
	for i in upgrade_buttons.size():
		upgrade_buttons[i].pressed.connect(_on_upgrade_button_pressed.bind(i))

	# 手机摇杆输入接入玩家
	$TouchUI.moved.connect(func(d): player.touch_move = d)

	# 背景音乐：无缝循环（等开始面板点击后再播放，满足浏览器音频手势要求）
	bgm_player = AudioStreamPlayer.new()
	var bgm_stream: AudioStreamWAV = BGM
	bgm_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	bgm_stream.loop_begin = 0
	bgm_stream.loop_end = bgm_stream.data.size() / 2
	bgm_player.stream = bgm_stream
	bgm_player.volume_db = -13.0
	add_child(bgm_player)

	update_ui()
	game_over_panel.hide()
	levelup_panel.hide()

	# 开始面板：等待玩家点击（解锁手机端音频 + 请求全屏）
	$TouchUI.reset()
	get_tree().paused = true
	start_panel.show()
	start_button.pressed.connect(_on_start_pressed)

# --- 音效 ---

func play_sfx(name: String, volume_db := 0.0, pitch_jitter := 0.05):
	var p = AudioStreamPlayer.new()
	p.stream = SFX[name]
	p.volume_db = volume_db
	p.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

# --- 刷怪 ---

func _on_timer_timeout():
	var enemy = enemy_scene.instantiate()
	# 抢滩登陆：敌机从屏幕上方随机位置出现
	enemy.position = Vector2(randf_range(0, 1152), -80)
	enemy.setup(pick_enemy_type())
	enemy.died.connect(_on_enemy_died)
	add_child(enemy)

func pick_enemy_type() -> String:
	# 分数越高，新兵种与强力兵种陆续登场
	var roll = randf()
	if score >= 150 and roll < 0.12:
		return "tank"
	if score >= 100 and roll < 0.24:
		return "shield"
	if score >= 60 and roll < 0.40:
		return "shooter"
	if score >= 40 and roll < 0.58:
		return "fast"
	if score >= 20 and roll < 0.76:
		return "swift"
	return "normal"

# --- 击杀与经验 ---

func _on_enemy_died(pos, value, fx_color):
	score += value
	kill_count += 1

	# 击杀演出：冲击波 + 音效 + 震屏
	spawn_ring(pos, fx_color, 0.35, 2.0, 0.35)
	play_sfx("explode", -8.0, 0.12)
	camera.add_shake(6.0 if value >= 30 else 2.5)

	# 敌机死亡处掉落经验水晶（重型机更值钱）
	var gem = gem_scene.instantiate()
	gem.position = pos
	gem.xp_value = 3 if value >= 30 else (2 if value >= 20 else 1)
	add_child(gem)

	update_ui()
	_maybe_boss()

func add_xp(amount):
	play_sfx("pickup", -10.0, 0.08)
	xp += amount
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		xp_to_next = 5 + level * 3
		pending_level_ups += 1
	update_ui()
	if pending_level_ups > 0 and not levelup_panel.visible:
		show_level_up()

# --- Boss 战 ---

func _maybe_boss():
	if boss_active or health <= 0:
		return
	if kill_count >= next_boss_at:
		_start_boss()

func _start_boss():
	boss_active = true
	$Timer.stop()  # Boss 战期间停止刷小怪
	play_sfx("warning", -2.0, 0.0)

	# 警报横幅闪烁 2.2 秒
	warning_label.text = "—— 第 %d 波 BOSS 来袭 ——" % (boss_tier + 1)
	warning_label.modulate.a = 1.0
	warning_label.show()
	var tw = create_tween()
	tw.set_loops(5)
	tw.tween_property(warning_label, "modulate:a", 0.15, 0.22)
	tw.tween_property(warning_label, "modulate:a", 1.0, 0.22)
	await get_tree().create_timer(2.2).timeout
	warning_label.hide()
	if health <= 0 or not is_inside_tree():
		boss_active = false
		return
	_spawn_boss()

func _spawn_boss():
	boss_tier += 1
	var boss = boss_scene.instantiate()
	var id = ((boss_tier - 1) % 5) + 1
	boss.setup(id, boss_tier)
	boss.died.connect(_on_boss_died)
	boss.hp_changed.connect(_on_boss_hp)
	add_child(boss)

	boss_name_label.text = "【 %s 】" % boss.boss_name()
	boss_name_label.show()
	boss_bar.max_value = boss.max_hp
	boss_bar.value = boss.max_hp
	boss_bar.show()

	spawn_ring(Vector2(576, 150), Color(1, 0.4, 0.4), 0.4, 3.0, 0.7)
	camera.add_shake(8.0)

func _on_boss_hp(hp, max_hp):
	boss_bar.max_value = max_hp
	boss_bar.value = hp

func _on_boss_died(pos):
	boss_active = false
	# 波次间隔：越来越久才遇到下一个 Boss
	next_boss_at = kill_count + 50 + boss_tier * 10
	boss_name_label.hide()
	boss_bar.hide()

	score += 150 + 50 * boss_tier
	play_sfx("boss_die")
	camera.add_shake(18.0)
	flash_ui(Color(1, 0.6, 0.3), 0.45)
	for i in 3:
		spawn_ring(pos + Vector2(randf_range(-60, 60), randf_range(-40, 40)), Color(1, 0.75, 0.4), 0.3, 2.4 + i * 0.8, 0.6)

	# 掉落核心装备：接住后战机渐进变形
	var core = core_scene.instantiate()
	core.position = pos
	core.form_target = mini(player.form + 1, 19)
	add_child(core)

	update_ui()
	$Timer.start()  # 恢复刷小怪

func spawn_enemy_bullet(pos, dir, speed, damage := 1, homing := 0.0, homing_time := 0.0):
	var b = enemy_bullet_scene.instantiate()
	b.position = pos
	b.dir = dir
	b.speed = speed
	b.damage = damage
	b.homing = homing
	b.homing_time = homing_time
	add_child(b)

func spawn_lightning(from: Vector2, to: Vector2):
	# 雷电链电弧：中间抖动的电光线
	var line = Line2D.new()
	line.default_color = Color(0.8, 0.7, 1)
	line.width = 3.0
	line.material = add_mat
	var mid = (from + to) / 2.0 + Vector2(randf_range(-14, 14), randf_range(-14, 14))
	line.points = PackedVector2Array([from, mid, to])
	add_child(line)
	var tw = line.create_tween()
	tw.tween_property(line, "modulate:a", 0.0, 0.12)
	tw.tween_callback(line.queue_free)

# --- 核心装备：渐进变形演出 ---

func apply_core(form):
	play_sfx("transform")
	flash_ui(CYAN, 0.35)
	camera.add_shake(8.0)
	confetti_burst(player.position, 24, CYAN)
	_apply_form_bonus(form)
	update_ui()

	# 连贯变形演出（不暂停）：旧机体收缩白化 → 光柱冲天 → 新机体弹性放大 → 回落
	var tw = create_tween()
	tw.tween_property(player, "scale", Vector2.ONE * 0.25, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(player, "modulate", Color(6, 6, 8), 0.18)
	tw.tween_callback(func():
		player.set_form(form)
		_spawn_evolution_beam()
		var tw2 = create_tween()
		tw2.tween_property(player, "modulate", Color(1, 1, 1), 0.18)
		tw2.parallel().tween_property(player, "scale", Vector2.ONE * player.base_scale * 1.35, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw2.tween_property(player, "scale", Vector2.ONE * player.base_scale, 0.2)
	)
	# 连环冲击波
	for i in 3:
		get_tree().create_timer(0.1 + i * 0.15, true).timeout.connect(func():
			if is_instance_valid(player):
				spawn_ring(player.position, CYAN if i % 2 == 0 else GOLD, 0.2, 2.0 + i * 0.5, 0.45))

func _spawn_evolution_beam():
	# 冲天光柱
	var beam = Sprite2D.new()
	beam.texture = SOFT_TEX
	beam.material = add_mat
	beam.position = player.position
	beam.scale = Vector2(0.45, 3.2)
	beam.modulate = Color(0.7, 0.95, 1, 0.9)
	add_child(beam)
	var tw = beam.create_tween()
	tw.set_parallel(true)
	tw.tween_property(beam, "scale", Vector2(1.1, 4.5), 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(beam, "modulate:a", 0.0, 0.5)
	tw.chain().tween_callback(beam.queue_free)

func _apply_form_bonus(n):
	# 每次变形的渐进成长：弹道/伤害/射速/生命交替增强
	if n % 2 == 1:
		player.bullet_count = mini(player.bullet_count + 1, 8)
	if n % 3 == 0:
		player.damage += 1
	player.fire_cooldown = maxf(0.055, player.fire_cooldown * 0.94)
	if n % 4 == 0:
		max_health += 2
		health = mini(health + 3, max_health)

# --- 升级三选一（12 张卡池随机抽 3） ---

func show_level_up():
	$TouchUI.reset()   # 暂停前复位摇杆，防止恢复后方向残留
	get_tree().paused = true
	levelup_panel.show()
	if levelup_panel.has_method("animate_in"):
		levelup_panel.animate_in()

	play_sfx("levelup", -4.0)
	flash_ui(GOLD, 0.5)
	spawn_ring(player.position, GOLD, 0.3, 3.2, 0.6)
	confetti_burst(player.position, 34, GOLD)
	camera.add_shake(9.0)
	pulse_player()

	var available = upgrade_pool.filter(func(u): return u["can"].call())
	available.shuffle()
	var choices = available.slice(0, 3)
	for i in upgrade_buttons.size():
		var up = choices[i]
		upgrade_buttons[i].text = up["title"] + "\n" + up["desc"]
		upgrade_buttons[i].set_meta("upgrade", up)

func _on_upgrade_button_pressed(index):
	var up = upgrade_buttons[index].get_meta("upgrade")
	up["apply"].call()
	pending_level_ups -= 1
	if pending_level_ups > 0:
		show_level_up()
	else:
		levelup_panel.hide()
		get_tree().paused = false

	spawn_ring(player.position, GOLD, 0.3, 1.8, 0.4)
	confetti_burst(player.position, 16, GOLD)
	camera.add_shake(5.0)
	pulse_player()

# --- 各种强化的具体效果 ---

func _upgrade_fire_rate():
	player.fire_cooldown = maxf(0.06, player.fire_cooldown * 0.8)

func _upgrade_damage():
	player.damage += 1

func _upgrade_multishot():
	player.bullet_count += 1

func _upgrade_speed():
	player.speed = int(player.speed * 1.12)

func _upgrade_health():
	max_health += 2
	health = min(health + 4, max_health)
	update_ui()

func _upgrade_fire_element():
	player.element = "fire"
	player.damage += 1

func _upgrade_ice_element():
	player.element = "ice"

func _upgrade_lightning_element():
	player.element = "lightning"

func _upgrade_wind_element():
	player.element = "wind"

func _upgrade_stream():
	player.pattern = "stream"

func _upgrade_wide():
	player.spacing_scale = 1.6
	player.bullet_count = mini(player.bullet_count + 1, 7)

func _upgrade_wave():
	player.pattern = "wave"

# --- 特效工具函数 ---

func spawn_ring(pos: Vector2, color: Color, from_scale: float, to_scale: float, dur: float):
	# 扩散冲击波圆环：放大 + 淡出后自毁
	var ring := Sprite2D.new()
	ring.texture = RING_TEX
	ring.material = add_mat
	ring.position = pos
	ring.modulate = color
	ring.scale = Vector2.ONE * from_scale
	add_child(ring)
	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2.ONE * to_scale, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "modulate:a", 0.0, dur)
	tw.chain().tween_callback(ring.queue_free)

func spawn_hit_spark(pos: Vector2):
	play_sfx("hit", -10.0, 0.15)
	var s := hit_spark_scene.instantiate()
	s.position = pos
	add_child(s)

func confetti_burst(pos: Vector2, amount: int, color: Color = GOLD):
	var p := CPUParticles2D.new()
	p.texture = SPARK_TEX
	p.amount = amount
	p.lifetime = 0.9
	p.one_shot = true
	p.explosiveness = 1.0
	p.spread = 180.0
	p.gravity = Vector2(0, 520)
	p.initial_velocity_min = 220.0
	p.initial_velocity_max = 480.0
	p.scale_amount_min = 0.3
	p.scale_amount_max = 0.7
	p.color = color
	p.position = pos
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.4).timeout.connect(p.queue_free)

func flash_ui(color: Color, peak: float):
	flash_rect.color = Color(color.r, color.g, color.b, 0.0)
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(flash_rect, "color:a", peak, 0.07)
	tw.tween_property(flash_rect, "color:a", 0.0, 0.5)

func pulse_player():
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(player, "scale", Vector2.ONE * player.base_scale * 1.3, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(player, "scale", Vector2.ONE * player.base_scale, 0.3)

# --- 受伤与结算 ---

func take_damage(amount):
	# 0.35 秒受伤无敌帧，避免被弹幕一帧多连击穿
	var now = Time.get_ticks_msec()
	if now - last_hurt_ms < 350:
		return
	last_hurt_ms = now

	health -= amount
	play_sfx("hit", -2.0, 0.15)
	player.modulate = Color(3, 0.6, 0.6)
	var tw := create_tween()
	tw.tween_property(player, "modulate", Color(1, 1, 1), 0.25)
	update_ui()
	if health <= 0:
		game_over()

func update_ui():
	if score_label:
		score_label.text = "积分: %d" % score
	if level_label:
		level_label.text = "等级 %d" % level
	if xp_bar:
		xp_bar.max_value = xp_to_next
		xp_bar.value = xp
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health
	# 动态难度：初始 0.9 秒一个怪，最快 0.3 秒一个
	$Timer.wait_time = max(0.3, 0.9 - score * 0.002)

func game_over():
	$TouchUI.reset()   # 暂停前复位摇杆
	final_score_label.text = "最终积分: %d    等级: %d" % [score, level]
	game_over_panel.show()
	if game_over_panel.has_method("animate_in"):
		game_over_panel.animate_in()
	flash_ui(Color(1, 0.25, 0.25), 0.4)
	camera.add_shake(12.0)
	play_sfx("gameover")
	get_tree().paused = true

# --- 开始面板 ---

func _on_start_pressed():
	start_panel.hide()
	get_tree().paused = false
	bgm_player.play()          # 在用户手势内启动音频（解锁手机端声音）
	_request_web_fullscreen()

func _request_web_fullscreen():
	# 手机浏览器：请求全屏并锁定横屏（部分浏览器可能拒绝，静默失败）
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("if(window.__requestGameFullscreen){window.__requestGameFullscreen();}", true)

# --- 结算栏按钮的功能代码 ---

func _on_restart_button_pressed():
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_quit_button_pressed():
	get_tree().quit()
