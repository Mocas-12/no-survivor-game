extends SceneTree
## Controlled presentation setup using real actors/shots; not a recorded player victory.
func _init() -> void: run.call_deferred()
func capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run() -> void:
	root.size=Vector2i(1152,648)
	preload("res://scripts/save.gd").disabled=true
	var w=load("res://scenes/world.tscn").instantiate()
	root.add_child(w)
	current_scene=w
	w._on_start_pressed()
	w.get_node("Timer").stop()
	w.director.encounter_after=1000
	w.director.elite_after=1000
	w.player.use_touch=true
	w.player.position=Vector3(0,-210,0)
	w.player.branch="escort"
	w.player.set_form(9)
	w.player.element="fire"
	for i in 6:
		w.director.make_enemy(["normal","fast","swift","shooter","shield","tank"][i],Vector3(-420+i*165,80+(i%2)*70,0))
	var boss=load("res://scenes/boss.tscn").instantiate()
	w.add_child(boss)
	boss.setup(6,1)
	w.boss_active=true
	await create_timer(1.8).timeout
	await capture("res://screenshots/fleet-combat-presentation.png")
	w.spawn_explosion(Vector3(-180,0,0),Color("f5a16b"),true)
	w.spawn_hit_spark(Vector3(100,-50,0),"lightning")
	await create_timer(.12).timeout
	await capture("res://screenshots/fleet-effects-combat.png")
	w.player.set_physics_process(false)
	w.director.request_evolution(10)
	await create_timer(.2).timeout
	await capture("res://screenshots/fleet-evolution-choice.png")
	print("FLEET_COMBAT_CAPTURE_COMPLETE")
	quit()
