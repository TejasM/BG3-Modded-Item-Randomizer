-- MIR exclusion browser — CLIENT side (Phase 3 chunk 3, design §4).
-- A custom MCM tab: search + paged mod list -> per-item list, with checkboxes to
-- exclude / un-exclude. The catalog stays SERVER-side; this asks for one page at
-- a time (SE silently drops net messages over ~1 MB, so the full catalog is never
-- shipped). API facts verified 2026-08-21 against SE v32 IdeHelpers + MCM source:
--   * MCM.InsertModMenuTab(tabName, tabCallback, ...) — callback fires ONCE with
--     an ExtuiTabItem; build the tree and keep references (it is not a draw loop).
--   * SameLine is a PROPERTY, not a method. Duplicate labels collide unless the
--     widget sets IDContext. Destroy() cascades to children.
--   * Large lists: ExtuiTable with OptimizedDraw = true (clipper).
MIRUI = MIRUI or {}

local function log(m) Ext.Utils.Print("[MIR][browser] " .. tostring(m)) end

local S = {           -- view state
    mode = "mods",    -- "mods" | "items"
    modUuid = nil,
    modName = nil,
    search = "",
    page = 1,
    pages = 1,
    total = 0,
    rows = {},
    busy = false,
}
local W = {}          -- persistent widget handles
local buildShares     -- forward decl (defined below; used from req's reply)

local function req(query, done)
    if not MIRNet or not MIRNet.Browse then log("net channel unavailable") return end
    S.busy = true
    local ok = pcall(function()
        MIRNet.Browse:RequestToServer(query, function(res)
            S.busy = false
            if type(res) == "table" then
                S.mode = res.mode or S.mode
                S.rows = res.rows or {}
                S.total = res.total or 0
                S.page = res.page or 1
                S.pages = res.pages or 1
                S.modUuid = res.modUuid or S.modUuid
                S.modName = res.modName or S.modName
                S.counts = res.counts or S.counts
                S.note = res.note -- surfaced in the empty state (review S2)
                S.gen = res.gen
                if res.shares then S.shares = res.shares end
                -- build the shares section on the first reply that actually has
                -- data, and repaint it on every later reply (review BLOCKER 1 /
                -- SHOULD-FIX 2: an empty first reply used to latch it away forever)
                -- a server-side error sentinel (cat "_error") must NOT latch the section
                -- as built with one dead row; it is surfaced via UpdateShares instead
                if not W.sharesBuilt and W.sharesHost and S.shares and #S.shares > 0
                   and not (S.shares[1] and S.shares[1].error) then
                    W.sharesBuilt = true
                    pcall(function() buildShares(W.sharesHost) end)
                else
                    pcall(MIRUI.UpdateShares)
                end
            else
                S.note = "No reply from the server."
            end
            if done then pcall(done) end
            -- this runs inside SE's net dispatcher: never let IMGUI throw into it (review S1)
            local rok, rerr = pcall(MIRUI.Render)
            if not rok then log("render ERROR: " .. tostring(rerr)) end
        end)
    end)
    if not ok then S.busy = false log("request failed") end
end

local function refresh()
    req({ mode = S.mode, modUuid = S.modUuid, search = S.search, page = S.page })
end

local function applyChange(payload, note)
    if not MIRNet or not MIRNet.Apply then return end
    pcall(function()
        MIRNet.Apply:RequestToServer(payload, function(res)
            if type(res) ~= "table" then
                if W.status then W.status.Label = "No reply from the server - change may not have applied." end
            elseif res.ok == false then
                if W.status then W.status.Label = res.note or "Change refused." end
            elseif W.status then
                local c2 = res.counts
                -- review B3: res.note used to be surfaced ONLY on refusal, so every
                -- success-path message - including the duplicate warning - was silently
                -- discarded. The server's note wins when it has something to say.
                W.status.Label = (res.note or note or "Applied.")
                    .. (c2 and ("   [excluded: %d mod(s), %d item(s)]"):format(c2.mods or 0, c2.items or 0) or "")
            end
            if type(res) == "table" and res.shares then
                S.shares = res.shares
                pcall(MIRUI.UpdateShares)
            end
            refresh() -- server rebuilt the pool; re-read this page
        end)
    end)
end

-- ---------------- rendering ----------------
-- One host container is destroyed and rebuilt per render; Destroy() cascades, so
-- no widget bookkeeping is needed (design §4.3 lazy render).
function MIRUI.Render()
    if not W.host then return end
    if W.body then pcall(function() W.body:Destroy() end) W.body = nil end
    local body = W.host:AddGroup("MIR_BrowserBody")
    W.body = body

    -- header line
    local header
    if S.mode == "items" then
        header = ("Items in %s  -  %d shown of %d  (page %d/%d)"):format(
            tostring(S.modName or "?"), #S.rows, S.total, S.page, S.pages)
    else
        header = ("Mods contributing items: %d  (page %d/%d)"):format(S.total, S.page, S.pages)
    end
    body:AddText(header)

    -- nav row
    if S.mode == "items" then
        local back = body:AddButton("< Back to mod list")
        back.IDContext = "MIR_back"
        back.OnClick = function()
            S.mode = "mods"; S.modUuid = nil; S.modName = nil; S.page = 1
            refresh()
        end
    end
    if S.pages > 1 then
        local prev = body:AddButton("< Prev")
        prev.IDContext = "MIR_prev"
        prev.SameLine = (S.mode == "items")
        prev.OnClick = function()
            if S.page > 1 then S.page = S.page - 1 refresh() end
        end
        local nxt = body:AddButton("Next >")
        nxt.IDContext = "MIR_next"
        nxt.SameLine = true
        nxt.OnClick = function()
            if S.page < S.pages then S.page = S.page + 1 refresh() end
        end
    end

    body:AddSeparator()

    if #S.rows == 0 then
        if S.note and S.note ~= "" then body:AddText(tostring(S.note))
        else body:AddText("Nothing matches. Clear the search box to see everything.") end
        return
    end

    -- rows: a clipped table (OptimizedDraw) — 3 columns
    local tbl = body:AddTable("MIR_Rows", 3)
    tbl.OptimizedDraw = true
    pcall(function()
        tbl:AddColumn("Exclude")
        tbl:AddColumn("Name")
        tbl:AddColumn("Info")
    end)
    for _, r in ipairs(S.rows) do
        local row = tbl:AddRow()
        local c1, c2, c3 = row:AddCell(), row:AddCell(), row:AddCell()
        local cb = c1:AddCheckbox("", r.excluded == true)
        cb.IDContext = "MIR_cb_" .. tostring(r.id)
        cb.OnChange = function(_, checked)
            if S.mode == "mods" then
                applyChange({ mods = { [r.id] = checked and true or false } },
                            (checked and "Excluded mod: " or "Re-included mod: ") .. tostring(r.name))
            else
                applyChange({ items = { [r.id] = checked and true or false } },
                            (checked and "Excluded item: " or "Re-included item: ") .. tostring(r.name))
            end
        end
        if S.mode == "mods" then
            local open = c2:AddButton(tostring(r.name))
            open.IDContext = "MIR_open_" .. tostring(r.id)
            open.OnClick = function()
                S.mode = "items"; S.modUuid = r.id; S.modName = r.name; S.page = 1
                refresh()
            end
            local info = ("%d item(s)"):format(r.count or 0)
            if (r.excludedItems or 0) > 0 then info = info .. ("  -  %d excluded"):format(r.excludedItems) end
            if (r.placedItems or 0) > 0 then info = info .. ("  -  %d placed by mod"):format(r.placedItems) end
            c3:AddText(info)
        else
            c2:AddText(tostring(r.name))
            -- "placed by mod" = the mod already distributes this item through its own
            -- treasure tables, so MIR leaves it alone (Pool tab toggle turns this off).
            local info = ("%s %s"):format(tostring(r.rarity or ""), tostring(r.cat or ""))
            if r.forced then
                -- the user deliberately let this one in: say so, and say what it costs.
                info = info .. "  -  ALSO PLACED IN THE WORLD"
                if r.src then info = info .. " (" .. tostring(r.src) .. ")" end
                info = info .. " - you may find two"
            elseif r.placed then
                info = info .. "  -  placed by mod"
                if r.src then info = info .. " (" .. tostring(r.src) .. ")" end
            end
            -- v1.0.1: an entry admitted for one container class only says so, so a user
            -- does not exclude "Shared" as junk and silently kill their clutter arrows
            if r.scope == "clutter" then info = info .. "  -  clutter containers only"
            elseif r.scope == "bookshelf" then info = info .. "  -  bookshelves only" end

            c3:AddText(info)
        end
    end
end


-- ---------------- category shares: the STATUS PANEL (v1.0) ----------------
-- Built ONCE with stable handles: only the text labels, slider values and the slider's
-- Disabled flag are updated afterwards, so dragging never destroys the widget under the
-- cursor. The per-category include CHECKBOX is gone (it was a hidden global veto - see
-- Config.lua); each row shows a status the SERVER derives - ON / LIMITED / OFF - and the
-- server also builds the whole text, so this file never decides what a state means.
-- `Disabled` is a documented ExtuiStyledRenderable property (SE IdeHelpers, verified
-- 2026-09-01); the write is still pcall'd, so the text ALSO says "slider inactive" - a
-- silently-ignored property must not leave the panel lying.
local shareRows = {}   -- [cat] = { text=<ExtuiText>, slider=<ExtuiSliderInt> }
local pending, sendTimer = {}, false
local flushShareWrites

local function shareReply(res)
    if type(res) == "table" then
        if res.ok == false and W.status then
            W.status.Label = res.note or "Change refused (the host manages MIR settings)."
        end
        if res.shares then
            S.shares = res.shares
            pcall(MIRUI.UpdateShares)
        end
    end
end

flushShareWrites = function()
    if not MIRNet or not MIRNet.Apply then pending = {} return end
    for cat, v in pairs(pending) do
        pcall(function()
            MIRNet.Apply:RequestToServer({ share = { cat = cat, value = v } }, shareReply)
        end)
    end
    pending = {}
end

-- A server push moves the widgets; if that were mistaken for a user edit the
-- client would write the value straight back, so edits are suppressed while a
-- push is being applied.
MIRUI.applyingPush = false
function MIRUI.ApplySharesPush(shares)
    if type(shares) ~= "table" then return end
    S.shares = shares
    pcall(MIRUI.UpdateShares) -- UpdateShares raises the guard itself (review S1)
end

local syncing = false
function MIRUI.UpdateShares()
    if syncing then return end
    syncing = true
    -- Raise the guard around EVERY widget mutation, not just the push path
    -- (review S1: four of five callers were unguarded), and save/restore so a
    -- nested call cannot clear an outer guard.
    local prevPush = MIRUI.applyingPush
    MIRUI.applyingPush = true
    for _, r in ipairs(S.shares or {}) do
        if r.error and W.status then pcall(function() W.status.Label = tostring(r.text) end) end
        local w = shareRows[r.cat]
        -- mirror server truth into the widgets so the blueprint tab and this tab
        -- can never disagree (review SHOULD-FIX 3); pcall'd because the exact
        -- slider value shape varies by SE build.
        -- do not yank the slider out from under a drag whose write is still in
        -- flight (review S2)
        if w and w.slider and pending[r.cat] == nil then
            pcall(function() w.slider.Value = { math.floor(r.weight or 0), 0, 0, 0 } end)
        end
        -- v1.0: LIMITED = the only category allowed wherever it is drawable, so a relative
        -- weight has nothing to be relative to. Driven from HERE (every push), not from
        -- buildShares, which runs once (review SF-1: "LIMITED will never turn back off").
        -- Guarded by pending[] exactly like the value write: a category dragged up from 0
        -- can become LIMITED, and disabling the slider under the cursor mid-drag would eat
        -- the rest of the drag (second plan review, SF-4). It is applied on the reply.
        if w and w.slider and pending[r.cat] == nil then
            pcall(function() w.slider.Disabled = (r.status == "limited") end)
        end
        if w and w.text then
            pcall(function()
                w.text.Label = ("%s  -  %s"):format(tostring(r.label or r.cat), tostring(r.text or r.status or "?"))
            end)
        end
    end
    MIRUI.applyingPush = prevPush
    syncing = false
end

function buildShares(parent)
    parent:AddSeparatorText("Category shares - slider = relative weight; ON / LIMITED / OFF is derived from your container settings")
    local note = parent:AddText("ON: competes with other categories in at least one enabled container type - the percentage is its share there."
        .. " LIMITED: the only category allowed wherever it can appear (100% there), so the slider is inactive."
        .. " OFF: cannot appear anywhere right now - the row says why. Weight 0 switches a category off; container-scoped ones are switched off on their container setting.")
    note.TextWrapPos = 0
    for _, r in ipairs(S.shares or {}) do
        local row = parent:AddGroup("MIR_share_" .. r.cat)
        -- slider FIRST so the sixteen sliders stay in one column; the status text, whose
        -- length varies per row, follows it on the same line (diff review M-1)
        local sl = row:AddSliderInt("", math.floor(r.weight or 50), 0, 100)
        sl.IDContext = "MIR_shareslider_" .. r.cat
        local txt = row:AddText("")
        txt.IDContext = "MIR_sharetext_" .. r.cat
        txt.SameLine = true
        sl.ItemWidth = 220
        sl.OnChange = function(ctrl, value)
            if MIRUI.applyingPush then return end
            -- v0.8.1 BUGFIX. An ExtuiSliderInt's value is an ARRAY ({n,0,0,0}) - the
            -- write path in UpdateShares has always known that. This read did
            -- `tonumber(value) or 0`, and tonumber(<table>) is nil, so EVERY drag
            -- silently wrote 0: seven of Alan's categories were zeroed this way and
            -- the log filled with '[MCM] share gloves = 0'. The `or 0` is what hid it -
            -- a type mismatch was coerced into a valid-looking 'off'.
            -- Accept every shape SE might pass, and NEVER fall back to 0: a value we
            -- cannot read must be IGNORED, not turned into 'this category is off'.
            local v = tonumber(value)
            if v == nil and type(value) == "table" then v = tonumber(value[1]) end
            if v == nil then
                pcall(function()
                    local sv = (ctrl or sl).Value
                    if type(sv) == "table" then v = tonumber(sv[1]) else v = tonumber(sv) end
                end)
            end
            if v == nil then return end -- unreadable: leave the stored weight alone
            -- slider events arrive per drag tick; each write persists MCM's
            -- settings file, so coalesce them (review SHOULD-FIX 5).
            pending[r.cat] = math.max(0, math.min(100, math.floor(v)))
            if sendTimer then return end
            sendTimer = true
            local ok = pcall(function()
                Ext.Timer.WaitFor(250, function()
                    sendTimer = false
                    flushShareWrites()
                end)
            end)
            if not ok then sendTimer = false flushShareWrites() end
        end
        shareRows[r.cat] = { text = txt, slider = sl }
    end
    MIRUI.UpdateShares()
end

-- ---------------- tab construction (fires ONCE) ----------------
function MIRUI.BuildTab(tab)
    local ok, err = pcall(function()
        -- shares section: the host exists immediately; rows are built by the
        -- first reply that carries share data (see req()).
        W.sharesHost = tab:AddGroup("MIR_SharesHost")
        req({ mode = "mods", page = 1 })

        tab:AddSeparatorText("Exclusions")
        tab:AddText("Exclude whole mods or individual items from MIR's loot pool.")
        tab:AddText("Checked = excluded. Changes apply immediately and persist per MCM profile.")
        tab:AddSeparator()

        local search = tab:AddInputText("Search", "")
        search.IDContext = "MIR_search"
        search.EnterReturnsTrue = true -- avoid a server round-trip per keystroke
        search.Hint = "type and press Enter"
        search.OnChange = function(_, text)
            S.search = tostring(text or "")
            S.page = 1
            refresh()
        end

        local clearSearch = tab:AddButton("Clear search")
        clearSearch.IDContext = "MIR_clearsearch"
        clearSearch.SameLine = true
        clearSearch.OnClick = function()
            S.search = ""
            S.page = 1
            pcall(function() search.Text = "" end)
            refresh()
        end

        local refreshBtn = tab:AddButton("Refresh")
        refreshBtn.IDContext = "MIR_refresh"
        refreshBtn.SameLine = true
        refreshBtn.OnClick = function() refresh() end

        local clearAll = tab:AddButton("Clear ALL exclusions")
        clearAll.IDContext = "MIR_clearall"
        clearAll.SameLine = true
        clearAll.OnClick = function()
            applyChange({ clear = true }, "All exclusions cleared.")
        end

        W.status = tab:AddText("")
        W.host = tab:AddChildWindow("MIR_BrowserHost")
        pcall(function() W.host.Size = { 0, 360 } end)

        refresh()
    end)
    if not ok then log("BuildTab ERROR: " .. tostring(err)) end
end

-- Register the tab once MCM's window exists. Table-argument form is mandatory:
-- the wiki's positional example uses a stale (modUUID, name, fn) order.
local registered = false
local function registerTab()
    if registered or MCM == nil then return end
    local ok = pcall(function()
        MCM.InsertModMenuTab({ tabName = "MIR Browser",
                               tabCallback = function(tab) MIRUI.BuildTab(tab) end })
    end)
    registered = ok
    if not ok then log("InsertModMenuTab failed (will retry on MCM window events)") end
end

registerTab()
pcall(function()
    Ext.ModEvents.BG3MCM["MCM_Window_Ready"]:Subscribe(function() registerTab() end)
end)
pcall(function()
    Ext.ModEvents.BG3MCM["MCM_Window_Opened"]:Subscribe(function() registerTab() end)
end)

-- Re-query when the user (re-)enters a MIR tab: the tab callback fires ONCE for
-- the whole session, so without this the view goes stale after any pool rebuild.
pcall(function()
    Ext.ModEvents.BG3MCM["MCM_Mod_Tab_Activated"]:Subscribe(function(p)
        if p and p.modUUID == ModuleUUID and W.host then refresh() end
    end)
end)

Ext.RegisterConsoleCommand("mir_browser", function()
    log("browser tab registered=" .. tostring(registered) .. " mode=" .. S.mode ..
        " rows=" .. #S.rows .. " page=" .. S.page .. "/" .. S.pages)
end)
