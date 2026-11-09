extends SceneTree
const REACTIONS=preload('res://scripts/element_reactions.gd')
const RULES=preload('res://scripts/run_rules.gd')
var failures: Array[String]=[]
var checks:=0
func _init(): run.call_deferred()
func check(ok: bool,why: String):
 checks+=1
 if not ok: failures.append(why);printerr('FAIL ',why)
func target(w,pos:=Vector3(0,100,0)):
 var e=w.enemy_scene.instantiate();e.setup('tank');w.add_child(e);e.position=pos;e.set_physics_process(false);e.health=10000;e.max_hp=10000
 return e
func run():
 root.size=Vector2i(1152,648)
 preload('res://scripts/save.gd').disabled=true
 var w=load('res://scenes/world.tscn').instantiate();root.add_child(w);current_scene=w
 await process_frame
 w._on_start_pressed();w.get_node('Timer').stop();w.director.set_process(false);w.campaign.set_process(false);w.salvage.set_process(false);w.player.set_physics_process(false)
 var p=w.player;var run=w.salvage;p.position=Vector3(0,-160,0)
 w.pick_element('fire');w.pick_element('water')
 check(p.element=='fire' and p.catalyst=='water','Second element coexists on the main weapon')
 var b=p.new_round();b.launch(2,p.element,1,0,0,0,1,p.position,Vector3.UP);preload('res://scripts/arsenal.gd').configure(p,b)
 check(b.catalyst=='water','Every main round snapshots its catalyst')
 var e=target(w);b._on_body_entered(e)
 check(w.campaign.reaction_counts.get('steam',0)>0,'One main projectile can produce the dual reaction without an auxiliary')
 w.pick_element('water');check(p.element_levels.water==2 and p.element=='fire','Repeated catalyst selection upgrades the catalyst')
 w.pick_element('ice');check(p.catalyst=='ice' and p.element=='fire','Third element uses the explicit catalyst replacement target')
 p.element_replace='element';w.pick_element('lightning');check(p.element=='lightning' and p.catalyst=='ice','Primary replacement preserves catalyst')
 for a in ['fire','water','ice','lightning','wind']:
  for c in ['fire','water','ice','lightning','wind']:
   if a>=c: continue
   e.set_meta('elements',{});e.dead=false;e.health=10000
   REACTIONS.apply(e,a,2,1,1,1,w)
   var result=REACTIONS.apply(e,c,2,1,1,1,w)
   check(result!='' and result==REACTIONS.pair(c,a),'Symmetric executable reaction '+a+' + '+c)
 p.element='fire';p.catalyst='water'
 var neighbor=target(w,Vector3(70,110,0))
 p.modules={};e.health=10000;e.set_meta('elements',{})
 REACTIONS.apply(e,'fire',2,1,1,1,w);REACTIONS.apply(e,'water',2,1,1,1,w)
 var base_neighbor: int=neighbor.health
 neighbor.health=10000;e.set_meta('elements',{});p.modules={'jump_arc':true}
 REACTIONS.apply(e,'fire',2,1,1,1,w);REACTIONS.apply(e,'water',2,1,1,1,w)
 check(neighbor.health<base_neighbor,'Jump relay adds bounded non-recursive reaction damage')
 p.modules={}
 var choices=w.director.offer(w.upgrade_pool.filter(func(u):return u.can.call()))
 check(choices.any(func(u):return RULES.DATA.has(u.id)),'A formed element build receives a rule opportunity')
 p.element='normal';p.catalyst='';p.element_levels={'fire':0,'water':0,'ice':0,'lightning':0,'wind':0}
 choices=w.director.offer(w.upgrade_pool.filter(func(u):return u.can.call()))
 check(choices.all(func(u):return u.id in ['fire','water','ice','lightning','wind']),'Opening choices all immediately change main fire')
 for id in RULES.DATA:
  check(ResourceLoader.exists('res://assets/modules/salvage/'+id+'.png'),'Original artwork '+id)
  w.upgrade_pool.filter(func(u):return u.id==id)[0].apply.call()
  check(p.modules.has(id),'Rule installs '+id)
 check(p.rule_slots.size()==2 and not p.modules.has('salvage_return'),'Two rule slots prevent all six rules converging into every run')
 run.energy=100;run.activate();check(run.burst_left==4 and run.energy==0,'Burst consumes full energy once')
 var before: int=run.bursts;run.activate();check(run.bursts==before,'Repeated activation cannot duplicate an active burst')
 run.burst_left=0;run.energy=0
 p.modules['salvage_return']=true
 b=p.new_round();b.launch(2,'normal',1,0,0,0,1,p.position,Vector3.DOWN);b.source_player=p;b.returned=true;b.flight_age=.5;b._process(.01)
 check(run.energy>0 and not b._active,'Catching a returned round grants energy and recycles it')
 run.energy=0;var shot=w.enemy_bullet_scene.instantiate();w.add_child(shot);shot.position=p.position+Vector3(40,0,0)
 run.graze(shot);run.graze(shot);check(run.energy==2.5,'Each grazed projectile rewards once')
 run.install('shield');run.energy=100;run.activate();shot.position=p.position+Vector3(0,45,0);shot.dir=Vector3.DOWN
 check(run.burst_kind()=='reflect' and run.block_projectile(shot),'Shield burst genuinely reflects hostile rounds')
 var locked_source: String=run.burst_source
 run.cycle_source();check(run.burst_source==locked_source,'Active burst cannot swap its behavior mid-effect')
 run.burst_left=0;run.install('mines');run.install('cannon')
 check(run.parts==['mines','cannon'] and run.mounts.size()==2,'Two hardware mounts replace the oldest part')
 check(run.mounts.all(func(m):return m.find_children('*','MeshInstance3D',true,false).size()>0),'Captured hardware has actual enemy mesh geometry')
 run.parts.assign(['mines']);run.burst_source='mines';run.energy=100
 var victim=target(w,p.position+Vector3(0,50,0));var hp: int=victim.health
 run.drop_mine(victim.position,false);run.activate()
 check(victim.health<hp,'Mine burst detonates deployed mines with real damage')
 run.burst_left=0;run.parts.clear();run.cooldowns.clear();e.health=10000;e.dead=false
 b=p.new_round();b.launch(2,'normal',1,0,0,0,1,p.position,Vector3.UP);preload('res://scripts/arsenal.gd').configure(p,b)
 for i in 6: run.hit(e,b)
 check(e.health<10000,'Repeated aligned hits trigger focus breach')
 p.modules={'shield_clone':true};run.cooldowns.clear()
 var shield=w.enemy_scene.instantiate();shield.setup('shield');w.add_child(shield);shield.set_physics_process(false);shield.health=1
 var old_rounds: int=get_nodes_in_group('player_bullets').filter(func(r):return r._active).size()
 shield.take_damage_silent(2);await process_frame
 check(get_nodes_in_group('player_bullets').filter(func(r):return r._active).size()>=old_rounds+6,'Destroying a shield releases the actual copied volley')
 p.modules={'tail_battery':true};run.last_position=p.position
 var rounds: int=get_nodes_in_group('player_bullets').filter(func(r):return r._active).size()
 for i in 6:
  p.position.x+=45;run._process(.016)
 check(get_nodes_in_group('player_bullets').filter(func(r):return r._active).size()>rounds,'Travel really emits lateral fire')
 p.modules={};run.parts.clear();run.event_bag.clear();run.events_seen.clear();run.collected=0;w.run_time=25
 run.opportunity_event();check(run.events_seen[0]=='transport','First opportunity guarantees recoverable hardware')
 run.parts.assign(['cannon']);run.collected=1
 for i in 4: run.opportunity_event()
 var unique: Dictionary={}
 for id in run.events_seen: unique[id]=true
 check(unique.size()==5,'Five opportunities are sampled without repeating the same event')
 run.pending.clear();run.present('shield')
 await process_frame
 check(paused and root.get_visible_rect().encloses(run.panel.get_global_rect()),'Hardware choice is centered while combat pauses')
 var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.position=run.buttons[0].get_global_rect().get_center();click.pressed=true;root.push_input(click,true);click.pressed=false;root.push_input(click,true)
 await process_frame
 check(not paused and 'shield' in run.parts,'Native mouse selection installs recovered hardware and resumes')
 var time_before: float=run.burst_left;paused=true;run._process(1)
 check(run.burst_left==time_before,'Burst timers freeze while paused')
 paused=false
 w.run_time=0;w.director.choosing=false
 for mob in get_nodes_in_group('mobs'): mob.queue_free()
 await process_frame
 w.director.opening_encounter();check(get_nodes_in_group('mobs').size()>=5,'Opening immediately presents an actual formation')
 check(w.campaign.next_event>=120,'Text contracts do not interrupt the opening minute')
 p.modules={}
 for shot_round in get_nodes_in_group('player_bullets'):
  if shot_round._active: shot_round._recycle()
 var crossing=target(w,Vector3(220,80,0))
 await physics_frame
 await physics_frame
 await process_frame
 var old_script:=GDScript.new()
 old_script.source_code='extends "res://scripts/bullet.gd"\nfunc sweep(from: Vector3,to: Vector3) -> bool:\n return true\n'
 old_script.reload()
 var legacy=load('res://scenes/bullet.tscn').instantiate();legacy.set_script(old_script);w.add_child(legacy)
 var baseline: float=crossing.health
 legacy.launch(2,'normal',1,0,0,0,1,Vector3(220,-80,0),Vector3.UP);legacy._process(.4)
 check(crossing.health==baseline,'The endpoint-only legacy path reproduces the missed contact')
 legacy.queue_free();await process_frame
 var fast=p.new_round();fast.launch(2,'normal',1,0,0,0,1,Vector3(220,-80,0),Vector3.UP)
 fast._process(.4)
 check(crossing.health<baseline,'Fast main rounds collide along their full movement segment')
 run.energy=0;run.start_support(Vector3(100,220,0));run._process(.05)
 check(run.energy==100 and is_instance_valid(run.support_node),'Captured turret grants real temporary support')
 w.run_time=run.support_until+.1;run._process(.05)
 check(not is_instance_valid(run.support_node),'Temporary support expires')
 var light=target(w,Vector3(350,100,0));light.kind='normal'
 run.gap_side=1;run.gap_until=w.run_time+6;run._process(.1)
 check(light.position.x<350,'Breakthrough opportunity opens a real light-enemy gap')
 if not run.pickups.is_empty(): check(run.pickups[0].label.scale.is_equal_approx(Vector3.ONE),'Pickup labels keep world size independent of hardware scale')
 print('SALVAGE_RUN ', 'OK' if failures.is_empty() else 'FAILED',' checks=',checks,' failures=',failures)
 w.queue_free();await process_frame
 quit(0 if failures.is_empty() else 1)
