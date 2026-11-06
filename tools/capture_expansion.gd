extends SceneTree
func _init() -> void: capture.call_deferred()
func capture() -> void:
	root.size=Vector2i(1440,900)
	var scene:=Node3D.new()
	root.add_child(scene)
	current_scene=scene
	var env:=WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color("0b1424")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color("9db5ce")
	env.environment.ambient_light_energy=.85
	scene.add_child(env)
	var light:=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-25,-35,0)
	light.light_energy=1.8
	scene.add_child(light)
	var camera:=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=1000
	camera.position=Vector3(0,0,1100)
	scene.add_child(camera)
	for id in range(1,7):
		for phase in [1,2]:
			var model=preload("res://scripts/blender_hostiles.gd").build("boss",id,170,true,phase)
			model.position=Vector3((id-3.5)*230,140 if phase==1 else -140,0)
			scene.add_child(model)
	await create_timer(.9).timeout
	root.get_texture().get_image().save_png("res://screenshots/expansion-boss-comparison.png")
	scene.queue_free()
	await process_frame
	preload("res://scripts/save.gd").disabled=true
	var w=load("res://scenes/world.tscn").instantiate()
	root.add_child(w)
	current_scene=w
	await process_frame
	root.get_texture().get_image().save_png("res://screenshots/expansion-menu.png")
	w._on_start_pressed()
	w.campaign.set_process(false)
	w.director.set_process(false)
	w.campaign.status.hide()
	w.health=10000
	w.max_health=10000
	w.player.use_touch=true
	w.player.position=Vector3(0,-180,0)
	w.player.modules={"split":true,"wetwake":true}
	w.player.element="fire"
	w.player.damage=4
	w.player.weapon="missile"
	w.run_time=100
	w.director.advanced_encounter(9)
	await create_timer(2).timeout
	root.get_texture().get_image().save_png("res://screenshots/expansion-combat.png")
	w.pending_level_ups=1
	w.show_level_up()
	for i in 3:
		var id: String=["rail","split","reaction_salvage"][i]
		w.upgrade_buttons[i].set_meta("upgrade",w.upgrade_pool.filter(func(up):return up.id==id)[0])
	w.levelup_panel.get_node("ModuleDraft").present()
	await create_timer(.8).timeout
	root.get_texture().get_image().save_png("res://screenshots/expansion-cards.png")
	w.levelup_panel.hide()
	paused=false
	for stage in 3:
		w.boss_tier=stage
		w.boss_active=false
		w.campaign.update_act()
		await create_timer(.15).timeout
		root.get_texture().get_image().save_png("res://screenshots/full-plan-act-%d.png" % (stage+1))
	w.campaign.update_recap()
	w.omega_slain=true
	w._show_victory()
	await create_timer(.2).timeout
	root.get_texture().get_image().save_png("res://screenshots/full-plan-victory.png")
	print("EXPANSION_CAPTURE_OK")
	quit()
