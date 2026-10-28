extends SceneTree
func _init() -> void:
	run.call_deferred()
func run() -> void:
	preload("res://scripts/save.gd").disabled=true
	root.size=Vector2i(1152,648)
	var world=load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	current_scene=world
	world.start_panel.hide()
	world.pending_level_ups=1
	world.show_level_up()
	var ids=["multishot","velocity","element_last"]
	for i in 3:
		var id: String=ids[i]
		var candidates: Array=world.upgrade_pool.filter(func(u):return u.id==id)
		world.upgrade_buttons[i].set_meta("upgrade",candidates[0])
	world.levelup_panel.get_node("ModuleDraft").present()
	await create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/visual-v2-final-cards.png")
	print("Final module preview captured")
	quit()
