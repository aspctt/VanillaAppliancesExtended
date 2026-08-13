"""
Builds the flamingo tile fix for QoL Compendium.

Lawn flamingos carry the attachedFloor property, which puts their sprite in the floor
render pass. IsoGridSquare.renderFloorInternal draws it there, and anything drawn onto the
square afterwards, furniture or a snow overlay, covers it. That is the whole bug: the
flamingo does not disappear, it is painted under everything.

The gnome, the bird bath and the ornamental bush sit in the same tileset without the
property and render correctly, which is what makes attachedFloor the difference rather
than a guess.

The property cannot be removed by a .patch.tiles. The loader dispatches on the property
name, not its value:

    if (propName.equals("attachedFloor")) { sprite.attachedFloor = true; ... }

so naming it at all sets the flag. A tileset can only be replaced whole, which is why this
writes out all fifty tiles of vegetation_ornamental_01 to change eight of them.

Everything except the flamingo change is copied verbatim from the installed build, so this
must be re-run after a game update that touches the tileset. checkTileDefs in
tests/harness/TestRunner.java fails the suite when that happens, rather than letting this
file quietly revert someone else's work.

Deliberately not a copy of the original mod's file. That one is build 41 era and is now a
strict subset of vanilla: it is missing CanScrap, Material, MaterialType and SnowTile on
every tile in the sheet, so installing it would strip build 42's snow overlays from the
hedges and flowerbeds to fix the flamingo.

Usage:  python tools/generate_flamingo_tiles.py
"""
import io
import os
import struct

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEST = os.path.join(ROOT, 'QoLCompendium', 'Contents', 'mods', 'QoLCompendium',
                    'common', 'media', 'qolc_flamingo.tiles')

TILESET = 'vegetation_ornamental_01'
TARGET = 'Flamingo'
DROP = 'attachedFloor'

# Tile definitions live in a binary .tiles, but the game ships a readable dump of the same
# data beside it, which is what this reads.
GAME_DUMP = 'newtiledefinitions.tiles.txt'


def find_game_dir():
    """The install, from the same places tests/run-tests.ps1 looks."""
    if os.environ.get('QOLC_PZ_DIR'):
        return os.environ['QOLC_PZ_DIR']

    for drive in 'CDEFGHS':
        for path in (r'%s:\SteamLibrary\steamapps\common\ProjectZomboid' % drive,
                     r'%s:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid' % drive):
            if os.path.isfile(os.path.join(path, 'projectzomboid.jar')):
                return path

    raise SystemExit('Could not find a Project Zomboid install. Set QOLC_PZ_DIR.')


def read_tileset(dump_path):
    """The one tileset this touches, as a list of 64 property dicts indexed by slot.

    Slots with no definition stay empty, which is how the format stores them.
    """
    lines = io.open(dump_path, encoding='utf-8', errors='replace').read().split('\n')

    start = next(i for i, l in enumerate(lines) if l.strip() == 'file = ' + TILESET)
    end = next(i for i in range(start + 2, len(lines)) if lines[i].startswith('tileset'))

    width = height = None
    tiles, current = {}, None

    for line in lines[start:end]:
        text = line.strip()

        if text.startswith('size = '):
            width, height = [int(n) for n in text[7:].split(',')]
        elif text == 'tile':
            current = {}
        elif text.startswith('xy = ') and current is not None:
            x, y = [int(n) for n in text[5:].split(',')]
            tiles[y * width + x] = current
        elif current is not None and ' = ' in text:
            key, value = text.split(' = ', 1)
            if key != 'xy':
                current[key] = value.strip()
        elif current is not None and text.endswith('=') and len(text) > 1:
            current[text[:-1].strip()] = ''

    return width, height, [tiles.get(i, {}) for i in range(width * height)]


def encode(width, height, tiles):
    out = bytearray(b'tdef')
    out += struct.pack('<i', 1)                 # format version
    out += struct.pack('<i', 1)                 # one tileset in this file
    out += TILESET.encode('utf-8') + b'\n'
    out += (TILESET + '.png').encode('utf-8') + b'\n'

    # The third number is the tileset's number within this file, which the loader rejects
    # below 1. It is not the global id the game's own dump prints.
    out += struct.pack('<iiii', width, height, 1, len(tiles))

    for props in tiles:
        out += struct.pack('<i', len(props))
        for key in sorted(props):
            out += key.encode('utf-8') + b'\n' + props[key].encode('utf-8') + b'\n'

    return bytes(out)


def main():
    dump = os.path.join(find_game_dir(), 'media', GAME_DUMP)
    if not os.path.isfile(dump):
        raise SystemExit('tile definition dump not found at %s' % dump)

    width, height, tiles = read_tileset(dump)

    fixed = 0
    for props in tiles:
        if props.get('CustomName') == TARGET and DROP in props:
            del props[DROP]
            fixed += 1

    if fixed == 0:
        raise SystemExit('no %s tile carried %s, this build may already be fixed' % (TARGET, DROP))

    data = encode(width, height, tiles)
    io.open(DEST, 'wb').write(data)

    defined = sum(1 for t in tiles if t)
    print('%s %dx%d, %d tiles defined, %s dropped from %d %s tiles'
          % (TILESET, width, height, defined, DROP, fixed, TARGET))
    print('wrote %s, %d bytes' % (os.path.relpath(DEST, ROOT), len(data)))


if __name__ == '__main__':
    main()
