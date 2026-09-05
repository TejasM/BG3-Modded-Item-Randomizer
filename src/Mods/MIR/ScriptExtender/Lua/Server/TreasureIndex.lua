-- MIR treasure-placement index (plan §5.1 #13, reworked 2026-08-24).
--
-- PURPOSE: detect items a mod ALREADY places somewhere findable, so MIR never
-- spawns a duplicate of an authored drop.
--
-- SCOPE RULE (Alan, 2026-08-24 — verbatim): "If the mod places the items with a
-- merchant, in the camp chest, or in the tutorial chest, that does not count
-- from our exclusion perspective. In other words -- we want to exclude (on the
-- player's option) items that are placed with a specific NPC or in a specific
-- position or chest in the game world."
--
-- Therefore this index is PROVENANCE-AWARE. It does not ask "does this item
-- appear in some treasure table"; it asks "is this item placed somewhere the
-- player FINDS it". The distinction is made by WHAT REFERENCES the table:
--
--   character .TradeTreasures  -> merchant stock      -> NOT a placement (buying
--                                                        is not finding)
--   character .Treasures       -> that NPC's own loot -> PLACEMENT ("placed with
--                                                        a specific NPC")
--   item/container .InventoryList -> a world container -> PLACEMENT, UNLESS the
--       container is camp/tutorial/traveller storage (CONVENIENCE_PATTERNS below)
--       -> player-convenience storage, NOT an authored placement.
--   a table hung off MANY templates -> generic class loot, NOT "a specific NPC".
--
-- OPEN QUESTION the first in-game run must answer: MIR's own Phase-0 probe saw
-- InventoryList=nil on all 39 root templates it sampled, so world-container
-- detection may yield nothing. !mir_tables reports .InventoryList template counts
-- explicitly; if that number is 0, only the NPC half of the rule is live.
--
-- This is why the ROOT-TEMPLATE WALK is now the primary (and only) enumeration
-- path: it is the only one that knows who references a table. Enumerating the
-- stats manager's table list — the previous approach — yields names with no
-- provenance at all, which is precisely what made the old version fence a mod's
-- entire catalogue when the mod shipped a tutorial-chest table.
--
-- API FACTS (verified 2026-08-21, see _research/treasure_table_research_2026-08-21.md):
--   * Ext.Template.GetAllRootTemplates() -> map of root templates.
--   * Character templates carry .Treasures / .TradeTreasures; item templates
--     carry .InventoryList. Field names confirmed in the SE v32 binary and in
--     VolitionCabinet's shipped reader.
--   * Ext.Stats.TreasureTable.GetLegacy(id) / Ext.Stats.TreasureCategory.GetLegacy(id).
--     Legacy shape: TreasureTable.SubTables[].Categories[], each category edge
--     carrying EITHER .TreasureTable (nested table NAME) or .TreasureCategory
--     (category NAME); TreasureCategory.Items[] each have .Name.
--   * Items[].Name is the ITEM STAT NAME (BagsBagsBags proof case). The template
--     name is probed as a secondary key because some content names them alike.
--   * "Empty" is the engine's no-treasure sentinel.
-- NOTE: that research doc is SUPERSEDED on two points (goal-log 2026-08-21):
-- item refs are STAT names (not root-template names), and
-- Ext.Stats.GetStats("TreasureTable") does work (C++ FetchTreasureTableEntries).
-- Vanilla name facts (2026-08-24): the camp chest is CONT_PlayerCampChest_A..D;
-- NO vanilla template contains "Tutorial" or "TUT_Chest" (the Nautiloid chest is
-- most likely the generic CONT_GEN_Chest_Travel_A family).
-- Everything below is pcall'd and FAILS OPEN: no names -> nothing is fenced.
MIR = MIR or {}

local function log(m)
    if MIR.Log then MIR.Log("[tt] " .. tostring(m))
    else Ext.Utils.Print("[MIR][tt] " .. tostring(m)) end
end

-- Budgets (review B2): pass 1 now walks EVERY root template, so it gets its own
-- slice and cannot starve pass 2. A trip still yields PARTIAL = fence inert, but
-- a partial index is now RETRYABLE via !mir_tables instead of latching for the
-- whole session.
local PASS1_MS = 5000
local BUDGET_MS = 9000
local MAX_DEPTH = 24
-- Tables referenced by more than this many distinct templates are GENERIC
-- distribution (vanilla attaches e.g. bandit loot to whole classes of NPC), not
-- "placed with a specific NPC" — review S2.
local GENERIC_REF_LIMIT = 5

local function newStats()
    return { templates = 0, rootTables = 0, npcTables = 0, containerTables = 0,
             merchantTables = 0, convenienceTables = 0, genericTables = 0,
             tplWithTreasures = 0, tplWithTradeTreasures = 0, tplWithInventoryList = 0,
             tablesResolved = 0, categories = 0, itemRefs = 0, distinctItems = 0,
             missingTables = 0, missingCategories = 0, cycles = 0, depthCapped = 0,
             aborted = false }
end

MIR.TreasureIndex = {
    built = false,
    names = {},          -- [itemName] = { table = <table name>, via = <template name>, kind = "npc"|"container" }
    stats = newStats(),
    source = "none",
    partial = false,
    ms = 0,
    note = nil,
}

local function tryGet(fn)
    local ok, v = pcall(fn)
    if ok then return v end
    return nil
end

local function deprefix(n, p)
    if type(n) == "string" and #n > 2 and n:sub(1, 2) == p then return n:sub(3) end
    return nil
end

-- Player-convenience storage: camp chest, tutorial chest, traveller's chest.
-- Deliberately its OWN list rather than borrowing Config.excludePatterns (review
-- S1): those two lists answer different questions ("never inject here" vs "this
-- is not an authored placement") and must be free to diverge. Matched
-- case-insensitively and kept deliberately WIDE, because a false negative here
-- re-creates the exact catastrophe this rewrite exists to prevent (a mod that
-- ships a tutorial chest having its whole catalogue fenced), while a false
-- positive merely leaves one more item in the pool.
local CONVENIENCE_PATTERNS = {
    "campchest", "chest_camp", "cont_camp", "tutorial", "tut_chest", "tut_",
    "travellerschest", "travelerschest", "traveller", "traveler", "storage",
}
local function isConvenienceName(name)
    if type(name) ~= "string" or name == "" then return false end
    local low = name:lower()
    for _, p in ipairs(CONVENIENCE_PATTERNS) do
        if low:find(p, 1, true) then return true end
    end
    return false
end

-- ---------------- pass 1: which tables are PLACEMENTS, and via what ----------------
-- Returns roots = { [tableName] = { via = <template name>, kind = "npc"|"container" } }
-- plus the merchant/convenience tables recorded only for the report.
local function getField(o, k) return o[k] end

-- A treasure-table reference arrives either as a plain string or as a node
-- carrying .Object (the serialized game-data shape is
-- <node id="InventoryItem"><attribute id="Object" value="<table>"/></node>;
-- VolitionCabinet assumes SE flattens it to a string, which is UNVERIFIED —
-- so accept both rather than silently extracting nothing).
local function asTableName(v)
    if type(v) == "string" then return v end
    if type(v) == "table" or type(v) == "userdata" then
        local o = nil
        pcall(function() o = v.Object end)
        if type(o) == "string" then return o end
        pcall(function() o = v.Name end)
        if type(o) == "string" then return o end
    end
    return nil
end

local function collectPlacementTables(deadline, stats)
    local roots, skipped, refs = {}, {}, {}

    local templates = tryGet(function() return Ext.Template.GetAllRootTemplates() end)
    if templates == nil then return roots, skipped, false end

    local shapeLogged = false
    local timedOut = false
    local i = 0
    local okWalk = pcall(function()
        for _, t in pairs(templates) do
            i = i + 1
            -- sample the clock rather than calling it per template (review B2)
            if (i % 512) == 0 and Ext.Utils.MonotonicTime() > deadline then
                timedOut = true break
            end
            stats.templates = stats.templates + 1

            local okN, tname = pcall(getField, t, "Name")
            tname = (okN and type(tname) == "string") and tname or ""
            -- branch on TemplateType so we do not probe fields the type cannot
            -- have (review B2: that was ~2 thrown errors per template)
            local okT, ttype = pcall(getField, t, "TemplateType")
            ttype = (okT and type(ttype) == "string") and ttype:lower() or ""

            local function note(raw, kind, isPlacement)
                local tbl = asTableName(raw)
                if type(tbl) ~= "string" or tbl == "" or tbl == "Empty" then return end
                refs[tbl] = (refs[tbl] or 0) + 1
                if isPlacement then
                    if not roots[tbl] then roots[tbl] = { via = tname, kind = kind } end
                elseif not roots[tbl] and not skipped[tbl] then
                    skipped[tbl] = { via = tname, kind = kind }
                end
            end

            if ttype ~= "item" then -- character (or unknown: probe both, cheaply)
                local okTr, trade = pcall(getField, t, "TradeTreasures")
                if okTr and trade ~= nil then
                    stats.tplWithTradeTreasures = stats.tplWithTradeTreasures + 1
                    pcall(function()
                        for _, n in pairs(trade) do note(n, "merchant", false) end
                    end)
                end
                local okTs, treas = pcall(getField, t, "Treasures")
                if okTs and treas ~= nil then
                    stats.tplWithTreasures = stats.tplWithTreasures + 1
                    pcall(function()
                        for _, n in pairs(treas) do
                            note(n, isConvenienceName(tname) and "convenience" or "npc",
                                 not isConvenienceName(tname))
                        end
                    end)
                end
            end
            if ttype ~= "character" then
                local okI, inv = pcall(getField, t, "InventoryList")
                if okI and inv ~= nil then
                    stats.tplWithInventoryList = stats.tplWithInventoryList + 1
                    -- one-shot shape log (review B1): MIR's own Phase-0 probe saw
                    -- InventoryList=nil on all 39 templates it sampled, so whether
                    -- this path yields anything at all is an OPEN QUESTION that the
                    -- first in-game run must answer.
                    if not shapeLogged then
                        shapeLogged = true
                        pcall(function()
                            local first = nil
                            for _, v in pairs(inv) do first = v break end
                            log(("InventoryList shape on '%s': type=%s first=%s (%s)"):format(
                                tname, type(inv), tostring(first), type(first)))
                        end)
                    end
                    local convenience = isConvenienceName(tname)
                    pcall(function()
                        for _, n in pairs(inv) do
                            note(n, convenience and "convenience" or "container", not convenience)
                        end
                    end)
                end
            end
        end
    end)
    if not okWalk then
        -- an abort truncates the placement set; the fence must not pretend the
        -- scan was complete (review S5)
        stats.aborted = true
        timedOut = true
    end

    -- Generic distribution: a table hung off many different templates is not
    -- "a specific NPC" (review S2). Demote those.
    for tbl, o in pairs(roots) do
        if (refs[tbl] or 0) > GENERIC_REF_LIMIT then
            roots[tbl] = nil
            skipped[tbl] = { via = o.via, kind = "generic" }
            stats.genericTables = stats.genericTables + 1
        end
    end
    for tbl, o in pairs(skipped) do
        if o.kind == "merchant" then stats.merchantTables = stats.merchantTables + 1
        elseif o.kind == "convenience" then stats.convenienceTables = stats.convenienceTables + 1 end
    end
    for _, o in pairs(roots) do
        if o.kind == "npc" then stats.npcTables = stats.npcTables + 1
        else stats.containerTables = stats.containerTables + 1 end
    end
    return roots, skipped, timedOut
end

-- ---------------- pass 2: expand the placement tables into item names ----------------
local resolveTable, expandCategory

expandCategory = function(catName, origin, ctx)
    if ctx.timedOut then return end
    if ctx.doneCat[catName] then return end
    ctx.doneCat[catName] = true
    local tc = tryGet(function() return Ext.Stats.TreasureCategory.GetLegacy(catName) end)
    if type(tc) ~= "table" then
        ctx.stats.missingCategories = ctx.stats.missingCategories + 1
        return
    end
    ctx.stats.categories = ctx.stats.categories + 1
    pcall(function()
        for _, item in ipairs(tc.Items or {}) do
            local n = item and item.Name
            if type(n) == "string" and n ~= "" then
                ctx.stats.itemRefs = ctx.stats.itemRefs + 1
                if ctx.names[n] == nil then
                    ctx.names[n] = origin
                    ctx.stats.distinctItems = ctx.stats.distinctItems + 1
                end
                local bare = deprefix(n, "I_")
                if bare and ctx.names[bare] == nil then ctx.names[bare] = origin end
            end
        end
    end)
end

resolveTable = function(name, origin, ctx)
    if ctx.done[name] then return end
    if ctx.active[name] then ctx.stats.cycles = ctx.stats.cycles + 1 return end
    if ctx.depth >= MAX_DEPTH then ctx.stats.depthCapped = ctx.stats.depthCapped + 1 return end
    if Ext.Utils.MonotonicTime() > ctx.deadline then ctx.timedOut = true return end

    local tt = tryGet(function() return Ext.Stats.TreasureTable.GetLegacy(name) end)
    if type(tt) ~= "table" then
        ctx.stats.missingTables = ctx.stats.missingTables + 1
        ctx.done[name] = true
        return
    end
    ctx.stats.tablesResolved = ctx.stats.tablesResolved + 1
    ctx.active[name] = true
    ctx.depth = ctx.depth + 1

    pcall(function()
        for _, sub in ipairs(tt.SubTables or {}) do
            for _, cat in ipairs(sub.Categories or {}) do
                local nested = asTableName(cat and cat.TreasureTable)
                if type(nested) == "string" and nested ~= "" and nested ~= "Empty" then
                    -- a nested table inherits the provenance of whoever referenced it
                    resolveTable(nested, origin, ctx)
                    local bare = deprefix(nested, "T_")
                    if bare then resolveTable(bare, origin, ctx) end
                end
                local catName = cat and cat.TreasureCategory
                if type(catName) == "string" and catName ~= "" then
                    expandCategory(catName, origin, ctx)
                end
            end
        end
    end)

    ctx.depth = ctx.depth - 1
    ctx.active[name] = nil
    if not ctx.timedOut then ctx.done[name] = true end
end

-- ---------------- build ----------------
function MIR.BuildTreasureIndex(reason)
    local t0 = Ext.Utils.MonotonicTime()
    local stats = newStats()

    local roots, skipped, timedOut1 = collectPlacementTables(t0 + PASS1_MS, stats)

    local ctx = { names = {}, done = {}, doneCat = {}, active = {}, depth = 0,
                  deadline = t0 + BUDGET_MS, timedOut = timedOut1, stats = stats }

    local nRoots = 0
    for tableName, origin in pairs(roots) do
        nRoots = nRoots + 1
        if not ctx.timedOut then
            local o = { table = tableName, via = origin.via, kind = origin.kind }
            resolveTable(tableName, o, ctx)
            local bare = deprefix(tableName, "T_")
            if bare then resolveTable(bare, o, ctx) end
        end
    end
    stats.rootTables = nRoots

    MIR.TreasureIndex = {
        built = true,
        names = ctx.names,
        skipped = skipped,
        stats = stats,
        source = (nRoots > 0) and "rootTemplates" or "none",
        partial = ctx.timedOut and true or false,
        ms = math.floor(Ext.Utils.MonotonicTime() - t0),
        note = (nRoots == 0) and "no placement tables found (fence inert)" or nil,
    }
    -- pcall'd: a formatting slip here must NEVER destroy a good index by
    -- throwing into EnsureTreasureIndex's handler (review S4)
    pcall(function()
        local idx = MIR.TreasureIndex
        log(("index built in %d ms via %s%s: %d templates (Treasures=%d TradeTreasures=%d InventoryList=%d) -> %d placement table(s) [npc=%d container=%d] ; IGNORED: merchant=%d camp/tutorial=%d generic=%d ; %d resolved, %d distinct item name(s) (%s)")
            :format(idx.ms, idx.source,
                    idx.partial and " (PARTIAL - fence DISABLED this session; rerun !mir_tables)" or "",
                    stats.templates, stats.tplWithTreasures, stats.tplWithTradeTreasures,
                    stats.tplWithInventoryList, nRoots, stats.npcTables, stats.containerTables,
                    stats.merchantTables, stats.convenienceTables, stats.genericTables,
                    stats.tablesResolved, stats.distinctItems, tostring(reason)))
    end)
    return MIR.TreasureIndex
end

-- force=true rebuilds even a built index; used by !mir_tables so a PARTIAL or
-- errored scan is retryable instead of latched for the session (review B2).
function MIR.EnsureTreasureIndex(reason, force)
    if MIR.TreasureIndex.built and not force then return MIR.TreasureIndex end
    local ok, err = pcall(function() MIR.BuildTreasureIndex(reason) end)
    if not ok then
        MIR.TreasureIndex = { built = true, names = {}, skipped = {}, stats = newStats(),
                              source = "error", partial = false, ms = 0, note = tostring(err) }
        log("index build ERROR (fence inert this session): " .. tostring(err))
    end
    return MIR.TreasureIndex
end

-- The fence predicate. Probes the STAT name first (TreasureCategory.Items[].Name
-- is a stat name) and the template name second. A PARTIAL index makes the fence
-- inert for the session: fencing an arbitrary, load-order-dependent prefix would
-- be non-deterministic and unreproducible.
function MIR.HasTreasureDistribution(statName, templateName)
    local idx = MIR.TreasureIndex
    if not idx.built or idx.partial then return false end
    local n = idx.names
    if type(statName) == "string" and statName ~= ""
       and (n[statName] ~= nil or n["I_" .. statName] ~= nil) then return true end
    if type(templateName) == "string" and templateName ~= ""
       and (n[templateName] ~= nil or n["I_" .. templateName] ~= nil) then return true end
    return false
end

-- Where an item is placed (report only): returns table name, referencing template, kind.
function MIR.TreasureSourceOf(statName, templateName)
    local n = MIR.TreasureIndex.names
    local o = nil
    if type(statName) == "string" and statName ~= "" then
        o = n[statName] or n["I_" .. statName]
    end
    if o == nil and type(templateName) == "string" and templateName ~= "" then
        o = n[templateName] or n["I_" .. templateName]
    end
    if type(o) ~= "table" then return nil end
    return o.table, o.via, o.kind
end

-- ---------------- !mir_tables report ----------------
function MIR.TreasureReport()
    local idx = MIR.TreasureIndex
    local s = idx.stats or newStats()
    local lines = {
        "MIR placement-detection report",
        "",
        "SCOPE RULE: an item counts as PLACED only when a mod put it where the player FINDS it -",
        "  * on a specific NPC (that character's own loot), or",
        "  * in a specific world container (a chest, a cache).",
        "Merchant stock does NOT count (buying is not finding), and neither do camp chests,",
        "tutorial chests or traveller's chests (player-convenience storage, not authored placement).",
        "",
        "EXCLUDED here means MIR will not SPAWN a copy. MIR never removes, replaces or",
        "suppresses anything the game or another mod gives you - the mod still places its own.",
        "",
        ("source=%s partial=%s scan=%d ms toggle=%s"):format(
            tostring(idx.source), tostring(idx.partial), idx.ms or 0,
            tostring(MIR.Config and MIR.Config.excludeTreasureTableItems)),
        ("root templates walked:        %d"):format(s.templates),
        ("  with .Treasures:            %d"):format(s.tplWithTreasures),
        ("  with .TradeTreasures:       %d"):format(s.tplWithTradeTreasures),
        ("  with .InventoryList:        %d   <- if 0, world-container detection is not working"):format(s.tplWithInventoryList),
        ("placement tables (COUNTED):   %d   [npc=%d container=%d]"):format(s.rootTables, s.npcTables, s.containerTables),
        ("merchant tables (ignored):    %d"):format(s.merchantTables),
        ("camp/tutorial (ignored):      %d"):format(s.convenienceTables),
        ("generic/many-NPC (ignored):   %d"):format(s.genericTables),
        ("scan aborted mid-walk:        %s"):format(tostring(s.aborted)),
        ("tables resolved:              %d"):format(s.tablesResolved),
        ("categories expanded:          %d"):format(s.categories),
        ("item references seen:         %d"):format(s.itemRefs),
        ("distinct item names indexed:  %d"):format(s.distinctItems),
        ("tables that would not resolve:%d   categories: %d   cycles: %d   depth-capped: %d"):format(
            s.missingTables, s.missingCategories, s.cycles, s.depthCapped),
        "",
    }
    if idx.note then lines[#lines + 1] = "NOTE: " .. tostring(idx.note) end

    -- which of MIR's own catalog items are fenced, and by what
    local fenced, n = {}, 0
    pcall(function()
        for _, e in pairs(MIR.Catalog and MIR.Catalog.tableExcluded or {}) do
            local tbl, via, kind = MIR.TreasureSourceOf(e.stat, e.tplName)
            n = n + 1
            fenced[#fenced + 1] = ("%-44s %-10s <- %s [%s: %s]"):format(
                tostring(e.name or e.stat), tostring(e.category),
                tostring(tbl or "?"), tostring(kind or "?"), tostring(via or "?"))
        end
    end)
    table.sort(fenced)
    local ign = {}
    pcall(function()
        for tbl, o in pairs(idx.skipped or {}) do
            ign[#ign + 1] = ("  %-46s %-12s via %s"):format(tbl, tostring(o.kind), tostring(o.via))
        end
    end)
    table.sort(ign)
    lines[#lines + 1] = ("TABLES DELIBERATELY IGNORED: %d"):format(#ign)
    for _, l in ipairs(ign) do lines[#lines + 1] = l end
    lines[#lines + 1] = ""
    lines[#lines + 1] = ("ITEMS CURRENTLY EXCLUDED FROM MIR'S SPAWN POOL: %d"):format(n)
    lines[#lines + 1] = "(name / category / treasure table <- [why: which NPC or container])"
    for _, l in ipairs(fenced) do lines[#lines + 1] = l end
    return lines
end
