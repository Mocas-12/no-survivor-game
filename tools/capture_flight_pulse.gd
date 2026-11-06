extends SceneTree
func _init(): run.call_deferred()
func shot(path: String):
    await process_frame
    await process_frame
    root.get_texture().get_image().save_png('res://screenshots/'+path+'.png')
func run():
    root.size=Vector2i(1152,648)
    preload('res://scripts/save.gd').disabled=true
    var w=load('res://scenes/world.tscn').instantiate()
    root.add_child(w);current_scene=w
    await process_frame
    w._on_start_pressed()
    w.get_node('Timer').stop();w.director.set_process(false);w.campaign.set_process(false)
    var p=w.player
    p.set_physics_process(false);p.position=Vector3(0,-180,0);p.weapon='beam';p.damage=1
    var beam=p.get_node('BeamWeapon');beam.set_process(false)
    for i in 3:
        var enemy=w.enemy_scene.instantiate();enemy.setup(['tank','repair','projector'][i]);w.add_child(enemy)
        enemy.position=Vector3(0,20+i*90,0);enemy.set_physics_process(false);enemy.health=10000
    w.campaign.environment.advance(3,0,false,false)
    beam._process(.05);await shot('pulse-charge')
    beam._process(.10);await shot('pulse-burst')
    beam._process(.18);await shot('pulse-sustain')
    beam._process(.31);await shot('pulse-cooldown')
    DirAccess.make_dir_recursive_absolute('res://build/pulse-frames')
    beam.hide_effect()
    for frame in 42:
        beam._process(1.0/30)
        w.campaign.environment.advance(1.0/30,0,false,false)
        await process_frame
        await process_frame
        root.get_texture().get_image().save_png('res://build/pulse-frames/%03d.png' % frame)
    for act in [1,2]:
        w.campaign.environment.change_act(act)
        w.campaign.environment.advance(2,0,false,false)
        beam.hide_effect();beam._process(.3)
        await shot('flight-transition-'+str(act))
        w.campaign.environment.advance(2,0,false,false)
        await shot('flight-scene-'+str(act))
    print('FLIGHT_PULSE_CAPTURE_OK')
    quit()
