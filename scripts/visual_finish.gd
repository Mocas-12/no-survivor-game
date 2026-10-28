extends RefCounted
## Presentation-only environment and sample count; viewport geometry and input coordinates stay intact.
static func apply(scene: Node3D) -> void:
	scene.get_viewport().msaa_3d=Viewport.MSAA_2X if DisplayServer.is_touchscreen_available() else Viewport.MSAA_4X
	var environments:=scene.find_children("*","WorldEnvironment",true,false)
	if not environments.is_empty():
		var env: Environment=environments[0].environment
		env.ambient_light_color=Color(0.55,0.65,0.8)
		env.ambient_light_energy=0.35
		var sky:=Sky.new()
		var material:=ProceduralSkyMaterial.new()
		material.sky_top_color=Color(0.08,0.13,0.23)
		material.sky_horizon_color=Color(0.68,0.75,0.84)
		material.ground_bottom_color=Color(0.02,0.03,0.05)
		material.ground_horizon_color=Color(0.3,0.36,0.44)
		sky.sky_material=material
		sky.radiance_size=Sky.RADIANCE_SIZE_128
		env.sky=sky
		env.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
	var suns:=scene.find_children("*","DirectionalLight3D",true,false)
	if not suns.is_empty():
		suns[0].rotation_degrees=Vector3(-30,-25,0)
		suns[0].light_color=Color(1.0,0.95,0.88)
		suns[0].light_energy=1.05
	if not scene.has_node("FinishFill"):
		var fill:=DirectionalLight3D.new()
		fill.name="FinishFill"
		fill.rotation_degrees=Vector3(25,30,0)
		fill.light_color=Color(0.58,0.73,1.0)
		fill.light_energy=0.3
		fill.shadow_enabled=false
		scene.add_child(fill)
