extends RefCounted
## Distinct coatings; only bare hardware receives subtle shared grain, never oversized black seams.
static var brushed: Texture2D

static func metal_grain() -> Texture2D:
	if brushed: return brushed
	var image:=Image.create(128,128,false,Image.FORMAT_RGB8)
	for y in 128:
		for x in 128:
			var hash_value: int=((x*73856093)^(y*19349663))&255
			var value:=0.965+sin(y*0.8)*0.012+(hash_value/255.0-0.5)*0.012
			image.set_pixel(x,y,Color(value,value,value))
	image.generate_mipmaps()
	brushed=ImageTexture.create_from_image(image)
	return brushed

static func make(color: Color,slot: int) -> StandardMaterial3D:
	var mat:=StandardMaterial3D.new()
	mat.albedo_color=color
	mat.cull_mode=BaseMaterial3D.CULL_BACK
	match slot:
		0:
			mat.metallic=0.38
			mat.roughness=0.55
		1:
			mat.metallic=0.18
			mat.roughness=0.38
			mat.clearcoat_enabled=true
			mat.clearcoat=0.35
			mat.clearcoat_roughness=0.26
		2:
			mat.metallic=0.82
			mat.roughness=0.26
			mat.albedo_texture=metal_grain()
			mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		3:
			mat.metallic=0.05
			mat.roughness=0.10
			mat.clearcoat_enabled=true
			mat.clearcoat=0.8
			mat.clearcoat_roughness=0.08
		4:
			mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color=color*0.65
			mat.emission_enabled=true
			mat.emission=color*0.4
			mat.emission_energy_multiplier=0.8
		5:
			mat.metallic=0.45
			mat.roughness=0.32
	return mat
