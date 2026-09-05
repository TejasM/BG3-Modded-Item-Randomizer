-- MIR — Modded Item Randomizer (Phase 2 development build)
-- Registrations first (must happen at bootstrap), then modules.
Ext.Vars.RegisterModVariable(ModuleUUID, "SpawnedItems", { Server = true, Client = false, SyncToClient = false })
Ext.Vars.RegisterUserVariable("MIR_Processed", { Server = true, Client = false, Persistent = true, WriteableOnServer = true, SyncToClient = false })

Ext.Require("Shared/Channels.lua") -- channels must exist in BOTH contexts
Ext.Require("Server/Config.lua")
-- pcall: a brand-new module must never be able to take the whole mod down;
-- Catalog.lua nil-guards both entry points, so a failure just disables the fence.
pcall(function() Ext.Require("Server/TreasureIndex.lua") end) -- before Catalog: its fence predicate is used during the build
Ext.Require("Server/Catalog.lua")
Ext.Require("Server/MCMSync.lua") -- before Main: its SessionLoaded sync must run before the catalog build
Ext.Require("Server/Browser.lua")
Ext.Require("Server/Main.lua")
