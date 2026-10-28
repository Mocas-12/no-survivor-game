extends SceneTree
func _init():
 for name in ClassDB.class_get_enum_list("Environment"):
  if "Reflect" in name: print(name,ClassDB.class_get_enum_constants("Environment",name))
 for p in ClassDB.class_get_property_list("Environment"):
  if "reflect" in str(p.name): print(p.name)
 print("MSAA",ClassDB.class_get_enum_constants("Viewport","MSAA"))
 quit()
