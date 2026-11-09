extends SceneTree
var failures: Array[String]=[]
func _init(): run.call_deferred()
func check(ok: bool,message: String):
	if not ok: failures.append(message);printerr("FAIL ",message)
func run():
	root.size=Vector2i(1152,648)
	preload("res://scripts/save.gd").disabled=true
	var w=load("res://scenes/world.tscn").instantiate()
	root.add_child(w)
	current_scene=w
	await process_frame
	w._on_start_pressed()
	w.director.set_process(false)
	w.get_node("Timer").stop()
	w.player.set_physics_process(false)
	w.run_time=135
	w.campaign._process(0)
	await process_frame
	var panel=w.campaign.panel
	var view=root.get_visible_rect()
	check(paused and panel.visible,"Real 135-second convoy event pauses combat")
	check(view.encloses(panel.get_global_rect()),"Convoy panel fully fits the screen")
	check(panel.get_global_rect().get_center().distance_to(view.get_center())<2,"Convoy panel is centered")
	var decline=panel.get_child(0).get_child(2)
	check(decline.can_process(),"Mouse buttons remain live while the scene is paused")
	var mouse:=InputEventMouseButton.new()
	mouse.button_index=MOUSE_BUTTON_LEFT
	mouse.position=decline.get_global_rect().get_center()
	mouse.pressed=true
	root.push_input(mouse,true)
	mouse.pressed=false
	root.push_input(mouse,true)
	await process_frame
	check(not paused and not panel.visible,"Native mouse decline resumes play")
	var before: float=w.campaign.flight_time
	w.campaign._process(1)
	check(w.campaign.flight_time>before,"Background advances during flight")
	check(w.campaign.background.material_override.get_shader_parameter("flight_time")==w.campaign.flight_time,"Background shader receives the flight clock")
	paused=true
	before=w.campaign.flight_time
	w.campaign._process(1)
	check(w.campaign.flight_time==before,"Background stops with paused combat")
	paused=false
	for viewport_size in [Vector2i(844,390),Vector2i(1440,900)]:
		root.size=viewport_size
		panel.show()
		await process_frame
		await process_frame
		check(root.get_visible_rect().encloses(panel.get_global_rect()),"Modal fits resized viewport "+str(viewport_size))
		check(panel.get_global_rect().get_center().distance_to(root.get_visible_rect().get_center())<2,"Modal stays centered after resize")
	panel.show()
	paused=true
	var accept=panel.get_child(0).get_child(1)
	mouse.position=accept.get_global_rect().get_center()
	mouse.pressed=true
	root.push_input(mouse,true)
	mouse.pressed=false
	root.push_input(mouse,true)
	await process_frame
	check(not paused and w.campaign.active_event=="contract","Native mouse accept starts the contract and resumes play")
	print("CAMPAIGN_UI ","OK" if failures.is_empty() else "FAILED"," ",failures)
	paused=false
	w.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
