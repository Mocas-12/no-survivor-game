extends SceneTree
func _init(): run.call_deferred()
func run():
	root.size=Vector2i(1400,1050)
	var scene=Node3D.new();root.add_child(scene);current_scene=scene
	var env=WorldEnvironment.new();env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color("091321")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	scene.add_child(env);scene.add_child(DirectionalLight3D.new())
	preload("res://scripts/visual_finish.gd").apply(scene)
	var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=850;camera.position=Vector3(0,0,1000);scene.add_child(camera)
	for i in 12:
		var id=i/2+1;var phase=i%2+1
		var model=preload("res://scripts/blender_hostiles.gd").build("boss",id,165,false,phase)
		model.position=Vector3(-420+(i%4)*280,280-(i/4)*260,0)
		model.rotation_degrees=Vector3(20,-15,0);scene.add_child(model)
		var label=Label3D.new();label.text="%s · P%d"%[preload("res://scripts/fleet_review.gd").CATALOG_NAMES[1][id-1],phase]
		label.font=preload("res://assets/fonts/NoSurvivorUI.ttf");label.font_size=28
		label.pixel_size=.65;label.position=model.position+Vector3(0,-100,20);scene.add_child(label)
	await create_timer(.9).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/boss-phase-comparison.png")
	for n in scene.get_children():
		if n!=camera and not n is WorldEnvironment and not n is DirectionalLight3D: n.queue_free()
	await process_frame
	var kinds=["steam","melt","freeze","conduct","shatter","overload"]
	for i in 6:
		var pos=Vector3(-350+(i%3)*350,170-(i/3)*340,0)
		preload("res://scripts/reaction_fx.gd").emit(scene,pos,kinds[i])
		var label=Label3D.new();label.text=kinds[i];label.font_size=30;label.pixel_size=.8;label.position=pos+Vector3(0,-100,20);scene.add_child(label)
	await create_timer(.14).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/element-reactions-comparison.png")
	print("COMBAT_REVISION_CAPTURE_COMPLETE");quit()
