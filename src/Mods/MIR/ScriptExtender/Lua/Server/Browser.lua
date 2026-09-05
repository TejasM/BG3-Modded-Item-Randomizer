-- MIR exclusion browser — SERVER side (Phase 3 chunk 3, design §4).
-- Builds the per-mod/per-item dataset the client IMGUI tab renders, and is the
-- SINGLE WRITER for the two exclusion list settings. Loads after Catalog/MCMSync,
-- before Main (net handlers only fire post-session, so order is not critical).
MIR = MIR or {}

local function log(m)
    if MIR.Log then MIR.Log("[browser] " .. tostring(m))
    else Ext.Utils.Print("[MIR][browser] " .. tostring(m)) end
end

-- Dataset generation: bumped on every catalog (re)build so the client can tell
-- its cache is stale. Incremented by MIR.BrowserBumpGen (called from Main's rebuild).
MIR.BrowserGen = 0
function MIR.BrowserBumpGen()
    MIR.BrowserGen = (MIR.BrowserGen or 0) + 1
end

-- ---------------- paged query (design §4.2, revised 2026-08-21) ----------------
-- SE caps one net message at 1,048,575 bytes and silently drops oversized ones,
-- so the client NEVER receives the whole catalog: it asks for one page and the
-- server does the filtering. Page payloads are a few KB.
local PAGE = 100

local nameCache = {}
local function modNameOf(uuid)
    local cached = nameCache[uuid]
    if cached then return cached end
    local name = nil
    pcall(function()
        local mod = Ext.Mod.GetMod(uuid)
        if mod and mod.Info then name = tostring(mod.Info.Name or "") end
    end)
    if name == nil or name == "" then name = "(unknown mod " .. tostring(uuid):sub(1, 8) .. ")" end
    nameCache[uuid] = name
    return name
end

local function lower(s2) return tostring(s2 or ""):lower() end

-- Aggregate per-mod counts across pool + userExcluded + tableExcluded. Cached per catalog
-- generation (review S5: this walked ~6.2k entries + 430 GetMod calls on every
-- page turn, search keystroke and post-click refresh).
local idxCache, idxGen = nil, -1
local function modIndex()
    if idxCache and idxGen == (MIR.BrowserGen or 0) then return idxCache end
    local byMod = {}
    local function feed(entry, excluded, placed)
        local key = entry.mod or ""
        local m = byMod[key]
        if not m then m = { uuid = key, count = 0, excludedItems = 0, placedItems = 0 } byMod[key] = m end
        m.count = m.count + 1
        if excluded then m.excludedItems = m.excludedItems + 1 end
        if placed then m.placedItems = m.placedItems + 1 end
    end
    -- review B1: this used to hardcode placed=false, so a force-included item (placed by its
    -- mod, but deliberately allowed into the pool) silently dropped out of the per-mod placed
    -- count. The count means "items this mod places in the world", which does not stop being
    -- true just because the user let one through.
    for _, e in pairs(MIR.Catalog.byTemplate or {}) do feed(e, false, e.placed == true) end
    for _, e in pairs(MIR.Catalog.userExcluded or {}) do feed(e, true, false) end
    -- items fenced because the mod already distributes them via treasure tables:
    -- shown so the user can SEE why they are missing (§5.1 #13)
    for _, e in pairs(MIR.Catalog.tableExcluded or {}) do feed(e, false, true) end
    local list = {}
    for uuid, m in pairs(byMod) do
        m.mod = modNameOf(uuid)
        m.excluded = MIR.Config.excludedModUuids[uuid] and true or false
        list[#list + 1] = m
    end
    table.sort(list, function(a, b)
        if a.count ~= b.count then return a.count > b.count end
        return a.mod < b.mod
    end)
    idxCache, idxGen = list, (MIR.BrowserGen or 0)
    return list
end

-- An item can be BOTH user-excluded and treasure-distributed. userExcluded wins
-- the storage slot, so compute "placed" from the entry itself — otherwise the
-- browser row would say nothing and unticking it would appear to do nothing
-- (review S4).
local function isPlaced(e)
    -- with the fence off the item IS in the pool; labelling it "placed by mod"
    -- would be a lie (review S3)
    if not (MIR.Config and MIR.Config.excludeTreasureTableItems) then return false end
    if e.placed then return true end
    -- review S7: the fence is MODDED, NON-CONSUMABLE only. Without this guard a vanilla
    -- item sitting in an indexed vanilla table was labelled "placed by mod" whenever
    -- includeBaseGame was on, and would have been offered a force-include button that
    -- could never do anything.
    if e.base or e.consumable then return false end
    if not MIR.HasTreasureDistribution then return false end
    local ok, res = pcall(function() return MIR.HasTreasureDistribution(e.stat, e.tplName) end)
    return (ok and res) and true or false
end

-- query = { mode = "mods"|"items", modUuid = <uuid>, search = <string>, page = <1-based> }
function MIR.BrowserQuery(query)
    query = type(query) == "table" and query or {}
    local page = math.max(1, math.floor(tonumber(query.page) or 1))
    local search = lower(query.search)
    if not MIR.Catalog.built then
        return { gen = MIR.BrowserGen or 0, mode = "mods", rows = {}, total = 0, page = 1, pages = 1,
                 note = "catalog not built", shares = MIR.SharesPayload() }
    end

    if query.mode == "items" and query.modUuid then
        local rows = {}
        local function collect(tbl, excluded, placed)
            for _, e in pairs(tbl or {}) do
                if e.mod == query.modUuid then
                    local nm = e.name or e.stat or "?"
                    if search == "" or lower(nm):find(search, 1, true) or lower(e.stat):find(search, 1, true) then
                        local isP = (placed or isPlaced(e)) or nil
                        rows[#rows + 1] = { id = e.template, name = nm, rarity = e.rarity or "",
                                            cat = e.category or "", excluded = excluded,
                                            placed = isP,
                                            -- v1.0.1: say where a scoped entry can appear
                                            scope = (e.clutterOnly and "clutter") or (e.bookshelfOnly and "bookshelf") or nil,
                                            forced = e.forced or nil,
                                            -- the duplicate warning, built server-side so the
                                            -- client needs no lookup. Deliberately names the
                                            -- CONTAINER, not the mod: entry.mod is the mod that
                                            -- DEFINES the item, which is not necessarily the one
                                            -- that places it (review S2).
                                            src = (isP and (e.placedVia or e.placedTable)) and
                                                  tostring(e.placedVia or e.placedTable) or nil }

                    end
                end
            end
        end
        collect(MIR.Catalog.byTemplate, false, false)
        collect(MIR.Catalog.userExcluded, true, false)
        collect(MIR.Catalog.tableExcluded, false, true)
        table.sort(rows, function(a, b) return a.name < b.name end)
        local total = #rows
        local pages = math.max(1, math.ceil(total / PAGE))
        if page > pages then page = pages end
        local out = {}
        for i = (page - 1) * PAGE + 1, math.min(page * PAGE, total) do out[#out + 1] = rows[i] end
        return { gen = MIR.BrowserGen or 0, mode = "items", modUuid = query.modUuid,
                 modName = modNameOf(query.modUuid), rows = out, total = total, page = page, pages = pages,
                 counts = MIR.CountExcluded(), shares = MIR.SharesPayload() }
    end

    -- mods mode
    local all = modIndex()
    local rows = {}
    for _, m in ipairs(all) do
        if search == "" or lower(m.mod):find(search, 1, true) then
            rows[#rows + 1] = { id = m.uuid, name = m.mod, count = m.count,
                                excluded = m.excluded, excludedItems = m.excludedItems,
                                placedItems = m.placedItems }
        end
    end
    local total = #rows
    local pages = math.max(1, math.ceil(total / PAGE))
    if page > pages then page = pages end
    local out = {}
    for i = (page - 1) * PAGE + 1, math.min(page * PAGE, total) do out[#out + 1] = rows[i] end
    return { gen = MIR.BrowserGen or 0, mode = "mods", rows = out, total = total, page = page, pages = pages,
             counts = MIR.CountExcluded(), shares = MIR.SharesPayload() }
end

function MIR.CountExcluded()
    local m, i = 0, 0
    for _ in pairs(MIR.Config.excludedModUuids) do m = m + 1 end
    for _ in pairs(MIR.Config.excludedTemplates) do i = i + 1 end
    return { mods = m, items = i }
end

-- Shares payload for the client tab (v1.0: label + weight + DERIVED status + display text).
-- A category missing from SHARE_ORDER never reaches the client at all (plan review BL-4), so
-- this list must name every key in Config.categoryWeights.
local SHARE_ORDER = { "weapon", "shield", "torso", "helmet", "gloves", "boots", "cloak",
                      "ring", "amulet", "vanityClothing", "vanityBoots", "underwear",
                      "potion", "arrow", "alchemyIngredient", "scroll" }
function MIR.SharesPayload()
    if not MIR.ComputeShares then return {} end
    local byCat = {}
    local ok, err = pcall(function()
        for _, r in ipairs(MIR.ComputeShares()) do byCat[r.cat] = r end
    end)
    if not ok then
        -- Diff review SF-2: an empty payload used to make the shares section silently never
        -- appear at all. Log it, and hand the client a sentinel it shows as a status line.
        log("ComputeShares ERROR: " .. tostring(err))
        return { { cat = "_error", label = "Category shares", weight = 0, status = "off", error = true,
                   text = "ERROR computing category status - see MIR_log.txt", active = false, hasItems = false } }
    end
    local out = {}
    for _, cat in ipairs(SHARE_ORDER) do
        local r = byCat[cat]
        if r then
            out[#out + 1] = { cat = cat, label = r.label, weight = math.floor(r.weight or 0),
                              -- "on" | "limited" | "off" | "empty" - the client only needs
                              -- this to decide whether the slider is live; the row TEXT is
                              -- built server-side so the two can never disagree.
                              status = r.status, text = r.text,
                              pct = r.pct and (math.floor(r.pct * 10 + 0.5) / 10) or nil,
                              active = r.active and true or false, hasItems = r.hasItems and true or false }
        end
    end
    return out
end
-- v1.0: MIR.SetCategoryIncluded and its MCM key mir_cat_* are DELETED (see Config.lua).

-- Set one category weight: mirror into Config and persist through MCM.
function MIR.SetShare(cat, value)
    local v = tonumber(value)
    if not cat or not v then return false end
    v = math.max(0, math.min(100, math.floor(v)))
    if MIR.Config.categoryWeights[cat] == nil then return false end
    MIR.Config.categoryWeights[cat] = v
    if MCM ~= nil and MIR.McmDetected then
        local ok, res = pcall(function()
            return MCM.Set("mir_share_" .. cat, v, ModuleUUID, true)
        end)
        if not ok or res == false then
            log("MCM.Set FAILED for mir_share_" .. cat .. " (" .. tostring(res) .. ") - session-only")
        end
    end
    return true
end

-- ---------------- single-writer exclusion path ----------------
-- payload = { mods = { [uuid] = true/false }, items = { [tplId] = true/false } }
-- true = exclude, false = un-exclude. Writes MCM list settings (authoritative
-- persistence), mirrors into Config, then rebuilds. Rebuild is invoked DIRECTLY
-- (design §4.4/S4): never rely on MCM emitting an event for List.SetEnabled.
local function applyOne(settingId, cfgField, key, want)
    -- MCM.List.SetEnabled RETURNS false (without raising) when the setting table
    -- is missing or validation fails — pcall alone would report success and the
    -- change would never persist (review B1). Check the return value.
    local ok, res = pcall(function()
        return MCM.List.SetEnabled(settingId, key, want and true or false, ModuleUUID)
    end)
    if not ok or res == false then
        log("MCM.List.SetEnabled FAILED for " .. settingId .. " / " .. tostring(key) .. " (" .. tostring(res) .. ")")
        return false
    end
    if want then MIR.Config[cfgField][key] = true else MIR.Config[cfgField][key] = nil end
    return true
end

function MIR.ApplyExcludeChanges(payload)
    if type(payload) ~= "table" then return 0, 0 end
    local okCount, failCount = 0, 0
    local mcmUp = (MCM ~= nil) and MIR.McmDetected
    for uuid, want in pairs(payload.mods or {}) do
        if mcmUp then
            if applyOne("mir_excluded_mod_uuids", "excludedModUuids", uuid, want) then okCount = okCount + 1
            else failCount = failCount + 1 end
        else -- MCM absent: session-only change, still honour it
            if want then MIR.Config.excludedModUuids[uuid] = true else MIR.Config.excludedModUuids[uuid] = nil end
            okCount = okCount + 1
        end
    end
    for tpl, want in pairs(payload.items or {}) do
        if mcmUp then
            if applyOne("mir_excluded_templates", "excludedTemplates", tpl, want) then okCount = okCount + 1
            else failCount = failCount + 1 end
        else
            if want then MIR.Config.excludedTemplates[tpl] = true else MIR.Config.excludedTemplates[tpl] = nil end
            okCount = okCount + 1
        end
    end
    -- v0.7 force-include. Same applyOne path as the exclusion lists, so it persists through
    -- MCM and triggers the same rebuild - the fence runs at catalog build, so a rebuild is
    -- REQUIRED for a force-include to take effect at all.
    local forcedNote = nil
    for tpl, want in pairs(payload.forceInclude or {}) do
        if mcmUp then
            if applyOne("mir_force_included_templates", "forceIncludedTemplates", tpl, want) then okCount = okCount + 1
            else failCount = failCount + 1 end
        else
            if want then MIR.Config.forceIncludedTemplates[tpl] = true else MIR.Config.forceIncludedTemplates[tpl] = nil end
            okCount = okCount + 1
        end
        if want then
            -- The whole point of the feature: say plainly what was just accepted.
            local e = (MIR.Catalog.tableExcluded and MIR.Catalog.tableExcluded[tpl])
                   or (MIR.Catalog.byTemplate and MIR.Catalog.byTemplate[tpl])
            local where = e and (e.placedVia or e.placedTable) or nil
            forcedNote = "Allowed in. Also placed in the world"
                .. (where and (" (" .. tostring(where) .. ")") or "")
                .. " - you may find two."
            -- review M5/S1.2: an exclusion silently outranks this, so do not let the user
            -- believe something happened when nothing will.
            if MIR.Config.excludedTemplates[tpl] then
                forcedNote = "No effect: that item is on your excluded list, which wins. Un-exclude it first."
            elseif e and e.mod and MIR.Config.excludedModUuids[e.mod] then
                forcedNote = "No effect: that item's mod is excluded, which wins. Re-include the mod first."
            end
        else
            forcedNote = "Allowed-in removed - the placement filter fences that item again."
        end
    end

    log(("applied %d exclusion change(s)%s"):format(okCount, failCount > 0 and (", " .. failCount .. " FAILED") or ""))

    if okCount > 0 then
        -- the fence runs at CATALOG BUILD time, so a force-include cannot take effect
        -- without this rebuild
        if MIR.RebuildAndRehydrate then MIR.RebuildAndRehydrate("browser") end
    end
    return okCount, failCount, forcedNote
end


-- Clear every user exclusion (both lists). MCM has no element-remove API, so a
-- full-value MCM.Set is used to empty each list [MCM-API §8].
function MIR.ClearAllExcludes()
    local n = 0
    for _ in pairs(MIR.Config.excludedModUuids) do n = n + 1 end
    for _ in pairs(MIR.Config.excludedTemplates) do n = n + 1 end
    local clearedMods, clearedItems = true, true
    if MCM ~= nil and MIR.McmDetected then
        -- MCM.Set returns a boolean; a discarded false would clear Config while
        -- MCM keeps the old lists, and the next sync would silently restore them
        -- (review B2). Only clear what actually persisted.
        local okM, resM = pcall(function()
            return MCM.Set("mir_excluded_mod_uuids", { enabled = true, elements = {} }, ModuleUUID, false)
        end)
        clearedMods = (okM and resM ~= false)
        local okI, resI = pcall(function()
            return MCM.Set("mir_excluded_templates", { enabled = true, elements = {} }, ModuleUUID, false)
        end)
        clearedItems = (okI and resI ~= false)
        if not clearedMods then log("CLEAR FAILED for mir_excluded_mod_uuids (" .. tostring(resM) .. ") - kept in place") end
        if not clearedItems then log("CLEAR FAILED for mir_excluded_templates (" .. tostring(resI) .. ") - kept in place") end
    end
    if clearedMods then MIR.Config.excludedModUuids = {} end
    if clearedItems then MIR.Config.excludedTemplates = {} end
    if clearedMods or clearedItems then
        log("cleared " .. n .. " user exclusion(s)")
        if MIR.RebuildAndRehydrate then MIR.RebuildAndRehydrate("browser-clear") end
    end
    return n, (clearedMods and clearedItems)
end

-- ---------------- console equivalents (work without the UI) ----------------
-- v0.7: let ONE placement-fenced item back into the pool, accepting a possible duplicate.
Ext.RegisterConsoleCommand("mir_forceinclude", function(_, arg, _2)
    local ok, err = pcall(function()
        if arg == nil or arg == "" then
            log("usage: !mir_forceinclude <itemTemplateUuid> | remove <uuid> | list | clear")
            return
        end
        if arg == "list" then
            local n = 0
            for tpl in pairs(MIR.Config.forceIncludedTemplates or {}) do
                n = n + 1
                local e = (MIR.Catalog.byTemplate and MIR.Catalog.byTemplate[tpl])
                     or (MIR.Catalog.tableExcluded and MIR.Catalog.tableExcluded[tpl])
                local nm = e and (e.name or e.stat) or "(name unavailable)"
                local where = e and (e.placedVia or e.placedTable) or "?"
                log(("allowed in %d: %s [%s] - also placed in %s"):format(n, nm, tpl, tostring(where)))
            end
            log("allowed-in total: " .. n .. " item(s)")
            return
        end
        if arg == "clear" then
            local n = 0
            local payload = {}
            for tpl in pairs(MIR.Config.forceIncludedTemplates or {}) do payload[tpl] = false n = n + 1 end
            if n == 0 then log("nothing to clear") return end
            MIR.ApplyExcludeChanges({ forceInclude = payload })
            log("cleared " .. n .. " allowed-in item(s) - the placement filter fences them again")
            return
        end
        if arg == "remove" then
            if not _2 or _2 == "" then log("usage: !mir_forceinclude remove <uuid>") return end
            MIR.ApplyExcludeChanges({ forceInclude = { [_2] = false } })
            log("allowed-in removed for " .. _2)
            return
        end
        local _, _, note = MIR.ApplyExcludeChanges({ forceInclude = { [arg] = true } })
        log(note or ("allowed in: " .. arg))
    end)
    if not ok then log("mir_forceinclude ERROR: " .. tostring(err)) end
    if MIR.FlushLog then MIR.FlushLog() end
end)

Ext.RegisterConsoleCommand("mir_exclude", function(_, what, id)
    -- !mir_exclude mod <uuid> | item <templateUuid> | clear
    local ok, err = pcall(function()
        if what == "clear" then MIR.ClearAllExcludes() return end
        if not id or id == "" then log("usage: !mir_exclude mod|item <uuid>  |  !mir_exclude clear") return end
        if what == "mod" then MIR.ApplyExcludeChanges({ mods = { [id] = true } })
        elseif what == "item" then MIR.ApplyExcludeChanges({ items = { [id] = true } })
        else log("usage: !mir_exclude mod|item <uuid>  |  !mir_exclude clear") end
    end)
    if not ok then log("mir_exclude ERROR: " .. tostring(err)) end
    if MIR.FlushLog then MIR.FlushLog() end
end)

Ext.RegisterConsoleCommand("mir_include", function(_, what, id)
    -- un-exclude: !mir_include mod <uuid> | item <templateUuid>
    local ok, err = pcall(function()
        if not id or id == "" then log("usage: !mir_include mod|item <uuid>") return end
        if what == "mod" then MIR.ApplyExcludeChanges({ mods = { [id] = false } })
        elseif what == "item" then MIR.ApplyExcludeChanges({ items = { [id] = false } })
        else log("usage: !mir_include mod|item <uuid>") end
    end)
    if not ok then log("mir_include ERROR: " .. tostring(err)) end
    if MIR.FlushLog then MIR.FlushLog() end
end)

-- Emergency path for setting category weights without the MIR Browser tab (e.g.
-- if the custom tab ever failed to register). The browser tab is the ONLY UI for
-- shares: the blueprint settings still exist as storage but are never shown.
Ext.RegisterConsoleCommand("mir_share", function(_, cat, value)
    local ok, err = pcall(function()
        if not cat then
            log("usage: !mir_share <category> <0-100>  |  !mir_share list")
            return
        end
        if cat == "list" then
            -- v1.0: prints the DERIVED status the browser shows (review BL-6: this was the
            -- one unguarded reader of the deleted categoryIncluded table)
            local byCat = {}
            pcall(function() for _, r in ipairs(MIR.SharesPayload()) do byCat[r.cat] = r end end)
            for _, c in ipairs(SHARE_ORDER) do -- stable order (review M3)
                local w = MIR.Config.categoryWeights[c]
                local r = byCat[c]
                log(("  %-20s weight=%-3d %s"):format(
                    c, math.floor(tonumber(w) or 0), r and tostring(r.text) or "?"))
            end
            return
        end
        if MIR.Config.categoryWeights[cat] == nil then
            log("unknown category '" .. tostring(cat) .. "' - run !mir_share list")
            return
        end
        if value == nil then
            log(cat .. " weight=" .. tostring(MIR.Config.categoryWeights[cat]))
            return
        end
        if MIR.SetShare and MIR.SetShare(cat, value) then
            log(("%s weight=%d"):format(cat, MIR.Config.categoryWeights[cat]))
            if MIR.PublishShares then MIR.PublishShares() end
        else
            log("could not set " .. tostring(cat) .. " to " .. tostring(value))
        end
    end)
    if not ok then log("mir_share ERROR: " .. tostring(err)) end
    if MIR.FlushLog then MIR.FlushLog() end
end)

-- v1.0: !mir_category is DELETED with the include checkbox it drove. Weight 0 (!mir_share
-- <category> 0) is the only browser-side "off"; container-scoped categories are switched
-- off on their container setting instead.

Ext.RegisterConsoleCommand("mir_excludes", function()
    -- list current user exclusions with readable names
    local ok, err = pcall(function()
        local n = 0
        for uuid in pairs(MIR.Config.excludedModUuids) do
            local name = uuid
            pcall(function()
                local mod = Ext.Mod.GetMod(uuid)
                if mod and mod.Info then name = tostring(mod.Info.Name or uuid) end
            end)
            log("excluded MOD: " .. name .. " [" .. uuid .. "]")
            n = n + 1
        end
        for tpl in pairs(MIR.Config.excludedTemplates) do
            -- look in EVERY catalog table, not just userExcluded: an excluded item
            -- can sit in tableExcluded (also placement-fenced) and, after the fence
            -- or the exclusion is lifted, back in the live pool. Falling through to
            -- "?" made the command useless exactly when it was needed (open item 8).
            local cat = MIR.Catalog or {}
            local e = (cat.userExcluded and cat.userExcluded[tpl])
                   or (cat.tableExcluded and cat.tableExcluded[tpl])
                   or (cat.byTemplate and cat.byTemplate[tpl]) or nil
            local label = e and (e.name or e.stat) or nil
            if not label then
                pcall(function()
                    local tmpl = Ext.Template.GetRootTemplate(tpl)
                    if tmpl then label = tostring(tmpl.Name or "") end
                end)
            end
            log("excluded ITEM: " .. ((label ~= nil and label ~= "") and label or "(name unavailable)")
                .. " [" .. tpl .. "]")
            n = n + 1
        end
        log("total user exclusions: " .. n)
    end)
    if not ok then log("mir_excludes ERROR: " .. tostring(err)) end
    if MIR.FlushLog then MIR.FlushLog() end
end)


-- ---------------- net handlers (design §4.4) ----------------
-- Authority: reads are open, WRITES are host-only (a client-side guard alone
-- would still trust arbitrary clients). Host check = MCM's proven pattern.
local HOST_USER = 65537 -- 0x10001: the host's user id (single-player short-circuit)
local function isHostUser(user)
    if user == nil then return true end -- local/dispatch without a user id
    if user == HOST_USER then return true end
    local ok, result = pcall(function()
        -- Osi.GetHostCharacter() returns a prefixed GUIDSTRING (S_Player_..._<uuid>);
        -- entity.Uuid.EntityUuid is the bare 36-char uuid (review S4).
        local host = tostring(Osi.GetHostCharacter() or ""):sub(-36)
        for _, entity in pairs(Ext.Entity.GetAllEntitiesWithComponent("ClientControl") or {}) do
            local uid = entity.UserReservedFor and entity.UserReservedFor.UserID or nil
            if uid == user then
                return entity.Uuid and entity.Uuid.EntityUuid == host
            end
        end
        return false
    end)
    return ok and result or false
end

if MIRNet and MIRNet.Browse then
    MIRNet.Browse:SetRequestHandler(function(data, user)
        local ok, res = pcall(function() return MIR.BrowserQuery(data) end)
        if ok then return res end
        log("query ERROR: " .. tostring(res))
        return { gen = MIR.BrowserGen or 0, mode = "mods", rows = {}, total = 0, page = 1, pages = 1,
                 note = "query failed" }
    end)
end

if MIRNet and MIRNet.Apply then
    MIRNet.Apply:SetRequestHandler(function(data, user)
        if not isHostUser(user) then
            log("write REFUSED from non-host user " .. tostring(user))
            -- return the true shares so a refused client's widget snaps back
            -- instead of showing a value the server never accepted (review M1)
            local sh = nil
            pcall(function() sh = MIR.SharesPayload() end)
            return { ok = false, note = "The host manages MIR settings.", shares = sh }
        end
        -- share writes are draw-time only: NO catalog rebuild
        if data and data.share and data.share.cat then
            local okS, done = pcall(function() return MIR.SetShare(data.share.cat, data.share.value) end)
            local sh = nil
            pcall(function() sh = MIR.SharesPayload() end)
            return { ok = (okS and done) and true or false, shares = sh, gen = MIR.BrowserGen or 0 }
        end
        -- v1.0 (review BL-7): the catInclude branch is gone. A payload this handler does not
        -- recognise (a stale client, say) must be REFUSED, not fall through to
        -- ApplyExcludeChanges - which would find nothing to do, return 0, and the client
        -- would render "Applied." for a change that never happened.
        if not (type(data) == "table" and (data.clear or data.mods or data.items or data.forceInclude)) then
            log("apply REFUSED: unrecognised payload")
            return { ok = false, note = "Unknown request - the MIR Browser and MIR's server side disagree; restart the game." }
        end
        local ok, a, b, note = pcall(function()
            if data and data.clear then
                local n = MIR.ClearAllExcludes()
                return n, 0
            end
            return MIR.ApplyExcludeChanges(data)
        end)
        if not ok then
            log("apply ERROR: " .. tostring(a))
            return { ok = false, note = "apply failed" }
        end
        local counts, sh = nil, nil
        pcall(function() counts = MIR.CountExcluded() end)
        pcall(function() sh = MIR.SharesPayload() end)
        return { ok = true, applied = a or 0, failed = b or 0, gen = MIR.BrowserGen or 0,
                 counts = counts, shares = sh, note = note }
    end)
end
