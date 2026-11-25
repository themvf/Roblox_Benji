"""Extract the chair's maps and create a restrained yellow upholstery stain.

Uses the saved GLB's mapped base-color image. The bright upholstery is tinted
locally; dark frame and wheel pixels are excluded by the brightness mask.
"""
from pathlib import Path
import hashlib
import io
import json

import numpy as np
from PIL import Image, ImageFilter

import gltf_post

ROOT=Path(__file__).resolve().parents[1]
PKG=ROOT/"assets/models/office-chair"
SOURCE=PKG/"source/trellis-original.glb"
EXPECTED="588cacb7a220d74a93a05a1f599ced4836eded2c5ab31e5b09c17af4c5961a01"
if hashlib.sha256(SOURCE.read_bytes()).hexdigest()!=EXPECTED:
    raise RuntimeError("Office chair source changed; reappraise before generating textures")
doc,blob=gltf_post.read_glb(SOURCE)
mat=doc["materials"][0]["pbrMetallicRoughness"]

def embedded_image(texture_index):
    texture=doc["textures"][texture_index]
    image_index=texture.get("source")
    if image_index is None:
        image_index=texture["extensions"]["EXT_texture_webp"]["source"]
    view=doc["bufferViews"][doc["images"][image_index]["bufferView"]]
    offset=view.get("byteOffset",0)
    return Image.open(io.BytesIO(blob[offset:offset+view["byteLength"]])).convert("RGBA")

clean=embedded_image(mat["baseColorTexture"]["index"])
packed=embedded_image(mat["metallicRoughnessTexture"]["index"])
if clean.size!=(2048,2048) or packed.size!=(2048,2048):
    raise RuntimeError("Expected two 2048-pixel source maps")
out=PKG/"textures"
out.mkdir(parents=True,exist_ok=True)
clean.save(PKG/"source/trellis-color.png")
packed.save(PKG/"source/trellis-metallic-roughness.png")
clean.save(out/"OfficeChair_Clean_Color.png")
packed.save(out/"OfficeChair_MetallicRoughness.png")

arr=np.asarray(clean,dtype=np.float32)/255.0
h,w=arr.shape[:2]
yy,xx=np.mgrid[:h,:w].astype(np.float32)
field=np.zeros((h,w),dtype=np.float32)
# A few small marks on the broad upholstery UV islands. Most cloth stays gray.
spots=[(340,770,90,72,.42),(935,500,85,70,.24),
       (720,1185,95,70,.34),(280,1500,70,55,.20)]
for cx,cy,sx,sy,weight in spots:
    field+=weight*np.exp(-.5*(((xx-cx)/sx)**2+((yy-cy)/sy)**2))
rng=np.random.default_rng(52)
low=Image.fromarray(rng.integers(30,225,(32,32),dtype=np.uint8),"L")
low=low.resize((w,h),Image.Resampling.BICUBIC).filter(ImageFilter.GaussianBlur(21))
variation=np.asarray(low,dtype=np.float32)/255.0
field*=.65+.7*variation
luma=arr[:,:,:3]@np.array([.2126,.7152,.0722],dtype=np.float32)
bright=np.clip((luma-.40)/.30,0,1)
bright=bright*bright*(3-2*bright)
neutral=np.clip(1-np.abs(arr[:,:,0]-arr[:,:,2])/.28,0,1)
alpha=np.clip(field*bright*neutral,0,.32)
stain=np.array([.69,.60,.25],dtype=np.float32)
result=arr.copy()
result[:,:,:3]=arr[:,:,:3]*(1-alpha[:,:,None])+stain*alpha[:,:,None]
Image.fromarray(np.uint8(np.clip(result,0,1)*255+.5),"RGBA").save(
    out/"OfficeChair_YellowStained_Color.png")
metrics={"sourceSha256":EXPECTED,"textureSize":[w,h],
         "changedPixels":int((alpha>.015).sum()),
         "upholsteryCandidates":int((bright>.5).sum()),
         "peakBlend":float(alpha.max()),
         "method":"localized yellow-tan blend on bright neutral upholstery pixels; dark hardware excluded"}
(PKG/"source/stain-metrics.json").write_text(json.dumps(metrics,indent=2)+"\n",
                                          encoding="utf-8")
print(metrics)
