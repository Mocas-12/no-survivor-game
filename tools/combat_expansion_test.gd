extends SceneTree
const ARSENAL=preload("res://scripts/arsenal.gd")
var failures: Array[String]=[]
var checks:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); printerr("FAIL ",message)
func _init() -> void: run.call_deferred()
func run() -> void:
	preload("res://scripts/save.gd").disabled=true
	root.size=Vector2i(1152,648)
	var w=load("res://scenes/world.tscn").instantiate()
	root.add_child(w)
	current_scene=w
	await process_frame
	w._on_start_pressed()
	w.get_node("Timer").stop()
	w.director.set_process(false)
	w.player.set_physics_process(false)
	var p=w.player
	check(w.upgrade_pool.size()==48,"48 complete modules")
	var ids: Array=[]
	for card in w.upgrade_pool:
		check(not ids.has(card.id),"Unique module "+card.id)
		ids.append(card.id)
	for weapon in ["pulse","rail","missile","blade","beam","mine"]:
		ARSENAL.install(w,weapon)
		p.shoot()
		var b=get_nodes_in_group("player_bullets").back()
		check(b.source_player==p,"Weapon wired to contact feedback "+weapon)
		if weapon=="rail": check(b.pierce_left>=3 and b.damage==p.damage*3,"Rail has real piercing and damage")
		if weapon=="missile": check(b.homing>0,"Missile genuinely tracks")
		if weapon=="blade": check(b.return_after>0,"Blade genuinely returns")
		if weapon=="mine": check(b.speed<100 and b.modules.has("blast"),"Mine has slow movement and blast")
	preload("res://scripts/upgrades.gd").auxiliary(w,"water")
	preload("res://scripts/upgrades.gd").auxiliary(w,"ice")
	check(p.auxiliary=="ice" and p.second_auxiliary=="water","Two elements coexist")
	preload("res://scripts/upgrades.gd").auxiliary(w,"water")
	check(p.auxiliary=="water" and p.auxiliary_level==2 and p.second_auxiliary=="ice","Upgrade swaps slots without losing the other weapon")
	for role in preload("res://scripts/tactical_enemy.gd").BASE:
		var e=w.director.make_enemy(role,Vector3(0,160,0))
		check(e!=null and e.model!=null,"Playable tactical role "+role)
		if e==null: continue
		e.set_physics_process(false)
		preload("res://scripts/tactical_enemy.gd").tick(e,3)
		e.queue_free()
		await process_frame
	for kind in range(3,12):
		w.director.advanced_encounter(kind)
		check(w.director.phase!="","Tactical encounter "+str(kind))
		for e in get_nodes_in_group("mobs"): e.queue_free()
		await process_frame
	var target=w.director.make_enemy("tank",Vector3(0,100,0))
	target.health=200
	target.max_hp=200
	target.set_physics_process(false)
	p.modules={"expose":true,"frostwake":true}
	p.weapon="pulse"
	var b=p.new_round()
	b.launch(2,"normal",1,0,0,0,1,target.position,Vector3.UP)
	ARSENAL.configure(p,b)
	b._on_body_entered(target)
	var state=preload("res://scripts/element_reactions.gd").state(target)
	check(state.has("exposed") and state.has("ice"),"Payload effects apply to real target")
	b=p.new_round()
	b.launch(1,"normal",1,0,0,0,1,Vector3.ZERO,Vector3.UP)
	check(b.modules.is_empty() and b.source_player==null,"Pooled projectiles clear every build modifier")
	w.pending_level_ups=1
	w.show_level_up()
	var draft=w.levelup_panel.get_node("ModuleDraft")
	draft.reroll()
	check(draft.rerolls==2 and w.pending_level_ups==1,"Reroll consumes allowance without spending the upgrade")
	draft.skip()
	check(not paused and w.pending_level_ups==0 and not w.levelup_panel.visible,"Skip resumes without forcing weapon replacement")
	for id in range(1,7):
		var boss=w.boss_scene.instantiate()
		boss.setup(id,2)
		w.add_child(boss)
		boss.set_physics_process(false)
		boss._change_phase(2)
		check(boss.transition_left>=1.8 and boss.model.deployment==0,"Continuous deployment "+str(id))
		await process_frame
		check(boss.get_node("Collision").shape.size.x>=70,"Deployed collider measured before hiding "+str(id))
		boss.queue_free()
		await process_frame
	print("COMBAT EXPANSION ","OK" if failures.is_empty() else "FAILED"," checks=",checks," failures=",failures)
	w.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
