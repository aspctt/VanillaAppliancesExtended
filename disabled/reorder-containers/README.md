Reorder Containers, held back
=============================

Nothing in this folder is loaded. The mod itself lives at
`QoLCompendium/Contents/mods/QoLCompendium/`, and Project Zomboid only reads `42/media`
and `common/media` inside it, so these files sit outside the mod entirely. They are kept here rather than deleted because the feature is
close to working and the investigation behind it was long.

Why it is out
-------------

Dragging a container to reorder it did not hold. In game the order would apply and then
undo itself a moment later, which reads as the containers having swapped contents,
because clicking the top one then opens whatever the order reverted to.

What was established, with logs from the game rather than guesses:

- Clicks were never wrong. Every one selected the container the button was carrying.
- The stored order is written correctly and survives a reload. It is kept on the player,
  keyed by `Item:getID()`, as flat numbers.
- Applying a stored order works. The array, the on screen positions, the icons and the
  priorities all agree after a refresh.
- The fault is in committing a drag. A second commit runs while the window is rebuilding
  and reads the half rebuilt layout, writing the game's own order back over the chosen
  one.

Three separate real bugs were found and fixed along the way, none of which was the one
above: releasing a drag opened the container it landed on, a swallowed click left the
button pressed so the next mouse move started a phantom drag, and the order was
originally stored in an `InventoryItem`'s mod data where nested tables do not survive.

What is left to do
------------------

Find what triggers the second commit, or make committing independent of where the
buttons happen to be sitting. An attempt at the second, deriving the new position from
the dragged button alone, rejected too many real drops and is not in this copy.

The manual priority window works and does not depend on any of this, so a smaller
version of the feature could ship with typing a number and no dragging at all.

Restoring
---------

The first three are relative to `QoLCompendium/Contents/mods/QoLCompendium/`, the spec is
relative to the repository root.

    qolc_reorder_data.lua             -> 42/media/lua/shared/
    qolc_reorder_containers.lua       -> 42/media/lua/client/
    qolc_reorder_priority_window.lua  -> 42/media/lua/client/
    reorder_containers_spec.lua       -> tests/specs/

The five `UI_QoLC_Reorder_*` keys also need putting back into
`42/media/lua/shared/Translate/EN/UI.json`. They are listed at the bottom of this file.

    "UI_QoLC_Reorder_Locked": "Container order is locked. Click to unlock and allow dragging.",
    "UI_QoLC_Reorder_Unlocked": "Container order is unlocked. Drag the buttons to reorder them.",
    "UI_QoLC_Reorder_SortLoot": "Allow sorting in this window",
    "UI_QoLC_Reorder_Priority": "Sorting Priority",
    "UI_QoLC_Reorder_Priority_tooltip": "Lower numbers sort nearer the top. Leave empty to use the game's own order.",

Reorder The Hotbar is a separate feature and is unaffected. It ships and works.
