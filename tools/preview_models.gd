extends SceneTree

# 模型预览工具：把 11 艘飞船排成两行渲染一张截图，用于确认机头朝向与外观
# 运行: godot --path . --script res://tools/preview_models.gd （弹出窗口约 2 秒后自动退出）

const SHIPS := ["Bob", "Challenger", "Dispatcher", "Executioner", "Imperial", "Insurgent", "Omen", "Pancake", "Spitfire", "Striker", "Zenith"]
const COLORS := {"Bob": "Blue", "Challenger": "Blue", "Dispatcher": "Blue", "Executioner": "Red", "Imperial": "Orange", "Insurgent": "Blue", "Omen": "Purple", "Pancake": "Blue", "Spitfire": "Red", "Striker": "Orange", "Zenith": "Green"}

func _init():
	_build.call_deferred()

func _build():
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.06, 0.12)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.75, 0.9)
	e.ambient_light_energy = 0.9
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	root.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 50
	root.add_child(cam)
	# 正俯视：屏幕右 = +X，屏幕上 = -Z（up 指向 -Z）
	cam.look_at_from_position(Vector3(0, 230, 0), Vector3(0, 0, 0), Vector3(0, 0, -1))

	var i := 0
	for s in SHIPS:
		var mesh: Mesh = load("res://assets/ships/%s/%s.obj" % [s, s])
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		# 归一化到最长边 44
		var aabb := mesh.get_aabb()
		var longest: float = maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
		mi.scale = Vector3.ONE * (44.0 / longest)
		var col := i % 6
		var row := i / 6
		mi.position = Vector3((col - 2.5) * 82.0, 0, row * 82.0 - 20.0)
		root.add_child(mi)
		# 真实涂装：认清机头细节
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = load("res://assets/ships/%s/Textures/%s_%s.png" % [s, s, COLORS[s]])
		mat.metallic = 0.35
		mat.roughness = 0.5
		mi.material_override = mat
		var lbl := Label3D.new()
		lbl.text = s
		lbl.font_size = 64
		lbl.pixel_size = 0.3
		lbl.position = mi.position + Vector3(0, 20, 34)
		root.add_child(lbl)
		i += 1

	for f in 6:
		await process_frame
	var img := root.get_texture().get_image()
	img.save_png("res://tools/preview.png")
	quit()
