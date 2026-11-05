"""Diagnostic silhouette registration; does not alter source concept or model renders."""
from pathlib import Path
import json
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

root=Path(__file__).resolve().parents[1]
out=root/'assets/art-direction/branches/blender-assault'
reference=Image.open(root/'assets/art-direction/branches/concept.png').convert('RGB')
# Only the left spacecraft is the contract for this prototype.
region=reference.crop((0,0,590,reference.height))
rgb=np.asarray(region).astype(float)
luma=rgb@np.array([.2126,.7152,.0722])
mask=Image.fromarray(np.where(luma>42,255,0).astype('uint8'))
mask=mask.filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.MinFilter(3))
flood=mask.copy(); ImageDraw.floodfill(flood,(0,0),128,thresh=0)
filled=Image.fromarray(np.where(np.asarray(flood)==128,0,255).astype('uint8'))
ref_box=filled.getbbox()
ref=filled.crop(ref_box)
render=Image.open(out/'top_mask.png').convert('RGBA').getchannel('A')
render=render.point(lambda value:255 if value>127 else 0)
render_box=render.getbbox()
render=render.crop(render_box)
ref_ratio=ref.width/ref.height; model_ratio=render.width/render.height
model=render.resize(ref.size,Image.Resampling.NEAREST)
a=np.asarray(ref)>0;b=np.asarray(model)>0
iou=float(np.logical_and(a,b).sum()/np.logical_or(a,b).sum())
report={'reference_crop':[0,0,590,reference.height],'reference_bbox':list(ref_box),'render_bbox':list(render_box),'bbox_registered_iou':iou,'aspect_ratio_relative_error':abs(model_ratio/ref_ratio-1),'interpretation':'Diagnostic after bounding-box alignment; not a material/depth score or production acceptance claim. Reference mask inferred from luminance and hole filling.'}
(out/'reference-comparison.json').write_text(json.dumps(report,indent=2))
overlay=np.zeros((*a.shape,3),dtype='uint8');overlay[a&b]=[204,217,222];overlay[a&~b]=[255,77,56];overlay[b&~a]=[38,204,255]
canvas=Image.new('RGB',((ref.width+20)*3,ref.height+90),'#101b2a')
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',18)
draw=ImageDraw.Draw(canvas)
for i,(label,img) in enumerate([('Concept silhouette',region.crop(ref_box)),('Actual model silhouette',model),('BBox-aligned IoU %.3f'%iou,Image.fromarray(overlay))]):
 canvas.paste(img,(i*(ref.width+20)+10,70));draw.text((i*(ref.width+20)+10,15),label,font=font,fill='white')
draw.text((2*(ref.width+20)+10,40),'Red: concept only / Cyan: model only',font=font,fill='white')
canvas.save(out/'reference-comparison.png')
print(json.dumps(report))
