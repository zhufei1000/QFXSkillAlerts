local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.Core = NS.Core or {}
NS.Core.GroupDeathMonitor = NS.Core.GroupDeathMonitor or {}

local Monitor = NS.Core.GroupDeathMonitor

local POLL_INTERVAL = 0.35
local callbacks = {}
local deadByGUID = {}

local enabled = false
local watcher
local ticker

local function ClearTable(tbl)
    if type(wipe) == "function" then
        wipe(tbl)
    else
        for key in pairs(tbl) do
            tbl[key] = nil
        end
    end
end

local function Call(name, fallback, ...)
    local fn = callbacks[name]
    if type(fn) ~= "function" then
        fn = fallback
    end
    if type(fn) == "function" then
        return fn(...)
    end
    return nil
end

local function IsGrouped()
    return Call("isInGroup", rawget(_G, "IsInGroup")) == true
end

local function IsRaid()
    return Call("isInRaid", rawget(_G, "IsInRaid")) == true
end

local function GetGroupCount()
    return math.max(0, math.floor(tonumber(Call("getNumGroupMembers", rawget(_G, "GetNumGroupMembers"))) or 0))
end

local function ForEachGroupUnit(fn)
    if IsRaid() then
        for index = 1, GetGroupCount() do
            local unit = "raid" .. index
            if Call("unitExists", rawget(_G, "UnitExists"), unit) == true
                and Call("unitIsUnit", rawget(_G, "UnitIsUnit"), unit, "player") ~= true then
                fn(unit)
            end
        end
    elseif IsGrouped() then
        for index = 1, 4 do
            local unit = "party" .. index
            if Call("unitExists", rawget(_G, "UnitExists"), unit) == true then
                fn(unit)
            end
        end
    end
end

function Monitor:Configure(opts)
    opts = type(opts) == "table" and opts or {}
    for _, name in ipairs({
        "onGroupMemberDeath", "createFrame", "newTicker", "isInGroup", "isInRaid",
        "getNumGroupMembers", "unitExists", "unitIsUnit", "unitGUID",
        "unitIsConnected", "unitIsDeadOrGhost", "unitIsFeignDeath",
    }) do
        if opts[name] ~= nil then
            callbacks[name] = opts[name]
        end
    end
    return true
end

function Monitor:Poll()
    if not enabled or not IsGrouped() then
        return false
    end

    local seen = {}
    local newlyDeadUnit
    ForEachGroupUnit(function(unit)
        local guid = Call("unitGUID", rawget(_G, "UnitGUID"), unit)
        if not guid then
            return
        end
        seen[guid] = true
        if Call("unitIsConnected", rawget(_G, "UnitIsConnected"), unit) ~= true then
            return
        end

        local dead = Call("unitIsDeadOrGhost", rawget(_G, "UnitIsDeadOrGhost"), unit) == true
            and Call("unitIsFeignDeath", rawget(_G, "UnitIsFeignDeath"), unit) ~= true
        if deadByGUID[guid] == false and dead and not newlyDeadUnit then
            newlyDeadUnit = unit
        end
        deadByGUID[guid] = dead
    end)

    for guid in pairs(deadByGUID) do
        if not seen[guid] then
            deadByGUID[guid] = nil
        end
    end

    if newlyDeadUnit then
        Call("onGroupMemberDeath", nil, newlyDeadUnit)
        return true
    end
    return false
end

function Monitor:Start()
    if ticker or not enabled or not IsGrouped() then
        return ticker ~= nil
    end

    ClearTable(deadByGUID)
    self:Poll()
    local timerApi = rawget(_G, "C_Timer")
    ticker = Call("newTicker", type(timerApi) == "table" and timerApi.NewTicker or nil, POLL_INTERVAL, function()
        return self:Poll()
    end)
    return ticker ~= nil
end

function Monitor:Stop()
    if ticker and type(ticker.Cancel) == "function" then
        ticker:Cancel()
    end
    ticker = nil
    ClearTable(deadByGUID)
    return true
end

function Monitor:UpdateActive()
    if enabled and IsGrouped() then
        return self:Start()
    end
    self:Stop()
    return false
end

function Monitor:EnsureWatcher()
    if watcher then
        return watcher
    end
    watcher = Call("createFrame", rawget(_G, "CreateFrame"), "Frame")
    if watcher and type(watcher.SetScript) == "function" then
        watcher:SetScript("OnEvent", function()
            self:UpdateActive()
        end)
    end
    return watcher
end

function Monitor:SetEnabled(value)
    value = value == true
    if enabled == value then
        return self:UpdateActive()
    end
    enabled = value

    local frame = self:EnsureWatcher()
    if frame and type(frame.UnregisterAllEvents) == "function" then
        frame:UnregisterAllEvents()
    end
    if enabled and frame and type(frame.RegisterEvent) == "function" then
        frame:RegisterEvent("GROUP_ROSTER_UPDATE")
        frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    end
    return self:UpdateActive()
end
