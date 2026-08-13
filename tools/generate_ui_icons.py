"""Generates the small UI glyphs the compendium needs.

Only the padlock pair so far. Vanilla already ships a gears icon that suits the reorder
options button, so that one is used directly rather than reproduced here.

The glyphs are drawn rather than bundled, which keeps the project's rule that no artwork
comes from another mod unless it genuinely cannot be reproduced. A padlock plainly can.

Output goes into the mod's own texture folder, which sits inside the Workshop layout at
QoLCompendium/Contents/mods/QoLCompendium/common/media/textures/GUI/.

Run:    python tools/generate_ui_icons.py
"""

from pathlib import Path

from PIL import Image, ImageDraw

# Drawn large and downsampled, which is the cheapest way to get clean edges on a glyph
# this small without hand antialiasing.
SUPERSAMPLE = 16

# 16 pixels, not 32. drawTexture paints at the texture's own size with no scaling, and
# these sit in 18 pixel cells on the hotbar, so anything larger spills out over the slots
# beside it. One pixel of padding each side is what the 18 leaves room for.
SIZE = 16

# The slot disc is scaled to whatever container size the player picked, which goes well
# past 16, so it is generated large enough to scale down rather than up.
DISC_SIZE = 128

# Matches the muted grey of vanilla's own button icons. The open padlock is dimmer,
# so "unlocked" reads as the inactive state at a glance.
COLOUR_CLOSED = (222, 222, 222, 255)
COLOUR_OPEN = (150, 150, 150, 255)

# The repository is laid out the way Steam expects a Workshop item, so the mod itself
# sits several levels down: <item>/Contents/mods/<modid>/.
OUTPUT = (
    Path(__file__).resolve().parent.parent
    / "QoLCompendium" / "Contents" / "mods" / "QoLCompendium"
    / "common" / "media" / "textures" / "GUI"
)


def draw_padlock(open_shackle: bool, colour: tuple) -> Image.Image:
    """One padlock: a rounded body with a shackle arcing out of the top."""
    span = SIZE * SUPERSAMPLE
    image = Image.new("RGBA", (span, span), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    unit = span / 32.0
    stroke = int(round(2.6 * unit))

    # Body. Sits in the lower half and leaves room for the shackle above it.
    body_left = 7 * unit
    body_right = 25 * unit
    body_top = 15 * unit
    body_bottom = 28 * unit
    draw.rounded_rectangle(
        [body_left, body_top, body_right, body_bottom],
        radius=int(2.5 * unit),
        outline=colour,
        width=stroke,
    )

    # Keyhole, a single dot. Anything more is lost once this is 32 pixels wide.
    centre_x = (body_left + body_right) / 2
    centre_y = (body_top + body_bottom) / 2
    dot = 2.0 * unit
    draw.ellipse(
        [centre_x - dot, centre_y - dot, centre_x + dot, centre_y + dot],
        fill=colour,
    )

    # Shackle. Closed sits centred on the body, open is shifted right and lifted so the
    # near leg clears the body entirely, which is what makes the two read differently.
    shackle_width = 11 * unit
    shackle_x = centre_x - shackle_width / 2
    shackle_top = 5 * unit
    shackle_bottom = 19 * unit

    if open_shackle:
        shackle_x += 5 * unit
        shackle_top -= 1.5 * unit
        shackle_bottom -= 3 * unit

    # Half an ellipse for the arc, then one leg down to meet the body. The open lock
    # keeps only its far leg, which is the whole visual difference.
    draw.arc(
        [shackle_x, shackle_top, shackle_x + shackle_width, shackle_bottom],
        start=180,
        end=360,
        fill=colour,
        width=stroke,
    )

    arc_mid_y = (shackle_top + shackle_bottom) / 2
    leg_bottom = body_top + stroke / 2
    if not open_shackle:
        draw.line(
            [shackle_x + stroke / 2, arc_mid_y, shackle_x + stroke / 2, leg_bottom],
            fill=colour,
            width=stroke,
        )
    draw.line(
        [
            shackle_x + shackle_width - stroke / 2,
            arc_mid_y,
            shackle_x + shackle_width - stroke / 2,
            leg_bottom if not open_shackle else arc_mid_y + 3 * unit,
        ],
        fill=colour,
        width=stroke,
    )

    return image.resize((SIZE, SIZE), Image.LANCZOS)


def arrow(draw: ImageDraw.ImageDraw, x1, y, x2, unit, stroke, colour) -> None:
    """A horizontal arrow from x1 to x2, head on the x2 end."""
    draw.line([x1, y, x2, y], fill=colour, width=stroke)

    head = 3.2 * unit
    direction = 1 if x2 > x1 else -1
    draw.line([x2, y, x2 - head * direction, y - head], fill=colour, width=stroke)
    draw.line([x2, y, x2 - head * direction, y + head], fill=colour, width=stroke)


def draw_swap(colour: tuple) -> Image.Image:
    """Two arrows pointing opposite ways: dragging exchanges the two slots."""
    span = SIZE * SUPERSAMPLE
    image = Image.new("RGBA", (span, span), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    unit = span / 32.0
    stroke = int(round(2.6 * unit))

    arrow(draw, 7 * unit, 11 * unit, 25 * unit, unit, stroke, colour)
    arrow(draw, 25 * unit, 21 * unit, 7 * unit, unit, stroke, colour)

    return image.resize((SIZE, SIZE), Image.LANCZOS)


def draw_insert(colour: tuple) -> Image.Image:
    """An arrow meeting a bar: dragging drops the slot in between the others."""
    span = SIZE * SUPERSAMPLE
    image = Image.new("RGBA", (span, span), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    unit = span / 32.0
    stroke = int(round(2.6 * unit))

    arrow(draw, 5 * unit, 16 * unit, 19 * unit, unit, stroke, colour)
    draw.line([24 * unit, 6 * unit, 24 * unit, 26 * unit], fill=colour, width=stroke)

    return image.resize((SIZE, SIZE), Image.LANCZOS)


def draw_disc() -> Image.Image:
    """A plain white disc, tinted at draw time.

    The equipped hand slots are round, so a rectangular condition fill spills out of
    them at the corners. This is drawn into the slot and clipped to however much of it
    should be filled. White because the colour comes from the draw call.

    Larger than the others: it is scaled to whatever slot size the player has chosen,
    and scaling down stays clean where scaling up does not.
    """
    span = DISC_SIZE * 4
    image = Image.new("RGBA", (span, span), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    # Half a pixel in at the final size, so the edge does not clip against the slot
    inset = span / DISC_SIZE * 0.5
    draw.ellipse([inset, inset, span - inset, span - inset], fill=(255, 255, 255, 255))

    return image.resize((DISC_SIZE, DISC_SIZE), Image.LANCZOS)


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)

    images = {
        "qolc_lock_closed": draw_padlock(False, COLOUR_CLOSED),
        "qolc_lock_open": draw_padlock(True, COLOUR_OPEN),
        "qolc_swap": draw_swap(COLOUR_CLOSED),
        "qolc_insert": draw_insert(COLOUR_CLOSED),
        "qolc_slot_disc": draw_disc(),
    }

    for name, image in images.items():
        path = OUTPUT / f"{name}.png"
        image.save(path)
        print(f"wrote {path.relative_to(OUTPUT.parent.parent.parent)}")


if __name__ == "__main__":
    main()
