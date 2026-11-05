"""Reference-led six enemy silhouettes and six capital ships, using the fleet pipeline."""
from pathlib import Path
import math,json,sys
import bpy,bmesh
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
exec(compile((ROOT/'tools/build_blender_fleet.py').read_text(encoding='utf-8').split('args=sys.argv')[0],str(ROOT/'tools/build_blender_fleet.py'),'exec'))
DEST=ROOT/'assets/ships/blender-hostiles';ART=ROOT/'assets/art-direction/hostiles-blender'
DEST.mkdir(parents=True,exist_ok=True);ART.mkdir(parents=True,exist_ok=True);(ART/'.gdignore').touch()
reports=[]
COLORS=[(.36,.025,.045),(.55,.20,.025),(.31,.36,.035),(.12,.22,.34),(.55,.58,.56),(.17,.095,.30)]
LIGHTS=[(1,.14,.1),(1,.46,.08),(.70,1,.08),(.15,.6,1),(.5,.85,1),(.67,.22,1)]

def arc(name,r,inner,start,sweep,z,depth,mat,segments=32):
    verts=[];faces=[]
    for i in range(segments+1):
        a=start+sweep*i/segments
        for radius,h in [(r,z),(inner,z),(r,z+depth),(inner,z+depth)]:verts.append((math.cos(a)*radius,math.sin(a)*radius,h))
    for i in range(segments):
        a=i*4;b=(i+1)*4
        faces.extend([(a,a+1,b+1,b),(a+2,b+2,b+3,a+3),(a,b,b+2,a+2),(a+1,a+3,b+3,b+1)])
    if abs(sweep-math.tau)>.00001:faces.extend([(0,2,3,1),(segments*4,segments*4+1,segments*4+3,segments*4+2)])
    obj=mesh(name,verts,faces,mat)
    for face in obj.data.polygons:face.use_smooth=False
    return bevel(obj,.035,3)

def spine(length=4,width=.55):
    p=[(-length,0,.025,.04,0),(-length*.7,0,width*.7,.38,.1),(-.3,0,width,.5,.2),(length*.5,0,width*.6,.4,.2),(length,0,.015,.025,0)]
    loft_y('MainFuselage',p,'paint',28,28)
    loft_y('LowerKeel',[(y,x,rx*1.07,rz*.8,z-.18)for y,x,rx,rz,z in p],'dark',24,24)

def sensor(x=0,y=0,r=.35):
    disc('SensorMount',(x,y,.61),r*1.4,.17,'metal')
    disc('SensorRecess',(x,y,.73),r*1.17,.08,'dark')
    disc('SensorLens',(x,y,.78),r,.045,'energy')
    disc('SensorIris',(x,y,.81),r*.34,.018,'glass')

def gun(side,x,y,length=2,z=.62):
    box('WeaponMount_'+str(side),(side*x,y,z-.20),(.42,length*.7,.25),'dark',.06)
    cylinder('WeaponBarrel_'+str(side),(side*x,y+.2,z),.11,length,'metal')
    cylinder('WeaponMuzzle_'+str(side),(side*x,y+length*.5+.2,z),.15,.1,'dark')
    cylinder('WeaponAperture_'+str(side),(side*x,y+length*.5+.26,z),.075,.02,'energy')

def wing_pair(span=3,forward=.8):
    for side in [-1,1]:
        p=[(.5,forward,-2.5,.25,.05),(1.3,forward*.55,-2,.22,.08),(span,-1.5,-2.0,.015,0)]
        crescent('WingShell_'+str(side),side,p)
        crescent('WingFrame_'+str(side),side,[(x*1.03,a,b,h*.9,z-.14)for x,a,b,h,z in p],'dark')
        wing_finish(side,p)

def enemy(kind):
    if kind=='normal':
        spine(3,.5);wing_pair(3.2,1.2);sensor(0,.35,.27)
        for side in [-1,1]:nacelle(side,.68,-1.6,.62);gun(side,1.5,-.45,1.3)
    elif kind=='fast':
        spine(4.9,.36)
        for side in [-1,1]:
            nacelle(side,.54,-2.9,.65)
            crescent('WingNeedle_'+str(side),side,[(.33,3.5,-2,.13,.2),(.7,3.8,-2.5,.12,.13),(1.05,1.2,-3.8,.015,.03)])
            box('WingRail_'+str(side),(side*.74,.6,.34),(.075,3.8,.09),'metal',.02)
        sensor(0,.1,.2)
    elif kind=='swift':
        disc('CoreHull',(0,0,.05),.85,.65,'paint');sensor(0,0,.34)
        for i in range(3):
            before=set(LOW.objects)
            p=[(.6,.6,-.6,.28,.17),(1.6,.7,-.9,.22,.12),(3.4,-.65,-1.2,.015,0)]
            crescent('WingRotor_'+str(i),1,p)
            wing_finish(1,p)
            box('RotorJoint_'+str(i),(1.1,0,.23),(.8,.34,.32),'metal',.06)
            for o in set(LOW.objects)-before:
                a=i*math.tau/3;x,y,z=o.location
                o.location=(math.cos(a)*x-math.sin(a)*y,math.sin(a)*x+math.cos(a)*y,z);o.rotation_euler.z=a
    elif kind=='shooter':
        spine(3.3,.50);sensor(0,-.4,.25)
        for side in [-1,1]:
            loft_y('ArmorPod_'+str(side),[(-2.3,1.45,.05,.04,0),(-1.8,1.45,.55,.42,.14),(1.2,1.45,.55,.5,.15),(2.0,1.45,.12,.17,.08)],'paint',24,28,side)
            gun(side,.95,.2,4.5);nacelle(side,1.45,-1.5,.6)
            for j in range(3):box('ArmorVent_%d_%d'%(side,j),(side*1.6,j*.3,.65),(.45,.09,.05),'dark',.015)
    elif kind=='shield':
        spine(2.8,.38);sensor(0,.2,.3)
        for side in [-1,1]:
            a=arc('ShieldArmor_'+str(side),3.4,2.25,.10 if side==1 else math.pi/2,.5*math.pi-.20,.1,.48,'paint',28)
            a.rotation_euler.z=0 if side==1 else 0
        arc('ShieldFrame',3.5,2.15,0,math.pi,.0,.20,'dark',48)
        arc('ShieldEmitter',2.22,2.17,.12,math.pi-.24,.30,.055,'energy',48)
        for side in [-1,1]:nacelle(side,.55,-1.35,.6)
    else:
        spine(3.9,.88);sensor(0,-.1,.34)
        for side in [-1,1]:
            for y in [-1.7,1.3]:
                before=set(LOW.objects);nacelle(side,1.45,y,.76)
                for o in set(LOW.objects)-before:o.name+='_'+str(y)
            box('ArmorShoulder_'+str(side),(side*.88,0,.55),(.7,3.5,.27),'paint',.16)
            for j in range(5):box('HeavyVent_%d_%d'%(side,j),(side*.88,-.6+j*.28,.72),(.49,.09,.06),'metal',.015)

def capital(kind):
    if kind==1:
        spine(4.6,.72);sensor(0,-.25,.42)
        for side in [-1,1]:
            box('CarrierShoulder_'+str(side),(side*2.1,-.2,.1),(2.4,4.6,.8),'paint',.26)
            for y in [-1.7,1.5]:
                disc('BatterySocket_%s_%s'%(side,y),(side*2.1,y,.62),.63,.23,'metal')
                disc('BatteryRecess_%s_%s'%(side,y),(side*2.1,y,.78),.48,.10,'dark')
                gun(side,1.96,y+.15,1.3,.99)
                gun(side,2.24,y+.15,1.3,.99)
                nacelle(side,3.0,y,.7)
    elif kind==2:
        sensor(0,0,.6)
        for side in [-1,1]:
            p=[(-4.6,1.35,.02,.04,0),(-3,1.55,.27,.32,.15),(0,1.2,.46,.48,.23),(2.8,.85,.24,.31,.13),(4.6,.40,.015,.03,0)]
            loft_y('WingBlade_'+str(side),p,'paint',34,30,side)
            loft_y('WingBladeFrame_'+str(side),[(y,x,rx*1.1,rz*.9,z-.15)for y,x,rx,rz,z in p],'dark',30,28,side)
            tube('WingBladeLight_'+str(side),[(side*x,y,z+rz+.012)for y,x,rx,rz,z in p[1:-1]],.025,'energy',2)
            box('CoreStrut_'+str(side),(side*.65,0,.12),(1.1,.26,.25),'metal',.06)
    elif kind==3:
        sensor(0,0,.68);disc('ReactorHull',(0,0,.13),1.05,.65,'dark')
        for i in range(6):
            a=i*math.tau/6;before=set(LOW.objects)
            box('ShieldPetal_'+str(i),(0,2.65,.24),(1.6,1.7,.68),'paint',.23)
            box('ShieldPetalFrame_'+str(i),(0,2.65,.01),(1.75,1.85,.42),'dark',.20)
            box('ShieldPanelInset_'+str(i),(0,2.65,.595),(.85,.9,.055),'metal',.08)
            box('ShieldPanelPlate_'+str(i),(0,2.65,.635),(.72,.76,.035),'paint',.06)
            for j in range(3):box('ShieldVent_%s_%s'%(i,j),(0,2.37+j*.22,.675),(.43,.045,.035),'dark',.008)
            box('ShieldArm_'+str(i),(0,1.55,.15),(.28,1.7,.25),'metal',.06)
            box('ShieldSlit_'+str(i),(0,2.66,.61),(.80,.09,.04),'energy',.015)
            for o in set(LOW.objects)-before:
                o.location=Vector((-math.sin(a)*o.location.y,math.cos(a)*o.location.y,o.location.z));o.rotation_euler.z=a
        arc('CoreRing',1.18,1.10,0,math.tau,.52,.08,'energy',48)
    elif kind==4:
        spine(5.3,.62);sensor(.9,-.1,.43)
        gun(1,0,2.2,5.2)
        for side in [-1,1]:
            nacelle(side,.85,-3,.75)
            loft_y('ArmorShoulder_'+str(side),[(-2.7,1.15,.02,.03,.1),(-1.4,1.15,.45,.42,.25),(1.1,.8,.22,.32,.25),(1.9,.7,.01,.02,.1)],'paint',24,28,side)
        box('SensorOutrigger',(1.3,-.1,.15),(2.1,.3,.3),'metal',.04)
        crescent('WingOutrigger',1,[(.6,.6,-.7,.18,.12),(1.5,.4,-.8,.2,.1),(2.8,-.5,-1.0,.01,.02)])
    elif kind==5:
        spine(3.5,.38);sensor(0,0,.44)
        for side in [-1,1]:
            p=[(.4,1.1,-1.5,.19,.14),(1.2,2.4,-1.9,.22,.12),(2.2,2.3,-1.7,.15,.08),(3.4,1.15,-1.4,.015,0)]
            crescent('WingSpectral_'+str(side),side,p,'paint')
            crescent('WingSpectralFrame_'+str(side),side,[(x*1.025,a,b,h*.9,z-.12)for x,a,b,h,z in p],'dark')
            wing_finish(side,p)
            arc('ShieldPhase_'+str(side),2.4,2.31,0 if side==1 else math.pi,math.pi*.83,.5,.08,'energy',32)
            nacelle(side,2.4,-.8,.68)
    else:
        spine(5.1,.52);sensor(0,0,.34)
        disc('ReactorWell',(0,0,.2),1.10,.55,'dark')
        arc('ReactorHalo',.82,.75,0,math.tau,.65,.06,'amber',48)
        for radius,segments,label in [(3.7,8,'Rotor0'),(2.1,6,'Rotor1')]:
            for i in range(segments):
                a=i*math.tau/segments
                arc(label+'_Armor_'+str(i),radius,radius-.5,a+.035,math.tau/segments-.07,.15,.42,'paint',10)
                arc(label+'_Frame_'+str(i),radius+.045,radius-.57,a+.02,math.tau/segments-.04,.02,.16,'dark',10)
                arc(label+'_Energy_'+str(i),radius-.18,radius-.23,a+.08,math.tau/segments-.16,.60,.035,'amber',10)
                arc(label+'_Recess_'+str(i),radius-.10,radius-.36,a+.19,math.tau/segments-.38,.565,.015,'dark',8)
        for i in range(8):
            a=i*math.tau/8+.39
            before=set(LOW.objects)
            disc('WeaponSocket_'+str(i),(0,3.4,.59),.20,.14,'metal')
            cylinder('WeaponTurret_'+str(i),(0,3.4,.73),.075,.65,'metal',20)
            for o in set(LOW.objects)-before:
                x,y,z=o.location;o.location=(math.cos(a)*x-math.sin(a)*y,math.sin(a)*x+math.cos(a)*y,z);o.rotation_euler.z+=a
        for i in range(8):
            a=i*math.tau/8
            o=box('ReactorSpoke_'+str(i),(0,2.1,.1),(.18,3.0,.24),'metal',.04)
            o.location=Vector((-math.sin(a)*2.1,math.cos(a)*2.1,.1));o.rotation_euler.z=a
        for side in [-1,1]:nacelle(side,.72,-3.8,.7)

def hostile_role(obj):
    if 'Rotor0' in obj.name:return 'Rotor0'
    if 'Rotor1' in obj.name:return 'Rotor1'
    return role(obj)

def surface_seams():
    hull=next((o for o in LOW.objects if o.name=='SM_MainFuselage'),None)
    if hull is None:return
    for y in [-2.0,-1.3,1.8,2.6]:
        points=[]
        for j in range(17):
            x=-1.2+j*.15
            hit,loc,normal,_=hull.ray_cast(Vector((x,y,10)),Vector((0,0,-1)))
            if hit and normal.z>.2:points.append(tuple(loc+normal*.012))
        if len(points)>2:tube('HullPanelSeam_'+str(y),points,.013,'dark',1)

targets=[('enemy',i)for i in range(6)]+[('boss',i)for i in range(1,7)]
requested=sys.argv[sys.argv.index('--')+1:]if '--'in sys.argv else []
if requested:
    targets=[(f,n)for f,n in targets if f+'-'+str(n)in requested]
    reports=[r for r in json.loads((ART/'manifest.json').read_text())if r['key']not in requested]
for faction,n in targets:
    reset_scene();key=faction+'-'+str(n);source=ART/key;source.mkdir(exist_ok=True)
    palette_index=n if faction=='enemy'else [0,0,5,2,1,3,4][n]
    M['paint'].node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*COLORS[palette_index],1)
    energy=LIGHTS[palette_index];p=M['energy'].node_tree.nodes['Principled BSDF'];p.inputs['Base Color'].default_value=(*energy,1);p.inputs['Emission Color'].default_value=(*energy,1)
    if faction=='boss'and n==6:
        M['paint'].node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.52,.48,.36,1)
        p.inputs['Base Color'].default_value=(1,.60,.12,1);p.inputs['Emission Color'].default_value=(1,.60,.12,1)
    enemy(['normal','fast','swift','shooter','shield','tank'][n])if faction=='enemy'else capital(n)
    surface_seams()
    construction=collection('COL_EditableConstruction')
    for obj in list(LOW.objects):
        copy=obj.copy();copy.data=obj.data.copy();construction.objects.link(copy);copy.hide_render=True;copy.hide_set(True)
        group='Hull'if faction=='enemy'else hostile_role(obj)
        select([obj])
        if obj.type=='CURVE':bpy.ops.object.convert(target='MESH')
        apply_modifiers(obj)
        bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(obj.data);bm.free()
        obj.vertex_groups.new(name=group).add(list(range(len(obj.data.vertices))),1,'REPLACE')
    lo=join(list(LOW.objects),'SM_Game_Combined');hi=lo.copy();hi.data=lo.data.copy();HIGH.objects.link(hi);hi.name='SM_High_Source';hi.data.calc_loop_triangles()
    budget=4200 if faction=='enemy'else 14000
    if len(hi.data.loop_triangles)>budget:
        dec=lo.modifiers.new('Runtime budget','DECIMATE');dec.ratio=budget/len(hi.data.loop_triangles);apply_modifiers(lo)
    bm=bmesh.new();bm.from_mesh(lo.data);bmesh.ops.triangulate(bm,faces=list(bm.faces));bad=sum(not e.is_manifold for e in bm.edges);bm.to_mesh(lo.data);bm.free()
    if bad:raise RuntimeError(key+' has non-manifold edges '+str(bad))
    select([lo]);bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=math.radians(62),island_margin=.01);bpy.ops.object.mode_set(mode='OBJECT')
    bake(lo,hi,source,512 if faction=='enemy'else 1024);parts=split_roles(lo);select(parts)
    bpy.ops.export_scene.gltf(filepath=str(DEST/(key+'.glb')),export_format='GLB',use_selection=True,export_apply=True,export_tangents=True,export_yup=True)
    cam=rig();cam.data.ortho_scale=13 if n in [4,6]and faction=='boss'else 12
    render(cam,'hero',(10,-13,13),source);render(cam,'top',(0,0,18),source)
    bpy.ops.wm.save_as_mainfile(filepath=str(source/(key+'-source.blend')))
    tris=0
    for o in parts:o.data.calc_loop_triangles();tris+=len(o.data.loop_triangles)
    report={'key':key,'triangles':tris,'budget':budget,'non_manifold_edges':bad,'parts':[o.name for o in parts],'editable_parts':len(construction.objects),'reference':'assets/art-direction/v2/fleet.png','texture_size':512 if faction=='enemy'else 1024}
    (source/'validation.json').write_text(json.dumps(report,indent=2));reports.append(report);(ART/'manifest.json').write_text(json.dumps(reports,indent=2));print('HOSTILE_VALIDATED',json.dumps(report),flush=True)
print('BLENDER_HOSTILES_COMPLETE',len(reports),flush=True)
