extends SceneTree

# README 截图采集：真实运行游戏，抓取战斗 / Boss 战 / 变形三个瞬间
# 运行: godot --path . --script res://tools/capture.gd （弹窗约 20 秒）

func _init():
	_build.call_deferred()

func _capture(path: String):
	root.get_texture().get_image().save_png(path)
	print("captured ", path)

func _build():
	var world = (load("res://world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	# --script 启动没有 current_scene，游戏代码依赖它（子弹挂载/伤害路由等）
	current_scene = world
	# 跳过开始面板直接开局
	world.start_panel.hide()
	paused = false
	# 主角定点站桩（触屏模式零输入），无敌血量保证全程存活
	world.player.use_touch = true
	world.player.position = Vector3(0, -180, 0)
	world.max_health = 99999
	world.health = 99999
	# 加速刷怪让战斗画面饱满，禁止自动触发 Boss（后面手动召）
	world.get_node("Timer").wait_time = 0.35
	world.next_boss_at = 999999

	# 7 秒混战 → 战斗截图（按真实时间等待，帧率无关）
	await create_timer(7.0).timeout
	_capture("res://screenshots/gameplay.png")

	# 变形演出：等茧体成形并染上主题色 → 变形截图（先拍，避免 Boss 警告压屏）
	world.apply_core(3)
	await create_timer(1.05).timeout
	_capture("res://screenshots/evolution.png")

	# 强制 Boss 登场：等警报结束 + 入场 + 弹幕展开 → Boss 截图
	world._start_boss()
	await create_timer(7.0).timeout
	_capture("res://screenshots/boss.png")

	quit()
