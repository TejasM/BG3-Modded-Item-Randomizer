-- MIR catalog engine (Phase 2): runtime enumeration of modded items.
-- Built once per session at SessionLoaded (~116 ms measured on Alan's 1,478-mod order).
-- Classification rules are the ones VERIFIED by the 2026-08-14 catalog probe:
--   * defining mod = stat.OriginalModId (fallback ModId) — NOT ModId, which names the last overrider
--   * shields are Armor entries with Slot == "Melee Offhand Weapon"
--   * potions/elixirs = InventoryTab "Consumable" + Using-ancestry reaching "_Potion",
--     or ObjectCategory beginning "Potion"
MIR = MIR or {}
MIR.Catalog = { built = false }

local SLOT_TO_CATEGORY = {
    Helmet = "helmet", Gloves = "gloves", Breast = "torso", Boots = "boots",
    Cloak = "cloak", Ring = "ring", Amulet = "amulet",
    VanityBody = "vanityClothing", VanityBoots = "vanityBoots", Underwear = "underwear",
    ["Melee Offhand Weapon"] = "shield",
    -- MusicalInstrument / Horns: deliberately unmapped -> excluded
}

-- Per-mod info, memoized for the session (the mod registry cannot change
-- mid-session, so the cache legitimately survives !mir_rebuild / !mir_util).
-- Failed lookups are cached too: GetMod is deterministic per UUID per session.
local modInfoCache = {}
local EMPTY_INFO = { base = false, name = nil }
local function modInfo(uuid)
    if uuid == nil or uuid == "" then return EMPTY_INFO end
    local cached = modInfoCache[uuid]
    if cached then return cached end
    local info = { base = false, name = nil }
    pcall(function()
        local m = Ext.Mod.GetMod(uuid)
        if m and m.Info then
            local n = tostring(m.Info.Name or "")
            info.name = (n:gsub("^%s+", ""):gsub("%s+$", "")) -- trimmed for byName matching
            if MIR.BaseModuleNames[m.Info.Name] then info.base = true end
        end
    end)
    modInfoCache[uuid] = info
    return info
end

local utilNameOnlyLogged = {} -- one diagnostic line per mod name per session

-- Walk the Using chain (bounded) to detect potion-family Objects.
local function isPotionFamily(stat, statName)
    local oc = ""
    pcall(function() oc = tostring(stat.ObjectCategory or "") end)
    if oc:sub(1, 6) == "Potion" then return true end
    local tab = ""
    pcall(function() tab = tostring(stat.InventoryTab or "") end)
    if tab ~= "Consumable" then return false end
    local cur, depth = stat, 0
    while cur and depth < 8 do
        local using = ""
        pcall(function() using = tostring(cur.Using or "") end)
        if using == "" then return false end
        if using == "_Potion" or using == "_Potion_Of_Resistance" then return true end
        local nxt = nil
        pcall(function() nxt = Ext.Stats.Get(using) end)
        cur, depth = nxt, depth + 1
    end
    return false
end

-- Prefix test with the length COMPUTED from the prefix. A literal length is how the v0.9
-- `sub(1, 8)` against a seven-character prefix made a clamp unreachable; never again.
local function hasPrefix(s, prefix) return s:sub(1, #prefix) == prefix end

-- Walk the Using chain (bounded, same shape as isPotionFamily) to detect the wand family.
local function isWandFamily(stat, statName)
    if statName == "OBJ_Wand" or statName == "_Wand" then return true end
    local cur, depth = stat, 0
    while cur and depth < 8 do
        local using = ""
        pcall(function() using = tostring(cur.Using or "") end)
        if using == "" then return false end
        if using == "_Wand" or using == "OBJ_Wand" then return true end
        local nxt = nil
        pcall(function() nxt = Ext.Stats.Get(using) end)
        cur, depth = nxt, depth + 1
    end
    return false
end

-- Consumable classifier (Phase 3 §2.3). NORMATIVE match order: potion -> arrow
-- -> alchemyIngredient -> scroll; first match wins. Returns a category name or nil.
-- ALCH_Solution_* deliberately NOT an ingredient rule (they are potion-family
-- elixirs or coatings, review S5).
-- v1.0 scrolls, verified against the vanilla extract (2026-09-01): every vanilla scroll stat
-- is OBJ_Scroll_*, inherits `_MagicScroll` which carries ItemUseType "Scroll", and has an
-- ObjectCategory beginning "MagicScroll" (MagicScroll, MagicScroll_2 .. _9, MagicScroll_Necro_3
-- ...). Their ROOT TEMPLATES are LOOT_SCROLL_* - NOT BOOK_GEN_Scroll_*, which is decorative
-- parchment - and the template is not fetched until after classification anyway, so the test
-- is stat-only: name prefix OR category OR ItemUseType, which also covers modded scrolls that
-- follow any one of the three conventions. Seven vanilla scrolls sit in the cut-content
-- category "MagicScroll_ToBeDeleted" (OBJ_Scroll_Aid, _AnimalFriendship ...) and are skipped.
local function consumableCategory(stat, statName)
    if isPotionFamily(stat, statName) then return "potion" end
    local oc, tab = "", ""
    pcall(function() oc = tostring(stat.ObjectCategory or "") end)
    pcall(function() tab = tostring(stat.InventoryTab or "") end)
    if hasPrefix(oc, "Arrow") then return "arrow" end
    if tab == "Consumable" and (hasPrefix(statName, "OBJ_Arrow") or hasPrefix(statName, "ARR_")) then
        return "arrow"
    end
    if oc == "Ingredient" or hasPrefix(statName, "ALCH_Ingredient_") then
        return "alchemyIngredient"
    end
    local byName = hasPrefix(statName, "OBJ_Scroll_") or (oc:find("MagicScroll", 1, true) ~= nil)
    local useType = ""
    pcall(function() useType = tostring(stat.ItemUseType or "") end)
    -- Diff review SF-1: vanilla `_Wand` (and OBJ_Wand / TOOL_Wand_Fireballs under it) ALSO
    -- carries ItemUseType "Scroll". Vanilla wands have no RootTemplate and die later, but a
    -- modded wand inheriting _Wand with a template would have been filed as a scroll -
    -- repeatable, ledger-exempt, and landing in bookshelves. The use-type test therefore
    -- excludes anything whose Using chain reaches the wand family.
    if byName or (useType == "Scroll" and not isWandFamily(stat, statName)) then
        if oc:find("ToBeDeleted", 1, true) then return nil end
        return "scroll"
    end
    return nil
end

function MIR.BuildCatalog()
    -- Treasure-table index: one-shot per session, a no-op on every later rebuild
    -- (see TreasureIndex.lua). Skipped entirely while the toggle is off, so users
    -- who do not want the feature never pay for the scan. Deliberately OUTSIDE the
    -- builtMs window — it logs its own timing line and would otherwise make the
    -- first "Catalog built in N ms" line unreadable.
    if MIR.Config.excludeTreasureTableItems and MIR.EnsureTreasureIndex then
        pcall(function() MIR.EnsureTreasureIndex("catalog") end)
    end
    local t0 = Ext.Utils.MonotonicTime()
    local cfg = MIR.Config
    local pool = {}          -- pool[category][rarityName] = array of entries
    local byTemplate = {}    -- [rootTemplateUuid] = entry (dedupe + ledger removal)
    local userExcluded = {}  -- [rootTemplateUuid] = fully-classified entry the USER
                             -- excluded (kept for the browser's un-exclude path, B2)
    local tableExcluded = {} -- [rootTemplateUuid] = fully-classified entry fenced because
                             -- the item already has a TREASURE-TABLE distribution (§5.1 #13).
                             -- Kept separate from userExcluded so the two exclusion KINDS stay
                             -- distinguishable, and retained (not dropped) so the browser can
                             -- still show the item and say why it is out.
    local stats = { seen = 0, eligible = 0, skippedBase = 0, skippedStory = 0,
                    skippedNoTemplate = 0, skippedNoName = 0, skippedDupe = 0,
                    skippedUnmappedSlot = 0, skippedExcluded = 0, skippedConsumable = 0,
                    skippedTreasureTable = 0, forceIncluded = 0,
                    -- v1.0: Objects that match no consumable/scroll rule. Previously they
                    -- vanished without bumping anything, so "my modded scroll is missing"
                    -- was indistinguishable from "it was never seen".
                    skippedUncategorised = 0,
                    -- v1.0.1: how much of the eligible pool is reserved for one container class
                    scopedClutter = 0, scopedBookshelf = 0,
                    -- these two count raw STAT entries fenced (incl. ones that would have
                    -- failed later filters anyway) — NOT eligible-item impact
                    skippedUtilityStats = 0, skippedNpcGearStats = 0 }

    local function addEntry(statName, category, rarity, tplId, modKey, dispName, consumable, tplName, baseMod, clutterOnly, bookshelfOnly)
        local entry = { stat = statName, template = tplId, category = category,
                        rarity = rarity, mod = modKey, name = dispName, tplName = tplName,
                        consumable = consumable or false, spawned = false,
                        -- review S7: the placement fence and every 'placed by mod' label are
                        -- MODDED-ONLY, but consumers outside addEntry had no way to tell a
                        -- base-game row from a modded one and mislabelled vanilla items as
                        -- "placed by mod" whenever includeBaseGame was on. Store it.
                        base = baseMod or false,
                        -- v0.9: admitted only because clutter asked for it (see the Object
                        -- branch). v1.0.1: LOAD-BEARING - Main.lua entryAllowedFor makes such
                        -- an entry drawable for clutter and nowhere else, which is what lets
                        -- clutter admit VANILLA consumables without leaking into chests.
                        -- Also reported by !mir_pool.
                        clutterOnly = clutterOnly or false,
                        -- v1.0: the same shape for scrolls admitted only because bookshelves
                        -- asked (includeScrolls off). Drawable in bookshelves and nowhere else.
                        bookshelfOnly = bookshelfOnly or false }
        entry.power = MIR.Power.Assess(entry)
        -- User exclusion check sits HERE, after full classification (B2): the
        -- entry is retained with all metadata so the browser can un-exclude it.
        -- skippedExcluded therefore counts otherwise-ELIGIBLE entries only.
        -- It is checked FIRST because an explicit user choice outranks the
        -- automatic treasure-table fence (and the browser checkbox must reflect it).
        if MIR.Config.excludedModUuids[modKey] or MIR.Config.excludedTemplates[tplId] then
            entry.excluded = true
            userExcluded[tplId] = entry
            stats.skippedExcluded = stats.skippedExcluded + 1
            return
        end
        -- Treasure-table fence (§5.1 #13, toggle-gated). Also late/post-classification
        -- so the browser gets a fully populated row to display.
        -- the nil check is load-order insurance: a missing TreasureIndex.lua must
        -- degrade to "no fence", never take the whole catalog build down with it.
        -- SCOPE (review B1 + recommendation): MODDED, NON-CONSUMABLE items only.
        --   * base-game items are excluded from the fence. DO NOT REMOVE `not baseMod`
        --     WITHOUT READING THIS. It was removed on 2026-08-24 to try to stop MIR
        --     respawning the Warped Headband of Intellect, and REVERTED the same day
        --     when an adversarial review extracted vanilla data and measured what the
        --     change actually does:
        --       - It does NOT fix the Headband. Vanilla assigns NPC and container loot
        --         on LEVEL INSTANCES, not root templates. The Headband's only vanilla
        --         treasure reference is the table FOR_SchoolOgre_Smart_Corpse, which is
        --         referenced by ZERO root templates (the ogres are level instances in
        --         WLD_Main_A). Ext.Template.GetAllRootTemplates() cannot see it, so the
        --         item is never indexed and never fenced. Only ~6.5% of vanilla treasure
        --         tables are reachable from root templates at all.
        --       - It fences the WRONG items. Measured on vanilla: 66/834 Armor and
        --         20/478 Weapon stats, and they are overwhelmingly MUNDANE generic loot,
        --         because vanilla hangs generic tables off a single archetype template.
        --         The whole martial weapon set (Longsword, Greatsword, Dagger, ...) goes
        --         via Monster_OchreJelly -> T_ST_MartialMeleeWeapons on the single
        --         template Ooze_Jelly_Ochre; plain rings and necklaces via a BIRD'S NEST
        --         (GEN_Nest_Small on CONT_GEN_Nest_Small_A); boots and hats via wardrobe
        --         tables. Exactly ONE authored unique was caught. GENERIC_REF_LIMIT = 5
        --         cannot help: these reference counts are 1, not >5.
        --     If this is ever revisited, the avenue NOT yet tried is
        --     Ext.Template.GetAllLocalTemplates() (server-side; it exists and is where
        --     level-instance Treasures nodes live) — but it is level-scoped, so an index
        --     built from it is partial and would need accumulating as the player travels.
        --     The only mechanism that helps a MID-PLAYTHROUGH install is an
        --     "already in the party's possession" check at spawn time.
        --   * consumables are exempt because MIR deliberately hands them out
        --     repeatedly (the no-duplicate ledger is equipment-only), so "don't give
        --     you a second copy" — the fence's whole rationale — does not apply.
        if MIR.Config.excludeTreasureTableItems and not baseMod and not consumable
           and MIR.HasTreasureDistribution
           and MIR.HasTreasureDistribution(statName, tplName) then
            entry.placed = true
            -- Cache the placement source HERE (review S1). HasTreasureDistribution has just
            -- returned true, so the lookup is warm; recomputing it per browser row per page
            -- turn would be pure waste.
            if MIR.TreasureSourceOf then
                local okS, tbl, via, kind = pcall(MIR.TreasureSourceOf, statName, tplName)
                if okS then
                    entry.placedTable = tbl
                    entry.placedVia = via
                    entry.placedKind = kind
                end
            end
            -- FORCE-INCLUDE (v0.7). Tested INSIDE the branch, deliberately: adding
            -- `and not forceIncluded[tplId]` to the condition above would skip the whole
            -- branch, so entry.placed would never be set and every downstream consumer -
            -- the per-mod placed count and the duplicate warning - would lose the one fact
            -- they depend on (review B1/S2 of the v0.7 plan review). The item stays MARKED
            -- as placed; it just is not fenced.
            if MIR.Config.forceIncludedTemplates and MIR.Config.forceIncludedTemplates[tplId] then
                entry.forced = true
                stats.forceIncluded = stats.forceIncluded + 1
                -- fall through to the pool
            else
                tableExcluded[tplId] = entry
                stats.skippedTreasureTable = stats.skippedTreasureTable + 1
                return
            end
        end

        pool[category] = pool[category] or {}
        pool[category][rarity] = pool[category][rarity] or {}
        table.insert(pool[category][rarity], entry)
        byTemplate[tplId] = entry
        stats.eligible = stats.eligible + 1
        if entry.clutterOnly then stats.scopedClutter = stats.scopedClutter + 1 end
        if entry.bookshelfOnly then stats.scopedBookshelf = stats.scopedBookshelf + 1 end
    end

    local function considerEntry(statName, stype)
        stats.seen = stats.seen + 1
        if statName:sub(1, 1) == "_" then return end
        local ok, stat = pcall(Ext.Stats.Get, statName)
        if not ok or not stat then return end

        local mid, omid = "", ""
        pcall(function() mid = tostring(stat.ModId or "") end)
        pcall(function() omid = tostring(stat.OriginalModId or "") end)
        local modKey = (omid ~= "" and omid) or mid

        local info = modInfo(modKey)
        local baseMod = info.base
        -- (user mod/template excludes are checked LATE, inside addEntry — B2)

        -- NPC/character-gear fence — UNCONDITIONAL, no toggle (Alan 2026-08-20):
        -- gear meant for a specific NPC/companion never enters the pool.
        if MIR.NpcGearMods.byUuid[modKey] then
            stats.skippedNpcGearStats = stats.skippedNpcGearStats + 1
            return
        end

        -- Curated utility-mod fence (default ON; applies to Armor+Weapon+Object alike)
        if cfg.excludeUtilityMods then
            local byUuid = MIR.UtilityMods.byUuid[modKey]
            if byUuid or MIR.UtilityMods.byName[info.name] then
                if not byUuid and info.name and not utilNameOnlyLogged[info.name] then
                    utilNameOnlyLogged[info.name] = true
                    if MIR.Log then MIR.Log("utility-excluded via NAME match (uuid not listed): "
                                            .. info.name .. " [" .. modKey .. "]") end
                end
                stats.skippedUtilityStats = stats.skippedUtilityStats + 1
                return
            end
        end

        -- category (base-game gating is PER BRANCH so consumable base/modded checkboxes
        -- stay independent of includeBaseGame, per spec §5.1 #3)
        local category
        local consumable, clutterOnly, bookshelfOnly = false, false, false
        if stype == "Weapon" then
            if baseMod and not cfg.includeBaseGame then stats.skippedBase = stats.skippedBase + 1 return end
            category = "weapon"
        elseif stype == "Armor" then
            local slot = ""
            pcall(function() slot = tostring(stat.Slot or "") end)
            category = SLOT_TO_CATEGORY[slot]
            if not category then stats.skippedUnmappedSlot = stats.skippedUnmappedSlot + 1 return end
            if baseMod and not cfg.includeBaseGame then stats.skippedBase = stats.skippedBase + 1 return end
        else -- Object
            -- NOTE (v1.0 review SF-6): there is deliberately NO includeBaseGame test in this
            -- branch. Base-game gating is per branch (spec §5.1 #3), and it is what lets
            -- bookshelves admit VANILLA scrolls locally and the base-consumables toggle work
            -- independently of "Include base-game items". Adding one "for symmetry" kills
            -- both features silently.
            category = consumableCategory(stat, statName)
            -- counted for MODDED objects only (diff review M-2): every vanilla book, key,
            -- note and prop would otherwise swamp the number and it would answer nothing
            if not category then
                if not baseMod then stats.skippedUncategorised = stats.skippedUncategorised + 1 end
                return
            end
            consumable = true
            if category == "scroll" then
                -- v1.0: scrolls have their OWN admission arms and ignore the consumable
                -- toggles entirely (review BL-3: without these two arms the new setting
                -- admitted nothing). ONE global switch, no base/modded split, so the
                -- per-category draw gate (Main.lua categoryEnabled, keyed on
                -- filter.allowScrolls) is exactly sufficient - see Config.includeScrolls.
                local wantScroll = cfg.includeScrolls
                local wantBookshelfScroll = cfg.includeBookshelves and cfg.bookshelfScrolls
                if not (wantScroll or wantBookshelfScroll) then
                    stats.skippedConsumable = stats.skippedConsumable + 1 return
                end
                -- admitted ONLY because bookshelves asked: bookshelves and nowhere else
                bookshelfOnly = not wantScroll
            else
            local wantModded = cfg.includeConsumablesModded and not baseMod
            local wantBase = cfg.includeConsumablesBase and baseMod
            -- v0.9 (Alan): clutter containers may admit consumables LOCALLY, without the
            -- pool-wide toggle - the same shape wardrobes already use for cosmetics. The
            -- v0.8 answer (turn the Pool setting on for the user) was wrong: it made them
            -- pool-wide, so they appeared in chests and on corpses too.
            -- HISTORY: v0.9 restricted this to MODDED consumables, and only while neither Pool
            -- toggle was on, because the draw-time gate was per-CATEGORY and could not tell a
            -- vanilla potion from a modded one (reviews BL-2 and S-1: with 'modded ON / base
            -- OFF' the category gate stood open and a clutter-admitted VANILLA potion drew in
            -- chests). That is why Alan's barrels could never hold vanilla arrows.
            -- v1.0.1 (Alan, 2026-09-03): scoping is PER ENTRY (Main.lua entryAllowedFor), so
            -- clutter admits vanilla AND modded consumables and the flag below, not the
            -- category gate, keeps them out of every other container type.
            local wantClutter = cfg.includeClutterContainers and cfg.clutterConsumablesOnly
            if not (wantModded or wantBase or wantClutter) then
                stats.skippedConsumable = stats.skippedConsumable + 1 return
            end
            -- admitted ONLY because of the clutter setting: it can appear in clutter and
            -- nowhere else. Load-bearing since v1.0.1; also reported by !mir_pool.
            clutterOnly = wantClutter and not (wantModded or wantBase)
            end
        end

        -- template + eligibility
        local rt = ""
        pcall(function() rt = tostring(stat.RootTemplate or "") end)
        if rt == "" then stats.skippedNoTemplate = stats.skippedNoTemplate + 1 return end
        if byTemplate[rt] or userExcluded[rt] or tableExcluded[rt] then stats.skippedDupe = stats.skippedDupe + 1 return end
        local tmpl = nil
        pcall(function() tmpl = Ext.Template.GetRootTemplate(rt) end)
        if not tmpl then stats.skippedNoTemplate = stats.skippedNoTemplate + 1 return end

        local story, key = false, false
        pcall(function() story = tmpl.StoryItem == true end)
        pcall(function() key = tmpl.IsKey == true end)
        if story or key then stats.skippedStory = stats.skippedStory + 1 return end

        local dn = ""
        pcall(function() dn = tostring(Ext.Loca.GetTranslatedString(tmpl.DisplayName.Handle.Handle) or "") end)
        if dn == "" then stats.skippedNoName = stats.skippedNoName + 1 return end

        -- internal template Name: the key treasure categories reference items by
        -- (NOT the stat name, NOT the uuid). Cached on the entry for the fence,
        -- the browser and !mir_tables.
        local tplName = ""
        pcall(function() tplName = tostring(tmpl.Name or "") end)

        local rarity = "Common"
        pcall(function()
            local r = tostring(stat.Rarity or "")
            if MIR.RarityOrder[r] then rarity = r end
        end)

        addEntry(statName, category, rarity, rt, modKey, dn, consumable, tplName, baseMod, clutterOnly, bookshelfOnly)
    end

    for _, n in ipairs(Ext.Stats.GetStats("Armor")) do considerEntry(n, "Armor") end
    for _, n in ipairs(Ext.Stats.GetStats("Weapon")) do considerEntry(n, "Weapon") end
    for _, n in ipairs(Ext.Stats.GetStats("Object")) do considerEntry(n, "Object") end

    MIR.Catalog = { built = true, pool = pool, byTemplate = byTemplate,
                    userExcluded = userExcluded, tableExcluded = tableExcluded,
                    stats = stats, builtMs = Ext.Utils.MonotonicTime() - t0 }
    return MIR.Catalog
end

-- Remove an already-spawned template from the live pool (ledger hydration + post-spawn).
function MIR.RemoveFromPool(tplId)
    local entry = MIR.Catalog.byTemplate and MIR.Catalog.byTemplate[tplId] or nil
    if not entry or entry.spawned then return end
    entry.spawned = true
    local slice = MIR.Catalog.pool[entry.category] and MIR.Catalog.pool[entry.category][entry.rarity] or nil
    if not slice then return end
    for i, e in ipairs(slice) do
        if e.template == tplId then
            slice[i] = slice[#slice]
            slice[#slice] = nil
            return
        end
    end
end

-- Per-mod breakdown of the FULL eligible catalog (byTemplate, spawned items
-- included) — the data source for growing the curated utility list. !mir_mods.
function MIR.ModBreakdown()
    if not MIR.Catalog.built then return { "catalog not built" } end
    local perMod = {} -- [modKey] = { total = n, cats = { [cat] = n } }
    for _, entry in pairs(MIR.Catalog.byTemplate) do
        local m = perMod[entry.mod]
        if not m then m = { total = 0, cats = {} } perMod[entry.mod] = m end
        m.total = m.total + 1
        m.cats[entry.category] = (m.cats[entry.category] or 0) + 1
    end
    local keys = {}
    for k in pairs(perMod) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
        local ta, tb = perMod[a].total, perMod[b].total
        if ta ~= tb then return ta > tb end
        return a < b
    end)
    local lines = { "MIR per-mod ELIGIBLE pool breakdown (" .. #keys .. " mods; full catalog incl. already-spawned)" }
    for _, k in ipairs(keys) do
        local m = perMod[k]
        local cats = {}
        for c in pairs(m.cats) do cats[#cats + 1] = c end
        table.sort(cats)
        local parts = {}
        for _, c in ipairs(cats) do parts[#parts + 1] = c .. "=" .. m.cats[c] end
        local name = modInfo(k).name or "?"
        lines[#lines + 1] = ("%-5d %s [%s] %s"):format(m.total, name, k, table.concat(parts, " "))
    end
    return lines
end

-- Per-mod breakdown of items a mod PLACES IN THE WORLD ITSELF (!mir_placed_mods).
-- These are the only mods whose items a player could ever obtain twice: once where
-- the mod puts them, once from MIR. Reading BOTH tableExcluded and the placed flag on
-- pooled entries matters: an item the user force-included is still placed by its mod,
-- it just is not fenced any more, and it must still be reported here.
function MIR.PlacedModsBreakdown()
    if not MIR.Catalog.built then return { "catalog not built" } end
    local perMod = {} -- [modKey] = { placed = n, pool = n, tables = { [name] = n } }
    local function slot(modKey)
        local m = perMod[modKey]
        if not m then m = { placed = 0, pool = 0, tables = {} } perMod[modKey] = m end
        return m
    end
    -- review S3: entry.placed is only ever set inside the toggle-gated fence branch, so with
    -- the filter OFF nothing carries it and this report would be silently empty - which is
    -- exactly the state in which a user most wants to know which mods double-dip. Recompute
    -- from the index instead. Cheap: HasTreasureDistribution is a hash lookup.
    local function isPlacedEntry(e)
        if e.placed then return true end
        -- MODDED, NON-CONSUMABLE only - same scope as the fence itself (review S7)
        if e.base or e.consumable then return false end
        if not MIR.HasTreasureDistribution then return false end
        local ok, res = pcall(MIR.HasTreasureDistribution, e.stat, e.tplName)
        return (ok and res) and true or false
    end

    local function notePlaced(entry)
        local m = slot(entry.mod)
        m.placed = m.placed + 1
        if MIR.TreasureSourceOf then
            local ok, tbl = pcall(MIR.TreasureSourceOf, entry.stat, entry.tplName)
            if ok and tbl ~= nil and tbl ~= "" then
                local k = tostring(tbl)
                m.tables[k] = (m.tables[k] or 0) + 1
            end
        end
    end
    -- fenced-out placed items (only populated while the filter is ON)
    for _, e in pairs(MIR.Catalog.tableExcluded or {}) do notePlaced(e) end
    -- pooled items: placed ones are either force-included or the filter is off entirely
    for _, e in pairs(MIR.Catalog.byTemplate or {}) do
        if isPlacedEntry(e) then notePlaced(e) else slot(e.mod).pool = slot(e.mod).pool + 1 end
    end
    local keys = {}
    for k, m in pairs(perMod) do if m.placed > 0 then keys[#keys + 1] = k end end
    table.sort(keys, function(a, b)
        local pa, pb = perMod[a].placed, perMod[b].placed
        if pa ~= pb then return pa > pb end
        return a < b
    end)
    local lines = {
        "MODS THAT PLACE THEIR OWN ITEMS IN THE GAME WORLD",
        "",
        "These are the only mods whose items you could ever obtain TWICE - once where the mod",
        "puts them, and once from MIR. By default MIR keeps such items out of its spawn pool so",
        "that cannot happen; this report is here so you can see which mods that affects.",
        "MIR never removes, replaces or suppresses anything a mod places - it only declines to",
        "spawn a second copy.",
        "",
        ("mods listed: %d"):format(#keys),
        ((MIR.TreasureIndex and MIR.TreasureIndex.partial)
            and "WARNING: the placement index is PARTIAL - these counts are INCOMPLETE. Re-run !mir_tables."
            or ((MIR.Config and MIR.Config.excludeTreasureTableItems)
                and "filter is ON - these items are currently excluded from MIR's spawn pool"
                or "filter is OFF - these items are currently IN MIR's spawn pool, so duplicates are possible")),
        "",
        ("%-7s %-6s %-46s %s"):format("placed", "pool", "mod", "most common source table"),
    }
    for _, k in ipairs(keys) do
        local m = perMod[k]
        local topTable, topN = "?", -1
        for name, n in pairs(m.tables) do
            if n > topN or (n == topN and name < topTable) then topTable, topN = name, n end
        end
        local name = (modInfo(k).name) or "?"
        lines[#lines + 1] = ("%-7d %-6d %-46s %s"):format(
            m.placed, m.pool, (name .. " [" .. tostring(k) .. "]"), topTable)
    end
    if #keys == 0 then
        lines[#lines + 1] = "(none - no mod in your load order places its own items where MIR can see it)"
    end
    return lines
end

-- Pool summary for !mir_pool
function MIR.PoolCounts()
    local lines = {}
    if not MIR.Catalog.built then return { "catalog not built" } end
    local grand = 0
    local cats = {}
    for cat in pairs(MIR.Catalog.pool) do cats[#cats + 1] = cat end
    table.sort(cats)
    for _, cat in ipairs(cats) do
        local parts, catTotal = {}, 0
        local clutterOnly, bookshelfOnly = 0, 0
        for _, tier in ipairs(MIR.TierName) do
            local slice = MIR.Catalog.pool[cat][tier]
            local n = slice and #slice or 0
            catTotal = catTotal + n
            parts[#parts + 1] = tier .. "=" .. n
            for _, e in ipairs(slice or {}) do
                if e.clutterOnly then clutterOnly = clutterOnly + 1 end
                if e.bookshelfOnly then bookshelfOnly = bookshelfOnly + 1 end
            end
        end
        grand = grand + catTotal
        -- v1.0: say when a category is only LOCALLY admitted, so the count cannot be read
        -- as "generally available" (the clutterOnly flag was recorded since v0.9 but never
        -- reported - review MINOR).
        local scope = ""
        if clutterOnly > 0 then scope = scope .. ("  [%d drawable in clutter containers ONLY]"):format(clutterOnly) end
        if bookshelfOnly > 0 then scope = scope .. ("  [%d drawable in bookshelves ONLY]"):format(bookshelfOnly) end
        lines[#lines + 1] = ("%-16s total=%-5d %s%s"):format(cat, catTotal, table.concat(parts, " "), scope)
    end
    lines[#lines + 1] = "GRAND TOTAL (live pool): " .. grand
    return lines
end
