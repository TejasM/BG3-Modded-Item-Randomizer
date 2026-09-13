-- Experimental, deterministic equipment assessment. No tooltip parsing or code execution.
MIR = MIR or {}
MIR.Power = {}
local P = MIR.Power
local equipment = { weapon=true, shield=true, torso=true, helmet=true, gloves=true,
    boots=true, cloak=true, ring=true, amulet=true }
local rarityFloor = { Common=0, Uncommon=3, Rare=7, VeryRare=12, Legendary=18 }
local function read(object, key)
    local ok, value = pcall(function() return object[key] end)
    if ok and value ~= nil then return tostring(value) end
    return ""
end
local function get(name)
    local ok, value = pcall(Ext.Stats.Get, name)
    if ok then return value end
end

-- Inherited attributes are replacements, not additive copies of parent attributes.
local function inherited(stat, key)
    local seen = {}
    for _ = 1, 32 do
        if not stat or seen[stat] then break end
        seen[stat] = true
        local value = read(stat, key)
        if value ~= "" then return value end
        stat = get(read(stat, "Using"))
    end
    return ""
end

function P.Assess(entry)
    if not equipment[entry.category] then return { exempt=true } end
    local result = { score=0, reasons={}, unknown={}, confidence="heuristic" }
    local function add(points, reason)
        result.score = result.score + math.max(0, points)
        result.reasons[#result.reasons+1] = reason
    end
    local function unknown(reason)
        result.unknown[#result.unknown+1] = reason
    end
    local seen = {}
    local inspect
    inspect = function(name, kind, depth)
        local key = kind .. ":" .. name
        if seen[key] then return end
        seen[key] = true
        if depth > 8 then unknown("reference depth: " .. name); return end
        local stat = get(name)
        if not stat then unknown("missing " .. key); return end
        if kind == "spell" then
            local level = tonumber(inherited(stat, "Level"))
            add(level and (2 + 2 * level) or 8, "grants spell " .. name)
            -- Spell level alone cannot describe scripted effects or unlimited reuse.
            unknown("spell behavior/recharge: " .. name)
        end
        for _, field in ipairs({"Boosts", "BoostsOnEquip", "DefaultBoosts"}) do
            local boosts = inherited(stat, field)
            -- Only flat, recognized calls are priced. Conditional/nested expressions
            -- remain visible as unknown instead of silently receiving a zero score.
            for token in boosts:gmatch("[^;]+") do
                local op, args = token:match("^%s*(%w+)%(([^()]*)%)%s*$")
                local number = args and tonumber(args)
                if (op == "WeaponEnchantment" or op == "AC") and number then
                    add(number * 3, token)
                elseif (op == "SpellSaveDC" or op == "SpellAttackRoll") and number then
                    add(number * 3, token)
                elseif op == "DamageBonus" then
                    local amount = args:match("^%s*([^,]+)") or ""
                    local n, sides = amount:match("^(%d+)d(%d+)$")
                    local average = tonumber(amount) or (n and tonumber(n)*(tonumber(sides)+1)/2)
                    if average then add(average * 1.5, token) else unknown(token) end
                elseif op == "Resistance" then add(5, token)
                elseif op == "Ability" then
                    local amount = tonumber(args:match(",%s*([%+%-]?%d+)%s*$"))
                    if amount then add(amount * 2, token) else unknown(token) end
                elseif op == "ActionResource" then
                    local resource, amount = args:match("^%s*(%w+)%s*,%s*([%+%-]?%d+)")
                    if amount and (resource == "ActionPoint" or resource == "BonusActionPoint") then
                        add(tonumber(amount) * 18, token)
                    else unknown(token) end
                elseif op == "UnlockSpell" then
                    local spell = args:match("^%s*([^,%s]+)")
                    if spell then inspect(spell, "spell", depth+1) else unknown(token) end
                else unknown(token) end
            end
        end
        for _, field in ipairs({"PassivesOnEquip", "Passives"}) do
            for passive in inherited(stat, field):gmatch("[^;%s]+") do
                inspect(passive, "passive", depth+1)
            end
        end
        for _, field in ipairs({"StatsFunctors", "Conditions", "BoostConditions", "OnUsePeaceActions", "OnUseActions"}) do
            if inherited(stat, field) ~= "" then unknown(name .. "." .. field) end
        end
    end
    inspect(entry.stat, "equipment", 0)
    -- Declared rarity is only a lower bound; strong bonuses can promote Common gear.
    result.score = math.max(result.score, rarityFloor[entry.rarity] or 0)
    if #result.unknown > 0 then
        result.confidence = "low"
        result.score = math.max(result.score, 12)
    end
    local score = result.score
    result.tier = score >= 18 and 5 or score >= 12 and 4 or score >= 7 and 3 or score >= 3 and 2 or 1
    result.minLevel = ({1, 3, 5, 8, 10})[result.tier]
    result.minAct = ({1, 1, 1, 2, 3})[result.tier]
    local override = (MIR.Config.powerOverrides or {})[entry.template]
        or (MIR.Config.powerOverrides or {})[entry.stat]
    if override then
        result.minLevel = math.max(1, tonumber(override.minLevel) or result.minLevel)
        result.minAct = math.max(1, math.min(3, tonumber(override.minAct) or result.minAct))
        result.excluded = override.exclude == true
        result.reasons[#result.reasons+1] = "manual override"
    end
    return result
end

function P.Context()
    local level
    pcall(function() level = tonumber(Osi.GetLevel(Osi.GetHostCharacter())) end)
    return { level=level, act=MIR.CurrentAct }
end

function P.Allowed(entry, context)
    if not MIR.Config.powerEnabled then return true end
    local p = entry.power
    if not p then return false end -- unassessed equipment must not bypass the gate
    if p.exempt then return true end
    if p.excluded then return false end
    if MIR.Config.powerStrictUnknown and p.confidence == "low" then return false end
    -- Missing campaign context holds equipment back; it never unlocks endgame gear.
    return context ~= nil and context.level ~= nil and context.act ~= nil
        and context.level >= p.minLevel and context.act >= p.minAct
end

Ext.RegisterConsoleCommand("mir_power", function(_, templateOrStat)
    if not templateOrStat then
        MIR.Log("Power assessment: !mir_power <template UUID or stat name>; settings in MCM Power tab")
        return
    end
    for _, entry in pairs(MIR.Catalog.byTemplate or {}) do
        if entry.template == templateOrStat or entry.stat == templateOrStat then
            MIR.Log(Ext.Json.Stringify({stat=entry.stat, power=entry.power}))
            return
        end
    end
    MIR.Log("No catalog entry for " .. templateOrStat)
end)
