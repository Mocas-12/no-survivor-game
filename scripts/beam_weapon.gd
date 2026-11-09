extends Node3D
## Phase-locked pulse visuals, audio and damage. World-sized, not scaled by the hull.
const CYCLE:=.7
const START:=.12
const END:=.58
const DUTY:=(END-START)/CYCLE
const SHADER=preload("res://scripts/pulse_beam.gdshader")
const CYCLE_SOUNDS=[preload("res://assets/sounds/beam-cycle-0.wav"),preload("res://assets/sounds/beam-cycle-1.wav"),preload("res://assets/sounds/beam-cycle-2.wav")]
var player: Node
var visual: MeshInstance3D
var muzzle: MeshInstance3D
var contacts: Array[MeshInstance3D]=[]
var mat: ShaderMaterial
var audio: AudioStreamPlayer
var impact_audio: AudioStreamPlayer
var age:=0.0
var damage_credit:=0.0
var active:=false
var phase:="idle"
var beam_length:=0.0
var width:=0.0
var impact_cooldown:=0.0
var audio_cycles:=0
var cycle_hit:=false
func make_quad(size: Vector2,kind: int=0) -> MeshInstance3D:
    var result:=MeshInstance3D.new()
    var quad:=QuadMesh.new()
    quad.size=size
    result.mesh=quad
    var shader:=ShaderMaterial.new()
    shader.shader=SHADER
    shader.set_shader_parameter("kind",kind)
    result.material_override=shader
    result.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(result)
    return result
func _ready():
    player=get_parent()
    top_level=true
    process_mode=Node.PROCESS_MODE_ALWAYS
    visual=make_quad(Vector2(48,1))
    mat=visual.material_override
    muzzle=make_quad(Vector2(32,32),1)
    for i in 3:
        contacts.append(make_quad(Vector2(23,23),1))
    audio=AudioStreamPlayer.new()
    audio.volume_db=-13
    add_child(audio)
    impact_audio=AudioStreamPlayer.new()
    impact_audio.stream=preload("res://assets/sounds/beam-impact.wav")
    impact_audio.volume_db=-19
    add_child(impact_audio)
    hide_effect()
func hide_effect():
    visible=false
    audio.stop()
    impact_audio.stop()
    active=false
    phase="idle"
    age=0
    cycle_hit=false
    damage_credit=0
func exposed_time(time: float) -> float:
    return floorf(time/CYCLE)*(END-START)+clampf(fposmod(time,CYCLE)-START,0,END-START)
func play_cycle():
    audio.stream=CYCLE_SOUNDS[audio_cycles%3]
    audio_cycles+=1
    audio.play()
func _process(dt: float):
    var w=get_tree().current_scene
    if player.weapon!="beam" or w.start_panel.visible or w.dying or w.victory_panel.visible or w.game_over_panel.visible:
        if active: hide_effect()
        return
    var paused: bool=get_tree().paused
    audio.stream_paused=paused
    impact_audio.stream_paused=paused
    if paused: return
    if not active:
        active=true
        visible=true
        play_cycle()
    var old_age:=age
    age+=dt
    if floori((age-END)/CYCLE)>floori((old_age-END)/CYCLE):
        if cycle_hit and player.modules.has('salvage_return') and w.get('salvage')!=null: w.salvage.add_energy(2)
        cycle_hit=false
    if floori(age/CYCLE)>floori(old_age/CYCLE): play_cycle()
    var t:=fposmod(age,CYCLE)
    if floori((age-START)/CYCLE)>floori((old_age-START)/CYCLE): player._hull_fire(true)
    phase="charge" if t<START else ("burst" if t<.20 else ("sustain" if t<END else "cooldown"))
    var power:=smoothstep(0,START,t)*.18 if t<START else (1.0 if t<END else 1.0-smoothstep(END,CYCLE,t))
    if phase=="burst": power*=1.15
    var low: bool=w.performance_limited or w.reduce_fx
    var color: Color=preload("res://scripts/projectile_geometry.gd").PLAYER.get(player.element,Color("8deafa"))
    global_position=player.global_position+Vector3(0,28*player.base_scale,3)
    var view: Rect2=get_viewport().get_visible_rect()
    var top: Vector3=w.camera.project_position(Vector2(view.get_center().x,-24),w.camera.global_position.z-global_position.z)
    var length_to_edge:=maxf(40,top.y-global_position.y)
    width=5.5+minf(player.bullet_count,9)*.7+player.form*.12
    var bursting: bool=w.get('salvage')!=null and w.salvage.burst_left>0
    if bursting: width*=1.8
    audio.volume_db=-11 if bursting else -13
    audio.pitch_scale=1.04 if bursting else 1.0
    var targets: Array=get_tree().get_nodes_in_group("mobs").filter(func(m):return not m.dead and m.global_position.y>global_position.y and m.global_position.y<top.y and absf(m.global_position.x-global_position.x)<width)
    targets.sort_custom(func(a,b):return a.global_position.y<b.global_position.y)
    targets=targets.slice(0,3)
    beam_length=targets[-1].global_position.y-global_position.y+10 if targets.size()==3 else length_to_edge
    visual.position=Vector3(0,beam_length/2,0)
    visual.scale=Vector3(width/4,beam_length,1)
    visual.visible=t>=START
    mat.set_shader_parameter("tint",color)
    var secondary: Color=preload("res://scripts/projectile_geometry.gd").PLAYER.get(player.catalyst,color)
    mat.set_shader_parameter("secondary",secondary)
    mat.set_shader_parameter("clock",age)
    mat.set_shader_parameter("energy",power*(.9 if low else .88+.08*sin(age*68)))
    mat.set_shader_parameter("detail",0.0 if low else 1.0+player.form*.025)
    muzzle.material_override.set_shader_parameter("tint",color)
    muzzle.material_override.set_shader_parameter("secondary",secondary)
    muzzle.material_override.set_shader_parameter("energy",power if t>=START else smoothstep(0,START,t)*.6)
    muzzle.scale=Vector3.ONE*(.7+player.form*.018)
    for i in 3:
        contacts[i].visible=i<targets.size() and t>=START and t<END
        if contacts[i].visible:
            contacts[i].global_position=Vector3(global_position.x,targets[i].global_position.y,global_position.z+2)
            contacts[i].material_override.set_shader_parameter("tint",color)
            contacts[i].material_override.set_shader_parameter("secondary",secondary)
            contacts[i].material_override.set_shader_parameter("energy",power*(.85+.12*sin(age*54+i)))
    var interval:=maxf(.09,player.fire_cooldown*.65)
    damage_credit+=(exposed_time(age)-exposed_time(old_age))/DUTY/interval
    damage_credit=minf(damage_credit,6)
    impact_cooldown-=dt
    if t<START or t>=END: return
    var hits:=0
    while damage_credit>=1:
        damage_credit-=1
        for target in targets:
            if not is_instance_valid(target) or target.dead: continue
            var round=player.new_round()
            round.launch(maxi(1,player.damage*mini(3,player.bullet_count/3)),player.element,0,0,0,0,1,target.position,Vector3.UP)
            preload("res://scripts/arsenal.gd").configure(player,round)
            round._on_body_entered(target)
            round._recycle()
            hits+=1
    if hits>0 and impact_cooldown<=0:
        cycle_hit=true
        impact_audio.play()
        impact_cooldown=.14
