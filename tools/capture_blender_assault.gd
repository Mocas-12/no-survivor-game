extends SceneTree
const MB=preload("res://scripts/model_builder.gd")
const B=preload("res://scripts/branch_visual.gd")
func _init() -> void: run.call_deferred()
func capture(path: String) -> void:
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run() -> void:
	root.size=Vector2i(1600,1000)
	var scene:=Node3D.new()
	root.add_child(scene)
	current_scene=scene
	var env:=WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color("091321")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	scene.add_child(env)
	var sun:=DirectionalLight3D.new()
	scene.add_child(sun)
	preload("res://scripts/visual_finish.gd").apply(scene)
	var cam:=Camera3D.new()
	cam.projection=Camera3D.PROJECTION_ORTHOGONAL
	cam.size=300
	cam.position=Vector3(0,0,1000)
	scene.add_child(cam)
	for i in 2:
		B.use_blender_assault=i==1
		var ship=MB.build_player_form(1)
		B.decorate(ship,"assault")
		ship.scale*=1.6
		ship.position.x=-125 if i==0 else 125
		ship.rotation_degrees.x=30
		ship.rotation_degrees.y=-15
		scene.add_child(ship)
		var label:=Label3D.new()
		label.text="原几何模型" if i==0 else "Blender · 真实曲面原型"
		label.font=preload("res://assets/fonts/NoSurvivorUI.ttf")
		label.font_size=26
		label.pixel_size=0.32
		label.position=Vector3(ship.position.x,-120,0)
		scene.add_child(label)
	await capture("res://screenshots/blender-assault-godot-comparison.png")
	scene.queue_free()
	await process_frame
	root.size=Vector2i(1152,648)
	preload("res://scripts/save.gd").disabled=true
	var w=load("res://scenes/world.tscn").instantiate()
	root.add_child(w)
	current_scene=w
	w._on_start_pressed()
	w.get_node("Timer").stop()
	B.use_blender_assault=true
	B.decorate(w.player.model,"assault")
	w.player._glow_mat=w.player.model.get_meta("glow_mat")
	w.player.use_touch=true
	w.player.position=Vector3(0,-150,0)
	await capture("res://screenshots/blender-assault-gameplay.png")
	w.director.request_evolution(1)
	await capture("res://screenshots/blender-assault-choice.png")
	print("BLENDER ASSAULT: actual GLB comparison, gameplay and branch choice captured")
	quit()
