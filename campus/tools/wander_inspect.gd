extends SceneTree
func _initialize():call_deferred("run")
func run():
	for asset in ["wave2_doubao","wave2_meituan","wave2_leaf_cat"]:
		var n=load("res://assets/"+asset+".glb").instantiate();root.add_child(n)
		for b in n.find_children("*","Node3D",true,false):
			if "Leg" in str(b.name) or "Foot" in str(b.name) or "Shoe" in str(b.name) or "Paw" in str(b.name) or "Sole" in str(b.name) or str(b.name).begins_with("Mascot_Front") or str(b.name).begins_with("Mascot_Back"):
				print(asset," ",b.get_path()," pos=",b.position," scale=",b.scale)
		n.queue_free()
	quit()
