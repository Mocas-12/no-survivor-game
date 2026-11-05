extends SceneTree
const FX=preload("res://scripts/layered_fx.gd")
var checks:=0
var failures=[]
class Stage extends Node3D:
	var reduce_fx:=false
	var pause_panel: Control
func _init(): run.call_deferred()
func check(value: bool,message: String):
	checks+=1
	if not value: failures.append(message);printerr("FAIL ",message)
func run():
	var world=Stage.new();root.add_child(world);current_scene=world
	for kind in ["steam","freeze","shatter","conduct","melt","overload","explosion","hit","water","ice","wind"]:
		var fx=FX.burst(world,Vector3.ZERO,kind,1,777)
		fx.set_process(false)
		check(fx!=null and fx.life>0,"Actual layers created "+kind)
		fx.advance(.1)
		var first=[]
		for i in fx.cursor:
			var layer=fx.layers[i]
			first.append([layer.mesh.position,layer.mesh.rotation,layer.mesh.scale])
			check(layer.mesh.mesh!=null and layer.mesh.material_override!=null,"Layer has render resources")
		fx.advance(3)
		check(not fx.active and not fx.visible,"Complete cleanup "+kind)
		var replay=FX.burst(world,Vector3.ZERO,kind,1,777);replay.set_process(false);replay.advance(.1)
		var second=[]
		for i in replay.cursor:
			var m=replay.layers[i].mesh;second.append([m.position,m.rotation,m.scale])
		check(first==second,"Seeded replay "+kind)
		check(replay==fx,"Actual node reused "+kind)
		replay.advance(3);replay.release()
		check(FX.active_count==0,"Idempotent release "+kind)
	var live=[]
	for i in 50:
		var fx=FX.burst(world,Vector3.ZERO,"explosion")
		if fx: fx.set_process(false);live.append(fx)
	check(live.size()==24 and FX.active_count==24,"Hard cap under repeated explosions")
	for fx in live: fx.release()
	world.reduce_fx=true
	live.clear()
	for i in 50:
		var low=FX.burst(world,Vector3.ZERO,"explosion")
		if low: low.set_process(false);live.append(low)
	check(live.size()==10,"Reduced quality has a lower hard cap")
	check(live[0].cursor<16,"Reduced quality removes layers rather than hiding particles")
	for fx in live: fx.release()
	world.reduce_fx=false
	var hit=FX.burst(world,Vector3.ZERO,"hit");hit.set_process(false)
	var age=hit.age
	paused=true
	await process_frame
	check(hit.age==age,"Deterministic manual seek does not advance accidentally")
	world.pause_panel=Control.new();world.add_child(world.pause_panel)
	hit.set_process(true)
	await create_timer(.04).timeout
	check(hit.age==age,"Pause menu freezes effect playback")
	world.pause_panel.hide()
	await create_timer(.04).timeout
	check(hit.age>age,"Card and end overlays allow residual effects to fade")
	paused=false;hit.advance(3)
	check(Engine.time_scale==1,"Cosmetic effects do not alter gameplay time")
	world.free()
	check(FX.active_count==0,"Scene unload clears all active effects")
	print("VFX_QUALITY ",checks," checks failures=",failures)
	quit(0 if failures.is_empty() else 1)
