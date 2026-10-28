import bpy, bmesh, math

for ob in list(bpy.data.objects):
    bpy.data.objects.remove(ob, do_unlink=True)
for me in list(bpy.data.meshes):
    if me.users == 0:
        bpy.data.meshes.remove(me)

def G(x, y, z):
    return (x, -z, y)

def srgb(r, g, b):
    f = lambda v: (v / 255) ** 2.2
    return (f(r), f(g), f(b))

def material(name, rgb, metal, rough, emit=0.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    p = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    c = (*rgb, 1.0)
    p.inputs["Base Color"].default_value = c
    p.inputs["Metallic"].default_value = metal
    p.inputs["Roughness"].default_value = rough
    p.inputs["Emission Strength"].default_value = emit
    if emit:
        p.inputs["Emission Color"].default_value = c
    m.diffuse_color = c
    return m

MAT = {
    "steel": material("steel", srgb(62, 70, 88), 0.6, 0.4),
    "dark": material("dark", srgb(30, 34, 44), 0.5, 0.6),
    "trim": material("trim", srgb(120, 128, 145), 0.7, 0.4),
    "hazard": material("hazard", srgb(214, 168, 44), 0.2, 0.5),
    "strip": material("strip", srgb(43, 182, 221), 0.0, 1.0, 3.0),
    "white": material("white", srgb(215, 235, 255), 0.0, 1.0, 3.0),
    "crystal": material("crystal", srgb(150, 230, 255), 0.0, 0.2, 4.0),
    "shield": material("shield", srgb(90, 200, 255), 0.0, 1.0, 3.0),
    "pylon": material("pylon", srgb(43, 182, 221), 0.0, 1.0, 3.0),
    "warn": material("warn", srgb(255, 60, 40), 0.0, 1.0, 3.0),
}

col = bpy.data.collections.get("Core_siege") or bpy.data.collections.new("Core_siege")
if col.name not in bpy.context.scene.collection.children:
    bpy.context.scene.collection.children.link(col)
parts = {}
cur = [None]

def part(name):
    me = bpy.data.meshes.new(name)
    ob = bpy.data.objects.new(name, me)
    col.objects.link(ob)
    parts[name] = (ob, bmesh.new())
    cur[0] = name

def merge(tmp, mat):
    ob, bm = parts[cur[0]]
    names = [m.name for m in ob.data.materials]
    if mat not in names:
        ob.data.materials.append(MAT[mat])
        names.append(mat)
    for f in tmp.faces:
        f.material_index = names.index(mat)
    me = bpy.data.meshes.new("tmp")
    tmp.to_mesh(me)
    tmp.free()
    bm.from_mesh(me)
    bpy.data.meshes.remove(me)

def hull(pts, mat, bevel=0.02):
    tmp = bmesh.new()
    for p in dict.fromkeys(tuple(round(v, 6) for v in p) for p in pts):
        tmp.verts.new(G(*p))
    r = bmesh.ops.convex_hull(tmp, input=tmp.verts[:])
    bmesh.ops.delete(tmp, geom=list(dict.fromkeys(r["geom_interior"] + r["geom_unused"])), context="VERTS")
    bmesh.ops.dissolve_limit(tmp, angle_limit=math.radians(1), verts=tmp.verts[:], edges=tmp.edges[:])
    if bevel:
        bmesh.ops.bevel(tmp, geom=tmp.edges[:], offset=bevel, segments=1, affect="EDGES", profile=0.5, clamp_overlap=True)
    bmesh.ops.triangulate(tmp, faces=[f for f in tmp.faces if len(f.verts) > 4])
    merge(tmp, mat)

def box(size, pos, mat, bevel=0.02):
    sx, sy, sz = size[0] / 2, size[1] / 2, size[2] / 2
    hull([(pos[0] + a * sx, pos[1] + b * sy, pos[2] + c * sz) for a in (-1, 1) for b in (-1, 1) for c in (-1, 1)], mat, bevel)

def rbox(size, pos, yaw, mat, bevel=0.02):
    sx, sy, sz = size[0] / 2, size[1] / 2, size[2] / 2
    c, s = math.cos(yaw), math.sin(yaw)
    hull([(pos[0] + a * sx * c - b * sz * s, pos[1] + h * sy, pos[2] + a * sx * s + b * sz * c) for a in (-1, 1) for h in (-1, 1) for b in (-1, 1)], mat, bevel)

def cyl(r0, r1, y0, y1, mat, segs=8, bevel=0.02, x=0.0, z=0.0, rot=0.0):
    pts = []
    for y, r in ((y0, r0), (y1, r1)):
        for k in range(segs):
            a = rot + math.pi / segs + k * 2 * math.pi / segs
            pts.append((x + r * math.cos(a), y, z + r * math.sin(a)))
    hull(pts, mat, bevel)

def ring(r0, r1, y0, y1, mat, segs=16, rot=0.0, gap=0.0):
    for k in range(segs):
        a0 = rot + k * 2 * math.pi / segs + gap / 2
        a1 = rot + (k + 1) * 2 * math.pi / segs - gap / 2
        hull([(r * math.cos(a), y, r * math.sin(a)) for r in (r0, r1) for a in (a0, a1) for y in (y0, y1)], mat, 0)

def arc(r0, r1, y0, y1, a0, a1, mat, segs, bevel=0.0):
    for k in range(segs):
        b0 = a0 + (a1 - a0) * k / segs
        b1 = a0 + (a1 - a0) * (k + 1) / segs
        hull([(r * math.cos(a), y, r * math.sin(a)) for r in (r0, r1) for a in (b0, b1) for y in (y0, y1)], mat, bevel)

HALF = 80.0
LANE_W = 10.0
FORT = 16.0
PLAZA = 14.0
CHOKES = (34.0, 56.0)
VENTS = ((45.0, -1), (67.0, 1))
SPAWN_GAP = 12.0
LANE_WALL = {"h": 1.3, "t": 0.6, "from": FORT + 1.0, "to": HALF - 0.5}
DIRS = ((0, -1), (1, 0), (0, 1), (-1, 0))

def lane_box(d, r0, r1, l0, l1, y0, y1, mat, bevel=0.03):
    dx, dz = d
    pts = []
    for r in (r0, r1):
        for l in (l0, l1):
            for y in (y0, y1):
                pts.append((dx * r - dz * l, y, dz * r + dx * l))
    hull(pts, mat, bevel)

part("border")
H = HALF + 0.5
for k in range(4):
    a = k * math.pi / 2
    c, s = math.cos(a), math.sin(a)
    for sign in (-1, 1):
        l0, l1 = sorted((sign * SPAWN_GAP / 2, sign * (HALF + 1)))
        lane_box((c, s), HALF, HALF + 1.0, l0, l1, 0.0, 3.0, "dark")
        lane_box((c, s), HALF - 0.05, HALF + 0.1, l0, l1, 2.3, 2.42, "strip", 0)
        lane_box((c, s), HALF + 0.2, HALF + 1.2, l0, l1, 3.0, 3.25, "steel")
        lane_box((c, s), HALF - 0.08, HALF + 0.2, l0, l1, 0.0, 0.3, "hazard", 0)
        n = int((HALF - SPAWN_GAP / 2) / 8)
        for j in range(n + 1):
            l = sign * (SPAWN_GAP / 2 + 2 + j * 8)
            if abs(l) < HALF - 1:
                lane_box((c, s), HALF - 0.3, HALF, l - 0.25, l + 0.25, 0.0, 2.9, "trim")
for cx, cz in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
    x, z = cx * (HALF - 8), cz * (HALF - 8)
    cyl(3.2, 3.2, 0.0, 0.06, "dark", 8, 0.01, x, z)
    ring(3.0, 3.2, 0.06, 0.08, "hazard", 8, math.pi / 8)
    ring(2.3, 2.45, 0.06, 0.09, "strip", 16)
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        hull([(x + 1.0 * math.cos(a), 0.06, z + 1.0 * math.sin(a)), (x + 1.9 * math.cos(a + 0.25), 0.06, z + 1.9 * math.sin(a + 0.25)), (x + 1.9 * math.cos(a - 0.25), 0.06, z + 1.9 * math.sin(a - 0.25)), (x + 1.0 * math.cos(a), 0.1, z + 1.0 * math.sin(a))], "white", 0)
    px, pz = cx * (HALF - 2.2), cz * (HALF - 2.2)
    cyl(0.5, 0.4, 0.0, 6.0, "dark", 8, 0.02, px, pz)
    cyl(0.55, 0.55, 5.6, 5.9, "white", 8, 0, px, pz)

part("lanes")
for d in DIRS:
    for side in (-1, 1):
        l0, l1 = sorted((side * LANE_W / 2, side * (LANE_W / 2 + LANE_WALL["t"])))
        cuts = sorted([(c - 2.0, c + 2.0) for c in CHOKES] + [(v - 1.4, v + 1.4) for v, sd in VENTS if sd == side])
        r = LANE_WALL["from"]
        for c0, c1 in cuts + [(LANE_WALL["to"], LANE_WALL["to"])]:
            if c0 > r:
                lane_box(d, r, c0, l0, l1, 0.0, LANE_WALL["h"], "dark")
                lane_box(d, r, c0, l0 - 0.05, l1 + 0.05, LANE_WALL["h"], LANE_WALL["h"] + 0.12, "steel")
                lane_box(d, r + 0.1, c0 - 0.1, side * (LANE_W / 2 - 0.02), side * (LANE_W / 2 + 0.02), 0.95, 1.05, "strip", 0)
            r = c1
        for c in CHOKES:
            n0, n1 = sorted((side * 3.0, side * (LANE_W / 2 + LANE_WALL["t"])))
            lane_box(d, c - 2.0, c + 2.0, n0, n1, 0.0, 1.6, "dark", 0.06)
            lane_box(d, c - 2.0, c + 2.0, n0 - 0.04, n1 + 0.04, 1.6, 1.85, "hazard", 0.02)
            lane_box(d, c - 1.6, c + 1.6, side * 2.96, side * 3.02, 0.5, 0.62, "white", 0)
        for v, sd in VENTS:
            if sd != side:
                continue
            lane_box(d, v - 1.4, v + 1.4, l0, l1, 0.0, 0.25, "dark")
            lane_box(d, v - 1.4, v + 1.4, l0, l1, 1.15, LANE_WALL["h"] + 0.12, "steel")
            lane_box(d, v - 1.6, v - 1.4, l0 - 0.1, l1 + 0.1, 0.0, 1.6, "trim")
            lane_box(d, v + 1.4, v + 1.6, l0 - 0.1, l1 + 0.1, 0.0, 1.6, "trim")
            for j in range(5):
                y = 0.35 + j * 0.17
                lane_box(d, v - 1.3, v + 1.3, side * (LANE_W / 2 + 0.2), side * (LANE_W / 2 + 0.3), y, y + 0.06, "strip", 0)
            lane_box(d, v - 1.4, v + 1.4, side * (LANE_W / 2 + 0.4), side * (LANE_W / 2 + LANE_WALL["t"]), 0.25, 1.15, "dark", 0)

part("fortress")
GATE_HALF = math.atan2(LANE_W / 2 + 1.6, FORT)
for k in range(4):
    a = k * math.pi / 2 - math.pi / 2
    a0, a1 = a + GATE_HALF, a + math.pi / 2 - GATE_HALF
    arc(FORT - 0.6, FORT + 0.6, 0.0, 2.6, a0, a1, "dark", 10, 0.03)
    arc(FORT - 0.7, FORT + 0.7, 2.6, 2.85, a0, a1, "steel", 10, 0.02)
    arc(FORT - 0.64, FORT - 0.6, 1.9, 2.0, a0 + 0.02, a1 - 0.02, "strip", 10)
    arc(FORT + 0.6, FORT + 0.75, 0.0, 0.35, a0, a1, "hazard", 10)
    for j in range(1, 5):
        b = a0 + (a1 - a0) * j / 5
        rbox((1.6, 3.1, 0.5), (FORT * math.cos(b), 1.55, FORT * math.sin(b)), b, "trim", 0.03)

part("plaza")
cyl(PLAZA, PLAZA, 0.0, 0.04, "steel", 32, 0.01)
ring(PLAZA - 0.6, PLAZA, 0.04, 0.06, "hazard", 32)
ring(PLAZA - 1.3, PLAZA - 1.1, 0.04, 0.065, "strip", 32, 0, 0.04)
ring(7.2, 7.5, 0.04, 0.06, "trim", 24)
for k in range(8):
    a = k * math.pi / 4
    rbox((PLAZA - 8.4, 0.03, 0.08), ((7.5 + (PLAZA - 7.5 - 0.6) / 2) * math.cos(a), 0.055, (7.5 + (PLAZA - 7.5 - 0.6) / 2) * math.sin(a)), a, "dark", 0)
for dx, dz in DIRS:
    for j in range(3):
        r = 9.0 + j * 1.2
        for sd in (-1, 1):
            pt = lambda f, l, y=0.05: (dx * f - dz * sd * l, y, dz * f + dx * sd * l)
            hull([pt(r + 0.5, 0), pt(r, 1.2), pt(r + 0.35, 1.2), pt(r + 0.85, 0, 0.07)], "white", 0)

part("core_base")
cyl(6.0, 5.6, 0.0, 0.45, "dark", 8, 0.04, rot=math.pi / 8)
ring(5.62, 5.8, 0.45, 0.47, "strip", 8, math.pi / 8)
cyl(4.4, 4.1, 0.45, 0.8, "steel", 8, 0.03, rot=math.pi / 8)
cyl(2.0, 1.6, 0.8, 1.4, "trim", 8, 0.03)
for k in range(4):
    a = math.pi / 4 + k * math.pi / 2
    c, s = math.cos(a), math.sin(a)
    hull([(1.4 * c, 0.8, 1.4 * s), (2.6 * c, 0.8, 2.6 * s), (2.3 * c, 2.2, 2.3 * s), (1.5 * c, 2.6, 1.5 * s), (1.1 * c, 1.6, 1.1 * s), (2.1 * c + 0.25 * s, 1.4, 2.1 * s - 0.25 * c), (2.1 * c - 0.25 * s, 1.4, 2.1 * s + 0.25 * c)], "trim", 0.03)
for dx, dz in DIRS:
    yaw = math.atan2(dz, dx)
    r = 4.6
    hull([(dx * (r - 0.5) - dz * w, 0.45, dz * (r - 0.5) + dx * w) for w in (-0.6, 0.6)] + [(dx * (r + 0.5) - dz * w, 0.45, dz * (r + 0.5) + dx * w) for w in (-0.6, 0.6)] + [(dx * (r - 0.25) - dz * w, 3.6, dz * (r - 0.25) + dx * w) for w in (-0.3, 0.3)] + [(dx * (r + 0.15) - dz * w, 3.6, dz * (r + 0.15) + dx * w) for w in (-0.3, 0.3)], "dark", 0.04)
    rbox((0.08, 2.3, 0.28), (dx * (r + 0.42), 2.0, dz * (r + 0.42)), yaw, "pylon", 0)
    cyl(0.32, 0.32, 3.6, 3.75, "steel", 8, 0.01, dx * (r - 0.05), dz * (r - 0.05))
    cyl(0.22, 0.22, 3.75, 3.85, "pylon", 8, 0, dx * (r - 0.05), dz * (r - 0.05))

part("core_crystal")
pts = [(0, 1.7, 0), (0, -1.5, 0)]
for k in range(6):
    a = k * math.pi / 3
    pts += [(0.95 * math.cos(a), 0.35, 0.95 * math.sin(a)), (0.75 * math.cos(a + 0.5), -0.45, 0.75 * math.sin(a + 0.5))]
hull(pts, "crystal", 0)

for i, r in enumerate((4.0, 3.35, 2.75, 2.2)):
    part("ring%d" % (i + 1))
    ring(r - 0.1, r, -0.05, 0.05, "shield", 12, i * 0.2, 0.08)

part("gate")
for sd in (-1, 1):
    l = sd * (LANE_W / 2 + 0.9)
    box((2.0, 4.0, 1.8), (0, 2.0, l), "dark", 0.06)
    box((2.2, 0.3, 2.0), (0, 4.15, l), "steel", 0.04)
    box((2.04, 0.5, 1.84), (0, 0.25, l), "hazard", 0.0)
    box((0.06, 2.4, 0.2), (1.01, 2.2, l - sd * 0.5), "strip", 0)
    box((0.06, 2.4, 0.2), (-1.01, 2.2, l - sd * 0.5), "strip", 0)
box((1.0, 0.06, LANE_W), (0, 0.03, 0), "trim", 0.01)
box((0.2, 0.07, LANE_W - 0.4), (0.5, 0.04, 0), "hazard", 0)
box((0.2, 0.07, LANE_W - 0.4), (-0.5, 0.04, 0), "hazard", 0)

part("gate_light")
for sd in (-1, 1):
    l = sd * (LANE_W / 2 + 0.9)
    box((0.12, 0.25, 1.4), (1.1, 3.6, l), "warn", 0)
    box((0.7, 0.2, 0.7), (0, 4.4, l), "warn", 0)

part("gate_door")
box((0.5, 2.3, LANE_W), (0, 1.15, 0), "steel", 0.04)
for j in range(5):
    z = -LANE_W / 2 + 1 + j * (LANE_W - 2) / 4
    box((0.7, 2.3, 0.3), (0, 1.15, z), "trim", 0.03)
box((0.62, 0.18, LANE_W - 0.2), (0, 1.75, 0), "dark", 0.01)
box((0.64, 0.06, LANE_W - 0.4), (0, 1.75, 0), "strip", 0)

part("gate_broken")
rbox((0.45, 1.4, 4.4), (0.6, 0.55, -2.6), 0.35, "steel", 0.04)
hull([(x, y, z) for x, y, z in ((-0.2, 0.0, 0.5), (0.4, 0.0, 0.5), (-0.2, 0.0, 4.6), (0.4, 0.0, 4.6), (1.4, 0.9, 1.2), (1.8, 0.9, 1.2), (1.4, 0.7, 4.3), (1.8, 0.7, 4.3))], "steel", 0.04)
for x, z, s, a in ((1.6, -0.6, 0.6, 0.4), (-0.9, 1.4, 0.5, 1.1), (2.3, 2.6, 0.7, 2.0), (-0.6, -3.8, 0.4, 0.7), (1.1, 4.0, 0.45, 2.6), (2.6, -2.2, 0.35, 1.7)):
    rbox((s, s * 0.7, s * 1.2), (x, s * 0.35, z), a, "dark", 0.05)
for x, z in ((0.9, -1.4), (0.2, 2.2)):
    rbox((0.25, 0.25, 2.4), (x, 0.12, z), 0.6, "trim", 0.02)

part("spawn_gate")
for sd in (-1, 1):
    l = sd * (SPAWN_GAP / 2 + 1.2)
    box((2.4, 6.5, 2.4), (0.5, 3.25, l), "dark", 0.06)
    box((2.6, 0.4, 2.6), (0.5, 6.7, l), "steel", 0.04)
    box((2.44, 0.6, 2.44), (0.5, 0.3, l), "hazard", 0)
box((2.4, 1.2, SPAWN_GAP + 4.8), (0.5, 7.3, 0), "dark", 0.06)
box((0.06, 0.25, SPAWN_GAP), (-0.72, 6.4, 0), "white", 0)
box((3.0, 0.06, SPAWN_GAP), (-1.0, 0.03, 0), "trim", 0.01)
for j in range(6):
    z = -SPAWN_GAP / 2 + 1 + j * (SPAWN_GAP - 2) / 5
    box((0.5, 0.07, 0.7), (-2.0, 0.045, z), "hazard", 0)

part("spawn_light")
box((0.1, 0.4, SPAWN_GAP - 1), (-0.75, 7.3, 0), "warn", 0)
for sd in (-1, 1):
    box((0.1, 2.4, 0.3), (-0.72, 3.8, sd * (SPAWN_GAP / 2 + 0.3)), "warn", 0)

part("build_pad")
box((4.0, 0.12, 4.0), (0, 0.06, 0), "dark", 0.02)
for sd in (-1, 1):
    box((4.0, 0.03, 0.3), (0, 0.135, sd * 1.85), "hazard", 0)
    box((0.3, 0.03, 3.4), (sd * 1.85, 0.135, 0), "hazard", 0)
box((3.0, 0.02, 3.0), (0, 0.125, 0), "steel", 0)
for sd in (-1, 1):
    for t in (-1, 1):
        box((0.5, 0.03, 0.08), (sd * 1.3, 0.15, t * 1.5), "strip", 0)
        box((0.08, 0.03, 0.5), (sd * 1.5, 0.15, t * 1.3), "strip", 0)

part("mod_wall")
box((1.2, 2.0, 3.6), (0, 1.12, 0), "steel", 0.06)
for z in (-1.2, 0.0, 1.2):
    box((1.36, 1.8, 0.3), (0, 1.02, z), "trim", 0.03)
box((1.3, 0.2, 3.7), (0, 2.2, 0), "dark", 0.03)
box((0.06, 0.12, 3.2), (0.66, 1.7, 0), "strip", 0)
box((0.06, 0.12, 3.2), (-0.66, 1.7, 0), "strip", 0)

part("mod_mine")
for x, z in ((-0.9, -0.9), (0.9, -0.9), (-0.9, 0.9), (0.9, 0.9)):
    cyl(0.45, 0.4, 0.12, 0.3, "dark", 8, 0.02, x, z)
    cyl(0.18, 0.18, 0.3, 0.36, "strip", 8, 0, x, z)

part("mod_laser")
cyl(0.8, 0.7, 0.12, 0.6, "dark", 8, 0.03)
cyl(0.35, 0.3, 0.6, 1.6, "trim", 8, 0.02)
box((1.2, 0.5, 0.6), (0.2, 1.8, 0), "steel", 0.04)
cyl(0.12, 0.12, 0.0, 1.1, "dark", 8, 0.01)
hull([(0.8, 1.72, -0.08), (0.8, 1.88, -0.08), (0.8, 1.72, 0.08), (0.8, 1.88, 0.08), (1.6, 1.76, -0.05), (1.6, 1.84, -0.05), (1.6, 1.76, 0.05), (1.6, 1.84, 0.05)], "dark", 0.01)
box((0.04, 0.1, 0.5), (0.81, 1.8, 0), "white", 0)

for name, (ob, bm) in parts.items():
    bm.to_mesh(ob.data)
    bm.free()
    for p in ob.data.polygons:
        p.use_smooth = False
    print(name, len(ob.data.polygons), "faces", "%.2f x %.2f x %.2f" % tuple(ob.dimensions))
