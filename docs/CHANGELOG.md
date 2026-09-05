# Changelog — MIR (Modded Item Randomizer)

MIR's development history. **v1.0.1 is the first public release.** Everything below it was a pre-release build that was never published (v1.0.0 was built and tested locally and superseded before upload); the list is here so the first public release carries an honest record of how it got here.

Dates are the day each build was completed and installed for testing.

---

## v1.0.1 — 2026-09-03 — first public release

**Fixed: clutter containers set to consumables only could never hand out the game's own arrows and ingredients.** Reported on the first test of v1.0.0: with *Include base-game consumables* off, arrows and alchemy ingredients read `OFF  no items in pool` and barrels gave none — because no mod in that load order adds any, every arrow MIR had ever spawned was vanilla, and the v0.9 rule admitted only *modded* consumables for clutter. That rule existed because MIR could not tell a vanilla potion from a modded one at draw time. It now can: each item admitted only because a container type asked for it is scoped to that type, and is never drawn for any other. So **Clutter containers: consumables only now admits vanilla and modded potions, arrows and ingredients into clutter, and only clutter**, with no Pool-tab setting required and no leak into chests. The Pool tab's two consumable settings keep their meaning (consumables *everywhere*). One consequence for anyone who already runs with clutter on: barrels get the vanilla consumables the moment you install this build.

**Changed: alchemy ingredients ignore the rarity window.** The game declares no rarity for any ingredient, so MIR files them all as Common, and a window above Common silently removed every one — the second half of the same bug report. The Rarity tab, the ingredient row on the MIR Browser (`- no rarity window`) and `!mir_rarity` all say so now. Potions, arrows and scrolls declare rarities and still obey the window.

**Changed: the MIR Browser says where a single figure applies.** A category that cannot appear in every enabled container type is labelled, so arrows read `ON  37.1% (clutter)` rather than a bare percentage. The `no items in pool` reasons now name the switch that is actually off. Browser item rows say `clutter containers only` / `bookshelves only` where that applies, so nobody excludes "Shared" as junk and silently kills their clutter loot.

**Changed: a fourth no-op reason in the log.** *Everything left that matches is reserved for another container type* — distinct from the content filter, the rarity window and an empty pool. The content-filter line also distinguishes "no items" from "no items drawable here". The catalogue line and `!mir_rarity` report how much of the pool is clutter-only or bookshelf-only.

58 MCM settings, 42 shown across four tabs — unchanged.

## v1.0.0 — 2026-09-01 — built and tested locally, superseded by 1.0.1 before upload

**Added: bookshelves and desks are their own container class, and they hold scrolls.** Bookcases, bookshelves, book rows, stacks and piles, scroll shelves and desks used to be clutter, so a necromancer's bookshelf handed out arrows. They are now a separate class, on by default, with two content settings: **Bookshelves: scrolls** (on) and **Bookshelves: also spawn all other items** (off). Unlike wardrobes, unticking both makes bookshelves spawn nothing at all — there is no unrestricted fallback, because a user who unticks scrolls to stop scrolls must not be handed a greatsword instead. Two name-match quirks are documented: the apothecary and tailor desks count as desks, and one wine rack is shaped like a scroll shelf.

**Added: scrolls, a sixteenth category.** Scrolls were not in MIR's pool at all before this build. They are consumables — repeatable, never duplicate-limited — with their own slider. **One pool-wide switch, `Include scrolls` (off by default), covers vanilla and modded scrolls together**, deliberately: MIR's draw-time gate works per category and cannot tell a vanilla scroll from a modded one, so a base/modded pair would have let the whole category leak into chests the moment either was on — the exact bug v0.9 fixed for consumables. With the switch off, bookshelves still get scrolls through their own setting, and those scrolls appear in bookshelves only. With it on, you will find vanilla scrolls in chests even with base-game items off.

**Changed: the MIR Browser's per-category include checkbox is gone, replaced by a status the mod derives for you.** The checkbox was a hidden global veto: unticking a category switched it off everywhere, *including* containers whose own setting admitted it — which is exactly what silenced clutter consumables in testing, almost certainly as collateral from the v0.8.1 slider bug. Each row now reads **ON** (competes with other categories somewhere — slider live, percentage shown per container type where the company differs), **LIMITED** (the only category allowed wherever it can appear — 100% there, slider inactive) or **OFF** (with the reason: weight 0, no items, or which Pool-tab switch to flip). Weight 0 is now the only browser-side off. **If you had a category unticked, that state is discarded — set its weight to 0 instead.**

**Changed: percentages are per container type.** A category's share is its weight over the weights of the categories it competes with in a given kind of container, so potions can be 6% of a chest and 33% of a barrel. Rows that compete in several kinds with different company show each figure separately; nothing is averaged across containers that do not share a pool.

**Changed: when a roll succeeds but nothing matches the container's content filter, the log names each allowed category and why it cannot draw** — weight 0, switched off on the Pool tab, no items, or nothing inside your rarity window. The old line was accurate but not actionable.

**Added: `!mir_bookshelves` and `!mir_scrolls`.** `!mir_share list` now prints each category's status; `!mir_category` is removed with the checkbox it drove. `!mir_status` reports the bookshelf gates and the whole Pool tab. `!mir_pool` now says when a category's items are drawable in clutter or bookshelves only, and the catalogue line counts Objects that matched no category.

58 MCM settings, 42 shown across four tabs.

## v0.9.0 — 2026-08-30

**Added: a Rarity tab — limit which rarities spawn, by character level and by Act.**

Off by default. Turn it on and you set a lowest and highest permitted rarity for four character-level
bands (1-5, 6-10, 11-15, 16-20+) and for each of the three Acts, chosen by name rather than by number.

**The two rules combine as the most restrictive of the pair** — the higher minimum and the *lower*
maximum — so lowering either your level band or your Act restricts the loot immediately. (The
original specification said the higher maximum; that was changed deliberately, because under it
lowering a single maximum did nothing at all and the setting appeared broken.) If a band and an Act
do not overlap, MIR narrows to one tier and logs which two rules disagreed instead of quietly
spawning nothing.

The top band covers 16 **and above**, so a level-cap-raising mod keeps working rather than leaving
your character outside every band.

**Added: `!mir_rarity`**, which both reports and sets. It prints every band and Act, marks the two
that apply to you, shows the window actually in use, and — most usefully — counts how many items in
your pool fall inside it. Worth knowing before you raise a minimum: an item whose mod declares no
rarity is filed as Common, and most cosmetic mods declare none, so a minimum above Common cuts
deeper than you would expect.

**Changed: clutter containers now admit modded consumables by themselves, and keep them to
themselves.** Previously, if consumables were not in your pool, MIR turned the Pool setting on for
you — which made them pool-wide, so they also began appearing in chests and on corpses. Now they are
admitted for clutter and drawable only there. Base-game consumables are never admitted this way and
still need their own Pool setting.

**MIR no longer edits any of your settings, ever.** Deleting the behaviour above removed the only
place it did.

68 MCM settings, 38 shown across four tabs.

## v0.8.1 — 2026-08-28

**Fixed: the category-share sliders in the MIR Browser wrote ZERO every time you moved them.**

This is the important one. A slider's value is held as an array internally, and while the code that
*writes* to the sliders had always known that, the code that *read* your drag did not — it asked for a
plain number, got nothing, and quietly substituted 0. So every category you adjusted was set to a
weight of 0, which means that category stopped spawning entirely. Categories you never touched kept
their values, which is why the problem looked arbitrary.

If you tuned shares in the browser at any point since v0.6.6, **check your weights** — the affected
categories will read 0. `!mir_share list` prints them all, and `!mir_share <category> <0-100>` sets
one back (the console path was never affected). The default is 50.

The underlying mistake was a silent fallback: a value that could not be read was turned into a
valid-looking "off" instead of being rejected. It now ignores a value it cannot read and leaves your
setting alone, so a failure of this kind can never again be mistaken for a deliberate zero.

## v0.8.0 — 2026-08-25

**Wardrobes are now their own thing, and clutter stops handing you greatswords.**

**IF YOU ALREADY RUN WITH CLUTTER CONTAINERS ON, READ THIS FIRST.** Wardrobes used to be classified as clutter, which meant they drew from your entire pool like a barrel does. They are now a separate container class with their own switch and their own content filter. With the new defaults they spawn garments only; if you switch wardrobes off, they spawn nothing at all where they previously spawned anything. That is a deliberate change and it is the one thing in this release most likely to be noticed.

**Added: wardrobes and closets are a separate spawn target,** on by default, and they spawn clothing. Three content filters decide what may appear: cosmetic garments (camp clothing, camp shoes, underwear), garments with stats (body armour, helmets, gloves, boots, cloaks), and a third that **adds** everything else on top rather than replacing them. Untick all three and the wardrobe is simply unrestricted — the wardrobe switch itself is the real on/off control. Your own camp wardrobe is never touched, for the same reason the camp chest never was.

**The wardrobe cosmetics filter deliberately overrules the pool-wide one.** Ticking *Wardrobes: cosmetic garments* admits camp clothing into wardrobes even when *Include cosmetics* on the Pool tab is off. A setting that names a container decides what may appear in that container; otherwise the setting would silently do nothing, which is exactly the trap this release is fixing elsewhere.

**Added: clutter containers can be restricted to consumables,** and are by default. Barrels, vases, crates and urns give you potions, arrows and alchemy ingredients rather than whatever the pool holds. Clutter itself is still off by default. (In v0.8 this could turn a Pool setting on for you; **v0.9.0 replaced that** with admitting consumables to clutter alone.)

**Fixed: a container you skipped past is no longer dead forever.** MIR has always marked every container it evaluated; it now records *why*. A container it rolled on, or deliberately left alone, stays finished with — but one merely passed over because a toggle was off becomes eligible again when you turn that toggle on. Without this, enabling wardrobes mid-playthrough would have done nothing on every wardrobe you had already walked past. Containers marked by v0.6.4 and later already recorded this reason, so wardrobes and clutter you walked past in an earlier version DO come back. Anything MIR cannot identify a reason for stays finished with, which is the safe assumption.

**Fixed: a dry run no longer burns the containers or corpses it inspects.** `!mir_dry` marked everything it looked at as rolled, so surveying your world with it permanently killed every container and every corpse it touched. Dry runs are now recorded as dry runs, and the dry-run line reports the container's class and exactly which categories are allowed in it.

**Added: `!mir_wardrobes` and `!mir_clutter`** to drive the new switches from the console, and `!mir_status` now reports every container gate and its content filter — so "why did my wardrobe do nothing?" is answerable from the log instead of guesswork. When a roll succeeds but nothing in the pool matches a container's filter, MIR now says so specifically rather than reporting a generic empty pool.

53 MCM settings, 23 shown across three tabs.

## v0.7.0 — 2026-08-25

**The theme of this release is telling you the truth about duplicates instead of quietly deciding for you.**

**Added: `!mir_placed_mods`.** Writes `MIR_Placed_Mods_Report.txt` — every mod that places its own items in the world, how many it places, how many MIR can still spawn from it, and the container it uses. These are the only mods whose items you could ever obtain twice: once where the mod puts them, once from MIR. It builds the placement index on demand, so it works even with the placement filter switched off, and it says plainly which of those two states you are in.

**Added: you can now let a placed item into the pool anyway.** Previously the placement filter was all-or-nothing: either every placed item was fenced or none were. There is now a per-item override, in the MIR Browser tab and as `!mir_forceinclude`. When you use it, MIR tells you exactly what you are accepting — *also placed in the world (…) — you may find two* — and the browser keeps saying so on that row afterwards. A user exclusion, or an excluded mod, still outranks the override, and MIR now says that instead of failing silently.

**Fixed: the per-mod "placed by mod" count dropped items you had allowed in.** The count is what tells you which mods double-dip; an item does not stop being placed by its mod just because you let it through.

**Fixed: base-game items could be labelled "placed by mod".** The placement filter has always been modded-equipment-only, but the browser's fallback check had no such guard, so with **Include base-game items** on, vanilla items sitting in an indexed vanilla table were mislabelled.

**Fixed: messages from the server were discarded when a change succeeded.** Only refusals were shown, which meant every confirmation — including the duplicate warning — was silently thrown away by the interface.

**Changed: "held back" is gone.** Every report, console line and document now says *excluded from MIR's spawn pool*. The old phrasing read as though MIR were stopping the game from handing you those items. It never was and never could: MIR only ever adds. The `!mir_tables` report now says so outright.

**Changed: the placement filter's effect is now documented from a real measurement** instead of being described as unmeasured. On a ~1,478-mod load order the scan took 532 ms and the filter excluded 5,064 items from the spawn pool, leaving 2,451 eligible — roughly two thirds, almost all of it clothing mods that ship their whole catalogue in a backpack. That is the filter working as intended, and `!mir_placed_mods` now names the mods responsible.

**Documented: base-game duplicates are expected**, which is why **Include base-game items** defaults to off. Hand-placed vanilla loot is assigned to level instances MIR cannot see at runtime, so it cannot know an item is already waiting for you. Modded items are different — MIR *can* see those, and fences them by default.

48 MCM settings, 18 shown across three tabs.

## v0.6.6 — 2026-08-24

**Changed: one settings surface for category shares.** The **Category shares** tab is gone. Every share is now edited in one place — the **MIR Browser** tab — where each category has its include checkbox, its live normalized percentage and its weight slider on a single row. Previously the same fifteen categories appeared in two places at once, which was confusing and which let the two views disagree.

**Your tuned values are preserved.** The thirty underlying settings still exist, under the same names and with the same defaults. They were moved into a blueprint section that is never rendered — a change to where they are *drawn*, not to where they are *stored*. MCM's settings file is keyed by setting name and ignores tab and section structure entirely, so your existing values carry over untouched. Nothing needs re-tuning after this update.

**Added: console fallbacks for shares.** `!mir_share <category> <0-100>` sets a weight, `!mir_share <category>` reads one back, `!mir_share list` prints every category as `<token> weight=<n> included=<true|false>`, and `!mir_category <category> on|off` includes or excludes a category. These exist so shares stay reachable if the custom browser tab ever fails to register. They take a short token (`weapon`, `torso`, `vanityClothing`, …) rather than the display label; `!mir_share list` is how you find them.

**Fixed: the browser and the MCM settings store did not update each other.** Two separate bugs, one in each direction. Edits made in the browser were written with change events suppressed — the value was stored, but nothing was notified, so MCM's own interface never repainted and no other listener ever heard about it; and the function meant to push MCM-side edits back to the browser had been left as an empty stub when shares moved to the custom tab, so those edits never arrived. Both directions now work, with a guard so a pushed update cannot be mistaken for a user edit and echo back, and a slider you are mid-drag on is no longer yanked out from under you.

**Fixed: refused multiplayer writes now snap the widget back.** A share or exclusion edit rejected because you are not the host now returns the true current values, so the slider or checkbox returns to where it really is instead of showing a change that did not happen. An in-interface tooltip still pointing at the removed tab was corrected at the same time.

**Fixed: `!mir_excludes` printed `?` instead of an item's name** when the item was excluded by table or by template rather than by hand. It now resolves names from every exclusion source, falling back to the root template's own name.

Still 47 MCM settings registered — 17 shown across three tabs (General, Pool, Exclusion lists), 30 held as storage for the browser's sliders.

## v0.6.5 — 2026-08-24

**Changed: the "already placed" filter now judges WHERE an item is placed.** Until now it excluded from MIR's spawn pool any modded item that appeared in a mod's treasure data at all. It now asks whether a mod put the item somewhere you would actually *find* it:

- **Counted as a placement:** an item on a **specific NPC** (that character's own loot), or in a **specific world container** — a reward chest, a cache.
- **Not counted, and back in the pool:** **merchant stock** (buying is not finding); **camp chests, tutorial chests and traveller's chests**, which are player-convenience storage rather than an authored placement; and **generic loot tables shared across many NPCs**, which is random class loot rather than gear placed anywhere in particular.

This matters most for the commonest modded distribution pattern of all — dumping a whole catalogue into the tutorial chest. Under the old rule such a mod had its entire catalogue excluded from MIR's spawn pool, which was the exact opposite of the intent.

**Changed: a partial scan is now retryable.** The scan runs under a time budget; if it overruns, the result is marked PARTIAL and the filter is switched off for that session rather than fencing an arbitrary slice — but running `!mir_tables` now rebuilds the index on the spot instead of the session being written off.

**Changed: `!mir_tables` builds the index on demand** (so the report works with the filter off) and now reports the split: placement tables counted, merchant tables ignored, camp/tutorial tables ignored, and how many of your catalogue's items were excluded from MIR's spawn pool.

Unchanged: the filter still applies to **modded equipment only** — base-game items and consumables are never affected — and items a quest mod spawns from its own script still cannot be detected and still need a manual exclude in the MIR Browser tab.

The Pool-tab setting is renamed to **Exclude items their mod already places in the world**. Still 47 MCM settings.

**Measured after release in v0.7.0:** on a ~1,478-mod load order the scan took 532 ms and the filter excluded 5,064 items from the spawn pool, leaving 2,451 eligible.

## v0.6.4 — 2026-08-24

**Added: MIR now tells you in game when it has disabled itself for want of MCM.** A small Script Extender window explains that Mod Configuration Menu is required, that MIR has switched itself off, that **nothing in your save has been changed**, and how to fix it.

It cannot use MCM's own interface for this — MCM is the missing piece — so it is a plain Script Extender window instead. On a machine where Script Extender's UI layer is broken the window will not appear, and the banner in `MIR_log.txt` remains the fallback.

## v0.6.3 — 2026-08-24

**Changed: Mod Configuration Menu is now a hard requirement at runtime, not just a declared dependency.** Previously, with MCM absent, MIR ran on its built-in defaults and injected items you could neither configure nor switch off. Now **MIR goes dormant**: no catalogue is built, no roll is made, nothing is injected, and a loud banner naming the missing dependency is written to the log. `!mir_status` reports `mcm=MISSING - MIR DORMANT`.

MCM's pak being present while its API has not initialised yet is deliberately *not* treated the same way — that is a transient state during load, not a missing dependency, and MIR waits it out.

## v0.6.2 — 2026-08-21

**Added: "Exclude items their mod already places" (Pool tab, default ON).**

If a mod distributes an item through its own treasure tables — gear the author deliberately put in a reward chest, a specific world container or a merchant's stock — MIR now keeps it out of the pool, so you never receive a duplicate of an authored drop before you find the real one.

- Applies to **modded equipment only**. Base-game items and consumables are never fenced this way.
- Detection covers treasure-table distribution only. Items a quest mod spawns from its own script cannot be detected at runtime and still need a manual exclude.
- The scan runs under a time budget; if it can only complete partially, the fence goes inert for that session rather than fencing an arbitrary slice.
- New console commands: `!mir_tables` (writes a full detection report) and `!mir_placed on|off`.
- **Since measured** (see v0.7.0): on a ~1,478-mod load order the fence excluded 5,064 items and left 2,451 eligible. The default stays ON; if that removes more of your pool than you want, `!mir_tables` shows what it caught, `!mir_placed_mods` names the mods, and `!mir_placed off` (or the Pool-tab checkbox) turns it off.
- The MIR Browser flags fenced items as placed by their mod, so you can see why something is missing.

47 MCM settings.

(The placement rule here was superseded in v0.6.5, which made it provenance-aware: merchant stock and camp/tutorial/traveller's chests no longer count as placements.)

## v0.6.1 — 2026-08-21

**Fixed: the checkboxes on the Category shares tab could not be unticked.** The live-percentage readout there was a display-only list that MIR re-published over every time you clicked it — a readout that looked like a control. It has been removed.

**Changed: live category shares moved into the MIR Browser tab,** where each category now gets one row: include checkbox, live normalized percentage, and a real 0–100 slider, side by side. Dragging a slider updates every other percentage immediately.

**Added: an explicit include/exclude toggle per category.** You no longer have to set a share to zero to switch a category off — untick it, and it drops out of the normalization entirely so the remaining categories re-normalize to 100%.

Category and share changes are draw-time only and never rebuild the pool. Slider drags are debounced so a drag doesn't hammer the settings file.

46 MCM settings.

## v0.6.0 — 2026-08-21

**Added: the MIR Browser tab** — a searchable, paged browser of every mod contributing items to the pool.

- Mod list sorted by item count, with per-mod totals; click a mod to drill into its items.
- Tick a checkbox to exclude a whole mod or an individual item; untick to put it back.
- Buttons: Refresh, Clear search, Clear ALL exclusions.
- Changes apply immediately, rebuild the pool once, and persist per MCM profile.
- In multiplayer the host manages settings: any player can browse the pool, but exclusion writes from non-host players are refused with a message saying so.

**Added: console equivalents** that work without the UI — `!mir_exclude mod|item <uuid>`, `!mir_exclude clear`, `!mir_include mod|item <uuid>`, `!mir_excludes`.

Search and paging run server-side by design: a single Script Extender network message is capped at 1,048,575 bytes and oversized ones are dropped silently, so the browser never ships the whole catalogue to the client.

## v0.5.2 — 2026-08-21

**Added: a live normalized category-shares readout** at the top of the Category shares tab, showing each category's real percentage alongside its raw weight, with inactive categories labelled (no items / weight zero / category off). Confirmed in-game that the MCM window repaints these values live.

(Superseded in v0.6.1, which moved this into the MIR Browser tab where it could be shown next to real sliders.)

## v0.5.1 — 2026-08-21 (folded into v0.5.2, never released separately)

**Added: read-only views of MIR's curated exclusions** at the top of the Exclusion lists tab — the utility-mod fence (following its toggle) and the permanent NPC-gear fence — each filtered to mods actually present in your load order and shown by readable name.

## v0.5.0 — 2026-08-20

**Added: full Mod Configuration Menu integration.** MIR is now configured in-game rather than by console command.

- MCM becomes a declared dependency. Four tabs, 29 settings at this stage: General, Pool, Category shares, Exclusion lists.
- Settings apply live with no restart. Settings that change what's in the pool trigger a rebuild, debounced so flipping several checkboxes costs one rebuild.
- Settings persist per MCM profile, globally across saves — nothing is written into a savegame.
- MCM profile switches re-sync everything and rebuild once.
- Console commands still work as **session-transient overrides**: they never write back to MCM, and any full re-sync (a new session, an MCM profile switch, or `!mir_mcm_sync`) restores the MCM values over them and notes in the log which ones it replaced.
- `!mir_status` now reports `mcm=detected` or `mcm=absent`; new `!mir_mcm_sync` forces a re-read.
- If MCM is missing, MIR's code falls back to its built-in defaults (guarded, but untested — MCM is a hard dependency). *(Superseded in v0.6.3: MIR now goes dormant instead of running on defaults.)*

## v0.4.0 — 2026-08-20

**Changed: consumables split into three categories** — potions and elixirs, arrows, and alchemy ingredients — each with its own share slider, instead of one lumped "potion" category.

**Fixed: the no-duplicate rule after that split.** Equipment is one-per-save; arrows and ingredients are consumables and must be able to repeat. The rule now keys off a consumable flag rather than the literal category name, so the split didn't accidentally make arrows unique.

**Changed: ship defaults set.** Base spawn chance is **25%** (the value the mod ships with; raise or lower it freely). Category weights default to 50, matching the slider default so one knob doesn't have two numbers.

**Changed: items you exclude stay visible.** Your per-mod and per-item exclusions are now applied after an item is fully classified rather than before, so an excluded item keeps its name, rarity and category and can be found again to un-exclude. Without this the exclusion browser would have been a one-way ratchet.

**Added:** `!mir_consumables on|off` and `!mir_consumables base on|off`.

## v0.3.2 — 2026-08-20

**Added: the permanent NPC / character-gear exclusion.** Mods whose items exist to equip a specific NPC, companion or origin character — starting-gear upgrades, NPC redesigns and evolutions, companion looks mods, join-the-party companion mods — are excluded unconditionally. **This has no toggle and never will.** That gear is meant to be used in the game by the character it was made for.

23 mods on the shipped list. Player-wearable themed packs are not NPC gear and stay in the pool.

## v0.3.1 — 2026-08-20

**Added:** `!mir_ledger` — a read-only dump of every item MIR has spawned in the current save and which container or body it went into, with names resolved.

## v0.3.0 — 2026-08-20

**Added: the utility-mod fence (default ON).** A curated list of mods whose purpose is utility rather than content — photo-mode tools, pose-pack trigger items, cheat and tutorial-chest spawners, QoL storage, framework libraries — whose items never enter the pool. Prompted by the very first live spawn in testing being a photo-mode ring.

57 mod UUIDs plus 32 distinctive mod names at this version (two of them later moved to the NPC-gear list, leaving 53). Every UUID verified against a real installed mod; none guessed. Content and equipment packs stay in the pool by design — they are what MIR exists to distribute.

**Added:** `!mir_util on|off` (toggles the fence and rebuilds the pool) and `!mir_mods` (writes a per-mod breakdown of the eligible pool to a report file).

## v0.2.1 — 2026-08-19

**Added:** `!mir_dry on|off` — dry-run mode. MIR classifies and logs every container and corpse it sees but never injects anything, so you can see exactly what it considers a treasure container before committing.

**Added:** per-corpse evaluation logging.

## v0.2.0 — 2026-08-14

**First working build.** The engine, with settings hardcoded:

- Catalogue of every eligible item in the load order, classified by the mod that *defines* each item rather than the last mod to override it — so rebalance mods don't leak vanilla items into a "modded" pool.
- Twelve equipment categories including weapons and shields.
- Injection at first container open and first corpse loot, additive only.
- Container classification by internal template name: treasure tier rolls, clutter is skipped by default, camp and tutorial chests are excluded outright.
- Guards: containers carried in anyone's inventory are skipped, owned containers are skipped (injected items would otherwise inherit ownership and count as theft), the Nautiloid prologue is excluded, and each container or body is only ever rolled on once.
- Two-stage roll: base chance, then a weighted category pick.
- Equipment no-duplicate ledger, save-scoped and re-read on every load.
- Story and quest items hard-excluded.
- Console commands for testing.

---

## Before v0.2 — research and probing

Six days of instrumented in-game probing preceded the first real build, in a throwaway probe mod. It established the things the mod depends on and would have been guesswork otherwise: that items injected when a container starts opening are visible in the loot panel on that first open; that the engine's "this container has treasure" flag means nothing useful (it reads true on barrels and on your own bag) so containers must be classified by template name; that containers held in an inventory fire the same event as world chests and must be filtered out; that injected items inherit container ownership, so owned containers have to be skipped; that corpse injection works on pre-placed bodies with no combat needed; and that the whole catalogue of ~12,000 stat entries builds in around 100 ms, which removed the need for any caching complexity.
