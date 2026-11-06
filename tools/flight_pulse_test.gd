extends SceneTree
var failures: Array[String]=[]
var checks:=0
func _init(): run.call_deferred()
func check(ok: bool,message: String):
    checks+=1
    if not ok: failures.append(message);printerr('FAIL ',message)
func run():
    root.size=Vector2i(1152,648)
    preload('res://scripts/save.gd').disabled=true
    var w=load('res://scenes/world.tscn').instantiate()
    root.add_child(w);current_scene=w
    await process_frame
    w._on_start_pressed()
    w.get_node('Timer').stop()
    w.director.set_process(false)
    w.campaign.set_process(false)
    w.player.set_physics_process(false)
    var env=w.campaign.environment
    var old_tex=env.background.material_override.get_shader_parameter('scene_texture')
    env.change_act(1)
    check(env.background.material_override.get_shader_parameter('scene_texture')==old_tex,'Chapter starts from existing distant plate')
    check(env.background.material_override.get_shader_parameter('transition')==0,'No hard swap on chapter boundary')
    var y: float=env.scenery[0].node.position.y
    env.advance(2,0,false,false)
    check(env.scenery[0].node.position.y<y,'Scenery travels behind the fighter')
    check(is_equal_approx(env.background.material_override.get_shader_parameter('transition'),.5),'Four second chapter blend has a continuous midpoint')
    env.advance(2,0,false,false)
    check(env.transition_time==4,'Chapter blend completes')
    var bounded:=true
    for i in 1200:
        env.advance(.1,0,false,false)
        bounded=bounded and env.scenery.size()<=4
    check(bounded,'Scenery remains bounded through 120 seconds')
    check(env.dust.multimesh.instance_count==12,'Dust is sparse and bounded')
    env.advance(0,0,true,true)
    check(not env.dust.visible,'Reduced motion hides directional dust')
    var p=w.player
    p.position=Vector3(0,-180,0)
    p.weapon='beam'
    p.damage=2
    p.bullet_count=3
    var beam=p.get_node('BeamWeapon')
    beam.set_process(false)
    var enemies: Array=[]
    for ey in [-60,40,150,250]:
        var e=w.enemy_scene.instantiate()
        e.setup('tank')
        e.position=Vector3(0,ey,0)
        w.add_child(e)
        e.set_physics_process(false)
        e.health=100000;e.max_hp=100000
        enemies.append(e)
    beam._process(.05)
    check(beam.phase=='charge' and not beam.visual.visible,'Charge precedes the visible beam')
    check(enemies[0].health==100000,'Charge cannot damage enemies')
    beam._process(.10)
    check(beam.phase=='burst' and beam.visual.visible,'Beam visibly opens during burst')
    beam._process(.15)
    check(enemies[0].health<100000 and enemies[2].health<100000,'Pulse damages first three contacts')
    check(enemies[3].health==100000,'Fourth target is beyond penetration budget')
    check(absf(beam.global_position.y+beam.beam_length-(enemies[2].global_position.y+10))<1,'Visible endpoint matches final penetrating contact')
    check(beam.audio.playing and beam.audio_cycles>0,'Dedicated cycle audio is playing')
    check(beam.impact_audio.playing,'Dedicated impact audio is playing')
    paused=true
    var age: float=beam.age
    beam._process(.3)
    check(beam.age==age and beam.audio.stream_paused,'Pause freezes pulse clock and sound')
    paused=false
    for e in enemies: e.queue_free()
    await process_frame
    beam._process(.01)
    check(beam.beam_length>500,'Unblocked beam reaches beyond the visible top')
    var target=w.enemy_scene.instantiate()
    target.setup('tank');w.add_child(target);target.position=Vector3(0,30,0)
    target.set_physics_process(false);target.health=100000;target.max_hp=100000
    beam.hide_effect()
    for i in 420: beam._process(1.0/60)
    var dealt: int=100000-target.health
    var expected: float=7.0/maxf(.09,p.fire_cooldown*.65)*p.damage
    check(absf(dealt-expected)/expected<.12,'Pulses preserve previous average damage within 12 percent')
    w.performance_limited=true
    beam._process(.01)
    check(beam.mat.get_shader_parameter('detail')==0,'Low quality retains the core but disables stream detail')
    p.weapon='pulse';beam._process(.01)
    check(not beam.visible and not beam.audio.playing,'Switching weapon stops beam and audio')
    p.weapon='beam';beam._process(.15)
    w.dying=true;beam._process(.01)
    check(not beam.visible and not beam.audio.playing,'Death stops beam and audio')
    print('FLIGHT_PULSE ', 'OK' if failures.is_empty() else 'FAILED',' checks=',checks,' damage=',dealt,' expected=',expected,' failures=',failures)
    w.queue_free();await process_frame
    quit(0 if failures.is_empty() else 1)
