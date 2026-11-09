extends RefCounted
## Coherent low-cost station geometry; all surfaces share the ship lighting.
static var materials: Array=[]
static func material(index: int) -> StandardMaterial3D:
 if materials.is_empty():
  for color in [Color('182a3b'),Color('263d4c'),Color('355566'),Color('70b4ba')]:
   var m:=StandardMaterial3D.new();m.albedo_color=color;m.metallic=.5;m.roughness=.68
   m.cull_mode=BaseMaterial3D.CULL_DISABLED
   materials.append(m)
 return materials[index]
static func plate(size: Vector3,position: Vector3,index: int,parent: Node3D):
 var x:=size.x*.5;var y:=size.y*.5;var cut:=minf(12,minf(x,y)*.25)
 var outline=[Vector2(-x+cut,-y),Vector2(x-cut,-y),Vector2(x,-y+cut),Vector2(x,y-cut),Vector2(x-cut,y),Vector2(-x+cut,y),Vector2(-x,y-cut),Vector2(-x,-y+cut)]
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in 8:
  var a: Vector2=outline[i];var b: Vector2=outline[(i+1)%8]
  var aa:=a*.96;var bb:=b*.96
  var vertices=[Vector3(0,0,size.z),Vector3(aa.x,aa.y,size.z),Vector3(bb.x,bb.y,size.z),Vector3(a.x,a.y,0),Vector3(b.x,b.y,0),Vector3(bb.x,bb.y,size.z),Vector3(a.x,a.y,0),Vector3(bb.x,bb.y,size.z),Vector3(aa.x,aa.y,size.z)]
  for j in range(0,9,3):
   st.add_vertex(vertices[j]);st.add_vertex(vertices[j+2]);st.add_vertex(vertices[j+1])
 st.generate_normals()
 var mesh:=MeshInstance3D.new();mesh.mesh=st.commit();mesh.material_override=material(index);mesh.position=position
 mesh.set_meta('minor_detail',size.x<20 or size.y<35)
 mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(mesh)
static func build(act: int,variant: int) -> Node3D:
 var root:=Node3D.new()
 plate(Vector3(150,350,8),Vector3(20,0,0),0,root)
 plate(Vector3(13,350,13),Vector3(-62,0,0),2,root)
 plate(Vector3(12,350,10),Vector3(104,0,0),1,root)
 for row in 4:
  var y: float=(row-1.5)*78
  plate(Vector3(122,67,7),Vector3(18,y,8),1 if row%2==variant%2 else 2,root)
  plate(Vector3(80,3,1),Vector3(18,y-22,16),0,root)
  if (row+variant)%3!=0:
   plate(Vector3(16,32,12),Vector3(-93,y,4),2,root)
   plate(Vector3(3,18,1),Vector3(-93,y,17),3,root)
 if act==0:
  root.rotation.z=.10 if variant%2==0 else -.08
  plate(Vector3(80,110,6),Vector3(141,45,0),0,root)
 elif act==1:
  for side in [-1,1]: plate(Vector3(40,120,3),Vector3(150,side*95,4),2,root)
 else:
  plate(Vector3(110,330,12),Vector3(167,0,0),1,root)
  for y in [-100,0,100]: plate(Vector3(75,6,1),Vector3(168,y,13),3,root)
 return root
