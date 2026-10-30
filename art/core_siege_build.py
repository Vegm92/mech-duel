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
    "plasma": material("plasma", srgb(255, 201, 60), 0.0, 0.2, 4.0),
    "plasma_in": material("plasma_in", srgb(255, 243, 196), 0.0, 0.2, 4.0),
    "petal": material("petal", srgb(47, 155, 255), 0.0, 0.5, 1.0),
    "petal_edge": material("petal_edge", srgb(156, 208, 255), 0.0, 0.5, 3.0),
    "pylon": material("pylon", srgb(43, 182, 221), 0.0, 1.0, 3.0),
    "warn": material("warn", srgb(255, 60, 40), 0.0, 1.0, 3.0),
    "concrete": material("concrete", srgb(48, 54, 70), 0.0, 0.85),
    "tread": material("tread", srgb(32, 36, 48), 0.1, 0.8),
    "seat_b": material("seat_b", srgb(40, 85, 150), 0.0, 0.7),
    "led_n": material("led_n", srgb(200, 200, 210), 0.0, 1.0, 3.0),
    "flood": material("flood", srgb(235, 240, 255), 0.0, 1.0, 3.0),
    "paint": material("paint", srgb(201, 162, 62), 0.15, 0.7),
    "mark": material("mark", srgb(112, 144, 161), 0.15, 0.65),
    "yard": material("yard", srgb(70, 60, 58), 0.4, 0.7),
    "rust": material("rust", srgb(110, 70, 50), 0.3, 0.75),
    "amber": material("amber", srgb(255, 176, 60), 0.0, 1.0, 3.0),
    "roof": material("roof", srgb(13, 15, 21), 0.3, 0.8),
    "aisle": material("aisle", srgb(72, 78, 94), 0.2, 0.7),
    "counter": material("counter", srgb(43, 182, 221), 0.0, 1.0, 3.0),
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

def ring(r0, r1, y0, y1, mat, segs=16, rot=0.0, gap=0.0, x=0.0, z=0.0):
    for k in range(segs):
        a0 = rot + k * 2 * math.pi / segs + gap / 2
        a1 = rot + (k + 1) * 2 * math.pi / segs - gap / 2
        hull([(x + r * math.cos(a), y, z + r * math.sin(a)) for r in (r0, r1) for a in (a0, a1) for y in (y0, y1)], mat, 0)

def arc(r0, r1, y0, y1, a0, a1, mat, segs, bevel=0.0):
    for k in range(segs):
        b0 = a0 + (a1 - a0) * k / segs
        b1 = a0 + (a1 - a0) * (k + 1) / segs
        hull([(r * math.cos(a), y, r * math.sin(a)) for r in (r0, r1) for a in (b0, b1) for y in (y0, y1)], mat, bevel)

HALF = 80.0
LANE_W = 10.0
W = LANE_W / 2
LANE_WALL = 1.5
RING_IN, RING_OUT = 16.0, 17.5
FORT = (RING_IN + RING_OUT) / 2
BLOCK, YARD_IN = 26.0, 27.5
ARCH = 6.0
PLAZA = 14.0
REPAIR = 5.0
CHOKES = (36.0, 58.0)
CHOKE_R = 2.0
AIR = 74.0
SPAWN_GAP = 12.0
DIRS = ((0, -1), (1, 0), (0, 1), (-1, 0))
QUADS = ((1, -1), (1, 1), (-1, 1), (-1, -1))
STAND = {"front": 2.4, "depth": 2.6, "base": 1.4, "rise": 1.3, "tiers": 3, "rows": (0.65, 1.95), "gap": 9.0, "aisle": 40.0, "aisle_w": 0.4, "wall": 7.0, "roof": 16.0}
BACK = STAND["front"] + STAND["depth"] * STAND["tiers"]
FLAT = (0.012, 0.018)

def lane_box(d, r0, r1, l0, l1, y0, y1, mat, bevel=0.03):
    dx, dz = d
    pts = []
    for r in (r0, r1):
        for l in (l0, l1):
            for y in (y0, y1):
                pts.append((dx * r - dz * l, y, dz * r + dx * l))
    hull(pts, mat, bevel)

def obox(c, axes, half, mat, bevel=0.03):
    pts = []
    for sa in (-1, 1):
        for sb in (-1, 1):
            for sc in (-1, 1):
                pts.append(tuple(c[i] + axes[0][i] * sa * half[0] + axes[1][i] * sb * half[1] + axes[2][i] * sc * half[2] for i in range(3)))
    hull(pts, mat, bevel)

part("markers")
for sx, sz in QUADS:
    x, z = sx * AIR, sz * AIR
    cyl(3.2, 3.2, 0.0, 0.03, "dark", 8, 0.01, x, z)
    ring(3.0, 3.2, 0.03, 0.045, "hazard", 8, math.pi / 8, x=x, z=z)
    ring(2.3, 2.45, 0.03, 0.05, "strip", 16, 0, 0.08, x, z)
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        hull([(x + 1.0 * math.cos(a), 0.03, z + 1.0 * math.sin(a)), (x + 1.9 * math.cos(a + 0.25), 0.03, z + 1.9 * math.sin(a + 0.25)), (x + 1.9 * math.cos(a - 0.25), 0.03, z + 1.9 * math.sin(a - 0.25)), (x + 1.0 * math.cos(a), 0.06, z + 1.0 * math.sin(a))], "white", 0)

part("markings")
for d in DIRS:
    for side in (-1, 1):
        r = YARD_IN
        while r < HALF - 1.5:
            if all(abs(r + 0.7 - c) > CHOKE_R + 0.6 for c in CHOKES):
                lane_box(d, r, r + 1.4, side * (W - 1.0), side * (W - 0.85), *FLAT, "paint", 0)
            r += 2.0
    for k in range(3):
        r = HALF - 10.0 + k * 2.2
        for side in (-1, 1):
            pts = []
            for f, l in ((r, 0.0), (r + 0.5, 0.0), (r + 1.5, side * 2.0), (r + 2.0, side * 2.0)):
                for y in FLAT:
                    pts.append((d[0] * f - d[1] * l, y, d[1] * f + d[0] * l))
            hull(pts, "mark", 0)
    l = -HALF + 1.0
    while l < HALF - 2.4:
        if abs(l + 0.7) > SPAWN_GAP / 2 + 1.0:
            lane_box(d, HALF - 1.0, HALF - 0.85, l, l + 1.4, *FLAT, "paint", 0)
        l += 2.0

part("yard_floor")
e0 = math.sqrt(BLOCK ** 2 - W ** 2)
for sx, sz in QUADS:
    P = lambda a, b, y: (sx * a, y, sz * b)
    edge = []
    t0, t1 = math.atan2(e0, W), math.atan2(W, e0)
    for k in range(17):
        t = t0 + (t1 - t0) * k / 16
        edge.append((BLOCK * math.cos(t), BLOCK * math.sin(t)))
    for (a0, b0), (a1, b1) in zip(edge, edge[1:]):
        hull([P(a, b, y) for a, b in ((a0, b0), (a1, b1), (a0, HALF), (a1, HALF)) for y in (0.0, 0.01)], "yard", 0)
    hull([P(a, b, y) for a in (edge[-1][0], HALF) for b in (W, HALF) for y in (0.0, 0.01)], "yard", 0)

part("yard_arch")
for s in (-1, 1):
    z = s * (ARCH / 2 + 0.6)
    cyl(0.68, 0.6, 0.0, 4.2, "dark", 8, 0.02, 0, z)
    cyl(0.7, 0.68, 0.0, 0.3, "hazard", 8, 0.01, 0, z)
    for k in range(4):
        f = k * math.pi / 2
        rbox((0.03, 2.6, 0.08), (0.6 * math.cos(f), 2.2, z + 0.6 * math.sin(f)), f, "amber", 0)
box((1.2, 0.7, ARCH + 2.6), (0, 4.5, 0), "dark", 0.05)
box((1.3, 0.12, ARCH + 2.7), (0, 4.9, 0), "steel", 0.03)
for s in (-1, 1):
    box((0.04, 0.16, ARCH), (s * 0.61, 4.45, 0), "amber", 0)
box((1.21, 0.14, ARCH), (0, 4.14, 0), "paint", 0)

part("stands")
for d in DIRS:
    segs = ((-HALF, -STAND["aisle"] - STAND["aisle_w"]), (-STAND["aisle"] + STAND["aisle_w"], -STAND["gap"]), (STAND["gap"], STAND["aisle"] - STAND["aisle_w"]), (STAND["aisle"] + STAND["aisle_w"], HALF))
    for l0, l1 in segs:
        lane_box(d, HALF + 1.0, HALF + STAND["front"], l0, l1, 0.0, 0.03, "tread", 0)
        for k in range(STAND["tiers"]):
            o = HALF + STAND["front"] + k * STAND["depth"]
            h = STAND["base"] + k * STAND["rise"]
            lane_box(d, o, o + STAND["depth"], l0, l1, 0.0, h - 0.06, "concrete", 0.03)
            lane_box(d, o, o + STAND["depth"], l0, l1, h - 0.06, h, "tread", 0)
            lane_box(d, o - 0.06, o, l0, l1, h - 0.95, h - 0.35, "led_n", 0)
            for row in STAND["rows"]:
                lane_box(d, o + row + 0.12, o + row + 0.42, l0 + 0.2, l1 - 0.2, h, h + 0.22, "seat_b", 0.02)
                lane_box(d, o + row + 0.42, o + row + 0.52, l0 + 0.2, l1 - 0.2, h, h + 0.5, "seat_b", 0.02)
    for s in (-1, 1):
        a0, a1 = s * (STAND["aisle"] - STAND["aisle_w"]), s * (STAND["aisle"] + STAND["aisle_w"])
        for k in range(STAND["tiers"]):
            o = HALF + STAND["front"] + k * STAND["depth"]
            h = STAND["base"] + k * STAND["rise"]
            lane_box(d, o, o + STAND["depth"], a0, a1, 0.0, h, "aisle", 0.01)
        g0, g1 = s * STAND["gap"], s * (STAND["gap"] + 0.6)
        lane_box(d, HALF + 1.2, HALF + BACK, g0, g1, 0.0, 5.0, "concrete", 0.03)
        b0, b1 = s * (STAND["gap"] + 0.6), s * (HALF + BACK + 0.6)
        lane_box(d, HALF + BACK, HALF + BACK + 0.6, b0, b1, 0.0, STAND["wall"], "concrete", 0.03)
        lane_box(d, HALF + BACK - 0.05, HALF + BACK, b0, b1, 4.7, 5.5, "led_n", 0)
        lane_box(d, HALF + BACK - 0.45, HALF + BACK - 0.05, b0, b1, 6.6, 6.85, "flood", 0)
    lane_box(d, HALF + 1.2, HALF + BACK + 0.6, -STAND["gap"] - 0.6, STAND["gap"] + 0.6, 5.0, 5.4, "dark", 0.03)
    lane_box(d, HALF + BACK, HALF + BACK + 0.6, -STAND["gap"] - 0.6, STAND["gap"] + 0.6, 5.4, STAND["wall"], "concrete", 0.03)
    lane_box(d, HALF + BACK, HALF + BACK + STAND["roof"], -(HALF + BACK + STAND["roof"]), HALF + BACK + STAND["roof"], STAND["wall"], STAND["wall"] + 0.4, "roof", 0.02)
    lane_box(d, HALF + 1.2, HALF + BACK, -STAND["gap"], STAND["gap"], 0.0, 0.03, "tread", 0)
for sx, sz in QUADS:
    c = HALF + BACK / 2
    top = STAND["base"] + (STAND["tiers"] - 1) * STAND["rise"]
    box((BACK, top, BACK), (sx * c, top / 2, sz * c), "concrete", 0.04)
    box((BACK, 0.06, BACK), (sx * c, top + 0.03, sz * c), "tread", 0)

part("flood_tower")
cyl(0.4, 0.3, 0.0, 17.2, "steel", 8)
tilt = math.radians(35)
fwd = (math.cos(tilt), -math.sin(tilt), 0.0)
up = (math.sin(tilt), math.cos(tilt), 0.0)
side = (0.0, 0.0, 1.0)
c = (0.4, 17.8, 0.0)
obox(c, (side, up, fwd), (1.9, 1.15, 0.35), "dark")
obox(tuple(c[i] + fwd[i] * 0.36 for i in range(3)), (side, up, fwd), (1.7, 0.95, 0.03), "flood", 0)
obox(tuple(c[i] - up[i] * 1.2 - fwd[i] * 0.2 for i in range(3)), (side, up, fwd), (1.2, 0.12, 0.12), "steel")

part("crate")
box((1.6, 1.1, 1.2), (0, 0.55, 0), "rust", 0.03)
for a in (-1, 1):
    for b in (-1, 1):
        box((0.12, 1.14, 0.12), (a * 0.76, 0.57, b * 0.56), "trim", 0.01)
for y in (0.3, 0.8):
    for b in (-1, 1):
        box((1.5, 0.12, 0.04), (0, y, b * 0.61), "dark", 0)
box((0.5, 0.3, 0.02), (0, 0.55, 0.615), "paint", 0)

part("crate_lid")
box((1.7, 0.14, 1.3), (0, 0, 0), "rust", 0.02)
box((1.74, 0.06, 1.34), (0, -0.04, 0), "trim", 0.01)

part("camp_ring")
ring(2.6, 2.8, 0.015, 0.03, "amber", 24, 0, 0.08)
for k in range(4):
    a = k * math.pi / 2
    rbox((0.5, 0.015, 0.14), (3.1 * math.cos(a), 0.022, 3.1 * math.sin(a)), a, "amber", 0)

part("camp_pip")
hull([(x, y, z) for x, z in ((0.22, 0), (-0.22, 0), (0, 0.22), (0, -0.22)) for y in (0.015, 0.03)], "amber", 0)

part("work_light")
cyl(0.12, 0.1, 0.0, 4.2, "dark", 6, 0.01)
box((1.0, 0.1, 0.1), (0.45, 4.15, 0), "steel", 0.01)
box((0.5, 0.3, 0.7), (0.95, 4.0, 0), "dark", 0.03)
box((0.42, 0.04, 0.6), (0.95, 3.84, 0), "amber", 0)

part("heap")
for k, (rr, h, ph) in enumerate(((1.0, 0.0, 0.0), (0.72, 0.45, 1.3), (0.42, 0.85, 2.6))):
    pts = []
    for j in range(9):
        a = j * 2 * math.pi / 9 + ph
        q = rr * (0.8 + 0.2 * math.sin(a * 3 + k))
        pts.append((q * math.cos(a), h, q * math.sin(a)))
        pts.append((q * 0.75 * math.cos(a + 0.3), h + 0.38, q * 0.75 * math.sin(a + 0.3)))
    hull(pts, "rust" if k % 2 == 0 else "dark", 0.02)
for k in range(5):
    a = k * 1.7
    rbox((0.5, 0.1, 0.18), (0.55 * math.cos(a), 0.55 + 0.1 * k, 0.55 * math.sin(a)), a, "trim", 0.01)

part("crane")
box((3.0, 0.8, 3.0), (0, 0.4, 0), "dark", 0.05)
box((3.04, 0.3, 3.04), (0, 0.2, 0), "hazard", 0)
for a in (-1, 1):
    for b in (-1, 1):
        box((0.25, 11.4, 0.25), (a * 0.8, 6.5, b * 0.8), "steel", 0.02)
for y in range(2, 12, 2):
    for b in (-1, 1):
        box((1.7, 0.12, 0.12), (0, y + 0.8, b * 0.8), "trim", 0)
        box((0.12, 0.12, 1.7), (b * 0.8, y + 0.8, 0), "trim", 0)
box((2.2, 1.6, 2.2), (0, 12.9, 0), "dark", 0.05)
box((0.04, 0.5, 1.6), (1.11, 13.0, 0), "amber", 0)
for b in (-1, 1):
    box((17.0, 0.25, 0.25), (6.5, 13.9, b * 0.5), "steel", 0.02)
box((3.0, 1.2, 1.4), (-3.5, 13.6, 0), "dark", 0.04)
box((0.08, 6.2, 0.08), (14.0, 10.6, 0), "dark", 0)
cyl(1.3, 1.3, 6.9, 7.5, "dark", 12, 0.03, 14.0, 0.0)
ring(1.18, 1.32, 6.84, 6.9, "amber", 12, 0, 0.06, 14.0, 0.0)

part("steam_grate")
cyl(1.4, 1.4, 0.0, 0.05, "dark", 8, 0.01, rot=math.pi / 8)
for k in range(5):
    box((2.2, 0.02, 0.1), (0, 0.06, -0.8 + k * 0.4), "trim", 0)
for k in range(4):
    a = math.pi / 4 + k * math.pi / 2
    cyl(0.16, 0.16, 0.0, 0.6, "steel", 8, 0.01, 1.9 * math.cos(a), 1.9 * math.sin(a))
    cyl(0.2, 0.2, 0.55, 0.65, "dark", 8, 0.01, 1.9 * math.cos(a), 1.9 * math.sin(a))

part("dock")
cyl(2.0, 1.9, 0.0, 0.3, "dark", 8, 0.03, rot=math.pi / 8)
ring(1.92, 2.04, 0.08, 0.22, "hazard", 8, math.pi / 8)
cyl(1.7, 1.7, 0.3, 0.33, "steel", 8, 0.01, rot=math.pi / 8)
ring(1.74, 1.84, 0.3, 0.345, "strip", 8, math.pi / 8)
for x in (-1.2, 0.9):
    for z in (-1.8, 1.8):
        box((0.36, 4.2, 0.36), (x, 2.1, z), "dark", 0.03)
        box((0.04, 2.6, 0.12), (x + 0.19, 2.0, z), "strip", 0)
    box((0.4, 0.4, 4.0), (x, 4.2, 0), "steel", 0.03)
for z in (-1.8, 1.8):
    box((2.5, 0.3, 0.3), (-0.15, 4.25, z), "steel", 0.03)
box((0.06, 0.12, 3.2), (1.12, 3.9, 0), "strip", 0)

part("dock_lamp")
box((0.1, 0.24, 0.42), (0, 0, 0), "pylon", 0)

part("parts_bay")

def bar3(p0, p1, w, mat):
    hull([(p[0] + a * w, p[1] + b * w, p[2] + c * w) for p in (p0, p1) for a in (-1, 1) for b in (-1, 1) for c in (-1, 1)], mat, 0.01)

box((3.6, 0.25, 5.2), (0, 0.125, 0), "dark", 0.04)
box((3.64, 0.08, 5.24), (0, 0.2, 0), "steel", 0.02)
box((0.06, 0.06, 5.0), (1.81, 0.2, 0), "strip", 0)
for z in (-2.3, 2.3):
    box((0.3, 2.0, 0.3), (-1.5, 1.25, z), "dark", 0.03)
    box((0.04, 1.2, 0.1), (-1.33, 1.3, z), "strip", 0)
box((0.4, 0.25, 5.0), (-1.5, 2.3, 0), "steel", 0.03)
box((0.15, 1.4, 4.3), (-1.62, 0.95, 0), "dark", 0.02)
for y in (0.8, 1.5):
    box((0.5, 0.08, 4.0), (-1.35, y, 0), "trim", 0.01)
    box((0.02, 0.04, 3.8), (-1.09, y + 0.06, 0), "strip", 0)
box((0.9, 1.0, 4.2), (1.15, 0.75, 0), "steel", 0.04)
box((1.0, 0.1, 4.4), (1.15, 1.3, 0), "trim", 0.02)
box((0.94, 0.03, 4.0), (1.15, 1.36, 0), "counter", 0)
box((0.04, 0.5, 3.6), (1.61, 0.8, 0), "counter", 0)
for z in (-1.6, 1.6):
    cyl(0.35, 0.3, 0.25, 0.6, "dark", 8, 0.02, -0.7, z)
    bar3((-0.7, 0.6, z), (-0.5, 1.9, z * 0.95), 0.12, "trim")
    bar3((-0.5, 1.9, z * 0.95), (0.1, 2.5, z * 0.8), 0.1, "trim")
    cyl(0.16, 0.16, 1.82, 1.98, "dark", 8, 0, -0.5, z * 0.95)
    for k in (-1, 1):
        bar3((0.1, 2.5, z * 0.8), (0.4, 2.35, z * 0.8 + k * 0.18), 0.04, "steel")
    box((0.06, 0.06, 0.06), (0.1, 2.5, z * 0.8), "strip", 0)

part("fortress")
GATE_HALF = math.atan2(LANE_W / 2 + 1.6, FORT)
for k in range(4):
    a = k * math.pi / 2 - math.pi / 2
    a0, a1 = a + GATE_HALF, a + math.pi / 2 - GATE_HALF
    arc(RING_IN, RING_OUT, 0.0, 2.6, a0, a1, "dark", 10, 0.03)
    arc(RING_IN - 0.1, RING_OUT + 0.1, 2.6, 2.85, a0, a1, "steel", 10, 0.02)
    arc(RING_IN - 0.04, RING_IN, 1.9, 2.0, a0 + 0.02, a1 - 0.02, "strip", 10)
    arc(RING_OUT, RING_OUT + 0.15, 0.0, 0.35, a0, a1, "hazard", 10)
    for j in range(1, 5):
        b = a0 + (a1 - a0) * j / 5
        rbox((2.0, 3.1, 0.5), (FORT * math.cos(b), 1.55, FORT * math.sin(b)), b, "trim", 0.03)

part("plaza")
cyl(PLAZA, PLAZA, 0.0, 0.04, "steel", 32, 0.01)
ring(PLAZA - 0.6, PLAZA, 0.04, 0.06, "hazard", 32)
ring(PLAZA - 1.3, PLAZA - 1.1, 0.04, 0.065, "strip", 32, 0, 0.04)
ring(REPAIR - 0.15, REPAIR + 0.15, 0.04, 0.065, "strip", 24, 0, 0.12)
ring(7.2, 7.5, 0.04, 0.06, "trim", 24)
for k in range(8):
    a = k * math.pi / 4
    rbox((PLAZA - 8.4, 0.03, 0.08), ((7.5 + (PLAZA - 7.5 - 0.6) / 2) * math.cos(a), 0.055, (7.5 + (PLAZA - 7.5 - 0.6) / 2) * math.sin(a)), a, "dark", 0)
for dx, dz in DIRS[:2] + DIRS[3:]:
    for j in range(3):
        r = 9.0 + j * 1.2
        for sd in (-1, 1):
            pt = lambda f, l, y=0.05: (dx * f - dz * sd * l, y, dz * f + dx * sd * l)
            hull([pt(r + 0.5, 0), pt(r, 1.2), pt(r + 0.35, 1.2), pt(r + 0.85, 0, 0.07)], "white", 0)

part("core_base")
cyl(4.6, 4.4, 0.0, 0.5, "dark", 16, 0.02)
cyl(4.4, 4.4, 0.5, 0.6, "steel", 16, 0.01)
ring(3.55, 4.05, 0.6, 0.63, "dark", 32)
cyl(1.7, 1.7, 0.6, 4.0, "dark", 12, 0.03)
cyl(1.85, 1.85, 0.6, 0.85, "steel", 12, 0.02)
cyl(1.78, 1.78, 2.2, 2.35, "trim", 12, 0.01)
cyl(1.85, 1.85, 3.85, 4.05, "steel", 12, 0.02)

part("core_plasma")
cyl(0.46, 0.46, 3.9, 7.0, "plasma", 8, 0.01)
ring(1.0, 1.2, 6.45, 6.6, "plasma", 16)
for k in range(4):
    a = k * math.pi / 2
    rbox((0.7, 0.1, 0.12), (0.78 * math.cos(a), 6.52, 0.78 * math.sin(a)), a, "plasma", 0)

part("core_plasma_in")
cyl(0.4, 0.4, 6.98, 7.06, "plasma_in", 8, 0)
for k in range(8):
    a = k * math.pi / 4
    rbox((0.04, 2.9, 0.1), (0.43 * math.cos(a), 5.5, 0.43 * math.sin(a)), a, "plasma_in", 0)

PETAL_IN, PETAL_OUT, PETAL_HALF, PETAL_SEGS = 2.1, 2.65, math.radians(34), 6
PETAL_BANDS = ((0.7, 1.15, 0.0, 0.03, "hazard"), (1.15, 4.35, 0.03, 0.28, "petal"), (4.35, 4.6, 0.28, 0.32, "petal_edge"))
for i in range(4):
    part("petal%d" % (i + 1))
    mid = math.pi / 4 + i * math.pi / 2
    for j in range(PETAL_SEGS):
        a0 = mid - PETAL_HALF + 2 * PETAL_HALF * j / PETAL_SEGS
        a1 = mid - PETAL_HALF + 2 * PETAL_HALF * (j + 1) / PETAL_SEGS
        for y0, y1, l0, l1, mat in PETAL_BANDS:
            hull([((r + l) * math.cos(a), y, (r + l) * math.sin(a)) for r in (PETAL_IN, PETAL_OUT) for a in (a0, a1) for y, l in ((y0, l0), (y1, l1))], mat, 0)

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

part("mod_wall")
box((1.2, 2.0, 6.0), (0, 1.12, 0), "steel", 0.06)
for z in (-2.4, -1.2, 0.0, 1.2, 2.4):
    box((1.36, 1.8, 0.3), (0, 1.02, z), "trim", 0.03)
box((1.3, 0.2, 6.1), (0, 2.2, 0), "dark", 0.03)
box((0.06, 0.12, 5.6), (0.66, 1.7, 0), "strip", 0)
box((0.06, 0.12, 5.6), (-0.66, 1.7, 0), "strip", 0)

part("mod_mine")
for x, z in ((-0.9, -0.9), (0.9, -0.9), (-0.9, 0.9), (0.9, 0.9)):
    cyl(0.45, 0.4, 0.12, 0.3, "dark", 8, 0.02, x, z)
    cyl(0.18, 0.18, 0.3, 0.36, "strip", 8, 0, x, z)

for name, (ob, bm) in parts.items():
    bm.to_mesh(ob.data)
    bm.free()
    for p in ob.data.polygons:
        p.use_smooth = False
    print(name, len(ob.data.polygons), "faces", "%.2f x %.2f x %.2f" % tuple(ob.dimensions))
