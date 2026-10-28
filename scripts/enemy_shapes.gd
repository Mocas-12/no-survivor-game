extends RefCounted
## Six role silhouettes and six independent capital architectures; local nose is +Y.
static func polygon(m, coords: Array, z: float, h: float, slot: int) -> void:
	var points := PackedVector2Array()
	for i in range(0,coords.size(),2):
		points.append(Vector2(coords[i],coords[i+1]))
	m.plate(points,z,h,slot)

static func eye(m,x: float,y: float,r: float) -> void:
	m.disk(x,y,r+3,8,0)
	m.disk(x,y,r+1,11,2)
	m.disk(x,y,r*0.62,14,4)
	m.disk(x,y,r*0.22,17,5)

static func drone(m,n: int) -> void:
	match n:
		0: # Batwing: no shared arrow body.
			polygon(m,[-6,24,7,24,16,-20,-16,-20],3,6,0)
			for s in [-1,1]:
				polygon(m,[s*5,18,s*38,4,s*48,-25,s*20,-13,s*7,-19],4,4,1)
				polygon(m,[s*14,10,s*34,1,s*39,-14,s*20,-6],9,2,2)
				m.nacelle(s*15,-21,0.65)
			eye(m,0,7,4)
		1: # Needle: slender spine, exposed orange fins.
			polygon(m,[0,46,6,15,5,-38,-5,-38,-6,15],3,5,2)
			polygon(m,[0,42,3,9,3,-25,-3,-25,-3,9],10,3,1)
			for s in [-1,1]:
				polygon(m,[s*6,15,s*12,-21,s*10,-34,s*5,-19],1,3,1)
				m.box(s*7,-18,2,22,7,4)
			m.nacelle(0,-28,0.7)
			eye(m,0,5,2.5)
		2: # Three separate turbine blades around a central eye.
			m.ring(14,4,3,0)
			for i in 3:
				var a: float = TAU*i/3
				var pts := PackedVector2Array()
				for p in [Vector2(-5,12),Vector2(5,12),Vector2(8,30),Vector2(0,43),Vector2(-8,30)]:
					pts.append(p.rotated(a))
				m.plate(pts,4,5,1)
				var v := Vector2(0,27).rotated(a)
				m.disk(v.x,v.y,3,10,2)
			eye(m,0,0,7)
		3: # Broad gunboat, two weapon pods and thick bridge.
			m.box(0,-3,33,44,3,2)
			m.box(0,0,24,36,7,1)
			for s in [-1,1]:
				m.box(s*26,-7,16,39,3,1)
				m.gun(s*25,6,0.8)
				m.nacelle(s*25,-24,0.65)
			m.box(0,7,12,17,12,3)
			m.box(0,11,7,3,17,4)
		4: # Shield hull: semicircle dominates the silhouette.
			m.ring(39,12,5,1,0,PI)
			m.ring(37,2,10,4,0.08,PI-0.16)
			m.ring(26,2,6,2,0,PI)
			polygon(m,[-8,12,8,12,6,-24,0,-33,-6,-24],1,5,2)
			for s in [-1,1]:
				m.box(s*19,6,3,9,11,0)
				m.nacelle(s*8,-18,0.5)
			eye(m,0,0,4)
		5: # Siege block: four separate propulsion blocks and recessed body.
			m.box(0,0,36,54,2,0)
			m.box(0,0,27,46,6,1)
			for s in [-1,1]:
				for y in [-22,22]:
					m.nacelle(s*26,y,0.8)
				m.box(s*11,2,4,36,11,2)
			m.gun(0,14,0.85)
			eye(m,0,-13,5)
	# All families retain small warm status hardware without sharing a complete hull.
	m.box(0,-8,2,3,19,5)

static func boss(m,n: int) -> void:
	match n:
		1: # Horizontal artillery hammerhead.
			m.box(0,0,38,76,2,0)
			m.box(0,0,29,66,7,1)
			for s in [-1,1]:
				polygon(m,[s*12,28,s*60,25,s*66,10,s*61,-24,s*16,-28],3,7,1)
				for y in [-17,17]:
					m.disk(s*41,y,13,11,2)
					m.disk(s*41,y,10,14,0)
					m.armor_panel(s*23,y,13,19,12)
				m.nacelle(s*16,-32,0.9)
			m.box(0,20,14,24,15,2)
			eye(m,0,-8,8)
		2: # Split blade: long hollow center, pointed independent jaws.
			m.box(0,-32,46,21,1,0)
			for s in [-1,1]:
				polygon(m,[s*21,-40,s*36,-15,s*26,33,s*9,65,s*15,12,s*13,-24],3,7,1)
				polygon(m,[s*20,-22,s*29,-10,s*20,30,s*16,20],11,4,2)
				m.box(s*18,4,2,23,17,4)
				m.nacelle(s*23,-31,0.9)
			eye(m,0,-26,7)
		3: # Six floating hexagonal armor blocks, not a fighter fuselage.
			m.ring(27,3,2,2)
			eye(m,0,0,13)
		4: # Asymmetric spear gun on one side, short sensor wing on the other.
			polygon(m,[-12,33,10,25,17,-26,5,-42,-15,-33],4,7,1)
			m.box(-24,3,18,101,4,0)
			m.box(-24,7,11,89,9,2)
			m.box(-24,24,3,50,15,4)
			polygon(m,[-30,45,-24,69,-18,45],10,4,2)
			polygon(m,[11,19,38,9,53,-10,31,-4,17,-15],2,5,1)
			m.disk(34,3,10,10,2)
			eye(m,34,3,5)
			m.nacelle(-4,-30,1.15)
			m.armor_panel(3,6,15,26,13)
		5: # Ghost crescent: crystalline arms, narrow bridges, detached side pods.
			polygon(m,[0,23,10,3,8,-19,0,-30,-8,-19,-10,3],5,8,2)
			for s in [-1,1]:
				polygon(m,[s*9,-7,s*28,-5,s*25,-11,s*10,-13],0,2,2)
				polygon(m,[s*13,-19,s*32,-12,s*43,10,s*40,34,s*29,55,s*32,17,s*19,-5],3,5,3)
				m.nacelle(s*49,-8,0.9)
				m.box(s*37,12,2,20,12,4)
			eye(m,0,0,7)
		6: # Annular mothership with multiple decks, no arrow body.
			m.ring(60,13,0,0)
			m.ring(57,7,5,1)
			m.ring(41,5,9,2)
			m.ring(37,2,12,4)
			for i in 6:
				var a: float = TAU*i/6
				var p := Vector2.from_angle(a)*48
				m.box(p.x,p.y,18,25,11,1)
				m.armor_panel(p.x,p.y,12,16,16)
				var q := Vector2.from_angle(a)*24
				m.box(q.x,q.y,9,12,4,2)
			eye(m,0,0,15)
	# Small contrast details and socket geometry are scaled to actual combat readability.
	m.box(0,0,2,3,22,5)
