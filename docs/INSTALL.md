# Install — MIR (Modded Item Randomizer)

MIR installs like a normal `.pak` mod, with one requirement that is not optional: **Mod Configuration Menu (MCM) must be installed and must load above MIR.** Without MCM, MIR disables itself and adds nothing to the game. The whole process takes a couple of minutes.

## Prerequisites

1. **Baldur's Gate 3**, Patch 8 or later.
2. **BG3 Script Extender (BG3SE)** installed and working (version 29 or later). If you don't have it, get it from <https://github.com/Norbyte/bg3se>. When BG3 launches with Script Extender active, you'll see its console window.
3. **Mod Configuration Menu (BG3MCM)** — NexusMods mod **9162**. **Required and enforced.** Every MIR setting lives there, and MIR goes dormant if MCM's pak is not in your load order. Developed and tested against MCM v1.40.1.
4. **BG3 Mod Manager (BG3MM)** — strongly recommended. MIR must be in your *active* load order, and a mod manager makes that one click.
5. **Windows.** Script Extender is Windows-only, so MIR is too.

MIR is safe to add to a playthrough already in progress. It only sees containers and corpses you interact with after it is installed.

## Install

1. **Download and unzip** `MIR-1.0.1.zip`. Inside you'll find `MIR.pak` plus these documents.

2. **Copy the `.pak` into your BG3 Mods folder.** Open File Explorer, paste this into the address bar, and press Enter:
   ```
   %LocalAppData%\Larian Studios\Baldur's Gate 3\Mods
   ```
   Copy `MIR.pak` into that folder.

3. **Activate it in your load order.** Open BG3 Mod Manager and refresh its mod list (`F5` or the refresh button). "MIR" appears in the **Inactive** pane — drag it into the **Active** list.

4. **Put Mod Configuration Menu above MIR.** MIR reads MCM's settings during its own startup, so MCM has to be initialised first. MIR has no ordering requirement against any other mod — only against MCM. A minimal correct order looks like:
   ```
   Mod Configuration Menu
   ...(anything else)...
   MIR
   ```
   Click **Save Load Order to File**, then launch the game from BG3MM.

5. **Load any save, or start a new game.** MIR builds its item pool as the session loads and starts rolling on the first container or corpse you open.

**Playing multiplayer?** Every player installs the same MIR, Script Extender and MCM versions, with MCM above MIR. The game compares mod lists when a player joins, and it cannot download a Nexus mod for you. MIR's loot logic runs on the host only, and the host's MCM settings apply to the whole party. See the multiplayer question in the FAQ of `README.md`.

## Verify it loaded

**1. The Script Extender console banner.** With the Script Extender console open, MIR prints one line at startup, beginning with its version:

```
MIR v1.0.1 (bookshelves + scrolls + browser status panel; clutter gets vanilla consumables) BootstrapServer/Main loaded. Server console: !mir_status !mir_pool ...
```

**2. `!mir_status`.** In the Script Extender console type `server` and press Enter to switch to the server context, then `!mir_status`. You should get a line like:

```
status: enabled=true gameplayActive=true level=WLD_Main_A catalogBuilt=true rolls=1 chance=25% utilExclude=true mcm=detected ledger=0 spawned
```

Look for `enabled=true`, `catalogBuilt=true`, and **`mcm=detected`**. `mcm=MISSING - MIR DORMANT` means MCM is not in your load order and MIR has switched itself off. `mcm=pending` means MCM is installed but its API had not answered yet — a normal transient state during load; `!mir_mcm_sync` forces a re-read.

**3. The MCM page.** Press **INSERT** (or open MCM from the ESC menu) and find **MIR**. You should see four tabs — General, Pool, Rarity, Exclusion lists — plus the custom **MIR Browser** tab.

## Using it

- **Leave the defaults for a session and just play.** Chests and corpses draw from the whole modded pool, wardrobes give garments, bookshelves give scrolls. One roll at 25% averages one spawn per four containers MIR actually rolls on — you are not meant to notice a firehose.
- **Open the MIR Browser tab** and skim the mod list, sorted by item count. If a single large pack dominates the pool and you'd rather it didn't, tick it out right there.
- **Each category row shows ON, LIMITED or OFF and says why.** Weight 0 switches a category off; a category limited to one kind of container is switched off on that container's setting.
- **Want barrels and crates too?** Tick **Include clutter containers** on the General tab. They give potions, arrows and ingredients — the game's own and modded — and only there.
- **Upgrading from a pre-release build (v0.6–v0.9)?** Check every slider on the MIR Browser tab: an old bug may have left some at 0, and the old per-category include checkbox is gone (its state is discarded).
- `!mir_dry on` makes MIR classify and log every container and corpse without injecting anything, if you want to see what it considers a treasure container before you commit. `!mir_dry off` afterwards.

## Troubleshooting

### No banner in the Script Extender console

- The pak isn't in `%LocalAppData%\Larian Studios\Baldur's Gate 3\Mods`, or MIR isn't in the **active** load order. Refresh BG3MM and check both.

### `mcm=MISSING - MIR DORMANT`, or an in-game window saying MIR has disabled itself

- MCM's pak is not in your load order, so MIR switched itself off rather than injecting items you could not configure. Confirm MCM is installed and active, and that it sits **above** MIR, then restart. In multiplayer it is the **host's** load order that decides this. Nothing in your save has been changed by the dormant session.

### MCM opens but has no MIR page

- MIR loaded but MCM didn't read its blueprint. Check the Script Extender log for MCM errors and confirm the two mods' load order.

### No MIR Browser tab, but the other four tabs are there

- The custom tab registers separately from MCM's own tabs, so it can fail on its own. Everything stays configurable: the four tabs cover the General, Pool and Rarity settings and your exclusion lists by UUID, and `!mir_share <category> <0-100>` / `!mir_share list` in the console set and show category shares.

### Nothing spawns after a lot of looting

- Check `!mir_status` and `!mir_pool` first. Then consider whether you use an auto-loot or loot-vacuum mod — those can bypass the events MIR listens on. See "Compatibility" in `README.md`.

### A category reads OFF or LIMITED in the MIR Browser

- The status is derived from your settings, not stored — read the reason on the row. See "The MIR Browser tab" in `README.md`.

### The version BG3MM shows doesn't match the console banner

- Go by the banner; it is printed by the code that is actually running. Refresh BG3MM and re-export the load order.

### Do not run MIR alongside another loot randomizer

- The Randomized Equipment Loot family, Fade's Equipment Distribution AIO's randomizer feature, and similar mods rewrite loot data and are not compatible. Details in `README.md`.

## Uninstalling

1. Deactivate **MIR** in BG3 Mod Manager and save the load order.
2. Delete `MIR.pak` from your BG3 Mods folder.

That is all. MIR is strictly additive and safe to remove mid-save: items it already spawned are ordinary items from mods you still have installed and simply stay where they are. MIR's per-save bookkeeping becomes inert.

Your settings survive in MCM's profile folder in case you reinstall:

```
%LocalAppData%\Larian Studios\Baldur's Gate 3\Script Extender\BG3MCM\Profiles\<profile>\MIR\settings.json
```

Delete that folder too if you want a clean slate. MIR's log and reports (`MIR_log.txt`, `MIR_Mods_Report.txt`, `MIR_TreasureTable_Report.txt`, `MIR_Placed_Mods_Report.txt`) live in your Script Extender folder and can be deleted freely.
