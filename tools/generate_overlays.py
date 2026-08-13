"""
Generates the QoL Compendium moodle overlay textures.

These are drawn full screen by qolc_immersive_overlays.lua and stretched to the
player's resolution, so each one is an original procedural vignette rather than
painted art. Everything here is generated from the maths below, which is why the
textures carry no third party rights.

    python tools/generate_overlays.py              per texture sizes, as shipped
    python tools/generate_overlays.py 2560 1440    force one size, for comparison

Writes into QoLCompendium/common/media/textures/GUI/.

On sizing. Each texture was measured by storing it at successively smaller sizes,
stretching back up and comparing premultiplied RGBA. All five turn out to carry no
detail that survives past roughly 320x180, so their error flattens out and larger
textures are pure VRAM cost. The measured floor of about 0.4 is the anti banding
dither, which is per pixel random and cannot survive any downsample, so it is not
real signal.

Hypothermia briefly ran at 4K while it had drawn snowflake crystals on it, which
were genuine high frequency content. Those read as cartoonish and were replaced
with ridged noise filaments, and remeasuring put it back with the others.

1920x1080 is therefore generous rather than tight, and leaves room to add sharper
detail later without revisiting this.
"""

import math
import os
import sys
import zlib

import numpy as np
from PIL import Image, ImageDraw, ImageFont

SEED = 20260809

SIZES = {
    "qolc_pain.png": (1920, 1080),          # smooth gradient, flat error below this
    "qolc_damage.png": (1920, 1080),        # noise blotches, all low frequency
    "qolc_tired.png": (1920, 1080),         # the smoothest of the five
    "qolc_hyperthermia.png": (1920, 1080),  # columns and bands are low frequency too
    "qolc_hypothermia.png": (1920, 1080),   # frost filaments, remeasured after the
                                            # drawn crystals were dropped
}

# The repository is laid out the way Steam expects a Workshop item, so the mod itself
# sits several levels down: <item>/Contents/mods/<modid>/.
OUT_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "QoLCompendium", "Contents", "mods", "QoLCompendium",
    "common", "media", "textures", "GUI",
)


def smoothstep(edge0, edge1, x):
    t = np.clip((x - edge0) / (edge1 - edge0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def normalise(field):
    lo, hi = float(field.min()), float(field.max())
    if hi - lo < 1e-6:
        return np.zeros_like(field)
    return (field - lo) / (hi - lo)


def ramp(colour_a, colour_b, t):
    """Per pixel colour ramp, so a texture is not stuck with one flat tint."""
    t = np.clip(t, 0.0, 1.0)[..., None]
    a = np.array(colour_a, dtype=np.float32)
    b = np.array(colour_b, dtype=np.float32)
    return a * (1.0 - t) + b * t


class Canvas:
    """
    One texture's working area.

    Each canvas carries its own generator, seeded from the texture name, so
    changing one texture's resolution can never shift another's pattern.
    """

    def __init__(self, name, width, height):
        self.name = name
        self.width = width
        self.height = height
        # crc32, not hash(), which python randomises per process and would make
        # every run produce different textures
        self.rng = np.random.default_rng(SEED + zlib.crc32(name.encode("utf-8")))

        ny, nx = np.mgrid[0:height, 0:width].astype(np.float32)
        self.nx = (nx / (width - 1)) * 2.0 - 1.0
        self.ny = (ny / (height - 1)) * 2.0 - 1.0
        self.r = np.sqrt(self.nx ** 2 + self.ny ** 2) / np.float32(math.sqrt(2.0))

    def noise(self, cells_x, cells_y, octaves=3):
        """
        Smooth fractal noise, built by upscaling small random grids.

        Different cell counts per axis stretch the features, which is how the
        rising columns in the heat haze are made.
        """
        total = np.zeros((self.height, self.width), dtype=np.float32)
        amplitude = 1.0
        weight = 0.0
        for octave in range(octaves):
            gx = max(2, cells_x * (2 ** octave))
            gy = max(2, cells_y * (2 ** octave))
            grid = self.rng.random((gy, gx)).astype(np.float32)
            layer = Image.fromarray(grid, mode="F").resize((self.width, self.height), Image.BICUBIC)
            total += np.asarray(layer, dtype=np.float32) * amplitude
            weight += amplitude
            amplitude *= 0.5
        return total / weight

    def angular_noise(self, harmonics=26):
        """
        Smooth noise that varies with angle around the frame, returned in -1..1.

        Built as a sum of random sinusoids in the angle itself, so it is exactly
        periodic and cannot seam where the angle wraps. Used to give the frost a
        fingered boundary rather than a clean arc.
        """
        angle = np.arctan2(self.ny, self.nx)
        out = np.zeros_like(angle)
        weight = 0.0
        for k in range(1, harmonics + 1):
            amplitude = 1.0 / (k ** 0.9)
            phase = float(self.rng.random()) * 2.0 * math.pi
            out += amplitude * np.sin(k * angle + phase)
            weight += amplitude
        return out / weight

    def ridged(self, cells_x, cells_y, octaves, sharpness):
        """Ridged noise, the standard way to turn smooth blobs into filaments."""
        folded = 1.0 - np.abs(2.0 * normalise(self.noise(cells_x, cells_y, octaves)) - 1.0)
        return folded ** sharpness

    def write(self, colour, alpha):
        """Packs a colour, flat or per pixel, and an alpha field into an RGBA png."""
        # A touch of noise keeps big smooth gradients from banding on 8 bit alpha
        dither = (self.rng.random((self.height, self.width)).astype(np.float32) - 0.5)
        alpha = np.clip(alpha + dither * (1.5 / 255.0), 0.0, 1.0)

        out = np.zeros((self.height, self.width, 4), dtype=np.uint8)
        if isinstance(colour, tuple):
            out[..., 0], out[..., 1], out[..., 2] = colour
        else:
            out[..., 0:3] = np.clip(colour, 0, 255).astype(np.uint8)
        out[..., 3] = (alpha * 255.0 + 0.5).astype(np.uint8)

        path = os.path.join(OUT_DIR, self.name)
        Image.fromarray(out, mode="RGBA").save(path, optimize=True)
        vram = self.width * self.height * 4 / (1024 * 1024)
        print(f"  {self.name:26} {self.width:>5}x{self.height:<5}"
              f"{os.path.getsize(path) / 1024:7.0f} KB   {vram:5.1f} MB vram")
        return out


# --- the overlays ----------------------------------------------------------

def build_pain(c):
    """A tight, hard edged red ring. The lua pulses its opacity, so this only
    has to define the shape."""
    alpha = smoothstep(0.34, 1.00, c.r) ** 1.30
    return c.write((150, 12, 12), alpha * 0.92)


def build_damage(c):
    """Wider and darker than pain, broken up with noise so it reads as something
    wet rather than a clean gradient."""
    blotch = 0.72 + 0.56 * normalise(c.noise(4, 4, octaves=3))
    alpha = smoothstep(0.26, 1.00, c.r) ** 1.15 * blotch
    return c.write((105, 7, 7), np.clip(alpha, 0, 1) * 0.96)


def build_tired(c):
    """Black, and weighted to the top and bottom so it closes in like eyelids
    rather than sitting evenly around the frame."""
    radial = smoothstep(0.46, 1.06, c.r) * 0.72
    lids = smoothstep(0.50, 1.00, np.abs(c.ny)) ** 0.85
    lids *= 1.0 - 0.18 * smoothstep(0.0, 0.7, np.abs(c.nx))
    return c.write((0, 0, 0), np.maximum(radial, lids) * 0.97)


def build_hyperthermia(c):
    """Air boiling off a hot surface. Noise stretched tall makes the rising
    columns, that same noise warps the vignette edge so it wobbles, and the
    colour runs from amber inside to a deep angry red at the rim."""
    columns = normalise(c.noise(30, 4, octaves=4))
    fine = normalise(c.noise(64, 9, octaves=3))
    shimmer = (columns - 0.5) * 0.085 + (fine - 0.5) * 0.035

    # Refraction bands, bent by the same turbulence that makes the columns
    bands = 0.5 + 0.5 * np.sin(c.ny * 34.0 + shimmer * 46.0 + c.nx * 2.5)
    warped = c.r + shimmer + 0.016 * bands

    alpha = smoothstep(0.24, 1.00, warped) ** 1.12
    alpha = np.clip(alpha * (1.0 + 0.34 * (columns - 0.5)), 0.0, 1.0)

    colour = ramp((242, 168, 52), (156, 26, 6), smoothstep(0.28, 1.00, warped))
    # Brightest where a column is thickest, as if that air is glowing
    glow = np.clip((columns - 0.62) * 2.2, 0.0, 1.0) * smoothstep(0.35, 1.0, c.r)
    colour[..., 0] += glow * 30.0
    colour[..., 1] += glow * 48.0
    return c.write(colour, alpha * 0.90)


def build_hypothermia(c):
    """
    Frost creeping in over glass. The boundary is fingered rather than a clean
    arc, so the ice reaches further in at some angles than others, and two
    ridged layers give it coarse fronds and fine needles. The colour whitens
    wherever ice has actually formed.
    """
    # Where the frost starts, varying with angle so it advances in fingers
    boundary = 0.32 + 0.17 * c.angular_noise(harmonics=26)
    frost = smoothstep(boundary, 1.02, c.r)

    fronds = c.ridged(7, 4, octaves=4, sharpness=2.6)
    needles = c.ridged(26, 15, octaves=3, sharpness=5.0)
    dendrites = np.clip(fronds * 0.72 + needles * 0.58, 0.0, 1.0) * frost

    base = smoothstep(0.24, 1.00, c.r) ** 1.20
    alpha = np.clip(base * 0.78 + dendrites * 0.64, 0.0, 1.0)

    ice = np.clip(dendrites * 1.7, 0.0, 1.0)
    return c.write(ramp((62, 128, 212), (236, 248, 255), ice), alpha * 0.92)


BUILDERS = {
    "qolc_pain.png": build_pain,
    "qolc_damage.png": build_damage,
    "qolc_tired.png": build_tired,
    "qolc_hyperthermia.png": build_hyperthermia,
    "qolc_hypothermia.png": build_hypothermia,
}


# --- previews --------------------------------------------------------------

def _font(size):
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


def contact_sheet(made):
    """One preview image so the overlays can be judged without loading the game."""
    titles = ["PAIN", "DAMAGE", "TIRED", "HYPERTHERMIA", "HYPOTHERMIA"]
    tile_w, tile_h = 620, 349
    cols, rows, pad, label = 3, 2, 14, 26

    sheet = Image.new("RGB", (cols * tile_w + pad * (cols + 1),
                              rows * (tile_h + label) + pad * (rows + 1)), (24, 24, 26))
    draw = ImageDraw.Draw(sheet)
    font = _font(17)

    for index, (name, title) in enumerate(zip(BUILDERS, titles)):
        col, row = index % cols, index // cols
        x = pad + col * (tile_w + pad)
        y = pad + row * (tile_h + label + pad)

        backdrop = Image.new("RGBA", (tile_w, tile_h), (128, 128, 130, 255))
        overlay = Image.fromarray(made[name], mode="RGBA").resize((tile_w, tile_h), Image.LANCZOS)
        sheet.paste(Image.alpha_composite(backdrop, overlay).convert("RGB"), (x, y + label))
        w, h = SIZES[name]
        draw.text((x, y + 5), f"{title}   {w}x{h}", fill=(225, 225, 230), font=font)

    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "overlay_preview.png")
    sheet.save(path)
    print(f"\npreview: {path}")


def detail_sheet(made):
    """Corner crops at native pixels, where the frost and haze detail lives."""
    names = ["qolc_hyperthermia.png", "qolc_hypothermia.png"]
    tile, pad, label = 620, 14, 26

    sheet = Image.new("RGB", (2 * tile + pad * 3, tile + label + pad * 2), (24, 24, 26))
    draw = ImageDraw.Draw(sheet)
    font = _font(17)

    for index, name in enumerate(names):
        x = pad + index * (tile + pad)
        crop = min(900, SIZES[name][1] // 2)
        full = Image.fromarray(made[name], mode="RGBA").crop((0, 0, crop, crop))
        backdrop = Image.new("RGBA", (crop, crop), (128, 128, 130, 255))
        composed = Image.alpha_composite(backdrop, full).resize((tile, tile), Image.LANCZOS)
        sheet.paste(composed.convert("RGB"), (x, pad + label))
        draw.text((x, pad + 5), f"{name}  corner, {crop}px native",
                  fill=(225, 225, 230), font=font)

    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "overlay_detail.png")
    sheet.save(path)
    print(f"detail:  {path}")


if __name__ == "__main__":
    if len(sys.argv) == 3:
        forced = (int(sys.argv[1]), int(sys.argv[2]))
        for key in SIZES:
            SIZES[key] = forced
        print(f"Forcing every texture to {forced[0]}x{forced[1]}\n")

    os.makedirs(OUT_DIR, exist_ok=True)
    print(f"Generating overlays into {OUT_DIR}\n")

    made = {}
    total_vram = 0
    for name, builder in BUILDERS.items():
        width, height = SIZES[name]
        made[name] = builder(Canvas(name, width, height))
        total_vram += width * height * 4

    print(f"\n  {'total':26} {'':11}{'':10}   {total_vram / (1024 * 1024):5.1f} MB vram")

    contact_sheet(made)
    detail_sheet(made)
