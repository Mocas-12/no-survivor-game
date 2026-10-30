extends SceneTree
func _init() -> void: run.call_deferred()
func capture(name: String) -> void:
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/run-"+name+".png")
func run() -> void:
	preload("res://scripts/save.gd").disabled=true
	root.size=Vector2i(1152,648)
	var w=load("res://scenes/world.tscn").instantiate()
	root.add_child(w)
	current_scene=w
	await capture("menu")
	w.director.archive_button.pressed.emit()
	await capture("archive")
	w.director.close_archive.pressed.emit()
	w._on_start_pressed()
	w.get_node("Timer").stop()
	w.player.position=Vector3(0,-190,0)
	w.player.use_touch=true
	w.health=10000
	w.max_health=10000
	w.run_time=20
	w.add_xp(5)
	await capture("draft")
	w._apply_upgrade_choice(0)
	preload("res://scripts/upgrades.gd").auxiliary(w,"water")
	w.director.check_combo()
	w.director.request_evolution(1)
	await capture("evolution")
	print("PREVIEW ",w.director.panel.get_global_rect(), " BUTTON ",w.director.buttons[0].get_global_rect())
	w.director.choose_branch(1)
	await create_timer(1.8).timeout
	w.director.draft_after=1000
	w.director.encounter_after=1000
	w.director.elite_after=1000
	for i in 5:
		w.director.make_enemy("shield" if i<3 else "shooter",Vector3((i-2)*145,160+i*20,0))
	await capture("battle")
	w.game_over()
	await capture("result")
	print("RUN CAPTURES OK · controlled presentation captures")
	quit()
