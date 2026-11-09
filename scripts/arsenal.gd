extends RefCounted
## Composable weapons. Secondary hits never recurse through projectile callbacks.
const EXTRA = {
	"repair_on_kill":["战场回收","Field salvage","每十次击破修复一点装甲；不超过装甲上限","Repair one armor per ten kills; capped at maximum","armor"],
	"rail":["轨道重炮","Rail cannon","主炮切换：低频蓄能、三倍伤害、贯穿三目标","Slow charged shots; triple damage; pierce three targets","velocity"],
	"missile":["蜂群导弹","Swarm missiles","主炮切换：先散开，再追踪目标","Spread first, then track targets","multishot"],
	"blade":["回旋飞刃","Returning blades","主炮切换：穿透后回旋，覆盖身后","Pierce and return behind your ship","wind"],
	"beam":["脉冲光束","Pulse beam","主炮切换：持续光束，沿航向贯穿最多三个目标","Sustained beam pierces up to three aligned targets","lightning"],
	"mine":["感应雷阵","Proximity mines","主炮切换：缓行布雷，近敌爆破","Slow mines detonate near targets","fire"],
	"pulse":["脉冲机炮","Pulse cannon","主炮切换：稳定高频齐射","Reliable automatic volleys","fire_rate"],
	"aux_fire":["烈焰副炮","Flame auxiliary","新增或强化火系辅助；最多两种同时工作","Add or upgrade fire support; two auxiliaries coexist","fire"],
	"aux_lightning":["雷霆副炮","Arc auxiliary","新增或强化雷系辅助；最多两种同时工作","Add or upgrade arc support; two auxiliaries coexist","lightning"],
	"aux_wind":["旋风副炮","Gust auxiliary","新增或强化风系辅助；传播元素标记","Wind support spreads elemental marks","wind"],
	"split":["分裂弹芯","Split core","主弹命中后释放两枚弱化副弹；副弹不再分裂","Primary hits release two weaker non-splitting shots","multishot"],
	"ricochet":["折射弹道","Ricochet","主弹触及左右边界时反弹一次","Primary shots bounce once at side boundaries","wave"],
	"returning":["回收弹道","Return path","主弹飞行后回转一次，扫过第二片区域","Primary shots turn back once in flight","wind"],
	"blast":["破片弹头","Blast payload","命中时对附近最多四个目标造成副伤害","Impact splash hits up to four nearby targets","fire"],
	"execute":["弱点收割","Execution","目标低于30%生命时，直接命中伤害提高","Direct hits deal more damage below 30% target health","crit"],
	"expose":["装甲撕裂","Armor tear","直接命中短暂暴露弱点，后续攻击受益","Direct hits expose weak points for subsequent attacks","pierce"],
	"frostwake":["霜痕弹芯","Frost wake","主弹命中额外挂冰，冷却0.7秒","Primary hits add frost; 0.7s target cooldown","ice"],
	"wetwake":["浸润弹芯","Wet wake","主弹命中额外挂水，冷却0.7秒","Primary hits add water; 0.7s target cooldown","water"],
	"firewake":["余烬弹芯","Ember wake","主弹命中额外挂火，冷却0.7秒","Primary hits add fire; 0.7s target cooldown","fire"],
	"reaction_salvage":["反应回收","Reaction salvage","反应补充过载；热冲击留下2秒蒸汽场","Reactions restore overdrive; steam leaves a 2s damage field","chain_reaction"],
	"kill_charge":["击破续航","Kill charge","击破敌人延长火力窗口，最多积累六秒","Kills extend a firing window, capped at six seconds","xp"],
	"crossfire":["交叉齐射","Crossfire","辅助炮从移动展开的双侧阵位发射","Auxiliary fire spreads into mobile flanking positions","wide"],
	"heavy_core":["重炮超容","Heavy capacitor","攻坚重炮命中伤害提高，充能更慢","Stronger siege cannon with a longer charge cycle","damage"],
	"escort_core":["护航火控","Escort control","辅助炮间隔缩短；主炮保持原状","Shorter auxiliary intervals; main weapon unchanged","aux_homing"],
	"assault_core":["过载回路","Overdrive circuit","持续接战进入过载；停止命中后逐渐冷却","Sustained contact enters overdrive; decays out of contact","fire_rate"],
}
static func title(id: String) -> String:
	if preload("res://scripts/run_rules.gd").DATA.has(id): return preload("res://scripts/run_rules.gd").title(id)
	var d: Array=EXTRA.get(id,[])
	if d.is_empty(): return preload("res://scripts/i18n.gd").T("card_"+id)
	return d[0 if preload("res://scripts/i18n.gd").lang()=="zh" else 1]

static func detail(id: String) -> String:
	if preload("res://scripts/run_rules.gd").DATA.has(id): return preload("res://scripts/run_rules.gd").detail(id)
	var d: Array=EXTRA.get(id,[])
	return d[2 if preload("res://scripts/i18n.gd").lang()=="zh" else 3] if not d.is_empty() else ""

static func cards(w) -> Array:
	var result: Array=preload("res://scripts/run_rules.gd").cards(w)
	for key in EXTRA:
		var id: String=key
		result.append({"id":id,"can":func(): return eligible(w,id),"apply":func(): install(w,id)})
	return result

static func eligible(w,id: String) -> bool:
	if id in ["rail","missile","blade","beam","mine","pulse"]: return w.player.weapon!=id
	if id=="heavy_core" and w.player.branch!="siege": return false
	if id in ["escort_core","crossfire"] and w.player.auxiliary=="": return false
	if id.begins_with("aux_"): return preload("res://scripts/upgrades.gd").auxiliary_eligible(w.player,id.trim_prefix("aux_"))
	if id in preload("res://scripts/equipment.gd").MODS:
		if w.player.equipment_focus!="main" and preload("res://scripts/equipment.gd").key(w.player,w.player.equipment_focus)=="aux:": return false
		return not preload("res://scripts/equipment.gd").installed(w.player,w.player.equipment_focus).has(id)
	return not w.player.modules.has(id)

static func install(w,id: String,slot_override:="") -> void:
	if id in ["rail","missile","blade","beam","mine","pulse"]:
		w.player.weapon=id
		return
	if id.begins_with("aux_"):
		preload("res://scripts/upgrades.gd").auxiliary(w,id.trim_prefix("aux_"))
		return
	if id in preload("res://scripts/equipment.gd").MODS:
		preload("res://scripts/equipment.gd").equip(w.player,id,w.player.equipment_focus if slot_override=="" else slot_override)
	else: w.player.modules[id]=true

static func interval(p) -> float:
	var factor: float={"pulse":1.0,"rail":3.8,"missile":2.2,"blade":2.1,"beam":.8,"mine":3.0}.get(p.weapon,1.0)
	return p.fire_cooldown*factor*(.74 if p.overdrive>0 else 1.0)

static func configure(p,b,primary:=true,slot:="main") -> void:
	b.source_player=p
	b.modules=preload("res://scripts/equipment.gd").profile(p,slot)
	b.damage_channel=(p.weapon if primary else "aux_"+(p.auxiliary if slot=="aux1" else p.second_auxiliary))
	b.return_after=.45 if b.modules.has("returning") else -1.0
	b.bounces=1 if b.modules.has("ricochet") else 0
	if not primary: return
	b.catalyst=p.catalyst
	b.catalyst_level=maxi(1,int(p.element_levels.get(p.catalyst,1)))
	if p.modules.has("salvage_return"): b.return_after=.38
	if p.get_tree().current_scene.get("salvage")!=null and p.get_tree().current_scene.salvage.burst_left>0:
		b.damage=roundi(b.damage*1.35)
		if p.weapon=="rail": b.pierce_left+=4
	b.get_node("Mesh").mesh=preload("res://scripts/weapon_projectile.gd").mesh(p.weapon,b.element,p.catalyst)
	b.get_node("Mesh").material_override=preload("res://scripts/weapon_projectile.gd").material(b.element)
	match p.weapon:
		"rail":
			b.damage*=3
			b.pierce_left+=3
			b.speed*=1.25
			b.get_node("Mesh").scale=Vector3(.7,2.0,.7)
		"missile": b.make_homing(); b.speed*=.6
		"blade":
			b.pierce_left+=2
			b.return_after=.55
			b.get_node("Mesh").scale=Vector3(1.7,.55,1)
		"beam": b.pierce_left+=1; b.get_node("Mesh").scale=Vector3(.45,2.8,.45)
		"mine":
			b.damage*=2
			b.speed=85
			b.projectile_role="mine"
			b.modules["blast"]=true
			b.get_node("Mesh").scale=Vector3(1.1,.65,1)

static func hit(b,target,world) -> void:
	var p=b.source_player
	if is_instance_valid(p):
		p.last_contact=0
		p.contact_charge=minf(2.5,p.contact_charge+.055)
		if (p.branch=="assault" or p.modules.has("assault_core")) and p.contact_charge>=2.5:
			p.overdrive=3.5
			p.contact_charge=0
	if b.modules.has("expose"): preload("res://scripts/element_reactions.gd").state(target)["exposed"]=1.5
	# Per-target cooldown also bounds multi-projectile and beam triggers.
	var now: int=roundi(world.run_time*1000)
	if now-int(target.get_meta("arsenal_hit_ms",-1000))<180: return
	target.set_meta("arsenal_hit_ms",now)
	if b.modules.has("blast"):
		for other in preload("res://scripts/element_reactions.gd").nearby(target,100,4):
			preload("res://scripts/element_reactions.gd").hurt(other,maxf(1,b.damage*.4),world)
		preload("res://scripts/precision_fx.gd").pulse(world,target.global_position,Color("ffc282"),35,false,.18,6)
	for id in ["frostwake","wetwake","firewake"]:
		if b.modules.has(id) and now-int(target.get_meta(id,-1000))>=700:
			target.set_meta(id,now)
			var el: String={"frostwake":"ice","wetwake":"water","firewake":"fire"}[id]
			preload("res://scripts/element_reactions.gd").apply(target,el,b.damage,1,b.reaction_boost,b.mark_boost,world)
	if b.modules.has("split") and is_instance_valid(p):
		split.call_deferred(p,b.global_position,b.dir,b.damage,b.element)

static func split(p,pos: Vector3,dir: Vector3,damage: int,element: String) -> void:
	if not is_instance_valid(p) or not p.is_inside_tree(): return
	if p.get_tree().get_nodes_in_group("player_bullets").filter(func(b):return b._active).size()>230: return
	for angle in [-.42,.42]:
		var b=p.new_round()
		b.launch(maxi(1,damage/2),element,.75,0,0,0,1,pos,dir.rotated(Vector3.BACK,angle))
		b.source_player=p
		b.damage_channel="fragment"
