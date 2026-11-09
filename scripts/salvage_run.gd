extends Node3D
## Run-local salvage, burst and opportunities. Physics effects never recurse.
const TXT=preload('res://scripts/module_readout.gd')
const FX=preload('res://scripts/precision_fx.gd')
const PARTS={
 'cannon':['敌舰重炮','Captured cannon','周期贯穿重弹 / 爆发连续齐射','Periodic piercing rounds / burst barrage',1],
 'mines':['感应弹仓','Mine rack','沿尾流布雷 / 爆发引爆雷场','Lay mines / burst detonates the field',2],
 'shield':['反射装甲','Reflector','周期正面格挡 / 爆发反射敌弹','Timed frontal guard / burst reflects rounds',3],
 'tractor':['牵引装置','Tractor','近距回收补给 / 爆发聚拢轻敌','Pull nearby salvage / burst gathers light ships',4],
 'bomber':['尾翼轰炸架','Bomb rack','移动积累投弹 / 爆发轰炸身后','Travel charges bombs / burst sweeps the rear',5],
 'splitter':['复制弹仓','Clone rack','精英接触复制弹幕 / 爆发扩大齐射','Elite hits release fragments / burst spreads fire',6]}
var w: Node
var parts: Array[String]=[]
var pickups: Array[Dictionary]=[]
var mounts: Array[Node3D]=[]
var energy:=45.0
var burst_left:=0.0
var burst_pulses:=0.0
var cooldowns: Dictionary={}
var next_event:=24.0
var opportunity:=''
var opportunity_until:=0.0
var event_bag: Array=[]
var pending: Array[String]=[]
var panel: PanelContainer
var buttons: Array[Button]=[]
var offered: Array[String]=[]
var hud: Label
var burst_button: Button
var source_button: Button
var burst_source:='weapon'
var active_burst:=''
var event_label: Label
var last_position:=Vector3.ZERO
var travel:=0.0
var tail_travel:=0.0
var focus_target:=0
var focus_count:=0
var collected:=0
var bursts:=0
var events_seen: Array[String]=[]
var shield_ready:=false
var _ui_tick:=0.0
var guard_visual: MeshInstance3D
var gap_until:=0.0
var gap_side:=1.0
var support_until:=0.0
var support_node: Node3D
func _ready():
 w=get_parent()
 process_mode=Node.PROCESS_MODE_ALWAYS
 build_ui()
 guard_visual=MeshInstance3D.new()
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in 12:
  var a: float=float(i)/12*PI
  var b: float=float(i+1)/12*PI
  for point in [Vector3.ZERO,Vector3(cos(a)*68,sin(a)*28,0),Vector3(cos(b)*68,sin(b)*28,0)]: st.add_vertex(point)
 guard_visual.mesh=st.commit()
 var shield_mat:=StandardMaterial3D.new();shield_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 shield_mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;shield_mat.albedo_color=Color(.25,.8,.95,.22);shield_mat.cull_mode=BaseMaterial3D.CULL_DISABLED
 guard_visual.material_override=shield_mat;w.add_child(guard_visual);guard_visual.hide()
func allowed() -> bool:
 return not w.start_panel.visible and not w.dying and not get_tree().paused and not w.victory_panel.visible and not w.game_over_panel.visible
func build_ui():
 hud=Label.new();hud.position=Vector2(16,118);hud.size=Vector2(280,65);hud.mouse_filter=Control.MOUSE_FILTER_IGNORE
 hud.add_theme_font_size_override('font_size',14);hud.add_theme_color_override('font_color',Color('c7dce3'));w.get_node('UI').add_child(hud)
 event_label=Label.new();event_label.position=Vector2(340,143);event_label.size=Vector2(470,42);event_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 event_label.add_theme_font_size_override('font_size',14);event_label.add_theme_color_override('font_color',Color('e7bf78'));event_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;w.get_node('UI').add_child(event_label)
 burst_button=Button.new();burst_button.position=Vector2(970,540);burst_button.size=Vector2(162,68)
 burst_button.theme=preload('res://scripts/visual_ui.gd').theme();burst_button.pressed.connect(activate);w.get_node('UI').add_child(burst_button)
 source_button=Button.new();source_button.position=Vector2(970,611);source_button.size=Vector2(162,27)
 source_button.theme=burst_button.theme;source_button.add_theme_font_size_override('font_size',12);source_button.pressed.connect(cycle_source);w.get_node('UI').add_child(source_button)
 var center:=CenterContainer.new();center.process_mode=Node.PROCESS_MODE_ALWAYS;center.mouse_filter=Control.MOUSE_FILTER_IGNORE
 w.get_node('UI').add_child(center);center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 panel=PanelContainer.new();panel.theme=preload('res://scripts/visual_ui.gd').theme();panel.add_theme_stylebox_override('panel',preload('res://scripts/visual_ui.gd').style(Color('102536'),Color('79dce7'),16));panel.custom_minimum_size=Vector2(630,0);center.add_child(panel)
 var box:=VBoxContainer.new();box.add_theme_constant_override('separation',12);panel.add_child(box)
 var title:=Label.new();title.text=TXT.pick('敌舰武装回收 · 选择现场改装','CAPTURED HARDWARE · choose a retrofit');title.add_theme_font_size_override('font_size',23);box.add_child(title)
 for i in 2:
  var button:=Button.new();button.custom_minimum_size=Vector2(590,96);button.pressed.connect(select.bind(i));box.add_child(button);buttons.append(button)
 var skip:=Button.new();skip.text=TXT.pick('拆成能量 · +20爆发能量','Recycle · +20 burst energy');skip.pressed.connect(recycle_offer);box.add_child(skip);buttons.append(skip)
 panel.hide()
func element_name(id: String) -> String:
 return TXT.pick({'normal':'普通','fire':'火','water':'水','ice':'冰','lightning':'雷','wind':'风'}.get(id,id),id)
func part_title(id: String) -> String: return PARTS[id][0 if preload('res://scripts/i18n.gd').lang()=='zh' else 1]
func add_energy(amount: float): energy=clampf(energy+amount,0,100)
func burst_kind() -> String:
 if burst_left>0 and active_burst!='': return active_burst
 if burst_source in parts: return {'shield':'reflect','mines':'detonate','tractor':'gather','bomber':'bomb','cannon':'barrage','splitter':'overclock'}[burst_source]
 return {'rail':'barrage','beam':'beam','mine':'detonate'}.get(w.player.weapon,'overclock')
func cycle_source():
 if not allowed() or burst_left>0: return
 var sources: Array=['weapon']+parts
 burst_source=sources[(sources.find(burst_source)+1)%sources.size()]
 refresh_hud()
func activate():
 if not allowed() or energy<100 or burst_left>0: return
 active_burst=burst_kind()
 energy=0;burst_left=4;burst_pulses=0;bursts+=1
 w.player.overdrive=4
 if w.homing_charges>0: w._use_homing()
 w.play_sfx('transform',-10)
 w._toast(TXT.pick('武装爆发 · ','BURST · ')+burst_name(),Color('8deafa'))
 if burst_kind()=='detonate':
  for shot in get_tree().get_nodes_in_group('player_bullets'):
   if shot._active and shot.projectile_role=='mine':
    area_damage(shot.position,160,w.player.damage*6,6);shot._recycle()
func burst_name() -> String:
 var names={'reflect':['反射推进','REFLECT'],'detonate':['雷场引爆','DETONATE'],'gather':['牵引冲击','TRACTOR'],'bomb':['尾翼轰炸','BOMB RUN'],'barrage':['贯穿齐射','BARRAGE'],'beam':['光束超容','BEAM SURGE'],'overclock':['弹幕超频','OVERCLOCK']}
 var names_row=names[burst_kind()];return names_row[0 if preload('res://scripts/i18n.gd').lang()=='zh' else 1]
func _input(event):
 if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_SPACE and not panel.visible and allowed():
  activate();get_viewport().set_input_as_handled()
 var pointer: bool=(event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT)
 if pointer:
  if panel.visible:
   for i in buttons.size():
    if buttons[i].get_global_rect().has_point(event.position):
     if i==2: recycle_offer()
     else: select(i)
     get_viewport().set_input_as_handled();return
  elif burst_button.visible and burst_button.get_global_rect().has_point(event.position):
   activate();get_viewport().set_input_as_handled()
  elif source_button.visible and source_button.get_global_rect().has_point(event.position):
   cycle_source();get_viewport().set_input_as_handled()
func _process(dt):
 var showing: bool=not w.start_panel.visible and not w.dying and not w.game_over_panel.visible and not w.victory_panel.visible
 burst_button.visible=showing and not w.levelup_panel.visible and not w.director.choosing and not panel.visible and not w.campaign.panel.visible
 hud.visible=burst_button.visible;event_label.visible=burst_button.visible
 source_button.visible=burst_button.visible
 for mount in mounts:
  if is_instance_valid(mount): mount.visible=not w.dying
 for pickup in pickups:
  pickup.node.visible=not w.dying and not w.victory_panel.visible
 guard_visual.visible=showing and ('shield' in parts and shield_ready or burst_left>0 and burst_kind()=='reflect')
 guard_visual.position=w.player.position+Vector3(0,45,7)
 if not allowed(): return
 if is_instance_valid(support_node):
  if w.run_time>=support_until: support_node.queue_free();support_node=null
  elif ready('support',.45): fire_round(support_node.position,Vector3.UP,'rail',w.player.damage*2)
 if w.run_time<gap_until:
  for enemy in get_tree().get_nodes_in_group('mobs'):
   if not enemy.dead and enemy.get('kind') in ['normal','swift','fast'] and absf(enemy.position.x-gap_side*350)<150:
    enemy.position.x=move_toward(enemy.position.x,gap_side*150,dt*120)
 for mount in mounts:
  if is_instance_valid(mount): mount.position.y=lerpf(mount.position.y,-4.0,minf(1,dt*16))
 if not pending.is_empty() and not w.director.choosing:
  present(pending.pop_front());return
 burst_left=maxf(0,burst_left-dt)
 _ui_tick-=dt
 if _ui_tick<=0:
  _ui_tick=.1;refresh_hud()
 for key in cooldowns.keys(): cooldowns[key]=maxf(0,cooldowns[key]-dt)
 var distance: float=w.player.position.distance_to(last_position)
 if distance<100: travel+=distance;tail_travel+=distance
 last_position=w.player.position
 if w.player.modules.has('tail_battery') and tail_travel>=220:
  tail_travel-=220;side_volley()
 if 'bomber' in parts and travel>=300:
  travel-=300;drop_mine(w.player.position-Vector3(0,25,0),true)
 if 'cannon' in parts and ready('cannon',1.5): fire_round(w.player.position,Vector3.UP,'rail',w.player.damage*4)
 if 'mines' in parts and ready('mines',1.6): drop_mine(w.player.position,false)
 if 'tractor' in parts:
  for group in ['gems','salvage_pickups']:
   for item in get_tree().get_nodes_in_group(group):
    if item.position.distance_to(w.player.position)<230: item.position=item.position.move_toward(w.player.position,dt*95)
 if 'shield' in parts: shield_ready=fmod(w.run_time,5)<1.1
 if burst_left>0:
  burst_pulses-=dt
  if burst_pulses<=0:
   burst_pulses=.3
   match burst_kind():
    'barrage': fire_round(w.player.position,Vector3.UP,'rail',w.player.damage*5)
    'gather':
     for mob in get_tree().get_nodes_in_group('mobs'):
      if not mob.dead and not 'boss_id' in mob and mob.position.distance_to(w.player.position)<260: mob.position=mob.position.move_toward(w.player.position+Vector3(0,95,0),28)
     area_damage(w.player.position+Vector3(0,90,0),150,w.player.damage*2,5)
    'bomb': area_damage(w.player.position-Vector3(0,110,0),190,w.player.damage*3,6)
    'detonate': drop_mine(w.player.position+Vector3(randf_range(-90,90),70,0),false)
 tick_pickups(dt)
 if not w.boss_active and not w.director.choosing and w.run_time>=next_event and w.director.may_spawn():
  next_event=w.run_time+randf_range(30,44);opportunity_event()
 if opportunity_until<w.run_time: opportunity=''
func refresh_hud():
 var names: Array=[]
 for id in parts: names.append(part_title(id))
 hud.text=TXT.pick('抢装：','SALVAGE: ')+(' / '.join(names) if names.size() else TXT.pick('击破标记运输舰，靠近回收','Destroy a marked carrier and collect'))
 hud.text+='\n'+TXT.pick('主炮元素：','MAIN ELEMENTS: ')+element_name(w.player.element)+(' + '+element_name(w.player.catalyst) if w.player.catalyst!='' else '')
 burst_button.text=(burst_name()+'\n'+(TXT.pick('爆发中','ACTIVE') if burst_left>0 else (TXT.pick('空格 / 点击释放','SPACE / TAP') if energy>=100 else '%d%%' % roundi(energy))))
 burst_button.disabled=energy<100 or burst_left>0
 burst_button.add_theme_color_override('font_color',Color('e7bf78') if energy>=100 else Color('dce9ed'))
 if not w.player.rule_slots.is_empty():
  var labels: Array=[]
  for id in w.player.rule_slots: labels.append(preload('res://scripts/run_rules.gd').title(id))
  hud.text+='\n'+TXT.pick('规则：','RULES: ')+' / '.join(labels)
 source_button.text=TXT.pick('切换爆发方案 ›','Change burst plan ›')
 source_button.disabled=burst_left>0
 event_label.text=opportunity
func ready(id: String,seconds: float) -> bool:
 if float(cooldowns.get(id,0))>0: return false
 cooldowns[id]=seconds;return true
func fire_round(pos: Vector3,direction: Vector3,weapon: String,damage: int):
 if get_tree().get_nodes_in_group('player_bullets').filter(func(b):return b._active).size()>220: return null
 var b=w.player.new_round();b.launch(damage,w.player.element,1,0,0,0,1,pos,direction)
 for mount in mounts:
  if is_instance_valid(mount): mount.position.y=-9
 b.source_player=w.player;b.damage_channel='salvage';b.catalyst=w.player.catalyst
 b.get_node('Mesh').mesh=preload('res://scripts/weapon_projectile.gd').mesh(weapon,b.element)
 b.get_node('Mesh').material_override=preload('res://scripts/weapon_projectile.gd').material(b.element)
 b.pierce_left=4 if weapon=='rail' else 0
 return b
func side_volley():
 for side in [-1,1]:
  for angle in [-.25,0,.25]: fire_round(w.player.position,Vector3(side*.8,.6,0).rotated(Vector3.BACK,angle),'pulse',w.player.damage)
func drop_mine(pos: Vector3,bomb: bool):
 var active=get_tree().get_nodes_in_group('player_bullets').filter(func(b):return b._active and b.projectile_role=='mine')
 if active.size()>=16: return
 var b=fire_round(pos,Vector3.DOWN if bomb else Vector3.UP,'mine',w.player.damage*3)
 if b:
  b.projectile_role='mine';b.speed=85;b.modules['blast']=true
func area_damage(pos: Vector3,radius: float,amount: float,limit: int):
 var count:=0
 for mob in get_tree().get_nodes_in_group('mobs'):
  if not mob.dead and mob.position.distance_to(pos)<radius:
   w.campaign.record_damage('salvage',mob,amount);mob.take_damage_silent(amount);count+=1
   if count>=limit: break
 FX.pulse(w,pos,Color('ffb56d'),radius*.8,false,.25,6)
func hit(target,b):
 if b.damage_channel in ['fragment','salvage','reflected']: return
 if w.player.modules.has('focus_breach'):
  if focus_target!=target.get_instance_id(): focus_target=target.get_instance_id();focus_count=0
  focus_count+=1
  if focus_count>=6 and ready('focus',.45):
   focus_count=0;w.campaign.record_damage('focus',target,b.damage*3);target.take_damage_silent(b.damage*3)
   FX.pulse(w,target.position,Color('ffd18a'),55,false,.2,6)
   w.play_sfx('heavy_hit',-12,.06)
 if 'splitter' in parts and ('boss_id' in target or target.get('elite')==true) and ready('clone',.6):
  for angle in [-.32,.32]: fire_round(w.player.position,Vector3.UP.rotated(Vector3.BACK,angle),'pulse',w.player.damage)
func enemy_killed(enemy):
 add_energy(2.5)
 if w.player.modules.has('shield_clone') and enemy.kind in ['shield','projector'] and ready('shield_clone',.8): side_volley.call_deferred()
func block_projectile(shot) -> bool:
 var ahead: bool=shot.position.y>w.player.position.y-10
 if not ahead or shot.position.distance_to(w.player.position)>80: return false
 if not ((burst_left>0 and burst_kind()=='reflect') or ('shield' in parts and shield_ready)): return false
 var direction: Vector3=-shot.dir
 fire_round(shot.position,direction,'rail',w.player.damage*3)
 add_energy(.5)
 FX.pulse(w,shot.position,Color('8be4ed'),32,false,.18,6)
 return true
func graze(shot):
 if w.player.modules.has('graze_core') and not shot.has_meta('grazed'):
  var d: float=shot.position.distance_to(w.player.position)
  if d>24 and d<58:
   shot.set_meta('grazed',true);add_energy(2.5)
func opportunity_event():
 if event_bag.is_empty(): event_bag=['transport','repair_chain','battery','convoy','breakthrough'];event_bag.shuffle()
 var kind: String
 if parts.is_empty() and collected==0:
  kind='transport';event_bag.erase('transport')
 else: kind=event_bag.pop_back()
 events_seen.append(kind);opportunity_until=w.run_time+16
 match kind:
  'transport','convoy':
   opportunity=TXT.pick('武装运输舰 · 击破并靠近回收','ARMED TRANSPORT · break and recover')
   var first: bool=parts.is_empty() and collected==0
   var carrier=w.director.make_enemy('shooter',Vector3(clampf(w.player.position.x,-250,250),200,0) if first else Vector3(-460,180,0))
   if carrier:
    carrier.health=8+int(w.run_time/35);carrier.max_hp=carrier.health;carrier.set_meta('salvage_carrier',true)
    if first: carrier.health=4;carrier.max_hp=4
    carrier.set_meta('first_salvage',first)
    mark_drop(carrier,PARTS.keys().pick_random())
   if kind=='convoy':
    for x in [-240,0,240]: w.director.make_enemy('normal',Vector3(x,280,0))
  'repair_chain':
   opportunity=TXT.pick('拆掉维修链 · 获取牵引装置','BREAK REPAIR CHAIN · tractor salvage')
   var healer=w.director.make_enemy('repair',Vector3(0,290,0))
   if healer: mark_drop(healer,'tractor')
   for x in [-100,100]: w.director.make_enemy('normal',Vector3(x,250,0))
  'battery':
   opportunity=TXT.pick('夺取炮台 · 充满能量并获得6秒火力支援','CAPTURE TURRET · full energy and 6s support')
   var turret=w.director.make_enemy('tank',Vector3(0,250,0))
   if turret:
    turret.health=12;turret.max_hp=12
    turret.died.connect(func(pos,_v,_c,_h):start_support.call_deferred(pos))
  'breakthrough':
   opportunity=TXT.pick('临时突破口 · 侧翼有可回收武装','BREACH OPEN · recover side hardware')
   gap_side=1.0 if randf()>.5 else -1.0;gap_until=w.run_time+6
   spawn_pickup(Vector3(gap_side*350,120,0),PARTS.keys().pick_random())
func start_support(pos: Vector3):
 add_energy(100)
 if is_instance_valid(support_node): support_node.queue_free()
 support_node=hardware('cannon');support_node.position=pos;w.add_child(support_node)
 support_until=w.run_time+6
func mark_drop(enemy,id: String):
 enemy.set_meta('salvage_drop',id)
 enemy.died.connect(func(pos,_v,_c,_hp):spawn_pickup.call_deferred(pos,id))
 var label:=Label3D.new();label.text=TXT.pick('可抢装','SALVAGE');label.font_size=30;label.pixel_size=.6;label.position=Vector3(0,45,15);enemy.add_child(label)
func hardware(id: String) -> Node3D:
 var hull=preload('res://scripts/blender_hostiles.gd').build('boss',int(PARTS[id][4]),65,false)
 var selected: Node3D
 for node in hull.find_children('*','MeshInstance3D',true,false):
  if 'Weapon' in node.name or 'Shield' in node.name or 'Bay' in node.name: selected=node;break
 var result:=Node3D.new()
 if selected:
  var mesh=selected.duplicate();mesh.transform=selected.transform;result.add_child(mesh)
  var bounds=preload('res://scripts/blender_fleet.gd').visible_bounds(result)
  mesh.position-=bounds.get_center();result.scale=Vector3.ONE*(30/maxf(1,bounds.size.length()));result.rotation.x=PI/2
 else:
  result.add_child(hull)
  hull.scale=Vector3.ONE*.4
 if selected: hull.free()
 return result
func spawn_pickup(pos: Vector3,id: String):
 if w.dying or pickups.size()>=3: return
 var item=hardware(id);item.position=pos;w.add_child(item);item.add_to_group('salvage_pickups')
 var label:=Label3D.new();label.text=part_title(id);label.font_size=27;label.pixel_size=.6;item.add_child(label)
 label.top_level=true;label.scale=Vector3.ONE;label.rotation=Vector3.ZERO;label.global_position=item.global_position+Vector3(0,28,10);label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
 pickups.append({'node':item,'id':id,'life':20.0,'label':label,'first':collected==0})
func tick_pickups(dt: float):
 for i in range(pickups.size()-1,-1,-1):
  var item=pickups[i];var node: Node3D=item.node
  item.life-=dt;node.position.y-=dt*12;node.rotation.z+=dt*.5
  item.label.global_position=node.global_position+Vector3(0,28,10)
  if node.position.distance_to(w.player.position)<85: node.position=node.position.move_toward(w.player.position,dt*220)
  elif item.first: node.position=node.position.move_toward(w.player.position,dt*170)
  if node.position.distance_to(w.player.position)<28:
   pending.append(item.id);collected+=1;node.queue_free();pickups.remove_at(i)
  elif item.life<=0 or node.position.y< -380:
   node.queue_free();pickups.remove_at(i)
func present(id: String):
 offered.assign([id,PARTS.keys()[(PARTS.keys().find(id)+1+randi()%4)%6]])
 for i in 2:
  buttons[i].text=part_title(offered[i])+'\n'+PARTS[offered[i]][2 if preload('res://scripts/i18n.gd').lang()=='zh' else 3]
  if offered[i] in parts: buttons[i].text+='\n'+TXT.pick('已装配 · 回收+35能量，修复2装甲','Owned · +35 energy, repair 2 armor')
  elif parts.size()>=2: buttons[i].text+='\n'+TXT.pick('替换：','Replace: ')+part_title(parts[0])
 panel.show();w.director.refresh_hud();get_tree().paused=true;w.get_node('TouchUI').reset();w.pause_button.hide()
func install(id: String):
 burst_source=id
 if id in parts:
  add_energy(35);w.health=mini(w.max_health,w.health+2)
 else:
  if parts.size()>=2: parts.pop_front();add_energy(20)
  parts.append(id);add_energy(20)
 rebuild_mounts()
func rebuild_mounts():
 for mount in mounts:
  if is_instance_valid(mount): mount.queue_free()
 mounts.clear()
 for i in parts.size():
  var mount=hardware(parts[i]);w.player.add_child(mount);mount.position=Vector3(-40 if i==0 else 40,-4,10)
  mount.scale*=1.4;mounts.append(mount)
func select(index: int):
 if not panel.visible or index>=offered.size(): return
 install(offered[index]);close_offer()
func recycle_offer():
 if not panel.visible: return
 add_energy(20);close_offer()
func close_offer():
 panel.hide();get_tree().paused=false;w.pause_button.show();w.director.refresh_hud();refresh_hud()
