extends SceneTree
func _init(): run.call_deferred()
func run():
	root.size=Vector2i(1152,648)
	preload("res://scripts/save.gd").disabled=true
	var w=load("res://scenes/world.tscn").instantiate()
	root.add_child(w)
	current_scene=w
	await process_frame
	w._on_start_pressed()
	w.get_node("Timer").stop()
	w.director.set_process(false)
	w.player.use_touch=true
	w.player.position=Vector3(0,-180,0)
	await create_timer(.5).timeout
	root.get_texture().get_image().save_png("res://screenshots/flight-before.png")
	await create_timer(2).timeout
	root.get_texture().get_image().save_png("res://screenshots/flight-after.png")
	w.run_time=55
	await create_timer(.2).timeout
	root.get_texture().get_image().save_png("res://screenshots/convoy-centered.png")
	print("CAMPAIGN_CAPTURE_OK")
	paused=false
	quit()
