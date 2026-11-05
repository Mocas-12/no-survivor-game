extends SceneTree
const R=preload("res://scripts/element_reactions.gd")
const H=preload("res://scripts/blender_hostiles.gd")
var checks:=0
var failures=[]
func _init(): run.call_deferred()
func check(ok: bool,label: String):
	checks+=1
	if not ok: failures.append(label); printerr("FAIL ",label)
func target(world,boss:=false):
	var n=load("res://scenes/boss.tscn" if boss else "res://scenes/enemy.tscn").instantiate()
	world.add_child(n)
	if boss: n.setup(6,1)
	else: n.setup("tank")
	n.set_physics_process(false)
	if not boss: n.health=1000; n.max_hp=1000
	return n
func run():
	preload("res://scripts/save.gd").disabled=true
	var world=load("res://scenes/world.tscn").instantiate()
	root.add_child(world);current_scene=world
	world.set_process(false);world.get_node("Timer").stop()
	paused=false;world.director.set_process(false);world.player.set_physics_process(false)
	for a in R.COLORS:
		for b in R.COLORS:
			if a==b: continue
			var n=target(world)
			check(R.apply(n,a,2,1,1,1,world)=="","First element primes, never reacts")
			check(R.apply(n,b,2,1,1,1,world)==R.pair(a,b),"Symmetric pair "+a+"+"+b)
			check(R.apply(n,a,2,1,1,1,world)=="","Per-target reaction cooldown")
			n.free()
	var n=target(world)
	n.slow_down(2,.5)
	check(R.apply(n,"lightning",2,1,1,1,world)=="","Generic slow is not frost")
	R.state(n).clear()
	R.apply(n,"ice",2,1,1,1,world)
	R.apply(n,"lightning",2,1,1,1,world)
	check(n.slow_timer==2,"Shatter does not erase unrelated ability slow")
	R.tick(n,.6)
	check(not R.state(n).has("reaction_cd"),"Reaction cooldown expires")
	R.state(n).clear()
	R.apply(n,"water",2,1,1,1,world)
	check(R.apply(n,"water",2,1,1,1,world)=="","Same element cannot react")
	R.state(n).clear()
	R.apply(n,"fire",2,1,1,1,world)
	var neighbor=target(world)
	R.apply(n,"wind",2,1,1,1,world)
	check(R.state(neighbor).has("fire"),"Wind spreads existing status")
	check(not R.state(neighbor).has("reaction_cd"),"Spread does not recursively react")
	n.free();neighbor.free()
	var kill=target(world)
	kill.health=1
	R.apply(kill,"water",1,1,1,1,world)
	var before=world.director.reactions
	var round=world.player.new_round()
	round.launch(3,"fire",1,0,0,0,1,Vector3.ZERO,Vector3.UP)
	round._on_body_entered(kill)
	check(kill.dead and world.director.reactions==before+1,"Lethal primary hit still triggers prepared reaction")
	kill.queue_free()
	for id in range(1,7):
		var boss=target(world,true)
		boss.boss_id=id;boss.is_omega=id==6;boss.hp=boss.max_hp
		boss.hp=boss.max_hp*.49
		boss._phase_check()
		check(boss.visual_phase==2 and boss.enraged,"Boss P2 "+str(id))
		check(boss.model.get_meta("hostile_key")=="boss-%d-p2"%id,"Real deployed asset "+str(id))
		check(boss.transition_left>.8,"Transformation pauses new attacks")
		check(boss.find_children("*","MeshInstance3D",true,false).size()<40,"No orbiting orb tree")
		var count=get_nodes_in_group("enemy_bullets").size()
		boss._attack()
		check(get_nodes_in_group("enemy_bullets").size()>count,"Deployed weapons fire actual projectiles "+str(id))
		if id==6:
			boss.transition_left=0;boss.hp=boss.max_hp*.3;boss._phase_check()
			check(boss.phase3 and boss.visual_phase==3,"OMEGA real P3")
			R.apply(boss,"water",2,1,1,1,world)
			check(R.apply(boss,"ice",2,1,1,1,world)=="freeze","Boss participates in reactions")
			check(R.movement(boss)>.5,"Boss resists hard freeze")
		boss.free()
	var shooter=target(world)
	check(not "cue" in shooter,"No long enemy aim line")
	shooter.model.impact(20)
	check(shooter.model.overlay!=null and shooter.model.impact_left>0,"Local impact flash")
	shooter.model.charge(1)
	check(shooter.model.muzzle.visible,"Compact weapon charge")
	shooter.model.charge(0)
	check(not shooter.model.muzzle.visible,"Charge resets")
	shooter.free()
	await create_timer(1.5).timeout
	check(preload("res://scripts/reaction_fx.gd").active==0,"Reaction geometry cleans up after playback")
	await process_frame
	print("COMBAT_REVISION ",checks," checks failures=",failures)
	for player in world.find_children("*","AudioStreamPlayer",true,false): player.stop()
	world.free()
	await create_timer(.15).timeout
	quit(0 if failures.is_empty() else 1)
