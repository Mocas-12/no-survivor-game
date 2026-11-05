extends SceneTree
func _init() -> void: run.call_deferred()
func run() -> void:
	root.size=Vector2i(1400,1050)
	var scene:=Node3D.new()
	root.add_child(scene)
	current_scene=scene
	var env:=WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color("091321")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	scene.add_child(env)
	scene.add_child(DirectionalLight3D.new())
	preload("res://scripts/visual_finish.gd").apply(scene)
	var camera:=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=850
	camera.position=Vector3(0,0,1000)
	scene.add_child(camera)
	var names: Array=preload("res://scripts/fleet_review.gd").CATALOG_NAMES[0]+preload("res://scripts/fleet_review.gd").CATALOG_NAMES[1]
	for i in 12:
		var model:=preload("res://scripts/blender_hostiles.gd").build("enemy" if i<6 else "boss",i if i<6 else i-5,180,false)
		model.position=Vector3(-420+(i%4)*280,280-(i/4)*260,0)
		model.rotation_degrees=Vector3(20,-15,0)
		scene.add_child(model)
		var label:=Label3D.new()
		label.text=names[i]
		label.font=preload("res://assets/fonts/NoSurvivorUI.ttf")
		label.font_size=28
		label.pixel_size=.65
		label.position=model.position+Vector3(0,-115,20)
		scene.add_child(label)
	await create_timer(.8).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/blender-hostile-overview.png")
	print("HOSTILE_OVERVIEW_COMPLETE")
	quit()
