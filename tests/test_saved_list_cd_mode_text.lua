-- Saved-list row text: cooldown entries show their CD type (Fixed / Ready) so
-- the list distinguishes fixed-number alerts from game-readiness alerts. The
-- segment must respect the legacy gameStateCD flag, normalize the removed
-- "charge" mode to Ready, and stay absent for items, casts and placeholders.

local function Fail(message)
    error(message, 2)
end

local function Assert(value, message)
    if not value then
        Fail(message or "assertion failed")
    end
end

local function Contains(text, needle, message)
    Assert(text:find(needle, 1, true) ~= nil, message or ("missing " .. needle))
end

local function NotContains(text, needle, message)
    Assert(text:find(needle, 1, true) == nil, message or ("unexpected " .. needle))
end

QFXSkillAlertsNS = {
    Constants = {
        ALL_RACES_ID = 0, ITEM_LOAD_NONE = "none",
        ITEM_LOAD_EQUIPPED = "equipped", ITEM_LOAD_BAGS = "bags",
    },
    Utils = {},
    UI = {},
}

dofile("QFXSkillAlerts_Config/UI/SavedListRows.lua")
local Rows = QFXSkillAlertsNS.UI.SavedListRows

local function Cooldown(overrides)
    local entry = {
        entryType = "cooldown",
        objectType = "spell",
        spellId = 446035,
        spellName = "Bladestorm",
        alertRaceIDs = { [0] = true },
    }
    for key, value in pairs(overrides or {}) do
        entry[key] = value
    end
    return entry
end

do
    local text = Rows.BuildEntryRowText(Cooldown({ cdMode = "ready" }), false)
    Contains(text, "SAVED_CD_MODE_READY", "ready mode shown")
    NotContains(text, "SAVED_CD_MODE_FIXED", "ready must not show fixed")
end

do
    local text = Rows.BuildEntryRowText(Cooldown({ cdMode = "fixed" }), false)
    Contains(text, "SAVED_CD_MODE_FIXED", "fixed mode shown")
    NotContains(text, "SAVED_CD_MODE_READY", "fixed must not show ready")
end

do
    local text = Rows.BuildEntryRowText(Cooldown({ cdMode = "cooldown" }), false)
    Contains(text, "SAVED_CD_MODE_COOLDOWN", "cooldown mode shown")
    NotContains(text, "SAVED_CD_MODE_READY", "cooldown must not show ready")
    NotContains(text, "SAVED_CD_MODE_FIXED", "cooldown must not show fixed")
end

do
    local entry = Cooldown()
    entry.cdMode = nil
    entry.gameStateCD = true
    local text = Rows.BuildEntryRowText(entry, false)
    Contains(text, "SAVED_CD_MODE_READY", "legacy gameStateCD shown as ready")
end

do
    local text = Rows.BuildEntryRowText(Cooldown({ cdMode = "charge" }), false)
    Contains(text, "SAVED_CD_MODE_READY", "removed charge mode shows ready")
end

do
    local entry = Cooldown()
    entry.cdMode = nil
    entry.gameStateCD = nil
    local text = Rows.BuildEntryRowText(entry, false)
    Contains(text, "SAVED_CD_MODE_FIXED", "entries without mode info show fixed")
end

do
    local text = Rows.BuildEntryRowText(Cooldown({ objectType = "item", itemLoadMode = "none" }), false)
    NotContains(text, "SAVED_CD_MODE_READY", "items do not show a CD type")
    NotContains(text, "SAVED_CD_MODE_FIXED", "items do not show a CD type")
end

do
    local text = Rows.BuildEntryRowText(Cooldown({ entryType = "cast", cdMode = "ready" }), false)
    NotContains(text, "SAVED_CD_MODE_READY", "casts do not show a CD type")
end

do
    local text = Rows.BuildEntryRowText({ spellName = "EMPTY", spellId = 0 }, false)
    NotContains(text, "SAVED_CD_MODE_READY", "placeholders do not show a CD type")
    NotContains(text, "SAVED_CD_MODE_FIXED", "placeholders do not show a CD type")
end

print("test_saved_list_cd_mode_text: OK")
