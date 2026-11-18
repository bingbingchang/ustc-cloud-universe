"""Apply the reference-proportioned library footprint without changing its doors.

Only library OSM 284161541 is changed. Dimensions are image estimates; the
entrance, playable upper landing and stair collision routes retain their metric
campus coordinates. Run after regenerating the legacy district manifest.
"""
import json
import math
import struct
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[1] / "godot"
COS = .9999335832569165
SIN = .011525149672913487
ORIGIN = (2.8535, 426.1915)


def world(x, z):
    return [round(ORIGIN[0] + COS*x - SIN*z, 6),
            round(ORIGIN[1] + SIN*x + COS*z, 6)]


def apply():
    manifest_path = PROJECT / "assets/library_district_manifest.json"
    data_path = PROJECT / "data/library_district.json"
    network_path = PROJECT / "data/campus_road_network.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    data = json.loads(data_path.read_text(encoding="utf-8"))
    network = json.loads(network_path.read_text(encoding="utf-8"))
    outline = [world(x, z) for x, z in [(-36,-25.5),(36,-25.5),(36,0),
        (15.7,0),(15.7,.4),(5.9,.4),(5.9,0),(-5.9,0),(-5.9,.4),
        (-15.7,.4),(-15.7,0),(-36,0)]]
    for catalog in (manifest, data, network):
        building = next(b for b in catalog["buildings"] if b["osm_way"] == "284161541")
        building.setdefault("source_osm_outline", building["outline"])
        building["outline"] = outline
        building["height"] = 24.3
        building["confidence"] = (
            "Six uploaded multiview references define the replacement proportions; "
            "72 m width, 25.5 m depth, 24.3 m main roof and 32.1 m crown are "
            "image-derived estimates, not surveyed dimensions. The campus "
            "entrance origin and 3.18 m landing remain fixed.")
        building["replica_dimensions"] = {"width":72.0,"depth":25.5,
            "main_roof":24.3,"tower_roof":29.4,"crown_top":32.1,"estimated":True}
    asset = manifest["assets"]["south_library"]
    asset["local_placement"] = {"position":[ORIGIN[0],0,ORIGIN[1]],
        "yaw_degrees":math.degrees(-math.atan2(SIN,COS))}
    asset["coordinate_system"] = (
        "Local metres: +X east/right when viewing the entrance, +Y up, +Z "
        "outside/south; origin at original main-door edge centre.")
    asset["reference_revision"] = "library-multiview-20261117"
    glb = (PROJECT/"assets/south_library.glb").read_bytes()
    json_size,chunk_type = struct.unpack_from("<II",glb,12)
    if chunk_type == 0x4E4F534A:
        geometry = json.loads(glb[20:20+json_size])
        primitives = [part for mesh in geometry.get("meshes",[]) for part in mesh["primitives"]]
        asset["surfaces"] = len(primitives)
        asset["triangles"] = sum(geometry["accessors"][part["indices"]]["count"]//3
            for part in primitives if part.get("mode",4)==4 and "indices" in part)
    def remove(name):
        return name in ("south_library_closed_exterior","south_library_left_pier",
            "south_library_right_pier") or name.startswith(
            ("south_library_portal_","south_library_replica_"))
    solids = [s for s in manifest["collision_solids"] if not remove(s["name"])]
    # Stretch the two existing stair flights laterally; their tread heights and
    # depths stay unchanged. Always derive from the preserved pre-change shape.
    for s in solids:
        name = s["name"]
        if name == "south_library_main_landing" or name.startswith("south_library_library_"):
            s.setdefault("source_polygon", s["polygon"])
            widened = []
            guard = "_side_" in name or "_parapet_landing_" in name
            center_x = sum(COS*(px-ORIGIN[0])+SIN*(pz-ORIGIN[1])
                for px,pz in s["source_polygon"])/len(s["source_polygon"])
            for px,pz in s["source_polygon"]:
                x = COS*(px-ORIGIN[0])+SIN*(pz-ORIGIN[1])
                z = -SIN*(px-ORIGIN[0])+COS*(pz-ORIGIN[1])
                if name == "south_library_main_landing":
                    x *= 9.54/6.78
                elif guard:
                    if abs(center_x) > 5:
                        x += 1.6 if center_x > 0 else -1.6
                else:
                    sign = -1 if x < 0 else 1
                    x = sign*(2.5+(abs(x)-2.5)*(6.82/5.22))
                widened.append(world(x,z))
            s["polygon"] = widened
    def solid(name, polygon, bottom, top):
        return {"name":"south_library_"+name,"type":"polygon_prism",
            "polygon":polygon,"bottom":bottom,"top":top}
    def box(name,x0,x1,z0,z1,bottom,top):
        return solid(name,[world(x0,z0),world(x1,z0),world(x1,z1),world(x0,z1)],bottom,top)
    replacement = [solid("closed_exterior",outline,.08,24.3)]
    for side in (-1,1):
        center = side*10.8
        replacement.append(box("replica_tower_"+str(side),center-4.9,center+4.9,-7,.4,24.3,29.4))
        for layer in range(4):
            half = 9.6 - layer*.62
            depth = 4.5 - layer*.92
            center = side*(half-.56/2)
            replacement.append(box("replica_portal_"+str(side)+"_"+str(layer),
                center-.56/2,center+.56/2,depth-.56,depth,.14,14.9-layer*.7))
    at = next(i for i,s in enumerate(solids) if s["name"].startswith("south_library_"))
    solids[at:at] = replacement
    manifest["collision_solids"] = solids
    source = {"local":"references/library_multiview_20261117",
        "use":"Six user-supplied top/front/back/left/right/oblique images; estimated proportions and visible facade/roof details."}
    if source not in manifest["sources"]:
        manifest["sources"].append(source)
    for path, content in ((manifest_path,manifest),(data_path,data),(network_path,network)):
        path.write_text(json.dumps(content,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print("LIBRARY_MULTIVIEW_INTEGRATION",sum(s["name"].startswith("south_library_") for s in solids))


if __name__ == "__main__":
    apply()
