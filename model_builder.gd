extends Object
## 程序化 3D 模型工厂：所有战机 / Boss / 物件由基础图元拼装（无外部模型文件）
## 坐标约定：模型机头朝 -Y（屏幕上方），厚度在 Z 轴

# ---------- 材质 ----------

static func mat(color: Color, metallic := 0.35) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = 0.45
	return m

static func glow_mat(color: Color, energy := 2.2) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m

static func part(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi

static func box(parent: Node3D, material: Material, size: Vector3, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	return part(parent, bm, material, pos, rot)

static func cyl(parent: Node3D, material: Material, r_top: float, r_bottom: float, height: float, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bottom
	cm.height = height
	return part(parent, cm, material, pos, rot)

static func sphere(parent: Node3D, material: Material, radius: float, pos: Vector3, scl := Vector3.ONE) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	var mi := part(parent, sm, material, pos)
	mi.scale = scl
	return mi

# ---------- 主角：20 形态（与原 2D 版同一套成长参数） ----------

const TIER_TOPS := [Color(0.75, 0.92, 1.0), Color(0.72, 0.93, 0.98), Color(0.78, 0.95, 0.88), Color(1.0, 0.88, 0.78), Color(0.98, 0.85, 0.98)]
const TIER_BOTS := [Color(0.12, 0.55, 0.85), Color(0.08, 0.47, 0.75), Color(0.06, 0.49, 0.43), Color(0.78, 0.24, 0.16), Color(0.59, 0.24, 0.78)]
const ACCENTS := [Color(0.35, 0.88, 1.0), Color(0.55, 1.0, 0.82), Color(0.43, 1.0, 0.71), Color(1.0, 0.75, 0.31), Color(1.0, 0.47, 0.47), Color(0.51, 0.55, 1.0), Color(1.0, 0.86, 0.43), Color(0.96, 0.96, 1.0)]

static func build_player_form(n: int) -> Node3D:
	var root := Node3D.new()
	root.rotation_degrees = Vector3(-8, 0, 0)  # 微仰角：露出机身顶面，强化立体感
	var tier := n / 4
	var k := n % 4
	var span := 30.0 + n * 2.4
	var hw := 7.0 + n * 0.32
	var engines := 1 + tier + (1 if k >= 2 else 0)
	var pods := n >= 4
	var barrels := n >= 8
	var armor := n >= 12
	var accent: Color = ACCENTS[n % ACCENTS.size()]
	var body := mat(TIER_BOTS[tier].lerp(TIER_TOPS[tier], 0.45), 0.5)
	var dark := mat(TIER_BOTS[tier].darkened(0.35))
	var hull_len := 120.0 + tier * 8.0
	var wing_y := -46.0 + tier * 3.0
	var drop := 14.0 + tier * 6.0 + k * 3.0
	var chord := 26.0 + tier * 3.0
	var wing := mini(tier, 5)
	var sweep: float = [12.0, 30.0, -22.0, 18.0, -8.0][wing]

	# 机身：锥形圆柱（尾部粗）+ 机鼻锥（头部尖）
	cyl(root, body, hw * 1.1, hw * 0.5, hull_len, Vector3(0, -(8 + hull_len * 0.5), 0))
	cyl(root, body, hw * 0.5, 0.05, 16.0, Vector3(0, -(8 + hull_len + 8), 0))
	# 座舱（发光）
	sphere(root, glow_mat(Color(0.55, 0.9, 1.0), 1.6), hw * 0.5, Vector3(0, -(hull_len * 0.45), hw * 0.25), Vector3(1.0, 1.6, 0.7))

	# 机翼：左右镜像，翼型随梯队变化
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(side * hw * 0.9, wing_y, 0)
		pivot.rotation_degrees = Vector3(0, 0, -side * sweep)
		root.add_child(pivot)
		match wing:
			0:  # 三角翼
				box(pivot, body, Vector3(span, chord, 5), Vector3(side * span * 0.5, drop * 0.5, 0))
			1:  # 后掠翼
				box(pivot, body, Vector3(span, chord * 0.8, 5), Vector3(side * span * 0.5, drop * 0.6, 0))
			2:  # 前掠翼
				box(pivot, body, Vector3(span, chord * 0.8, 5), Vector3(side * span * 0.5, -drop * 0.5, 0))
			3:  # X 翼（两对）
				box(pivot, body, Vector3(span, chord * 0.7, 5), Vector3(side * span * 0.5, drop * 0.4, 6))
				box(pivot, dark, Vector3(span * 0.7, chord * 0.6, 5), Vector3(side * span * 0.45, drop * 0.1, -6))
			4:  # 前伸双叉
				box(pivot, body, Vector3(span, 10.0, 5), Vector3(side * span * 0.5, drop * 0.2, 0))
				box(pivot, dark, Vector3(span * 0.6, 12.0, 5), Vector3(side * span * 0.42, drop * 0.75, 0))
			5:  # 双层翼
				box(pivot, body, Vector3(span, chord * 0.7, 5), Vector3(side * span * 0.5, drop * 0.4, 7))
				box(pivot, dark, Vector3(span * 0.85, chord * 0.7, 5), Vector3(side * span * 0.45, drop * 0.5, -6))
		# 翼尖发光条
		box(pivot, glow_mat(accent, 1.8), Vector3(4, 6, 6), Vector3(side * span, drop * 0.5, 0))
		# 翼上挂舱 / 炮管
		if pods:
			cyl(pivot, dark, 3.0, 3.0, 16.0, Vector3(side * span * 0.68, drop * 0.45, 0), Vector3(0, 0, 90))
		if barrels:
			cyl(pivot, dark, 1.6, 1.6, 20.0, Vector3(side * span * 0.8, drop * 0.3, 0))

	# 尾翼
	for side in [-1.0, 1.0]:
		box(root, dark, Vector3(4, 16, 4), Vector3(side * (hw + 4), -(8 + hull_len) + 10, 0), Vector3(0, side * 25, side * 15))
	# 引擎喷口 + 尾焰发光
	var rear_y := -(8 + hull_len) + 4
	for i in engines:
		var ex := (i - (engines - 1) / 2.0) * 9.0
		cyl(root, dark, 3.4, 3.4, 12.0, Vector3(ex, rear_y, 0))
		cyl(root, glow_mat(accent, 2.4), 2.6, 2.6, 1.6, Vector3(ex, rear_y + 7, 0))
	# 装甲带 / 机鼻双侧炮
	if armor:
		box(root, dark, Vector3(hw * 2.2, 14, hw * 1.6 + 4), Vector3(0, -70, 0))
	if barrels:
		for side in [-1.0, 1.0]:
			cyl(root, dark, 1.4, 1.4, 26.0, Vector3(side * (hw + 3), -(hull_len * 0.5), 0))
	return root


# ---------- 敌机（6 种，机头朝 -Y，运行时滚转朝向玩家） ----------

const ENEMY_LOOK := {
	"normal": {"len": 50.0, "hw": 11.0, "span": 26.0, "sweep": 28.0, "color": Color(1.0, 0.32, 0.42)},
	"fast": {"len": 56.0, "hw": 9.0, "span": 32.0, "sweep": 36.0, "color": Color(1.0, 0.6, 0.25)},
	"swift": {"len": 42.0, "hw": 7.0, "span": 20.0, "sweep": 32.0, "color": Color(0.72, 1.0, 0.4)},
	"shooter": {"len": 46.0, "hw": 12.0, "span": 22.0, "sweep": 22.0, "color": Color(0.6, 0.76, 1.0), "gun": true},
	"shield": {"len": 44.0, "hw": 15.0, "span": 24.0, "sweep": 20.0, "color": Color(0.85, 0.9, 0.98)},
	"tank": {"len": 58.0, "hw": 17.0, "span": 38.0, "sweep": 26.0, "color": Color(0.68, 0.4, 1.0)},
}

static func build_enemy(kind: String) -> Node3D:
	var d: Dictionary = ENEMY_LOOK[kind]
	var root := Node3D.new()
	root.rotation_degrees = Vector3(-8, 0, 0)
	var col: Color = d["color"]
	var body := mat(col.darkened(0.15), 0.45)
	var dark := mat(col.darkened(0.5))
	var accent := glow_mat(col.lightened(0.25), 1.8)
	var hw: float = d["hw"]
	var len: float = d["len"]

	cyl(root, body, hw * 0.9, hw * 0.45, len, Vector3(0, -6, 0))
	cyl(root, body, hw * 0.45, 0.05, 14.0, Vector3(0, -6 - len * 0.5 - 7, 0))
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(side * hw * 0.7, 2.0, 0)
		pivot.rotation_degrees = Vector3(0, 0, -side * d["sweep"])
		root.add_child(pivot)
		box(pivot, body, Vector3(d["span"], 16.0, 4), Vector3(side * d["span"] * 0.5, 8.0, 0))
		box(pivot, glow_mat(col.lightened(0.3), 1.5), Vector3(3.5, 5, 5), Vector3(side * d["span"], 8.0, 0))
	sphere(root, mat(Color(0.08, 0.08, 0.16)), hw * 0.4, Vector3(0, -2, hw * 0.3), Vector3(1.0, 1.5, 0.7))
	cyl(root, accent, 3.0, 3.0, 1.5, Vector3(0, len * 0.5 - 1, 0))
	if d.get("gun", false):
		for side in [-1.0, 1.0]:
			cyl(root, dark, 1.5, 1.5, 18.0, Vector3(side * 5.0, -len * 0.5 - 6, 0))
	return root


# ---------- BOSS（5 种，机头朝 +Y 即屏幕下方，直接面对玩家） ----------

static func build_boss(id: int) -> Node3D:
	var root := Node3D.new()
	root.rotation_degrees = Vector3(8, 0, 0)
	match id:
		1:  # 毁灭者：红色三舰体战列舰
			var red := mat(Color(0.85, 0.25, 0.3), 0.5)
			var dark := mat(Color(0.45, 0.08, 0.15))
			box(root, red, Vector3(64, 150, 26), Vector3(0, 0, 0))
			box(root, red, Vector3(46, 120, 22), Vector3(-84, -10, 0))
			box(root, red, Vector3(46, 120, 22), Vector3(84, -10, 0))
			box(root, dark, Vector3(40, 40, 30), Vector3(0, -60, 0))
			sphere(root, mat(Color(0.1, 0.1, 0.2)), 10, Vector3(0, -30, 14), Vector3(1.2, 1.6, 0.7))
			for x in [-62.0, 62.0]:
				cyl(root, dark, 11, 13, 12, Vector3(x, 60, 6))
				cyl(root, glow_mat(Color(1, 0.4, 0.4), 2.0), 6, 6, 3, Vector3(x, 60, 13))
			for x in [-30.0, 30.0, -100.0, 100.0]:
				cyl(root, glow_mat(Color(1, 0.45, 0.45), 2.2), 6, 6, 2, Vector3(x, -78, 0))
		2:  # 拦截者：紫色双叉隐形巡洋舰
			var body := mat(Color(0.5, 0.3, 0.85), 0.55)
			var dark := mat(Color(0.25, 0.12, 0.45))
			var accent := glow_mat(Color(0.7, 0.45, 1.0), 2.0)
			box(root, body, Vector3(70, 150, 22), Vector3(0, -10, 0), Vector3(0, 0, 45))
			for side in [-1.0, 1.0]:
				box(root, body, Vector3(26, 120, 18), Vector3(side * 52, -60, 0), Vector3(0, 0, side * -18))
				box(root, dark, Vector3(30, 70, 16), Vector3(side * 95, 20, 0))
				cyl(root, accent, 4, 4, 2, Vector3(side * 40, -110, 0))
			sphere(root, glow_mat(Color(0.85, 0.6, 1.0), 2.2), 8, Vector3(0, -70, 12), Vector3(1.2, 1.8, 0.7))
			for x in [-35.0, 35.0]:
				cyl(root, accent, 5, 5, 2, Vector3(x, -95, 0))
		3:  # 要塞：青绿巨型航母 + 三炮塔
			var body := mat(Color(0.16, 0.62, 0.55), 0.45)
			var dark := mat(Color(0.05, 0.32, 0.28))
			box(root, body, Vector3(230, 90, 26), Vector3(0, 30, 0))
			box(root, body, Vector3(80, 90, 22), Vector3(0, -40, 0))
			box(root, dark, Vector3(60, 40, 24), Vector3(0, -20, 20))
			for x in [-72.0, 72.0, 0.0]:
				var ty := 55.0 if x == 0.0 else 42.0
				cyl(root, dark, 12, 14, 12, Vector3(x, ty, 8))
				cyl(root, glow_mat(Color(0.4, 1.0, 0.85), 2.0), 6, 6, 3, Vector3(x, ty, 15))
			for x in [-100.0, 100.0, -40.0, 40.0]:
				cyl(root, glow_mat(Color(0.4, 1.0, 0.85), 2.0), 5, 5, 2, Vector3(x, -78, 0))
		4:  # 猎手：金色双爪追猎舰
			var body := mat(Color(0.9, 0.68, 0.2), 0.5)
			var dark := mat(Color(0.45, 0.28, 0.05))
			box(root, body, Vector3(60, 140, 22), Vector3(0, -10, 0), Vector3(0, 0, 45))
			for side in [-1.0, 1.0]:
				box(root, body, Vector3(30, 110, 18), Vector3(side * 62, -40, 0), Vector3(0, 0, side * 24))
				box(root, dark, Vector3(22, 60, 16), Vector3(side * 95, 30, 0), Vector3(0, 0, side * -30))
			sphere(root, glow_mat(Color(1.0, 0.85, 0.4), 2.2), 9, Vector3(0, -60, 12), Vector3(1.2, 1.6, 0.7))
			for x in [-32.0, 32.0]:
				cyl(root, glow_mat(Color(1.0, 0.8, 0.35), 2.2), 5, 5, 2, Vector3(x, -95, 0))
		5:  # 幻影：蓝白水晶幽灵舰
			var body := mat(Color(0.6, 0.75, 1.0), 0.3)
			var dark := mat(Color(0.2, 0.35, 0.7))
			var core := glow_mat(Color(0.75, 0.9, 1.0), 2.4)
			box(root, body, Vector3(70, 150, 20), Vector3(0, 0, 0), Vector3(0, 0, 45))
			box(root, body, Vector3(60, 120, 18), Vector3(0, 0, 8), Vector3(0, 0, -45))
			for side in [-1.0, 1.0]:
				box(root, dark, Vector3(34, 80, 14), Vector3(side * 78, -30, 0), Vector3(0, 0, side * -20))
			sphere(root, core, 7, Vector3(0, 0, 14), Vector3(1.0, 1.5, 0.6))
			for x in [-28.0, 28.0]:
				cyl(root, glow_mat(Color(0.75, 0.9, 1.0), 2.0), 5, 5, 2, Vector3(x, -85, 0))
	return root


# ---------- 物件 ----------

static func build_gem() -> Node3D:
	# 旋转的水晶方块（父节点负责旋转动画）
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(13, 13, 9)
	mi.mesh = bm
	mi.rotation_degrees = Vector3(0, 0, 45)
	mi.material_override = glow_mat(Color(0.45, 0.9, 1.0), 2.4)
	root.add_child(mi)
	return root


static func build_core() -> Node3D:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(24, 24, 12)
	mi.mesh = bm
	mi.rotation_degrees = Vector3(0, 0, 45)
	mi.material_override = glow_mat(Color(1.0, 0.82, 0.3), 2.6)
	root.add_child(mi)
	sphere(root, glow_mat(Color(0.7, 0.98, 1.0), 3.0), 6, Vector3(0, 0, 7))
	return root
