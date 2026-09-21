extends Node3D

# 1. 模板场景
@export var enemy_scene: PackedScene = preload("res://scenes/enemy.tscn")
@export var gem_scene: PackedScene = preload("res://scenes/gem.tscn")
@export var hit_spark_scene: PackedScene = preload("res://scenes/hit_spk.tscn")
@export var core_scene: PackedScene = preload("res://scenes/core.tscn")
@export var enemy_bullet_scene: PackedScene = preload("res://scenes/enemy_bullet.tscn")
@export var boss_scene: PackedScene = preload("res://scenes/boss.tscn")

const BGM := preload("res://assets/sounds/bgm.wav")
const BulletScene := preload("res://scenes/bullet.tscn")
const BulletScript := preload("res://scripts/bullet.gd")
const MB := preload("res://scripts/model_builder.gd")
const I18n := preload("res://scripts/i18n.gd")
const SaveGame := preload("res://scripts/save.gd")
const Fx := preload("res://scripts/fx.gd")
const Upgrades := preload("res://scripts/upgrades.gd")
const SpawnDirector := preload("res://scripts/spawn_director.gd")
const FormAbility := preload("res://scripts/form_ability.gd")
const GOLD := Color(1, 0.84, 0.35)
const CYAN := Color(0.55, 0.9, 1)
const UI_FONT := preload("res://assets/fonts/ZCOOLKuaiLe-Regular.ttf")

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
var high_score = 0
var is_new_record = false

# 3. 波次与 Boss
var kill_count = 0
var next_boss_at = 25
var boss_tier = 0
var boss_active = false
var omega_armed = false    # 第 10 波 Boss 被击破后待命：下一波为终局 OMEGA
var omega_slain = false    # OMEGA 已被击破（本局胜利，之后进入无尽）
var last_hurt_ms = -10000
var regen_accum = 0.0   # 脱战回血的小数累积
var dying = false       # 主角阵亡演出中（结算面板尚未弹出）
var run_time := 0.0     # 本局战斗时长（暂停/升级/演出不计）

# 3.5 形态能力
var ability := ""                # 当前形态能力 id（空 = 初始形态无能力）
var ability_tick := 0.0          # 光环效果计时
var buff_kind := ""              # 限时增益类型
var buff_left := 0.0
var _buff_cooldown0 := 0.0
var _buff_speed0 := 0
var _buff_count0 := 0
var _prebuilt_model: Node3D = null  # 变形预建的新机体（提前分摊构建开销）
var _cocoon: MeshInstance3D = null  # 变形能量茧（每帧跟随主角，防止飞出光圈）
var _aura: Node3D = null            # 能力常驻光环（跟随主角的世界空间节点）
var _aura_spinners: Array = []      # [粒子节点, 角速度]：旋转发射器实现轨道环绕
var _flake_mesh: QuadMesh = null   # 寒霜细雪片网格（缓存，form_ability.gd 使用）

# 3.6 卡牌与被动（升级系统 / 存档设置）
var card_taken := {}             # 卡 id → 已选次数（可叠加卡显示 Lv.N）
var magnet_range_mul := 1.0      # 水晶/核心磁吸范围倍率（磁力强化卡）
var xp_mul := 1.0                # 经验获取倍率（精英学员卡）
var revive_charges := 0          # 凤凰模块复活的次数
var muted := false               # 声音开关（存档）
var reduce_fx := false           # 减少闪光/震屏（存档，光敏友好）
var formation_cd := 12.0         # 编队波次倒计时
var homing_charges := 0          # 追踪导弹道具（每击破一个 Boss +1，点击释放）

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
@onready var start_high_label = $UI/StartPanel/HighScoreLabel
@onready var game_over_panel = $UI/GameOverPanel
@onready var final_score_label = $UI/GameOverPanel/FinalScoreLabel
@onready var record_label = $UI/GameOverPanel/RecordLabel
@onready var victory_panel = $UI/VictoryPanel
@onready var victory_stats_label = $UI/VictoryPanel/Box/StatsLabel
@onready var levelup_panel = $UI/LevelUpPanel
@onready var ability_label = $UI/AbilityLabel
@onready var ability_chip = $UI/AbilityChip
@onready var buff_bar = $UI/BuffBar
@onready var pause_button = $UI/PauseButton
@onready var pause_panel = $UI/PausePanel
@onready var homing_btn = $UI/HomingButton
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

# 升级卡池（upgrades.gd），每次升级随机抽 3 张
var upgrade_pool = []
var bgm_player: AudioStreamPlayer

func _ready():
	Engine.time_scale = 1.0
	# 预热全部飞船模型与涂装：变形换装零加载卡顿
	MB.warm_up()
	# 音效播放器对象池（暂停菜单/开始面板期间音效不中断）
	for i in 14:
		var p := AudioStreamPlayer.new()
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_sfx_pool.append(p)
	upgrade_pool = Upgrades.build(self)

	# 存档：最高分 + 声音 / 减少闪光设置 + OMEGA 徽章
	var data := SaveGame.load_data()
	high_score = int(data.get("high", 0))
	muted = bool(data.get("mute", false))
	reduce_fx = bool(data.get("reduce_fx", false))
	AudioServer.set_bus_mute(0, muted)
	if high_score > 0 or bool(data.get("omega", false)):
		start_high_label.show()
		var lines := ""
		if high_score > 0:
			lines = I18n.T("high") % high_score
		if bool(data.get("omega", false)):
			lines += ("\n" if lines != "" else "") + "🏆 " + I18n.T("start_omega")
		start_high_label.text = lines
	else:
		start_high_label.hide()

	# 双语文案（按系统语言自动选择，见 i18n.gd）
	$UI/GameOverPanel/Label.text = I18n.T("game_over")
	$UI/GameOverPanel/RestartButton.text = I18n.T("btn_restart")
	$UI/GameOverPanel/QuitButton.text = I18n.T("btn_quit")
	$UI/VictoryPanel/Title.text = I18n.T("victory_title")
	$UI/VictoryPanel/Sub.text = I18n.T("victory_sub")
	$UI/VictoryPanel/Box/EndlessButton.text = I18n.T("btn_endless")
	$UI/VictoryPanel/Box/RestartButton.text = I18n.T("btn_restart")
	$UI/VictoryPanel/Box/QuitButton.text = I18n.T("btn_quit")
	$UI/LevelUpPanel/Box/Title.text = I18n.T("levelup_title")
	$UI/StartPanel/Title.text = I18n.T("start_title")
	$UI/StartPanel/Hint.text = I18n.T("start_hint")
	if muted:
		# 静音状态会持久化：在开始面板上明示，避免"游戏没声音"的误会
		$UI/StartPanel/Hint.text += "\n" + I18n.T("muted_hint")
	start_button.text = I18n.T("btn_start")
	pause_button.text = I18n.T("btn_pause_mini")
	$UI/PausePanel/Title.text = I18n.T("pause_title")
	$UI/PausePanel/Box/ResumeButton.text = I18n.T("btn_resume")
	$UI/PausePanel/Box/RestartButton.text = I18n.T("btn_restart")
	$UI/PausePanel/Box/QuitButton.text = I18n.T("btn_quit")
	_update_pause_labels()

	for i in upgrade_buttons.size():
		upgrade_buttons[i].pressed.connect(_on_upgrade_button_pressed.bind(i))
	pause_button.pressed.connect(_open_pause)
	homing_btn.pressed.connect(_use_homing)
	pause_panel.esc_pressed.connect(_close_pause)
	$UI/PausePanel/Box/ResumeButton.pressed.connect(_close_pause)
	$UI/PausePanel/Box/RestartButton.pressed.connect(_on_restart_button_pressed)
	$UI/PausePanel/Box/SoundButton.pressed.connect(_on_sound_toggled)
	$UI/PausePanel/Box/FxButton.pressed.connect(_on_fx_toggled)
	$UI/PausePanel/Box/QuitButton.pressed.connect(_on_quit_button_pressed)
	$UI/VictoryPanel/Box/EndlessButton.pressed.connect(_continue_endless)
	$UI/VictoryPanel/Box/RestartButton.pressed.connect(_on_restart_button_pressed)
	$UI/VictoryPanel/Box/QuitButton.pressed.connect(_on_quit_button_pressed)

	# 手机摇杆输入接入玩家
	$TouchUI.moved.connect(func(d): player.touch_move = d)

	# 背景音乐：导入时已设置无缝循环（bgm.wav.import loop_mode=1），播完自动重播作为保险。
	# 初始即播放且不受暂停影响（桌面端立即可闻）；网页端受浏览器手势限制，点击开始后自动接上
	bgm_player = AudioStreamPlayer.new()
	bgm_player.stream = BGM
	bgm_player.volume_db = -13.0
	bgm_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(bgm_player)
	bgm_player.finished.connect(func(): bgm_player.play())
	bgm_player.play()

	update_ui()
	game_over_panel.hide()
	victory_panel.hide()
	levelup_panel.hide()
	pause_panel.hide()
	pause_button.hide()

	# 开始面板：等待玩家点击（解锁手机端音频 + 请求全屏）
	$TouchUI.reset()
	get_tree().paused = true
	start_panel.show()

func _process(delta):
	# 多层星空向下滚动（UV 偏移驱动）
	for i in star_mats.size():
		star_mats[i].uv1_offset.y -= star_speeds[i] * delta / star_tex_h[i]
	# 形态能力系统：能量茧/光环跟随 + 限时增益 + 持续型脉冲（实现在 form_ability.gd）
	FormAbility.process(self, delta)
	if dying:
		return
	run_time += delta
	# 脱战回血：4 秒未受击后，每 1.2 秒缓慢回复 1 点
	var now_ms = Time.get_ticks_msec()
	if health > 0 and health < max_health and now_ms - last_hurt_ms > 4000:
		regen_accum += delta / 1.2
		if regen_accum >= 1.0:
			regen_accum -= 1.0
			health = mini(health + 1, max_health)
			update_ui()
	# 刷怪与 Boss 调度（实现在 spawn_director.gd）
	SpawnDirector.process(self, delta)

func _unhandled_input(event):
	# 鼠标左键：消耗追踪导弹道具（桌面端；手机用右下角按钮）
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if homing_charges > 0 and not dying:
			_use_homing()
		return
	# Esc 打开暂停（关闭方向由 pause_menu.gd 在暂停状态下处理）
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if dying or levelup_panel.visible or start_panel.visible or game_over_panel.visible:
			return
		_open_pause()
		get_viewport().set_input_as_handled()

# --- 音效 ---

var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_i := 0

func play_sfx(name: String, volume_db := 0.0, pitch_jitter := 0.05):
	# 对象池轮转：自动射击下避免每发子弹新建/销毁播放器的分配抖动
	var p: AudioStreamPlayer = _sfx_pool[_sfx_i]
	_sfx_i = (_sfx_i + 1) % _sfx_pool.size()
	p.stream = SFX[name]
	p.volume_db = volume_db
	p.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	p.play()

# 事件震屏统一入口：减少闪光模式下按比例衰减
func _shake(amount: float):
	camera.add_shake(amount * (0.3 if reduce_fx else 1.0))

# --- 刷怪（实现在 spawn_director.gd，这里保留计时器接线与外部调用面） ---

func _on_timer_timeout():
	SpawnDirector.spawn_enemy(self)

# 编队波次（冒烟测试直接调用）
func _spawn_formation():
	SpawnDirector._spawn_formation(self)

# 增援词缀：Boss 定期召唤小怪（boss.gd 经 has_method 守卫调用）
func spawn_minions(n: int):
	SpawnDirector.spawn_minions(self, n)

# --- 击杀与经验 ---

func _on_enemy_died(pos: Vector3, value, fx_color, max_hp := 3):
	score += value
	kill_count += 1

	# 纳米修复：击杀有概率回复 1 点生命
	if ability == "leech" and health > 0 and health < max_health and randf() < 0.1:
		health = mini(health + 1, max_health)

	# 击杀演出：3D 爆炸粒子 + 冲击波环 + 音效 + 震屏
	spawn_explosion(pos, fx_color, value >= 30)
	spawn_ring(pos, fx_color, 0.35, 2.0, 0.35)
	play_sfx("explode", -8.0, 0.12)
	_shake(6.0 if value >= 30 else 2.5)

	# 掉落经验水晶：按敌机血量分三档（白 1 / 绿 3 / 紫 8）
	var tier := 1
	if max_hp >= 9:
		tier = 3
	elif max_hp >= 4:
		tier = 2
	var gem = gem_scene.instantiate()
	gem.position = pos
	gem.tier = tier
	gem.xp_value = [1, 3, 8][tier - 1]
	add_child(gem)

	update_ui()
	SpawnDirector.maybe_boss(self)

func add_xp(amount):
	play_sfx("pickup", -10.0, 0.08)
	xp += maxi(1, roundi(amount * xp_mul))
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		xp_to_next = 5 + level * 3
		pending_level_ups += 1
	update_ui()
	if pending_level_ups > 0 and not levelup_panel.visible:
		show_level_up()

# --- Boss 战（实现在 spawn_director.gd，这里保留外部调用面：smoke_test / capture.gd / 信号连接） ---

func _start_boss():
	SpawnDirector.start_boss(self)

func _spawn_boss():
	SpawnDirector._spawn_boss(self)

func _on_boss_hp(hp, max_hp):
	boss_bar.max_value = max_hp
	boss_bar.value = hp

func _on_boss_died(pos: Vector3, is_omega := false):
	SpawnDirector.on_boss_died(self, pos, is_omega)

func spawn_enemy_bullet(pos: Vector3, dir: Vector3, speed, damage := 1, homing := 0.0, homing_time := 0.0, style := "shooter"):
	var b = enemy_bullet_scene.instantiate()
	b.position = pos
	b.dir = dir
	b.speed = speed
	b.damage = damage
	b.homing = homing
	b.homing_time = homing_time
	b.style = style
	add_child(b)

func spawn_lightning(from: Vector3, to: Vector3):
	Fx.lightning(self, from, to)

# --- 核心装备：连贯 3D 变形演出 ---

# --- 核心装备变形与形态能力（实现在 form_ability.gd；core.gd 经 has_method 调用） ---

func apply_core(form):
	FormAbility.apply_core(self, form)
# --- 升级三选一（15 张卡池随机抽 3，可叠加卡显示 Lv.N） ---

func show_level_up():
	$TouchUI.reset()   # 暂停前复位摇杆，防止恢复后方向残留
	pause_button.hide()
	get_tree().paused = true
	levelup_panel.show()
	if levelup_panel.has_method("animate_in"):
		levelup_panel.animate_in()

	play_sfx("levelup", -4.0)
	flash_ui(GOLD, 0.5)
	spawn_ring(player.position, GOLD, 0.3, 3.2, 0.6)
	confetti_burst(player.position, 34, GOLD)
	_shake(9.0)
	pulse_player()

	var available = upgrade_pool.filter(func(u): return u["can"].call())
	available.shuffle()
	var choices = available.slice(0, 3)
	# 超后期卡池枯竭时用紧急维修补位
	while choices.size() < 3:
		choices.append(Upgrades.repair_card(self))
	for i in upgrade_buttons.size():
		var up = choices[i]
		var base: String = I18n.T("card_" + String(up["id"]))
		# 等级：元素/弹道卡读各自的等级表，其余读选取计数
		var lv: int = up["lv_fn"].call() if up.has("lv_fn") else int(card_taken.get(up["id"], 0))
		var title := base if lv == 0 else "%s Lv.%d" % [base, lv + 1]
		# 切换提示：选非当前元素/弹道时标注"切换"（等级不会清空）
		if up.has("hint_fn"):
			var hint: String = up["hint_fn"].call()
			if hint != "":
				title += " · " + I18n.T(hint)
		upgrade_buttons[i].text = title + "\n" + I18n.T("card_" + String(up["id"]) + "_d")
		upgrade_buttons[i].set_meta("upgrade", up)

func _on_upgrade_button_pressed(index):
	var up = upgrade_buttons[index].get_meta("upgrade")
	up["apply"].call()
	card_taken[up["id"]] = int(card_taken.get(up["id"], 0)) + 1
	pending_level_ups -= 1
	if pending_level_ups > 0:
		show_level_up()
	else:
		levelup_panel.hide()
		get_tree().paused = false
		if not dying:
			pause_button.show()

	spawn_ring(player.position, GOLD, 0.3, 1.8, 0.4)
	confetti_burst(player.position, 16, GOLD)
	_shake(5.0)
	pulse_player()

# 元素弹头：切换 / 升级（各元素等级独立保留，随时切回来继续）
func pick_element(id: String):
	player.element = id
	player.element_levels[id] = int(player.element_levels.get(id, 0)) + 1

# 特殊弹道：切换 / 升级（追踪/波浪等级独立保留）
func pick_pattern(id: String):
	player.pattern = id
	player.pattern_levels[id] = int(player.pattern_levels.get(id, 0)) + 1

# --- 受伤 / 复活 / 阵亡结算 ---

func take_damage(amount):
	if dying:
		return
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
		if revive_charges > 0:
			_do_revive()
		else:
			_start_death()

# 凤凰模块：原地复活 + 冲击波清场
func _do_revive():
	revive_charges -= 1
	dying = false
	health = maxi(1, int(max_health / 2.0))
	last_hurt_ms = Time.get_ticks_msec() + 1200   # 额外无敌帧，防止落地即再被打死
	player.revive()
	for b in get_tree().get_nodes_in_group("enemy_bullets"):
		if b.global_position.distance_to(player.global_position) < 540.0:
			b.queue_free()
	for m in get_tree().get_nodes_in_group("mobs"):
		if m.dead:
			continue
		if m.global_position.distance_to(player.global_position) < 460.0:
			if m.has_method("take_damage"):
				m.take_damage(10)
			if m.has_method("knockback"):
				var away = (m.global_position - player.global_position).normalized()
				m.knockback(Vector3(away.x, away.y, 0) * 70.0)
	play_sfx("transform", -2.0)
	flash_ui(Color(1, 0.6, 0.2), 0.5)
	_shake(12.0)
	spawn_ring(player.position, Color(1, 0.6, 0.25), 0.4, 5.4, 0.8)
	spawn_explosion(player.position, Color(1, 0.6, 0.25), true)
	update_ui()

# 阵亡演出：爆炸 + 慢动作谢幕，随后弹结算面板
func _start_death():
	dying = true
	pause_button.hide()
	FormAbility.clear_aura(self)
	ability_chip.hide()
	buff_bar.hide()
	$TouchUI.reset()
	player.play_death()
	play_sfx("explode", -2.0)
	play_sfx("gameover")
	_shake(16.0)
	flash_ui(Color(1, 0.25, 0.25), 0.45)
	spawn_ring(player.position, Color(1, 0.5, 0.3), 0.3, 3.4, 0.8)
	for i in 3:
		get_tree().create_timer(0.12 + i * 0.14, true).timeout.connect(func():
			if is_instance_valid(player):
				spawn_explosion(player.position + Vector3(randf_range(-40, 40), randf_range(-30, 30), 0.0), Color(1, 0.55, 0.3), i == 2))
	# 慢动作谢幕（0.5 缩放秒 ≈ 1.25 真实秒）
	Engine.time_scale = 0.4
	await get_tree().create_timer(0.5).timeout
	Engine.time_scale = 1.0
	game_over()

func update_ui():
	if score_label:
		score_label.text = I18n.T("score") % score
	if level_label:
		level_label.text = I18n.T("level") % level
	if xp_bar:
		xp_bar.max_value = xp_to_next
		xp_bar.value = xp
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health
	# 动态难度：初始 0.9 秒一个怪，最快 0.3 秒一个；Boss 战降为 1.7 秒低频续刷
	if boss_active:
		$Timer.wait_time = 1.7
	else:
		$Timer.wait_time = max(0.3, 0.9 - score * 0.002)

func game_over():
	# 结算 + 存档（新纪录才覆盖最高分）
	is_new_record = score > high_score
	if is_new_record:
		high_score = score
	SaveGame.save_data({"high": high_score, "mute": muted, "reduce_fx": reduce_fx})
	final_score_label.text = I18n.T("final") % [score, level]
	if is_new_record and score > 0:
		record_label.text = I18n.T("new_record")
	else:
		record_label.text = I18n.T("high") % high_score
	game_over_panel.show()
	if game_over_panel.has_method("animate_in"):
		game_over_panel.animate_in()
	flash_ui(Color(1, 0.25, 0.25), 0.4)
	_shake(12.0)
	get_tree().paused = true

# ✦ 胜利结算：OMEGA 击破演出落定后弹出（战绩回顾 + 徽章 + 无尽/重开选择）
func _show_victory():
	# 若延迟期间玩家已阵亡，让位于败北结算
	if dying or game_over_panel.visible or not omega_slain:
		return
	var mins := int(run_time) / 60
	var secs := int(run_time) % 60
	victory_stats_label.text = "%s\n%s · %s\n%s" % [
		I18n.T("final") % [score, level],
		I18n.T("victory_form") % (player.form + 1),
		I18n.T("victory_kills") % kill_count,
		I18n.T("victory_time") % [mins, secs],
	]
	pause_button.hide()
	levelup_panel.hide()   # 演出窗口内触发的升级：先收起，继续无尽时重新弹出
	victory_panel.show()
	if victory_panel.has_method("animate_in"):
		victory_panel.animate_in()
	get_tree().paused = true
	confetti_burst(player.position, 40, GOLD)
	play_sfx("levelup", -2.0)

# 胜利结算：带着已变强的机体继续无尽冲击更高分
func _continue_endless():
	victory_panel.hide()
	if not dying:
		pause_button.show()
	get_tree().paused = false
	# 结算期间攒下的升级（若有）重新弹出
	if pending_level_ups > 0:
		show_level_up()

# --- 暂停菜单 ---

func _open_pause():
	if dying or levelup_panel.visible or start_panel.visible or game_over_panel.visible:
		return
	$TouchUI.reset()
	pause_button.hide()
	pause_panel.show()
	get_tree().paused = true

func _close_pause():
	pause_panel.hide()
	if not dying:
		pause_button.show()
	get_tree().paused = false

func _on_sound_toggled():
	muted = not muted
	AudioServer.set_bus_mute(0, muted)
	SaveGame.save_data({"high": high_score, "mute": muted, "reduce_fx": reduce_fx})
	_update_pause_labels()

func _on_fx_toggled():
	reduce_fx = not reduce_fx
	SaveGame.save_data({"high": high_score, "mute": muted, "reduce_fx": reduce_fx})
	_update_pause_labels()

func _update_pause_labels():
	$UI/PausePanel/Box/SoundButton.text = I18n.T("sound_on") if muted else I18n.T("sound_off")
	$UI/PausePanel/Box/FxButton.text = I18n.T("fx_on") if reduce_fx else I18n.T("fx_off")

# --- 追踪导弹道具：击破 Boss 获得，点击鼠标 / 右下角按钮触发——
#     当前整个屏幕上的主角子弹全部转为追踪弹（镀金 + 音效 + 特效） ---

func _use_homing():
	if homing_charges <= 0 or dying:
		return
	# 转换全场飞行中的子弹
	var converted := 0
	for b in get_tree().get_nodes_in_group("player_bullets"):
		if b.has_method("make_homing") and b.make_homing():
			converted += 1
	if converted == 0:
		# 没有子弹可转：不消耗道具，给出提示
		_toast(I18n.T("no_bullets"), Color(0.7, 0.8, 0.9))
		play_sfx("hit", -10.0, 0.1)
		return
	homing_charges -= 1
	_update_homing_btn()
	# 触发音效 + 特效：金光闪 + 主角冲击波环
	play_sfx("transform", -4.0, 0.1)
	flash_ui(Color(1, 0.85, 0.4), 0.18)
	_shake(6.0)
	spawn_ring(player.position, Color(1, 0.85, 0.4), 0.3, 2.8, 0.5)
	confetti_burst(player.position, 14, Color(1, 0.85, 0.4))

func _update_homing_btn():
	homing_btn.text = I18n.T("btn_homing") % homing_charges
	homing_btn.visible = homing_charges > 0 and not dying

# 反应提示：命中点浮起反应名（元素反应可见性）
func spawn_reaction_text(pos: Vector3, key: String, color: Color):
	var lbl := Label3D.new()
	lbl.text = I18n.T(key)
	lbl.font = UI_FONT
	lbl.font_size = 64
	lbl.pixel_size = 1.1
	lbl.modulate = color
	lbl.outline_size = 20
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.position = pos
	add_child(lbl)
	var tw := lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", pos.y + 80.0, 0.7)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.7).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(lbl.queue_free)

# 短 toast 横幅（获得道具等即时反馈）
func _toast(text: String, col: Color):
	ability_label.text = text
	ability_label.modulate = Color(col.r, col.g, col.b, 0.0)
	ability_label.show()
	var tw := ability_label.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(ability_label, "modulate:a", 1.0, 0.2)
	tw.tween_interval(1.2)
	tw.tween_property(ability_label, "modulate:a", 0.0, 0.35)
	tw.tween_callback(ability_label.hide)

# --- 特效工具（实现见 fx.gd，这里保留旧签名供敌机 / Boss / 子弹调用） ---

func spawn_ring(pos: Vector3, color: Color, from_scale: float, to_scale: float, dur: float):
	Fx.ring(self, pos, color, from_scale, to_scale, dur)

func spawn_explosion(pos: Vector3, color: Color, big := false):
	Fx.explosion(self, pos, color, big)

func confetti_burst(pos: Vector3, amount: int, color: Color = GOLD):
	Fx.confetti(self, pos, amount, color)

func spawn_hit_spark(pos: Vector3):
	play_sfx("hit", -10.0, 0.15)
	var s := hit_spark_scene.instantiate()
	s.position = pos
	add_child(s)

func flash_ui(color: Color, peak: float):
	if reduce_fx:
		peak *= 0.25
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

# --- 开始面板 ---

func _on_start_pressed():
	start_panel.hide()
	pause_button.show()
	get_tree().paused = false
	# 无条件重启 BGM：网页端此刻才拿到音频手势（此前的 play 可能被浏览器挂起），
	# 桌面端音乐随开战从头播放
	bgm_player.play()
	_request_web_fullscreen()

func _request_web_fullscreen():
	# 手机浏览器：请求全屏并锁定横屏（部分浏览器可能拒绝，静默失败）
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("if(window.__requestGameFullscreen){window.__requestGameFullscreen();}", true)

# --- 结算栏按钮的功能代码 ---

func _on_restart_button_pressed():
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_quit_button_pressed():
	# 网页版浏览器禁止脚本关闭页面，quit() 会卡死引擎——改为刷新回开始界面
	if OS.has_feature("web"):
		Engine.time_scale = 1.0
		get_tree().paused = false
		JavaScriptBridge.eval("location.reload()", true)
	else:
		get_tree().quit()
