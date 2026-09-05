-- MIR net channels — created in BOTH contexts (SE requirement: the same channel
-- must exist client- and server-side; CreateChannel ERRORS on duplicate names,
-- so this file is required exactly once per context).
-- Request/reply style: the client asks for one PAGE of browser data; the server
-- filters and paginates. Rationale (2026-08-21 API research): SE caps a single
-- net message at 1,048,575 bytes and SILENTLY DROPS anything larger, so the full
-- ~6.2k-item catalog can never be shipped in one message.
MIRNet = MIRNet or {}

if not MIRNet.Browse then
    local ok, ch = pcall(function()
        return Ext.Net.CreateChannel(ModuleUUID, "MIR_Browse")
    end)
    MIRNet.Browse = ok and ch or nil
    if not ok then Ext.Utils.Print("[MIR] channel MIR_Browse creation failed: " .. tostring(ch)) end
end

if not MIRNet.Apply then
    local ok, ch = pcall(function()
        return Ext.Net.CreateChannel(ModuleUUID, "MIR_Apply")
    end)
    MIRNet.Apply = ok and ch or nil
    if not ok then Ext.Utils.Print("[MIR] channel MIR_Apply creation failed: " .. tostring(ch)) end
end

if not MIRNet.Notice then
    local ok, ch = pcall(function()
        return Ext.Net.CreateChannel(ModuleUUID, "MIR_Notice")
    end)
    MIRNet.Notice = ok and ch or nil
    if not ok then Ext.Utils.Print("[MIR] channel MIR_Notice creation failed: " .. tostring(ch)) end
end
