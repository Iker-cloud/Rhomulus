"""Convierte un modelo .glb de assets/ en un módulo Lua de src/server/ZombieData/ (piezas, colores y articulaciones).
Uso: python tools/glb_to_lua.py <archivo-sin-.glb> <NombreDelModulo> [escala] [articulaciones]
  articulaciones = lista separada por comas de los únicos grupos que serán articulación (p. ej. "tapa" en las cajas); por defecto todos
Ejemplos:
  python tools/glb_to_lua.py zombie-el-brotado Brotado 2.8
  python tools/glb_to_lua.py zombie-el-desbocado Desbocado 3.0
  python tools/glb_to_lua.py caja-municion CajaMunicion 3.0 tapa"""
import struct, json, math, sys

import os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if len(sys.argv) < 3:
    print(__doc__)
    sys.exit(1)
GLB = os.path.join(ROOT, "assets", sys.argv[1] + ".glb")
MODULE = sys.argv[2]
OUT = os.path.join(ROOT, "src", "server", "ZombieData", MODULE + ".luau")
SCALE = float(sys.argv[3]) if len(sys.argv) > 3 else 2.8  # metros del modelo -> studs (2.8 = unos 5.9 studs de alto)

data = open(GLB, "rb").read()
off = 12
gltf = None
bin_chunk = None
while off < len(data):
    clen, ctype = struct.unpack("<I4s", data[off:off + 8])
    chunk = data[off + 8:off + 8 + clen]
    if ctype == b"JSON":
        gltf = json.loads(chunk)
    elif ctype.startswith(b"BIN"):
        bin_chunk = chunk
    off += 8 + clen

accessors, views, nodes = gltf["accessors"], gltf["bufferViews"], gltf["nodes"]

def read_positions(i):
    acc = accessors[i]
    view = views[acc["bufferView"]]
    stride = view.get("byteStride", 12)
    base = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    return [struct.unpack_from("<fff", bin_chunk, base + k * stride) for k in range(acc["count"])]

def mat_mul(a, b):
    # matrices 4x4 como listas de 16 en orden columna (como glTF): m[col*4+row]
    out = [0.0] * 16
    for c in range(4):
        for r in range(4):
            out[c * 4 + r] = sum(a[k * 4 + r] * b[c * 4 + k] for k in range(4))
    return out

IDENT = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]
# giro de 180 grados sobre Y: el frente del modelo (+Z en glTF) pasa a -Z, el frente de Roblox
FLIP = [-1, 0, 0, 0, 0, 1, 0, 0, 0, 0, -1, 0, 0, 0, 0, 1]

def local_matrix(n):
    if "matrix" in n:
        return list(n["matrix"])
    t = n.get("translation", [0, 0, 0])
    m = list(IDENT)
    m[12], m[13], m[14] = t
    return m

def srgb(c):
    c = max(0.0, min(1.0, c))
    return 12.92 * c if c <= 0.0031308 else 1.055 * (c ** (1 / 2.4)) - 0.055

parent = {}
for i, n in enumerate(nodes):
    for c in n.get("children", []):
        parent[c] = i

world = {}
def get_world(i):
    if i in world:
        return world[i]
    m = local_matrix(nodes[i])
    if i in parent:
        m = mat_mul(get_world(parent[i]), m)
    world[i] = m
    return m

def to_roblox(m):
    """Aplica el giro de 180 grados y la escala. Devuelve (x, y, z, r00..r22) estilo CFrame.new(x,y,z,R00,R01,R02,R10,...)."""
    w = mat_mul(FLIP, m)
    x, y, z = w[12] * SCALE, w[13] * SCALE, w[14] * SCALE
    # columna c = eje c; CFrame.new(..., R00,R01,R02, R10,R11,R12, R20,R21,R22) es por filas
    rows = [[w[c * 4 + r] for c in range(3)] for r in range(3)]
    flat = [rows[r][c] for r in range(3) for c in range(3)]
    return [x, y, z] + flat

def is_group(i):
    return "mesh" not in nodes[i]

def group_of(i):
    j = parent.get(i)
    while j is not None and not ("children" in nodes[j] and any(("mesh" not in nodes[c]) or True for c in nodes[j]["children"]) and is_group(j)):
        j = parent.get(j)
    return j

# grupos = nodos sin malla que tienen hijos
ONLY = set(sys.argv[4].split(",")) if len(sys.argv) > 4 else None
groups = [i for i, n in enumerate(nodes) if "mesh" not in n and n.get("children") and (ONLY is None or n.get("name") in ONLY or i not in parent)]
group_names = {i: nodes[i].get("name", f"grupo_{i}") for i in groups}  # hay nodos de giro sin nombre (clavos del bate)

def nearest_group(i):
    j = parent.get(i)
    while j is not None and j not in group_names:
        j = parent.get(j)
    return j

# --- partes ---
parts = []
min_y, max_y = 1e9, -1e9
min_x, max_x, min_z, max_z = 1e9, -1e9, 1e9, -1e9
gbounds = {}  # grupo -> [min x, max x, min y, max y, min z, max z]
for i, n in enumerate(nodes):
    if "mesh" not in n:
        continue
    mesh = gltf["meshes"][n["mesh"]]
    prim = mesh["primitives"][0]
    pos = read_positions(prim["attributes"]["POSITION"])
    w_full = get_world(i)
    # Los nodos pueden traer escala (columnas de la matriz que no miden 1): se pasa a las medidas de la pieza y la matriz queda solo
    # con el giro, porque un CFrame de Roblox no admite escala.
    sc = [math.sqrt(sum(w_full[c * 4 + r] ** 2 for r in range(3))) or 1.0 for c in range(3)]
    w = list(w_full)
    for c in range(3):
        for r in range(3):
            w[c * 4 + r] = w_full[c * 4 + r] / sc[c]
    pos_raw = pos
    pos = [[p[k] * sc[k] for k in range(3)] for p in pos_raw]
    lo = [min(p[k] for p in pos) for k in range(3)]
    hi = [max(p[k] for p in pos) for k in range(3)]
    size = [hi[k] - lo[k] for k in range(3)]
    center = [(hi[k] + lo[k]) / 2 for k in range(3)]
    # posición del centro de la pieza en el mundo
    ctr = mat_mul(w, [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, center[0], center[1], center[2], 1])
    # Forma: caja (8 vértices distintos), esfera (todos a la misma distancia del centro), cilindro (dos medidas
    # iguales y una distinta: discos, aros planos, varillas) o, si no encaja, caja del tamaño de la pieza.
    uniq = {tuple(round(c, 4) for c in p) for p in pos}
    shape = "Block"
    if len(uniq) > 8:
        radii = [math.dist(p, center) for p in uniq]
        near = lambda a, b: abs(a - b) <= 0.12 * max(a, b)
        if max(radii) - min(radii) < 0.03 * max(radii) and near(size[0], size[1]) and near(size[1], size[2]):
            shape = "Ball"
            d = max(size)
            size = [d, d, d]
        else:
            for axis in range(3):
                others = [size[k] for k in range(3) if k != axis]
                if near(others[0], others[1]) and abs(size[axis] - max(others)) > 0.12 * max(size):
                    shape = "Cylinder"
                    length, diameter = size[axis], max(others)
                    size = [length, diameter, diameter]
                    # el eje de un cilindro de Roblox es X: se gira para que coincida con el eje de la pieza
                    if axis == 1:
                        rot = [0, 1, 0, 0, -1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]  # X -> Y (giro de 90 grados sobre Z)
                    elif axis == 2:
                        rot = [0, 0, -1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1]  # X -> Z (giro de 90 grados sobre Y)
                    else:
                        rot = IDENT
                    ctr = mat_mul(ctr, rot)
                    break
    cf = to_roblox(ctr)
    is_ball = shape == "Ball"
    material = gltf["materials"][prim.get("material", 0)]
    base = material["pbrMetallicRoughness"].get("baseColorFactor", [1, 1, 1, 1])  # las texturas no traen color
    emissive = material.get("emissiveFactor")
    color = [round(srgb(base[k]) * 255) for k in range(3)]
    parts.append({
        "name": n["name"],
        "group": group_names[nearest_group(i)],
        "shape": shape,
        "size": [round(s * SCALE, 3) for s in size],
        "cf": [round(v, 4) for v in cf],
        "color": color,
        "neon": bool(emissive and max(emissive) > 0.1),
        # las piezas con textura no traen color: el constructor del mapa decide cómo se ven según el nombre del material
        "mat": material["name"] if (material["pbrMetallicRoughness"].get("baseColorTexture") or material.get("emissiveTexture")) else None,
    })
    # extremos para la altura
    for p in pos_raw:
        pw = mat_mul(w_full, [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, p[0], p[1], p[2], 1])
        y = pw[13] * SCALE
        min_y, max_y = min(min_y, y), max(max_y, y)
        fx, fz = -pw[12] * SCALE, -pw[14] * SCALE  # tras el giro de 180 grados
        min_x, max_x = min(min_x, fx), max(max_x, fx)
        min_z, max_z = min(min_z, fz), max(max_z, fz)
        gb = gbounds.setdefault(group_names[nearest_group(i)], [1e9, -1e9, 1e9, -1e9, 1e9, -1e9])
        gb[0], gb[1] = min(gb[0], fx), max(gb[1], fx)
        gb[2], gb[3] = min(gb[2], y), max(gb[3], y)
        gb[4], gb[5] = min(gb[4], fz), max(gb[5], fz)

# --- articulaciones ---
joints = []
def walk(i):
    for c in nodes[i].get("children", []):
        if c in group_names:
            joints.append({
                "name": group_names[c],
                "parent": group_names[i],
                "cf": [round(v, 4) for v in to_roblox(get_world(c))],
            })
            walk(c)
root = [i for i in groups if i not in parent][0]
root_cf = [round(v, 4) for v in to_roblox(get_world(root))]
walk(root)
# La tapa gira sobre su borde trasero (+z, el frente es -z), a la altura de su cara inferior
for j in joints:
    if j["name"] == "tapa":
        gb = gbounds["tapa"]
        j["cf"][0] = round((gb[0] + gb[1]) / 2, 4)
        j["cf"][1] = round(gb[2], 4)
        j["cf"][2] = round(gb[5], 4)

def fmt_cf(cf):
    return "CFrame.new(" + ", ".join(f"{v:g}" for v in cf) + ")"

lines = []
lines.append(f"-- GENERADO desde assets/{sys.argv[1]}.glb con tools/glb_to_lua.py (no editar a mano): piezas, colores y articulaciones.")
lines.append("-- Unidades en studs, con los pies en y = 0 y el frente hacia -Z. Cada pieza va soldada a su grupo; los grupos")
lines.append("-- se unen con Motor6D en las articulaciones (cadera, rodilla, hombro, codo, cuello, mandíbula).")
lines.append("return {")
lines.append(f"\trig = \"{MODULE}\",")
lines.append(f"\tscale = {SCALE},")
lines.append(f"\tminY = {min_y:.3f},")
lines.append(f"\tmaxY = {max_y:.3f},")
lines.append(f"\tbounds = {{ min = Vector3.new({min_x:.3f}, {min_y:.3f}, {min_z:.3f}), max = Vector3.new({max_x:.3f}, {max_y:.3f}, {max_z:.3f}) }},")
lines.append(f"\troot = {{ name = \"{group_names[root]}\", cf = {fmt_cf(root_cf)} }},")
lines.append("\tjoints = {")
for j in joints:
    lines.append(f"\t\t{{ name = \"{j['name']}\", parent = \"{j['parent']}\", cf = {fmt_cf(j['cf'])} }},")
lines.append("\t},")
lines.append("\tparts = {")
for p in parts:
    lines.append(
        f"\t\t{{ name = \"{p['name']}\", group = \"{p['group']}\", shape = \"{p['shape']}\", "
        f"size = Vector3.new({p['size'][0]:g}, {p['size'][1]:g}, {p['size'][2]:g}), "
        f"cf = {fmt_cf(p['cf'])}, color = Color3.fromRGB({p['color'][0]}, {p['color'][1]}, {p['color'][2]})"
        + (", neon = true" if p["neon"] else "") + (f", mat = \"{p['mat']}\"" if p.get("mat") else "") + " },"
    )
lines.append("\t},")
lines.append("}")
os.makedirs(os.path.dirname(OUT), exist_ok=True)
open(OUT, "w", encoding="utf-8", newline="\n").write("\n".join(lines) + "\n")

print("partes:", len(parts), "articulaciones:", len(joints), "altura:", round(max_y - min_y, 2), "minY", round(min_y, 2), "maxY", round(max_y, 2))
print("raíz:", group_names[root], root_cf[:3])
for j in joints:
    print("  joint", j["name"], "<-", j["parent"], [round(v, 2) for v in j["cf"][:3]])
tiny = [p["name"] for p in parts if p["size"][0] * p["size"][1] * p["size"][2] < 0.02]
print("pequeñas (<0.02 studs³):", len(tiny), tiny)
