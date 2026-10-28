extends RefCounted
## Read-only previews of the existing upgrade formulas; never invokes an apply callback.
const I18N := preload("res://scripts/i18n.gd")
static func pick(zh: String,en: String) -> String:
	return zh if I18N.lang()=="zh" else en

static func describe(w,id: String,level: int) -> String:
	var p = w.player
	match id:
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
			if level==0: return pick("首次装配：伤害 %d → %d\n溅射半径 90 px","First install: damage %d → %d\nSplash radius 90 px") % [p.damage,p.damage+1]
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
