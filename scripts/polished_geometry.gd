extends RefCounted
## Closed flat panels, rounded bevel bands and analytic curve normals. XY footprints are preserved.

static func emit(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,na: Vector3,nb: Vector3,nc: Vector3) -> void:
	if (b-a).cross(c-a).length_squared()<0.00000001: return
	if (c-a).cross(b-a).dot(na+nb+nc)<0:
		var p:=b
		b=c
		c=p
		var n:=nb
		nb=nc
		nc=n
	for pair in [[a,na],[b,nb],[c,nc]]:
		var v: Vector3=pair[0]
		st.set_uv(Vector2(v.x/140.0+0.5,v.y/140.0+0.5))
		st.set_normal(pair[1])
		st.add_vertex(v)

static func face(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,n: Vector3) -> void:
	emit(st,a,b,c,n,n,n)

static func cw(points: PackedVector2Array) -> PackedVector2Array:
	var result:=points.duplicate()
	if not Geometry2D.is_polygon_clockwise(result): result.reverse()
	return result

static func cap(st: SurfaceTool,points: PackedVector2Array,z: float,n: Vector3) -> void:
	var indices:=Geometry2D.triangulate_polygon(points)
	for i in range(0,indices.size(),3):
		var a:=points[indices[i]]
		var b:=points[indices[i+1]]
		var c:=points[indices[i+2]]
		face(st,Vector3(a.x,a.y,z),Vector3(b.x,b.y,z),Vector3(c.x,c.y,z),n)

static func plate(surfaces: Array[SurfaceTool],points: PackedVector2Array,z: float,h: float,slot: int) -> void:
	var outer:=cw(points)
	var bounds:=Rect2(outer[0],Vector2.ZERO)
	for p in outer: bounds=bounds.expand(p)
	var bevel:=minf(0.85,minf(bounds.size.x,bounds.size.y)*0.12)
	bevel=minf(bevel,maxf(0.15,(h+4)*0.22))
	var inner:=outer.duplicate()
	var offsets:=Geometry2D.offset_polygon(outer,-bevel,Geometry2D.JOIN_MITER)
	if offsets.size()==1 and offsets[0].size()==outer.size():
		var candidate:=cw(offsets[0])
		var best_shift:=0
		var best_cost:=INF
		for shift in outer.size():
			var cost:=0.0
			for i in outer.size(): cost+=outer[i].distance_squared_to(candidate[(i+shift)%outer.size()])
			if cost<best_cost:
				best_cost=cost
				best_shift=shift
		for i in outer.size(): inner[i]=candidate[(i+best_shift)%outer.size()]
	else:
		# Narrow concave fins keep their exact outline instead of risking inverted inset geometry.
		bevel=0.0
	var top:=z+h
	var bottom:=z-4
	cap(surfaces[slot],inner,top,Vector3.BACK)
	cap(surfaces[slot],outer,bottom,Vector3.FORWARD)
	for i in outer.size():
		var j: int=(i+1)%outer.size()
		var a:=outer[i]
		var b:=outer[j]
		var edge:=b-a
		var normal:=Vector3(-edge.y,edge.x,0).normalized()
		var low_a:=Vector3(a.x,a.y,bottom)
		var low_b:=Vector3(b.x,b.y,bottom)
		var rim_a:=Vector3(a.x,a.y,top-bevel)
		var rim_b:=Vector3(b.x,b.y,top-bevel)
		face(surfaces[slot],low_a,low_b,rim_b,normal)
		face(surfaces[slot],low_a,rim_b,rim_a,normal)
		if bevel<=0: continue
		for k in 2:
			var t0: float=k*PI/4
			var t1: float=(k+1)*PI/4
			var pa:=a.lerp(inner[i],1-cos(t0))
			var pb:=b.lerp(inner[j],1-cos(t0))
			var qa:=a.lerp(inner[i],1-cos(t1))
			var qb:=b.lerp(inner[j],1-cos(t1))
			var va:=Vector3(pa.x,pa.y,top-bevel+bevel*sin(t0))
			var vb:=Vector3(pb.x,pb.y,top-bevel+bevel*sin(t0))
			var wa:=Vector3(qa.x,qa.y,top-bevel+bevel*sin(t1))
			var wb:=Vector3(qb.x,qb.y,top-bevel+bevel*sin(t1))
			var n0: Vector3=(normal*cos(t0)+Vector3.BACK*sin(t0)).normalized()
			var n1: Vector3=(normal*cos(t1)+Vector3.BACK*sin(t1)).normalized()
			emit(surfaces[slot],va,vb,wb,n0,n0,n1)
			emit(surfaces[slot],va,wb,wa,n0,n1,n1)

static func radial(r: float,a: float,z: float) -> Vector3:
	return Vector3(cos(a)*r,sin(a)*r,z)

static func ring(surfaces: Array[SurfaceTool],r: float,width: float,z: float,slot: int,start: float,sweep: float,segments: int,center:=Vector2.ZERO,height:=1.0) -> void:
	var inner:=maxf(0,r-width)
	var bevel:=minf(0.55,width*0.22)
	var top: float=z+height
	var base:=z-4.0
	var count:=maxi(4,ceili(segments*absf(sweep)/TAU))
	var offset:=Vector3(center.x,center.y,0)
	var st:=surfaces[slot]
	for i in count:
		var a: float=start+sweep*i/count
		var b: float=start+sweep*(i+1)/count
		var outer_a:=radial(r,a,base)+offset
		var outer_b:=radial(r,b,base)+offset
		var na:=radial(1,a,0)
		var nb:=radial(1,b,0)
		emit(st,outer_a,outer_b,radial(r,b,top-bevel)+offset,na,nb,nb)
		emit(st,outer_a,radial(r,b,top-bevel)+offset,radial(r,a,top-bevel)+offset,na,nb,na)
		for side in [1,-1]:
			if side==-1 and inner<=0: continue
			var radius: float=r if side==1 else inner
			if side==-1:
				emit(st,radial(inner,a,base)+offset,radial(inner,b,base)+offset,radial(inner,b,top-bevel)+offset,-na,-nb,-nb)
				emit(st,radial(inner,a,base)+offset,radial(inner,b,top-bevel)+offset,radial(inner,a,top-bevel)+offset,-na,-nb,-na)
			for k in 2:
				var t0: float=k*PI/4
				var t1: float=(k+1)*PI/4
				var r0: float=radius-side*bevel*(1-cos(t0))
				var r1: float=radius-side*bevel*(1-cos(t1))
				var n0a: Vector3=na*side*cos(t0)+Vector3.BACK*sin(t0)
				var n0b: Vector3=nb*side*cos(t0)+Vector3.BACK*sin(t0)
				var n1a: Vector3=na*side*cos(t1)+Vector3.BACK*sin(t1)
				var n1b: Vector3=nb*side*cos(t1)+Vector3.BACK*sin(t1)
				var va:=radial(r0,a,top-bevel+bevel*sin(t0))+offset
				var vb:=radial(r0,b,top-bevel+bevel*sin(t0))+offset
				var wa:=radial(r1,a,top-bevel+bevel*sin(t1))+offset
				var wb:=radial(r1,b,top-bevel+bevel*sin(t1))+offset
				emit(st,va,vb,wb,n0a,n0b,n1b)
				emit(st,va,wb,wa,n0a,n1b,n1a)
		var oa:=radial(r-bevel,a,top)+offset
		var ob:=radial(r-bevel,b,top)+offset
		var ia:=radial(inner+bevel,a,top)+offset if inner>0 else offset+Vector3(0,0,top)
		var ib:=radial(inner+bevel,b,top)+offset if inner>0 else ia
		face(st,oa,ob,ib,Vector3.BACK)
		face(st,oa,ib,ia,Vector3.BACK)
		face(st,outer_a,outer_b,radial(inner,b,base)+offset,Vector3.FORWARD)
		face(st,outer_a,radial(inner,b,base)+offset,radial(inner,a,base)+offset,Vector3.FORWARD)
	if absf(sweep)<TAU-0.001:
		for a in [start,start+sweep]:
			var n:=Vector3(-sin(a),cos(a),0)*(1 if a==start+sweep else -1)
			face(st,radial(inner,a,base)+offset,radial(r,a,base)+offset,radial(r,a,top-bevel)+offset,n)
			face(st,radial(inner,a,base)+offset,radial(r,a,top-bevel)+offset,radial(inner,a,top-bevel)+offset,n)

static func dome(surfaces: Array[SurfaceTool],x: float,y: float,rx: float,ry: float,z: float,h: float,slot: int,segments: int) -> void:
	var st:=surfaces[slot]
	for row in 6:
		var t0: float=row*PI/12
		var t1: float=(row+1)*PI/12
		for i in segments:
			var a: float=TAU*i/segments
			var b: float=TAU*(i+1)/segments
			var vs: Array[Vector3]=[]
			var ns: Array[Vector3]=[]
			for pair in [[t0,a],[t0,b],[t1,b],[t1,a]]:
				var t: float=pair[0]
				var angle: float=pair[1]
				vs.append(Vector3(x+rx*sin(t)*cos(angle),y+ry*sin(t)*sin(angle),z+h*cos(t)))
				ns.append(Vector3(sin(t)*cos(angle)/rx,sin(t)*sin(angle)/ry,cos(t)/h).normalized())
			emit(st,vs[0],vs[1],vs[2],ns[0],ns[1],ns[2])
			emit(st,vs[0],vs[2],vs[3],ns[0],ns[2],ns[3])
