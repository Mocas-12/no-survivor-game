extends Node3D
## Bounded pooled cosmetic pulses; no lights, damage, timers or gameplay dependencies.
const SHADER=preload("res://scripts/precision_fx.gdshader")
static var pool: Array=[]
static var active_count:=0
static var quad: QuadMesh
var age:=0.0
var lifetime:=.3
var active:=false
var visual: MeshInstance3D
var material: ShaderMaterial

static func pulse(parent: Node,pos: Vector3,color: Color,size: float,big:=false,duration:=.32,style:=0) -> Node3D:
	var world=parent.get_tree().current_scene
	var reduced: bool=world!=null and "reduce_fx" in world and world.reduce_fx
	if active_count>=(24 if reduced else 72): return null
	var effect: Node3D
	while not pool.is_empty():
		var candidate=pool.pop_back()
		if is_instance_valid(candidate) and candidate.is_inside_tree():
			effect=candidate
			break
	if effect==null:
		effect=new()
		effect.visual=MeshInstance3D.new()
		if quad==null:
			quad=QuadMesh.new()
			quad.size=Vector2.ONE
		effect.visual.mesh=quad
		effect.visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		effect.material=ShaderMaterial.new()
		effect.material.shader=SHADER
		effect.visual.material_override=effect.material
		effect.add_child(effect.visual)
		parent.add_child(effect)
	elif effect.get_parent()!=parent:
		effect.get_parent().remove_child(effect)
		parent.add_child(effect)
	effect.position=pos+Vector3(0,0,3)
	effect.scale=Vector3.ONE*size*(.75 if reduced else 1.0)
	effect.material.set_shader_parameter("tint",Color(color,color.a*(.55 if reduced else 1.0)))
	effect.material.set_shader_parameter("mode",1.0 if big else 0.0)
	effect.material.set_shader_parameter("style",float(style))
	effect.material.set_shader_parameter("radius_from",.1)
	effect.material.set_shader_parameter("radius_to",.87)
	effect.material.set_shader_parameter("progress",0.0)
	effect.age=0
	effect.lifetime=duration
	effect.active=true
	effect.visible=true
	effect.process_mode=Node.PROCESS_MODE_ALWAYS
	effect.set_process(true)
	active_count+=1
	return effect

func _process(dt: float) -> void:
	var world=get_tree().current_scene
	if get_tree().paused and world!=null and "pause_panel" in world and world.pause_panel.visible: return
	advance(dt)

func advance(dt: float) -> void:
	if not active: return
	age+=dt
	material.set_shader_parameter("progress",minf(age/lifetime,1))
	if age>=lifetime:
		active=false
		visible=false
		set_process(false)
		active_count-=1
		pool.append(self)

func _exit_tree() -> void:
	if active:
		active_count-=1
		active=false
