extends RefCounted
## One symmetric reaction per hit. Secondary damage never applies another element.
const VISUAL=preload("res://scripts/reaction_fx.gd")
const PAIRS={"fire+water":"steam", "fire+ice":"melt", "lightning+water":"conduct", "ice+water":"freeze", "ice+lightning":"shatter", "fire+lightning":"overload", "fire+wind":"firestorm", "water+wind":"vortex", "ice+wind":"frost_blades", "lightning+wind":"storm_arc"}
const COLORS={"fire":Color("ff864d"),"water":Color("56cfff"),"ice":Color("bdedff"),"lightning":Color("d1a3ff"),"wind":Color("82dec1")}

static func state(target) -> Dictionary:
	if not target.has_meta("elements"): target.set_meta("elements",{})
	return target.get_meta("elements")

static func pair(a: String,b: String) -> String:
	var keys=[a,b]; keys.sort()
	return PAIRS.get("+".join(keys),"")

static func hurt(target,amount: float,world) -> void:
	if world.get("campaign")!=null: world.campaign.record_damage("reaction",target,amount)
	target.take_damage_silent(amount)

static func tick(target,dt: float) -> void:
	var s=state(target)
	for key in s.keys():
		s[key]=maxf(0,float(s[key])-dt)
		if s[key]<=0: s.erase(key)
	if s.has("fire"):
		var next=float(target.get_meta("burn_tick",0))-dt
		if next<=0:
			next=.65
			hurt(target,float(target.get_meta("burn_damage",1)),target.get_tree().current_scene)
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
	if element=="wind" and not COLORS.keys().any(func(key):return key!="wind" and s.has(key)):
		s["wind"]=2.1*mark
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
				hurt(m,maxf(1,damage*.5),world)
				if world.has_method("spawn_lightning"): world.spawn_lightning(target.global_position,m.global_position)
		return ""
	s.erase(element)
	s["reaction_cd"]=.8 if "boss_id" in target else .55
	if world.get("campaign")!=null: world.campaign.reaction_counts[reaction]=int(world.campaign.reaction_counts.get(reaction,0))+1
	var amount=damage*boost
	var affected=[]
	match reaction:
		"firestorm":
			for m in nearby(target,180,4):
				state(m)["fire"]=2.0
				m.set_meta("burn_damage",maxf(1,amount*.2))
				hurt(m,amount*.5,world)
		"vortex":
			for m in nearby(target,190,4):
				if not "boss_id" in m: m.position=m.position.move_toward(target.position,28)
				hurt(m,amount*.45,world)
		"frost_blades":
			for m in nearby(target,200,4):
				state(m)["ice"]=1.3
				hurt(m,amount*.65,world)
				FX_blade(world,target.position,m.position,Color("a3e7ed"))
		"storm_arc":
			for m in nearby(target,240,4):
				hurt(m,amount*.6,world)
				if world.has_method("spawn_lightning"): world.spawn_lightning(target.position,m.position)
		"melt": hurt(target,amount*1.6,world)
		"steam":
			s["exposed"]=1.8
			if world.get("player")!=null and world.player.modules.has("reaction_salvage"): preload("res://scripts/reaction_field.gd").spawn(world,target.global_position,amount)
			for m in nearby(target,130): hurt(m,maxf(1,amount*.65),world)
		"freeze":
			s["frozen"]=.65 if "boss_id" in target else 1.15
			if "attack_cd" in target: target.attack_cd=maxf(target.attack_cd,.35)
		"conduct":
			affected=nearby(target,220,30)
			affected.sort_custom(func(a,b): return state(a).has("water") and not state(b).has("water"))
			affected=affected.slice(0,5)
			for m in affected:
				hurt(m,maxf(1,amount*(1 if state(m).has("water") else .65)),world)
				if world.has_method("spawn_lightning"): world.spawn_lightning(target.global_position,m.global_position)
		"shatter", "overload":
			hurt(target,amount*.7,world)
			for m in nearby(target,150): hurt(m,maxf(1,amount*.8),world)
			if reaction=="overload" and "fire_cd" in target: target.fire_cd=maxf(target.fire_cd,.35)
	if reaction=="shatter" and world.get("player")!=null and preload("res://scripts/equipment.gd").has_active(world.player,"split"):
		for other in nearby(target,160,3): state(other)["ice"]=1.2
	if world.get("director")!=null: world.director.reactions+=1
	if world.get("player")!=null and world.player.modules.has("jump_arc"):
		for other in nearby(target,190,2):
			hurt(other,maxf(1,amount*.45),world)
			if world.has_method("spawn_lightning"): world.spawn_lightning(target.position,other.position)
	if world.get("player")!=null and world.player.modules.has("reaction_salvage"): world.player.overdrive=minf(6,world.player.overdrive+.2)
	if world.has_method("spawn_reaction_text"):
		var key="react_"+reaction
		world.spawn_reaction_text(target.global_position,key,Color("e4f4ff"))
	VISUAL.emit(world,target.global_position,{"firestorm":"melt","vortex":"steam","frost_blades":"shatter","storm_arc":"conduct"}.get(reaction,reaction))
	return reaction

static func FX_blade(world,a: Vector3,b: Vector3,color: Color):
	preload("res://scripts/precision_fx.gd").pulse(world,a.lerp(b,.5),color,55,false,.22,6)
