extends RefCounted
const DATA={
	"salvage_return":["回收弹仓","Return capacitor","主弹返航；接回弹药补充爆发能量","Returning main rounds recharge burst when caught"],
	"jump_arc":["跳跃电流","Jump relay","元素反应向附近两个目标跳跃，衍生伤害不再递归","Reactions jump to two nearby targets without recursion"],
	"shield_clone":["破盾增殖","Shield splitter","击破护盾舰后释放复制齐射，有短冷却","Shield kills release a copied volley with a short cooldown"],
	"tail_battery":["尾流武装","Wake battery","移动积累侧翼齐射，持续穿梭获取覆盖火力","Travel charges lateral volleys"],
	"focus_breach":["集中轰击","Focus breach","连续命中同一目标六次，释放贯穿重击","Six consecutive hits on one target trigger a heavy strike"],
	"graze_core":["临界推进","Graze collector","擦过敌弹获得能量，每颗弹只奖励一次","Grazing a hostile round grants burst energy once"]}
static func title(id: String) -> String:
	return DATA[id][0 if preload("res://scripts/i18n.gd").lang()=="zh" else 1]
static func detail(id: String) -> String:
	return DATA[id][2 if preload("res://scripts/i18n.gd").lang()=="zh" else 3]
static func cards(w) -> Array:
	var result: Array=[]
	for value in DATA:
		var id: String=value
		result.append({"id":id,"can":func():return not w.player.modules.has(id),"apply":func():install(w,id)})
	return result
static func install(w,id: String):
	if id in w.player.rule_slots: return
	if w.player.rule_slots.size()>=2: w.player.modules.erase(w.player.rule_slots.pop_front())
	w.player.rule_slots.append(id)
	w.player.modules[id]=true
