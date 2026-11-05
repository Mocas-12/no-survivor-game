extends SceneTree
const FX=preload("res://scripts/layered_fx.gd")
class Stage extends Node3D:
	var reduce_fx:=false
func _init(): run.call_deferred()
func percentile(values: Array,fraction: float):
	values.sort();return values[mini(values.size()-1,int(values.size()*fraction))]
func sample(scene: Node3D,stress: bool) -> Dictionary:
	var process=[];var draws=[];var nodes=[]
	var last=Time.get_ticks_usec()
	for frame in 180:
		if stress and frame%45==0:
			for node in scene.get_children():
				if node is FX and node.active: node.release()
			for i in 6:
				var fx=FX.burst(scene,Vector3((i%3-1)*120,(i/3)*140-70,0),"explosion",1,700+i)
				fx.set_process(false)
		if stress:
			for node in scene.get_children():
				if node is FX and node.active: node.advance(1.3/45.0)
		await process_frame
		await RenderingServer.frame_post_draw
		var now=Time.get_ticks_usec()
		if frame>30:
			process.append((now-last)/1000.0)
			draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			nodes.append(scene.get_child_count())
		last=now
	return {"frame_wall_ms_p95":percentile(process,.95),"draw_calls_peak":draws.max(),"root_nodes_peak":nodes.max()}
func run():
	root.size=Vector2i(1152,648)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var scene=Stage.new();root.add_child(scene);current_scene=scene
	var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=648;camera.position.z=1000;scene.add_child(camera)
	var result={"renderer":"gl_compatibility","resolution":"1152x648","device":RenderingServer.get_video_adapter_name(),"metric":"warmed isolated-scene frame wall time, VSync off; not GPU time, full-game FPS or phone FPS"}
	result.baseline=await sample(scene,false)
	result.six_bursts=await sample(scene,true)
	for child in scene.get_children():
		if child is FX: child.release()
	scene.reduce_fx=true
	result.reduced_six_bursts=await sample(scene,true)
	FileAccess.open("res://tools/vfx-profile.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("VFX_PROFILE ",JSON.stringify(result));quit()
