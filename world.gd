extends Node3D

# 1. 模板场景
@export var enemy_scene: PackedScene = preload("res://enemy.tscn")
@export var gem_scene: PackedScene = preload("res://gem.tscn")
@export var hit_spark_scene: PackedScene = preload("res://hit_spk.tscn")
@export var core_scene: PackedScene = preload("res://core.tscn")
@export var enemy_bullet_scene: PackedScene = preload("res://enemy_bullet.tscn")
@export var boss_scene: PackedScene = preload("res://boss.tscn")

const SPARK_TEX := preload("res://assets/particle_spark.png")
const BGM := preload("res://assets/sounds/bgm.wav")
const MB := preload("res://model_builder.gd")
const GOLD := Color(1, 0.84, 0.35)
const CYAN := Color(0.55, 0.9, 1)

# 形态特殊能力：每次变形按形态序号循环获得一种（20 形态 = 每种能力两轮）
const ABILITY_ORDER := ["nova", "overcharge", "frost", "flame", "magnet", "leech", "aegis", "thrust", "barrage", "gravity"]
const ABILITIES := {
	"nova": {"name": "引力新星", "color": Color(1, 0.55, 0.3)},      # 变形瞬间：冲击波重创周围敌机
	"overcharge": {"name": "超载射击", "color": Color(1, 0.85, 0.3)}, # 6 秒射速翻倍
	"frost": {"name": "寒霜力场", "color": Color(0.55, 0.85, 1)},     # 持续：冻结周围敌机
	"flame": {"name": "烈焰力场", "color": Color(1, 0.45, 0.2)},      # 持续：灼烧周围敌机
	"magnet": {"name": "磁力核心", "color": Color(0.45, 0.9, 1)},     # 持续：拾取磁吸范围翻倍
	"leech": {"name": "纳米修复", "color": Color(0.4, 0.95, 0.5)},    # 持续：击杀概率回复生命
	"aegis": {"name": "相位护盾", "color": Color(0.75, 0.55, 1)},     # 持续：受到的所有伤害 -1
	"thrust": {"name": "超频引擎", "color": Color(0.8, 0.95, 1)},     # 6 秒移速大幅提升
	"barrage": {"name": "弹幕风暴", "color": Color(1, 0.8, 0.25)},    # 6 秒 +1 弹道且射速提升
	"gravity": {"name": "引力井", "color": Color(0.45, 0.55, 1)},     # 持续：靠近主角的敌方子弹减速
}

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
var score = 0
var health = 10
var max_health = 10
var xp = 0
var level = 1
var xp_to_next = 5
var pending_level_ups = 0

# 3. 波次与 Boss
var kill_count = 0
var next_boss_at = 25
var boss_tier = 0
var boss_active = false
var last_hurt_ms = -10000
var regen_accum = 0.0   # 脱战回血的小数累积

# 3.5 形态能力
var ability := ""                # 当前形态能力 id（空 = 初始形态无能力）
var ability_aura: Node3D = null  # 持续型能力的光环
var ability_tick := 0.0          # 光环效果计时
var buff_kind := ""              # 限时增益类型
var buff_left := 0.0
var _buff_cooldown0 := 0.0
var _buff_speed0 := 0
var _buff_count0 := 0

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
@onready var ability_label = $UI/AbilityLabel
@onready var upgrade_buttons = [
	$UI/LevelUpPanel/Box/Buttons/Btn0,
	$UI/LevelUpPanel/Box/Buttons/Btn1,
	$UI/LevelUpPanel/Box/Buttons/Btn2,
]
@onready var star_mats = [
	$Background/Nebula.material_override,
	$Background/Far.material_override,
	$Background/Mid.material_override,
	$Background/Near.material_override,
]
var star_speeds := [16.0, 40.0, 90.0, 170.0]
var star_tex_h := [1024.0, 512.0, 512.0, 512.0]

# 升级强化池（12 张），每次升级随机抽 3 张
var upgrade_pool = []
var bgm_player: AudioStreamPlayer

func _ready():
	# 预热全部飞船模型与涂装：变形换装零加载卡顿
	MB.warm_up()
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
		{"title": "追踪导弹", "desc": "发射自动追踪敌机的导弹", "apply": _upgrade_homing, "can": func(): return player.pattern != "homing"},
		{"title": "扩散弹幕", "desc": "扇形张开，弹道 +1", "apply": _upgrade_wide, "can": func(): return player.spacing_scale < 1.6 and player.pattern != "homing"},
		{"title": "波浪弹道", "desc": "子弹蛇行，覆盖更广", "apply": _upgrade_wave, "can": func(): return player.pattern != "wave"},
	]
	for i in upgrade_buttons.size():
		upgrade_buttons[i].pressed.connect(_on_upgrade_button_pressed.bind(i))

	# 手机摇杆输入接入玩家
	$TouchUI.moved.connect(func(d): player.touch_move = d)

	# 背景音乐：导入时已设置无缝循环（bgm.wav.import loop_mode=1），
	# 播完自动重播作为保险（等开始面板点击后再播放，满足浏览器音频手势要求）
	bgm_player = AudioStreamPlayer.new()
	bgm_player.stream = BGM
	bgm_player.volume_db = -13.0
	add_child(bgm_player)
	bgm_player.finished.connect(func(): bgm_player.play())

	update_ui()
	game_over_panel.hide()
	levelup_panel.hide()

	# 开始面板：等待玩家点击（解锁手机端音频 + 请求全屏）
	$TouchUI.reset()
	get_tree().paused = true
	start_panel.show()

func _process(delta):
	# 多层星空向下滚动（UV 偏移驱动）
	for i in star_mats.size():
		star_mats[i].uv1_offset.y -= star_speeds[i] * delta / star_tex_h[i]
	# 脱战回血：4 秒未受击后，每 1.2 秒缓慢回复 1 点
	var now_ms = Time.get_ticks_msec()
	if health > 0 and health < max_health and now_ms - last_hurt_ms > 4000:
		regen_accum += delta / 1.2
		if regen_accum >= 1.0:
			regen_accum -= 1.0
			health = mini(health + 1, max_health)
			update_ui()
	# 限时增益倒计时
	if buff_left > 0.0:
		buff_left -= delta
		if buff_left <= 0.0:
			_end_buff()
	# 持续型能力光环：冻结 / 灼烧周围敌机
	if ability == "frost" or ability == "flame":
		ability_tick -= delta
		if ability_tick <= 0.0:
			ability_tick = 0.4
			var radius := 250.0 if ability == "frost" else 210.0
			for m in get_tree().get_nodes_in_group("mobs"):
				if m.dead:
					continue
				if m.global_position.distance_to(player.global_position) > radius:
					continue
				if ability == "frost" and m.has_method("slow_down"):
					m.slow_down(0.45)
				elif ability == "flame" and m.has_method("take_damage"):
					m.take_damage(1)

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
	enemy.position = Vector3(randf_range(-576.0, 576.0), 404.0, 0.0)
	enemy.setup(pick_enemy_type())
	enemy.died.connect(_on_enemy_died)
	add_child(enemy)

func pick_enemy_type() -> String:
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

func _on_enemy_died(pos: Vector3, value, fx_color):
	score += value
	kill_count += 1

	# 纳米修复：击杀有概率回复 1 点生命
	if ability == "leech" and health > 0 and health < max_health and randf() < 0.1:
		health = mini(health + 1, max_health)

	# 击杀演出：3D 爆炸粒子 + 冲击波环 + 音效 + 震屏
	spawn_explosion(pos, fx_color, value >= 30)
	spawn_ring(pos, fx_color, 0.35, 2.0, 0.35)
	play_sfx("explode", -8.0, 0.12)
	camera.add_shake(6.0 if value >= 30 else 2.5)

	# 掉落经验水晶
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
	$Timer.stop()
	play_sfx("warning", -2.0, 0.0)

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

	spawn_ring(Vector3(0, 174, 0), Color(1, 0.4, 0.4), 0.4, 3.0, 0.7)
	camera.add_shake(8.0)

func _on_boss_hp(hp, max_hp):
	boss_bar.max_value = max_hp
	boss_bar.value = hp

func _on_boss_died(pos: Vector3):
	boss_active = false
	next_boss_at = kill_count + 50 + boss_tier * 10
	boss_name_label.hide()
	boss_bar.hide()

	score += 150 + 50 * boss_tier
	play_sfx("boss_die")
	camera.add_shake(18.0)
	flash_ui(Color(1, 0.6, 0.3), 0.45)
	for i in 3:
		spawn_ring(pos + Vector3(randf_range(-60, 60), randf_range(-40, 40), 0.0), Color(1, 0.75, 0.4), 0.3, 2.4 + i * 0.8, 0.6)

	# 掉落核心装备：接住后战机渐进变形
	var core = core_scene.instantiate()
	core.position = pos
	core.form_target = mini(player.form + 1, 19)
	add_child(core)

	update_ui()
	$Timer.start()

func spawn_enemy_bullet(pos: Vector3, dir: Vector3, speed, damage := 1, homing := 0.0, homing_time := 0.0):
	var b = enemy_bullet_scene.instantiate()
	b.position = pos
	b.dir = dir
	b.speed = speed
	b.damage = damage
	b.homing = homing
	b.homing_time = homing_time
	add_child(b)

func spawn_lightning(from: Vector3, to: Vector3):
	# 逼真闪电：抖折主放电通道 + 两条随机分支，二次闪烁后消散
	_lightning_channel(from, to, 3.4)
	for i in 2:
		var anchor = from.lerp(to, randf_range(0.3, 0.7))
		var branch_dir = Vector3(randf_range(-1, 1), randf_range(-0.4, 1), randf_range(-1, 1)).normalized()
		_lightning_channel(anchor, anchor + branch_dir * from.distance_to(to) * randf_range(0.2, 0.38), 1.7)

func _lightning_channel(from: Vector3, to: Vector3, width: float):
	var dist = from.distance_to(to)
	if dist < 1.0:
		return
	var root := Node3D.new()
	add_child(root)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.9, 0.86, 1.0, 0.95)
	m.emission_enabled = true
	m.emission = Color(0.72, 0.58, 1.0)
	m.emission_energy_multiplier = 3.4
	# 中点位移：沿通道逐段向随机侧向抖折，形成锯齿放电
	var steps = maxi(int(dist / 24.0), 3)
	var prev = from
	for i in steps:
		var endp = from.lerp(to, float(i + 1) / steps)
		if i < steps - 1:
			var jitter = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))
			endp += jitter.cross(to - from).normalized() * randf_range(-16.0, 16.0)
		var seg_len = prev.distance_to(endp)
		if seg_len > 0.5:
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(width, width, 1.0)
			mi.mesh = bm
			mi.material_override = m
			root.add_child(mi)
			var dirv = (endp - prev).normalized()
			var up := Vector3.UP
			if absf(dirv.dot(up)) > 0.98:
				up = Vector3(0, 0, 1)
			mi.look_at_from_position((prev + endp) * 0.5, endp, up)
			mi.scale = Vector3(1, 1, seg_len)
		prev = endp
	# 闪烁：亮 → 短暂变暗 → 回亮 → 淡出
	var tw := root.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.3, 0.05)
	tw.tween_property(m, "albedo_color:a", 0.9, 0.03)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.1)
	tw.tween_callback(root.queue_free)

# --- 核心装备：连贯 3D 变形演出 ---

func apply_core(form):
	play_sfx("transform")
	flash_ui(CYAN, 0.35)
	camera.add_shake(8.0)
	confetti_burst(player.position, 24, CYAN)
	_end_buff()   # 旧形态的限时增益随变形结束
	_apply_form_bonus(form)
	update_ui()

	# 渐进变形（不暂停）：机体收缩 → 能量茧包裹 → 茧内脉冲重塑 → 破茧揭示新形态 + 形态能力
	var accent: Color = MB.ACCENTS[form % MB.ACCENTS.size()]
	var tw = create_tween()
	tw.tween_property(player, "scale", Vector3.ONE * 0.22, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func(): _morph_cocoon(form, accent))
	# 连环冲击波
	for i in 3:
		get_tree().create_timer(0.1 + i * 0.15, true).timeout.connect(func():
			if is_instance_valid(player):
				spawn_ring(player.position, CYAN if i % 2 == 0 else GOLD, 0.2, 2.0 + i * 0.5, 0.45))

func _morph_cocoon(form, accent: Color):
	# 能量茧：包裹收缩的机体，颜色从青色渐变为新形态主题色，三次脉冲后破茧
	var cocoon := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 30.0
	sm.height = 60.0
	cocoon.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(CYAN.r, CYAN.g, CYAN.b, 0.0)
	m.emission_enabled = true
	m.emission = CYAN
	m.emission_energy_multiplier = 2.2
	cocoon.material_override = m
	cocoon.position = player.position
	add_child(cocoon)

	player.set_form(form)

	var tw := cocoon.create_tween()
	# 包裹：茧体胀起并显现
	tw.tween_property(m, "albedo_color:a", 0.68, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(cocoon, "scale", Vector3.ONE * 1.32, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# 茧色渐变 → 新形态的主题色（形态特征预兆）
	tw.tween_property(m, "albedo_color", Color(accent.r, accent.g, accent.b, 0.68), 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(m, "emission", accent, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# 三次重塑脉冲：新形态在茧内平滑地逐次成形
	for i in 3:
		tw.tween_property(cocoon, "scale", Vector3.ONE * (1.24 + 0.1 * i), 0.13).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(cocoon, "scale", Vector3.ONE * 1.32, 0.13).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# 破茧：能量迸发，新机体翻滚着登场，同时激活本形态特殊能力
	tw.tween_callback(func():
		spawn_explosion(cocoon.position, accent, false)
		spawn_ring(cocoon.position, accent, 0.3, 2.6, 0.5)
		confetti_burst(cocoon.position, 18, accent)
		cocoon.queue_free()
		_spawn_reveal()
		_activate_ability(form))

func _spawn_reveal():
	_spawn_evolution_beam()
	var tw2 = create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(player.model, "rotation_degrees:y", 360.0, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw2.tween_property(player, "scale", Vector3.ONE * player.base_scale * 1.32, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw2.chain().tween_property(player, "scale", Vector3.ONE * player.base_scale, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# --- 形态特殊能力 ---

func _activate_ability(form: int):
	_end_buff()
	ability = ABILITY_ORDER[form % ABILITY_ORDER.size()]
	var info: Dictionary = ABILITIES[ability]
	var col: Color = info["color"]
	# 持续型能力：主角身上挂常驻能力光环
	if ability_aura:
		ability_aura.queue_free()
		ability_aura = null
	match ability:
		"frost", "flame", "magnet", "gravity", "aegis":
			ability_aura = MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = 31.0
			torus.outer_radius = 35.0
			ability_aura.mesh = torus
			var am := StandardMaterial3D.new()
			am.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			am.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			am.albedo_color = Color(col.r, col.g, col.b, 0.42)
			am.emission_enabled = true
			am.emission = col
			am.emission_energy_multiplier = 1.7
			ability_aura.material_override = am
			ability_aura.rotation_degrees = Vector3(90, 0, 0)
			player.add_child(ability_aura)
	player.set_meta("magnet_mul", 2.2 if ability == "magnet" else 1.0)
	# 公告横幅
	ability_label.text = "✦ 形态能力 · %s ✦" % info["name"]
	ability_label.modulate = Color(col.r, col.g, col.b, 0.0)
	ability_label.show()
	var tw := ability_label.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(ability_label, "modulate:a", 1.0, 0.25)
	tw.tween_interval(1.7)
	tw.tween_property(ability_label, "modulate:a", 0.0, 0.4)
	tw.tween_callback(ability_label.hide)
	# 能力入场特效
	spawn_ring(player.position, col, 0.3, 3.0, 0.55)
	confetti_burst(player.position, 16, col)
	match ability:
		"nova":
			# 引力新星：变形瞬间冲击波重创周围敌机
			spawn_ring(player.position, col, 0.5, 5.2, 0.7)
			camera.add_shake(10.0)
			for m in get_tree().get_nodes_in_group("mobs"):
				if m.dead:
					continue
				if m.global_position.distance_to(player.global_position) < 430.0:
					if m.has_method("take_damage"):
						m.take_damage(12)
					if m.has_method("knockback"):
						var away = (m.global_position - player.global_position).normalized()
						m.knockback(Vector3(away.x, away.y, 0) * 70.0)
		"overcharge":
			_start_buff("overcharge", 6.0)
		"thrust":
			_start_buff("thrust", 6.0)
		"barrage":
			_start_buff("barrage", 6.0)

func _start_buff(kind: String, dur: float):
	_end_buff()
	buff_kind = kind
	buff_left = dur
	match kind:
		"overcharge":
			_buff_cooldown0 = player.fire_cooldown
			player.fire_cooldown = maxf(0.045, player.fire_cooldown * 0.5)
		"thrust":
			_buff_speed0 = player.speed
			player.speed = int(player.speed * 1.6)
		"barrage":
			_buff_cooldown0 = player.fire_cooldown
			_buff_count0 = player.bullet_count
			player.bullet_count = mini(player.bullet_count + 1, 9)
			player.fire_cooldown = maxf(0.045, player.fire_cooldown * 0.75)

func _end_buff():
	if buff_kind == "":
		return
	match buff_kind:
		"overcharge", "barrage":
			player.fire_cooldown = _buff_cooldown0
		"thrust":
			player.speed = _buff_speed0
	if buff_kind == "barrage":
		player.bullet_count = _buff_count0
	buff_kind = ""
	buff_left = 0.0

func _spawn_evolution_beam():
	# 冲天光柱
	var mi = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 10.0
	cm.bottom_radius = 26.0
	cm.height = 760.0
	mi.mesh = cm
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.6, 0.9, 1, 0.5)
	m.emission_enabled = true
	m.emission = Color(0.6, 0.9, 1)
	m.emission_energy_multiplier = 1.8
	mi.material_override = m
	mi.position = player.position + Vector3(0, 320, 0)
	add_child(mi)
	var tw = mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(2.2, 1.15, 2.2), 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.5)
	tw.chain().tween_callback(mi.queue_free)

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
	player.fire_cooldown = maxf(0.055, player.fire_cooldown * 0.8)

func _upgrade_damage():
	player.damage += 1

func _upgrade_multishot():
	player.bullet_count = mini(player.bullet_count + 1, 8)

func _upgrade_speed():
	player.speed = int(player.speed * 1.12)

func _upgrade_health():
	max_health += 2
	health = mini(health + 3, max_health)

func _upgrade_fire_element():
	player.element = "fire"
	player.damage += 1

func _upgrade_ice_element():
	player.element = "ice"

func _upgrade_lightning_element():
	player.element = "lightning"

func _upgrade_wind_element():
	player.element = "wind"

func _upgrade_homing():
	player.pattern = "homing"

func _upgrade_wide():
	player.spacing_scale = 1.6
	player.bullet_count = mini(player.bullet_count + 1, 8)

func _upgrade_wave():
	player.pattern = "wave"

# --- 特效工具函数 ---

func spawn_ring(pos: Vector3, color: Color, from_scale: float, to_scale: float, dur: float):
	# 3D 冲击波圆环：放大 + 淡出后自毁
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 9.0
	torus.outer_radius = 11.0
	ring.mesh = torus
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 1.8
	ring.material_override = m
	ring.position = pos
	ring.rotation_degrees = Vector3(90, 0, 0)
	ring.scale = Vector3.ONE * from_scale
	add_child(ring)
	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3.ONE * to_scale, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, dur)
	tw.chain().tween_callback(ring.queue_free)

func spawn_explosion(pos: Vector3, color: Color, big := false):
	var p := CPUParticles3D.new()
	p.amount = 40 if big else 22
	p.lifetime = 0.55
	p.one_shot = true
	p.explosiveness = 1.0
	p.spread = 180.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 130.0
	p.initial_velocity_max = 320.0
	p.scale_amount_min = 1.2
	p.scale_amount_max = 3.2 if big else 2.2
	var m := SphereMesh.new()
	m.radius = 2.6
	m.height = 5.2
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.albedo_color = color
	mm.emission_enabled = true
	mm.emission = color
	mm.emission_energy_multiplier = 2.0
	m.material = mm
	p.mesh = m
	p.position = pos
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)

func spawn_hit_spark(pos: Vector3):
	play_sfx("hit", -10.0, 0.15)
	var s := hit_spark_scene.instantiate()
	s.position = pos
	add_child(s)

func confetti_burst(pos: Vector3, amount: int, color: Color = GOLD):
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = 0.9
	p.one_shot = true
	p.explosiveness = 1.0
	p.spread = 180.0
	p.gravity = Vector3(0, -500, 0)
	p.initial_velocity_min = 220.0
	p.initial_velocity_max = 480.0
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.8
	var m := BoxMesh.new()
	m.size = Vector3(2.2, 2.2, 2.2)
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.albedo_color = color
	mm.emission_enabled = true
	mm.emission = color
	mm.emission_energy_multiplier = 2.0
	m.material = mm
	p.mesh = m
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
	tw.tween_property(player, "scale", Vector3.ONE * player.base_scale * 1.3, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(player, "scale", Vector3.ONE * player.base_scale, 0.3)

# --- 受伤与结算 ---

func take_damage(amount):
	# 0.35 秒受伤无敌帧，避免被弹幕一帧多连击穿
	var now = Time.get_ticks_msec()
	if now - last_hurt_ms < 350:
		return
	last_hurt_ms = now

	# 相位护盾：所有伤害 -1（最低 1）
	if ability == "aegis":
		amount = maxi(1, amount - 1)
	health -= amount
	play_sfx("hit", -2.0, 0.15)
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
	$TouchUI.reset()
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
