extends SceneTree
func _init(): run.call_deferred()
func snap(name: String):
 var w=current_scene
 w.salvage._process(0)
 await create_timer(.7).timeout
 await process_frame;await process_frame
 root.get_texture().get_image().save_png('res://screenshots/'+name+'.png')
func run():
 root.size=Vector2i(1152,648);preload('res://scripts/save.gd').disabled=true
 var w=load('res://scenes/world.tscn').instantiate();root.add_child(w);current_scene=w;await process_frame
 w._on_start_pressed();w.get_node('Timer').stop();w.director.set_process(false);w.campaign.set_process(false);w.salvage.set_process(false);w.player.set_physics_process(false)
 w.player.position=Vector3(0,-180,0);w.player.branch='assault';w.health=1000;w.max_health=1000
 w.pick_element('fire');w.pick_element('water');w.salvage.install('shield');w.salvage.install('cannon');w.salvage.energy=100
 w.salvage.burst_source='shield';w.salvage.activate();w.salvage.refresh_hud()
 w.player.modules={};w.player.rule_slots.clear()
 preload('res://scripts/run_rules.gd').install(w,'salvage_return');preload('res://scripts/run_rules.gd').install(w,'tail_battery')
 w.run_time=35;w.director.opening_encounter()
 for i in 120:
  w.player.shoot();w.campaign.environment.advance(1.0/60,0,false,false);w.salvage._process(1.0/60)
  await process_frame
 await snap('salvage-combat')
 w.salvage.present('mines');await snap('salvage-hardware')
 w.salvage.recycle_offer();w.pending_level_ups=1;w.show_level_up()
 for i in 3:
  var id: String=['fire','jump_arc','focus_breach'][i]
  w.upgrade_buttons[i].set_meta('upgrade',w.upgrade_pool.filter(func(u):return u.id==id)[0])
 w.levelup_panel.get_node('ModuleDraft').present();w.levelup_panel.get_node('ModuleDraft').reveal_all();await snap('salvage-cards')
 print('SALVAGE_CAPTURE_OK');paused=false;quit()
