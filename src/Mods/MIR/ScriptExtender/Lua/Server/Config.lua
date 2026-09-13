-- MIR Phase 2 hardcoded configuration.
-- Every value here becomes an MCM setting in Phase 3. Defaults per Alan's matrix
-- (RESEARCH_AND_PLAN.md §5.2 #6): modded-only, cosmetics/consumables excluded,
-- rolls=1, Nautiloid excluded, traders excluded, rarity window inactive.
MIR = MIR or {}

MIR.Config = {
    enabled = true,
    powerEnabled = true,
    suppressConvenience = true,
    gateMerchants = true,
    convenienceContainers = {}, -- exact instance/template UUID -> true, for delivery chests

    powerStrictUnknown = false,
    powerOverrides = {}, -- keyed by template UUID (preferred) or stat name; see docs/POWER.md

    dryRun = false,   -- classify + log, but never inject (!mir_dry on|off)

    -- Roll model: per looting opportunity, `rolls` independent attempts, each
    -- succeeding at `baseChancePct` percent. 25 = the SHIP default (Alan,
    -- 2026-08-20, design §2.6); raise via !mir_chance for spawn-data sessions.
    rolls = 1,
    baseChancePct = 25,

    -- Pool composition (defaults matrix)
    includeBaseGame = false,        -- vanilla items never enter the pool
    includeCosmetics = false,       -- VanityBody / VanityBoots / Underwear categories
    includeConsumablesModded = false,
    includeConsumablesBase = false,
    -- v1.0: scrolls are their own category and NOT part of the consumable toggles above.
    -- ONE switch, no base/modded split, deliberately: it was designed when the draw-time gate
    -- was per-CATEGORY (v1.0.1 added per-entry scoping), and one switch is simply clearer.
    -- ON = every scroll in the load order (vanilla AND modded) is pool-wide. OFF = scrolls
    -- still enter the catalogue when bookshelves ask for them, drawable in bookshelves only.
    includeScrolls = false,
    excludeUtilityMods = true,      -- fence out MIR.UtilityMods (Alan 2026-08-19, default YES; MCM toggle in Phase 3)
    -- Plan §5.1 #13: items a mod already distributes through its OWN treasure
    -- tables are authored placements (reward chests, specific world containers,
    -- merchant stock). Default YES so MIR never duplicates an authored drop.
    -- Detection is treasure-table-only; script/level-instance placements are
    -- undetectable at runtime and still need a manual browser exclude.
    excludeTreasureTableItems = true,

    -- Targets
    excludeNautiloid = true,        -- no injection while on TUT_Avernus_C
    notifySpawns = false,           -- item-received toast on inject (TemplateAddTo 4th param)
    includeCorpses = true,          -- RequestCanLoot hook (visibility pending Phase 0 close-out)
    includeClutterContainers = false, -- "treasure containers only" (Alan, §5 Q2)
    -- v0.8 (Alan): clutter is vases/barrels/crates. Restricting it to consumables stops
    -- barrels handing out greatswords. Since v0.9 this setting ALSO admits consumables to
    -- the catalogue for clutter alone (Catalog.lua Object branch; vanilla AND modded since
    -- v1.0.1, kept out of every other container by the per-entry scope) - MIR no longer
    -- touches the Pool toggles for you.
    clutterConsumablesOnly = true,
    -- v0.8 wardrobes: their own container class and content filter. The three content
    -- flags are ADDITIVE and ALL-OFF MEANS UNRESTRICTED (Alan 2026-08-25).
    includeWardrobes = true,
    wardrobeCosmetics = true,      -- vanityClothing / vanityBoots / underwear
    wardrobeStatGarments = true,   -- torso / helmet / gloves / boots / cloak
    wardrobeAllItems = false,      -- ADDS the non-garment categories on top
    -- v1.0 bookshelves: bookcases, book rows/stacks/piles, scroll shelves and desks. Their own
    -- class so they can be switched separately and filled with scrolls rather than arrows.
    -- UNLIKE wardrobes, both content flags off means the class contributes NOTHING (the
    -- wardrobe "all-off = unrestricted" rule would hand out greatswords to a user who
    -- unticked scrolls to stop scrolls - v1.0 plan review BL-1).
    includeBookshelves = true,
    bookshelfScrolls = true,       -- admits scrolls (vanilla and modded) for bookshelves LOCALLY,
                                   -- even while includeScrolls is off
    bookshelfAllItems = false,     -- ADDS every other category on top

    -- Traders: NOT implemented in Phase 2 at all (and default-excluded by §5.2 #6)

    -- Category weights (relative likelihood; a weight's share of the summed
    -- enabled weights IS its normalized probability). 50 = the MCM slider
    -- default (design §2 — slider value maps 1:1 onto these weights).
    -- Categories with weight 0 never spawn. Cosmetic categories are
    -- additionally gated by includeCosmetics.
    categoryWeights = {
        helmet = 50, gloves = 50, torso = 50, boots = 50, cloak = 50,
        ring = 50, amulet = 50, weapon = 50, shield = 50,
        vanityClothing = 50, vanityBoots = 50, underwear = 50,
        potion = 50, arrow = 50, alchemyIngredient = 50,
        scroll = 50, -- v1.0: sixteenth category
    },

    -- v1.0: the per-category include table (`categoryIncluded`, the browser checkbox) is
    -- GONE. It was the first test in categoryEnabled, so unticking a category vetoed it
    -- everywhere - including containers that admitted it locally - and that is exactly
    -- what silenced Alan's clutter consumables (all three had been unticked, almost
    -- certainly collateral from the v0.8.1 slider bug). Weight 0 is now the only
    -- browser-side "off"; the panel shows a DERIVED on/off/limited status instead.
    -- Do not reintroduce a global veto here.

    -- Rarity window system (§5.1): INACTIVE by default = all rarities equal.
    rarityWindow = {
        enabled = false,
        -- Per-level-band AND per-Act min/max tiers (1=Common .. 5=Legendary).
        -- MERGE RULE (Alan, 2026-08-30): MOST RESTRICTIVE WINS -
        --   min = max(levelMin, actMin)   max = MIN(levelMax, actMax)
        -- This SUPERSEDES the 2026-08-08 spec in RESEARCH_AND_PLAN.md:213, which said
        -- 'highest minimum and highest MAXIMUM'. Under that rule every MAX setting was
        -- INERT at the 1..5 defaults: max(5, actMax) is always 5, so a user had to lower
        -- BOTH the band and the Act to restrict anything. Do not 'restore' the old line.
        -- CONSEQUENCE: intersection CAN produce an empty window (band 4-5 vs Act 1-2),
        -- which the old rule provably could not. effectiveRarityWindow MUST clamp.
        --
        -- The bands are FIXED because MCM settings are flat - there is no way to render
        -- an editable list of arbitrary rules.
        -- FOUR BANDS COVERING 1-20 (Alan, 2026-08-30: he runs a level-cap extender to 20,
        -- so 1-12 would have left him permanently in no band at all). The top band is
        -- stored as 16-99 while the UI calls it '16-20+': above the cap no band would
        -- match, the level rule would vanish, and only the Act rule would apply - which is
        -- exactly review BL-3, and Alan IS the affected population.
        levelRules = {
            { minLevel = 1,  maxLevel = 5,  minTier = 1, maxTier = 5 },
            { minLevel = 6,  maxLevel = 10, minTier = 1, maxTier = 5 },
            { minLevel = 11, maxLevel = 15, minTier = 1, maxTier = 5 },
            { minLevel = 16, maxLevel = 99, minTier = 1, maxTier = 5 },
        },
        actRules   = { [1] = { minTier = 1, maxTier = 5 }, [2] = { minTier = 1, maxTier = 5 }, [3] = { minTier = 1, maxTier = 5 } },
    },


    -- Container-tier classifier (Phase 0 decision: template-NAME patterns).
    -- Matched as plain substrings against BOTH the root-template name and the
    -- instance name. Case-sensitive (engine names are consistently cased).
    treasurePatterns = { "Chest", "Strongbox", "Coffer", "Sarcoph", "Tomb", "Casket", "Vault", "Lockbox", "Stash" },
    -- Hard target exclusions (§5.2 #4: tutorial + camp chests are hands-off).
    -- Verified against real names during the Phase 2 test session (checklist item).
    -- v0.8: Wardrobe_Player is the player's CAMP wardrobe - same rule as the camp chest
    -- (player-convenience storage, and where cosmetic mods auto-insert camp outfits).
    -- It MUST be tested before the wardrobe class or it would be captured by it.
    excludePatterns = { "CampChest", "Chest_Camp", "CONT_Camp", "Tutorial", "TUT_Chest", "TravellersChest", "TravelersChest", "Wardrobe_Player" },

    -- v0.8 wardrobe class. Case-SENSITIVE substring match, same as the other pattern
    -- lists, so a modded "closet_x" will NOT match - accepted and documented.
    -- "Cabinet" is deliberately NOT here (FUR_GEN_Desk_Cabinet_A is a desk, and cabinets
    -- hold crockery as often as clothes); nor is "Drawers" (only FUR_Printshop_Drawers_*).
    wardrobePatterns = { "Wardrobe", "Closet" },

    -- v1.0 bookshelf class. Verified against the vanilla root-template extract (2026-09-01):
    -- BOOK_GEN_Books_Row_*/Stack_*/Pile_A, CONT_GEN_Books_Stack_*, FUR_GEN_Bookcase_* and
    -- Bookshelf_*, FUR_Druids/Temple/Dungeon_SharTemple_Bookcase_*, DEC_GEN_Bookcase_Bottle_A,
    -- FUR_GEN_ScrollShelf_* / CONT_GEN_ScrollShelf_*, and the desk families (FUR_GEN_Desk_*,
    -- FUR_Temple_Scribe_Desk_*, DEC_GEN_Office_Desk_*, DEC_GEN_Apothecary_Desk_A ...).
    -- "BOOK_" also prefixes hundreds of book/letter/parchment ITEM templates - harmless,
    -- because classifyContainer only ever sees something that passed Osi.IsContainer.
    -- "Desk" is deliberate (Alan asked for desks) even though it turns the apothecary and
    -- tailor desks into bookshelves; "ScrollShelf" also catches CONT_GEN_ScrollShelf_Wine_Bottle_A
    -- (a wine rack shaped like a scroll shelf). Both documented as known name-match quirks.
    -- DEC_GEN_Necromancer_Shelf_Chest_A matches none of these and stays a treasure chest.
    bookshelfPatterns = { "BOOK_", "Bookcase", "Bookshelf", "Books_Stack", "Books_Pile", "ScrollShelf", "Desk" },

    -- Per-mod / per-item excludes (Phase 3 gets the MCM browser; Phase 2 = hardcoded lists)
    excludedModUuids = {},          -- [uuid] = true
    excludedTemplates = {},         -- [rootTemplateUuid] = true
    -- v0.7: items the user has deliberately let INTO the pool even though their own mod
    -- already places them in the world. The opposite of an exclusion: it defeats the
    -- placement fence for one item. A duplicate becomes possible, which is the point -
    -- the browser warns at the moment of the choice. User EXCLUSION still outranks this.
    forceIncludedTemplates = {},    -- [rootTemplateUuid] = true
}

-- Larian base modules by exact Name (validated against the 2026-08-14 catalog report:
-- Shared, SharedDev, Gustav, GustavDev observed as OriginalModId sources; the rest are
-- known Larian module names included defensively).
MIR.BaseModuleNames = {
    Gustav = true, GustavDev = true, GustavX = true, Shared = true, SharedDev = true,
    Honour = true, ModBrowser = true, MainUI = true, DiceSet_01 = true, DiceSet_02 = true,
    DiceSet_03 = true, DiceSet_04 = true, DiceSet_06 = true,
}

MIR.RarityOrder = { Common = 1, Uncommon = 2, Rare = 3, VeryRare = 4, Legendary = 5 }
MIR.TierName = { "Common", "Uncommon", "Rare", "VeryRare", "Legendary" }

-- ============================================================================
-- Curated utility-mod exclusion list (gated by Config.excludeUtilityMods).
-- These are mods whose PURPOSE is utility — photo/pose tools, cheat/spawn
-- tools, tutorial-chest summoners, QoL storage, frameworks/libraries — so any
-- items they define (photo rings, expression mirrors, summonable chests,
-- framework template stats) must never appear as random loot. Trigger case:
-- the first live MIR spawn was LOW_PhotoRing_Ring, a photo-mode utility ring
-- defined by PhotographyRing (verified by pak extract, 2026-08-20).
--
-- byUuid  = mod UUIDs (global across users; every entry verified from Alan's
--           modsettings.lsx or a meta.lsx extracted from the pak — none guessed).
-- byName  = exact-but-TRIMMED Ext.Mod Info.Name strings, DISTINCTIVE names only
--           (belt-and-suspenders for authors who regenerate UUIDs between
--           versions; generic names like "Console Commands" are deliberately
--           absent so another user's same-named CONTENT mod can't be fenced).
-- Content/equipment packs (BasketEquipment*, clothing packs...) stay IN the
-- pool by design — they are what MIR exists to distribute. Per-mod excludes
-- for those arrive with the Phase 3 MCM browser. Pose PACKS (animation-only)
-- are not listed; if one leaks items, !mir_mods will surface it.
-- ============================================================================
MIR.UtilityMods = {
    byUuid = {
        -- Photo mode / posing tools
        ["735c0fc0-7931-c48a-a6d6-a4f8c072aeae"] = true, -- PhotographyRing (VERIFIED: defines LOW_PhotoRing_Ring)
        ["19a0e800-7080-b396-7732-cc80740d441a"] = true, -- UnlimitedPhotoMode
        ["07a42bde-6934-b4de-d2b3-f8427c33f845"] = true, -- Photobooth
        ["147e3190-6753-eb33-afac-5f8b84bed381"] = true, -- LittleMirrorofExpressions2
        ["70e3afee-2d2a-eec5-931f-06f6ac0ca9f5"] = true, -- LittleMirrorofExpressions_Vol3
        ["3779a4fb-0c2c-404a-beee-879d97eb9e87"] = true, -- Origin Mirror Unlock
        ["34f343b7-7e9f-6446-1ecc-d1f3ca5ef0d0"] = true, -- Creature Photomode Fix
        ["1d9601b7-8310-47b6-855f-5c7dc6545d4c"] = true, -- PhotoModePoses
        ["b89c0578-e78d-7745-a58d-27235a68995d"] = true, -- Domain Expansion: Poses for Photo Mode
        ["25fe41cc-68bb-a75c-e71f-5d56f8b793a3"] = true, -- P4 Photomode Additions
        ["37390e1b-98e5-540f-2f22-fc6d27ac84e2"] = true, -- Additional_Photomode_Expressions
        ["e35b62f4-2d5d-58b4-2e05-05c706c19910"] = true, -- Claravel's Emotes For Photo Mode
        ["63c33dd8-30ee-0c0a-6bcc-d6e6407d6867"] = true, -- Compendium Of Poses
        ["6d80ba29-ea49-462c-a97d-2b0f5e84c20b"] = true, -- Extra Camera Mode Poses and Animations + Dragon poses
        ["1ef157e7-d6d5-0c32-8d21-345793f65ed3"] = true, -- Kith'rak Photoshoot
        ["92416381-0325-5413-556b-9077f00d738f"] = true, -- Portrait Poses for Photo Mode
        ["5e0b951c-b483-906d-013e-01697210514b"] = true, -- Get a Room - Photomode Animations
        ["534d411f-05e5-6e32-08d7-412f32177273"] = true, -- Get a Room and The Urge to Pose - Patch
        ["6988b52d-461c-af98-8203-95e1fd08141a"] = true, -- Cuddle Astarion - Photo Mode Add-on
        ["019e8a3a-15ad-73af-9ee6-204b7a74a692"] = true, -- UniversalPosePatcher
        ["a5a10678-d1a3-fc3a-2396-79fef5335b15"] = true, -- One Patch To Pose Them All
        ["17b21d55-5d5c-92ad-e002-a40d5d52afe3"] = true, -- FF Mega Pack - Patch (pose patch)

        -- Cheat / spawner / tutorial-chest
        ["5b5ad5b6-ce37-4a63-8dea-a1fee4cee156"] = true, -- EasyCheat
        ["8ec86e0e-3b6b-4d7a-b62f-821c4f1c4bd5"] = true, -- Ultimate Cheat Spell Collection
        ["210daf61-48c2-4b4b-a1e0-5a2e022a8106"] = true, -- SpawnTutorialChest
        ["8b8624ed-6b98-781b-659f-7e8be5ef5856"] = true, -- Summon Tutorial Chest
        ["505c630c-79fa-49b6-9f21-29a5f2322c2d"] = true, -- TutorialChestSummoning
        ["d7d810fc-0e7a-7340-c7b6-476e564db016"] = true, -- Tutorial Chest Summoner (portable)
        ["84ecbc58-b82a-0f4c-34c2-be845ad4590b"] = true, -- Easy Toggle Tutorial Chest
        ["e8124590-187b-4ef0-9386-372097ad749e"] = true, -- Ultimate Cut Content Tutorial Chest Add-On
        ["0baffcc2-c931-4af6-9724-178895255416"] = true, -- Spineful - Tutorial Chest Addon
        ["3fe1bccd-53b2-460e-ab69-c8f7a8da729c"] = true, -- Console Commands
        ["dcf86ff3-0d21-d025-f451-e2fa7e86cefd"] = true, -- ShadMirrorBuff
        ["aca84364-60e0-515e-a536-8e4434db4e1e"] = true, -- RFB Purge (save cleaner)

        -- QoL storage / tools
        ["2be20ac0-d3b5-b67e-2847-882b7bfd85e7"] = true, -- Travelers_Backpacks
        ["70ae5d0c-162d-4f1f-e5f1-4b812201d5fd"] = true, -- AseCatBackpack
        ["82c1f53b-5ed3-4e2e-95f5-f84ca6ff0c81"] = true, -- Transmog Enhanced Revamped
        ["642035f0-6390-43fa-afb7-2409628b3cc4"] = true, -- Hide Appearance Ring (utility ring, same class as PhotoRing)

        -- Frameworks / libraries
        ["396c5966-09b0-40a1-af3f-93a5e9ce71c0"] = true, -- CommunityLibrary (VERIFIED: 532 W + 9 A + 20 O framework stats)
        ["755a8a72-407f-4f0d-9a33-274ac0f0b53d"] = true, -- Mod Configuration Menu (MCM)
        ["26922ba9-6018-5252-075d-7ff2ba6ed879"] = true, -- ImpUI_P8_Fork
        ["67fbbd53-7c7d-4cfa-9409-6d737b4d92a9"] = true, -- CompatibilityFramework
        ["f97b43be-7398-4ea5-8fe2-be7eb3d4b5ca"] = true, -- VolitionCabinet
        ["5d1bd6cb-6361-45ef-b20c-d997acfba822"] = true, -- AahzLib
        ["e6333436-9cf0-4464-aaf2-39246292575e"] = true, -- AV Item Shipment Framework
        ["65e55feb-aada-4fec-821f-7d913e9b4d82"] = true, -- DART (Dialogue and Reactivity Tags) Framework
        ["896aa172-c026-9e72-7c91-9d67e17595e6"] = true, -- Kay's Material Library
        ["2da3bc36-b4b2-4652-a611-3fe16527417e"] = true, -- UtutsCoreLibrary
        ["90f3a982-58bb-4b8c-aa19-73ec4322a00a"] = true, -- CBR_MOXI_Scene_Library
        ["a6f2fef6-5c49-b37b-8145-b84672e2d734"] = true, -- NF_GaleModsCore

        -- Judgment calls CONFIRMED as default exclusions by Alan 2026-08-20
        -- (items arguably loot-worthy, but their purpose is utility/delivery).
        -- The two [Aza] Better Starting Gear mods moved to MIR.NpcGearMods (hard fence).
        ["3c0d5efc-3e23-3ecb-89f8-c5678ebd26db"] = true, -- Bag Of Holding
        ["08aaab4b-03b9-5dc1-bbc7-cdd80ff2084e"] = true, -- Aardi's Chest of Presents
        ["d52251d7-183f-8542-d185-b07c2647470a"] = true, -- Merchant's Chest
    },
    -- Distinctive names only; compared against the TRIMMED runtime Info.Name.
    byName = {
        ["PhotographyRing"] = true,
        ["UnlimitedPhotoMode"] = true,
        ["LittleMirrorofExpressions2"] = true,
        ["LittleMirrorofExpressions_Vol3"] = true,
        ["Origin Mirror Unlock"] = true,
        ["Creature Photomode Fix"] = true,
        ["PhotoModePoses"] = true,
        ["UniversalPosePatcher"] = true,
        ["ShadMirrorBuff"] = true,
        ["EasyCheat"] = true,
        ["Ultimate Cheat Spell Collection"] = true,
        ["SpawnTutorialChest"] = true,
        ["TutorialChestSummoning"] = true,
        ["Tutorial Chest Summoner"] = true,
        ["Easy Toggle Tutorial Chest"] = true,
        ["Ultimate Cut Content Tutorial Chest Add-On"] = true,
        ["Travelers_Backpacks"] = true,
        ["AseCatBackpack"] = true,
        ["Transmog Enhanced Revamped"] = true,
        ["Hide Appearance Ring"] = true,
        ["CommunityLibrary"] = true,
        ["Mod Configuration Menu"] = true,
        ["ImpUI_P8_Fork"] = true,
        ["CompatibilityFramework"] = true,
        ["VolitionCabinet"] = true,
        ["AahzLib"] = true,
        ["AV Item Shipment Framework"] = true,
        ["DART (Dialogue and Reactivity Tags) Framework"] = true,
        ["Kay's Material Library"] = true,
        ["UtutsCoreLibrary"] = true,
        ["CBR_MOXI_Scene_Library"] = true,
        ["NF_GaleModsCore"] = true,
    },
}

-- ============================================================================
-- NPC / character-upgrade gear — HARD-EXCLUDED, NO TOGGLE (Alan 2026-08-20):
-- "That gear should be used in the game with the intended character."
-- Mods whose items exist to equip a specific NPC, companion, or origin
-- character (starting-gear upgrades, NPC redesigns/evolutions, join-the-party
-- companion mods). Unlike MIR.UtilityMods this fence is unconditional — it is
-- NOT controlled by Config.excludeUtilityMods, !mir_util, or any future MCM
-- checkbox, and MUST be documented in the NexusMods description.
-- Player-wearable THEMED packs (character-inspired outfits for Tav) stay in
-- the pool. UUIDs verified from the 2026-08-20 MIR_Mods_Report (runtime
-- attribution) or Alan's modsettings.lsx. No byName fallback here by choice:
-- a UUID-regenerating update would silently unfence (a !mir_mods run surfaces
-- any leak; revisit if that ever happens).
-- ============================================================================
MIR.NpcGearMods = {
    byUuid = {
        -- Companion starting-gear / looks upgrades
        ["08eb0e2d-2496-4175-b0f1-253d47830a37"] = true, -- Astarion's Alternative Starting Armor (Replacer)
        ["88472061-89a9-43b7-91d6-651e6005f738"] = true, -- CBR_Astarion_Gear
        ["acf0df32-63d7-5b2a-7e9e-dae980f73182"] = true, -- HT_EA_AstarionsArmor_NonReplacer
        ["fd3d6825-2133-4cfe-b3db-6f76caefe590"] = true, -- Astarions Lavish Outfit
        ["d2c6c87f-bf98-4117-880b-c80b9ad2ce48"] = true, -- Gale's Keyart Armour
        ["0ff32c37-1619-ffdd-df3c-9eda4583a1bd"] = true, -- Lae'zel's New Look
        ["46b87672-a8a8-bc9f-93fa-44fe66d608f9"] = true, -- Minsc's New Look
        ["ed609af6-c2f2-2d3c-2c7c-ef50b3020dd0"] = true, -- [wasabi] New Gears - Wyll
        ["edec7b9d-0063-1df6-7b30-d1d4b9a0adc3"] = true, -- [Aza] Better Starting Gear: Shadowheart
        ["32378f72-9a6a-9601-7481-c2117ba648d2"] = true, -- [Aza] Better Starting Gear (Gale) + Tutorial Chest
        ["b637575e-1188-a203-7645-8dfbaf610f07"] = true, -- [Aza] Better Starting Gear (Lae'zel) + Tutorial Chest
        ["015ec171-e4bd-aa07-4805-b17ead2aae1f"] = true, -- BrandedMinthara
        ["48a805c2-160a-4e93-b72e-18e98a443c6b"] = true, -- P4 Unique Companion Equipment
        -- NPC redesigns / evolutions
        ["67933c1b-4a1c-8c30-74c7-03638ceb5d65"] = true, -- Sazza Evolved
        ["cb93bf8a-cebc-cd54-7705-01d531e2341b"] = true, -- Bernard Evolved
        ["c56b9bae-fddc-083d-0862-95d73646c304"] = true, -- Shovel Evolved
        ["b5efc83b-23e6-2e98-f692-db616585dfb9"] = true, -- IsobelBetterStats
        ["840d9bea-53fd-4a8e-995e-1a75a5135077"] = true, -- NPC Revamp - Tieflings (Alfira JtP Patch)
        ["ab2692a7-11aa-55ff-7f99-5f2edf6333da"] = true, -- [Aza] NPC Redesign: The Emerald Grove (Alfira JtP Patch)
        ["5bfc90ea-d4ef-ee45-38fd-df5583ca0d97"] = true, -- [Aza] NPC Redesign: Vampire Spawns (WIP)
        -- Join-the-party companion mods (their gear belongs to the new companion)
        ["9ef1089a-2941-94e0-99c3-5efebb69f9de"] = true, -- Aylin and Isobel Join the Party
        ["3539eba9-6d77-c53d-1009-b3c77c9cd04c"] = true, -- AlfiraJoinsTheParty
        ["45ee21a6-8e12-4444-bb8c-6060c11753c1"] = true, -- AlfiraJoinsTheDurgesParty
    },
}
