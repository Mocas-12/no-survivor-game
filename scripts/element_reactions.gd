extends RefCounted
## One symmetric reaction per hit. Secondary damage never applies another element.
const VISUAL=preload("res://scripts/reaction_fx.gd")
const PAIRS={"fire+water":"steam", "fire+ice":"melt", "lightning+water":"conduct", "ice+water":"freeze", "ice+lightning":"shatter", "fire+lightning":"overload"}
const COLORS={"fire":Color("ff864d"),"water":Color("56cfff"),"ice":Color("bdedff"),"lightning":Color("d1a3ff")}

static func state(target) -> Dictionary:
	if not target.has_meta("elements"): target.set_meta("elements",{})
	return target.get_meta("elements")

static func pair(a: String,b: String) -> String:
	var keys=[a,b]; keys.sort()
	return PAIRS.get("+".join(keys),"")

static func tick(target,dt: float) -> void:
	var s=state(target)
	for key in s.keys():
		s[key]=maxf(0,float(s[key])-dt)
		if s[key]<=0: s.erase(key)
	if s.has("fire"):
		var next=float(target.get_meta("burn_tick",0))-dt
		if next<=0:
			next=.65
			target.take_damage_silent(float(target.get_meta("burn_damage",1)))
		target.set_meta("burn_tick",next)

static func movement(target) -> float:
	var s=state(target)
	if s.has("frozen"): return .65 if "boss_id" in target else .08
	return .82 if s.has("ice") and "boss_id" in target else (.58 if s.has("ice") else 1.0)

static func nearby(target,radius: float,limit:=6) -> Array:
	var found=[]
	for m in target.get_tree().get_nodes_in_group("mobs"):
		if m!=target and not m.dead and target.global_position.distance_to(m.global_position)<=radius: found.append(m)
	found.sort_custom(func(a,b): return target.global_position.distance_squared_to(a.global_position)<target.global_position.distance_squared_to(b.global_position))
	return found.slice(0,limit)

static func apply(target,element: String,damage: float,level: int,boost: float,mark: float,world) -> String:
	if target.dead or not COLORS.has(element) and element!="wind": return ""
	var s=state(target)
	if element=="wind":
		if s.has("wind_cd"): return ""
		s["wind_cd"]=.5
		var spread=""
		for key in COLORS:
			if s.has(key): spread=key; break
		for m in nearby(target,170,3):
			if m.has_method("knockback"): m.knockback((target.global_position-m.global_position).normalized()*18)
			if spread!="": state(m)[spread]=1.4*mark
			if spread=="fire": m.set_meta("burn_damage",maxf(1,damage*.15))
			if spread!="": preload("res://scripts/precision_fx.gd").pulse(world,target.global_position.lerp(m.global_position,.5),COLORS[spread],40,false,.25,6)
		return ""
	var reaction=""
	if not s.has("reaction_cd"):
		for other in COLORS:
			if other!=element and s.has(other):
				reaction=pair(other,element)
				if reaction!="": s.erase(other); break
	s[element]=(2.1+.25*maxi(level-1,0))*mark
	if element=="fire": target.set_meta("burn_damage",maxf(.5,damage*.18))
	if element=="water" and target.has_method("knockback"): target.knockback(Vector3(0,12,0))
	if reaction=="":
		if element=="lightning" and not s.has("chain_cd"):
			s["chain_cd"]=.3
			for m in nearby(target,140,mini(level+1,4)):
				m.take_damage_silent(maxf(1,damage*.5))
				if world.has_method("spawn_lightning"): world.spawn_lightning(target.global_position,m.global_position)
		return ""
	s.erase(element)
	s["reaction_cd"]=.8 if "boss_id" in target else .55
	var amount=damage*boost
	var affected=[]
	match reaction:
		"melt": target.take_damage_silent(amount*1.6)
		"steam":
			s["exposed"]=1.8
			for m in nearby(target,130): m.take_damage_silent(maxf(1,amount*.65))
		"freeze":
			s["frozen"]=.65 if "boss_id" in target else 1.15
			if "attack_cd" in target: target.attack_cd=maxf(target.attack_cd,.35)
		"conduct":
			affected=nearby(target,220,30)
			affected.sort_custom(func(a,b): return state(a).has("water") and not state(b).has("water"))
			affected=affected.slice(0,5)
			for m in affected:
				m.take_damage_silent(maxf(1,amount*(1 if state(m).has("water") else .65)))
				if world.has_method("spawn_lightning"): world.spawn_lightning(target.global_position,m.global_position)
		"shatter", "overload":
			target.take_damage_silent(amount*.7)
			for m in nearby(target,150): m.take_damage_silent(maxf(1,amount*.8))
			if reaction=="overload" and "fire_cd" in target: target.fire_cd=maxf(target.fire_cd,.35)
	if world.get("director")!=null: world.director.reactions+=1
	if world.has_method("spawn_reaction_text"):
		var key="react_"+reaction
		world.spawn_reaction_text(target.global_position,key,Color("e4f4ff"))
	VISUAL.emit(world,target.global_position,reaction)
	return reaction
