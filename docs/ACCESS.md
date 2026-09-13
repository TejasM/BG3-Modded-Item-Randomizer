# Access controls — experimental v1.0.2

The fork now redistributes only modded equipment with positive evidence of
merchant or convenience-chest delivery. A detected authored NPC/world placement
takes precedence, even if the item also appears in a merchant or tutorial table.
Unknown sources are excluded from redistribution. Existing browser exclusions
still apply. Source gating is independent of the Power toggle.

## Behavior

- **Convenience delivery:** identified, newly generated equipment is moved into
  hidden storage. MIR can distribute its template through normal world loot.
- **Merchant stock:** identified generated equipment is held until both the host
  level and Act meet its power assessment. Reopening trade releases eligible
  stock. Disabling the Power gate also releases merchant power holds.
- **Player-handled equipment:** observed player acquisitions, deposits and sales
  are protected. Mod-generated gear is never removed from the party inventory.
- **Authored placements, vanilla items, cosmetics and consumables:** untouched
  by Access controls. Stackable equipment is also left alone to avoid instance
  merging or splitting in storage.

Items are not deleted. A per-save ledger records each held item's UUID, source
holder and off-stage storage container. Transfers preserve the exact instance
and original ownership. No replacement template is spawned for merchant release.
Failed transfers retain recovery records. Unloaded holders remain pending until
their area is available. Holdings survive save/reload through mod variables.

The new **Access** MCM tab has separate convenience suppression and merchant-gate
switches, both enabled by default. Changes affect the next source interaction;
level/region starts also attempt eligible releases. `!mir_access` reports held
and tracked instance counts. `!mir_power <stat>` explains power requirements.

## Restore before uninstalling

Disable both Access switches in MCM. Visit the regions/sources where items were
held, and run `!mir_access restore`. The command disables both switches for the
session and returns holdings whose original sources are loaded. Check the count
reaches zero before removing this fork. Unloaded regions cannot be restored
remotely; removing the mod first can leave those items in hidden storage.

## Detection limits

BG3's `AddedTo` event distinguishes `Treasure` and `TradeTreasure` generation,
but reports scripted gifts, deposits and sales alike as `Regular`. Consequently:

- Existing stock with no recorded provenance is not retroactively confiscated.
- Ambiguous scripted gifts and old camp contents are left alone. This is not yet
  universal suppression across every equipment mod or delivery framework.
- Direct gifts into player inventory are protected. Delivery bags and nested
  container content may require mod-specific adapters.
- Convenience recognition uses the camp chest family, the tutorial chest table,
  and exact source UUIDs in `Config.convenienceContainers`. Generic storage or
  traveller names are not enough. Local template data is checked when available.
- The source index traces root-template treasure references and the known
  `TUT_Chest_Potions` table. It cannot prove the absence of arbitrary scripted
  quests or placements defined only on level instances. Manual exclusions remain
  necessary for such mods. Detected incomplete index resolution disables positive
  source classification instead of assuming items are safe to manage.
- Other loot mods can independently grant the same equipment. Their authored
  world drops are outside this feature's interception points.

No full inventory is scanned every frame. Generation events record provenance;
container-open and trade-request events inspect the relevant holder. Inventory
iteration uses Osiris EntityEvent callbacks. The timing of those callbacks versus
the trade UI must still be checked in BG3; this build has automated mock tests,
not verified in-game purchase/pickpocket timing.

## Development

`Server/Access.lua` owns runtime provenance, holding and restoration. Source
classification lives in `TreasureIndex.lua`; `Catalog.lua` records whether an
entry is managed, and every draw stage applies that flag through Main.lua's
shared entry filter. `tests/test_access.py` exercises generation, protected
player transfers, recovery, source precedence, and save-state reuse.

The holding backpack UUID was verified against this installation's vanilla
Shared root templates. Package extraction/byte comparison verifies packaging;
it does not establish that game runtime behavior is correct.
