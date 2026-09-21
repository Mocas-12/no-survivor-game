extends Object

# 刷怪与 Boss 调度（从 world.gd 拆出）：抢滩刷怪 / 编队波次 / Boss 阈值与入场 / Boss 阵亡结算
# 模式与 upgrades.gd / fx.gd 一致：纯静态函数，首参传 world（w）；全部状态留在 world 上
# 外部调用面不变：world 上的同名委托方法（smoke_test / capture.gd / boss.gd 依赖）

# 循环词缀池（tier 6 起 Boss 随机携带一种）
const AFFIXES := ["swift", "wall", "reinforce", "vengeful"]

const I18n := preload("res://scripts/i18n.gd")
const SaveGame := preload("res://scripts/save.gd")
const GOLD := Color(1, 0.84, 0.35)
const CYAN := Color(0.55, 0.9, 1)

# 每帧调度：编队波次倒计时（Boss 战期间停用，由 world._process 驱动）
static func process(w, delta: float) -> void:
	if not w.boss_active and w.health > 0:
		w.formation_cd -= delta
		if w.formation_cd <= 0.0:
			w.formation_cd = randf_range(13.0, 19.0)
			_spawn_formation(w)

# --- 抢滩刷怪 ---

static func spawn_enemy(w) -> void:
	var enemy = w.enemy_scene.instantiate()
	# 抢滩登陆：敌机从屏幕上方随机位置出现
	enemy.position = Vector3(randf_range(-576.0, 576.0), 404.0, 0.0)
	enemy.setup(pick_enemy_type(w))
	enemy.apply_tier(w.boss_tier)
	enemy.died.connect(w._on_enemy_died)
	w.add_child(enemy)

static func pick_enemy_type(w) -> String:
	var roll = randf()
	if w.score >= 150 and roll < 0.12:
		return "tank"
	if w.score >= 100 and roll < 0.24:
		return "shield"
	if w.score >= 60 and roll < 0.40:
		return "shooter"
	if w.score >= 40 and roll < 0.58:
		return "fast"
	if w.score >= 20 and roll < 0.76:
		return "swift"
	return "normal"

# --- 编队波次：V 字纵队 / 横排盾墙 / 两翼包抄 ---

static func _spawn_formation(w) -> void:
	var roll := randf()
	if w.score >= 100 and roll < 0.35:
		_formation_pincer(w)
	elif w.score >= 60 and roll < 0.65:
		_formation_line(w)
	else:
		_formation_vee(w)

static func _formation_vee(w) -> void:
	var count := 5 + mini(w.boss_tier, 4)
	var type := "swift" if w.score >= 20 else "normal"
	var cx := randf_range(-240.0, 240.0)
	for i in count:
		var k := i - (count - 1) / 2.0
		_spawn_formation_enemy(w, type, Vector3(cx + k * 54.0, 404.0 + absf(k) * 40.0, 0.0))

static func _formation_line(w) -> void:
	var count := 5
	var type := "shield" if w.score >= 100 else "normal"
	for i in count:
		var x := -380.0 + 760.0 * i / float(count - 1)
		_spawn_formation_enemy(w, type, Vector3(x, 404.0, 0.0))

static func _formation_pincer(w) -> void:
	var type := "fast" if w.score >= 40 else "normal"
	var vx: float = 70.0 + w.boss_tier * 6.0
	for side in 2:
		var dir := 1.0 if side == 0 else -1.0
		for row in 4:
			_spawn_formation_enemy(w, type, Vector3(-560.0 * dir, 330.0 + row * 46.0, 0.0), vx * dir)

static func _spawn_formation_enemy(w, type: String, pos: Vector3, vx := 0.0) -> void:
	var enemy = w.enemy_scene.instantiate()
	enemy.position = pos
	enemy.setup(type)
	enemy.apply_tier(w.boss_tier)
	enemy.vx = vx
	enemy.died.connect(w._on_enemy_died)
	w.add_child(enemy)

# 增援词缀：Boss 定期召唤小怪
static func spawn_minions(w, n: int) -> void:
	for i in n:
		_spawn_formation_enemy(w, pick_enemy_type(w), Vector3(randf_range(-500.0, 500.0), 404.0, 0.0))

# --- Boss 战 ---

static func maybe_boss(w) -> void:
	if w.boss_active or w.health <= 0:
		return
	if w.kill_count >= w.next_boss_at:
		start_boss(w)

static func start_boss(w) -> void:
	w.boss_active = true
	w.update_ui()   # 刷怪降频：Boss 战期间保留 1.7 秒低频续刷，避免屏幕空旷 / 经验断粮
	w.play_sfx("warning", -2.0, 0.0)

	if w.omega_armed:
		w.warning_label.text = I18n.T("warning_omega")
		w.warning_label.modulate = Color(0.95, 0.85, 0.4)
	else:
		w.warning_label.text = I18n.T("warning_boss") % (w.boss_tier + 1)
		w.warning_label.modulate = Color(1, 1, 1)
	w.warning_label.modulate.a = 1.0
	w.warning_label.show()
	var tw = w.create_tween()
	tw.set_loops(5)
	tw.tween_property(w.warning_label, "modulate:a", 0.15, 0.22)
	tw.tween_property(w.warning_label, "modulate:a", 1.0, 0.22)
	await w.get_tree().create_timer(2.2).timeout
	if w.health <= 0 or not w.is_inside_tree():
		w.boss_active = false
		return
	w.warning_label.hide()
	_spawn_boss(w)

static func _spawn_boss(w) -> void:
	w.boss_tier += 1
	var boss = w.boss_scene.instantiate()
	if w.omega_armed:
		boss.setup(6, w.boss_tier)
		w.omega_armed = false
	else:
		var id = ((w.boss_tier - 1) % 5) + 1
		# 第二轮循环（tier 6）起，Boss 随机携带一个词缀
		var affix := ""
		if w.boss_tier >= 6:
			affix = AFFIXES[randi() % AFFIXES.size()]
		boss.setup(id, w.boss_tier, affix)
	boss.died.connect(w._on_boss_died)
	boss.hp_changed.connect(w._on_boss_hp)
	w.add_child(boss)

	w.boss_name_label.text = "【 %s 】" % boss.full_name()
	w.boss_name_label.show()
	w.boss_bar.max_value = boss.max_hp
	w.boss_bar.value = boss.max_hp
	w.boss_bar.show()

	w.spawn_ring(Vector3(0, 174, 0), Color(1, 0.4, 0.4), 0.4, 3.0, 0.7)
	w._shake(8.0)

static func on_boss_died(w, pos: Vector3, is_omega := false) -> void:
	w.boss_active = false
	w.boss_name_label.hide()
	w.boss_bar.hide()

	w.score += 150 + 50 * w.boss_tier
	w.play_sfx("boss_die")
	w._shake(18.0)
	w.flash_ui(Color(1, 0.6, 0.3), 0.45)
	for i in 3:
		w.spawn_ring(pos + Vector3(randf_range(-60, 60), randf_range(-40, 40), 0.0), Color(1, 0.75, 0.4), 0.3, 2.4 + i * 0.8, 0.6)

	if is_omega and not w.omega_slain:
		# ✦ 胜利：灭世母舰被击破（记录徽章，随后进入无尽模式）
		w.omega_slain = true
		w.score += 2000
		w.next_boss_at = w.kill_count + 80
		var data := SaveGame.load_data()
		data["omega"] = true
		SaveGame.save_data(data)
		w.warning_label.text = I18n.T("victory")
		w.warning_label.modulate = Color(1, 0.85, 0.35)
		w.warning_label.modulate.a = 1.0
		w.warning_label.show()
		var vtw = w.create_tween()
		vtw.tween_interval(2.2)
		vtw.tween_property(w.warning_label, "modulate:a", 0.0, 0.8)
		vtw.tween_callback(w.warning_label.hide)
		w.flash_ui(Color(1, 0.85, 0.35), 0.5)
		w.play_sfx("levelup", 0.0)
		w._shake(24.0)
		for i in 6:
			w.spawn_ring(pos + Vector3(randf_range(-120, 120), randf_range(-80, 80), 0.0), Color(1, 0.85, 0.35) if i % 2 == 0 else CYAN, 0.3, 3.0 + i * 0.7, 0.8)
		# 演出落定后弹出胜利结算（终点弧线的落点：战绩 + 徽章 + 无尽/重开选择）
		w.get_tree().create_timer(2.6).timeout.connect(w._show_victory)
	elif w.boss_tier >= 10 and not w.omega_slain:
		# 五种 Boss 两轮循环完毕：武装终局 OMEGA，短间隔后降临
		w.omega_armed = true
		w.next_boss_at = w.kill_count + 25
	else:
		w.next_boss_at = w.kill_count + 50 + w.boss_tier * 10

	# 掉落核心装备：接住后战机渐进变形
	var core = w.core_scene.instantiate()
	core.position = pos
	core.form_target = mini(w.player.form + 1, 19)
	w.add_child(core)
	# 追踪导弹道具：每击破一个 Boss 获得 1 枚
	w.homing_charges += 1
	w._update_homing_btn()
	w._toast(I18n.T("gain_homing"), GOLD)
	# Boss 破阵：敌主力接踵增援，梯次涌入形成一波数量冲击
	var wave := mini(10 + w.boss_tier * 2, 22)
	w.warning_label.text = I18n.T("warning_reinforce")
	w.warning_label.modulate.a = 1.0
	w.warning_label.show()
	var wtw = w.create_tween()
	wtw.tween_interval(1.1)
	wtw.tween_property(w.warning_label, "modulate:a", 0.0, 0.4)
	wtw.tween_callback(w.warning_label.hide)
	w.play_sfx("warning", -6.0, 0.1)
	for i in wave:
		# 不设 process_always：暂停（暂停菜单/结算）期间不再刷怪
		w.get_tree().create_timer(0.3 + i * 0.16).timeout.connect(func():
			# 主角阵亡、下一 Boss 已入场或面板暂停（升级/胜利结算）期间停止增援
			if w.health > 0 and not w.boss_active and not w.dying and not w.get_tree().paused:
				spawn_enemy(w))

	w.update_ui()
	w.get_node("Timer").start()
