"""16 editable Blender hulls; shared tier geometry with five real module stages each."""
from pathlib import Path
import json, math, sys, hashlib
import bpy, bmesh
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[1]
# Reuse the established closed-volume modeling helpers, without running its export.
helper=(ROOT/'tools/build_assault_blender.py').read_text(encoding='utf-8')
exec(compile(helper.split("print('PHASE primary curved volumes")[0],str(ROOT/'tools/build_assault_blender.py'),'exec'))
DEST=ROOT/'assets/ships/blender-fleet'
ART=ROOT/'assets/art-direction/branches/blender-fleet'
DEST.mkdir(parents=True,exist_ok=True);ART.mkdir(parents=True,exist_ok=True)
(ART/'.gdignore').touch()
reports=[]

def reset_scene():
    global SCENE, LOW, HIGH, ACTIVE, M
    bpy.ops.wm.read_factory_settings(use_empty=True)
    SCENE=bpy.context.scene
    LOW=collection('COL_Game');HIGH=collection('COL_High');ACTIVE=LOW
    M={'paint':material('MAT_IvoryPaint',(.48,.46,.40),.04,.38,.16),
       'dark':material('MAT_Graphite',(.025,.041,.052),.52,.40),
       'metal':material('MAT_BrushedMetal',(.27,.34,.38),.87,.28),
       'glass':material('MAT_Canopy',(.013,.10,.13),.38,.13,.7),
       'energy':material('MAT_Energy',(.04,.65,.78),.05,.2,.1,1.0),
       'amber':material('MAT_Amber',(.68,.37,.08),.65,.33)}

def disc(name,loc,radius,depth,mat):
    bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=radius,depth=depth,location=loc)
    return bevel(finish(bpy.context.object,name,mat),.025,3)

def crescent(name,side,profiles,mat='paint'):
    verts=[];faces=[];rings=30;segments=28
    for i in range(rings+1):
        x=profiles[0][0]+(profiles[-1][0]-profiles[0][0])*i/rings
        lead,trail,rz,cz=interp(profiles,x)
        for j in range(segments):
            a=math.tau*j/segments
            verts.append((side*x,(lead+trail)/2+(lead-trail)/2*math.cos(a),cz+rz*math.sin(a)))
    for i in range(rings):
        for j in range(segments):faces.append((i*segments+j,(i+1)*segments+j,(i+1)*segments+(j+1)%segments,i*segments+(j+1)%segments))
    faces.extend([tuple(reversed(range(segments))),tuple(rings*segments+j for j in range(segments))])
    return mesh(name,verts,faces,mat)

def nacelle(side,x,y,size=1):
    profiles=[(-1.3,x,.29,.30,.05),(-1.0,x,.44,.43,.05),(-.25,x,.46,.43,.08),(.7,x,.31,.29,.15),(1.15,x,.015,.02,.18)]
    loft_y('EngineNacelle_'+str(side),[(a*size+y,b,c*size,d*size,e)for a,b,c,d,e in profiles],'paint',26,32,side)
    for label,dy,radius,depth,mat in [('Collar',-1.28,.32,.17,'metal'),('Recess',-1.4,.27,.08,'dark'),('Glow',-1.45,.19,.02,'energy')]:
        cylinder('Engine'+label+'_'+str(side),(side*x,y+dy*size,.05),radius*size,depth,mat)
    box('EngineTopLight_'+str(side),(side*x,y-.85*size,.45*size),(.25,.35,.025),'energy',.02)
    for i in range(4):box('EngineVent_%d_%d'%(side,i),(side*x,y-.35+i*.16,.48*size),(.40,.055,.035),'metal',.01)

def canopy(length=1,width=1,z=.6):
    p=[(-1.1,0,.02,.02,z),(-.65,0,.26*width,.27,z+.12),(.25,0,.34*width,.40,z+.15),(1.1,0,.25*width,.3,z+.13),(1.7,0,.02,.02,z-.02)]
    loft_y('CanopyGasket',[(y*length,x,rx*1.13,rz,cz-.05)for y,x,rx,rz,cz in p],'dark',24,30)
    loft_y('TealCanopy',[(y*length,x,rx,rz,cz)for y,x,rx,rz,cz in p],'glass',28,32)

def wing_finish(side,profiles):
    def point(x,v,offset=.01):
        lead,trail,h,z=interp(profiles,x)
        return (side*x,lead*(1-v)+trail*v,z+h*math.sqrt(max(0,1-(1-2*v)**2))+offset)
    xs=[profiles[1][0]+(profiles[-1][0]-.25-profiles[1][0])*i/6 for i in range(7)]
    for v in [.24,.73]:tube('WingPanelSeam_%s_%s'%(side,v),[point(x,v)for x in xs],.008,'dark',1)
    tube('WingLight_'+str(side),[point(x,.12,.015)for x in xs[2:6]],.017,'energy',2)
    for j in range(2):
        x=xs[2]+j*.12;loc=point(x,.45,.018)
        box('WingAmberMark_%s_%s'%(side,j),loc,(.04,.22,.018),'amber',.004)

def escort(tier):
    span=4.0+tier*.32
    hull=[(-3.9,0,.015,.035,0),(-3.0,0,.38,.35,.05),(-1.3,0,.68,.49,.16),(.6,0,.76,.55,.21),(2.2,0,.47,.38,.12),(4.1,0,.015,.025,0)]
    loft_y('MainFuselage',hull,'paint',38,36)
    loft_y('LowerKeel',[(y,x,rx*1.06,rz*.78,z-.20)for y,x,rx,rz,z in hull],'dark',32,30)
    canopy(.95,1.15,.64)
    for side in [-1,1]:
        p=[(.58,1.5,-2.5,.36,.15),(1.35,1.95,-2.8,.32,.19),(2.3,1.2,-2.1,.22,.13),(3.15,.0,-1.5,.14,.08),(span,-1.8,-2.35,.015,0)]
        crescent('WingShell_'+str(side),side,p)
        crescent('WingUnderframe_'+str(side),side,[(x*1.025,a,b,h*.85,z-.15)for x,a,b,h,z in p],'dark')
        disc('ShieldHousing_'+str(side),(side*1.35,.1,.51),.47,.19,'metal')
        disc('ShieldWell_'+str(side),(side*1.35,.1,.63),.36,.055,'dark')
        disc('ShieldEmitter_'+str(side),(side*1.35,.1,.67),.19,.04,'energy')
        for k in range(4):
            a=k*math.pi/2
            box('ShieldBrace_%d_%d'%(side,k),(side*1.35+math.cos(a)*.37,.1+math.sin(a)*.37,.7),(.12,.12,.1),'paint',.035)
        nacelle(side,1.35+tier*.10,-2.4,1.08+tier*.07)
        box('BayDock_'+str(side),(side*2.12,-.45,.36),(.54,1.13,.15),'dark',.06)
        box('BayDoor_'+str(side),(side*2.12,-.45,.45),(.43,.95,.07),'paint',.07)
        for j in [-1,1]:box('BayGuide_%d_%d'%(side,j),(side*2.12+j*.18,-.45,.50),(.025,.65,.02),'energy',.007)
        wing_finish(side,p)
        if tier>=1:
            crescent('WingForwardArmor_'+str(side),side,[(.7,2.6,1.45,.17,.36),(1.1,2.5,1.2,.19,.38),(1.9,1.8,.85,.06,.37),(2.15,1.5,1.48,.01,.29)])
        if tier>=2:
            box('BaySecondary_'+str(side),(side*2.65,-1.12,.30),(.48,.9,.25),'metal',.09)
            disc('ShieldSecondary_'+str(side),(side*2.65,-1.0,.48),.16,.055,'energy')
        if tier>=3:
            crescent('WingRearCrown_'+str(side),side,[(1.7,-1.8,-3.2,.15,.25),(2.4,-1.7,-3.5,.16,.19),(3.4,-2.5,-3.6,.02,.02)])

def siege(tier):
    hull=[(-4.0,0,.15,.22,-.06),(-3.4,0,1.05,.60,.04),(-1.8,0,1.46,.67,.13),(-.1,0,1.48,.65,.16),(1.4,0,1.02,.46,.09),(2.0,0,.20,.18,0)]
    loft_y('MainFuselage',hull,'paint',36,36)
    loft_y('LowerKeel',[(y,x,rx*1.055,rz*.8,z-.2)for y,x,rx,rz,z in hull],'dark',30,28)
    # Recessed heavy weapon between two genuinely separate armored prow arms.
    box('WeaponChannel',(0,2.22,.23),(.57,4.9,.18),'dark',.09)
    cylinder('WeaponBarrel',(0,2.48,.40),.13,3.8,'metal')
    box('WeaponEnergy',(0,2.40,.54),(.045,3.25,.035),'amber',.015)
    for side in [-1,1]:
        x=.63+tier*.04
        arm=[(-1.25,x,.31,.35,.43),(.2,x,.40,.43,.46),(2.6,x,.36,.38,.46),(4.15+tier*.13,x,.23,.27,.42),(4.65+tier*.13,x,.015,.025,.33)]
        loft_y('ProwGasket_'+str(side),[(y,x,rx*1.05,rz,z-.07)for y,x,rx,rz,z in arm],'dark',30,28,side)
        loft_y('ProwArmor_'+str(side),arm,'paint',32,30,side)
        tube('ProwPanelSeam_'+str(side),[(side*(cx+rx*.52),y,z+rz*.86+.008)for y,cx,rx,rz,z in arm[1:-1]],.009,'dark',1)
        p=[(1.1,1.35,-3.3,.42,.14),(1.8,.8,-3.0,.4,.14),(2.6,-.2,-2.5,.24,.1),(3.1+tier*.12,-1.5,-2.25,.02,-.01)]
        crescent('WingShell_'+str(side),side,p)
        crescent('WingUnderframe_'+str(side),side,[(x*1.025,a,b,h*.9,z-.18)for x,a,b,h,z in p],'dark')
        nacelle(side,1.15+tier*.1,-2.75,1.30+tier*.05)
        box('RadiatorWell_'+str(side),(side*1.7,-.8,.48),(.48,1.18,.08),'dark',.05)
        for i in range(5):box('RadiatorFin_%d_%d'%(side,i),(side*1.7,-1.22+i*.19,.58),(.45,.08,.12),'metal',.014)
        wing_finish(side,p)
        if tier>=1:
            loft_y('OuterProw_'+str(side),[(.2,1.38,.24,.28,.28),(1.6,1.2,.3,.32,.3),(2.25,1.0,.02,.03,.25)],'paint',24,28,side)
        if tier>=2:
            cylinder('WeaponSecondary_'+str(side),(side*.43,1.3,.70),.085,1.1,'metal')
            box('WeaponBreech_'+str(side),(side*.43,.65,.66),(.23,.4,.24),'dark',.04)
        if tier>=3:
            crescent('WingRearBattlement_'+str(side),side,[(1.8,-1.7,-3.6,.25,.34),(2.4,-1.7,-3.8,.22,.30),(3.0,-2.4,-3.6,.02,.05)])
    # Small protected command canopy behind the gun rather than a fighter canopy.
    loft_y('TealCanopy',[(-2.1,0,.03,.03,.73),(-1.8,0,.32,.24,.83),(-1.0,0,.29,.20,.89),(-.7,0,.025,.03,.79)],'glass',24,30)
    box('CommandCanopyWell',(0,-1.5,.77),(.84,1.7,.08),'dark',.16)

def assault(tier):
    build(1)
    # Curved primary parts retained; later tiers add structural armor, not scale only.
    for side in [-1,1]:
        if tier>=1:
            loft_y('ProwArmor_'+str(side),[(.9,.53,.04,.04,.62),(1.8,.46,.15,.18,.62),(2.9,.25,.02,.03,.40)],'paint',24,28,side)
        if tier>=2:
            crescent('WingCanard_'+str(side),side,[(.62,2.2,1.1,.15,.42),(1.0,1.8,.8,.15,.38),(1.75,.5,.38,.015,.21)])
            box('WeaponFeed_'+str(side),(side*1.28,-1.4,.22),(.38,.4,.22),'paint',.06)
        if tier>=3:
            crescent('WingRearBlade_'+str(side),side,[(1.0,-2.4,-4.25,.18,.18),(1.9,-2.6,-4.4,.15,.12),(2.75,-3.7,-4.45,.012,.01)])
            cylinder('WeaponSecondary_'+str(side),(side*1.88,-.93,.20),.07,.78,'metal')

def common(tier):
    loft_y('MainFuselage',[(-3.5,0,.06,.08,0),(-2.8,0,.4,.36,.1),(-.5,0,.62,.46,.17),(1.5,0,.46,.36,.15),(3.65,0,.015,.02,0)],'paint',36,32)
    canopy(.8,.85,.55)
    for side in [-1,1]:
        span=2.55+tier*.17
        p=[(.5,.8,-2.5,.25,.02),(1.1,.4,-2.4,.20,.02),(span,-2.0,-2.4,.015,-.03)]
        crescent('WingShell_'+str(side),side,p)
        crescent('WingUnderframe_'+str(side),side,[(x*1.025,a,b,h*.8,z-.12)for x,a,b,h,z in p],'dark')
        wing_finish(side,p)
        nacelle(side,.68,-2.2,.70+tier*.03)
        cylinder('WeaponBarrel_'+str(side),(side*.85,-.35,.27),.065,.85,'metal')
        if tier>=1:box('ShoulderArmor_'+str(side),(side*.68,-.15,.43),(.25,.95,.17),'paint',.09)
        if tier>=2:crescent('WingCanard_'+str(side),side,[(.4,1.7,.9,.1,.25),(.8,1.3,.65,.1,.22),(1.3,.4,.38,.01,.1)])
        if tier>=3:box('WeaponFeed_'+str(side),(side*.85,-.85,.29),(.28,.44,.2),'dark',.05)

def modules(family,tier):
    wide={'common':1.0,'assault':1.5,'escort':2.4,'siege':2.0}[family]
    for stage in range(1,5):
        for side in [-1,1]:
            if stage==1:
                box('Stage01_WeaponMount_'+str(side),(side*wide,-.7,.32),(.29,.56,.30),'dark',.04)
                cylinder('Stage01_WeaponSleeve_'+str(side),(side*wide,-.7,.50),.13,.48,'metal')
            elif stage==2:crescent('Stage02_WingTip_'+str(side),side,[(wide+.1,.1,-.6,.10,.29),(wide+.5,-.4,-.9,.09,.23),(wide+.8,-1,-1.04,.01,.1)])
            elif stage==3:
                box('Stage03_EngineFairing_'+str(side),(side*(.7 if family in ['common','assault'] else 1.3),-2.8,.62 if family=='siege' else .48),(.33,.8,.16),'paint',.07)
                for j in range(3):box('Stage03_Radiator_%d_%d'%(side,j),(side*wide,-1.4+j*.12,.51),(.35,.045,.08),'metal',.012)
            else:
                disc('Stage04_CoreMount_'+str(side),(side*wide,-.5,.49),.20,.44,'metal')
                disc('Stage04_Core_'+str(side),(side*wide,-.5,.72),.19,.12,'dark')
                disc('Stage04_CoreLens_'+str(side),(side*wide,-.5,.80),.12,.03,'energy')

def role(obj):
    name=obj.name
    for i in range(1,5):
        if 'Stage%02d_'%i in name:return 'Stage%02d'%i
    side='Left' if '_-1' in name else 'Right'
    if any(s in name for s in ['Cannon','Weapon']):return 'Weapon_'+side
    if 'BayDoor' in name:return 'Bay_'+side
    if 'Wing' in name:return 'Wing_'+side
    if 'Engine' in name or 'Exhaust' in name:return 'Engine_'+side
    if 'Shield' in name:return 'Shield_'+side
    return 'Hull'

def select(objects):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]

def join(objects,name):
    select(objects);bpy.ops.object.join();obj=bpy.context.object;obj.name=name
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    return obj

def bake(lo,hi,source,size=1024):
    SCENE.render.engine='CYCLES';SCENE.cycles.samples=8
    maps={}
    for name,kind in [('normal','NORMAL'),('ao','AO')]:
        image=bpy.data.images.new(name,width=size,height=size,alpha=False);image.colorspace_settings.name='Non-Color'
        for mat in lo.data.materials:
            node=mat.node_tree.nodes.new('ShaderNodeTexImage');node.image=image;mat.node_tree.nodes.active=node
        hi.hide_render=kind=='AO';hi.hide_set(kind=='AO')
        select([hi,lo] if kind=='NORMAL' else [lo]);bpy.context.view_layer.objects.active=lo
        bpy.ops.object.bake(type=kind,use_selected_to_active=kind=='NORMAL',cage_extrusion=.018,max_ray_distance=.07,margin=6)
        image.filepath_raw=str(source/(name+'.png'));image.file_format='PNG';image.save();image.pack();maps[name]=image
    hi.hide_render=True;hi.hide_set(True)
    for mat in lo.data.materials:
        nodes=mat.node_tree.nodes;links=mat.node_tree.links;p=nodes.get('Principled BSDF')
        tex=nodes.new('ShaderNodeTexImage');tex.image=maps['normal'];normal=nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.28
        links.new(tex.outputs['Color'],normal.inputs['Color'])
        if mat.name not in ['MAT_Canopy','MAT_Energy']:links.new(normal.outputs['Normal'],p.inputs['Normal'])
        group=bpy.data.node_groups.get('glTF Material Output')
        if not group:
            group=bpy.data.node_groups.new('glTF Material Output','ShaderNodeTree');group.interface.new_socket(name='Occlusion',in_out='INPUT',socket_type='NodeSocketFloat')
        tex=nodes.new('ShaderNodeTexImage');tex.image=maps['ao'];out=nodes.new('ShaderNodeGroup');out.node_tree=group;links.new(tex.outputs['Color'],out.inputs['Occlusion'])

def split_roles(lo):
    # Preserve one shared atlas while retaining named movable/reconfigurable pieces.
    groups={i:g.name for i,g in enumerate(lo.vertex_groups)};polys={}
    for p in lo.data.polygons:
        weights=lo.data.vertices[p.vertices[0]].groups
        group=groups[max(weights,key=lambda g:g.weight).group] if weights else 'Hull'
        polys.setdefault(group,[]).append(p)
    result=[]
    for group,faces in polys.items():
        ids=sorted({v for p in faces for v in p.vertices});lookup={v:i for i,v in enumerate(ids)}
        data=bpy.data.meshes.new(group);data.from_pydata([lo.data.vertices[i].co for i in ids],[],[[lookup[i]for i in p.vertices]for p in faces]);data.update()
        for mat in lo.data.materials:data.materials.append(mat)
        uv=data.uv_layers.new(name='UVMap')
        for p,old in zip(data.polygons,faces):
            p.material_index=old.material_index;p.use_smooth=old.use_smooth
            for i,j in zip(p.loop_indices,old.loop_indices):uv.data[i].uv=lo.data.uv_layers.active.data[j].uv
        obj=bpy.data.objects.new('SM_'+group,data);LOW.objects.link(obj)
        obj['role']=group;obj['stage_from']=int(group[-2:])if group.startswith('Stage')else 0
        result.append(obj)
    bpy.data.objects.remove(lo,do_unlink=True)
    return result

def rig():
    SCENE.render.engine='CYCLES';SCENE.cycles.samples=20;SCENE.cycles.use_denoising=True
    SCENE.render.resolution_x=768;SCENE.render.resolution_y=768;SCENE.render.resolution_percentage=100
    SCENE.render.image_settings.file_format='PNG';SCENE.view_settings.view_transform='AgX'
    SCENE.world=bpy.data.worlds.new('Studio');SCENE.world.use_nodes=True
    SCENE.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.021,.032,.052,1);SCENE.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.6
    for name,loc,power,size,color in [('Key',(-5,4,9),1500,7,(1,.91,.79)),('Fill',(6,1,6),1100,6,(.64,.82,1)),('Rim',(0,-7,5),1300,5,(.55,.83,1))]:
        data=bpy.data.lights.new('LGT_'+name,'AREA');data.energy=power;data.size=size;data.color=color;o=bpy.data.objects.new(data.name,data);SCENE.collection.objects.link(o);o.location=loc;o.rotation_euler=(-o.location).to_track_quat('-Z','Y').to_euler()
    data=bpy.data.cameras.new('CAM_Review');cam=bpy.data.objects.new(data.name,data);SCENE.collection.objects.link(cam);SCENE.camera=cam;data.type='ORTHO';data.ortho_scale=12
    return cam

def render(cam,name,loc,source):
    cam.location=loc;cam.rotation_euler=(-cam.location).to_track_quat('-Z','Y').to_euler();SCENE.render.filepath=str(source/(name+'.png'));bpy.ops.render.render(write_still=True)

args=sys.argv[sys.argv.index('--')+1:]if '--'in sys.argv else []
families=args or ['common','assault','escort','siege']
for family in families:
    for tier in range(4):
        print('FLEET_BUILD',family,tier,flush=True);reset_scene()
        source=ART/('%s-%d'%(family,tier));source.mkdir(exist_ok=True)
        globals()[family](tier);modules(family,tier)
        construction=collection('COL_EditableConstruction')
        for obj in list(LOW.objects):
            backup=obj.copy();backup.data=obj.data.copy();construction.objects.link(backup);backup.hide_render=True;backup.hide_set(True)
            group=role(obj)
            select([obj])
            if obj.type=='CURVE':bpy.ops.object.convert(target='MESH')
            apply_modifiers(obj)
            bm=bmesh.new();bm.from_mesh(obj.data)
            bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001)
            bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
            defects=sum(not e.is_manifold for e in bm.edges)
            if defects:print('PART_TOPOLOGY',obj.name,defects,flush=True)
            bm.to_mesh(obj.data);bm.free();obj.data.update()
            obj.vertex_groups.new(name=group).add(list(range(len(obj.data.vertices))),1,'REPLACE')
        lo=join(list(LOW.objects),'SM_Game_Combined')
        hi=lo.copy();hi.data=lo.data.copy();HIGH.objects.link(hi);hi.name='SM_High_Source'
        hi.data.calc_loop_triangles();high_tris=len(hi.data.loop_triangles)
        if high_tris>18500:
            dec=lo.modifiers.new('Runtime budget','DECIMATE');dec.ratio=18000/high_tris;apply_modifiers(lo)
        bm=bmesh.new();bm.from_mesh(lo.data);bmesh.ops.triangulate(bm,faces=list(bm.faces));bad=sum(not e.is_manifold for e in bm.edges);bm.to_mesh(lo.data);bm.free();lo.data.update()
        if bad:
            bpy.ops.wm.save_as_mainfile(filepath=str(source/'topology-debug.blend'))
            raise RuntimeError('Non-manifold export '+family+str(tier)+': '+str(bad))
        select([lo]);bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=math.radians(62),island_margin=.009);bpy.ops.object.mode_set(mode='OBJECT')
        bake(lo,hi,source)
        parts=split_roles(lo);triangles=0;stages={}
        for obj in parts:
            obj.data.calc_loop_triangles();n=len(obj.data.loop_triangles);triangles+=n
            if obj['stage_from']:stages[obj['stage_from']]=n
        if triangles>25000 or len(stages)!=4:raise RuntimeError('Budget or stage parts missing')
        select(parts)
        bpy.ops.export_scene.gltf(filepath=str(DEST/('%s-%d.glb'%(family,tier))),export_format='GLB',use_selection=True,export_apply=True,export_tangents=True,export_yup=True,export_extras=True)
        cam=rig()
        render(cam,'hero',(10,-13,13),source);render(cam,'top',(0,0,17),source);render(cam,'side',(16,0,3),source)
        bpy.ops.wm.save_as_mainfile(filepath=str(source/(family+'-source.blend')))
        report={'family':family,'tier':tier,'triangles':triangles,'high_triangles':high_tris,'non_manifold_edges':bad,'material_roles':6,'stage_triangles':stages,'parts':[p.name for p in parts],'editable_parts':len(construction.objects),'normal_ao':1024,'source':str(source.relative_to(ROOT))}
        (source/'validation.json').write_text(json.dumps(report,indent=2));reports.append(report)
        (ART/'manifest.json').write_text(json.dumps(reports,indent=2))
        print('FLEET_VALIDATED',json.dumps(report),flush=True)
print('BLENDER_FLEET_COMPLETE',len(reports),'tier assemblies',flush=True)
