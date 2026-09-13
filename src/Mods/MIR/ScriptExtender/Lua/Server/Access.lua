-- Source-aware access control. Move exact instances into off-stage storage;
-- never destroy equipment or reconstruct a replacement from its template.
MIR.Access = {}
local A = MIR.Access
local scans, sequence, moving = {}, 0, {}
local function read(object, key)
    local ok, value = pcall(function() return object[key] end)
    if ok then return value end
end
local function id(value) return tostring(value or ""):sub(-36) end
local function state()
    local vars = Ext.Vars.GetModVariables(ModuleUUID)
    local s = vars.AccessState or { held={}, vaults={}, provenance={} }
    s.sources = s.sources or {}
    return s, vars
end
local function save(s) Ext.Vars.GetModVariables(ModuleUUID).AccessState = s end
local function log(message) MIR.Log("[access] " .. message) end
local function guarded(fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then log("ERROR: " .. tostring(err)) end
    end
end

function A.Entry(item)
    local template = id(Osi.GetTemplate(item))
    return MIR.Catalog.byTemplate and MIR.Catalog.byTemplate[template]
end

function A.Convenience(holder)
    local template = id(Osi.GetTemplate(holder))
    local overrides = MIR.Config.convenienceContainers or {}
    if overrides[id(holder)] or overrides[template] then return true end
    local root = Ext.Template.GetTemplate(id(holder)) or Ext.Template.GetRootTemplate(template)
    if not root then return false end
    local name = tostring(read(root, "Name") or ""):lower()
    -- Do not reuse the old broad 'storage', 'traveller', 'tut_' name heuristic.
    if name:match("^cont_playercampchest_[abcd]$") then return true end
    for _, tableName in pairs(read(root, "InventoryList") or {}) do
        if (type(tableName) == "string" and tableName or read(tableName, "Object")) == "TUT_Chest_Potions" then return true end
    end
    return false
end

function A.ShouldHold(entry, kind, provenance, context)
    if not MIR.Config.enabled or MIR.McmMissing then return false end
    if not entry or not entry.managed or entry.base or entry.power.exempt then return false end
    if provenance == "player" or provenance == "unknown" or provenance == nil then return false end
    if kind == "convenience" then return MIR.Config.suppressConvenience end
    if kind == "merchant" then
        return MIR.Config.gateMerchants and not MIR.Power.Allowed(entry, context)
    end
    return false
end

local function vault(holder, s)
    local key = id(holder)
    local existing = s.vaults[key]
    if existing and Ext.Entity.Get(existing) then return existing end
    -- Verified against the installed game's Shared root templates (OBJ_Backpack).
    local backpack = "47805d79-88f1-4933-86eb-f78f67cbc33f"
    local x, y, z = Osi.GetPosition(holder)
    local created = Osi.CreateAt(backpack, x, y, z, 0, 0, "")
    if not created or Osi.IsContainer(created) ~= 1 then error("Could not create holding inventory") end
    Osi.SetOnStage(created, 0)
    s.vaults[key] = id(created)
    save(s)
    return created
end

function A.Hold(item, holder, kind, entry)
    local key = id(item)
    local s = state()
    if s.held[key] or moving[key] then return end
    if Osi.IsInInventoryOf(item, holder) ~= 1 then return end
    local amount, maximum = Osi.GetStackAmount(item)
    if amount ~= 1 or maximum ~= 1 then
        log("skipped stackable equipment to preserve instance identity: " .. entry.stat)
        return
    end
    local storage = vault(holder, s)
    -- Persist intent before moving; a failed move is retried, never a new spawn.
    s.held[key] = { holder=id(holder), vault=id(storage), kind=kind, template=entry.template }
    save(s)
    moving[key] = true
    local ok, err = pcall(Osi.ToInventory, item, storage, 1, 0, 0)
    moving[key] = nil
    if not ok then error(err) end
    log("held " .. entry.stat .. " from " .. kind)
end

function A.Release(holder, force)
    local s = state()
    local context = MIR.Power.Context()
    for item, record in pairs(s.held) do
        if (not holder or record.holder == id(holder)) and Ext.Entity.Get(record.holder)
            and Ext.Entity.Get(item) then
            local entry = MIR.Catalog.byTemplate and MIR.Catalog.byTemplate[record.template]
            local restore = force or not MIR.Config.enabled or (entry and not entry.managed)
                or (record.kind == "convenience" and not MIR.Config.suppressConvenience)
                or (record.kind == "merchant" and (not MIR.Config.gateMerchants
                    or (entry and MIR.Power.Allowed(entry, context))))
            if restore then
                if Osi.IsInInventoryOf(item, record.vault) == 1 then
                    moving[item] = true
                    local ok, err = pcall(Osi.ToInventory, item, record.holder, 1, 0, 0)
                    moving[item] = nil
                    if not ok then log("restore failed: " .. tostring(err)) end
                end
                if Osi.IsInInventoryOf(item, record.holder) == 1 then
                    s.held[item] = nil
                end
            elseif Osi.IsInInventoryOf(item, record.holder) == 1 then
                moving[item] = true
                local ok, err = pcall(Osi.ToInventory, item, record.vault, 1, 0, 0)
                moving[item] = nil
                if not ok then log("hold retry failed: " .. tostring(err)) end
            end
        end
    end
    save(s)
end

function A.Process(item, holder, kind)
    if not MIR.Catalog.built then return end
    local s = state()
    local provenance = s.provenance[id(item)]
    local entry = A.Entry(item)
    if entry and not entry.managed and MIR.DeliverySource then
        entry.deliverySource = MIR.DeliverySource(entry.stat, entry.tplName, entry.template)
        entry.managed = not entry.base and not entry.power.exempt and entry.deliverySource ~= nil
    end
    if A.ShouldHold(entry, kind, provenance, MIR.Power.Context()) then
        A.Hold(item, holder, kind, entry)
    end
end

function A.Scan(holder, kind)
    if not MIR.Catalog.built then return end
    A.Release(holder)
    sequence = sequence + 1
    local event = "MIR_ACCESS_" .. sequence
    scans[event] = {holder=holder, kind=kind}
    Osi.IterateInventory(holder, event, event .. "_END")
end

Ext.Osiris.RegisterListener("EntityEvent", 2, "after", guarded(function(item, event)
    local scan = scans[event]
    if scan then A.Process(item, scan.holder, scan.kind); return end
    local base = event:match("^(MIR_ACCESS_%d+)_END$")
    if base then scans[base] = nil end
end))

Ext.Osiris.RegisterListener("AddedTo", 3, "after", guarded(function(item, holder, addType)
    local key = id(item)
    local s = state()
    if moving[key] or s.held[key] then return end
    local top = Osi.GetInventoryOwner(holder) or holder
    if Osi.IsPlayer(holder) == 1 or Osi.IsPlayer(top) == 1 then
        s.provenance[key] = "player"
    elseif s.provenance[key] ~= "player" then
        -- 'Regular' conflates script gifts, deposits and sales. Never guess.
        if addType == "TradeTreasure" then s.provenance[key] = "merchant"
        elseif addType == "Treasure" and A.Convenience(holder) then s.provenance[key] = "convenience"
        else s.provenance[key] = "unknown" end
    end
    if s.provenance[key] == "merchant" or s.provenance[key] == "convenience" then
        s.sources[id(Osi.GetTemplate(item))] = s.provenance[key]
    end
    save(s)
    if s.provenance[key] == "merchant" then A.Process(item, holder, "merchant")
    elseif s.provenance[key] == "convenience" then A.Process(item, holder, "convenience") end
end))

Ext.Osiris.RegisterListener("TemplateOpening", 3, "before", guarded(function(_, holder, player)
    if Osi.IsPlayer(player) == 1 and A.Convenience(holder) then A.Scan(holder, "convenience") end
end))
Ext.Osiris.RegisterListener("RequestTrade", 4, "before", guarded(function(player, trader)
    if Osi.IsPlayer(player) == 1 then A.Scan(trader, "merchant") end
end))
Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "after", guarded(function()
    A.Release()
end))
Ext.Osiris.RegisterListener("SavegameLoadStarted", 0, "before", function()
    scans, sequence, moving = {}, 0, {}
end)

Ext.RegisterConsoleCommand("mir_access", guarded(function(_, command)
    if command == "restore" then
        MIR.Config.suppressConvenience, MIR.Config.gateMerchants = false, false
        MIR.MarkConsoleOverride("mir_suppress_convenience")
        MIR.MarkConsoleOverride("mir_gate_merchants")
        A.Release(nil, true)
    end
    local s = state()
    local held, tracked = 0, 0
    for _ in pairs(s.held) do held = held + 1 end
    for _ in pairs(s.provenance) do tracked = tracked + 1 end
    log(("%d held instances; %d tracked. !mir_access restore returns loaded holdings; disable both Access controls before uninstalling."):format(held, tracked))
end))
