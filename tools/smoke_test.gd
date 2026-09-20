extends Node

# 无头冒烟测试：真实实例化 world.tscn 并走完开局 / 升级 / 暂停 / 变形 / Boss / 复活 / 阵亡全流程
# 运行: godot --headless --path . res://tools/smoke_test.tscn
# 退出码 0 = 全部通过；1 = 有断言失败；脚本错误会直接打印到 stderr

var fails: Array = []

func check(cond: bool, name: String) -> void:
	if cond:
		print("  ok  - ", name)
	else:
		fails.append(name)
		print("  FAIL - ", name)

func _ready() -> void:
	# 后台跑，不阻塞帧循环
	_run()

func _run() -> void:
	await get_tree().process_frame
	var world = load("res://world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame

	print("== 开局 ==")
	check(world.start_panel.visible, "开始面板显示")
	check(get_tree().paused, "初始暂停")
	world._on_start_pressed()
	check(not get_tree().paused, "点击开始后解除暂停")
	check(world.pause_button.visible, "暂停按钮显示")

	print("== 战斗与刷怪 ==")
	world._spawn_formation()
	await get_tree().create_timer(1.5).timeout
	check(get_tree().get_nodes_in_group("mobs").size() > 0, "敌机已生成")
	check(world.score >= 0, "计分系统运行")

	print("== 升级三选一 ==")
	world.add_xp(20)
	check(world.levelup_panel.visible, "升级面板弹出")
	var guard := 0
	while world.levelup_panel.visible and guard < 10:
		world._on_upgrade_button_pressed(0)
		await get_tree().process_frame
		guard += 1
	check(world.pending_level_ups == 0 and not world.levelup_panel.visible, "全部升级选择完成")

	print("== 元素/弹道切换 ==")
	# 随机升级卡可能已选过元素/弹道，这里以基线增量断言，不假设从 0 开始
	var fire0 := int(world.player.element_levels.get("fire", 0))
	var hom0 := int(world.player.pattern_levels.get("homing", 0))
	world.pick_element("fire")
	world.pick_element("fire")
	check(int(world.player.element_levels.get("fire", 0)) == fire0 + 2, "同元素重复选取升级 Lv.2")
	world.pick_element("ice")
	check(world.player.element == "ice" and int(world.player.element_levels.get("fire", 0)) == fire0 + 2, "切换元素后原等级保留")
	world.pick_pattern("homing")
	check(world.player.pattern == "homing" and int(world.player.pattern_levels.get("homing", 0)) == hom0 + 1, "选追踪弹道")
	world.pick_pattern("wave")
	check(world.player.pattern == "wave" and int(world.player.pattern_levels.get("homing", 0)) == hom0 + 1, "切换弹道后等级保留")
	world.pick_pattern("spread")

	print("== 暂停菜单 ==")
	world._open_pause()
	check(get_tree().paused and world.pause_panel.visible, "暂停面板生效")
	world._on_sound_toggled()
	world._on_fx_toggled()
	world._close_pause()
	check(not get_tree().paused and not world.pause_panel.visible, "恢复游戏")

	print("== 变形演出 ==")
	world.apply_core(2)
	await get_tree().create_timer(2.5).timeout
	check(world.player.form == 2, "形态切换为 2")
	check(is_instance_valid(world._aura), "能力光环已生成")
	check(world.ability_chip.visible, "HUD 能力指示器显示")

	print("== Boss 战 ==")
	world._start_boss()
	await get_tree().create_timer(3.5).timeout
	var boss = get_tree().get_first_node_in_group("boss")
	check(boss != null, "Boss 已入场")
	if boss:
		boss.take_damage_silent(boss.max_hp * 0.6)
		check(boss.enraged, "半血狂暴触发")
		await get_tree().create_timer(1.0).timeout
		boss.take_damage_silent(999999)
		await get_tree().create_timer(1.5).timeout
		check(not world.boss_active and not world.boss_bar.visible, "Boss 阵亡结算与血条隐藏")

	print("== 循环词缀 ==")
	world.boss_tier = 6
	world._spawn_boss()
	await get_tree().create_timer(0.3).timeout
	var boss2 = get_tree().get_first_node_in_group("boss")
	check(boss2 != null and boss2.affix != "", "tier6+ Boss 带随机词缀")
	world.health = 9999   # 防止遗言弹幕等流弹干扰后续断言
	if boss2:
		boss2.take_damage_silent(999999)
	await get_tree().create_timer(1.0).timeout

	print("== OMEGA 终局 ==")
	for b in get_tree().get_nodes_in_group("enemy_bullets"):
		b.queue_free()
	world.boss_tier = 10
	world.omega_armed = true
	world._start_boss()
	await get_tree().create_timer(3.0).timeout
	var omega = get_tree().get_first_node_in_group("boss")
	check(omega != null and omega.boss_id == 6, "OMEGA 登场")
	if omega:
		omega.take_damage_silent(omega.max_hp * 0.4)   # 压到 60%：P2 狂暴
		check(omega.enraged, "OMEGA P2 狂暴")
		omega.take_damage_silent(omega.max_hp * 0.3)   # 压到 30%：P3 相位
		check(omega.phase3, "OMEGA P3 相位")
		omega.take_damage_silent(999999)
		await get_tree().create_timer(1.2).timeout
	check(world.omega_slain, "OMEGA 被击破，胜利结算")

	print("== 追踪导弹道具 ==")
	check(world.homing_charges >= 1, "击杀 Boss 获得追踪导弹")
	var hc: int = world.homing_charges
	world.player.shoot()   # 保证屏幕上有子弹（无子弹时道具不消耗）
	await get_tree().process_frame
	world._use_homing()
	check(world.homing_charges == hc - 1, "点击触发全场子弹转追踪")

	print("== 凤凰复活 ==")
	world.revive_charges = 1
	world.health = 1
	world.take_damage(99)
	check(world.revive_charges == 0, "复活次数已消耗")
	check(world.health >= 1, "复活后生命回复")

	print("== 阵亡结算 ==")
	world.revive_charges = 0
	world.health = 1
	# 复活附赠 1.2s 额外无敌帧（+0.35s 基础），等它过期后再补致命一击
	await get_tree().create_timer(2.0).timeout
	world.take_damage(99)
	await get_tree().create_timer(3.0).timeout
	check(world.dying or world.game_over_panel.visible, "阵亡演出与结算面板")
	check(get_tree().paused, "结算后暂停")

	if fails.is_empty():
		print("SMOKE OK - 全部通过")
		get_tree().quit(0)
	else:
		print("SMOKE FAILED - %d 项: %s" % [fails.size(), ", ".join(fails)])
		get_tree().quit(1)
