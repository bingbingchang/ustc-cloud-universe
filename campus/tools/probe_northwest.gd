extends SceneTree
func _initialize():
 var W=load("res://scripts/west_lake_garden.gd")
 for z in range(74,105,2):
  var xs=[]
  for x in range(-75,-12,2):
   if W.safe_land(Vector2(x,z),.95):xs.append(x)
  print(z,":",xs)
 quit()
