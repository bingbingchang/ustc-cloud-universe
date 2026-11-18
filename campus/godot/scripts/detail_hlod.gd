extends Node
## Preserve original plants nearby and match them to their baked views.

const VegetationLOD = preload("res://scripts/vegetation_lod.gd")
const ASSETS = ["study_flower_mound_0", "study_flower_mound_1", "study_bank_patch_0",
	"study_bank_patch_1", "sakura_shrub_0", "sakura_shrub_1", "sakura_shrub_2"]

var game


func _ready() -> void:
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/runtime_hlod/manifest.json"))
	var groups := VegetationLOD.groups(game.world, manifest.assets, func(asset): return asset in ASSETS)
	var meshes := {}
	var plants := 0
	for index in groups.size():
		var group: Dictionary = groups[index]
		var spec: Dictionary = manifest.assets[group.asset]
		var node := VegetationLOD.impostor_batch(spec, group.placements, VegetationLOD.atlas_quad(spec, meshes))
		node.name = "DetailFar_%d" % index
		VegetationLOD.pair(node, group.near, 21.0, 90.0, 8.0)
		game.world.add_child(node)
		plants += group.placements.size()
	print("DETAIL_HLOD_READY groups=", groups.size(), " plants=", plants)
