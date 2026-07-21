local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.Core = NS.Core or {}
NS.Core.EventHub = NS.Core.EventHub or {}

local EventHub = NS.Core.EventHub

local EVENTS = {
    "PLAYER_LOGIN",
    "PLAYER_LOGOUT",
    "PLAYER_ENTERING_WORLD",
    "PLAYER_SPECIALIZATION_CHANGED",
    "PLAYER_TALENT_UPDATE",
    "SPELLS_CHANGED",
    "ITEM_DATA_LOAD_RESULT",
    "PLAYER_REGEN_ENABLED",
    "PLAYER_EQUIPMENT_CHANGED",
    "BAG_UPDATE_DELAYED",
}

local function Call(handlers, name, ...)
    local fn = handlers and handlers[name]
    if type(fn) == "function" then
        return fn(...)
    end
    return nil
end

function EventHub:Initialize(frame, handlers)
    if not frame or type(frame.RegisterEvent) ~= "function" then
        return false
    end

    self.frame = frame
    self.handlers = handlers or {}

    for _, event in ipairs(EVENTS) do
        frame:RegisterEvent(event)
    end
    if type(frame.RegisterUnitEvent) == "function" then
        frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "pet")
        frame:RegisterUnitEvent("UNIT_AURA", "player")
    else
        frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        frame:RegisterEvent("UNIT_AURA")
    end

    frame:SetScript("OnEvent", function(_, event, ...)
        self:Dispatch(event, ...)
    end)

    return true
end

function EventHub:Dispatch(event, ...)
    local handlers = self.handlers or {}

    if event == "PLAYER_LOGIN" then
        return Call(handlers, "OnPlayerLogin")
    elseif event == "PLAYER_LOGOUT" then
        return Call(handlers, "OnPlayerLogout")
    elseif event == "PLAYER_ENTERING_WORLD" or event == "SPELLS_CHANGED" or event == "PLAYER_TALENT_UPDATE" then
        return Call(handlers, "OnProfileRefresh", event)
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        local unit = ...
        return Call(handlers, "OnSpecializationChanged", unit)
    elseif event == "ITEM_DATA_LOAD_RESULT" then
        return Call(handlers, "OnItemDataLoadResult", ...)
    elseif event == "PLAYER_REGEN_ENABLED" then
        return Call(handlers, "OnPlayerRegenEnabled")
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellId = ...
        return Call(handlers, "OnUnitSpellcastSucceeded", unit, spellId)
    elseif event == "UNIT_AURA" then
        local unit = ...
        return Call(handlers, "OnUnitAura", unit)
    elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "BAG_UPDATE_DELAYED" then
        return Call(handlers, "OnItemInventoryChanged", event)
    end
end
