extends SceneTree
const MB := preload("res://scripts/model_builder.gd")
func _init() -> void:
	run.call_deferred()

func run() -> void:
	root.size = Vector2i(1600,900)
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("091320")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("b0cce3")
	e.ambient_light_energy = 0.65
	env.environment = e
	scene.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-25,-30,0)
	sun.light_energy = 1.6
	scene.add_child(sun)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 560
	cam.position = Vector3(0,0,1200)
	scene.add_child(cam)
	var names := ["攻击机 / BATWING","拦截针 / NEEDLE","疾风 / TRI-WING","炮艇 / GUNBOAT","盾甲 / AEGIS","攻城 / SIEGE","毁灭者 / ARTILLERY","拦截者 / SPLIT BLADE","要塞 / HEX BASTION","猎手 / RAIL HUNTER","幻影 / GHOST","终局 / OMEGA"]
	var i := 0
	for kind in MB.ENEMY_SHIPS:
		var model := MB.build_enemy(kind)
		model.scale *= 90.0/MB.ENEMY_SHIPS[kind][2]
		place(scene,model,i,names[i])
		i+=1
	for id in MB.BOSS_SHIPS:
		var model := MB.build_boss(id)
		model.scale *= 150.0/MB.BOSS_SHIPS[id][2]
		place(scene,model,i,names[i])
		i+=1
	await create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/visual-v2-enemies.png")
	for child in scene.get_children(): child.queue_free()
	await process_frame
	var mesh_nodes: Array[Node3D] = []
	var pg := preload("res://scripts/projectile_geometry.gd")
	for kind in pg.PLAYER:
		var mi := MeshInstance3D.new()
		mi.mesh = pg.mesh(kind,false)
		mi.material_override = pg.material(kind,false)
		mi.scale = Vector3.ONE*4
		mesh_nodes.append(mi)
	for kind in pg.ENEMY:
		var mi := MeshInstance3D.new()
		mi.mesh = pg.mesh(kind,true)
		mi.material_override = pg.material(kind,true)
		mi.scale = Vector3.ONE*4
		mesh_nodes.append(mi)
	# Separate projectile plate uses a fresh camera after the ship plate.
	scene.add_child(cam.duplicate() if is_instance_valid(cam) else camera())
	var backdrop := WorldEnvironment.new()
	backdrop.environment=e
	scene.add_child(backdrop)
	var labels: Array = pg.PLAYER.keys()+pg.ENEMY.keys()
	for j in mesh_nodes.size():
		var mi := mesh_nodes[j]
		mi.position=Vector3((j%7-3)*125,130 if j<7 else -100,0)
		scene.add_child(mi)
		var label:=Label3D.new()
		label.text=labels[j]+(" / PLAYER" if j<7 else " / ENEMY")
		label.font=preload("res://assets/fonts/NoSurvivorUI.ttf")
		label.font_size=24
		label.pixel_size=0.45
		label.position=mi.position+Vector3(0,-70,0)
		scene.add_child(label)
	await create_timer(0.1).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/visual-v2-projectiles.png")
	print("V2 CATALOGS captured (projectiles shown at 4x display scale)")
	quit()

func camera() -> Camera3D:
	var cam:=Camera3D.new()
	cam.projection=Camera3D.PROJECTION_ORTHOGONAL
	cam.size=560
	cam.position=Vector3(0,0,1200)
	return cam

func place(scene: Node3D,model: Node3D,i: int,title: String) -> void:
	model.position=Vector3((i%6-2.5)*150,130 if i<6 else -100,0)
	scene.add_child(model)
	var label:=Label3D.new()
	label.text=title
	label.font=preload("res://assets/fonts/NoSurvivorUI.ttf")
	label.font_size=24
	label.pixel_size=0.37
	label.position=model.position+Vector3(0,-70 if i<6 else -100,0)
	scene.add_child(label)
