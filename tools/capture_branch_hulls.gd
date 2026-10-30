extends SceneTree
const MB=preload("res://scripts/model_builder.gd")
const BRANCH=preload("res://scripts/branch_visual.gd")
func _init() -> void: run.call_deferred()
func run() -> void:
	root.size=Vector2i(1600,1100)
	var scene:=Node3D.new()
	root.add_child(scene)
	current_scene=scene
	var environment:=WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color("091321")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	scene.add_child(environment)
	var sun:=DirectionalLight3D.new()
	scene.add_child(sun)
	preload("res://scripts/visual_finish.gd").apply(scene)
	var cam:=Camera3D.new()
	cam.projection=Camera3D.PROJECTION_ORTHOGONAL
	cam.size=820
	cam.position=Vector3(0,0,1200)
	scene.add_child(cam)
	for row in 4:
		for col in 3:
			var variant: int=[1,6,11,19][row]
			var branch: String=["assault","escort","siege"][col]
			var ship=MB.build_player_form(variant)
			BRANCH.decorate(ship,branch)
			ship.position=Vector3((col-1)*275,270-row*180,0)
			scene.add_child(ship)
			var label:=Label3D.new()
			label.text=["突击","护航","歼灭"][col]+" / F-%02d" % (variant+1)
			label.font=preload("res://assets/fonts/NoSurvivorUI.ttf")
			label.font_size=27
			label.pixel_size=0.46
			label.position=ship.position+Vector3(0,-88,0)
			scene.add_child(label)
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/branch-hull-sheet.png")
	print("BRANCH HULLS captured at actual world size, 4 evolution stages")
	quit()
