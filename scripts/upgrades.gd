extends Object

# 升级卡池：19 张卡 + 紧急维修兜底（从 world.gd 拆出）
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
	w.pick_element("fire")
	if int(w.player.element_levels.get("fire", 0)) == 1:
		w.player.damage += 1   # 首次选择火焰弹头保留原有的 +1 伤害

static func _wide(w) -> void:
	w.player.spacing_scale = 1.6
	w.player.bullet_count = mini(w.player.bullet_count + 1, 8)

static func _element(w, id: String) -> void:
	w.pick_element(id)

static func _pattern(w, id: String) -> void:
	w.pick_pattern(id)

static func _crit(w) -> void:
	w.player.crit_chance = minf(w.player.crit_chance + 0.10, 0.30)

static func _velocity(w) -> void:
	w.player.proj_speed_mul *= 1.2

static func _chain_reaction(w) -> void:
	w.player.reaction_boost += 0.5

static func _element_last(w) -> void:
	w.player.mark_boost += 1.0

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
		# 元素卡：可叠加至 Lv.3（再选同元素升级效果），选其他元素随时切换且各元素等级独立保留
		{"id": "fire", "can": func(): return int(player.element_levels.get("fire", 0)) < 3,
			"apply": func(): _fire(w),
			"lv_fn": func(): return int(player.element_levels.get("fire", 0)),
			"hint_fn": func(): return "" if player.element == "fire" else "switch_el"},
		{"id": "water", "can": func(): return int(player.element_levels.get("water", 0)) < 3,
			"apply": func(): _element(w, "water"),
			"lv_fn": func(): return int(player.element_levels.get("water", 0)),
			"hint_fn": func(): return "" if player.element == "water" else "switch_el"},
		{"id": "ice", "can": func(): return int(player.element_levels.get("ice", 0)) < 3,
			"apply": func(): _element(w, "ice"),
			"lv_fn": func(): return int(player.element_levels.get("ice", 0)),
			"hint_fn": func(): return "" if player.element == "ice" else "switch_el"},
		{"id": "lightning", "can": func(): return int(player.element_levels.get("lightning", 0)) < 3,
			"apply": func(): _element(w, "lightning"),
			"lv_fn": func(): return int(player.element_levels.get("lightning", 0)),
			"hint_fn": func(): return "" if player.element == "lightning" else "switch_el"},
		{"id": "wind", "can": func(): return int(player.element_levels.get("wind", 0)) < 3,
			"apply": func(): _element(w, "wind"),
			"lv_fn": func(): return int(player.element_levels.get("wind", 0)),
			"hint_fn": func(): return "" if player.element == "wind" else "switch_el"},
		# 特殊弹道卡：波浪（追踪弹已改为 Boss 掉落道具）
		{"id": "wave", "can": func(): return int(player.pattern_levels.get("wave", 0)) < 3,
			"apply": func(): _pattern(w, "wave"),
			"lv_fn": func(): return int(player.pattern_levels.get("wave", 0)),
			"hint_fn": func(): return "" if player.pattern == "wave" else "switch_pt"},
		# 组合卡：围绕暴击与元素反应构筑流派
		{"id": "crit", "can": func(): return int(w.card_taken.get("crit", 0)) < 3,
			"apply": func(): _crit(w)},
		{"id": "velocity", "can": func(): return int(w.card_taken.get("velocity", 0)) < 3,
			"apply": func(): _velocity(w)},
		{"id": "chain_reaction", "can": func(): return int(w.card_taken.get("chain_reaction", 0)) < 2,
			"apply": func(): _chain_reaction(w)},
		{"id": "element_last", "can": func(): return int(w.card_taken.get("element_last", 0)) < 2,
			"apply": func(): _element_last(w)},
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
