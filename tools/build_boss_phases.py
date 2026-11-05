"""Derive deployed mechanical assemblies from the authored Blender hulls, retaining UVs/PBR."""
import bpy, math, json
from pathlib import Path
from mathutils import Vector, Matrix
ROOT=Path(__file__).resolve().parents[1]
ART=ROOT/'assets/art-direction/hostiles-blender'
DEST=ROOT/'assets/ships/blender-hostiles'
reports=[]
for kind,phase in [(i,2) for i in range(1,7)]+[(6,3)]:
    bpy.ops.wm.open_mainfile(filepath=str(ART/f'boss-{kind}'/f'boss-{kind}-source.blend'))
    parts=[o for o in bpy.data.objects if o.type=='MESH' and o.name.startswith('SM_') and not o.hide_render and not o.name.startswith('SM_High')]
    if not parts: raise RuntimeError('No runtime meshes')
    for obj in parts:
        name=obj.name
        # Edit vertices rather than object origins: split meshes share the common atlas pivot.
        for v in obj.data.vertices:
            p=v.co
            side=1 if p.x>=0 else -1
            if kind==1:
                if 'Weapon' in name: p.x+=side*.52; p.y+=.65; p.z+=.18
                elif abs(p.x)>1.4: p.x+=side*.5; p.z+=.16
            elif kind==2 and 'Wing' in name:
                p[:]=Matrix.Rotation(side*math.radians(-22),3,'Z')@p
                p.x+=side*.5; p.z+=.25
            elif kind==3 and 'Shield' in name:
                sector=round(math.atan2(-p.x,p.y)/(math.tau/6))*(math.tau/6)
                radial=Vector((-math.sin(sector),math.cos(sector),0))
                center=radial*2.65
                tangent=Vector((math.cos(sector),math.sin(sector),0))
                p[:]=center*1.30+Matrix.Rotation(math.radians(48),3,tangent)@(p-center)
            elif kind==4:
                if 'Weapon' in name: p.y*=1.25; p.z+=.18
                elif 'Wing' in name or 'Engine' in name: p.x*=1.55; p.z+=.25
            elif kind==5:
                if 'Wing' in name: p.x*=1.28; p.y+=abs(p.x)*.32; p.z+=.30
                elif 'Shield' in name: p.x*=1.30; p.y*=.85
            elif kind==6:
                if 'Rotor0' in name: p.x*=1.16; p.y*=.84; p.z+=.45 if phase==2 else .90
                elif 'Rotor1' in name:
                    p[:]=Matrix.Rotation(math.radians(26 if phase==2 else 55),3,'Z')@p
                    p.x*=.90 if phase==2 else .72; p.z+=.72 if phase==2 else 1.4
                elif 'Weapon' in name: p.x*=1.22; p.y*=1.22; p.z+=.4
                elif phase==3: p.z*=1.3
        obj.data.update()
    if kind==6 and phase==3:
        metal=next(m for m in bpy.data.materials if m.name.startswith('MAT_BrushedMetal'))
        for j in range(3):
            bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=.72-j*.15,depth=.55,location=(0,0,.8+j*.5))
            obj=bpy.context.object;obj.name='SM_CoreCannon_'+str(j);obj.data.materials.append(metal)
            bevel=obj.modifiers.new('Machined edge','BEVEL');bevel.width=.05;bevel.segments=3
            for poly in obj.data.polygons:poly.use_smooth=True
            parts.append(obj)
    bpy.ops.object.select_all(action='DESELECT')
    for o in parts: o.select_set(True)
    bpy.context.view_layer.objects.active=parts[0]
    key=f'boss-{kind}-p{phase}'
    bpy.ops.export_scene.gltf(filepath=str(DEST/(key+'.glb')),export_format='GLB',use_selection=True,export_apply=True,export_tangents=True,export_yup=True)
    source=ART/key;source.mkdir(exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(source/(key+'-source.blend')))
    triangles=0
    for obj in parts:
        obj.data.calc_loop_triangles();triangles+=len(obj.data.loop_triangles)
    if triangles>15000:raise RuntimeError(key+' exceeds phase budget')
    report={'key':key,'triangles':triangles,'budget':15000,'parts':[o.name for o in parts],'source':f'boss-{kind}','method':'deployed articulated mesh; original UV and normal/AO retained'}
    reports.append(report)
    print('PHASE_EXPORTED',key,len(parts),flush=True)
(ART/'phase-manifest.json').write_text(json.dumps(reports,indent=2))
print('BOSS_PHASES_COMPLETE',len(reports),flush=True)
