"""Volume-first original hostile fleet. Image-2 silhouettes are reconstructed as actual
closed curved armor, separate weapons and mechanisms. No projected concept-art textures.
"""
from pathlib import Path
import sys,math,json,bpy,bmesh
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[1]
helper=(ROOT/'tools/build_blender_hostiles.py').read_text(encoding='utf-8')
exec(compile(helper.split("targets=[('enemy'")[0],str(ROOT/'tools/build_blender_hostiles.py'),'exec'))
DEST=ROOT/'assets/ships/hostiles-final';ART=ROOT/'assets/art-direction/hostiles-final'
DEST.mkdir(parents=True,exist_ok=True);ART.mkdir(parents=True,exist_ok=True);(ART/'.gdignore').touch()
reports=[]

def plated_pod(side,x,y,length,width=.65,height=.5,label='ArmorPod'):
    profiles=[(-length*.52+y,x,.04,.03,.1),(-length*.4+y,x,width*.8,height*.8,.12),(length*.28+y,x,width,height,.16),(length*.5+y,x,width*.4,height*.45,.14),(length*.6+y,x,.025,.03,.1)]
    loft_y(label+'_'+str(side),profiles,'paint',24,24,side)
    for j in range(4):box(label+'Vent_'+str(side)+'_'+str(j),(side*x,y-.8+j*.3,height+.17),(width*.8,.075,.05),'dark',.012)
    box(label+'Inset_'+str(side),(side*x,y+.45,height+.16),(width*.65,.6,.04),'metal',.025)

def boss_v5(kind):
    if kind==1:
        spine(4.8,.68);canopy(.85,1,.7)
        for side in [-1,1]:
            plated_pod(side,1.65,0,5.2,.72,.55,'WingBattery')
            box('WingBatteryFrame_'+str(side),(side*1.65,-.1,.05),(1.5,4.0,.3),'dark',.13)
            for x in [1.36,1.94]: gun(side,x,1.5,3.5)
            nacelle(side,1.6,-2,.7)
            box('WeaponSocket_'+str(side),(side*1.65,.6,.82),(.9,1.3,.25),'paint',.12)
    elif kind==2:
        spine(5,.36);canopy(1.1,.8,.6)
        for side in [-1,1]:
            p=[(.42,2.8,-2.4,.32,.12),(1.0,1.9,-2.2,.34,.18),(2.2,-.3,-1.9,.24,.19),(3.2,-1.4,-1.65,.04,.16)]
            crescent('WingScythe_'+str(side),side,p)
            crescent('WingScytheFrame_'+str(side),side,[(x*1.03,a,b,h*.8,z-.15)for x,a,b,h,z in p],'metal')
            wing_finish(side,p);gun(side,.65,1.6,2.5);nacelle(side,.65,-2.5,.6)
    elif kind==3:
        spine(4.2,1.1);canopy(.7,1,.9)
        box('HullFlightDeck',(0,-.2,.7),(2.5,4.2,.3),'paint',.23)
        box('HullBridge',(0,-.6,1.05),(1.15,1.8,.45),'paint',.17)
        for side in [-1,1]:
            plated_pod(side,2,0,4.3,.86,.5,'ShieldCarrier')
            box('BayDoor_'+str(side),(side*2,0,.7),(.7,2.4,.1),'dark',.05)
            for y in [-.9,.2,1.3]:
                gun(side,1.7,y,1.6)
                box('ShieldSlit_'+str(side)+'_'+str(y),(side*2.45,y,.58),(.08,.55,.04),'energy',.015)
            nacelle(side,2,-2,.65)
    elif kind==4:
        spine(5.7,.42);canopy(1.15,.7,.55)
        for side in [-1,1]:
            plated_pod(side,.92,-1.5,4.1,.42,.4,'WingRail')
            gun(side,.55,2.6,5.5)
            box('WeaponRailHousing_'+str(side),(side*.55,.8,.3),(.4,3.9,.45),'paint',.12)
            nacelle(side,.92,-3,.85)
    elif kind==5:
        spine(4.0,.42);canopy(.9,.85,.55)
        for side in [-1,1]:
            k=1 if side==1 else .72
            p=[(.45,1.7,-2,.28,.17),(1.4,2.6*k,-2.2,.36,.22),(2.6,1.7*k,-1.9,.22,.2),(3.8*k,.6,-1.0,.03,.17)]
            crescent('WingStealth_'+str(side),side,p);wing_finish(side,p)
            crescent('WingStealthFrame_'+str(side),side,[(x*1.035,a,b,h*.9,z-.12)for x,a,b,h,z in p],'dark')
            gun(side,2.4*k,.25,2.1);nacelle(side,1.2,-2,.7)
    else:
        spine(5.2,.72)
        for side in [-1,1]:
            p=[(.6,3.8,-3.6,.55,.12),(1.7,2.2,-3.5,.58,.22),(3.0,.3,-3.2,.4,.2),(4.2,-1.8,-3.0,.04,.10)]
            crescent('WingMothership_'+str(side),side,p);wing_finish(side,p)
            crescent('WingOuterFrame_'+str(side),side,[(x*1.03,a,b,h*.9,z-.2)for x,a,b,h,z in p],'dark')
            for x in [1.1,1.65,2.2]:gun(side,x,1.5-x*.5,3.5)
            plated_pod(side,2.6,-1.8,2,.55,.32,'ShieldMantle')
            nacelle(side,2.2,-3.0,.9)
        box('HullReactorTrench',(0,.1,.73),(.7,3.3,.2),'dark',.08)
        loft_y('ReactorCore',[(-1.5,0,.05,.04,.87),(-1.2,0,.18,.14,.87),(.8,0,.20,.18,.87),(1.5,0,.03,.04,.87)],'energy',20,20)
        canopy(.45,.7,.94)

def tactical(kind):
    # All six have independent closed-volume construction, rather than recolored copies.
    if kind=='repair':
        spine(3,.6);disc('RepairCore',(0,0,.4),.65,.5,'glass')
        for side in [-1,1]:plated_pod(side,1.5,0,2.5,.45,.3,'WingRepair');nacelle(side,.7,-1.5,.6)
    elif kind=='minelayer':
        spine(3.5,.9)
        for side in [-1,1]:
            plated_pod(side,1.3,0,3,.55,.4,'BayMine')
            for y in [-.9,0,.9]:disc('WeaponMine_'+str(side)+'_'+str(y),(side*1.3,y,.6),.30,.2,'metal')
    elif kind=='projector':
        spine(2.5,.5)
        for side in [-1,1]:
            p=[(.5,1.6,-1.6,.25,.2),(1.3,1.9,-1.7,.3,.2),(2.6,.5,-.5,.03,.2)]
            crescent('ShieldEmitter_'+str(side),side,p);wing_finish(side,p)
            box('ShieldSlot_'+str(side),(side*1.4,.2,.55),(.1,1.4,.08),'energy',.02)
    elif kind=='splitter':
        spine(2.8,.55)
        for side in [-1,1]:plated_pod(side,1.1,-.2,3,.65,.45,'WingBud');nacelle(side,1,-1.4,.45)
        disc('HullBrood',(0,.6,.7),.45,.25,'dark')
    elif kind=='tractor':
        spine(3.1,.65)
        for side in [-1,1]:
            gun(side,1.1,1.5,2.8);plated_pod(side,1.4,-.4,2.5,.38,.35,'WingProng')
        disc('HullCoil',(0,.1,.65),.55,.3,'metal');disc('HullCoilInset',(0,.1,.83),.3,.1,'energy')
    else:
        spine(3.7,.32)
        for side in [-1,1]:
            p=[(.3,.8,-1.9,.2,.12),(1.4,.35,-1.8,.2,.12),(3.2,-.7,-1.3,.02,.08)]
            crescent('WingBomber_'+str(side),side,p);wing_finish(side,p)
            plated_pod(side,1.2,-.5,2,.35,.28,'WeaponBomb')
            nacelle(side,.6,-1.6,.55)

targets=[('boss',i)for i in range(1,7)]+[('tactical',i)for i in range(6)]
requested=sys.argv[sys.argv.index('--')+1:]if '--'in sys.argv else []
if requested: targets=[(role,i)for role,i in targets if f'{role}-{i}'in requested]
for role_name,kind in targets:
    reset_scene();key=f'{role_name}-{kind}';source=ART/key;source.mkdir(exist_ok=True)
    palette=([0,0,5,2,1,3,4][kind]if role_name=='boss'else [2,1,3,5,3,0][kind])
    final_colors=[(.23,.035,.045),(.30,.14,.035),(.12,.16,.065),(.15,.22,.28),(.43,.44,.41),(.15,.075,.24)]
    M['paint'].node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*final_colors[palette],1)
    energy=LIGHTS[palette]
    for name in ['Base Color','Emission Color']:M['energy'].node_tree.nodes['Principled BSDF'].inputs[name].default_value=(*energy,1)
    if role_name=='boss':boss_v5(kind)
    else:tactical(['repair','minelayer','projector','splitter','tractor','bomber'][kind])
    surface_seams()
    for obj in list(LOW.objects):
        group=hostile_role(obj);select([obj])
        if obj.type=='CURVE':bpy.ops.object.convert(target='MESH')
        apply_modifiers(obj)
        obj.vertex_groups.new(name=group).add(list(range(len(obj.data.vertices))),1,'REPLACE')
    lo=join(list(LOW.objects),'SM_Game_Combined')
    hi=lo.copy();hi.data=lo.data.copy();HIGH.objects.link(hi);hi.name='SM_High_Source'
    hi.data.calc_loop_triangles();budget=14000 if role_name=='boss'else 4500
    if len(hi.data.loop_triangles)>budget:
        dec=lo.modifiers.new('Runtime budget','DECIMATE');dec.ratio=budget/len(hi.data.loop_triangles);apply_modifiers(lo)
    select([lo]);bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=math.radians(62),island_margin=.012);bpy.ops.object.mode_set(mode='OBJECT')
    bake(lo,hi,source,1024 if role_name=='boss'else 512)
    parts=split_roles(lo)
    for obj in parts:
        select([obj]);tri=obj.modifiers.new('Export triangles','TRIANGULATE');apply_modifiers(obj);obj.data.calc_loop_triangles()
    select(parts)
    bpy.ops.export_scene.gltf(filepath=str(DEST/(key+'.glb')),export_format='GLB',use_selection=True,export_apply=True,export_tangents=True,export_yup=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(source/(key+'-source.blend')))
    triangles=sum(len(o.data.loop_triangles) for o in parts)
    reports.append({'key':key,'triangles':triangles,'budget':budget,'parts':[o.name for o in parts],'reference':'../combat-expansion/boss-deployment-concepts.png','method':'closed curved geometry with baked normals/AO; no concept projection'})
    if role_name=='boss':
        # All states retain the same UV and mechanical parts; animation drives their pivots.
        for phase in range(2,4 if kind==6 else 3):
            for obj in parts:
                for vertex in obj.data.vertices:
                    p=vertex.co;side=1 if p.x>=0 else -1
                    if obj.name.startswith(('SM_Wing','SM_Shield','SM_Bay')):p.x*=1.55;p.z+=.28
                    if obj.name.startswith('SM_Weapon'):p.x+=side*.25;p.y+=.35;p.z+=.15
                    if kind==6 and phase==3:p.z*=1.12
                obj.data.update()
            select(parts)
            bpy.ops.export_scene.gltf(filepath=str(DEST/(key+f'-p{phase}.glb')),export_format='GLB',use_selection=True,export_apply=True,export_tangents=True,export_yup=True)
    (ART/'manifest.json').write_text(json.dumps(reports,indent=2))
    print('FINAL_HOSTILE_EXPORTED',key,flush=True)
print('FINAL_HOSTILES_COMPLETE',len(reports),flush=True)
