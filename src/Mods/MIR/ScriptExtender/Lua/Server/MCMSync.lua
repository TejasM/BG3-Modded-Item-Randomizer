-- MIR MCM sync layer (Phase 3 chunk 2, design §1/§3.3).
-- One-way MCM -> MIR.Config. The engine keeps reading MIR.Config; MCM is a
-- SOURCE that writes into it. Loads BEFORE Main.lua so its SessionLoaded
-- subscriber runs first (settings applied before the catalog is built).
-- Degrades gracefully: with MCM absent the hardcoded Config defaults stand.
MIR = MIR or {}

local MCM_UUID = "755a8a72-407f-4f0d-9a33-274ac0f0b53d"

-- MIR.Log is assigned by Main.lua (loads after this file); fall back until then.
local function log(m)
    if MIR.Log then MIR.Log("[MCM] " .. tostring(m))
    else Ext.Utils.Print("[MIR][MCM] " .. tostring(m)) end
end

-- settingId -> config field + whether a pool rebuild is needed (design §3.3)
local SETTING_MAP = {
    { id = "mir_power_enabled", field = "powerEnabled", rebuild = false, kind = "bool" },
    { id = "mir_power_strict", field = "powerStrictUnknown", rebuild = false, kind = "bool" },
    { id = "mir_enabled",                    field = "enabled",                  rebuild = false, kind = "bool" },
    { id = "mir_base_chance",                field = "baseChancePct",            rebuild = false, kind = "int" },
    { id = "mir_rolls",                      field = "rolls",                    rebuild = false, kind = "int" },
    { id = "mir_include_corpses",            field = "includeCorpses",           rebuild = false, kind = "bool" },
    -- v0.9: BOTH clutter settings now decide CATALOG COMPOSITION (whether consumables are
    -- admitted for clutter - vanilla and modded since v1.0.1), so both must rebuild. rebuild=false here would
    -- leave the setting apparently doing nothing until something else forced a rebuild.
    { id = "mir_include_clutter",            field = "includeClutterContainers", rebuild = true,  kind = "bool" },
    -- v0.8 container classes + content filters: draw-time (rebuild = false) EXCEPT the
    -- clutter consumables filter, which since v0.9 also admits to the catalogue.
    { id = "mir_clutter_consumables_only",   field = "clutterConsumablesOnly",   rebuild = true,  kind = "bool" },
    { id = "mir_include_wardrobes",          field = "includeWardrobes",         rebuild = false, kind = "bool" },
    { id = "mir_wardrobe_cosmetics",         field = "wardrobeCosmetics",        rebuild = false, kind = "bool" },
    { id = "mir_wardrobe_stat_garments",     field = "wardrobeStatGarments",     rebuild = false, kind = "bool" },
    { id = "mir_wardrobe_all_items",         field = "wardrobeAllItems",         rebuild = false, kind = "bool" },
    -- v1.0 bookshelves + scrolls. The class switch and the bookshelf-scrolls box both decide
    -- whether scrolls are ADMITTED to the catalogue (Catalog.lua Object branch), so they
    -- rebuild; "all items" is draw-time only (plan review BL-5).
    { id = "mir_include_bookshelves",        field = "includeBookshelves",       rebuild = true,  kind = "bool" },
    { id = "mir_bookshelf_scrolls",          field = "bookshelfScrolls",         rebuild = true,  kind = "bool" },
    { id = "mir_bookshelf_all_items",        field = "bookshelfAllItems",        rebuild = false, kind = "bool" },
    { id = "mir_include_scrolls",            field = "includeScrolls",           rebuild = true,  kind = "bool" },
    { id = "mir_exclude_nautiloid",          field = "excludeNautiloid",         rebuild = false, kind = "bool" },
    { id = "mir_notify_spawns",              field = "notifySpawns",             rebuild = false, kind = "bool" },
    { id = "mir_include_cosmetics",          field = "includeCosmetics",         rebuild = false, kind = "bool" }, -- draw-time gate
    { id = "mir_include_base_game",          field = "includeBaseGame",          rebuild = true,  kind = "bool" },
    { id = "mir_include_consumables_modded", field = "includeConsumablesModded", rebuild = true,  kind = "bool" },
    { id = "mir_include_consumables_base",   field = "includeConsumablesBase",   rebuild = true,  kind = "bool" },
    { id = "mir_exclude_utility_mods",       field = "excludeUtilityMods",       rebuild = true,  kind = "bool" },
    -- changes pool composition (fence applied at catalog build time) -> rebuild
    { id = "mir_exclude_treasure_items",     field = "excludeTreasureTableItems", rebuild = true, kind = "bool" },

    -- ===== v0.9 rarity window =====
    -- These write NESTED config (rarityWindow.levelRules[n].minTier), which a plain
    -- `field` cannot express: both application sites do `MIR.Config[field] = v`, a
    -- single-level assignment, and ApplyMcmSetting returns early for any id it does not
    -- know. A blueprint-only id would therefore apply NEVER, silently, on BOTH paths
    -- (review BL-1). Hence `apply`, honoured by SyncFromMCM and ApplyMcmSetting alike.
    { id = "mir_rarity_window_enabled", rebuild = false, kind = "bool",
      apply = function(v) MIR.Config.rarityWindow.enabled = v end },

    { id = "mir_rw_lvl1_min", rebuild = false, kind = "tier",
      apply = function(v) MIR.Config.rarityWindow.levelRules[1].minTier = v end },
    { id = "mir_rw_lvl1_max", rebuild = false, kind = "tier",
      apply = function(v) MIR.Config.rarityWindow.levelRules[1].maxTier = v end },
    { id = "mir_rw_lvl2_min", rebuild = false, kind = "tier",
      apply = function(v) MIR.Config.rarityWindow.levelRules[2].minTier = v end },
    { id = "mir_rw_lvl2_max", rebuild = false, kind = "tier",
      apply = function(v) MIR.Config.rarityWindow.levelRules[2].maxTier = v end },
    { id = "mir_rw_lvl3_min", rebuild = false, kind = "tier",
      apply = function(v) MIR.Config.rarityWindow.levelRules[3].minTier = v end },
    { id = "mir_rw_lvl3_max", rebuild = false, kind = "tier",
      apply = function(v) MIR.Config.rarityWindow.levelRules[3].maxTier = v end },
    { id = "mir_rw_lvl4_min", rebuild = false, kind = "tier",
      apply = function(v) MIR.Config.rarityWindow.levelRules[4].minTier = v end },
    { id = "mir_rw_lvl4_max", rebuild = false, kind = "tier",
      apply = function(v) MIR.Config.rarityWindow.levelRules[4].maxTier = v end },

    { id = "mir_rw_act1_min", rebuild = false, kind = "tier",
      apply = function(v) MIR.Config.rarityWindow.actRules[1].minTier = v end },
    { id = "mir_rw_act1_max", rebuild = false, kind = "tier",
      apply = function(v) MIR.Config.rarityWindow.actRules[1].maxTier = v end },
    { id = "mir_rw_act2_min", rebuild = false, kind = "tier",
      apply = function(v) MIR.Config.rarityWindow.actRules[2].minTier = v end },
    { id = "mir_rw_act2_max", rebuild = false, kind = "tier",
      apply = function(v) MIR.Config.rarityWindow.actRules[2].maxTier = v end },
    { id = "mir_rw_act3_min", rebuild = false, kind = "tier",
      apply = function(v) MIR.Config.rarityWindow.actRules[3].minTier = v end },
    { id = "mir_rw_act3_max", rebuild = false, kind = "tier",
      apply = function(v) MIR.Config.rarityWindow.actRules[3].maxTier = v end },
}

-- v0.9: one place that knows how to write a row, so `apply` cannot be honoured on one
-- path and forgotten on the other.
local function applySetting(m, v)
    if m.apply then m.apply(v) else MIR.Config[m.field] = v end
end

-- v0.9 (review Q7). MCM cannot express cross-setting validation, so min<=max is enforced
-- on READ. Direction matters: on a SINGLE-setting change the changed id is known, so clamp
-- the OTHER value - raising max back to min would undo the very drag the user just made and
-- read as a broken control. On a FULL sync there is no "last changed", so clamp max=min.
-- DELIBERATELY NOT written back through MCM.Set: v0.9 removes the last place MIR edited a
-- user setting and must not add a new one. Clamped in memory, logged once, and !mir_rarity
-- shows raw-vs-clamped so the MCM value never silently lies.
local rwNormWarned = false
function MIR.NormalizeRarityWindow(changedId)
    local rw = MIR.Config and MIR.Config.rarityWindow
    if not rw then return end
    local fixed = {}
    local function fixRule(rule, label, minId, maxId)
        if not rule then return end
        local mn = math.max(1, math.min(5, tonumber(rule.minTier) or 1))
        local mx = math.max(1, math.min(5, tonumber(rule.maxTier) or 5))
        if mn > mx then
            -- review S-2: keep the RAW pair so !mir_rarity can show what MCM still
            -- displays alongside what MIR is actually using. MCM is deliberately not
            -- rewritten, so without this the two views silently disagree forever.
            MIR.RarityClamps = MIR.RarityClamps or {}
            MIR.RarityClamps[label] = { rawMin = mn, rawMax = mx }
            if changedId == minId then mx = mn        -- user raised min: push max up
            elseif changedId == maxId then mn = mx    -- user lowered max: pull min down
            else mx = mn end                          -- full sync: no last-changed known
            fixed[#fixed + 1] = label
        end
        rule.minTier, rule.maxTier = mn, mx
        if MIR.RarityClamps and MIR.RarityClamps[label] then
            MIR.RarityClamps[label].useMin, MIR.RarityClamps[label].useMax = mn, mx
        end
    end
    for i, r in ipairs(rw.levelRules or {}) do
        fixRule(r, "level band " .. i, "mir_rw_lvl" .. i .. "_min", "mir_rw_lvl" .. i .. "_max")
    end
    for a = 1, 3 do
        fixRule((rw.actRules or {})[a], "Act " .. a, "mir_rw_act" .. a .. "_min", "mir_rw_act" .. a .. "_max")
    end
    if #fixed > 0 and not rwNormWarned then
        rwNormWarned = true
        log("rarity window: min was above max in " .. table.concat(fixed, ", ")
            .. " - clamped in memory (MCM is NOT rewritten). !mir_rarity shows the values in use.")
    end
end

local SETTING_BY_ID = {}


for _, m in ipairs(SETTING_MAP) do SETTING_BY_ID[m.id] = m end

-- A category missing here has its weight silently reset to the default every session,
-- because this is what SyncFromMCM reads back (plan review BL-4). Must name every key in
-- Config.categoryWeights.
local SHARE_CATS = { "helmet", "gloves", "torso", "boots", "cloak", "ring", "amulet",
                     "weapon", "shield", "vanityClothing", "vanityBoots", "underwear",
                     "potion", "arrow", "alchemyIngredient", "scroll" }
local SHARE_BY_ID = {}
for _, cat in ipairs(SHARE_CATS) do SHARE_BY_ID["mir_share_" .. cat] = cat end

-- v1.0: the per-category include checkboxes (mir_cat_*) are DELETED - see Config.lua.
-- MCM drops the stale keys from settings.json on its own; nothing here reads them.

local LIST_IDS = {
    mir_excluded_mod_uuids = "excludedModUuids",
    mir_excluded_templates = "excludedTemplates",
    mir_force_included_templates = "forceIncludedTemplates",
}

-- Console-override shadows (design §3.3/M4): console commands mark the MCM
-- setting they shadow; an explicit MCM save for that key wins and clears it;
-- full syncs clear all shadows.
MIR.ConsoleOverrides = {}
function MIR.MarkConsoleOverride(settingId)
    if settingId then MIR.ConsoleOverrides[settingId] = true end
end

MIR.McmDetected = false
-- MIR.McmMissing: the mod is DORMANT because MCM is not installed (Alan 2026-08-24:
-- "since MCM is a hard requirement we want the mod to refuse to run without it").
-- IMPORTANT distinction, and the reason there are two flags:
--   * mcmPakLoaded()  = is the BG3MCM pak in the load order? Authoritative, and
--     independent of Lua timing. This is what gates dormancy.
--   * MCM ~= nil      = has MCM injected its API into our env YET? The lifecycle
--     point is undocumented, so a nil global is NOT proof the user lacks MCM and
--     must never be allowed to disable the mod. That case keeps the existing
--     retry-and-defaults path.
MIR.McmMissing = false
local function mcmPakLoaded()
    -- A live MCM API is conclusive proof MCM is installed; no probe needed.
    if MCM ~= nil then return true end
    local ok, loaded = pcall(Ext.Mod.IsModLoaded, MCM_UUID)
    if not ok then
        -- INDETERMINATE, never fail closed (review #1): declaring a working
        -- install "MCM-less" would brick the mod for a user who did everything
        -- right, whereas assuming present merely restores v0.6.2 behaviour.
        log("Ext.Mod.IsModLoaded unavailable - assuming MCM present (not going dormant)")
        return true
    end
    return loaded == true
end
local function mcmPresent()
    return MCM ~= nil
end

-- Debounced rebuild (design §3.3): one rebuild per event burst. Falls back to
-- an immediate rebuild if the timer facility is unavailable.
local rebuildPending = false
function MIR.RequestMcmRebuild(tag)
    if rebuildPending then return end
    rebuildPending = true
    local ok = pcall(function()
        Ext.Timer.WaitFor(200, function()
            rebuildPending = false
            local ok2, err = pcall(function()
                if MIR.RebuildAndRehydrate then MIR.RebuildAndRehydrate("mcm:" .. tostring(tag)) end
            end)
            if not ok2 then log("debounced rebuild ERROR: " .. tostring(err)) end
        end)
    end)
    if not ok then
        rebuildPending = false
        if MIR.RebuildAndRehydrate then MIR.RebuildAndRehydrate("mcm-immediate:" .. tostring(tag)) end
    end
end

-- ---------------- live-event subscriptions ----------------
-- Per-event idempotent subscription with retry (review B2/M5): the MCM global
-- may not be injected at MIR's file-load time (lifecycle undocumented), and a
-- partial failure must not orphan the succeeded subscriptions. ensureSubscribed
-- is re-run from SyncFromMCM once MCM is provably present.
local subs = {}
local function trySub(eventName, handler)
    if subs[eventName] then return end
    subs[eventName] = pcall(function()
        Ext.ModEvents.BG3MCM[eventName]:Subscribe(handler)
    end)
end

local function onSettingSaved(p)
    if not p or p.modUUID ~= ModuleUUID or not p.settingId then return end
    local ok, err = pcall(function() MIR.ApplyMcmSetting(p.settingId, p.value) end)
    if not ok then log("ApplyMcmSetting ERROR: " .. tostring(err)) end
end
local function onSettingReset(p)
    if not p or p.modUUID ~= ModuleUUID or not p.settingId then return end
    local ok, err = pcall(function() MIR.ApplyMcmSetting(p.settingId, p.defaultValue) end)
    if not ok then log("ApplyMcmSetting(reset) ERROR: " .. tostring(err)) end
end
local function onProfileActivated()
    local ok, err = pcall(function()
        log("MCM profile switch - full re-sync")
        MIR.SyncFromMCM("profile")
        MIR.RequestMcmRebuild("profile")
    end)
    if not ok then log("profile re-sync ERROR: " .. tostring(err)) end
end

local function ensureSubscribed()
    trySub("MCM_Setting_Saved", onSettingSaved)
    trySub("MCM_Setting_Reset", onSettingReset)
    trySub("MCM_Profile_Activated", onProfileActivated)
end

local tierTypeWarned = false
local function coerce(kind, value)
    -- nil ALWAYS stays nil: an unreadable value must be SKIPPED, never applied
    -- (review B1: `value == true` coerced nil to false and silently overwrote
    -- true-default guards like enabled/excludeNautiloid).
    if kind == "bool" then
        if type(value) == "boolean" then return value end
        return nil
    end
    if kind == "int" then
        local n = tonumber(value)
        return n and math.floor(n) or nil
    end
    -- v0.9: rarity tier. The MCM control is an ENUM whose value is the rarity NAME
    -- ("Common".."Legendary"); a number is accepted too so a console setter or a
    -- hand-edited settings file still works. Anything unrecognised stays nil, which
    -- means SKIP - never silently coerce to a tier the user did not choose.
    if kind == "tier" then
        -- MCM enum values are the CHOICE STRING. If a build ever hands back an index
        -- instead, blindly clamping it would shift every tier silently (a 0-based index
        -- would put Uncommon at Common), and AuditSettingIds would still say "OK" because
        -- it only tests for non-nil. Say so once rather than quietly mis-setting the window.
        if type(value) ~= "string" and not tierTypeWarned then
            tierTypeWarned = true
            log("rarity: MCM returned a " .. type(value) .. " for a tier setting, not the choice"
                .. " name. Treating it as a 1-5 tier number - verify with !mir_rarity.")
        end
        if type(value) == "string" then
            local t = MIR.RarityOrder and MIR.RarityOrder[value]
            if t then return t end
            local n = tonumber(value)
            if n then return math.max(1, math.min(5, math.floor(n))) end
            return nil
        end
        local n = tonumber(value)
        if not n then return nil end
        return math.max(1, math.min(5, math.floor(n)))
    end

    return value
end

-- Returns set, ok. On a read ERROR, ok=false and the caller must SKIP the
-- assignment (review S3: never wipe real user exclusions on a transient failure).
local function readListSetting(settingId)
    local set = {}
    local ok = pcall(function()
        local t = MCM.List.GetEnabled(settingId)
        for name, enabled in pairs(t or {}) do
            if enabled then set[tostring(name)] = true end
        end
    end)
    return set, ok
end

-- ---------------- read-only curated-exclusion views ----------------
-- (Alan, 2026-08-21: "list anything that is excluded there, including things
-- that are toggled excluded.") Two ReadOnly list_v2 settings on the Exclusion
-- lists tab mirror the mod-level curated fences, filtered to mods PRESENT in
-- the load order, by readable name. Never read back; published via MCM.Set
-- with shouldEmitEvent=false (their ids are not in our maps anyway).
local function modDisplayName(uuid)
    local name = nil
    pcall(function()
        local m = Ext.Mod.GetMod(uuid)
        if m and m.Info then name = tostring(m.Info.Name or "") end
    end)
    if not name or name == "" then return nil end
    return (name:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function buildElements(uuidSet, nameSet, enabledFlag)
    local elems, seen = {}, {}
    local function add(uuid, name)
        if seen[uuid] then return end
        seen[uuid] = true
        elems[#elems + 1] = { name = (name or "?") .. "  [" .. tostring(uuid):sub(1, 8) .. "]", enabled = enabledFlag }
    end
    for uuid in pairs(uuidSet) do
        local loaded = false
        pcall(function() loaded = Ext.Mod.IsModLoaded(uuid) end)
        if loaded then add(uuid, modDisplayName(uuid)) end
    end
    -- byName-fenced mods (review S2): walk the load order once; trivial cost
    if nameSet then
        pcall(function()
            for _, uuid in ipairs(Ext.Mod.GetLoadOrder() or {}) do
                local name = modDisplayName(uuid)
                if name and nameSet[name] then add(uuid, name) end
            end
        end)
    end
    table.sort(elems, function(a, b) return a.name < b.name end)
    return elems
end

-- MCM.Set returns boolean; the runtime list shape is lowercase
-- (enabled/elements/name) per MCM's ListV2Validator (review M1: no other shape passes).
local function setListValue(settingId, elems)
    local ok, r = pcall(function()
        return MCM.Set(settingId, { enabled = true, elements = elems }, ModuleUUID, false)
    end)
    if ok and r ~= false then return true, "ok" end
    return false, tostring(r)
end

function MIR.PublishCuratedLists()
    if not MIR.McmDetected then return end
    local u = buildElements(MIR.UtilityMods.byUuid, MIR.UtilityMods.byName, MIR.Config.excludeUtilityMods == true)
    local n = buildElements(MIR.NpcGearMods.byUuid, nil, true)
    local okU, infoU = setListValue("mir_view_utility_excluded", u)
    local okN, infoN = setListValue("mir_view_npcgear_excluded", n)
    log(("curated views: utility %d mod(s) %s; npc-gear %d mod(s) %s"):format(
        #u, okU and "published" or ("FAILED: " .. infoU),
        #n, okN and "published" or ("FAILED: " .. infoN)))
end

-- Live shares are rendered by the MIR Browser tab (client IMGUI) as text above
-- real sliders. The old blueprint list_v2 readout was removed 2026-08-21: MCM's
-- "ReadOnly" lists keep clickable checkboxes, so a display-only list reads as a
-- broken control (Alan: "the checkmark boxes ... cannot be unchecked").
-- Push the recomputed shares to the MIR Browser tab, which is now the ONLY UI
-- for category shares. Still needed after the raw tab was deleted: !mir_share, MCM
-- profile switches, container/pool toggles (v1.0: they drive the ON/LIMITED/OFF status) and pool rebuilds all change the numbers
-- behind the tab's back (Alan, 2026-08-24: the menus "don't update each other"). Debounced because slider events arrive per
-- drag tick.
local sharesPushPending = false
function MIR.PublishShares()
    if sharesPushPending then return end
    sharesPushPending = true
    local ok = pcall(function()
        Ext.Timer.WaitFor(200, function()
            sharesPushPending = false
            pcall(function()
                if MIRNet and MIRNet.Notice and MIR.SharesPayload then
                    MIRNet.Notice:Broadcast({ kind = "shares", shares = MIR.SharesPayload() })
                end
            end)
        end)
    end)
    if not ok then
        sharesPushPending = false
        pcall(function()
            if MIRNet and MIRNet.Notice and MIR.SharesPayload then
                MIRNet.Notice:Broadcast({ kind = "shares", shares = MIR.SharesPayload() })
            end
        end)
    end
end

-- Full sync: read every MCM value into MIR.Config. Does NOT rebuild the
-- catalog itself — callers decide (SessionLoaded lets Main's builder run
-- after; !mir_mcm_sync and profile switches request a rebuild).
-- v0.9 (review BL-1): a typo in a setting id is otherwise a SILENT no-op on BOTH the
-- full-sync and live-change paths - MCM would happily hold a value MIR never reads.
-- Report any id MCM does not recognise, once, loudly.
local auditDone = false
function MIR.AuditSettingIds()
    if not (MCM and MCM.Get) then return end
    local missing, n = {}, 0
    for _, m in ipairs(SETTING_MAP) do
        n = n + 1
        local ok, v = pcall(function() return MCM.Get(m.id) end)
        if not ok or v == nil then missing[#missing + 1] = m.id end
    end
    -- v1.0: the share ids too (second plan review SF-8) - a category whose mir_share_* is
    -- missing from the blueprint would otherwise reset to its default every session, silently.
    for id in pairs(SHARE_BY_ID) do
        n = n + 1
        local ok, v = pcall(function() return MCM.Get(id) end)
        if not ok or v == nil then missing[#missing + 1] = id end
    end
    if #missing > 0 then
        log("SETTING ID AUDIT FAILED - MCM does not know: " .. table.concat(missing, ", "))
        log("        those settings can NEVER apply. Check MCM_blueprint.json against SETTING_MAP / SHARE_CATS.")
    else
        log(("setting id audit OK (%d settings all resolved)"):format(n))
    end
end

function MIR.SyncFromMCM(reason)
    if not mcmPakLoaded() then
        -- Hard dependency missing: go dormant rather than injecting items the user
        -- has no way to configure or switch off.
        MIR.McmDetected = false
        MIR.McmMissing = true
        log("=====================================================================")
        log("MCM (Mod Configuration Menu) IS NOT INSTALLED.")
        log("MCM is a hard requirement for MIR, which has DISABLED ITSELF: no items")
        log("will be added to any container or corpse this session.")
        log("Install Mod Configuration Menu (Nexus 9162) and load it ABOVE MIR.")
        log("=====================================================================")
        return false
    end
    if not mcmPresent() then
        -- Pak is present but the API has not been injected yet: transient, not a
        -- user error. Keep the defaults and let ensureSubscribed/retry catch up.
        MIR.McmDetected = false
        log("MCM pak loaded but its API is not available yet - defaults active for now ("
            .. tostring(reason) .. ")")
        return false
    end
    MIR.McmMissing = false -- only cleared once MCM is provably usable (review #5)
    MIR.McmDetected = true
    ensureSubscribed() -- retry live-event hookup now that MCM is provably up (review B2)
    local applied, shadowed = 0, 0
    for _, m in ipairs(SETTING_MAP) do
        local v = nil
        pcall(function() v = MCM.Get(m.id) end)
        v = coerce(m.kind, v)
        if v ~= nil then
            if MIR.ConsoleOverrides[m.id] then
                shadowed = shadowed + 1
                log("console override on " .. m.id .. " replaced by MCM value (full sync)")
            end
            MIR.ConsoleOverrides[m.id] = nil -- per-key clear: only when actually applied (review S2)
            -- review S-3: the rarity rows write NESTED config through closures. A throw
            -- here would abort every remaining row, the clamp, the shares loop and the
            -- list loop - on a path whose result the caller discards. Isolate each row.
            local okA, errA = pcall(applySetting, m, v)
            if okA then applied = applied + 1
            else log("apply FAILED for " .. tostring(m.id) .. ": " .. tostring(errA)) end
        end
    end
    -- v0.9: clamp after the whole map is applied, so a band and its Act are both current.
    if MIR.NormalizeRarityWindow then MIR.NormalizeRarityWindow(nil) end
    for id, cat in pairs(SHARE_BY_ID) do
        local v = nil
        pcall(function() v = MCM.Get(id) end)
        v = coerce("int", v)

        if v ~= nil then
            MIR.Config.categoryWeights[cat] = v
            applied = applied + 1
        end
    end
    for id, field in pairs(LIST_IDS) do
        local set, ok = readListSetting(id)
        if ok then MIR.Config[field] = set
        else log("list read FAILED for " .. id .. " - keeping current exclusions") end
    end
    log(("synced %d settings from MCM (%s)%s"):format(applied, tostring(reason),
        shadowed > 0 and (" - " .. shadowed .. " console override(s) replaced") or ""))
    -- v0.9: run the id audit ONCE, after a real sync has proven MCM is answering.
    if not auditDone then auditDone = true pcall(MIR.AuditSettingIds) end
    MIR.PublishCuratedLists()
    return true
end

-- Live single-setting apply (MCM_Setting_Saved / MCM_Setting_Reset payloads).
function MIR.ApplyMcmSetting(settingId, value)
    -- display-only views: any user tick/untick/reset is immediately overwritten
    -- (MCM's ReadOnly only hides add/remove; checkboxes stay clickable — review S1)
    if settingId == "mir_view_utility_excluded" or settingId == "mir_view_npcgear_excluded" then
        MIR.PublishCuratedLists()
        return
    end
    MIR.ConsoleOverrides[settingId] = nil -- explicit MCM action always wins
    local cat = SHARE_BY_ID[settingId]
    if cat then
        local v = coerce("int", value)
        if v ~= nil then
            MIR.Config.categoryWeights[cat] = v
            log("share " .. cat .. " = " .. v)
            MIR.PublishShares() -- keep the MIR Browser tab in step
        end
        return
    end
    local field = LIST_IDS[settingId]
    if field then
        local set, ok = readListSetting(settingId) -- authoritative re-read
        if ok then
            MIR.Config[field] = set
            MIR.RequestMcmRebuild(settingId)
        else
            log("list read FAILED for " .. settingId .. " - keeping current exclusions")
        end
        return
    end
    local m = SETTING_BY_ID[settingId]
    if not m then return end -- not ours / future setting
    local v = coerce(m.kind, value)
    if v == nil then return end
    applySetting(m, v)
    -- "mir_rw_" is SEVEN characters. sub(1, 8) yielded "mir_rw_l" and matched NOTHING, so
    -- the direction-aware clamp was unreachable on every live MCM change and a user who
    -- raised a minimum above its maximum got the window collapsed to the MAXIMUM tier by
    -- EffectiveRarityWindow's fallback - the opposite of the tier they just picked.
    if settingId:sub(1, 7) == "mir_rw_" or settingId == "mir_rarity_window_enabled" then
        MIR.NormalizeRarityWindow(settingId)
    end
    log(settingId .. " = " .. tostring(v) .. (m.rebuild and " (rebuild queued)" or ""))
    if m.rebuild then MIR.RequestMcmRebuild(settingId)
    else MIR.PublishShares() end -- v1.0: draw-time toggles change the panel's status too
    if settingId == "mir_exclude_utility_mods" then MIR.PublishCuratedLists() end
end

-- First subscription attempt at file load (harmless if MCM's global/events
-- aren't up yet — SyncFromMCM retries via ensureSubscribed).
ensureSubscribed()

-- NOTE (review S1): the initial "session" sync is invoked by Main.lua's
-- SessionLoaded handler, immediately BEFORE its catalog build — a structural
-- ordering guarantee instead of relying on subscriber registration order.

Ext.RegisterConsoleCommand("mir_mcm_sync", function()
    local ok, err = pcall(function()
        if MIR.SyncFromMCM("console") then MIR.RequestMcmRebuild("console") end
    end)
    if not ok then log("mir_mcm_sync ERROR: " .. tostring(err)) end
    if MIR.FlushLog then MIR.FlushLog() end
end)
