#!/usr/bin/env python3
"""Split a Rodin tower GLB into a static base + a rotating crown, and (optionally) split a
fused weapon barrel into twin barrels.

WHY THIS EXISTS
---------------
Rodin reconstructs a tower as ONE connected body. `Tower.gd` needs the weapon crown as a
separate node so `_find_child_named(model, "crown")` can lift it out and reparent it under
`_turret`, which yaws to track targets. The Plasma Bastion was split ad-hoc in 2026-07-25;
this script generalises that pass so every future tower gets the same treatment.

It also handles a second Rodin failure: at Quad 8000 a pair of closely-spaced barrels fuses
into one central barrel (observed on the Sentry Spire 2026-07-27 — V1 at Quad 18000 had twin
barrels at x +/-0.235, V2 at Quad 8000 had one barrel at x ~= 0). Rather than re-roll the
geometry (which loses the seed and every measurement), the fused barrel is cut at its root
plane, shrunk, and instanced twice at the authored separation.

METHOD
------
CROWN SPLIT
  Partition triangles by centroid Y at --seam. Both halves become separate primitives under
  separate nodes ("<prefix>_base" / "<prefix>_crown"). The two primitives REUSE the same
  attribute accessors, the same material and the same images -- only new INDEX accessors are
  appended, so the file grows by a few hundred KB rather than duplicating textures.

BARREL SPLIT (optional, --barrel-z)
  a. Barrel vertex set B = crown verts with z >= --barrel-z. The root plane is found by
     scanning cross-section width; pass the z where the housing steps down to the barrel.
  b. The ORIGINAL barrel is FLATTENED onto the root plane (z := barrel_z, normal := +Z). This
     closes the housing's front face with no new cap geometry and no hole -- the boundary
     triangles that straddled the root plane become the bezel around a flat face.
  c. Two copies of the barrel submesh are appended, each scaled about the barrel axis by
     --barrel-scale (in X and Y, so it stays round) and translated to x = -/+ --barrel-x.
     Copies reuse the material; their root openings sit flush against the flattened face.

USAGE
-----
  python tools/split_tower_glb.py IN.glb OUT.glb --seam 1.52 --prefix spire \
      --barrel-z 0.36 --barrel-x 0.235 --barrel-scale 0.6
  python tools/split_tower_glb.py IN.glb OUT.glb --seam 1.04 --prefix bastion   # crown only
  python tools/split_tower_glb.py IN.glb --scan                                 # find the seam
"""

import argparse
import json
import struct
import sys

import numpy as np

COMPONENT_TYPES = {5120: ("<i1", 1), 5121: ("<u1", 1), 5122: ("<i2", 2),
                   5123: ("<u2", 2), 5125: ("<u4", 4), 5126: ("<f4", 4)}
TYPE_COUNTS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


# --------------------------------------------------------------------------- glb io

def load_glb(path):
    data = open(path, "rb").read()
    magic, _, total = struct.unpack("<III", data[:12])
    if magic != 0x46546C67:
        sys.exit(f"{path} is not a GLB (bad magic)")
    off, chunks = 12, []
    while off < total:
        clen, ctype = struct.unpack("<II", data[off:off + 8])
        chunks.append((ctype, data[off + 8:off + 8 + clen]))
        off += 8 + clen
    gltf = json.loads(chunks[0][1].decode("utf-8"))
    binary = chunks[1][1] if len(chunks) > 1 else b""
    return gltf, bytearray(binary)


def write_glb(path, gltf, binary):
    while len(binary) % 4:
        binary.append(0)
    gltf["buffers"] = [{"byteLength": len(binary)}]
    js = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    while len(js) % 4:
        js += b" "
    total = 12 + 8 + len(js) + 8 + len(binary)
    with open(path, "wb") as fh:
        fh.write(struct.pack("<III", 0x46546C67, 2, total))
        fh.write(struct.pack("<II", len(js), 0x4E4F534A)); fh.write(js)
        fh.write(struct.pack("<II", len(binary), 0x004E4942)); fh.write(bytes(binary))


def read_accessor(gltf, binary, index):
    acc = gltf["accessors"][index]
    view = gltf["bufferViews"][acc["bufferView"]]
    fmt, size = COMPONENT_TYPES[acc["componentType"]]
    n = TYPE_COUNTS[acc["type"]]
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    raw = binary[start:start + acc["count"] * n * size]
    arr = np.frombuffer(bytes(raw), dtype=fmt)
    return arr.reshape(-1, n) if n > 1 else arr


def append_buffer(gltf, binary, payload):
    while len(binary) % 4:
        binary.append(0)
    offset = len(binary)
    binary.extend(payload)
    gltf.setdefault("bufferViews", []).append(
        {"buffer": 0, "byteOffset": offset, "byteLength": len(payload)})
    return len(gltf["bufferViews"]) - 1


def add_index_accessor(gltf, binary, indices):
    indices = np.asarray(indices, dtype=np.uint32)
    view = append_buffer(gltf, binary, indices.tobytes())
    gltf["accessors"].append({"bufferView": view, "componentType": 5125,
                              "count": int(indices.size), "type": "SCALAR"})
    return len(gltf["accessors"]) - 1


def add_vec_accessor(gltf, binary, arr, kind):
    arr = np.ascontiguousarray(arr, dtype=np.float32)
    view = append_buffer(gltf, binary, arr.tobytes())
    acc = {"bufferView": view, "componentType": 5126,
           "count": int(arr.shape[0]), "type": kind}
    if kind == "VEC3":
        acc["min"] = arr.min(axis=0).tolist()
        acc["max"] = arr.max(axis=0).tolist()
    gltf["accessors"].append(acc)
    return len(gltf["accessors"]) - 1


# --------------------------------------------------------------------------- passes

def remap_roughness(gltf, binary, lo, hi):
    """Stretch the packed metallic-roughness texture's G channel into [lo, hi].

    Rodin returns Architect ceramic at roughness p50 ~0.94-0.97 with under ~1% of the surface
    below 0.35 -- flat chalk, where the concept and docs/DESIGN-GUIDELINES.md both call for
    near-mirror polished plate. Measured on three structures (FOB, Plasma Bastion 0.950,
    Sentry Spire V1 0.973 / V2 0.941), and PBR Temperature 5 barely moved it, so the fix
    belongs here rather than in another material pass.

    This is a percentile STRETCH, not a clamp: the p01..p99 window is expanded into [lo, hi],
    so relative variation between plate and recess is preserved (and in fact amplified). The
    guidelines forbid flattening surface detail; they permit tuning response.
    """
    from PIL import Image
    import io

    materials = gltf.get("materials", [])
    if not materials:
        print("  ! no materials; skipping roughness remap")
        return
    pbr = materials[0].get("pbrMetallicRoughness", {})
    tex = pbr.get("metallicRoughnessTexture")
    if tex is None:
        print("  ! no metallicRoughness texture; skipping roughness remap")
        return
    image_index = gltf["textures"][tex["index"]]["source"]
    view_index = gltf["images"][image_index]["bufferView"]
    view = gltf["bufferViews"][view_index]
    start = view.get("byteOffset", 0)
    raw = bytes(binary[start:start + view["byteLength"]])

    img = Image.open(io.BytesIO(raw)).convert("RGB")
    arr = np.asarray(img).astype(np.float32) / 255.0
    g = arr[..., 1]
    p01, p99 = np.percentile(g, 1), np.percentile(g, 99)
    before = np.percentile(g, 50)
    if p99 - p01 < 1e-4:
        print("  ! roughness is constant; skipping remap")
        return
    arr[..., 1] = np.clip((g - p01) / (p99 - p01), 0.0, 1.0) * (hi - lo) + lo
    after = np.percentile(arr[..., 1], 50)

    out = io.BytesIO()
    Image.fromarray((arr * 255.0).round().astype(np.uint8)).save(out, format="PNG")
    payload = out.getvalue()
    new_view = append_buffer(gltf, binary, payload)
    gltf["images"][image_index]["bufferView"] = new_view
    print("  roughness remap: p50 %.3f -> %.3f  (window %.3f..%.3f into %.2f..%.2f)"
          % (before, after, p01, p99, lo, hi))


def scan(positions):
    """Print a radius-by-height profile so the operator can pick the collar seam."""
    radius = np.sqrt(positions[:, 0] ** 2 + positions[:, 2] ** 2)
    y = positions[:, 1]
    print(" yLo   yHi   maxR    n")
    step = (y.max() - y.min()) / 40.0
    for lo in np.arange(y.min(), y.max(), step):
        sel = (y >= lo) & (y < lo + step)
        if sel.sum() < 10:
            continue
        print("%5.3f %5.3f  %.3f  %d" % (lo, lo + step, radius[sel].max(), sel.sum()))


def split_barrel(pos, nrm, uv, tan, tris, in_barrel, barrel_z, barrel_x, barrel_scale):
    """Flatten the fused barrel onto its root plane and append two shrunk copies.

    `in_barrel` is a per-vertex bool mask (crown AND forward of the root plane).
    Returns (pos, nrm, uv, tan, extra_tris). The caller keeps `tris` as-is: the original
    barrel triangles are retained but now lie flat on the root plane, sealing the housing.
    """
    if not in_barrel.any():
        print("  ! no verts beyond barrel-z; skipping barrel split")
        return pos, nrm, uv, tan, np.empty((0, 3), np.uint32)

    idx = np.where(in_barrel)[0]
    barrel_tris = tris[np.all(in_barrel[tris], axis=1)]
    axis_y = float((pos[idx, 1].min() + pos[idx, 1].max()) * 0.5)
    axis_x = float((pos[idx, 0].min() + pos[idx, 0].max()) * 0.5)
    print("  barrel: %d verts, %d tris, axis x %.4f y %.4f, z %.3f..%.3f"
          % (idx.size, len(barrel_tris), axis_x, axis_y, pos[idx, 2].min(), pos[idx, 2].max()))

    # -- two shrunk copies at +/- barrel_x -----------------------------------
    remap = -np.ones(len(pos), np.int64)
    remap[idx] = np.arange(idx.size)
    new_pos, new_nrm, new_uv, new_tan, extra = [], [], [], [], []
    for sign in (-1.0, 1.0):
        base = len(pos) + sum(len(p) for p in new_pos)
        p = pos[idx].copy()
        p[:, 0] = (p[:, 0] - axis_x) * barrel_scale + sign * barrel_x
        p[:, 1] = (p[:, 1] - axis_y) * barrel_scale + axis_y
        new_pos.append(p)
        new_nrm.append(nrm[idx].copy())
        if uv is not None:
            new_uv.append(uv[idx].copy())
        if tan is not None:
            new_tan.append(tan[idx].copy())
        extra.append(remap[barrel_tris] + base)

    # -- flatten the original onto the root plane, sealing the housing face ---
    pos = pos.copy()
    nrm = nrm.copy()
    pos[idx, 2] = barrel_z
    nrm[idx] = np.array([0.0, 0.0, 1.0], np.float32)

    pos = np.vstack([pos] + new_pos).astype(np.float32)
    nrm = np.vstack([nrm] + new_nrm).astype(np.float32)
    if uv is not None:
        uv = np.vstack([uv] + new_uv).astype(np.float32)
    if tan is not None:
        tan = np.vstack([tan] + new_tan).astype(np.float32)
    return pos, nrm, uv, tan, np.vstack(extra).astype(np.uint32)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("dst", nargs="?")
    ap.add_argument("--seam", type=float, help="Y of the rotation collar waist")
    ap.add_argument("--prefix", default="tower", help="node name prefix (-> <p>_base / <p>_crown)")
    ap.add_argument("--barrel-z", type=float, default=None, help="Z of the barrel root plane")
    ap.add_argument("--barrel-x", type=float, default=0.235, help="target |x| of each barrel")
    ap.add_argument("--barrel-scale", type=float, default=0.6, help="shrink factor per barrel")
    ap.add_argument("--scan", action="store_true", help="print a radius-by-height profile and exit")
    ap.add_argument("--roughness", type=float, nargs=2, metavar=("LO", "HI"), default=None,
                    help="stretch the packed MR texture's G channel into [LO, HI] "
                         "(Architect ceramic: 0.18 0.55)")
    ap.add_argument("--trunnion-z", type=float, default=None,
                    help="split the CROWN again at this Z into a static housing and a pitching "
                         "barrel group (-> <p>_crown / <p>_barrels). Use where the barrels step "
                         "out of the housing, so elevation moves the guns and not the whole "
                         "crown -- and so recoil slides the barrels back instead of lifting the "
                         "crown out of its collar.")
    args = ap.parse_args()

    gltf, binary = load_glb(args.src)
    mesh = gltf["meshes"][0]
    if len(mesh["primitives"]) != 1:
        sys.exit("expected a single primitive (an unsplit Rodin export)")
    prim = mesh["primitives"][0]
    attrs = prim["attributes"]

    pos = read_accessor(gltf, binary, attrs["POSITION"]).astype(np.float32)
    tris = read_accessor(gltf, binary, prim["indices"]).astype(np.uint32).reshape(-1, 3)
    if args.scan:
        scan(pos)
        return

    if args.seam is None:
        sys.exit("--seam is required (run with --scan to find the collar)")

    nrm = read_accessor(gltf, binary, attrs["NORMAL"]).astype(np.float32)
    uv = read_accessor(gltf, binary, attrs["TEXCOORD_0"]).astype(np.float32) \
        if "TEXCOORD_0" in attrs else None
    tan = read_accessor(gltf, binary, attrs["TANGENT"]).astype(np.float32) \
        if "TANGENT" in attrs else None

    print("input: %d verts, %d tris" % (len(pos), len(tris)))

    extra = np.empty((0, 3), np.uint32)
    if args.barrel_z is not None:
        # The barrel is crown geometry forward of the root plane. Gating on the crown as well
        # as on Z matters: the spire's base skirt also reaches past the barrel root in Z, and
        # flattening that would collapse the front of the building.
        in_barrel = (pos[:, 1] >= args.seam) & (pos[:, 2] >= args.barrel_z)
        pos, nrm, uv, tan, extra = split_barrel(
            pos, nrm, uv, tan, tris, in_barrel,
            args.barrel_z, args.barrel_x, args.barrel_scale)

    all_tris = np.vstack([tris, extra]) if len(extra) else tris
    centroid = pos[all_tris].mean(axis=1)
    crown_sel = centroid[:, 1] >= args.seam
    crown_idx = all_tris[crown_sel].reshape(-1)
    base_idx = all_tris[~crown_sel].reshape(-1)
    print("split at y=%.3f -> base %d tris / crown %d tris"
          % (args.seam, (~crown_sel).sum(), crown_sel.sum()))

    # Rewrite the shared vertex attributes (barrel split changed them), then point BOTH
    # primitives at those same accessors -- only the index accessors differ.
    new_attrs = dict(attrs)
    new_attrs["POSITION"] = add_vec_accessor(gltf, binary, pos, "VEC3")
    new_attrs["NORMAL"] = add_vec_accessor(gltf, binary, nrm, "VEC3")
    if uv is not None:
        new_attrs["TEXCOORD_0"] = add_vec_accessor(gltf, binary, uv, "VEC2")
    if tan is not None:
        new_attrs["TANGENT"] = add_vec_accessor(gltf, binary, tan, "VEC4")

    material = prim.get("material", 0)

    def mesh_for(name, idx):
        return {"name": name, "primitives": [
            {"attributes": new_attrs, "indices": add_index_accessor(gltf, binary, idx),
             "material": material}]}

    if args.trunnion_z is not None:
        crown_tris = all_tris[crown_sel]
        fwd = centroid[crown_sel][:, 2] >= args.trunnion_z
        barrel_idx = crown_tris[fwd].reshape(-1)
        housing_idx = crown_tris[~fwd].reshape(-1)
        print("  trunnion z=%.3f -> housing %d tris / barrels %d tris"
              % (args.trunnion_z, (~fwd).sum(), fwd.sum()))
        gltf["meshes"] = [mesh_for(f"{args.prefix}_base", base_idx),
                          mesh_for(f"{args.prefix}_crown", housing_idx),
                          mesh_for(f"{args.prefix}_barrels", barrel_idx)]
        gltf["nodes"] = [
            {"name": "model", "children": [1, 2, 3]},
            {"name": f"{args.prefix}_base", "mesh": 0},
            {"name": f"{args.prefix}_crown", "mesh": 1},
            {"name": f"{args.prefix}_barrels", "mesh": 2},
        ]
    else:
        gltf["meshes"] = [mesh_for(f"{args.prefix}_base", base_idx),
                          mesh_for(f"{args.prefix}_crown", crown_idx)]
        gltf["nodes"] = [
            {"name": "model", "children": [1, 2]},
            {"name": f"{args.prefix}_base", "mesh": 0},
            {"name": f"{args.prefix}_crown", "mesh": 1},
        ]
    gltf["scenes"] = [{"nodes": [0]}]
    gltf["scene"] = 0

    if args.roughness:
        remap_roughness(gltf, binary, args.roughness[0], args.roughness[1])

    dst = args.dst or args.src.replace(".glb", "_split.glb")
    write_glb(dst, gltf, binary)
    print("wrote %s (%.2f MB)" % (dst, len(binary) / 1e6))


if __name__ == "__main__":
    main()
