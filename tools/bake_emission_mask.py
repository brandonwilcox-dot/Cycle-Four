#!/usr/bin/env python3
"""Bake a crisp, architectural emission mask from an authored structure's DIFFUSE texture.

WHY THIS EXISTS
---------------
Rodin exports with De-light ON, so the cyan light-channels arrive as painted colour in the
diffuse with no emissive map. Earlier masks were made by "find bright cyan, dilate, blur".
That produced three defects the player can see when they zoom in:

  1. SPLOTCHES  - isolated few-pixel noise blobs all over the armour, each becoming a glowing dot.
  2. SLABS      - Rodin paints openings (e.g. the FOB front gate) as one flat teal FILL. A
                  brightness test grabs the whole panel, so the gate emitted as a solid glowing
                  arch and read as a decal pasted on the wall instead of a recessed opening.
  3. MUSH       - MaxFilter + blur (added for mip safety) rounded off every hard edge. On the
                  FOB, 82% of lit mask pixels were mid-tone and only 13% were hot cores.

This script replaces that with a shape-aware pass. No blur anywhere.

THE RECIPE
----------
  a. Threshold on BLUE-DOMINANCE (b - r) gated by saturation. Blue-dominance beats a hue/value
     test because De-light leaves some channels as DARK navy insets rather than bright cyan
     (this is what defeated the HSV recipe on the Plasma Bastion).
  b. Morphological OPEN to shave threshold fuzz off the edges.
  c. Split into connected components and classify each one by SHAPE, not by brightness:
       - area < MIN_AREA                -> noise, DROPPED (kills the splotches)
       - max half-width > MAX_HALFWIDTH -> a filled PANEL, converted to a glowing RIM
                                           (the gate becomes a lit arch outline, not a slab)
       - otherwise                      -> a genuine thin CHANNEL, kept solid
     Half-width comes from the distance transform, so classification is about how FAT a shape
     is, not how big. A 4px-wide channel 300px long stays solid; a 40x40 blob gets rimmed.
  d. Facet every outline with approxPolyDP so organic wobble becomes straight segments and
     hard corners - the "solid angles" of engineered architecture.

The mask is GRAYSCALE and only gates INTENSITY. The colour comes from
StructureEmissionLighting.ARCHITECT_BLUE, so one script serves every faction.

GODOT IMPORT (do not skip)
--------------------------
Godot first-imports a new mask as `compress/mode=0, mipmaps=false, detect_3d=1`. Emission masks
must be VRAM-compressed with mipmaps per docs/DESIGN-GUIDELINES.md. Pass --write-import to have
this script emit a correct .import file, then re-import in the editor.

USAGE
-----
  python tools/bake_emission_mask.py assets/models/buildings/architect_fob_hifi_texture_diffuse.png
  python tools/bake_emission_mask.py <diffuse.png> -o <mask.png> --preview --write-import

Tunables are exposed as flags; the defaults are the values confirmed on the Architect FOB.
Aim for roughly 1.5-2.5% final coverage. If a model comes in far under, lower --blue-dominance
before touching anything else.
"""

import argparse
import os
import sys

import numpy as np

try:
    import cv2
except ImportError:
    sys.exit("OpenCV required:  pip install opencv-python-headless")
try:
    from PIL import Image
except ImportError:
    sys.exit("Pillow required:  pip install pillow")

Image.MAX_IMAGE_PIXELS = None

# Defaults confirmed on architect_fob_hifi (2026-07-26).
BLUE_DOMINANCE = 0.10   # b - r. Lower catches darker navy insets; raises coverage fast.
SATURATION     = 0.18   # rejects the near-white polished armour
MIN_AREA       = 14     # px. Components smaller than this are noise.
MAX_HALFWIDTH  = 9.0    # px. Thicker than this => filled panel => convert to rim.
RIM            = 3      # px. Stroke width of a panel's glowing outline.
EPSILON        = 2.0    # px. approxPolyDP tolerance. Higher = harsher faceting.
EMISSIVE_LUMA  = 0.05   # --from-emissive only: luminance cut on an AUTHORED emissive map.

## Per-model overrides, keyed by diffuse filename stem. How strongly Rodin's De-light pass
## drained the cyan varies per generation, so the blue-dominance cut has to be set per model.
## Matched by substring; add an entry whenever a new structure is baked.
PRESETS = {
    "architect_fob_hifi":            {"blue_dominance": 0.100},   # -> 1.61% coverage
    ## Bastion is now baked with --from-emissive off its OBJ-pack emissive (2026-07-29) and the
    ## blue-dominance path never runs. Kept as the fallback: its channels are DARK navy insets,
    ## so colour returns them as short fragments — at min_area 14 that mask carried 476
    ## components / 168 speckles and read as "splotchy" in play; 140 cut it to 122. The authored
    ## emissive gets 47 clean components for comparison. Colour is mitigation, never the fix.
    "architect_plasma_bastion_hifi": {"blue_dominance": 0.085, "min_area": 140,
                                      "epsilon": 2.5},           # colour fallback only
    ## Sentry Spire ships an AUTHORED emissive, so it is baked with --from-emissive and the
    ## blue-dominance cut never runs. Its diffuse WOULD pass the colour gate (p99 0.275) if the
    ## emissive were ever lost -- 0.090 is the tuned fallback.
    "architect_sentry_spire_hifi":   {"blue_dominance": 0.090},
    # architect_garrison_keep_hifi: NOT BAKEABLE. Its diffuse is fully achromatic (max b-r
    # 0.125, p99 0.027) -- De-light stripped every cyan channel, so no colour criterion can
    # find them, and a black-hat recess pass just returns surface cracks. Needs either a
    # Rodin re-export with De-light off, or the channels authored as a second material in
    # Blender. Do NOT ship a colour-derived mask for it; you get noise.
}

IMPORT_TEMPLATE = """[remap]

importer="texture"
type="CompressedTexture2D"
uid="uid://{uid}"
path.s3tc="res://.godot/imported/{base}-{hash}.s3tc.ctex"
metadata={{
"imported_formats": ["s3tc_bptc"],
"vram_texture": true
}}

[deps]

source_file="res://{res_path}"
dest_files=["res://.godot/imported/{base}-{hash}.s3tc.ctex"]

[params]

compress/mode=2
compress/high_quality=false
compress/lossy_quality=0.7
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
"""


def bake(diffuse_path, out_path, cfg, preview_dir=None):
    img = Image.open(diffuse_path).convert("RGB")
    d = np.asarray(img).astype(np.float32) / 255.0

    if cfg.from_emissive:
        ## HARDENING PATH. The regions are already authored; all we do is make them mip-safe.
        ## Rodin's emissive is soft -- measured 70-72% mid-tone on the Sentry Spire, versus the
        ## 82% that made the FOB's cyan vanish at gameplay distance. Thresholding to binary and
        ## letting the component pass run drives every surviving pixel to full value.
        raw = (d.max(2) > cfg.emissive_luma).astype(np.uint8)
    else:
        r, b = d[..., 0], d[..., 2]
        mx = d.max(2)
        mn = d.min(2)
        sat = np.where(mx > 1e-5, (mx - mn) / np.maximum(mx, 1e-5), 0.0)
        raw = (((b - r) > cfg.blue_dominance) & (sat > cfg.saturation)).astype(np.uint8)

    raw_cov = raw.mean() * 100.0
    raw = cv2.morphologyEx(raw, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))

    count, labels, stats, _ = cv2.connectedComponentsWithStats(raw, 8)
    out = np.zeros(raw.shape, np.uint8)
    rims = solid = dropped = 0
    pad = cfg.rim + 2

    for i in range(1, count):
        area = stats[i, cv2.CC_STAT_AREA]
        if area < cfg.min_area:
            dropped += 1
            continue
        x, y = stats[i, cv2.CC_STAT_LEFT], stats[i, cv2.CC_STAT_TOP]
        w, h = stats[i, cv2.CC_STAT_WIDTH], stats[i, cv2.CC_STAT_HEIGHT]

        sub = np.zeros((h + 2 * pad, w + 2 * pad), np.uint8)
        sub[pad:pad + h, pad:pad + w] = (labels[y:y + h, x:x + w] == i).astype(np.uint8)

        # Distance transform peak = radius of the largest inscribed disc = how FAT the shape is.
        fat = cv2.distanceTransform(sub, cv2.DIST_L2, 3).max() > cfg.max_halfwidth

        contours, _ = cv2.findContours(sub, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        poly = np.zeros_like(sub)
        for c in contours:
            facets = cv2.approxPolyDP(c, cfg.epsilon, True)
            if fat:
                cv2.polylines(poly, [facets], True, 1, cfg.rim)
            else:
                cv2.fillPoly(poly, [facets], 1)
        rims += fat
        solid += not fat

        oy, ox = y - pad, x - pad
        y0, x0 = max(0, oy), max(0, ox)
        y1 = min(raw.shape[0], oy + poly.shape[0])
        x1 = min(raw.shape[1], ox + poly.shape[1])
        out[y0:y1, x0:x1] |= poly[y0 - oy:y0 - oy + (y1 - y0), x0 - ox:x0 - ox + (x1 - x0)]

    mask = (out * 255).astype(np.uint8)
    coverage = (mask > 0).mean() * 100.0

    Image.fromarray(mask).save(out_path)
    print("  raw threshold coverage : %.2f%%" % raw_cov)
    print("  thin channels (solid)  : %d" % solid)
    print("  panels -> glowing rim  : %d" % rims)
    print("  noise speckles dropped : %d" % dropped)
    print("  FINAL coverage         : %.2f%%   -> %s" % (coverage, out_path))
    if coverage < 0.8:
        print("  WARNING: under 0.8%% - lower --blue-dominance and re-run.")
    elif coverage > 4.0:
        print("  WARNING: over 4%% - raise --blue-dominance or --min-area.")

    if preview_dir:
        os.makedirs(preview_dir, exist_ok=True)
        stem = os.path.splitext(os.path.basename(out_path))[0]
        ys, xs = np.nonzero(mask)
        cy, cx = (int(ys.mean()), int(xs.mean())) if ys.size else (512, 512)
        cy = min(max(cy - 256, 0), mask.shape[0] - 512)
        cx = min(max(cx - 256, 0), mask.shape[1] - 512)
        box = (cx, cy, cx + 512, cy + 512)
        Image.fromarray(mask).crop(box).resize((640, 640), Image.NEAREST).save(
            os.path.join(preview_dir, stem + "_preview.png"))
        img.crop(box).resize((640, 640), Image.NEAREST).save(
            os.path.join(preview_dir, stem + "_preview_diffuse.png"))
        print("  preview written to     : %s" % preview_dir)
    return coverage


def write_import(out_path, project_root):
    import binascii
    import uuid
    res_path = os.path.relpath(out_path, project_root).replace("\\", "/")
    base = os.path.basename(out_path)
    digest = binascii.hexlify(res_path.encode()).decode()[:32].ljust(32, "0")
    uid = uuid.uuid5(uuid.NAMESPACE_URL, res_path).hex[:13]
    with open(out_path + ".import", "w", newline="\n") as fh:
        fh.write(IMPORT_TEMPLATE.format(uid=uid, base=base, hash=digest, res_path=res_path))
    print("  .import written (compress=2, mipmaps=on, detect_3d=off) - re-import in the editor")


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("diffuse", help="path to the structure's *_texture_diffuse.png, "
                                    "or its *_texture_emissive.png with --from-emissive")
    ap.add_argument("-o", "--out", help="output mask path (default: <model>_emission_mask.png)")
    ap.add_argument("--from-emissive", action="store_true",
                    help="input is an AUTHORED emissive map: skip blue-dominance and only "
                         "harden (drop noise, drive cores to full, facet outlines). Also "
                         "disables PANEL->RIM unless --max-halfwidth is given explicitly.")
    ap.add_argument("--emissive-luma", type=float, default=EMISSIVE_LUMA,
                    help="luminance cut for --from-emissive (default %(default)s)")
    ap.add_argument("--blue-dominance", type=float, default=BLUE_DOMINANCE)
    ap.add_argument("--saturation", type=float, default=SATURATION)
    ap.add_argument("--min-area", type=int, default=MIN_AREA)
    ap.add_argument("--max-halfwidth", type=float, default=MAX_HALFWIDTH)
    ap.add_argument("--rim", type=int, default=RIM)
    ap.add_argument("--epsilon", type=float, default=EPSILON)
    ap.add_argument("--preview", metavar="DIR", nargs="?", const=".", default=None,
                    help="write a 512px mask/diffuse preview pair for eyeballing")
    ap.add_argument("--write-import", action="store_true",
                    help="emit a correct .import beside the mask")
    ap.add_argument("--project-root", default=os.path.join(os.path.dirname(__file__), ".."))
    ap.add_argument("--no-preset", action="store_true", help="ignore the PRESETS table")
    cfg = ap.parse_args()

    ## An AUTHORED emissive means fat components are usually DELIBERATE (glowing lozenge
    ## inserts, capacitor faces). The PANEL->RIM rule exists to defend against Rodin PAINTING a
    ## slab over an opening in the DIFFUSE -- that assumption inverts here, and blanket
    ## rim-conversion would gut the artist's design. Off unless asked for explicitly.
    if cfg.from_emissive and "--max-halfwidth" not in sys.argv:
        cfg.max_halfwidth = float("inf")
        print("  --from-emissive: PANEL->RIM disabled (authored shapes kept solid)")

    ## Apply a per-model preset unless the user set the flag explicitly on the command line.
    if not cfg.no_preset:
        stem = os.path.basename(cfg.diffuse)
        for key, over in PRESETS.items():
            if key in stem:
                for name, value in over.items():
                    if ("--" + name.replace("_", "-")) not in sys.argv:
                        setattr(cfg, name, value)
                        print("  preset[%s] %s = %s" % (key, name, value))
                break

    out = cfg.out
    if not out:
        stem = cfg.diffuse
        for suffix in ("_texture_diffuse.png", "_diffuse.png", ".png"):
            if stem.endswith(suffix):
                stem = stem[:-len(suffix)]
                break
        out = stem + "_emission_mask.png"

    print("baking %s" % os.path.basename(cfg.diffuse))
    bake(cfg.diffuse, out, cfg, cfg.preview)
    if cfg.write_import:
        write_import(out, os.path.abspath(cfg.project_root))


if __name__ == "__main__":
    main()
