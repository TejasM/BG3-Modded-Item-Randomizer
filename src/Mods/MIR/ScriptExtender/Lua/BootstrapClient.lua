-- MIR client bootstrap: gameplay logic is server-side; the client hosts the
-- MCM browser tab (Phase 3 chunk 3) and net channels.
Ext.Require("Shared/Channels.lua")
Ext.Require("Client/Notice.lua")
Ext.Require("Client/BrowserTab.lua")

local function hint(cmd)
    Ext.Utils.Print("[MIR][C] '" .. cmd .. "' is a SERVER command: type 'server' in the console first, then !" .. cmd)
end
for _, c in ipairs({ "mir_status", "mir_pool", "mir_enable", "mir_chance", "mir_rolls", "mir_rebuild",
                     "mir_flush", "mir_dry", "mir_util", "mir_consumables", "mir_mods", "mir_ledger",
                     "mir_mcm_sync", "mir_exclude", "mir_include", "mir_excludes", "mir_share",
                     "mir_tables", "mir_placed", "mir_placed_mods", "mir_forceinclude",
                     "mir_wardrobes", "mir_clutter", "mir_bookshelves", "mir_scrolls", "mir_rarity" }) do
    Ext.RegisterConsoleCommand(c, function() hint(c) end)
end
Ext.Utils.Print("[MIR][C] BootstrapClient loaded (MCM browser tab + net channels).")
