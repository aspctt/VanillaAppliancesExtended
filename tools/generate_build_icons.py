"""Generate build-menu icons from the mod's own texture pack.

The build menu needs a PNG per entity (xuiSkin `Icon = ...`); without one the
game draws a placeholder. Rather than hand-draw them, this crops the south
facing world sprites straight out of VanillaAppliancesExtended.pack, so the
icons always match what actually gets placed.

The .pack format (little-endian throughout):

    "PZPK"
    int32   version
    int32   page count
    int32   len + bytes      pack name
    int32   sprite count
    int32   unknown
    per sprite:
        int32 len + bytes    sprite name
        int32 x, y, w, h     rect within the atlas PNG
        int32 offX, offY     offset within the 128px tile cell
        int32 cellW, cellH

The atlas PNG is appended whole after the header, starting at the PNG magic.

Usage:  python tools/generate_build_icons.py
"""

import os
import struct

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
MEDIA = os.path.join(
    HERE, "..", "VanillaAppliancesExtended", "Contents", "mods",
    "VanillaAppliancesExtended", "42", "media",
)
PACK = os.path.join(MEDIA, "texturepacks", "VanillaAppliancesExtended.pack")
OUT = os.path.join(MEDIA, "textures")

# Facings come from VanillaAppliancesExtended.tiles. South is the face the
# camera looks at, so it reads best at icon size.
STOVE_S = 1
FREEZER_S = (6, 7)          # grid 0,0 and 1,0
STEP_X, STEP_Y = 64, 32     # one tile along +x, in screen pixels, for a 128px cell


def parse_pack(path):
    """Return (atlas Image, {index: (x, y, w, h, offX, offY)})."""
    d = open(path, "rb").read()
    if d[:4] != b"PZPK":
        raise SystemExit(f"not a PZPK file: {path}")

    i = 4
    _ver, _pages = struct.unpack_from("<ii", d, i)
    i += 8
    n, = struct.unpack_from("<i", d, i)
    i += 4 + n                                  # pack name
    count, _unknown = struct.unpack_from("<ii", d, i)
    i += 8

    rects = {}
    for _ in range(count):
        n, = struct.unpack_from("<i", d, i)
        i += 4
        name = d[i:i + n].decode()
        i += n
        x, y, w, h, ox, oy, _cw, _ch = struct.unpack_from("<8i", d, i)
        i += 32
        rects[int(name.rsplit("_", 1)[1])] = (x, y, w, h, ox, oy)

    png = d.find(b"\x89PNG")
    atlas_bytes = d[png:]
    tmp = os.path.join(OUT, "_atlas_tmp.png")
    os.makedirs(OUT, exist_ok=True)
    with open(tmp, "wb") as fh:
        fh.write(atlas_bytes)
    atlas = Image.open(tmp).convert("RGBA")
    atlas.load()
    os.remove(tmp)
    return atlas, rects


def main():
    atlas, rects = parse_pack(PACK)
    print(f"atlas {atlas.size}, {len(rects)} sprites: {sorted(rects)}")

    def crop(i):
        x, y, w, h, ox, oy = rects[i]
        return atlas.crop((x, y, x + w, y + h)), ox, oy

    os.makedirs(OUT, exist_ok=True)

    img, _, _ = crop(STOVE_S)
    img.save(os.path.join(OUT, "Build_PotBellyStove.png"))
    print(f"  Build_PotBellyStove.png {img.size}")

    # The freezer spans two tiles, so compose both halves at their pack offsets
    # with the far tile painted first.
    a, oxa, oya = crop(FREEZER_S[0])
    b, oxb, oyb = crop(FREEZER_S[1])
    left = min(oxa, oxb + STEP_X)
    top = min(oya, oyb + STEP_Y)
    w = max(oxa + a.width, oxb + STEP_X + b.width) - left
    h = max(oya + a.height, oyb + STEP_Y + b.height) - top
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    canvas.alpha_composite(b, (oxb + STEP_X - left, oyb + STEP_Y - top))
    canvas.alpha_composite(a, (oxa - left, oya - top))
    canvas = canvas.crop(canvas.getbbox())
    canvas.save(os.path.join(OUT, "Build_ChestFreezer.png"))
    print(f"  Build_ChestFreezer.png  {canvas.size}")


if __name__ == "__main__":
    main()
