extends SceneTree

# 游戏视角验证：正面查看主角（机头应朝上、机背朝镜头）与敌机/Boss（机头应朝下）
# 运行: godot --path . --script res://tools/preview_wrap.gd

const MB := preload("res://model_builder.gd")

func _init():
	_build.call_deferred()

func _build():
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.06, 0.12)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.6, 0.85)
	e.ambient_light_energy = 0.8
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.light_energy = 1.25
	root.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 50
	root.add_child(cam)
	cam.look_at_from_position(Vector3(0, 0, 620), Vector3(0, 0, 0))

	# 左：主角形态 0（应机头朝上）  中：主角形态 6（Executioner 蓝）  右：敌机 Spitfire 红（机头朝下）
	var p0 := MB.build_player_form(0)
	p0.position = Vector3(-260, -140, 0)
	root.add_child(p0)
	var p1 := MB.build_player_form(11)
	p1.position = Vector3(0, 0, 0)
	root.add_child(p1)
	var en := MB.build_enemy("normal")
	en.position = Vector3(260, 140, 0)
	root.add_child(en)
	var bs := MB.build_boss(1)
	bs.position = Vector3(260, -140, 0)
	bs.scale = Vector3.ONE * 0.35
	root.add_child(bs)

	var lbl := Label3D.new()
	lbl.text = "player f0 / player f11 / enemy / boss"
	lbl.font_size = 48
	lbl.pixel_size = 0.3
	lbl.position = Vector3(0, -230, 0)
	root.add_child(lbl)

	for f in 6:
		await process_frame
	root.get_texture().get_image().save_png("res://tools/preview_wrap.png")
	quit()
