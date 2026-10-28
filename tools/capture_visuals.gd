extends SceneTree
const MB := preload("res://scripts/model_builder.gd")

func _init() -> void:
	run.call_deferred()

func capture(path: String) -> void:
	await create_timer(0.7).timeout
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("CAPTURE ",path)

func run() -> void:
	preload("res://scripts/save.gd").disabled = true
	root.size = Vector2i(1152,648)
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await capture("res://screenshots/redesign-menu.png")
	world._on_start_pressed()
	world.player.use_touch = true
	world.player.position = Vector3(0,-170,0)
	world.health = 99999
	world.max_health = 99999
	world.next_boss_at = 999999
	await create_timer(3).timeout
	await capture("res://screenshots/redesign-gameplay.png")
	world.apply_core(10)
	await capture("res://screenshots/redesign-evolution.png")
	await create_timer(2.0).timeout
	world.show_level_up()
	await capture("res://screenshots/redesign-upgrades.png")
	world.levelup_panel.hide()
	paused = false
	world._spawn_boss()
	await create_timer(3).timeout
	await capture("res://screenshots/redesign-boss.png")
	world._open_pause()
	await capture("res://screenshots/redesign-pause.png")
	world.pause_panel.hide()
	world.game_over()
	await capture("res://screenshots/redesign-result.png")
	world.game_over_panel.hide()
	world.omega_slain = true
	world._show_victory()
	await capture("res://screenshots/redesign-victory.png")
	world.queue_free()
	paused = false
	await process_frame
	root.size = Vector2i(1600,1000)
	var scene := Node3D.new()
	root.add_child(scene)
	var env := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("091320")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("b0cce3")
	settings.ambient_light_energy = 0.7
	env.environment = settings
	scene.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-25,-30,0)
	sun.light_energy = 1.6
	scene.add_child(sun)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 790
	cam.position = Vector3(0,0,1200)
	scene.add_child(cam)
	var names: Array[String] = []
	var models: Array[Node3D] = []
	for i in 20:
		names.append("F-%02d" % (i+1))
		var model := MB.build_player_form(i)
		model.scale *= 100.0/(115.0+i*1.8)
		models.append(model)
	for kind in MB.ENEMY_SHIPS:
		names.append(kind)
		var model := MB.build_enemy(kind)
		model.scale *= 100.0/MB.ENEMY_SHIPS[kind][2]
		models.append(model)
	for id in MB.BOSS_SHIPS:
		names.append("BOSS-%d" % id)
		var model := MB.build_boss(id)
		model.scale *= 100.0/MB.BOSS_SHIPS[id][2]
		models.append(model)
	for i in models.size():
		var model := models[i]
		model.position = Vector3((i%8-3.5)*145,275-(i/8)*180,0)
		scene.add_child(model)
		var label := Label3D.new()
		label.text = names[i]
		label.font_size = 32
		label.pixel_size = 0.5
		label.position = model.position+Vector3(0,-70,0)
		scene.add_child(label)
	await capture("res://screenshots/redesign-fleet.png")
	quit()
