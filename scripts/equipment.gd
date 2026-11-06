extends RefCounted
const MODS=["split","ricochet","returning","blast","execute","expose","frostwake","wetwake","firewake"]

static func key(p,slot: String) -> String:
	return "main:"+p.weapon if slot=="main" else "aux:"+(p.auxiliary if slot=="aux1" else p.second_auxiliary)

static func installed(p,slot: String) -> Dictionary:
	return p.weapon_modules.get(key(p,slot),{})

static func equip(p,id: String,slot: String) -> void:
	var identity:=key(p,slot)
	var items: Dictionary=p.weapon_modules.get(identity,{}).duplicate()
	if not items.has(id) and items.size()>=2: items.erase(items.keys()[0])
	items[id]=true
	p.weapon_modules[identity]=items

static func profile(p,slot: String) -> Dictionary:
	var result: Dictionary=p.modules.duplicate()
	result.merge(installed(p,slot),true)
	return result

static func label(p,slot: String) -> String:
	if slot=="main": return preload("res://scripts/arsenal.gd").title(p.weapon)
	var id: String=p.auxiliary if slot=="aux1" else p.second_auxiliary
	return preload("res://scripts/arsenal.gd").title("aux_"+id) if id!="" else preload("res://scripts/module_readout.gd").pick("空槽","Empty slot")

static func preview(p,id: String,slot_override:="") -> String:
	var slot: String=p.equipment_focus if slot_override=="" else slot_override
	var items:=installed(p,slot)
	var names: Array=[]
	for mod in items: names.append(preload("res://scripts/arsenal.gd").title(mod))
	var replacing: String=""
	if items.size()>=2 and not items.has(id): replacing=preload("res://scripts/module_readout.gd").pick("\n替换：","\nReplace: ")+str(names[0])
	return label(p,slot)+" · %d/2" % items.size()+replacing

static func has_active(p,id: String) -> bool:
	for slot in ["main","aux1","aux2"]:
		if profile(p,slot).has(id): return true
	return false
