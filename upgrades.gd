extends Object

# 升级卡池：15 张卡 + 紧急维修兜底（从 world.gd 拆出）
# 每张卡：id（对应 i18n 的 card_<id> / card_<id>_d）、can（能否出现）、apply（选中效果）
# 可重复选取的卡由 world.card_taken 计数，显示 "Lv.N"
# 注意：多语句效果一律走静态辅助函数，避免字典内多行 lambda 的解析坑

# 兜底卡：卡池枯竭时补位（威力/疾跑/装甲全满的超后期）
static func _repair(w) -> void:
	w.health = mini(w.health + 6, w.max_health)

static func repair_card(w) -> Dictionary:
	return {"id": "repair", "can": func(): return true, "apply": func(): _repair(w)}

static func _armor(w) -> void:
	w.max_health += 2
	w.health = mini(w.health + 4, w.max_health)

static func _fire(w) -> void:
	w.player.element = "fire"
	w.player.damage += 1

static func _wide(w) -> void:
	w.player.spacing_scale = 1.6
	w.player.bullet_count = mini(w.player.bullet_count + 1, 8)

static func build(w) -> Array:
	var player = w.player
	return [
		{"id": "fire_rate", "can": func(): return player.fire_cooldown > 0.06,
			"apply": func(): player.fire_cooldown = maxf(0.055, player.fire_cooldown * 0.8)},
		{"id": "damage", "can": func(): return true,
			"apply": func(): player.damage += 1},
		{"id": "multishot", "can": func(): return player.bullet_count < 7,
			"apply": func(): player.bullet_count = mini(player.bullet_count + 1, 8)},
		{"id": "speed", "can": func(): return int(w.card_taken.get("speed", 0)) < 5,
			"apply": func(): player.speed = int(player.speed * 1.12)},
		{"id": "armor", "can": func(): return true,
			"apply": func(): _armor(w)},
		# 元素承诺制：选定一种元素后不再出现其他元素卡（防止随机池把流派覆盖掉）
		{"id": "fire", "can": func(): return player.element == "normal",
			"apply": func(): _fire(w)},
		{"id": "ice", "can": func(): return player.element == "normal",
			"apply": func(): player.element = "ice"},
		{"id": "lightning", "can": func(): return player.element == "normal",
			"apply": func(): player.element = "lightning"},
		{"id": "wind", "can": func(): return player.element == "normal",
			"apply": func(): player.element = "wind"},
		# 弹道承诺制：追踪 / 波浪互斥，只在基础扇形弹上选择
		{"id": "homing", "can": func(): return player.pattern == "spread",
			"apply": func(): player.pattern = "homing"},
		{"id": "wave", "can": func(): return player.pattern == "spread",
			"apply": func(): player.pattern = "wave"},
		{"id": "wide", "can": func(): return player.spacing_scale < 1.6 and player.pattern != "homing",
			"apply": func(): _wide(w)},
		# 被动系新卡
		{"id": "magnet", "can": func(): return int(w.card_taken.get("magnet", 0)) < 3,
			"apply": func(): w.magnet_range_mul *= 1.35},
		{"id": "xp", "can": func(): return int(w.card_taken.get("xp", 0)) < 3,
			"apply": func(): w.xp_mul += 0.15},
		{"id": "revive", "can": func(): return w.revive_charges == 0,
			"apply": func(): w.revive_charges += 1},
	]
