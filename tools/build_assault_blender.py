"""Reference-led assault prototype. Run in Blender 5.2; outputs editable source, baked GLB and renders."""
import bpy, bmesh, math, json, sys
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'assets'/'ships'/'blender-assault'
SOURCE = ROOT/'assets'/'art-direction'/'branches'/'blender-assault'
OUT.mkdir(parents=True, exist_ok=True)
SOURCE.mkdir(parents=True, exist_ok=True)
SCENE=bpy.context.scene
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for coll in list(bpy.data.collections):
    if coll.name!='Collection': bpy.data.collections.remove(coll)

def collection(name):
    c=bpy.data.collections.new(name); SCENE.collection.children.link(c); return c
LOW=collection('COL_LowPoly'); HIGH=collection('COL_HighPoly'); LIGHTS=collection('COL_Lookdev')
ACTIVE=LOW

def move(obj, coll=None):
    for c in list(obj.users_collection): c.objects.unlink(obj)
    (coll or ACTIVE).objects.link(obj)
    return obj

def material(name,color,metal=0,rough=.3,coat=.0,emission=0):
    m=bpy.data.materials.new(name); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Metallic'].default_value=metal
    p.inputs['Roughness'].default_value=rough
    p.inputs['Coat Weight'].default_value=coat
    if emission:
        p.inputs['Emission Color'].default_value=(*color,1)
        p.inputs['Emission Strength'].default_value=emission
    return m

M={
 'paint':material('MAT_IvoryPaint',(.55,.52,.43),.04,.34,.35),
 'dark':material('MAT_Graphite',(.026,.038,.047),.65,.43),
 'metal':material('MAT_BrushedMetal',(.24,.30,.33),.9,.3),
 'glass':material('MAT_Canopy',(.012,.078,.095),.4,.12,.8),
 'energy':material('MAT_Energy',(.04,.65,.78),.05,.22,.2,1.0),
 'amber':material('MAT_Amber',(.62,.35,.095),.65,.34),
}

def finish(obj,name,mat,smooth=True):
    obj.name='SM_'+name
    obj.data.materials.append(M[mat]); move(obj)
    if obj.type=='MESH':
        for f in obj.data.polygons: f.use_smooth=smooth
        bm=bmesh.new(); bm.from_mesh(obj.data)
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(obj.data); bm.free()
    return obj

def mesh(name,verts,faces,mat):
    data=bpy.data.meshes.new(name); data.from_pydata(verts,[],faces); data.update()
    obj=bpy.data.objects.new(name,data); ACTIVE.objects.link(obj)
    return finish(obj,name,mat)

def interp(profiles,t):
    for a,b in zip(profiles,profiles[1:]):
        if a[0]<=t<=b[0]:
            f=(t-a[0])/(b[0]-a[0]);return tuple(a[i]*(1-f)+b[i]*f for i in range(1,len(a)))
    return profiles[0][1:] if t<profiles[0][0] else profiles[-1][1:]

def loft_y(name,profiles,mat,rings=36,segments=32,side=1):
    # profile: Y, centre X, half-width, half-height, centre Z.
    verts=[]; faces=[]
    for i in range(rings+1):
        y=profiles[0][0]+(profiles[-1][0]-profiles[0][0])*i/rings
        cx,rx,rz,cz=interp(profiles,y)
        for j in range(segments):
            a=2*math.pi*j/segments
            verts.append((side*(cx+rx*math.cos(a)),y,cz+rz*math.sin(a)))
    for i in range(rings):
        for j in range(segments):
            a=i*segments+j; b=(i+1)*segments+j
            faces.append((a,b,(i+1)*segments+(j+1)%segments,i*segments+(j+1)%segments))
    faces.append(tuple(reversed(range(segments))))
    faces.append(tuple(rings*segments+j for j in range(segments)))
    return mesh(name,verts,faces,mat)

WING=[(.40,1.05,-3.3,.32,.10),(1.0,.75,-2.85,.27,.10),(1.65,-.08,-2.35,.18,.10),(2.3,-1.15,-2.65,.12,.08),(2.95,-2.4,-3.2,.065,.045),(3.53,-3.74,-3.92,.012,.02)]

def wing_z(x,y):
    lead,trail,rz,cz=interp(WING,x)
    q=(y-(lead+trail)/2)/max(.001,(lead-trail)/2)
    return cz+rz*math.sqrt(max(0,1-q*q))

def wing(name,side,detail,under=False):
    profiles=[(x*(1.014 if under else 1),lead,trail,rz*(.88 if under else 1),cz-(.13 if under else 0)) for x,lead,trail,rz,cz in WING]
    if not under: profiles=[(1.15,1.05,-2.9,.24,.10)]+[p for p in profiles if p[0]>1.15]
    rings=24*detail; segments=32*detail; verts=[]; faces=[]
    for i in range(rings+1):
        x=profiles[0][0]+(profiles[-1][0]-profiles[0][0])*i/rings
        lead,trail,rz,cz=interp(profiles,x)
        for j in range(segments):
            a=2*math.pi*j/segments
            verts.append((side*x,(lead+trail)/2+(lead-trail)/2*math.cos(a),cz+rz*math.sin(a)))
    for i in range(rings):
        for j in range(segments): faces.append((i*segments+j,(i+1)*segments+j,(i+1)*segments+(j+1)%segments,i*segments+(j+1)%segments))
    faces.append(tuple(reversed(range(segments))))
    faces.append(tuple(rings*segments+j for j in range(segments)))
    return mesh(name,verts,faces,'dark' if under else 'paint')

def bevel(obj,width=.025,segments=2):
    mod=obj.modifiers.new('Design bevel','BEVEL'); mod.width=width; mod.segments=segments
    mod.limit_method='ANGLE'; mod.angle_limit=.5
    return obj

def box(name,loc,size,mat,width=.02):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc)
    obj=bpy.context.object; obj.dimensions=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    finish(obj,name,mat,False)
    if width: bevel(obj,width,2)
    return obj

def tube(name,points,radius,mat,segments=2):
    curve=bpy.data.curves.new(name,'CURVE'); curve.dimensions='3D';curve.resolution_u=12
    curve.bevel_depth=radius;curve.bevel_resolution=segments;curve.use_fill_caps=True
    spline=curve.splines.new('BEZIER');spline.bezier_points.add(len(points)-1)
    for p,co in zip(spline.bezier_points,points):
        p.co=co;p.handle_left_type='AUTO';p.handle_right_type='AUTO'
    obj=bpy.data.objects.new(name,curve);ACTIVE.objects.link(obj)
    obj.data.materials.append(M[mat]);obj.name='SM_'+name
    return obj

def cylinder(name,loc,radius,depth,mat,segments=32):
    bpy.ops.mesh.primitive_cylinder_add(vertices=segments,radius=radius,depth=depth,location=loc,rotation=(math.pi/2,0,0))
    return bevel(finish(bpy.context.object,name,mat),.012,2)

def apply_modifiers(obj):
    bpy.context.view_layer.objects.active=obj
    for mod in list(obj.modifiers): bpy.ops.object.modifier_apply(modifier=mod.name)

def build(detail):
    hull=[(-4.35,0,.03,.04,.02),(-4.0,0,.19,.17,.03),(-3.1,0,.37,.29,.04),(-1.9,0,.52,.40,.09),(-.5,0,.69,.50,.16),(.7,0,.69,.53,.18),(1.9,0,.63,.43,.17),(2.8,0,.42,.32,.13),(3.8,0,.19,.21,.08),(4.65,0,.065,.085,.02),(5.0,0,.006,.008,0)]
    loft_y('MainFuselage',hull,'paint',48*detail,40*detail)
    loft_y('LowerKeel',[(y,cx,rx*1.065,rz*.7,cz-.14) for y,cx,rx,rz,cz in hull],'dark',40*detail,32*detail)
    canopy=[(-.72,0,.02,.025,.67),(-.3,0,.22,.22,.75),(.5,0,.31,.39,.79),(1.3,0,.29,.36,.78),(2.0,0,.18,.23,.69),(2.45,0,.015,.02,.56)]
    loft_y('CanopyGasket',[(y,cx,rx*1.14,rz*.98,cz-.025) for y,cx,rx,rz,cz in canopy],'dark',30*detail,32*detail)
    loft_y('TealCanopy',canopy,'glass',30*detail,40*detail)
    for side in [-1,1]:
        under=wing('WingUnderframe_'+str(side),side,detail,True)
        shell=wing('WingShell_'+str(side),side,detail)
        cutter=box('CutterGunBay_'+str(side),(side*1.28,-.9,.2),(.46,1.52,1.3),'dark',.10)
        apply_modifiers(cutter)
        mod=shell.modifiers.new('Recessed gun bay','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter
        bpy.context.view_layer.objects.active=shell;bpy.ops.object.modifier_apply(modifier=mod.name)
        mod=under.modifiers.new('Open gun well','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter
        bpy.context.view_layer.objects.active=under;bpy.ops.object.modifier_apply(modifier=mod.name)
        bpy.data.objects.remove(cutter,do_unlink=True)
        bevel(shell,.018,2)
        box('CannonBayLiner_'+str(side),(side*1.28,-.9,-.15),(.43,1.48,.04),'dark',.03)
        cylinder('RecessedWingCannon_'+str(side),(side*1.28,-.85,.10),.085,1.05,'metal',24*detail)
        cylinder('CannonMuzzle_'+str(side),(side*1.28,-.28,.10),.11,.09,'dark',24*detail)
        for j in range(3): cylinder('CannonBand_%s_%s'%(side,j),(side*1.28,-1.18+j*.26,.10),.10,.035,'metal',20*detail)
        box('CannonAmberClip_'+str(side),(side*1.28,-1.19,.11),(.20,.09,.05),'amber',.01)
        shoulder=[(-2.7,.46,.05,.05,.18),(-1.7,.61,.17,.22,.40),(-.3,.61,.18,.24,.57),(.65,.49,.13,.19,.68),(1.45,.35,.01,.02,.65)]
        loft_y('ShoulderGasket_'+str(side),[(y,x,rx*1.12,rz*.96,z-.018) for y,x,rx,rz,z in shoulder],'dark',32*detail,28*detail,side)
        loft_y('FlowingShoulder_'+str(side),shoulder,'paint',32*detail,28*detail,side)
        pod=[(-4.65,.72,.32,.30,0),(-4.0,.72,.42,.40,.01),(-2.9,.72,.43,.38,.04),(-1.9,.68,.36,.30,.08),(-1.28,.61,.20,.16,.10),(-1.12,.58,.02,.03,.12)]
        loft_y('EngineNacelle_'+str(side),pod,'paint',30*detail,36*detail,side)
        cylinder('ExhaustMetalCollar_'+str(side),(side*.72,-4.68,0),.34,.20,'metal',40*detail)
        cylinder('ExhaustRecess_'+str(side),(side*.72,-4.80,0),.275,.09,'dark',40*detail)
        cylinder('ExhaustGlow_'+str(side),(side*.72,-4.86,0),.215,.025,'energy',40*detail)
        bpy.ops.mesh.primitive_cone_add(vertices=32*detail,radius1=.215,radius2=.06,depth=.23,location=(side*.72,-4.96,0),rotation=(math.pi/2,0,0))
        finish(bpy.context.object,'ExhaustCore_'+str(side),'energy')
        box('ExhaustTopWindow_'+str(side),(side*.72,-4.25,.31),(.27,.25,.045),'dark',.035)
        box('ExhaustTopLight_'+str(side),(side*.72,-4.27,.34),(.16,.14,.02),'energy',.02)
        box('EngineVentWell_'+str(side),(side*.72,-2.65,.412),(.4,.78,.03),'dark',.03)
        for i in range(6): box('EngineVent_%s_%s'%(side,i),(side*.72,-2.95+i*.115,.445),(.37,.045,.025),'metal',.008)
        for v in [.18,.7]:
            points=[]
            for x in [1.7,2.05,2.45,2.8,3.2]:
                lead,trail,rz,cz=interp(WING,x); y=lead*(1-v)+trail*v
                points.append((side*x,y,wing_z(x,y)+.008))
            tube('WingPanelSeam_%s_%s'%(side,v),points,.008,'dark',1)
        outline=[]
        for x,v in [(1.72,.38),(2.18,.38),(2.55,.52),(2.45,.82),(1.78,.83),(1.72,.38)]:
            lead,trail,_,_=interp(WING,x);y=lead*(1-v)+trail*v
            outline.append((side*x,y,wing_z(x,y)+.014))
        tube('WingArmorBoundary_'+str(side),outline,.010,'dark',1)
        for y in [-3.55,-3.9]:
            bpy.ops.mesh.primitive_torus_add(major_segments=32*detail,minor_segments=8,location=(side*.72,y,.02),rotation=(math.pi/2,0,0),major_radius=.40,minor_radius=.022)
            finish(bpy.context.object,'EngineSeam_%s_%s'%(side,y),'metal')
        points=[]
        for x in [2.0,2.25,2.5,2.75]:
            lead,trail,_,_=interp(WING,x);y=lead*.87+trail*.13
            points.append((side*x,y,wing_z(x,y)+.012))
        tube('WingLightStrip_'+str(side),points,.017,'energy',2)
        for y in [3.0,3.45,3.85]:
            _,rx,rz,cz=interp(hull,y)
            box('NoseInset_%s_%s'%(side,y),(side*rx*.55,y,cz+rz*.88),(.025,.18,.015),'metal',.006)
        tube('CanopyFrame_'+str(side),[(side*rx*.96,y,cz+.035) for y,_,rx,rz,cz in canopy[1:-1]],.018,'metal',2)
        for j in range(2):
            x=2.1+j*.1;y=-1.7
            box('AmberWingMark_%s_%s'%(side,j),(side*x,y,wing_z(x,y)+.012),(.04,.18,.02),'amber',.005)
    points=[]
    for y in [2.8,3.1,3.5,3.9,4.2]:
        _,_,rz,cz=interp(hull,y);points.append((0,y,cz+rz+.01))
    tube('NoseEnergyStrip',points,.017,'energy',2)

def select(objects):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects: o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]

print('PHASE primary curved volumes and recessed systems',flush=True)
build(1)
low=list(LOW.objects)
ACTIVE=HIGH
build(2)
high=list(HIGH.objects)
primary=['SM_MainFuselage','SM_TealCanopy','SM_WingShell_-1','SM_WingShell_1','SM_EngineNacelle_-1','SM_EngineNacelle_1']
part_counts={name:sum(obj.name==name for obj in low) for name in primary}
if any(count!=1 for count in part_counts.values()): raise RuntimeError('Primary part count differs from reference brief')
construction=collection('COL_Construction_Editable')
for obj in low+high:
    backup=obj.copy();backup.data=obj.data.copy();backup.name='EDIT_'+obj.name
    construction.objects.link(backup);backup.hide_render=True;backup.hide_set(True)

def collapse(objects,name):
    for obj in objects:
        select([obj])
        if obj.type=='CURVE': bpy.ops.object.convert(target='MESH')
        apply_modifiers(obj)
    select(objects); bpy.ops.object.join()
    obj=bpy.context.object;obj.name=name
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    bm=bmesh.new();bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(obj.data);bm.free();obj.data.update()
    return obj

lo=collapse(low,'SM_Assault_Game')
hi=collapse(high,'SM_Assault_High')
lo.data.calc_loop_triangles()
if len(lo.data.loop_triangles)>16000:
    dec=lo.modifiers.new('Game budget','DECIMATE');dec.ratio=15000/len(lo.data.loop_triangles)
    apply_modifiers(lo)
bm=bmesh.new();bm.from_mesh(lo.data)
bmesh.ops.triangulate(bm,faces=list(bm.faces),quad_method='BEAUTY',ngon_method='BEAUTY')
bm.to_mesh(lo.data);bm.free();lo.data.update()
select([lo])
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=math.radians(60),island_margin=.012)
bpy.ops.object.mode_set(mode='OBJECT')

SCENE.render.engine='CYCLES'
SCENE.cycles.samples=16
SCENE.cycles.bake_type='NORMAL'
SCENE.render.bake.use_selected_to_active=True
SCENE.render.bake.cage_extrusion=.045
SCENE.render.bake.max_ray_distance=.12
SCENE.render.bake.margin=8

def bake_map(name,kind):
    image=bpy.data.images.new(name,width=1024,height=1024,alpha=False)
    image.colorspace_settings.name='Non-Color'
    for mat in lo.data.materials:
        node=mat.node_tree.nodes.new('ShaderNodeTexImage');node.image=image
        mat.node_tree.nodes.active=node
    hi.hide_render=kind!='NORMAL';hi.hide_set(kind!='NORMAL')
    select([lo,hi] if kind=='NORMAL' else [lo]);bpy.context.view_layer.objects.active=lo
    bpy.ops.object.bake(type=kind,use_selected_to_active=(kind=='NORMAL'),cage_extrusion=.018,max_ray_distance=.06,margin=8)
    image.filepath_raw=str(SOURCE/(name+'.png'));image.file_format='PNG';image.save()
    return image

print('PHASE baking tangent normals and ambient occlusion',flush=True)
normal=bake_map('assault_normal','NORMAL')
hi.hide_render=True;hi.hide_set(True)
# AO is baked from the complete low-poly assembly to preserve contact shadows between components.
select([lo]);SCENE.render.bake.use_selected_to_active=False
ao=bake_map('assault_ao','AO')
hi.hide_render=True;hi.hide_set(True)
for mat in lo.data.materials:
    nodes=mat.node_tree.nodes;links=mat.node_tree.links;p=nodes.get('Principled BSDF')
    # Sampling atlases uses the same UVs in Blender and glTF.
    tex=nodes.new('ShaderNodeTexImage');tex.image=normal
    n=nodes.new('ShaderNodeNormalMap');n.inputs['Strength'].default_value=.45
    links.new(tex.outputs['Color'],n.inputs['Color'])
    if mat.name not in ['MAT_Canopy','MAT_Energy']: links.new(n.outputs['Normal'],p.inputs['Normal'])
    tex=nodes.new('ShaderNodeTexImage');tex.image=ao
    group=bpy.data.node_groups.get('glTF Material Output')
    if group is None:
        group=bpy.data.node_groups.new('glTF Material Output','ShaderNodeTree')
        group.interface.new_socket(name='Occlusion',in_out='INPUT',socket_type='NodeSocketFloat')
    output=nodes.new('ShaderNodeGroup');output.node_tree=group
    links.new(tex.outputs['Color'],output.inputs['Occlusion'])

def audit(obj):
    obj.data.calc_loop_triangles()
    bm=bmesh.new();bm.from_mesh(obj.data)
    result={'triangles':len(obj.data.loop_triangles),'vertices':len(obj.data.vertices),'materials':len(obj.data.materials),'non_manifold_edges':sum(not e.is_manifold for e in bm.edges),'uv_layers':len(obj.data.uv_layers),'dimensions':list(obj.dimensions)}
    bm.free();return result

report={'blender':bpy.app.version_string,'low':audit(lo),'high':audit(hi),'primary_components':part_counts,'editable_parts':len(construction.objects),'reference':'assets/art-direction/branches/concept.png','scope':'one assault prototype; other branches unchanged'}
if report['low']['triangles']>18000:
    # Keep the source/high intact; simplify the export mesh only.
    dec=lo.modifiers.new('Game budget','DECIMATE');dec.ratio=16000/report['low']['triangles']
    apply_modifiers(lo);report['low']=audit(lo)
if report['low']['non_manifold_edges'] or not report['low']['uv_layers']: raise RuntimeError('Geometry/UV validation failed: '+str(report))
(SOURCE/'validation.json').write_text(json.dumps(report,indent=2))
print('VALIDATE',json.dumps(report),flush=True)
select([lo]);hi.hide_render=True
bpy.ops.export_scene.gltf(filepath=str(OUT/'assault.glb'),export_format='GLB',use_selection=True,export_apply=True,export_tangents=True,export_yup=True)

# Neutral look-development cameras; the reference top view and 3/4 view render the actual game mesh.
SCENE.render.engine='CYCLES';SCENE.cycles.samples=40
SCENE.cycles.use_denoising=True
SCENE.world.color=(.15,.15,.15)
SCENE.render.resolution_x=1100;SCENE.render.resolution_y=1100;SCENE.render.resolution_percentage=100
SCENE.render.image_settings.file_format='PNG'
SCENE.render.film_transparent=False
SCENE.view_settings.view_transform='AgX'
SCENE.world.use_nodes=True
SCENE.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.025,.038,.065,1)
SCENE.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.6

def light(name,loc,power,size,color):
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size;data.color=color
    o=bpy.data.objects.new(name,data);LIGHTS.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,0,0))-o.location).to_track_quat('-Z','Y').to_euler()
light('LGT_Key',(-5,3,9),1300,7,(1,.9,.75))
light('LGT_Fill',(5,0,6),900,6,(.55,.78,1))
light('LGT_Rim',(0,-7,4),1100,5,(.6,.85,1))
data=bpy.data.cameras.new('CAM_Hero');cam=bpy.data.objects.new('CAM_Hero',data);LIGHTS.objects.link(cam)
SCENE.camera=cam;data.type='ORTHO';data.ortho_scale=11.5

def render(name,loc,target=(0,0,0)):
    cam.location=loc;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
    SCENE.render.filepath=str(SOURCE/(name+'.png'));bpy.ops.render.render(write_still=True)

print('PHASE rendering actual model',flush=True)
render('top_preview',(0,0,16))
render('threequarter_preview',(10,-13,13))
render('side_preview',(16,0,3))
SCENE.render.film_transparent=True
mask=bpy.data.materials.new('MAT_Silhouette');mask.use_nodes=True
nodes=mask.node_tree.nodes;nodes.clear()
em=nodes.new('ShaderNodeEmission');em.inputs['Color'].default_value=(1,1,1,1)
output=nodes.new('ShaderNodeOutputMaterial');mask.node_tree.links.new(em.outputs[0],output.inputs[0])
SCENE.view_layers[0].material_override=mask
render('top_mask',(0,0,16))
SCENE.view_layers[0].material_override=None
SCENE.render.film_transparent=False
data.ortho_scale=11.5
for image in [normal,ao]: image.pack()
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'assault-source.blend'))
print('ASSAULT_BLENDER_COMPLETE',str(OUT/'assault.glb'),flush=True)
