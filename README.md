Vanilla Appliances Extended
===========================

Two craftable appliances for Project Zomboid, styled and balanced to sit
alongside the base game's own. Because they are craftable, they don't need to be
placed on a map to be useful.

The original stopped working when build 42 landed and its author is no longer
updating it. This is a continuation against the current build.

**Build 42.20+ | Singleplayer and multiplayer**


Features
--------

**Chest Freezer**

A large freezer in the spirit of the icebox, two tiles wide, with two 100-slot
frozen compartments rather than the icebox's 20. It needs refrigeration
components, which are salvaged rather than found.

To get them, pick up a fridge, then use the disassemble option on it in your
inventory. You'll need a screwdriver and Electrical 3.

**Potbelly Stove**

A craftable alternative to the wood stove. It wants a lot of metal and welding
gear, and it doesn't survive being moved especially well. Good for putting heat
in a bedroom before winter does its worst.

**Extra dismantling**

Toy cars, loose radio components and electric guitars can be broken down for
electronics scrap. The base game already handles TVs, radios and walkie-talkies
on its own, so those are left alone.


Installation
------------

Subscribe on the Steam Workshop, then enable it in the mod list.

To install by hand, copy
`VanillaAppliancesExtended/Contents/mods/VanillaAppliancesExtended` into
`%UserProfile%\Zomboid\mods\`. For a server, add `VanillaAppliancesExtended` to
`Mods=` in your server config, and the Workshop id to `WorkshopItems=`.

This repository is laid out the way Steam expects a Workshop item, so the mod
itself sits at
`VanillaAppliancesExtended/Contents/mods/VanillaAppliancesExtended/`, with the
build 42 payload under `42/` and shared assets under `common/`.


What changed for build 42
-------------------------

Build 41 script and Lua conventions did not survive the move, and most of this
mod's surface area sat on them. Every item below was checked against a local
build 42 install before being changed.

| Broke | Why |
| --- | --- |
| Both appliances uncraftable | `recipe` blocks are gone. Build 42 ships 969 `craftRecipe` blocks and no legacy ones. |
| Server Lua raised on load | The `Recipe.OnCreate` and `Recipe.OnGiveXP` namespaces no longer exist. |
| Item declarations ignored | `Type = Normal` / `Type = Moveable` became `ItemType = base:normal` / `base:moveable`. |
| Guitar dismantling did nothing | The six coloured variants were consolidated into `GuitarElectric` and `GuitarElectricBass`. |
| Salvage produced nothing | `Base.ElectronicScrap` is a typo. The item is `Base.ElectronicsScrap`. |
| Tooltip never appeared | Build 42 reads translations as JSON, not `.txt`. |
| Appliances render wrong | Custom tilesheets need `tileGeometry.txt` for the current renderer. |

The appliances are now entity definitions with `SpriteConfig` and `CraftRecipe`
components, matching how the base game defines its own craftable furniture.
Ingredients, skill requirements and XP awards were carried over unchanged.

Pre-42 support was dropped deliberately rather than straddling both builds.


Known issues
------------

**You can stand in half of the chest freezer.** Only the origin tile of a
multi-tile object blocks movement, so the far half is walkable. This is base
game behaviour, not something this mod introduces: a vanilla wood bed does
exactly the same thing. It was verified against the freezer's own tile data,
which is identical across both halves and matches the single-tile potbelly
stove that blocks correctly.

Nothing in this mod can fix it without dropping the freezer to a single tile,
which would cost it the two-compartment layout, so it is left as-is.


Building on other people's work
-------------------------------

This is a fork, not a reimplementation. The artwork, tile definitions and
dismantling code are the original author's, and are used here as-is. Everything
rebuilt for build 42 is new work.

The original was published without a licence, which means the author granted
nothing and this fork rests on the absence of an objection. If you are that
author and would rather this not exist, say so and it will be taken down.

NOTICE records exactly what was inherited and what was rewritten. LICENSE sets
out the two sets of terms that apply.


Licence
-------

Split, because this project cannot grant rights over work it did not create.

The inherited artwork, tile definitions and dismantling code remain the property
of the original author under no stated licence. Everything written for build 42
here is MIT, so that whoever picks this up next isn't left where this fork
started.

See LICENSE.
