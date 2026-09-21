extends SceneTree

# 捕捉胜利结算画面：武装并击杀 OMEGA，等演出落定后截图到 screenshots/victory.png
# 运行: godot --path . --script res://tools/capture_victory.gd（会开窗口约 12 秒）

func _init():
	_build()

func _build() -> void:
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await create_timer(1.0).timeout
	world._on_start_pressed()
	# 摆一局典型的终局状态作为结算画面背景数据
	world.score = 58400
	world.level = 22
	world.kill_count = 812
	world.run_time = 762.0
	world.player.set_form(13)
	world._update_homing_btn()
	# 武装并击杀 OMEGA
	world.boss_tier = 10
	world.omega_armed = true
	world._start_boss()
	await create_timer(3.5).timeout
	var omega = get_first_node_in_group("boss")
	if omega != null:
		omega.take_damage_silent(999999)
	# 等击杀演出 + 结算延迟（2.6s）落定
	await create_timer(4.0).timeout
	await create_timer(0.5).timeout
	var img = root.get_texture().get_image()
	img.save_png("res://screenshots/victory.png")
	print("saved res://screenshots/victory.png  victory_panel=", world.victory_panel.visible)
	quit()
