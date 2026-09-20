extends Node3D

# 1. 模板场景
@export var enemy_scene: PackedScene = preload("res://enemy.tscn")
@export var gem_scene: PackedScene = preload("res://gem.tscn")
@export var hit_spark_scene: PackedScene = preload("res://hit_spk.tscn")
@export var core_scene: PackedScene = preload("res://core.tscn")
@export var enemy_bullet_scene: PackedScene = preload("res://enemy_bullet.tscn")
@export var boss_scene: PackedScene = preload("res://boss.tscn")

const BGM := preload("res://assets/sounds/bgm.wav")
const BulletScene := preload("res://bullet.tscn")
const BulletScript := preload("res://bullet.gd")
const MB := preload("res://model_builder.gd")
const I18n := preload("res://i18n.gd")
const SaveGame := preload("res://save.gd")
const Fx := preload("res://fx.gd")
const Upgrades := preload("res://upgrades.gd")
const GOLD := Color(1, 0.84, 0.35)
const CYAN := Color(0.55, 0.9, 1)
const SNOW_TEX := preload("res://assets/aura_snow.png")
const UI_FONT := preload("res://assets/fonts/ZCOOLKuaiLe-Regular.ttf")

# 形态特殊能力：每次变形按形态序号循环获得一种（20 形态 = 每种能力两轮）
const ABILITY_ORDER := ["nova", "overcharge", "frost", "flame", "magnet", "leech", "aegis", "thrust", "barrage", "gravity"]
const ABILITIES := {
	"nova": {"color": Color(1, 0.55, 0.3)},      # 变形瞬间：冲击波重创周围敌机
	"overcharge": {"color": Color(1, 0.85, 0.3)}, # 6 秒射速翻倍
	"frost": {"color": Color(0.55, 0.85, 1)},     # 持续：冻结周围敌机
	"flame": {"color": Color(1, 0.45, 0.2)},      # 持续：灼烧周围敌机
	"magnet": {"color": Color(0.45, 0.9, 1)},     # 持续：拾取磁吸范围翻倍
	"leech": {"color": Color(0.4, 0.95, 0.5)},    # 持续：击杀概率回复生命
	"aegis": {"color": Color(0.75, 0.55, 1)},     # 持续：受到的所有伤害 -1
	"thrust": {"color": Color(0.8, 0.95, 1)},     # 6 秒移速大幅提升
	"barrage": {"color": Color(1, 0.8, 0.25)},    # 6 秒 +1 弹道且射速提升
	"gravity": {"color": Color(0.45, 0.55, 1)},   # 持续：靠近主角的敌方子弹减速
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

# 循环词缀池（tier 6 起 Boss 随机携带一种）
const AFFIXES := ["swift", "wall", "reinforce", "vengeful"]

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
	# 变形能量茧 / 能力光环跟随主角：机体移动时光圈贴着走，不会留在原地
	if _cocoon != null:
		if is_instance_valid(_cocoon):
			_cocoon.position = player.global_position
		else:
			_cocoon = null
	if _aura != null:
		if is_instance_valid(_aura):
			_aura.position = player.global_position
			# 轨道环绕：旋转发射器节点（CPUParticles 无轨道速度参数，本地坐标下整体旋转）
			for s in _aura_spinners:
				if is_instance_valid(s[0]):
					s[0].rotation.z += s[1] * delta
		else:
			_aura = null
			_aura_spinners.clear()
	# 限时增益倒计时条
	if buff_kind != "" and buff_bar.visible:
		buff_bar.value = buff_left
	if dying:
		return
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
	# 编队波次：与散刷并行的阵型压力（Boss 战期间停用）
	if not boss_active and health > 0:
		formation_cd -= delta
		if formation_cd <= 0.0:
			formation_cd = randf_range(13.0, 19.0)
			_spawn_formation()

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

# --- 刷怪 ---

func _spawn_enemy():
	var enemy = enemy_scene.instantiate()
	# 抢滩登陆：敌机从屏幕上方随机位置出现
	enemy.position = Vector3(randf_range(-576.0, 576.0), 404.0, 0.0)
	enemy.setup(pick_enemy_type())
	enemy.apply_tier(boss_tier)
	enemy.died.connect(_on_enemy_died)
	add_child(enemy)

func _on_timer_timeout():
	_spawn_enemy()

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

# --- 编队波次：V 字纵队 / 横排盾墙 / 两翼包抄 ---

func _spawn_formation():
	var roll := randf()
	if score >= 100 and roll < 0.35:
		_formation_pincer()
	elif score >= 60 and roll < 0.65:
		_formation_line()
	else:
		_formation_vee()

func _formation_vee():
	var count := 5 + mini(boss_tier, 4)
	var type := "swift" if score >= 20 else "normal"
	var cx := randf_range(-240.0, 240.0)
	for i in count:
		var k := i - (count - 1) / 2.0
		_spawn_formation_enemy(type, Vector3(cx + k * 54.0, 404.0 + absf(k) * 40.0, 0.0))

func _formation_line():
	var count := 5
	var type := "shield" if score >= 100 else "normal"
	for i in count:
		var x := -380.0 + 760.0 * i / float(count - 1)
		_spawn_formation_enemy(type, Vector3(x, 404.0, 0.0))

func _formation_pincer():
	var type := "fast" if score >= 40 else "normal"
	var vx: float = 70.0 + boss_tier * 6.0
	for side in 2:
		var dir := 1.0 if side == 0 else -1.0
		for row in 4:
			_spawn_formation_enemy(type, Vector3(-560.0 * dir, 330.0 + row * 46.0, 0.0), vx * dir)

func _spawn_formation_enemy(type: String, pos: Vector3, vx := 0.0):
	var enemy = enemy_scene.instantiate()
	enemy.position = pos
	enemy.setup(type)
	enemy.apply_tier(boss_tier)
	enemy.vx = vx
	enemy.died.connect(_on_enemy_died)
	add_child(enemy)

# 增援词缀：Boss 定期召唤小怪
func spawn_minions(n: int):
	for i in n:
		_spawn_formation_enemy(pick_enemy_type(), Vector3(randf_range(-500.0, 500.0), 404.0, 0.0))

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
	_shake(6.0 if value >= 30 else 2.5)

	# 掉落经验水晶
	var gem = gem_scene.instantiate()
	gem.position = pos
	gem.xp_value = 3 if value >= 30 else (2 if value >= 20 else 1)
	add_child(gem)

	update_ui()
	_maybe_boss()

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

# --- Boss 战 ---

func _maybe_boss():
	if boss_active or health <= 0:
		return
	if kill_count >= next_boss_at:
		_start_boss()

func _start_boss():
	boss_active = true
	update_ui()   # 刷怪降频：Boss 战期间保留 1.7 秒低频续刷，避免屏幕空旷 / 经验断粮
	play_sfx("warning", -2.0, 0.0)

	if omega_armed:
		warning_label.text = I18n.T("warning_omega")
		warning_label.modulate = Color(0.95, 0.85, 0.4)
	else:
		warning_label.text = I18n.T("warning_boss") % (boss_tier + 1)
		warning_label.modulate = Color(1, 1, 1)
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
	if omega_armed:
		boss.setup(6, boss_tier)
		omega_armed = false
	else:
		var id = ((boss_tier - 1) % 5) + 1
		# 第二轮循环（tier 6）起，Boss 随机携带一个词缀
		var affix := ""
		if boss_tier >= 6:
			affix = AFFIXES[randi() % AFFIXES.size()]
		boss.setup(id, boss_tier, affix)
	boss.died.connect(_on_boss_died)
	boss.hp_changed.connect(_on_boss_hp)
	add_child(boss)

	boss_name_label.text = "【 %s 】" % boss.full_name()
	boss_name_label.show()
	boss_bar.max_value = boss.max_hp
	boss_bar.value = boss.max_hp
	boss_bar.show()

	spawn_ring(Vector3(0, 174, 0), Color(1, 0.4, 0.4), 0.4, 3.0, 0.7)
	_shake(8.0)

func _on_boss_hp(hp, max_hp):
	boss_bar.max_value = max_hp
	boss_bar.value = hp

func _on_boss_died(pos: Vector3, is_omega := false):
	boss_active = false
	boss_name_label.hide()
	boss_bar.hide()

	score += 150 + 50 * boss_tier
	play_sfx("boss_die")
	_shake(18.0)
	flash_ui(Color(1, 0.6, 0.3), 0.45)
	for i in 3:
		spawn_ring(pos + Vector3(randf_range(-60, 60), randf_range(-40, 40), 0.0), Color(1, 0.75, 0.4), 0.3, 2.4 + i * 0.8, 0.6)

	if is_omega and not omega_slain:
		# ✦ 胜利：灭世母舰被击破（记录徽章，随后进入无尽模式）
		omega_slain = true
		score += 2000
		next_boss_at = kill_count + 80
		var data := SaveGame.load_data()
		data["omega"] = true
		SaveGame.save_data(data)
		warning_label.text = I18n.T("victory")
		warning_label.modulate = Color(1, 0.85, 0.35)
		warning_label.modulate.a = 1.0
		warning_label.show()
		var vtw = create_tween()
		vtw.tween_interval(2.2)
		vtw.tween_property(warning_label, "modulate:a", 0.0, 0.8)
		vtw.tween_callback(warning_label.hide)
		flash_ui(Color(1, 0.85, 0.35), 0.5)
		play_sfx("levelup", 0.0)
		_shake(24.0)
		for i in 6:
			spawn_ring(pos + Vector3(randf_range(-120, 120), randf_range(-80, 80), 0.0), Color(1, 0.85, 0.35) if i % 2 == 0 else CYAN, 0.3, 3.0 + i * 0.7, 0.8)
	elif boss_tier >= 10 and not omega_slain:
		# 五种 Boss 两轮循环完毕：武装终局 OMEGA，短间隔后降临
		omega_armed = true
		next_boss_at = kill_count + 25
	else:
		next_boss_at = kill_count + 50 + boss_tier * 10

	# 掉落核心装备：接住后战机渐进变形
	var core = core_scene.instantiate()
	core.position = pos
	core.form_target = mini(player.form + 1, 19)
	add_child(core)
	# 追踪导弹道具：每击破一个 Boss 获得 1 枚
	homing_charges += 1
	_update_homing_btn()
	_toast(I18n.T("gain_homing"), GOLD)	# Boss 破阵：敌主力接踵增援，梯次涌入形成一波数量冲击
	var wave := mini(10 + boss_tier * 2, 22)
	warning_label.text = I18n.T("warning_reinforce")
	warning_label.modulate.a = 1.0
	warning_label.show()
	var wtw = create_tween()
	wtw.tween_interval(1.1)
	wtw.tween_property(warning_label, "modulate:a", 0.0, 0.4)
	wtw.tween_callback(warning_label.hide)
	play_sfx("warning", -6.0, 0.1)
	for i in wave:
		# 不设 process_always：暂停（暂停菜单/结算）期间不再刷怪
		get_tree().create_timer(0.3 + i * 0.16).timeout.connect(func():
			# 主角阵亡或下一 Boss 已入场则停止增援
			if health > 0 and not boss_active and not dying:
				_spawn_enemy())

	update_ui()
	$Timer.start()

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

func apply_core(form):
	play_sfx("transform")
	flash_ui(CYAN, 0.35)
	_shake(8.0)
	confetti_burst(player.position, 24, CYAN)
	_end_buff()   # 旧形态的限时增益随变形结束
	_apply_form_bonus(form)
	update_ui()
	# 立刻预建新机体：构建开销落在有白闪+震屏掩护的这一帧，换装瞬间零生成
	_prebuilt_model = MB.build_player_form(form)

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
	_cocoon = cocoon

	player.set_form(form, _prebuilt_model)
	_prebuilt_model = null

	var tw := cocoon.create_tween()
	# 包裹：茧体胀起并显现（节奏压缩：拾取 → 破茧全程约 1 秒，不再长时间小机体）
	tw.tween_property(m, "albedo_color:a", 0.68, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(cocoon, "scale", Vector3.ONE * 1.32, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# 茧色渐变 → 新形态的主题色（形态特征预兆）
	tw.tween_property(m, "albedo_color", Color(accent.r, accent.g, accent.b, 0.68), 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(m, "emission", accent, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# 两次快速重塑脉冲：新形态在茧内逐次成形
	for i in 2:
		tw.tween_property(cocoon, "scale", Vector3.ONE * (1.24 + 0.1 * i), 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(cocoon, "scale", Vector3.ONE * 1.32, 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# 破茧：能量迸发，新机体翻滚着登场；能力激活分到下一帧，避免同一帧挤爆
	tw.tween_callback(func():
		_cocoon = null
		spawn_explosion(cocoon.position, accent, false)
		spawn_ring(cocoon.position, accent, 0.3, 2.6, 0.5)
		cocoon.queue_free()
		_spawn_reveal()
		get_tree().create_timer(0.05, true).timeout.connect(func(): _activate_ability(form)))

func _spawn_reveal():
	_spawn_evolution_beam()
	var tw2 = create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(player.model, "rotation_degrees:y", 360.0, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw2.tween_property(player, "scale", Vector3.ONE * player.base_scale * 1.32, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw2.chain().tween_property(player, "scale", Vector3.ONE * player.base_scale, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# --- 形态特殊能力 ---

func _activate_ability(form: int):
	_end_buff()
	ability = ABILITY_ORDER[form % ABILITY_ORDER.size()]
	var info: Dictionary = ABILITIES[ability]
	var col: Color = info["color"]
	var ability_name: String = I18n.T("ab_" + ability)
	player.set_meta("magnet_mul", 2.2 if ability == "magnet" else 1.0)
	# 公告横幅
	ability_label.text = I18n.T("ability") % ability_name
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
	# 常驻能力指示器（左上角，能力色常显，不再只靠 2 秒横幅）
	ability_chip.text = "✦ " + ability_name
	ability_chip.modulate = Color(col.r, col.g, col.b)
	ability_chip.show()
	# 常驻能力光环：光尘 + 半径圈 / 护盾泡（引力新星是瞬间爆发，无常驻视觉）
	if ability != "nova":
		_build_aura(ability)
	match ability:
		"nova":
			# 引力新星：变形瞬间冲击波重创周围敌机
			spawn_ring(player.position, col, 0.5, 5.2, 0.7)
			_shake(10.0)
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
	buff_bar.max_value = dur
	buff_bar.value = dur
	buff_bar.show()
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
	buff_bar.hide()
	_clear_aura()   # 限时增益的常驻光环随增益结束消散

# --- 能力常驻视觉：环绕光尘 + 半径指示圈 / 护盾泡（跟随主角的世界空间节点） ---

func _clear_aura():
	if _aura != null:
		if is_instance_valid(_aura):
			_aura.queue_free()
		_aura = null
	_aura_spinners.clear()

func _build_aura(id: String):
	_clear_aura()
	var col: Color = ABILITIES[id]["color"]
	_aura = Node3D.new()
	_aura.position = player.global_position
	add_child(_aura)
	# 主题环绕粒子：每种能力有自己的动态（寒霜 = 细雪片沿轨道绕机旋转）
	match id:
		"frost":
			_motes(Color(0.93, 0.97, 1.0), 10, 2.6, 48.0, 1.8, 0.0, 0.0, Vector3(0, -13, 0), 0.9, 1.5, _snowflake_mesh())
		"flame":
			_motes(col, 9, 0.8, 0.0, 0.0, 60.0, 140.0, Vector3(0, 70, 0), 1.2, 2.2)
		"magnet":
			_motes(col, 8, 1.4, 30.0, 3.2, 0.0, 0.0, Vector3.ZERO, 0.6, 1.0)
		"leech":
			_motes(col, 7, 1.6, 0.0, 0.0, 15.0, 45.0, Vector3(0, -40, 0), 0.6, 1.1)
		"gravity":
			_motes(col, 10, 1.9, 40.0, -1.4, 0.0, 0.0, Vector3.ZERO, 0.8, 1.3)
		"overcharge":
			_motes(col, 12, 0.45, 0.0, 0.0, 110.0, 210.0, Vector3.ZERO, 0.5, 1.0)
		"thrust":
			_motes(col, 10, 0.5, 22.0, 0.0, 40.0, 90.0, Vector3(0, -150, 0), 0.6, 1.1)
		"barrage":
			_motes(col, 9, 0.9, 34.0, 3.8, 0.0, 0.0, Vector3.ZERO, 0.5, 0.9)
		"aegis":
			pass   # 护盾只有能量泡，干净一些
	# 相位护盾：包裹机体的半透明能量泡，呼吸明暗
	if id == "aegis":
		var bubble := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 62.0
		sm.height = 124.0
		bubble.mesh = sm
		var bm := StandardMaterial3D.new()
		bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bm.albedo_color = Color(col.r, col.g, col.b, 0.16)
		bm.emission_enabled = true
		bm.emission = col
		bm.emission_energy_multiplier = 1.4
		bubble.material_override = bm
		_aura.add_child(bubble)
		var bt := bubble.create_tween().set_loops()
		bt.tween_property(bm, "albedo_color:a", 0.3, 0.7)
		bt.tween_property(bm, "albedo_color:a", 0.14, 0.7)

# 能力环绕粒子通用构建：环状/球状发射 + 可选轨道旋转
func _motes(col: Color, amount: int, life: float, ring_radius: float, orbital: float, vel_min: float, vel_max: float, grav: Vector3, smin: float, smax: float, mesh: Mesh = null):
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	if ring_radius > 0.0:
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		p.emission_ring_radius = ring_radius
		p.emission_ring_inner_radius = maxf(ring_radius - 6.0, 0.0)
		p.emission_ring_axis = Vector3(0, 0, 1)   # 游戏平面法线：轨道绕机体水平旋转
		p.emission_ring_height = 8.0
	else:
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 42.0
	p.spread = 180.0
	if orbital != 0.0:
		# 轨道环绕：本地坐标 + 旋转发射器节点（world._process 驱动）
		p.local_coords = true
		_aura_spinners.append([p, orbital])
	p.gravity = grav
	p.initial_velocity_min = vel_min
	p.initial_velocity_max = vel_max
	p.scale_amount_min = smin
	p.scale_amount_max = smax
	var m := SphereMesh.new()
	m.radius = 2.2
	m.height = 4.4
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.vertex_color_use_as_albedo = true
	mm.emission_enabled = true
	mm.emission = col
	mm.emission_energy_multiplier = 2.2
	m.material = mm
	p.mesh = mesh if mesh != null else m
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(col.r, col.g, col.b, 0.95), Color(col.r, col.g, col.b, 0.0)])
	p.color_ramp = g
	_aura.add_child(p)
	p.emitting = true
	return p

var _flake_mesh: QuadMesh = null

# 寒霜细雪片：六臂雪花贴图 + 面向镜头
func _snowflake_mesh() -> QuadMesh:
	if _flake_mesh == null:
		_flake_mesh = QuadMesh.new()
		_flake_mesh.size = Vector2(15, 15)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_texture = SNOW_TEX
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.emission_enabled = true
		m.emission = Color(0.75, 0.9, 1.0)
		m.emission_energy_multiplier = 1.1
		_flake_mesh.material = m
	return _flake_mesh

func _aura_radius_ring(col: Color, radius: float):
	# 已按反馈移除机体外圈的大光圈，只保留雪花 / 火焰等粒子特效
	pass

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
	_clear_aura()
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
