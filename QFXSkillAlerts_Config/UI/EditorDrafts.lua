local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.UI = NS.UI or {}
NS.UI.EditorDrafts = NS.UI.EditorDrafts or {}

local Drafts = NS.UI.EditorDrafts

function Drafts:NormalizeEntryType(value)
    value = tostring(value or "cooldown")
    if value == "cast" then
        return "cast"
    elseif value == "event" then
        return "event"
    elseif value == "bloodlust" then
        return "bloodlust"
    end
    return "cooldown"
end
