# QoL Compendium tests

Runs the mod's real Lua against Project Zomboid's own VM, without launching the game.

```
pwsh tests/run-tests.ps1
```

A full run takes under a second.

## How it works

`projectzomboid.jar` contains Kahlua, the Lua 5.1 VM the game runs mods on. The runner
boots that same VM outside the game, installs a stubbed game API, loads the real mod
source, and drives it frame by frame.

Because it is the shipped VM and the shipped `PZAPI/ModOptions.lua`, the tests break
when a game update changes the API, rather than silently passing against a hand-written
imitation.

Load order, assembled by `run-tests.ps1`:

| Layer | Source |
| --- | --- |
| Game API stubs | `harness/pz_stubs.lua` |
| Translations | the mod's `Translate/EN/*.json`, parsed as flat json |
| Mod options API | the real one from the game install |
| Assertions | `harness/test_lib.lua` |
| Code under test | every `.lua` in the mod's `shared`, `client` and `server` folders |
| Specs | `specs/*_spec.lua` |

Singleplayer loads all three lua folders, so the harness does too. Multiplayer does
not, which is exactly why where a file lives is a decision rather than a detail.

Each test runs in a completely fresh environment. A mod's file-level locals, such as
the overlay blend accumulators, cannot leak from one test into the next.

## What it checks

Beyond the specs themselves, every run performs a set of static checks first. Each one
exists because the mistake it catches was shipped at least once:

- **Syntax**, by compiling each file with the game's own compiler.
- **Constant validity.** Every `MoodleType.X` and `CharacterStat.X` in shipped mod
  source is verified against the constants actually present in the installed build,
  read straight out of the jar. This catches build-41 names in branches the tests never
  execute, reported with file and line. Comments are skipped, since they routinely name
  a retired constant to explain why it is gone.
- **Item script shape.** A legacy `Type =` leaves `getItemType()` null and takes the
  debug item spawner down with it, `DisplayName` is ignored in build 42, and a
  `BodyLocation` that is not namespaced never resolves.
- **Sandbox options.** Types are checked against the five the game's parser accepts,
  and every option and page must have its label in `Sandbox.json`. Neither mistake
  crashes: the option is silently dropped or renders as a raw key.
- **Translation escaping.** The game runs every string through `String.format`, so a
  bare `%` is an invalid conversion and the whole string fails to render.
- **Texture paths.** Every `getTexture` path is resolved against the mod's own trees and
  the game install. A wrong path is not an error at runtime: the texture is simply null
  and nothing draws.
- **Item types.** Every `"Module.Item"` literal in shipped mod source is resolved against
  the items this build defines, the mod's own scripts first and then the game's. A
  retired clothing name is completely silent: the lookup simply stops matching.
- **Tile definitions.** A tileset can only be replaced whole, so `qolc_flamingo.tiles`
  carries fifty tiles copied from the game to change one property on eight of them. Every
  one is diffed against the installed build: any difference other than the intended one
  fails, and so does the intended one going missing, which would leave a file that freezes
  the tileset while fixing nothing. Regenerate with `tools/generate_flamingo_tiles.py`.

## Conflict passes

Some guards decide **at file scope** whether a feature installs itself at all, because
standing down before touching anything is the only arrangement where load order between
two mods stops mattering. A spec cannot reach those: the decision was made before it ran.

So the suite runs again, once per folder under `specs-conflicts/`, with the whole mod
loaded a second time and that folder's name added to the mod list:

```
specs-conflicts/CleanHotBar/clean_hotbar_spec.lua
```

The folder name is the other mod's id, the `id=` line from its `mod.info` and what
`getActivatedMods` returns. `run-tests.ps1` passes it through the `QOLC_MODS` environment
variable, and `pz_stubs.lua` seeds `Harness.ActivatedMods` from it before any mod file
loads. Adding a conflict is a folder and a spec, no runner changes.

Every such spec asserts what did **not** happen, and an assertion of absence passes just
as happily against the wrong mod list, so each one starts by proving the pass is really
set up the way it claims.

The `MoodleType` and `CharacterStat` tables exposed to tests are built from that same
jar reflection, so a retired constant is nil in tests exactly as it is in game, and the
stub raises a clear error instead of a Java NullPointerException. `CharacterStat` also
carries the real min, max and default of every stat, which is what lets the stubbed
`Stats:set` clamp exactly as the engine does.

Sandbox defaults are parsed out of `sandbox-options.txt` and handed to the specs, so
the stubs never restate a number that already lives in the option file.

## Writing a spec

```lua
Test("description of the behaviour", function()
    Harness.Fire("OnGameBoot")
    Harness.SetMoodle(MoodleType.PAIN, 4)
    Harness.FireFrames(20)

    local Draw = Harness.FindDraw("qolc_pain")
    AssertNotNil(Draw, "pain overlay was not drawn")
    AssertNear(Draw.Alpha, 0.28, 0.0001, "pain alpha")
end)
```

Harness surface: `Fire`, `FireFrames`, `SetMoodle`, `SetScreenSize`, `ClearDraws`,
`FindDraw`, `DrawOrder`, `HandlerCount`, and the flags `HasPlayer`, `Draws`, `Moodles`.

For anything player driven: `NewPlayer(Number, IsLocal)` builds a character with its own
stats, moodles and mod data, and `Advance(Milliseconds)` moves the clock that
`getTimestampMs` reads. `ResetSandbox` and `ClearSandbox` set up the server side
balance, the latter reproducing a save made before a feature existed.

For UI: `NewInventoryPage(PlayerNum, OnCharacter)` and `NewHotbar(Player, SlotTypes)`
build the two windows, `ButtonOrderByArray` and `ButtonOrderByPosition` read a container
window's order out of the array and off the screen so a spec can prove the two agree,
and `SlotOrder` does the same for the hotbar. `NewContainer`, `NewInventoryItem`,
`NewIsoObject` and `PlaceItemOnGround` cover the things an order can be stored on.

Both windows reproduce the behaviour that actually catches mods out. The inventory page
takes its scroll height and selection from the `backpacks` array rather than from where
the buttons are drawn, and the hotbar rebuilds its slots in the game's own order with
Back forced to the front every time clothing changes.

`ClientCommands` records anything a client would have sent to a server, and
`Harness.IsClient` switches between singleplayer and a multiplayer client, which is how
the networked half is tested without a server.

Passing `IsLocal` as false gives a remote player. On a real client `OnPlayerUpdate`
fires for those too, so any mod that writes to a character needs a test proving it
leaves them alone.

Assertions: `AssertTrue`, `AssertFalse`, `AssertNil`, `AssertNotNil`, `AssertEquals`,
`AssertNear`, `AssertContains`.

## Adding a mod

Drop `specs/<mod>_spec.lua` in place. The runner picks up new specs and new mod source
automatically, no configuration.

If a mod calls a game function the stubs do not cover yet, add it to `pz_stubs.lua`.
Events need no work: any `Events.Anything.Add` is captured on first use.

## Requirements

A JDK. The JRE bundled with the game has no compiler, so the runner looks for one in
`Program Files`, Adoptium and the JetBrains runtime included with IntelliJ both work.
Tests execute from the game directory, because Kahlua resolves `stdlib.lua` relative to
the working directory.
