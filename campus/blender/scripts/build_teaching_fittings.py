"""Build the shared seating and classroom equipment in metres.

Teaching examples: USTC's 1101 and 2207 classroom photographs and the
Teaching Building 5 multimedia classroom guides. +Z faces the teaching wall.
"""
import argparse
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector


FINISHES = {
    "PaleAsh":         ((.48, .32, .16), .47, .0),
    "DarkWalnut":      ((.255, .135, .105), .50, .0),
    "OakVeneer":       ((.48, .30, .15), .44, .0),
    "WarmLaminate":    ((.57, .46, .32), .51, .0),
    "LightSteel":      ((.39, .43, .42), .38, .48),
    "DarkSteel":       ((.11, .14, .145), .45, .45),
    "PerforatedSteel": ((.31, .35, .34), .47, .28),
    "BluePolymer":     ((.044, .11, .177), .43, .0),
    "OffWhite":        ((.80, .78, .71), .59, .0),
    "Rubber":          ((.043, .042, .039), .82, .0),
    "Lens":            ((.038, .062, .082), .17, .32),
}


def point(p):
    return p[0], -p[2], p[1]


class Fitting:
    def __init__(self, materials):
        self.materials = materials
        self.vertices = []
        self.faces = []
        self.finishes = []
        self.smooth = []

    def rings(self, rings, finish, smooth=False):
        base = len(self.vertices)
        width = len(rings[0])
        self.vertices.extend(point(p) for ring in rings for p in ring)
        self.face([base + i for i in reversed(range(width))], finish)
        for k in range(len(rings) - 1):
            row = base + k * width
            for i in range(width):
                j = (i + 1) % width
                self.face([row + i, row + j, row + j + width, row + i + width], finish, smooth)
        end = base + (len(rings) - 1) * width
        self.face([end + i for i in range(width)], finish)

    def face(self, indices, finish, smooth=False):
        self.faces.append(indices)
        self.finishes.append(finish)
        self.smooth.append(smooth)

    def box(self, center, size, finish, clip=0.0):
        x, y, z = center
        a, h, b = (d * .5 for d in size)
        if clip:
            r = min(clip, a * .45, b * .45)
            outline = [(-a, -b+r), (-a, b-r), (-a+r, b), (a-r, b),
                       (a, b-r), (a, -b+r), (a-r, -b), (-a+r, -b)]
        else:
            outline = [(-a, -b), (-a, b), (a, b), (a, -b)]
        self.rings([[(x+u, y+level, z+v) for u,v in outline]
                    for level in (-h, h)], finish)

    def rod(self, bottom, top, radius, finish, sides=8):
        a, b = Vector(bottom), Vector(top)
        axis = (b-a).normalized()
        u = axis.cross(Vector((1, 0, 0)))
        if u.length_squared < .01:
            u = axis.cross(Vector((0, 1, 0)))
        u.normalize()
        v = axis.cross(u)
        self.rings([[center + radius * (u * math.cos(t) + v * math.sin(t))
                     for t in (math.tau*i/sides for i in range(sides))]
                    for center in (a,b)], finish, True)

    def back(self, width, finish, bottom, top, z):
        outline = [(-width*.47, bottom+.035), (-width*.5, bottom+.075),
                   (-width*.47, top-.043), (-width*.37, top),
                   (width*.37, top), (width*.47, top-.043),
                   (width*.5, bottom+.075), (width*.47, bottom+.035)]
        self.rings([[(x, y, z + depth - (y-bottom)*.21) for x,y in outline]
                    for depth in (.016, -.016)], finish)

    def build(self, name):
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata(self.vertices, [], self.faces)
        mesh.validate()
        mesh.update()
        finishes = list(dict.fromkeys(self.finishes))
        for finish in finishes:
            mesh.materials.append(self.materials[finish])
        uv = mesh.uv_layers.new()
        for polygon, finish, smooth in zip(mesh.polygons, self.finishes, self.smooth):
            polygon.material_index = finishes.index(finish)
            polygon.use_smooth = smooth
            normal = polygon.normal
            for loop in polygon.loop_indices:
                x,y,z = mesh.vertices[mesh.loops[loop].vertex_index].co
                if abs(normal.z) > .65:
                    uv.data[loop].uv = (x, y)
                elif abs(normal.y) > .65:
                    uv.data[loop].uv = (x, z)
                else:
                    uv.data[loop].uv = (y, z)
        mesh.calc_loop_triangles()
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.collection.objects.link(obj)
        print(f"{name} {len(mesh.loop_triangles)} triangles")
        return obj


def bench(part, style):
    timber, steel = {
        "one": ("PaleAsh", "LightSteel"),
        "two": ("DarkWalnut", "LightSteel"),
        "five": ("OakVeneer", "DarkSteel"),
    }[style]
    part.box((0,.752,.235),(.588,.038,.415),timber,.018)
    if style != "two":
        part.box((0,.742,.434),(.58,.030,.019),"LightSteel",.005)
    part.box((0,.449,-.185),(.48,.049,.33),timber,.037)
    for side in (-1,1):
        x = .235*side
        part.rod((x,.038,.26),(x,.716,.30),.019,steel)
        part.rod((x,.042,-.25),(x,.726,.075),.019,steel)
        part.rod((x,.388,-.28),(x,.839,-.39),.013,steel)
        part.box((x,.025,.244),(.042,.033,.132),"Rubber",.009)
        part.box((x,.024,-.248),(.042,.032,.087),"Rubber",.008)
    part.rod((-.23,.413,-.18),(.23,.413,-.18),.020,steel)
    if style == "two":
        for y in (.702,.742,.782,.82):
            part.box((0,y,-.345-(y-.702)*.16),(.47,.019,.024),steel,.004)
        for x in (-.135,-.045,.045,.135):
            part.rod((x,.620,.06),(x,.620,.323),.004,steel,6)
        part.rod((-.22,.62,.322),(.22,.62,.322),.006,steel,6)
    elif style == "one":
        part.back(.485,"PerforatedSteel",.59,.849,-.324)
        part.box((0,.841,-.378),(.48,.022,.025),steel,.004)
    else:
        part.back(.458,timber,.46,.851,-.302)
        part.box((0,.635,.416),(.52,.149,.026),timber,.012)


def north_desk(part):
    part.box((0,.754,0),(1.45,.040,.47),"WarmLaminate",.029)
    part.box((0,.697,-.08),(1.35,.040,.034),"LightSteel",.008)
    for side in (-1,1):
        x = side*.63
        part.rod((x,.023,-.19),(x*.95,.727,.060),.016,"LightSteel")
        part.rod((x,.022,.214),(x*.95,.727,.090),.016,"LightSteel")
        part.rod((x,.092,-.162),(x,.093,.188),.012,"LightSteel")
        for z in (-.195,.213):
            part.box((x,.014,z),(.051,.026,.065),"Rubber",.009)


def north_chair(part):
    part.box((0,.443,-.022),(.469,.045,.427),"BluePolymer",.058)
    part.back(.444,"BluePolymer",.447,.844,-.163)
    for side in (-1,1):
        x = .176*side
        part.rod((x,.424,.121),(side*.225,.017,.176),.013,"LightSteel")
        part.rod((x,.423,-.159),(side*.235,.017,-.249),.013,"LightSteel")
        part.rod((x,.401,-.126),(x,.665,-.208),.011,"LightSteel")
        for fx,z in ((side*.225,.176),(side*.235,-.249)):
            part.box((fx,.010,z),(.034,.018,.038),"Rubber",.006)


def projector(part):
    part.rod((0,-.18,0),(0,0,0),.018,"LightSteel",12)
    part.box((0,-.012,0),(.19,.03,.13),"OffWhite",.013)
    part.box((0,-.218,0),(.242,.038,.17),"LightSteel",.01)
    part.box((0,-.289,0),(.352,.114,.235),"OffWhite",.030)
    part.rod((-.104,-.288,.107),(-.104,-.288,.13),.042,"Rubber",16)
    part.rod((-.104,-.288,.130),(-.104,-.288,.136),.026,"Lens",16)
    for i in range(6):
        part.box((.031+i*.019,-.296,.118),(.008,.038,.004),"DarkSteel")


def ceiling_fan(part):
    part.rod((0,-.195,0),(0,-.01,0),.018,"OffWhite",12)
    part.rod((0,-.283,0),(0,-.192,0),.104,"OffWhite",16)
    for angle in (0,math.tau/3,math.tau*2/3):
        outline = [(.055,-.045),(.266,-.073),(.650,-.086),(.665,.064),
                   (.613,.092),(.225,.065),(.055,.039)]
        part.rings([[(x*math.cos(angle)-z*math.sin(angle),y,
                       x*math.sin(angle)+z*math.cos(angle)) for x,z in reversed(outline)]
                    for y in (-.247,-.231)], "OffWhite")


def camera(part):
    part.rod((0,-.08,0),(0,0,0),.064,"OffWhite",16)
    part.box((0,-.114,0),(.157,.058,.136),"OffWhite",.026)
    part.box((0,-.145,.012),(.109,.077,.103),"DarkSteel",.017)
    part.rod((0,-.143,.059),(0,-.143,.075),.033,"Rubber",12)
    part.rod((0,-.143,.075),(0,-.143,.082),.019,"Lens",12)


def export(path):
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB",
                              use_selection=True, export_yup=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--preview", type=Path)
    args = parser.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else [])
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.context.scene.unit_settings.system = "METRIC"
    materials = {}
    for name,(color,rough,metal) in FINISHES.items():
        material = bpy.data.materials.new(name)
        material.diffuse_color = (*color,1)
        material.use_nodes = True
        shader = next(n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        shader.inputs["Base Color"].default_value = (*color,1)
        shader.inputs["Roughness"].default_value = rough
        shader.inputs["Metallic"].default_value = metal
        materials[name] = material
    objects = []
    groups = [("OneBench",lambda f: bench(f,"one")),("TwoBench",lambda f: bench(f,"two")),
              ("FiveBench",lambda f: bench(f,"five")),("NorthDesk",north_desk),
              ("NorthChair",north_chair),("Projector",projector),("CeilingFan",ceiling_fan),("Camera",camera)]
    for name, build in groups:
        part = Fitting(materials)
        build(part)
        obj = part.build(name)
        obj.select_set(True)
        objects.append(obj)
    export(args.output)
    if args.preview:
        for i,obj in enumerate(objects):
            obj.location = (i % 4 * 1.75, i // 4 * 1.5, .45 if i>=5 else 0)
        export(args.preview)


if __name__ == "__main__":
    main()
