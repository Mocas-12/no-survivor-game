extends Node2D

# 1. 引用模板场景
@export var enemy_scene: PackedScene = preload("res://enemy.tscn")
@export var gem_scene: PackedScene = preload("res://gem.tscn")
@export var hit_spark_scene: PackedScene = preload("res://hit_spk.tscn")

const RING_TEX := preload("res://assets/ring.png")
const SPARK_TEX := preload("res://assets/particle_spark.png")
const GOLD := Color(1, 0.84, 0.35)

# 2. 核心变量
var score = 0              # 积分
var health = 10            # 当前血量
var max_health = 10        # 血量上限（装甲强化会提高）
var xp = 0                 # 当前经验
var level = 1              # 当前等级
var xp_to_next = 5         # 升到下一级需要的经验
var pending_level_ups = 0  # 待选择的升级次数（一口气连升时排队）

# 3. 引用节点（名字必须和场景树里的名字完全一样）
@onready var player = $Player
@onready var camera = $Camera
@onready var flash_rect = $UI/LevelUpFlash
@onready var score_label = $UI/ScoreLabel
@onready var level_label = $UI/LevelLabel
@onready var xp_bar = $UI/XpBar
@onready var health_bar = $UI/HealthBar
@onready var game_over_panel = $UI/GameOverPanel
@onready var final_score_label = $UI/GameOverPanel/FinalScoreLabel
@onready var levelup_panel = $UI/LevelUpPanel
@onready var upgrade_buttons = [
	$UI/LevelUpPanel/Box/Buttons/Btn0,
	$UI/LevelUpPanel/Box/Buttons/Btn1,
	$UI/LevelUpPanel/Box/Buttons/Btn2,
]

# 升级强化池（在 _ready 里填充）
var upgrade_pool = []

# 特效共用的加法混合材质（发光感）
var add_mat: CanvasItemMaterial

func _ready():
	add_mat = CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	upgrade_pool = [
		{"title": "射速强化", "desc": "射击间隔 -20%", "apply": _upgrade_fire_rate, "can": func(): return player.fire_cooldown > 0.07},
		{"title": "威力强化", "desc": "子弹伤害 +1", "apply": _upgrade_damage, "can": func(): return true},
		{"title": "多重弹道", "desc": "同时多射一发", "apply": _upgrade_multishot, "can": func(): return player.bullet_count < 7},
		{"title": "疾跑强化", "desc": "移动速度 +12%", "apply": _upgrade_speed, "can": func(): return true},
		{"title": "装甲强化", "desc": "生命上限 +2，回复 4 点", "apply": _upgrade_health, "can": func(): return true},
	]
	# 三个升级按钮都连到同一个函数，用参数区分点的是哪个
	for i in upgrade_buttons.size():
		upgrade_buttons[i].pressed.connect(_on_upgrade_button_pressed.bind(i))

	# 游戏开始时初始化界面，隐藏结算栏和升级栏
	update_ui()
	game_over_panel.hide()
	levelup_panel.hide()

# --- 刷怪 ---

func _on_timer_timeout():
	var enemy = enemy_scene.instantiate()
	# 抢滩登陆：敌人从屏幕上方随机位置出现
	enemy.position = Vector2(randf_range(0, 1152), -80)
	enemy.setup(pick_enemy_type())
	enemy.died.connect(_on_enemy_died)
	add_child(enemy)

func pick_enemy_type() -> String:
	# 分数越高，强力敌人出现得越频繁
	var roll = randf()
	if score >= 150 and roll < 0.15:
		return "tank"
	if score >= 50 and roll < 0.45:
		return "fast"
	return "normal"

# --- 击杀与经验 ---

func _on_enemy_died(pos, value, fx_color):
	# 只有被打死的敌人会走到这里（撞玩家自杀的不发信号、不加分）
	score += value

	# 击杀演出：冲击波圆环 + 镜头轻震（坦克怪更震撼）
	spawn_ring(pos, fx_color, 0.35, 2.0, 0.35)
	camera.add_shake(6.0 if value >= 30 else 2.5)

	# 敌人死亡处掉落经验水晶（坦克怪更值钱）
	var gem = gem_scene.instantiate()
	gem.position = pos
	gem.xp_value = 3 if value >= 30 else 1
	add_child(gem)

	update_ui()

func add_xp(amount):
	xp += amount
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		xp_to_next = 5 + level * 3
		pending_level_ups += 1
	update_ui()
	if pending_level_ups > 0 and not levelup_panel.visible:
		show_level_up()

# --- 升级三选一 ---

func show_level_up():
	# 暂停游戏，弹出三选一面板，并播放"进化"演出
	get_tree().paused = true
	levelup_panel.show()
	if levelup_panel.has_method("animate_in"):
		levelup_panel.animate_in()

	flash_ui(GOLD, 0.5)
	spawn_ring(player.position, GOLD, 0.3, 3.2, 0.6)
	confetti_burst(player.position, 34)
	camera.add_shake(9.0)
	pulse_player()

	# 从可用强化里随机抽 3 个不重复的
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
		show_level_up()   # 一次攒了多级：继续选
	else:
		levelup_panel.hide()
		get_tree().paused = false

	# 选定强化后的小型进化演出
	spawn_ring(player.position, GOLD, 0.3, 1.8, 0.4)
	confetti_burst(player.position, 16)
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
	# 子弹命中的小火花
	var s := hit_spark_scene.instantiate()
	s.position = pos
	add_child(s)

func confetti_burst(pos: Vector2, amount: int):
	# 金色粒子迸发（升级时游戏是暂停的，所以设为 ALWAYS 保证能播放）
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
	p.color = GOLD
	p.position = pos
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.4).timeout.connect(p.queue_free)

func flash_ui(color: Color, peak: float):
	# 全屏闪光（例如升级时闪金光、死亡时闪红光）：快速亮起 → 缓慢消退
	flash_rect.color = Color(color.r, color.g, color.b, 0.0)
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(flash_rect, "color:a", peak, 0.07)
	tw.tween_property(flash_rect, "color:a", 0.0, 0.5)

func pulse_player():
	# 玩家进化脉冲：放大再弹回
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(player, "scale", Vector2(1.3, 1.3), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(player, "scale", Vector2.ONE, 0.3)

# --- 受伤与结算 ---

func take_damage(amount):
	health -= amount
	print("受到伤害！当前血量: ", health)
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

	# --- 动态难度 ---
	# 初始 0.9 秒一个怪，分数越高刷得越快，最快 0.3 秒一个
	$Timer.wait_time = max(0.3, 0.9 - score * 0.002)

func game_over():
	# 显示结算栏并暂停游戏逻辑，配红光 + 震屏
	final_score_label.text = "最终积分: %d    等级: %d" % [score, level]
	game_over_panel.show()
	if game_over_panel.has_method("animate_in"):
		game_over_panel.animate_in()
	flash_ui(Color(1, 0.25, 0.25), 0.4)
	camera.add_shake(12.0)
	get_tree().paused = true

# --- 结算栏按钮的功能代码 ---

func _on_restart_button_pressed():
	get_tree().paused = false          # 取消暂停
	get_tree().reload_current_scene()  # 重新加载当前关卡

func _on_quit_button_pressed():
	get_tree().quit()                  # 退出游戏
