-- MIR player-facing notice — CLIENT side.
-- Shown when MIR has disabled itself because MCM is not installed. This CANNOT
-- use MCM (that is the very thing missing), so it uses a plain Script Extender
-- IMGUI window: Ext.IMGUI.NewWindow(name) -> ExtuiWindow (.Closeable/.Open/
-- .OnClose verified against the SE v32 definitions, 2026-08-24).
-- The SE log banner remains the fallback for setups where IMGUI itself is broken.
MIRUI = MIRUI or {}

local shown = false

local function build()
    if shown then return end
    local ok, err = pcall(function()
        local w = Ext.IMGUI.NewWindow("MIR - Modded Item Randomizer")
        w.Closeable = true
        w.AlwaysAutoResize = true
        w:AddSeparatorText("Mod Configuration Menu is required")
        w:AddText("MIR (Modded Item Randomizer) has DISABLED itself for this session.")
        w:AddText(
            "It needs Mod Configuration Menu (MCM) to run, and MCM is not installed\n" ..
            "or not enabled in your load order. Until MCM is present, MIR will not add\n" ..
            "any items to containers or corpses. Nothing in your save has been changed.")
        w:AddSpacing()
        w:AddSeparatorText("How to fix")
        w:AddText(
            "1. Install 'Mod Configuration Menu' (Nexus mod 9162).\n" ..
            "2. Enable it in BG3 Mod Manager and place it ABOVE MIR in the load order.\n" ..
            "3. Export the order and restart the game.\n" ..
            "   (In multiplayer this is the HOST's load order that matters.)")
        w:AddSpacing()
        local close = w:AddButton("Close")
        close.IDContext = "MIR_notice_close"
        close.OnClick = function()
            pcall(function() w.Open = false end)
        end
    end)
    if ok then
        shown = true -- latch only on success, so a transient IMGUI failure can retry
    else
        Ext.Utils.Print("[MIR][C] notice window failed: " .. tostring(err)
            .. " (see MIR_log.txt: MCM is required and MIR is disabled)")
    end
end

if MIRNet and MIRNet.Notice then
    MIRNet.Notice:SetHandler(function(data)
        local kind = (type(data) == "table" and data.kind) or ""
        if kind == "mcm_missing" then build()
        elseif kind == "shares" and MIRUI.ApplySharesPush then
            pcall(function() MIRUI.ApplySharesPush(data.shares) end)
        end
    end)
end
