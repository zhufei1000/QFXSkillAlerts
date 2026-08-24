local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.UI = NS.UI or {}
NS.UI.MainFrameRefresh = NS.UI.MainFrameRefresh or {}

local Refresh = NS.UI.MainFrameRefresh

local function CallSoon(callback)
    if type(callback) ~= "function" then
        return
    end
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0, callback)
    else
        callback()
    end
end

local function CachedListContainsKey(list, key)
    key = tostring(key or "")
    if key == "" or not list then
        return false
    end
    for _, rows in ipairs({ list._cachedLoadedEntries, list._cachedUnloadedEntries }) do
        for _, entry in ipairs(type(rows) == "table" and rows or {}) do
            if tostring(entry and entry.key or "") == key then
                return true
            end
        end
    end
    return false
end

function Refresh:RefreshSavedListOnly(main, allowCached)
    if not main or not main.frame then
        return
    end

    local ace = NS.AceOptions
    if not ace or type(ace.GetState) ~= "function" then
        return
    end

    local state = ace:GetState()
    if tostring(state.entryType or "") == "cdmVoice" and tostring(state.selectedKey or "") ~= "" then
        local found = allowCached == true and main.savedList
            and main.savedList._layoutDirty ~= true
            and CachedListContainsKey(main.savedList, state.selectedKey)
        if not found then
            local api = NS.API or {}
            local entries = type(api.GetCDMVoiceSavedEntries) == "function" and api.GetCDMVoiceSavedEntries() or {}
            for _, entry in ipairs(type(entries) == "table" and entries or {}) do
                if tostring(entry.key or "") == tostring(state.selectedKey or "") then
                    found = true
                    break
                end
            end
        end
        if not found then
            state.selectedKey = nil
            state.entryType = "cooldown"
        end
    end
    if main.summary and type(ace.GetCurrentScopeSummary) == "function" then
        main.summary:SetText(ace:GetCurrentScopeSummary())
    end
    if main.savedList then
        main.savedList:SetSelectedKey(state.selectedKey)
        main.savedList:Refresh(allowCached == true)
    end
    self:RefreshActionButtons(main)
end

function Refresh:RefreshActionButtons(main)
    if not main or not main.frame then
        return
    end

    local ace = NS.AceOptions
    local state = ace and type(ace.GetState) == "function" and ace:GetState() or {}
    local hasSelected = tostring(state.selectedKey or "") ~= ""
    if main.editBtn then
        main.editBtn:SetEnabled(hasSelected)
    end
    if main.deleteBtn then
        local combatBlocked = tostring(state.entryType or "") == "cdmVoice"
            and type(InCombatLockdown) == "function" and InCombatLockdown() == true
        local isGlobalSingleton = tostring(state.entryType or "") == "bloodlust"
        main.deleteBtn:SetEnabled(hasSelected and not combatBlocked and not isGlobalSingleton)
    end
end

function Refresh:RequestRefresh(main, reason)
    if not main then
        return
    end

    reason = tostring(reason or "full")
    if reason ~= "buttons" and main.savedList and type(main.savedList.InvalidateLayout) == "function" then
        main.savedList:InvalidateLayout(reason)
    end
    if main._refreshPending then
        if reason == "full" then
            main._refreshReason = "full"
        elseif reason == "list" and tostring(main._refreshReason or "") == "buttons" then
            main._refreshReason = "list"
        elseif not main._refreshReason then
            main._refreshReason = reason
        end
        return
    end

    main._refreshPending = true
    main._refreshReason = reason
    CallSoon(function()
        main._refreshPending = false
        local pendingReason = tostring(main._refreshReason or "full")
        main._refreshReason = nil
        if pendingReason == "buttons" then
            self:RefreshActionButtons(main)
        else
            -- Both full and list refreshes share the same visible work here, but
            -- queuing them avoids repeated full rebuilds when data-layer and UI
            -- code request a refresh in the same click/drag/import operation.
            self:RefreshSavedListOnly(main)
        end
    end)
end

function Refresh:Refresh(main, allowCached)
    if not main or not main.frame then
        return
    end
    if allowCached ~= true and main.savedList and type(main.savedList.InvalidateLayout) == "function" then
        main.savedList:InvalidateLayout("full")
    end
    self:RefreshSavedListOnly(main, allowCached == true)
end
