extends SceneTree
const EQUIP=preload("res://scripts/equipment.gd")
const ARSENAL=preload("res://scripts/arsenal.gd")
var failures: Array[String]=[]
var checks:=0
func _init() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message);printerr("FAIL ",message)
func run() -> void:
	root.size=Vector2i(1152,648)
	preload("res://scripts/save.gd").disabled=true
	var w=load("res://scenes/world.tscn").instantiate()
	root.add_child(w)
	current_scene=w
	await process_frame
	w._on_start_pressed()
	w.director.set_process(false)
	w.campaign.set_process(false)
	w.get_node("Timer").stop()
	w.player.set_physics_process(false)
	var p=w.player
	p.weapon="pulse"
	ARSENAL.install(w,"split","main")
	ARSENAL.install(w,"ricochet","main")
	check(EQUIP.installed(p,"main").size()==2,"Two per-weapon modifications")
	ARSENAL.install(w,"expose","main")
	check(not EQUIP.installed(p,"main").has("split") and EQUIP.installed(p,"main").has("expose"),"Full slots explicitly replace oldest modification")
	p.weapon="rail"
	check(EQUIP.installed(p,"main").is_empty(),"Different weapon keeps a separate loadout")
	p.weapon="pulse"
	check(EQUIP.installed(p,"main").has("ricochet"),"Returning to a weapon restores its loadout")
	p.auxiliary="water"
	p.auxiliary_level=1
	p.second_auxiliary="ice"
	p.second_auxiliary_level=1
	ARSENAL.install(w,"firewake","aux1")
	check(EQUIP.installed(p,"aux1").has("firewake") and not EQUIP.installed(p,"aux2").has("firewake"),"Auxiliary slots are independent")
	var target=w.director.make_enemy("tank",Vector3(0,100,0))
	target.set_physics_process(false)
	target.health=100
	target.max_hp=100
	var round=p.new_round()
	round.launch(2,"water",0,0,0,0,1,target.position,Vector3.UP)
	ARSENAL.configure(p,round,false,"aux1")
	round._on_body_entered(target)
	check(w.campaign.reaction_counts.has("steam"),"Auxiliary payload and own element produce a real reaction")
	w.campaign.damage_sources.clear()
	target.health=5
	w.campaign.record_damage("rail",target,100)
	check(w.campaign.damage_sources.rail==5,"Damage ledger excludes overkill")
	for stage in 3:
		w.boss_tier=stage
		w.boss_active=false
		w.campaign.update_act()
		check(w.campaign.act==stage and w.campaign.background.material_override.get_shader_parameter("scene_texture")!=null,"Act background loaded "+str(stage))
	w.campaign.panel.show()
	w.campaign.resolve_event(false)
	check(w.campaign.active_event=="" and not paused,"Risk contract can be declined freely")
	w.campaign.panel.show()
	w.campaign.resolve_event(true)
	check(w.campaign.active_event!="","Risk contract records the accepted challenge")
	var damage_before: int=p.damage
	w.kill_count+=12
	w.campaign._process(0)
	check(w.campaign.active_event=="" and p.damage==damage_before+1,"Reward granted once for actual kill objective")
	w.campaign._process(0)
	check(p.damage==damage_before+1,"Contract reward cannot repeat")
	for i in 10: preload("res://scripts/reaction_field.gd").spawn(w,Vector3.ZERO,8)
	await process_frame
	check(get_nodes_in_group("reaction_fields").size()<=4,"Simultaneous deferred fields respect the shared cap")
	var beam_target=w.director.make_enemy("tank",Vector3(0,100,0))
	beam_target.set_physics_process(false)
	beam_target.health=100
	beam_target.max_hp=100
	p.position=Vector3(0,-180,0)
	p.weapon="beam"
	p.get_node("BeamWeapon")._process(.3)
	check(beam_target.health<100,"Sustained beam actually damages aligned targets")
	w.pending_level_ups=1
	w.show_level_up()
	await process_frame
	var draft=w.levelup_panel.get_node("ModuleDraft")
	var touch:=InputEventScreenTouch.new()
	touch.index=0
	touch.pressed=true
	touch.position=draft.slot_buttons[1].get_global_rect().get_center()
	root.push_input(touch,true)
	await process_frame
	check(p.equipment_focus=="aux1","Real touch selects an independent auxiliary slot")
	touch.pressed=false
	root.push_input(touch,true)
	touch.pressed=true
	touch.position=draft.action_buttons[1].get_global_rect().get_center()
	root.push_input(touch,true)
	await process_frame
	check(not w.levelup_panel.visible and not paused,"Real touch skips the draft")
	touch.pressed=false
	root.push_input(touch,true)
	w.campaign.panel.show()
	paused=true
	await process_frame
	touch.pressed=true
	touch.position=w.campaign.panel.get_child(0).get_child(2).get_global_rect().get_center()
	root.push_input(touch,true)
	await process_frame
	check(not w.campaign.panel.visible and not paused,"Real touch declines a risk contract")
	touch.pressed=false
	root.push_input(touch,true)
	for id in range(1,7):
		for phase in [1,2]:
			var model=preload("res://scripts/blender_hostiles.gd").build("boss",id,180,true,phase)
			check(model.find_children("*","MeshInstance3D",true,false).size()>=4,"Boss has actual articulated mesh groups")
			check(preload("res://scripts/blender_fleet.gd").visible_bounds(model).size.z>4,"Boss is volumetric")
			model.free()
	for id in ARSENAL.EXTRA:
		check(ResourceLoader.exists("res://assets/modules/expansion/%s.png" % id),"Unique new module artwork "+id)
	w.performance_limited=true
	var quality_round=p.new_round()
	quality_round.launch(7,"fire",1,0,0,0,1,Vector3.ZERO,Vector3.UP)
	check(quality_round._low_fx and not quality_round.get_node("Trail").emitting,"Low quality removes CPU tails")
	check(quality_round.damage==7 and quality_round.speed==800,"Quality does not alter projectile damage or speed")
	quality_round._recycle()
	check(not quality_round.is_processing(),"Dormant pooled bullets do not receive frame callbacks")
	quality_round=preload("res://scripts/bullet.gd").take()
	quality_round.launch(7,"fire",1,0,0,0,1,Vector3.ZERO,Vector3.UP)
	check(quality_round.is_processing(),"Reusing a pooled bullet restores callbacks")
	print("FULL_PLAN ","OK" if failures.is_empty() else "FAILED"," checks=",checks," failures=",failures)
	w.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
