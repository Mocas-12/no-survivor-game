extends SceneTree
const FX=preload("res://scripts/layered_fx.gd")
func _init(): run.call_deferred()
func run():
	root.size=Vector2i(1200,720)
	var scene=Node3D.new();root.add_child(scene);current_scene=scene
	var env=WorldEnvironment.new();env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("101c29")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	scene.add_child(env);scene.add_child(DirectionalLight3D.new())
	var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=720;camera.position=Vector3(0,0,1000);scene.add_child(camera)
	var effects=[]
	for i in 6:
		var pos=Vector3(-360+(i%3)*360,160-(i/3)*320,0)
		var kind=["steam","melt","freeze","conduct","shatter","overload"][i]
		var fx=FX.burst(scene,pos,kind,1.65,777+i);fx.set_process(false);effects.append(fx)
		var label=Label3D.new();label.text=kind;label.font_size=24;label.pixel_size=.6
		label.position=pos+Vector3(0,-110,10);scene.add_child(label)
	var last=0.0
	DirAccess.make_dir_recursive_absolute("res://screenshots/vfx-timeline")
	for time in [.03,.10,.20,.35,.60,1.0,1.5,2.2]:
		for fx in effects: fx.advance(time-last)
		last=time
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://screenshots/vfx-timeline/%04dms.png"%roundi(time*1000))
	print("VFX_TIMELINE_COMPLETE 8 exact-time frames");quit()
