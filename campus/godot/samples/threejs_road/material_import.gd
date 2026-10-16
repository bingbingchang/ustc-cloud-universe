@tool
extends EditorScenePostImport

# The sample stores leaf, grass and fallen-leaf colors in glTF COLOR_0.
func _post_import(scene: Node) -> Object:
	for instance in scene.find_children("*", "MeshInstance3D", true, false):
		for surface in instance.mesh.get_surface_count():
			var arrays: Array = instance.mesh.surface_get_arrays(surface)
			var colors = arrays[Mesh.ARRAY_COLOR]
			if colors != null and colors.size() > 0:
				var material = instance.mesh.surface_get_material(surface)
				if material is BaseMaterial3D:
					material.vertex_color_use_as_albedo = true
					material.vertex_color_is_srgb = false
	return scene
