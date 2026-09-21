extends Node

# 无头平衡测试：自动驾驶 bot 打完整局，输出各 tier Boss TTK / 承伤 / 升级节奏 / 场面密度等数据表
# 运行: godot --headless --path . res://tools/balance_test.tscn
# 环境变量: BAL_RUNS=bot 轮数(默认3)  BAL_TIME_SCALE=时间倍速(默认4, 上限8)  BAL_TIMEOUT=单局游戏分钟上限(默认15)
# 说明:
#   - 幽灵轮(1轮): 无敌参照，保证拿到完整时长的 Boss TTK / 到 OMEGA 节奏曲线（承伤数据无效属预期）
#   - bot 轮: 会死的"底部风筝流"玩家，负责 胜率 / 承伤 / 存活时长 数据
#   - 站桩轮(2轮): 不躲避的基线，仅校准刷怪压力
#   - time_scale 加速下物理步进偏粗，数据用于调参相对比较而非绝对标定
# 退出码 0 = 正常完成

# bot 选卡优先级：射速/伤害/弹道打底，火+雷主元素（烧超载反应链，压力测试上限最高的流派）
const CARD_PRIORITY := [
	"fire_rate", "damage", "multishot",
	"fire", "lightning", "chain_reaction", "armor", "crit", "element_last",
	"speed", "water", "wind", "ice", "wave",
	"xp", "magnet", "velocity", "revive", "wide",
]
const STEP := 0.1   # 主循环节拍（游戏秒）：转向每步都做，统计每 2 步采一次

var _timeout := 15.0 * 60.0   # 单局上限（游戏秒），BAL_TIMEOUT 可覆盖
var _reports: Array = []

func _ready() -> void:
	preload("res://scripts/save.gd").disabled = true
	_go()

func _go() -> void:
	await get_tree().process_frame   # 等 _ready 调用栈退出来，才能往 root 挂子节点
	var bot_runs := 3
	var tscale := 4.0
	var env_runs := OS.get_environment("BAL_RUNS")
	if env_runs != "":
		bot_runs = maxi(1, int(env_runs))
	var env_ts := OS.get_environment("BAL_TIME_SCALE")
	if env_ts != "":
		tscale = clampf(float(env_ts), 1.0, 8.0)
	var env_to := OS.get_environment("BAL_TIMEOUT")
	if env_to != "":
		_timeout = maxf(float(env_to), 1.0) * 60.0
	print("== 平衡测试: 1 幽灵轮 + %d bot 轮 + 2 站桩轮, %sx 加速, 单局上限 %.0f 游戏分钟 ==" % [bot_runs, tscale, _timeout / 60.0])
	await _one_run("ghost", tscale, 0)
	for i in bot_runs:
		await _one_run("bot", tscale, i + 1)
	for i in 2:
		await _one_run("still", tscale, i + 1)
	_print_report()
	get_tree().quit(0)

func _one_run(mode: String, tscale: float, idx: int) -> void:
	Engine.time_scale = 1.0
	var world = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child(world)   # 必须挂 root：current_scene 只认根下节点
	await get_tree().process_frame
	await get_tree().process_frame
	# 游戏代码经 get_tree().current_scene 路由（敌方开火/水晶拾取/接触伤害等 has_method 守卫），
	# 测试场景下必须手动接管，否则全部静默失效（同 tools/capture.gd 的做法）
	get_tree().current_scene = world
	world._on_start_pressed()
	Engine.time_scale = tscale
	var player = world.player
	var use_bot := mode != "still"
	player.autopilot = use_bot
	player.autopilot_target = Vector3(0, -220, 0)
	if mode == "ghost":
		world.max_health = 99999
		world.health = 99999   # 幽灵参照：只测节奏曲线，不受承伤截断

	var run := {
		"mode": mode, "result": "超时", "sim_time": 0.0,
		"score": 0, "level": 1, "kills": 0, "boss_tier": 0,
		"dmg": 0, "dmg_events": 0, "dmg_contact": 0, "dmg_bullet": 0,
		"peak_mobs": 0, "peak_bullets": 0,
		"ttk": {}, "bhp": {}, "t_omega": -1.0,
	}
	_dodge_dir = 0.0
	_dodge_ttl = 0.0
	var last_health: int = world.health
	var boss_start := -1.0     # 当前 Boss 的首次目击时刻（<0 表示场上无存活 Boss）
	var boss_tier_at := 0
	var homing_cd := 0.0
	var stall := 0             # 暂停却不在升级面板的连续采样数（保险丝）
	var tick := 0

	while float(run["sim_time"]) < _timeout:
		await get_tree().create_timer(STEP).timeout
		if not is_instance_valid(world):
			break
		# 结束条件：OMEGA 被击破（立即，胜利面板出现前）/ 阵亡演出
		if world.omega_slain:
			run["result"] = "胜利"
			run["t_omega"] = run["sim_time"]
			break
		if world.dying or world.game_over_panel.visible:
			run["result"] = "阵亡"
			break
		if get_tree().paused:
			_pick_card(world)   # 升级面板期间自动选卡
			if world.levelup_panel.visible:
				stall = 0
			else:
				stall += 1
				if stall > 100:
					run["result"] = "停滞"
					break
			continue
		stall = 0
		run["sim_time"] = float(run["sim_time"]) + STEP
		homing_cd = maxf(homing_cd - STEP, 0.0)

		# 自动驾驶（每步都转向）；统计与道具按低频节拍采样
		if use_bot:
			_steer(player, STEP)
			if world.boss_active and world.homing_charges > 0 and homing_cd <= 0.0:
				homing_cd = 1.0
				world._use_homing()

		tick += 1
		if tick % 2 == 0:
			# Boss TTK：从首次目击存活 Boss 到其 dead / boss_active 翻落
			var boss = get_tree().get_first_node_in_group("boss")
			if boss != null and not boss.dead and boss_start < 0.0:
				boss_start = float(run["sim_time"])
				boss_tier_at = world.boss_tier
				run["bhp"][boss_tier_at] = float(boss.max_hp)
			if boss_start >= 0.0 and (boss == null or boss.dead or not world.boss_active):
				run["ttk"][boss_tier_at] = float(run["sim_time"]) - boss_start
				boss_start = -1.0
			# 场面密度与承伤采样
			run["peak_mobs"] = maxi(int(run["peak_mobs"]), get_tree().get_nodes_in_group("mobs").size())
			run["peak_bullets"] = maxi(int(run["peak_bullets"]), get_tree().get_nodes_in_group("enemy_bullets").size())
			var hp_now: int = world.health
			if hp_now < last_health:
				var drop := last_health - hp_now
				run["dmg"] = int(run["dmg"]) + drop
				run["dmg_events"] = int(run["dmg_events"]) + 1
				# 来源启发式：掉血瞬间附近 ≤100px 有敌机记为撞机，否则记为 中弹
				var hit_pos: Vector3 = world.player.global_position
				var contact := false
				for m in get_tree().get_nodes_in_group("mobs"):
					if not m.dead and hit_pos.distance_to(m.global_position) <= 100.0:
						contact = true
						break
				if contact:
					run["dmg_contact"] = int(run["dmg_contact"]) + drop
				else:
					run["dmg_bullet"] = int(run["dmg_bullet"]) + drop
			last_health = hp_now

	run["score"] = world.score
	run["level"] = world.level
	run["kills"] = world.kill_count
	run["boss_tier"] = world.boss_tier
	_reports.append(run)
	_print_run(idx, run)

	# 等挂起的 SceneTreeTimer（增援波 / 胜利面板延迟等）自然过期，避免释放 world 后回调悬空
	Engine.time_scale = 1.0
	await get_tree().create_timer(4.5).timeout
	get_tree().current_scene = self
	world.free()
	await get_tree().process_frame

var _dodge_dir := 0.0   # 织躲方向锁定（0.5s 内不许翻转，防止原地抖动喂弹）
var _dodge_ttl := 0.0

# 走位：Boss 战贴在 Boss 正下方对轴输出；平时蹲下缘，横向织躲最近子弹（0.25s 前瞻），
# 近身敌机推离，无威胁时捡低空水晶。模拟该品类的主流打法。
func _steer(player, dt: float) -> void:
	var pos: Vector3 = player.global_position
	_dodge_ttl = maxf(_dodge_ttl - dt, 0.0)
	var target := Vector3(pos.x, -250.0, 0.0)
	var boss = get_tree().get_first_node_in_group("boss")
	var boss_alive: bool = boss != null and not boss.dead
	if boss_alive:
		target = Vector3(boss.global_position.x, boss.global_position.y - 280.0, 0.0)
	# 水平织躲：小幅度侧移（满速大横扫反而会主动穿过弹幕），方向带锁定防抖
	var nearest_d := 300.0
	var dodge := 0.0
	for b in get_tree().get_nodes_in_group("enemy_bullets"):
		var future: Vector3 = b.global_position + b.dir * float(b.speed) * 0.25
		var diff: Vector3 = pos - future
		var d := Vector2(diff.x, diff.y).length()
		if d < nearest_d:
			nearest_d = d
			dodge = 1.0 if diff.x >= 0.0 else -1.0
	if dodge != 0.0:
		if _dodge_ttl > 0.0 and _dodge_dir != 0.0:
			dodge = _dodge_dir
		else:
			_dodge_dir = dodge
			_dodge_ttl = 0.35
		target.x = pos.x + dodge * 120.0
	elif _dodge_ttl > 0.0 and _dodge_dir != 0.0:
		# 危险解除前不急着回位：最近的子弹已在 300px 外才逐步回归基准位
		dodge = _dodge_dir
		target.x = pos.x + dodge * 60.0
	# 近身敌机推离（撞机伤害高，权重最重）
	var mob_push := Vector3.ZERO
	for m in get_tree().get_nodes_in_group("mobs"):
		if m.dead:
			continue
		var to_m: Vector3 = pos - m.global_position
		var d2 := to_m.length()
		if d2 < 200.0 and d2 > 1.0:
			mob_push += to_m * ((200.0 - d2) / 200.0 / d2)
	target += mob_push * 1.8
	# 无威胁时捡下方水晶（模拟真实玩家的拾取循环；Boss 战不追水晶）
	if dodge == 0.0 and mob_push.length() < 10.0 and not boss_alive:
		var best_d := 420.0
		var gem_pos := Vector3.ZERO
		var has_gem := false
		for g in get_tree().get_nodes_in_group("gems"):
			if g.global_position.y > 80.0:
				continue   # 只捡下半场的水晶，不深入刷怪口
			var d3 := pos.distance_to(g.global_position)
			if d3 < best_d:
				best_d = d3
				gem_pos = g.global_position
				has_gem = true
		if has_gem:
			target = gem_pos
	player.autopilot_target = Vector3(clampf(target.x, -520.0, 520.0), clampf(target.y, -280.0, 240.0), 0.0)

# 升级三选一：按流派优先级选卡（读按钮 meta，不走游戏逻辑捷径）
func _pick_card(world) -> void:
	if not world.levelup_panel.visible:
		return
	var best_i := -1
	var best_rank := 9999
	for i in world.upgrade_buttons.size():
		var btn = world.upgrade_buttons[i]
		if not btn.has_meta("upgrade"):
			return   # 面板尚未填充完
		var id := String(btn.get_meta("upgrade")["id"])
		var rank := CARD_PRIORITY.find(id)
		if rank < 0:
			rank = 999
		if rank < best_rank:
			best_rank = rank
			best_i = i
	if best_i >= 0:
		world._on_upgrade_button_pressed(best_i)

func _print_run(idx: int, run: Dictionary) -> void:
	var mode_name := "bot"
	if run["mode"] == "ghost":
		mode_name = "幽灵"
	elif run["mode"] == "still":
		mode_name = "站桩"
	var keys = run["ttk"].keys()
	keys.sort()
	var ttk_parts := []
	for k in keys:
		ttk_parts.append("T%d:%.0fs/%.0f血" % [k, float(run["ttk"][k]), float(run["bhp"].get(k, 0.0))])
	var omega_note := ""
	if float(run["t_omega"]) >= 0.0:
		omega_note = " | 到OMEGA %.1fmin" % (float(run["t_omega"]) / 60.0)
	print("轮%d[%s] %s | 时长%.1fmin 积分%d 等级%d Boss%d 击杀%d | 承伤%d(触%d/弹%d, %d次) 峰值敌机%d/敌弹%d | TTK %s%s" % [
		idx, mode_name, run["result"], float(run["sim_time"]) / 60.0,
		run["score"], run["level"], run["boss_tier"], run["kills"],
		run["dmg"], run["dmg_contact"], run["dmg_bullet"], run["dmg_events"],
		run["peak_mobs"], run["peak_bullets"],
		", ".join(ttk_parts), omega_note,
	])

func _print_report() -> void:
	print("\n== Boss 节奏曲线（幽灵轮）==")
	print("tier | 平均TTK | 平均血量 | 有效DPS(血/TTK)")
	var sum_t := {}
	var sum_hp := {}
	var n := {}
	for run in _reports:
		if run["mode"] != "ghost":
			continue
		var keys = run["ttk"].keys()
		for k in keys:
			sum_t[k] = float(sum_t.get(k, 0.0)) + float(run["ttk"][k])
			sum_hp[k] = float(sum_hp.get(k, 0.0)) + float(run["bhp"].get(k, 0.0))
			n[k] = int(n.get(k, 0)) + 1
	var tkeys = sum_t.keys()
	tkeys.sort()
	for k in tkeys:
		var avg_t: float = float(sum_t[k]) / int(n[k])
		var avg_hp: float = float(sum_hp[k]) / int(n[k])
		print("T%d | %.1fs | %.0f | %.0f" % [k, avg_t, avg_hp, avg_hp / maxf(avg_t, 0.1)])
	print("\n== 汇总 ==")
	var bot_runs := 0
	var wins := 0
	var total_min := 0.0
	var total_dmg := 0
	for run in _reports:
		if run["mode"] == "bot":
			bot_runs += 1
			if run["result"] == "胜利":
				wins += 1
		if run["mode"] != "still":
			total_min += float(run["sim_time"]) / 60.0
			total_dmg += int(run["dmg"])
	if bot_runs > 0:
		print("bot 胜率: %d/%d | bot 平均承伤: %.1f/分钟 | bot 幽灵平均单局: %.1fmin" % [
			wins, bot_runs, float(total_dmg) / maxf(total_min, 0.1), total_min / float(bot_runs)])
	print("注: 幽灵轮=无敌参照(承伤无效)；bot=会死的风筝玩家；站桩=不躲避基线；加速下物理偏粗，TTK 略乐观")
