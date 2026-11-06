extends RefCounted
## Read-only previews of the existing upgrade formulas; never invokes an apply callback.
const I18N := preload("res://scripts/i18n.gd")
static func pick(zh: String,en: String) -> String:
	return zh if I18N.lang()=="zh" else en

static func describe(w,id: String,level: int) -> String:
	if id.begins_with("aux_"): return auxiliary_preview(w,id)
	if preload("res://scripts/arsenal.gd").EXTRA.has(id):
		var extra: String=preload("res://scripts/arsenal.gd").detail(id)
		if id in preload("res://scripts/equipment.gd").MODS: extra=preload("res://scripts/equipment.gd").preview(w.player,id)+"\n"+extra
		return extra
	var p = w.player
	match id:
		"pierce": return pick("贯穿额外目标 %d → %d","Additional targets pierced %d → %d") % [p.pierce_level,p.pierce_level+1]
		"aux_water", "aux_ice", "aux_homing":
			var level_next: int=mini(p.auxiliary_level+1,3) if p.auxiliary==id.trim_prefix("aux_") else 1
			return pick("独立辅助炮 Lv.%d · 不替换主炮\n自动追踪 · 单独装配", "Auxiliary Lv.%d · keeps main cannon\nAuto-targeted · separate slot") % level_next
		"fire_rate": return pick("基础间隔 %d → %d ms","Base interval %d → %d ms") % [roundi(p.fire_cooldown*1000),roundi(maxf(0.055,p.fire_cooldown*0.8)*1000)]
		"damage": return pick("子弹伤害 %d → %d","Shot damage %d → %d") % [p.damage,p.damage+1]
		"multishot": return pick("齐射弹道 %d → %d","Projectiles %d → %d") % [p.bullet_count,mini(p.bullet_count+1,8)]
		"speed": return pick("基础移速 %d → %d","Base speed %d → %d") % [p.speed,int(p.speed*1.12)]
		"armor": return pick("生命上限 %d → %d\n修复最多 4 点装甲","Max armor %d → %d\nRepair up to 4 armor") % [w.max_health,w.max_health+2]
		"velocity": return pick("基础弹速倍率 %.2f → %.2f","Base shot speed ×%.2f → ×%.2f") % [p.proj_speed_mul,p.proj_speed_mul*1.2]
		"crit": return pick("暴击率 %d%% → %d%%\n暴击造成双倍伤害","Critical chance %d%% → %d%%\nCritical hits deal double damage") % [roundi(p.crit_chance*100),roundi(minf(p.crit_chance+0.1,0.3)*100)]
		"wide": return pick("齐射弹道 %d → %d\n展开扇形炮口","Projectiles %d → %d\nOpen a wider firing arc") % [p.bullet_count,mini(p.bullet_count+1,8)]
		"magnet": return pick("磁吸范围倍率 %.2f → %.2f","Pickup range ×%.2f → ×%.2f") % [w.magnet_range_mul,w.magnet_range_mul*1.35]
		"xp": return pick("经验倍率 %.2f → %.2f","Experience ×%.2f → ×%.2f") % [w.xp_mul,w.xp_mul+0.15]
		"chain_reaction": return pick("反应伤害倍率 %.2f → %.2f","Reaction damage ×%.2f → ×%.2f") % [p.reaction_boost,p.reaction_boost+0.5]
		"element_last": return pick("标记时长倍率 %.1f → %.1f","Mark duration ×%.1f → ×%.1f") % [p.mark_boost,p.mark_boost+1]
		"fire":
			if level==0 and p.element_levels.values().all(func(lv):return int(lv)==0): return pick("首次装配：伤害 %d → %d\n溅射半径 90 px","First install: damage %d → %d\nSplash radius 90 px") % [p.damage,p.damage+1]
			if level==0: return pick("装配火焰弹头\n溅射半径 90 px","Install fire warhead\nSplash radius 90 px")
			return pick("溅射半径 %d → %d px","Splash radius %d → %d px") % [90+30*(level-1),90+30*level]
		"water": return pick("浸润 %.1f 秒 · 水流击退\n可与火、冰、雷联动","Wet for %.1fs · Push on impact\nCombines with fire, ice and lightning") % ((1.6+0.5*level)*p.mark_boost)
		"ice": return pick("减速 %d%% · 持续 %.1f 秒","Slow %d%% for %.1fs") % [roundi(minf(0.45+0.1*level,0.85)*100),1.6+0.4*level]
		"lightning": return pick("电链最多 %d 个邻近目标\n浸润目标可额外传导","Chain to %d nearby targets\nWet targets extend conduction") % mini(2+level,5)
		"wind": return pick("弹速 +40%% · 聚拢敌群\n聚拢半径 %d px","Shot speed +40%% · Pull foes\nPull radius %d px") % (150+20*(level+1))
		"wave":
			if level==0: return pick("切换为波浪弹道\n基础波幅 220","Switch to a waving trajectory\nBase amplitude 220")
			return pick("基础波幅 %d → %d","Base amplitude %d → %d") % [220+80*(level-1),220+80*level]
		"revive": return pick("补充 1 次凤凰复活\n复活时释放清场冲击波","Restore one phoenix charge\nRelease a shockwave on revival")
		"repair": return pick("装甲 %d → %d\n立即生效","Armor %d → %d\nImmediate repair") % [w.health,mini(w.health+6,w.max_health)]
	return I18N.T("card_"+id+"_d")

static func auxiliary_preview(w,id: String) -> String:
	var slot: String=id.trim_prefix("aux_")
	var p=w.player
	if p.auxiliary==slot: return pick("强化辅助 Lv.%d → %d · 保留另一辅助","Upgrade auxiliary Lv.%d → %d · keep other slot") % [p.auxiliary_level,mini(3,p.auxiliary_level+1)]
	if p.second_auxiliary==slot: return pick("强化辅助 Lv.%d → %d · 保留另一辅助","Upgrade auxiliary Lv.%d → %d · keep other slot") % [p.second_auxiliary_level,mini(3,p.second_auxiliary_level+1)]
	if p.auxiliary!="" and p.second_auxiliary!="": return pick("替换：%s\n主炮与另一辅助保留","Replaces: %s\nKeep main weapon and other auxiliary") % preload("res://scripts/arsenal.gd").title("aux_"+p.second_auxiliary)
	return pick("装入空闲辅助槽 · 不替换主炮\n自动追踪，独立挂元素","Install in empty auxiliary slot\nAuto-target and independently apply elements")
