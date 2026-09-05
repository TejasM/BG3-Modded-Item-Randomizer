# MIR — Modded Item Randomizer

**Takes all of your modded equipment and seeds it into the world's loot, according to your specifications. This mod gives you clear, detailed controls in MCM over where modded items are placed — in treasure chests, on corpses, in wardrobes, in bookshelves and in barrels, each chosen separately — at a rate you control. Wardrobes give you clothing, bookshelves give you scrolls, barrels give you potions and arrows, and you can have the mod give you more kinds of item in each container if you want. The mod is strictly additive: it never removes, replaces, moves or reprices anything.**

If you run dozens of equipment mods, you probably never see most of them. They never surface, because modded gear normally arrives through the tutorial chest, the camp chest, a vendor, or a console command — not through play. MIR hooks the moment loot appears: open a chest, a wardrobe or a bookshelf, or loot a corpse, for the first time, and MIR rolls. On a hit, one item from your modded pool is waiting in the loot panel on that first open. The game's own loot is untouched.

**Why another random equipment mod?** I have used other equipment randomization mods and wanted one more suited to my personal preference. **Your preferences may vary, so I am not saying this mod is better than others — only different.**

**The major difference:** this mod is strictly for adding modded items to the game through gameplay, according to your preferences.

**No sidecar to run.** MIR applies itself at runtime; a single pak file is all that is needed. It auto-indexes all your modded items and adds them as you loot.

**Designed for fine-tuning, transparency and ease of use.** You can exclude specific items and mods, and every control in MCM is detailed and, I hope, easy to understand.

```
  You open a chest for the first time.
  MIR rolls (default: 1 roll at 25%).
  On a hit, one item from your modded pool is added to the chest.
  It is there in the loot panel, on that first open.
```

## ➤ How to use — please read this

**MIR REQUIRES MOD CONFIGURATION MENU (MCM). IF MCM IS NOT IN YOUR LOAD ORDER, MIR DISABLES ITSELF AND ADDS NOTHING TO THE GAME.** It tells you so with a small in-game window and in its log.

Once installed (see `INSTALL.md`), it works out of the box:

- **Leave the defaults for a session and just play.** One roll at 25% averages one spawn per four containers MIR actually rolls on, and a good share of what you open (clutter, owned containers, carried bags, camp chests) is never rolled at all. You are not meant to notice a firehose.
- **Open MCM** (the **INSERT** key, or from the ESC menu) and find **MIR**. Four tabs — General, Pool, Rarity, Exclusion lists — plus a custom **MIR Browser** tab, which is where you tune category shares and exclude mods or items.
- **On the MIR Browser tab, each category row shows a status — ON, LIMITED or OFF — and says why.** Weight 0 is the only way to switch a category off from there; a category that can only appear in one kind of container is switched off on that container's setting instead.
- **Want barrels and crates too?** Tick **Include clutter containers** on the General tab. They are restricted to consumables by default, and that setting admits the game's own potions, arrows and ingredients into clutter on its own — and into clutter only.

## Features

- **Modded loot where you actually find loot** — treasure chests, strongboxes, coffers, sarcophagi and the like, and every corpse you loot for the first time. Pre-placed bodies count; no combat required.
- **Wardrobes give clothing.** Closets and wardrobes are their own container type, on by default, filled with cosmetic garments and stat-bearing armour rather than greatswords. Your camp wardrobe is never touched.
- **Bookshelves give scrolls.** Bookcases, book rows, stacks and piles, scroll shelves and desks are their own type, on by default, holding scrolls — vanilla and modded — with an option to add everything else.
- **Clutter gives consumables.** Off by default. When on, barrels, crates, vases and urns hand out potions, arrows and alchemy ingredients — vanilla and modded — and those items never leak into chests.
- **A two-stage roll you can tune.** *How often* (base chance and rolls per opportunity) is separate from *what* (a 0–100 slider per category). The MIR Browser shows each category's live percentage per container type.
- **Equipment never spawns twice in the same save — guaranteed.** When MIR gives you a weapon, armour piece, ring, amulet or cosmetic garment, it removes that item's template from the live pool and records it in a per-save ledger stored in the savegame's mod variables. Every time the save loads, the ledger is read back and every recorded item is removed from the pool again. So across an entire playthrough, no piece of equipment is handed out a second time by MIR. Consumables — potions, arrows, ingredients, scrolls — are deliberately exempt and can repeat.
- **Exclusion browser.** Every mod contributing items, sorted by count; drill into a mod and tick out a whole mod or a single item. Changes apply immediately and persist per MCM profile.
- **Items a mod already places in the world are kept out of the pool** by default, so MIR never hands you a duplicate of an authored drop. You can let individual items back in.
- **Known utility mods are fenced out** by default — photo-mode rings, cheat spawners, framework libraries — so the first thing MIR gives you is not a photo-mode ring (which is exactly what happened in development).
- **NPC and companion gear is permanently excluded.** No toggle. That gear belongs to its character.
- **An optional rarity window** limits which rarities can spawn by your character level and by Act.
- **Console commands** for every diagnostic and most settings — see the reference at the end.
- **Nothing is written into your save by MIR's settings.** They live in MCM's per-profile store. Removing MIR mid-playthrough is safe.

## Requirements

- **Baldur's Gate 3**, Patch 8 or later.
- **BG3 Script Extender (BG3SE)**, version 29 or later. Required — MIR is entirely Script Extender Lua. Get it from <https://github.com/Norbyte/bg3se>.
- **Mod Configuration Menu (BG3MCM)** — **a hard requirement, enforced at runtime.** Developed and tested against MCM v1.40.1. It must load **above** MIR. If MCM's pak is not in your load order, MIR builds no pool, rolls on nothing and injects nothing.
- **A mod manager** such as BG3 Mod Manager (BG3MM) — strongly recommended, because MIR must be **active in your load order** for its script to run.
- **Windows.** Script Extender is Windows-only, so MIR is too.

No Python, no sidecar, no external tools. Everything runs in-game. MCM's window is mouse and keyboard.

## The settings

Every change applies live — no restart, no reload. Settings that change *what is in the pool* rebuild it once (debounced); everything else applies to the very next roll. Settings persist **per MCM profile, globally across saves**.

### General

| Setting | Default | What it does |
|---|---|---|
| Enable MIR | On | Master switch. |
| Base spawn chance (%) | 25 | Chance that *anything* spawns at a looting opportunity. |
| Rolls per looting opportunity | 1 | Independent attempts per container or corpse, each at the base chance (0–10). |
| Roll on corpses | On | Roll when a corpse is first looted. |
| Include clutter containers | Off | Also roll on crates, barrels, vases and similar. |
| Clutter containers: consumables only | On | Restrict clutter to potions, arrows and alchemy ingredients — and **admit them, vanilla and modded, into clutter on its own**. Items admitted this way never appear anywhere else. |
| Spawn in wardrobes and closets | On | Wardrobes are their own container type. Your camp wardrobe is never touched. |
| Wardrobes: cosmetic garments | On | Camp clothing, camp shoes and underwear may spawn in wardrobes, **even while Include cosmetics is off**. |
| Wardrobes: garments with stats | On | Body armour, helmets, gloves, boots and cloaks may spawn in wardrobes. |
| Wardrobes: also spawn non-garment items | Off | Adds everything else on top. Untick all three and the wardrobe is unrestricted. |
| Spawn in bookshelves and desks | On | Bookshelves are their own container type. |
| Bookshelves: scrolls | On | Scrolls — vanilla and modded — may spawn in bookshelves, even while Include scrolls is off, and only there. |
| Bookshelves: also spawn all other items | Off | Adds every other category on top. **Untick both bookshelf boxes and bookshelves spawn nothing** — there is no unrestricted fallback. |
| Exclude the Nautiloid | On | Never spawn anything during the prologue. |
| Show item-received notification on spawn | Off | Use the game's item-received toast. Off = the item is simply there in the loot. |

### Pool

| Setting | Default | What it does |
|---|---|---|
| Include base-game items | Off | Let vanilla equipment into the pool. **Expect duplicates if you turn this on** — see the FAQ. |
| Include cosmetics | Off | Camp clothing, camp shoes and underwear, everywhere MIR rolls. |
| Include modded consumables | Off | Modded potions, arrows and ingredients everywhere MIR rolls. Not needed for barrels alone. |
| Include base-game consumables | Off | Vanilla potions, arrows and ingredients everywhere MIR rolls. Not needed for barrels alone. |
| Include scrolls | Off | Scrolls everywhere MIR rolls. **One switch for vanilla and modded scrolls together.** Off does not stop bookshelves. |
| Exclude known utility mods | On | The curated utility fence. Recommended on. |
| Exclude items their mod already places in the world | On | The placement filter: modded equipment a mod puts on a specific NPC or in a specific world container stays out of the pool. Merchant stock and camp/tutorial chests do not count. |

### Rarity

Off by default — every rarity can spawn everywhere. Turn on **Limit rarity by level and Act** and you set a lowest and highest rarity for four character-level bands (1–5, 6–10, 11–15, 16–20+) and for each Act. **The most restrictive of the two rules wins**: the higher minimum and the lower maximum. If a band and an Act do not overlap, MIR narrows to one tier and says which two rules disagreed in the log.

**Alchemy ingredients ignore the window.** The game gives none of them a rarity, so they would all vanish under one. **Any other item whose mod declares no rarity is filed as Common** — most clothing mods declare none — so a minimum above Common removes far more than you might expect. `!mir_rarity` prints how many items actually fall inside the window you set.

### Exclusion lists

Two display-only lists show which utility mods and which NPC-gear mods in your load order are fenced (their checkboxes accept clicks but do nothing — an MCM quirk). Three editable lists hold your own per-mod and per-item exclusions and your "allowed in anyway" overrides, by UUID, as a fallback if the MIR Browser tab is ever unavailable.

### The MIR Browser tab

The place you will actually tune things. Two sections.

**Category shares — the status panel.** Sixteen rows: Weapons, Shields, Body armour, Helmets, Gloves, Boots, Cloaks, Rings, Amulets, Camp clothing, Camp shoes, Underwear, Potions and elixirs, Arrows, Alchemy ingredients, Scrolls. Each has a slider and a status:

- **ON** — the category competes with others in at least one enabled container type. The percentage is its share there, labelled by container where it differs: `ON  30.9% (chests, corpses) | 30.5% (clutter)`.
- **LIMITED** — it can appear, but everywhere it can appear it is the only category allowed (scrolls with bookshelves set to scrolls only). It gets 100% there and the slider is inactive.
- **OFF** — it cannot appear anywhere right now, and the row says why: weight 0, no items in the pool, or which Pool-tab switch to flip.

A category's percentage is its weight over the weights of the categories it competes with *in that container type*, so potions can be 6% of a chest and 33% of a barrel. Nothing is averaged across containers that do not share a pool.

**Exclusion browser.** A search box and a paged list of every mod contributing items. Click a mod to see its items; tick to exclude a mod or an item; untick to put it back. Items the placement filter keeps out are flagged *placed by mod*, with a button to allow them in anyway — and a warning that you may then find two.

## How it works (brief technical overview)

At session load, MIR enumerates every Armor, Weapon and Object stat in your load order and classifies each by the mod that **defines** it — not the last mod to override it, which is how a rebalance mod would otherwise leak a thousand vanilla items into a "modded" pool. On the development machine that is about 12,000 entries in roughly 100 ms. Items are sorted into sixteen categories and five rarities.

MIR then listens for two engine events: a player opening a container, and a player first requesting to loot a corpse. Containers are classified by their internal template name — treasure, wardrobe, bookshelf, clutter, or excluded (camp and tutorial chests) — and each gets a content filter. On a successful roll MIR picks a category by weight among those the container may hold, a rarity inside your window, and an item, and adds it with the engine's own additive "add template to inventory" call. Each container and corpse is stamped so it is rolled only once; one passed over because a toggle was off becomes eligible again if you turn that toggle on.

MIR makes exactly eight engine calls, and only one of them changes anything: the add. There is no code path that removes, replaces, moves or reprices an item, and no vanilla data file ships in the pak.

## Compatibility

**Compatible.**

- Equipment, armour and clothing mods of every kind — they are MIR's raw material.
- Mods that alter vendor stock (MIR does not touch traders) and mods that add containers or corpses.
- **Container Loot Control** (Volitio) and **Randomized Item Framework** (GraphicFade) — analysed at code level rather than playtested together. Both act on their own registered containers or their own item lists and leave MIR's additions alone. **Do not combine Randomized Item Framework with MIR's "Include base-game items"** — that puts both mods on the same items.

**Not compatible — do not run these alongside MIR.**

- **Randomized Equipment Loot** and its family, **Fade's Equipment Distribution AIO's randomizer feature**, and any other mod that randomizes or re-places loot **by rewriting loot data**. MIR's whole premise is that nothing rewrites it; two of these together give compounded spawn rates at best and contradictory loot tables at worst.

**Caveats.**

- **Auto-loot and loot-vacuum mods may bypass MIR.** MIR rolls on the events fired when a player opens a container or first loots a corpse; a mod that empties containers at a distance may not fire them. First thing to check if you never see spawns.
- **Remote container access** (remote camp-chest commands and the like) bypasses MIR entirely, by design.
- **Quest mods.** Items placed on a specific NPC or in a specific world container are kept out by default, but items a quest mod spawns from its own script cannot be detected. Exclude such a mod by hand if you want certainty.
- **Multiplayer.** MIR is server-authoritative and **the host manages the settings**. Any player can browse the pool; exclusion writes from non-host players are refused with a message saying so.

## Known limitations

- **MCM is mandatory.** There is no defaults-only mode. The in-game notice is a Script Extender window, so where Script Extender's UI layer is broken the only notice is the banner in `MIR_log.txt`.
- **The placement filter removes a large share of a cosmetics-heavy pool.** On a 1,478-mod load order it excluded 5,064 items and left 2,451 — almost all clothing mods that ship their whole catalogue in a backpack, which is the filter working as intended. `!mir_tables` shows your own numbers; `!mir_placed_mods` names the mods responsible; switch it off if it takes out more than you want.
- **Late-game rate decline.** Equipment never repeats, so categories empty as a playthrough goes on. Expected; add more mods or raise the base chance.
- **Reloading re-rolls.** No deterministic seed: reload a save from before a container was opened and it rolls again.
- **Container classification is by name.** Shields are detected by the offhand slot (a mod's offhand weapon can be labelled a shield); apothecary and tailor desks count as desks; one wine rack is shaped like a scroll shelf. Modded scroll detection is a heuristic — a modded scroll that follows none of the vanilla conventions stays out of the pool.
- **Containers you already looted before installing** are unrolled as far as MIR is concerned, so the next time you open one it rolls. Expected.
- **MCM's read-only exclusion views accept clicks** (clicking does nothing), and MCM's list widgets may need a tab reopen to show exclusions written from the browser. MCM quirks, not MIR's.
- **Windows only**, and MCM's configuration window is mouse and keyboard.

## FAQ

**Q: Nothing ever spawns.**
A: Run `!mir_status` in the Script Extender console (type `server` first). If the MCM field reads `MISSING - MIR DORMANT`, MCM is not in your load order and MIR has switched itself off. Otherwise look for `enabled=true`, `catalogBuilt=true` and a non-zero `chance`, then `!mir_pool` — an empty pool means your filters exclude everything you have. Remember the defaults: modded equipment only, with cosmetics and consumables off, and one roll at 25%. A quiet session is not by itself evidence of a problem.

**Q: Will MIR give me the same item twice?**
A: Not equipment. **What MIR guarantees: equipment never spawns twice in the same save.** When MIR gives you a weapon, armour piece, ring, amulet or cosmetic garment, it removes that item's template from the live pool and records it in a per-save ledger stored in the savegame's mod variables. Every time the save loads, the ledger is read back and every recorded item is removed from the pool again. So across an entire playthrough, no piece of equipment is handed out a second time by MIR. Consumables (potions, arrows, ingredients, scrolls) are deliberately exempt and can repeat. Two limits: MIR only controls its own spawns, not the game's or another mod's (see the next question), and a reload re-rolls — if you load a save from before a container was opened, that container rolls again, because the earlier attempt's ledger entry went with the discarded save state.

**Q: I got the same item twice.**
A: With **Include base-game items** on, that is expected: the game places vanilla items by hand, on level data MIR cannot see, so it cannot know an item is already waiting for you. That is why the setting defaults to off. Modded items are different — MIR *can* see when a mod places its own item and keeps those out by default; `!mir_placed_mods` names the mods that place their own items, which are the only ones you could ever get twice.

**Q: A category reads OFF or LIMITED and I did not switch it off.**
A: The status is derived, not stored — read the reason on the row. OFF with `weight 0` means the slider is at zero. OFF naming a Pool-tab switch means no enabled container admits the category. LIMITED means the category is the only thing allowed wherever it can appear, so its share is 100% there and the slider is deliberately inactive.

**Q: Arrows and ingredients show up in barrels but never in chests.**
A: By design. With the Pool tab's consumable settings off, consumables reach clutter only through the clutter setting, and those are scoped to clutter. Turn on **Include base-game consumables** or **Include modded consumables** if you want them everywhere.

**Q: I only ever see items from one or two mods.**
A: The pool is proportional to how many eligible items each mod contributes, and a single large clothing pack can contribute hundreds. `!mir_mods` writes a per-mod breakdown; exclude the pack in the MIR Browser, or lower the categories it dominates.

**Q: Does it change vanilla loot?**
A: No. MIR only ever adds. Vanilla loot is exactly what it always was, and no vanilla data file ships in the pak.

**Q: Is it safe to remove mid-playthrough?**
A: Yes. Items MIR already gave you are ordinary items from mods you still have; they stay where they are. MIR's bookkeeping in the save becomes inert. Your settings remain in MCM's profile folder in case you reinstall.

**Q: Can I install it mid-playthrough?**
A: Yes. MIR only sees containers and corpses you interact with after it is installed.

**Q: Does it work with a controller?**
A: Gameplay is unaffected either way, but MCM's window — and therefore all of MIR's configuration — is mouse and keyboard.

**Q: Where are my settings?**
A: `%LocalAppData%\Larian Studios\Baldur's Gate 3\Script Extender\BG3MCM\Profiles\<profile>\MIR\settings.json`. Per MCM profile, global across saves; nothing is written into a savegame.

## Console reference

All commands are **server** commands: in the Script Extender console type `server`, then the command with a `!` prefix.

| Command | What it does |
|---|---|
| `!mir_status` | State dump: enabled, level, catalogue built, rolls, chance, MCM state, ledger size, every container gate and the whole Pool tab. |
| `!mir_pool` | Per-category counts of the eligible pool, flagging items drawable in clutter or bookshelves only. |
| `!mir_share <category> <0-100>` / `!mir_share list` | Set a category weight, or list every category's weight and status. Takes the console token (`weapon`, `torso`, `vanityClothing`, `scroll`, …); `list` prints them. |
| `!mir_exclude mod\|item <uuid>` / `!mir_include mod\|item <uuid>` / `!mir_excludes` | Exclude, un-exclude, list. `!mir_exclude clear` wipes all your exclusions. |
| `!mir_forceinclude <uuid>` / `remove <uuid>` / `list` / `clear` | Let one placement-fenced item back into the pool, accepting a possible duplicate. |
| `!mir_rarity` / `on\|off` / `level <n> <min> <max>` / `act <n> <min> <max>` | Report or set the rarity window; counts the pool inside it and the exempt ingredients. |
| `!mir_clutter on\|off\|consumables\|all` | The clutter switch and its content filter. |
| `!mir_wardrobes on\|off` | The wardrobe switch, printing what a wardrobe may spawn. |
| `!mir_bookshelves on\|off` / `scrolls on\|off` / `all on\|off` | The bookshelf switch and its two content filters. |
| `!mir_scrolls on\|off` | The pool-wide scroll switch. |
| `!mir_consumables on\|off` / `base on\|off` | Modded / base-game consumables everywhere. |
| `!mir_util on\|off` / `!mir_placed on\|off` | The utility fence and the placement filter. |
| `!mir_enable on\|off` / `!mir_chance <0-100>` / `!mir_rolls <0-10>` / `!mir_dry on\|off` | Master switch, base chance, rolls, and dry run (classify and log every container, inject nothing). |
| `!mir_mods` / `!mir_placed_mods` / `!mir_tables` | Write reports to your Script Extender folder: per-mod pool breakdown; mods that place their own items; the placement-filter scan. |
| `!mir_ledger` / `!mir_rebuild` / `!mir_mcm_sync` / `!mir_flush` | Dump the no-duplicate ledger; rebuild the pool; re-read every MCM value; flush the log. |

Most console changes are session-only and are replaced by the MCM values on any full re-sync. **`!mir_share`, `!mir_exclude`, `!mir_include` and `!mir_forceinclude` write through MCM and persist.** Eight settings have no console command at all — roll on corpses, exclude the Nautiloid, the notification, include base-game items, include cosmetics, and the three wardrobe content filters — and are reachable only through MCM.

MIR writes `MIR_log.txt` to your Script Extender folder, appending across sessions.

## Credits

- **Author:** Serpentine (NexusMods: SerpentineShel)
- **BG3 Script Extender:** [Norbyte](https://github.com/Norbyte/bg3se) — MIR is entirely built on it.
- **Mod Configuration Menu:** AtilioA and contributors — the entire configuration surface.
- **Larian Studios** — for the loot system MIR politely leans on.
- **Testing and feedback:** the BG3 modding community, and the authors of the equipment mods that make MIR worth running.

## AI use disclosure

MIR was developed with substantial assistance from an AI coding assistant (Claude, by Anthropic), used for code authoring (Script Extender Lua and the MCM blueprint), research, and this documentation. The mod contains **no AI-generated art, images, audio, or other media** — only code and text. All design decisions, in-game testing, and the final release were done by the author.

## Source code

MIR is open source. The full source — Script Extender Lua, the MCM blueprint, build scripts, and these documents — lives on GitHub:

<https://github.com/Shiney1965/BG3-Modded-Item-Randomizer>

The Lua and the blueprint also ship as plain text inside `MIR.pak`, so the complete source is in every download.

## License

MIT. See `LICENSE`. MIR bundles no third-party files; its dependencies are listed in `LICENSE-THIRD-PARTY.md`.

## Reporting issues

Drop a comment on the NexusMods listing, or open an issue on the [GitHub repository](https://github.com/Shiney1965/BG3-Modded-Item-Randomizer). When reporting, please include:

- Your BG3, Script Extender and MCM versions.
- The relevant part of `MIR_log.txt` from your Script Extender folder.
- The output of `!mir_status` and `!mir_pool`.
- Any other loot, container or randomizer mods in your load order.
