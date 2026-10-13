"""Extract the archived LookDev teaching hall without rebuilding its geometry.

Run: blender --factory-startup -b --python build_lookdev_live.py
The GLB is compacted directly so original positions, split normals, material
definitions and evaluated bevels are copied byte-for-byte. Blender imports the
result only to save a separately editable source file; it does not re-export it.
"""
from pathlib import Path
import copy
import hashlib
import json
import math
import shutil
import struct

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / 'godot/assets'
EXPORT = ROOT / 'blender/exports/lookdev_teaching_hall.glb'
SOURCE = ROOT / 'blender/source/lookdev_teaching_hall.blend'
MANIFEST = ASSETS / 'lookdev_teaching_hall_manifest.json'
HALL = (-63.0, -.02, 163.8, 63.0, 18.0, 223.0)
OLD_STEPS = (-6.2, -.02, 164.0, 6.2, .761, 166.4)
CORRECTED_ENTRY = (-6.01, -.01, 164.75, 6.01, .481, 167.235)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def inside(p, bounds):
    return all(bounds[k] - .0001 <= p[k] <= bounds[k + 3] + .0001 for k in range(3))


def bounds(points):
    return {'min': [round(min(p[k] for p in points), 6) for k in range(3)],
            'max': [round(max(p[k] for p in points), 6) for k in range(3)]}


class Glb:
    def __init__(self, path):
        self.path = path
        raw = path.read_bytes()
        magic, version, length = struct.unpack_from('<III', raw)
        assert magic == 0x46546C67 and version == 2 and length == len(raw)
        offset = 12
        self.binary = b''
        while offset < len(raw):
            size, kind = struct.unpack_from('<II', raw, offset)
            content = raw[offset + 8:offset + 8 + size]
            if kind == 0x4E4F534A:
                self.doc = json.loads(content)
            elif kind == 0x004E4942:
                self.binary = content
            offset += size + 8
        assert not self.doc.get('images'), 'Texture-buffer remapping requires explicit implementation.'
        assert not self.doc.get('skins'), 'This architectural extractor does not process rigs.'
        assert all(not n.get('children') for n in self.doc['nodes']), 'Handle hierarchy explicitly before changing source.'

    def elements(self, index):
        acc = self.doc['accessors'][index]
        assert not acc.get('sparse')
        view = self.doc['bufferViews'][acc['bufferView']]
        component = {5120: ('b', 1), 5121: ('B', 1), 5122: ('h', 2),
                     5123: ('H', 2), 5125: ('I', 4), 5126: ('f', 4)}[acc['componentType']]
        count = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[acc['type']]
        length = component[1] * count
        start = view.get('byteOffset', 0) + acc.get('byteOffset', 0)
        stride = view.get('byteStride', length)
        raw = [self.binary[start + i * stride:start + i * stride + length] for i in range(acc['count'])]
        fmt = '<' + component[0] * count
        return raw, [struct.unpack(fmt, row) for row in raw]


def world_position(point, node):
    if 'matrix' in node:
        m = node['matrix']
        return tuple(sum(m[j * 4 + i] * point[j] for j in range(3)) + m[12 + i] for i in range(3))
    scale = node.get('scale', (1, 1, 1))
    p = tuple(point[k] * scale[k] for k in range(3))
    if 'rotation' in node:
        x, y, z, w = node['rotation']
        # v' = v + 2*w*(q.xyz cross v) + 2*(q.xyz cross (q.xyz cross v))
        uv = (y * p[2] - z * p[1], z * p[0] - x * p[2], x * p[1] - y * p[0])
        uuv = (y * uv[2] - z * uv[1], z * uv[0] - x * uv[2], x * uv[1] - y * uv[0])
        p = tuple(p[k] + 2 * (w * uv[k] + uuv[k]) for k in range(3))
    offset = node.get('translation', (0, 0, 0))
    return tuple(p[k] + offset[k] for k in range(3))


class Writer:
    def __init__(self):
        self.doc = {'asset': {'version': '2.0', 'generator': 'USTC LookDev exact geometry extraction'},
                    'scene': 0, 'scenes': [{'name': 'LookDevTeachingHall', 'nodes': []}],
                    'nodes': [], 'meshes': [], 'materials': [], 'accessors': [], 'bufferViews': [], 'buffers': []}
        self.binary = bytearray()
        self.records = []
        self.all_world = []

    def accessor(self, raw, template, target, values=None):
        while len(self.binary) % 4:
            self.binary.append(0)
        offset = len(self.binary)
        content = b''.join(raw)
        self.binary.extend(content)
        view = len(self.doc['bufferViews'])
        self.doc['bufferViews'].append({'buffer': 0, 'byteOffset': offset, 'byteLength': len(content), 'target': target})
        acc = {k: copy.deepcopy(v) for k, v in template.items()
               if k not in ('bufferView', 'byteOffset', 'count', 'min', 'max', 'sparse')}
        acc.update(bufferView=view, count=len(raw))
        if values is not None:
            acc['min'] = [min(p[k] for p in values) for k in range(len(values[0]))]
            acc['max'] = [max(p[k] for p in values) for k in range(len(values[0]))]
        self.doc['accessors'].append(acc)
        return len(self.doc['accessors']) - 1

    def material(self, source, index):
        material = source.doc['materials'][index]
        for i, existing in enumerate(self.doc['materials']):
            if existing['name'] == material['name']:
                assert existing == material, 'Matching material key has a different source definition.'
                return i
        self.doc['materials'].append(copy.deepcopy(material))
        return len(self.doc['materials']) - 1

    def add(self, source, node, primitive, faces, positions, world, role):
        used = sorted({i for face in faces for i in face})
        mapping = {v: i for i, v in enumerate(used)}
        attributes = {}
        for key, acc_id in primitive['attributes'].items():
            raw, values = source.elements(acc_id)
            attributes[key] = self.accessor([raw[i] for i in used], source.doc['accessors'][acc_id], 34962,
                                             [values[i] for i in used] if key == 'POSITION' else None)
        indices = [mapping[i] for face in faces for i in face]
        code, ctype = ('H', 5123) if len(used) <= 65535 else ('I', 5125)
        index = self.accessor([struct.pack('<' + code, i) for i in indices],
                              {'componentType': ctype, 'type': 'SCALAR'}, 34963)
        material = self.material(source, primitive['material'])
        mesh_name = role + '_' + node.get('name', 'Mesh')
        mesh_id = len(self.doc['meshes'])
        self.doc['meshes'].append({'name': mesh_name,
                                  'primitives': [{'attributes': attributes, 'indices': index, 'material': material, 'mode': 4}]})
        new_node = {k: copy.deepcopy(v) for k, v in node.items() if k in ('matrix', 'translation', 'rotation', 'scale')}
        new_node.update(name=mesh_name, mesh=mesh_id, extras={'source_asset': source.path.name,
                                                             'source_node': node.get('name'), 'role': role})
        self.doc['scenes'][0]['nodes'].append(len(self.doc['nodes']))
        self.doc['nodes'].append(new_node)
        selected_world = [world[i] for i in used]
        self.all_world.extend(selected_world)
        self.records.append({'node': mesh_name, 'source': source.path.name, 'source_node': node.get('name'),
                             'role': role, 'material': self.doc['materials'][material]['name'],
                             'vertices': len(used), 'triangles': len(faces), 'bounds_godot_m': bounds(selected_world),
                             'preserved_attributes': list(attributes)})

    def write(self, path):
        while len(self.binary) % 4:
            self.binary.append(0)
        self.doc['buffers'] = [{'byteLength': len(self.binary)}]
        doc = json.dumps(self.doc, ensure_ascii=False, separators=(',', ':')).encode('utf-8')
        doc += b' ' * ((-len(doc)) % 4)
        data = struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(doc) + 8 + len(self.binary))
        data += struct.pack('<II', len(doc), 0x4E4F534A) + doc
        data += struct.pack('<II', len(self.binary), 0x004E4942) + self.binary
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)


def extract(source, writer, entry=False):
    rejected = []
    for node in source.doc['nodes']:
        if 'mesh' not in node:
            continue
        for primitive in source.doc['meshes'][node['mesh']]['primitives']:
            assert primitive.get('mode', 4) == 4
            material = source.doc['materials'][primitive['material']]['name']
            if entry and material != 'Stone':
                continue
            _, pos = source.elements(primitive['attributes']['POSITION'])
            world = [world_position(p, node) for p in pos]
            _, index_rows = source.elements(primitive['indices'])
            indices = [row[0] for row in index_rows]
            faces = [tuple(indices[i:i + 3]) for i in range(0, len(indices), 3)]
            candidate = CORRECTED_ENTRY if entry else HALL
            mask = [inside(p, candidate) for p in world]
            old = [inside(p, OLD_STEPS) for p in world] if material == 'Stone' and not entry else None
            selected = [face for face in faces if all(mask[i] for i in face)
                        and not (old is not None and all(old[i] for i in face))]
            if entry and selected:
                selected = complete_entry_components(selected, world)
            if selected:
                writer.add(source, node, primitive, selected, pos, world,
                           'CorrectedEntry' if entry else 'ArchivedLookDevHall')
            rejected.append({'node': node.get('name'), 'material': material,
                             'source_triangles': len(faces), 'kept_triangles': len(selected)})
    return rejected


def complete_entry_components(faces, world):
    """The spatial box also intersects column bevel caps; retain five full treads."""
    used = {i for face in faces for i in face}
    parents = {i: i for i in used}
    def find(a):
        while parents[a] != a:
            parents[a] = parents[parents[a]]
            a = parents[a]
        return a
    def join(a, b):
        parents[find(a)] = find(b)
    welded = {}
    for i in used:
        key = tuple(round(v, 5) for v in world[i])
        if key in welded:
            join(i, welded[key])
        else:
            welded[key] = i
    for a, b, c in faces:
        join(a, b)
        join(b, c)
    groups = {}
    for face in faces:
        groups.setdefault(find(face[0]), []).append(face)
    kept = []
    component_bounds = []
    for group in groups.values():
        box = bounds([world[i] for face in group for i in face])
        if box['min'][0] < -5.99 and box['max'][0] > 5.99:
            kept.extend(group)
            component_bounds.append(box)
    assert len(component_bounds) == 5, 'Expected precisely four complete steps and one landing.'
    return kept


def entry_collisions():
    result = []
    for x in (-5.6, 5.6):
        suffix = 'West' if x < 0 else 'East'
        result.append({'name': 'LookDevCanopyColumn' + suffix, 'type': 'box',
                       'center': [x, 2.4, 166.75], 'size': [.24, 4.7, .24],
                       'source': 'lookdev_assets.py canopy column box; no change to geometry'})
        result.append({'name': 'LookDevHandrailTop' + suffix, 'type': 'box',
                       'center': [x, 1.16, 165.3], 'size': [.054, .054, 2.0],
                       'source': 'Conservative AABB of horizontal radius .027m tube, endpoints z164.3/166.3'})
        for k, z in enumerate((164.4, 165.2, 166.0)):
            result.append({'name': 'LookDevHandrailPost' + suffix + str(k), 'type': 'cylinder',
                           'center': [x, .705, z], 'radius': .022, 'height': .91,
                           'source': 'Exact vertical radius .022m tube, y.25..1.16'})
    return result


def point_segment_distance(p, a, b):
    delta = (b[0] - a[0], b[1] - a[1])
    norm = delta[0] ** 2 + delta[1] ** 2
    t = max(0, min(1, sum((p[k] - a[k]) * delta[k] for k in range(2)) / norm)) if norm else 0
    return math.dist(p, (a[0] + t * delta[0], a[1] + t * delta[1]))


def in_polygon(p, polygon, tolerance=.00001):
    inside_poly = False
    for a, b in zip(polygon, polygon[1:] + polygon[:1]):
        if point_segment_distance(p, a, b) <= tolerance:
            return True
        if (a[1] > p[1]) != (b[1] > p[1]) and p[0] < (b[0] - a[0]) * (p[1] - a[1]) / (b[1] - a[1]) + a[0]:
            inside_poly = not inside_poly
    return inside_poly


def polygons_intersect(one, two):
    def cross(a, b, c):
        return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])
    if any(in_polygon(p, two) for p in one) or any(in_polygon(p, one) for p in two):
        return True
    for a, b in zip(one, one[1:] + one[:1]):
        for c, d in zip(two, two[1:] + two[:1]):
            if cross(a, b, c) * cross(a, b, d) < 0 and cross(c, d, a) * cross(c, d, b) < 0:
                return True
    return False


def context_asset():
    """Select complete OSM buildings disjoint from every enabled playable polygon."""
    site = json.loads((ASSETS / 'site.json').read_text('utf-8'))
    north = json.loads((ROOT / 'godot/data/north_axis_layout.json').read_text('utf-8'))
    modules = json.loads((ROOT / 'godot/data/module_layout.json').read_text('utf-8'))['modules']
    domains = [{'id': 'core', 'polygon': [[-80, 118], [80, 118], [80, 238], [-80, 238]]},
               {'id': 'north_axis', 'polygon': north['polygon']}]
    for module in modules:
        if not module['enabled']:
            continue
        b = module['bounds']
        domains.append({'id': module['id'], 'polygon': module.get('polygon',
                        [[b[0], b[1]], [b[2], b[1]], [b[2], b[3]], [b[0], b[3]]])})
    rebuilt = {'267646978', '270537516', '298741849', '298741850'}
    retained, audit = [], []
    for building in site['background']:
        poly = building['outline'][:]
        if poly[0] == poly[-1]:
            poly.pop()
        intersections = [d['id'] for d in domains if polygons_intersect(poly, d['polygon'])]
        reason = 'Already rebuilt by the new north-axis architecture' if building['osm_id'] in rebuilt else (
                 'Whole original footprint intersects an enabled playable domain' if intersections else 'Outside every enabled playable domain')
        keep = not intersections and building['osm_id'] not in rebuilt
        audit.append({'osm_id': building['osm_id'], 'name': building['name'], 'retained': keep,
                      'reason': reason, 'intersecting_domains': intersections})
        if keep:
            retained.append(building)
    writer = Writer()
    source = Glb(ASSETS / 'background.glb')
    for node in source.doc['nodes']:
        if 'mesh' not in node:
            continue
        for primitive in source.doc['meshes'][node['mesh']]['primitives']:
            _, pos = source.elements(primitive['attributes']['POSITION'])
            world = [world_position(p, node) for p in pos]
            _, raw_indices = source.elements(primitive['indices'])
            ids = [row[0] for row in raw_indices]
            faces = [tuple(ids[i:i + 3]) for i in range(0, len(ids), 3)]
            for building in retained:
                poly = building['outline'][:-1]
                b = bounds([(p[0], 0, p[1]) for p in poly])
                bbox = [b['min'][0] - .20, -.03, b['min'][2] - .20,
                        b['max'][0] + .20, building['height'] + .30, b['max'][2] + .20]
                mask = [inside(p, bbox) and in_polygon((p[0], p[2]), poly, .20) for p in world]
                selected = [face for face in faces if all(mask[i] for i in face)]
                if selected:
                    writer.add(source, node, primitive, selected, pos, world, 'Context_' + building['osm_id'])
    output = ROOT / 'blender/exports/lookdev_context.glb'
    assert retained and writer.records
    assert all(any(r['role'] == 'Context_' + b['osm_id'] for r in writer.records) for b in retained)
    writer.write(output)
    shutil.copy2(output, ASSETS / output.name)
    report = {'asset': output.name, 'coordinate_system': 'Godot meters, identity root, original absolute site coordinates',
              'purpose': 'Background enclosure only; no additional playable ground, NPCs or entrance routes',
              'retained_osm_ids': [b['osm_id'] for b in retained], 'retained_buildings': retained,
              'excluded_rebuilt_osm_ids': sorted(rebuilt), 'domain_polygons': domains, 'selection_audit': audit,
              'selection_geometry_rule': 'Select full buildings by polygon disjointness; copy original faces whose vertices fit that footprint plus .20m existing cornice allowance. No invented/relocated geometry.',
              'bounds_godot_m': bounds(writer.all_world), 'triangles': sum(r['triangles'] for r in writer.records),
              'vertices': sum(r['vertices'] for r in writer.records), 'mesh_nodes': len(writer.records),
              'materials': writer.doc['materials'], 'mesh_records': writer.records, 'glb_bytes': output.stat().st_size,
              'output_sha256': digest(output), 'all_retained_footprints_disjoint': True,
              'source_sha256': {str(source.path.relative_to(ROOT)): digest(source.path)},
              'attribution': 'Original OpenStreetMap footprint data, ODbL; existing project background simplification. Building heights/facades remain approximate.',
              'collision_policy': 'No colliders generated in this GLB. Existing playable-domain visible boundaries govern access.'}
    (ASSETS / 'lookdev_context_manifest.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    return output, report


def save_blender_source(asset, destination):
    import bpy
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(asset))
    bpy.context.scene.unit_settings.system = 'METRIC'
    bpy.context.scene.unit_settings.scale_length = 1.0
    bpy.context.scene['provenance'] = 'Exact archived LookDev extraction; see matching asset manifest in godot/assets'
    bpy.context.preferences.filepaths.save_version = 0
    destination.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(destination))


def verify_export(path):
    """Read the written GLB independently and verify original vertex attributes."""
    output = Glb(path)
    sources = {}
    verified_vertices = 0
    for node in output.doc['nodes']:
        info = node['extras']
        if info['source_asset'] not in sources:
            sources[info['source_asset']] = Glb(ASSETS / info['source_asset'])
        original = sources[info['source_asset']]
        original_node = next(n for n in original.doc['nodes'] if n.get('name') == info['source_node'])
        for key in ('matrix', 'translation', 'rotation', 'scale'):
            assert node.get(key) == original_node.get(key), 'Source transform was changed.'
        for primitive in output.doc['meshes'][node['mesh']]['primitives']:
            material = output.doc['materials'][primitive['material']]
            source_primitive = next(p for p in original.doc['meshes'][original_node['mesh']]['primitives']
                                    if original.doc['materials'][p['material']]['name'] == material['name'])
            assert material == original.doc['materials'][source_primitive['material']]
            attributes = sorted(primitive['attributes'])
            assert attributes == sorted(source_primitive['attributes'])
            source_raw = [original.elements(source_primitive['attributes'][key])[0] for key in attributes]
            original_vertices = set(zip(*source_raw))
            written_raw = [output.elements(primitive['attributes'][key])[0] for key in attributes]
            assert all(vertex in original_vertices for vertex in zip(*written_raw)), 'A vertex attribute was altered.'
            count = len(written_raw[0])
            verified_vertices += count
            _, indices = output.elements(primitive['indices'])
            assert len(indices) % 3 == 0 and all(0 <= i[0] < count for i in indices)
    return {'passed': True, 'verified_vertices': verified_vertices,
            'checks': ['Written GLB is structurally readable', 'Every written position/normal tuple occurs unchanged in its exact source node',
                       'Node transform and complete material dictionary equal source', 'All triangle indices are valid'],
            'scope': 'CPU asset integrity only; Godot render and player traversal are validated by the integrating task'}


def main():
    frozen = [ASSETS / name for name in ('architecture.glb', 'dioarchitecture.glb', 'diositedetail.glb', 'background.glb', 'site.json')]
    frozen += [ROOT / 'blender/source' / name for name in ('ustc_north_axis.blend', 'ustc_diorama.blend')]
    frozen += [ROOT / 'blender/scripts' / name for name in ('build_campus.py', 'lookdev_assets.py', 'diorama_assets.py')]
    hashes = {str(p.relative_to(ROOT)): digest(p) for p in frozen}
    writer = Writer()
    archived = Glb(ASSETS / 'architecture.glb')
    corrected = Glb(ASSETS / 'dioarchitecture.glb')
    selection = extract(archived, writer) + extract(corrected, writer, entry=True)
    assert all(inside(p, HALL) for p in writer.all_world)
    assert not any('Pavilion' in r['material'] or r['material'] in ('Letter', 'Plaster', 'Wood') for r in writer.records)
    assert any(r['role'] == 'CorrectedEntry' for r in writer.records)
    writer.write(EXPORT)
    shutil.copy2(EXPORT, ASSETS / EXPORT.name)
    hall_validation = verify_export(EXPORT)
    hall_validation['corrected_entry_components'] = 5
    hall_validation['corrected_entry_triangles'] = next(r['triangles'] for r in writer.records if r['role'] == 'CorrectedEntry')
    # Geometry comes from the GLBs above; Blender is a source preview/editor only.
    save_blender_source(EXPORT, SOURCE)
    context_output, context_report = context_asset()
    context_report['validation'] = verify_export(context_output)
    (ASSETS / 'lookdev_context_manifest.json').write_text(json.dumps(context_report, ensure_ascii=False, indent=2), encoding='utf-8')
    save_blender_source(context_output, ROOT / 'blender/source/lookdev_context.blend')
    unchanged = {name: digest(ROOT / name) == value for name, value in hashes.items()}
    assert all(unchanged.values()), 'A frozen input changed during extraction; investigate concurrent edits.'
    triangles = sum(r['triangles'] for r in writer.records)
    report = {'asset': EXPORT.name, 'source_blend': str(SOURCE.relative_to(ROOT)),
              'coordinate_system': 'Godot XYZ east/up/south in meters, root identity; Blender X,-Z,Y mapping on import',
              'bounds_godot_m': bounds(writer.all_world), 'triangles': triangles,
              'vertices': sum(r['vertices'] for r in writer.records), 'mesh_nodes': len(writer.records),
              'glb_bytes': EXPORT.stat().st_size, 'output_sha256': digest(EXPORT),
              'selection': {'hall_inclusive_xyz_min_max': HALL, 'remove_old_entry_xyz_min_max': OLD_STEPS,
                            'corrected_entry_only_xyz_min_max': CORRECTED_ENTRY,
                            'rule': 'Keep whole triangles whose three world-space vertices fall inside the chosen box; entry additionally keeps only five full-width connected components, excluding intersected canopy-column bevel caps. No clipping or vertex relocation.'},
              'alignment': {'root_translation': [0, 0, 0], 'root_scale': [1, 1, 1],
                            'main_wall': {'min': [-62, 0, 168.4], 'max': [62, 17, 184]},
                            'wing_outer_z': [180, 222], 'paving_top': .105,
                            'corrected_steps': [{'center_z': 165 + i * .45, 'top_y': .12 * (i + 1),
                                                 'width': 12, 'depth': .48} for i in range(4)],
                            'landing': {'center_z': 166.85, 'top_y': .48, 'width': 12, 'depth': .75},
                            'old_step_issue': 'The archived four steps got higher toward the north (away from the entrance); removed only these faces.',
                            'diorama_difference': 'Same walls and window locations; archived .018m manufactured bevels remain, without later .065m Diorama bevel/rear joinery/parapet additions.'},
              'materials': writer.doc['materials'], 'mesh_records': writer.records,
              'selection_audit': selection, 'new_collision_proposals': entry_collisions(),
              'collision_ownership': {'main_hall_and_steps': 'Existing shared diorama.build_collisions; do not create GLB trimesh duplicates',
                                      'new_thin_columns_and_rails': 'lookdev_live.build_collisions consumes new_collision_proposals',
                                      'entry_planters': 'Existing diositedetail visuals and shared EntryPlanter collisions'},
              'excluded': ['Old north gate', 'Old pavilion', 'Old bridge', 'Expert building',
                           'Diorama trees', 'Diositedetail planters/bicycle stands/site furniture (loaded separately)'],
              'preservation': {'original_position_and_normal_element_bytes_copied': True,
                               'material_definitions_copied_without_renaming': True,
                               'old_glbs_blends_and_builders_unchanged': unchanged},
              'source_sha256': hashes,
              'builder_sha256': digest(Path(__file__)),
              'validation': hall_validation,
              'limitations': ['Original archived .018m bevel tessellation remains expensive; no optimization or aesthetic redesign in this extraction.',
                              'This is asset integrity/alignment validation, not a Godot rendering or walkability result.']}
    MANIFEST.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    print('LOOKDEV_TEACHING_HALL_OK', json.dumps({'triangles': triangles, 'bounds': report['bounds_godot_m'],
                                                'glb_bytes': report['glb_bytes'], 'inputs_unchanged': all(unchanged.values()),
                                                'context_osm_ids': context_report['retained_osm_ids'],
                                                'context_triangles': context_report['triangles']}))


if __name__ == '__main__':
    main()
