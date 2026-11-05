extends Node3D
## Mechanical response only; no collision, weapon or balance changes.
var age:=0.0
var recoil:=0.0
var bay_response:=0.0
var moving: Array[Node3D]=[]
var family:="common"

func configure() -> void:
	for piece in find_children("SM_*","MeshInstance3D",true,false):
		var role:=String(piece.name).trim_prefix("SM_")
		if role.begins_with("Stage") or role=="Hull": continue
		var pivot:=Node3D.new()
		pivot.name=role+"Pivot"
		var parent:=piece.get_parent()
		var old: Transform3D=piece.transform
		var center: Vector3=old*piece.get_aabb().get_center()
		parent.add_child(pivot)
		pivot.position=center
		piece.owner=null
		parent.remove_child(piece)
		pivot.add_child(piece)
		piece.transform=Transform3D(Basis.IDENTITY,-center)*old
		pivot.set_meta("rest",center)
		pivot.set_meta("role",role)
		moving.append(pivot)

func fire(heavy:=false) -> void:
	recoil=maxf(recoil,1.0 if heavy else 0.55)

func launch_bay() -> void:
	bay_response=1.0

func _process(dt: float) -> void:
	advance(dt)

func advance(dt: float) -> void:
	age+=dt
	recoil=move_toward(recoil,0.0,dt*5.5)
	bay_response=move_toward(bay_response,0.0,dt*2)
	var opening:=1.0-pow(1.0-clampf(age/.65,0,1),3)
	for part in moving:
		var role: String=part.get_meta("role")
		part.position=part.get_meta("rest")
		if role.begins_with("Weapon"):
			part.position.z+=recoil*(.17 if family=="siege" else .09)
		if role.begins_with("Bay"):
			part.position.x+=(1.0 if role.ends_with("Right") else -1.0)*bay_response*.12
		if role.begins_with("Wing"):
			part.scale.x=.84+.16*opening
		if role.begins_with("Shield"):
			part.rotation.y=sin(age*.8)*.07
		if role.begins_with("Engine"):
			part.scale=Vector3.ONE*(1.0+sin(age*5)*.003)
