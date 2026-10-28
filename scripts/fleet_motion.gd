extends Node3D
## Cosmetic motion only; pulse is called by the existing boss projectile emission.
@export var kind := 1
var clock := 0.0
var recoil := 0.0
var core: StandardMaterial3D

static func attach(root: Node3D,n: int,light: StandardMaterial3D) -> void:
	root.set_script(load("res://scripts/fleet_motion.gd"))
	root.set("kind",n)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("9aa8b4")
	metal.metallic = 0.8
	metal.roughness = 0.3
	if n == 1:
		var battery := Node3D.new()
		battery.name = "Battery"
		root.add_child(battery)
		battery.owner = root
		for s in [-1,1]:
			for y in [-17,17]:
				var mount := Node3D.new()
				mount.position = Vector3(s*41,y,16)
				battery.add_child(mount)
				mount.owner = root
				for x in [-3,3]:
					var mesh := BoxMesh.new()
					mesh.size = Vector3(3,20,3)
					part(root,mount,mesh,Vector3(x,9,0),metal)
				var flash := BoxMesh.new()
				flash.size = Vector3(8,2,2)
				var tip := part(root,mount,flash,Vector3(0,19,0),light)
				tip.name = "Flash"
				tip.visible = false
	if n == 3:
		var armor := Node3D.new()
		armor.name = "ArmorRotor"
		root.add_child(armor)
		armor.owner = root
		var coat: Material = root.get_node("Surface1").material_override
		for i in 6:
			var a: float = TAU*i/6
			var pod := Node3D.new()
			pod.position = Vector3(cos(a)*39,sin(a)*39,0)
			pod.rotation.z = a-PI/2
			armor.add_child(pod)
			pod.owner = root
			var shell := CylinderMesh.new()
			shell.top_radius = 14
			shell.bottom_radius = 16
			shell.height = 8
			shell.radial_segments = 6
			part(root,pod,shell,Vector3(0,0,7),coat).rotation.x = PI/2
			var plate := BoxMesh.new()
			plate.size = Vector3(10,14,2)
			part(root,pod,plate,Vector3(0,0,12),metal)
			var slit := BoxMesh.new()
			slit.size = Vector3(8,2,2)
			part(root,pod,slit,Vector3(0,-3,14),light)
		root.set_meta("extent",110.0)
	if n == 6:
		for j in 2:
			var rotor := Node3D.new()
			rotor.name = "Rotor"+str(j)
			root.add_child(rotor)
			rotor.owner = root
			for i in 6:
				var a: float = TAU*i/6
				var mesh := BoxMesh.new()
				mesh.size = Vector3(6,4,3)
				var r: float = 52 if j == 0 else 28
				var tab := part(root,rotor,mesh,Vector3(cos(a)*r,sin(a)*r,17+j*2),metal if j == 0 else light)
				tab.rotation.z = a

static func part(root: Node3D,parent: Node3D,mesh: Mesh,pos: Vector3,mat: Material) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.mesh = mesh
	item.material_override = mat
	item.position = pos
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(item)
	item.owner = root
	return item

func _ready() -> void:
	var surface: MeshInstance3D = get_node("Surface4")
	core = surface.material_override.duplicate()
	surface.material_override = core
	if kind == 5:
		get_node("Surface3").material_override = get_node("Surface3").material_override.duplicate()

func shot() -> void:
	recoil = 1.0

func _process(delta: float) -> void:
	clock += delta
	recoil = maxf(0,recoil-delta*7)
	var world = get_tree().current_scene
	var reduced: bool = world != null and "reduce_fx" in world and world.reduce_fx
	var parent := get_parent()
	var enraged: bool = parent is CharacterBody3D and "enraged" in parent and parent.enraged
	core.emission_energy_multiplier = (1.55 if enraged else 1.0) + (0.0 if reduced else sin(clock*3)*0.12+recoil*0.3)
	if reduced:
		return
	if kind == 1:
		get_node("Battery").position.y = -recoil*3
		for mount in get_node("Battery").get_children():
			mount.get_node("Flash").visible = recoil > 0.8
	elif kind == 2:
		get_node("Surface1").scale.x = 1.0+sin(clock*2)*0.015
	elif kind == 3:
		get_node("ArmorRotor").rotation.z += delta*(0.17 if not enraged else 0.3)
	elif kind == 4:
		if parent is CharacterBody3D and "attack_cd" in parent:
			core.emission_energy_multiplier += clampf(1.0-parent.attack_cd/0.35,0,1)*0.7
	elif kind == 5:
		get_node("Surface3").material_override.albedo_color.a = 0.6+sin(clock*2.3)*0.12
	elif kind == 6:
		var final_phase: bool = parent is CharacterBody3D and "phase3" in parent and parent.phase3
		get_node("Rotor0").rotation.z += delta*(0.42 if final_phase else 0.24)
		get_node("Rotor1").rotation.z -= delta*(0.6 if enraged else 0.37)
		get_node("Rotor1").scale = Vector3.ONE*(1.12 if final_phase else 1.0)
