-- Standalone logic test for the Cooldown Manager voice toggle-clear flow in
-- CDMVoiceEditorController.lua (OnVoiceChanged / UpdateRowButtons /
-- MarkRowDirty).  Mirrors the exact branches used in the addon so it can run
-- without the WoW frame environment.

local function Fail(message)
    error(message, 2)
end

local function Assert(condition, message)
    if not condition then
        Fail(message or "assertion failed")
    end
end

local L = function(key) return tostring(key) end

local registryItems = {
    { payload = -1000000001, name = "Voice A", path = "Sound\\A.ogg" },
    { payload = -1000000002, name = "Voice B", path = "Sound\\B.ogg" },
}

-- Stub of NS.UI.Widgets:SetDropdownValue used by the placeholder restore.
local lastDropdownValue, lastDropdownText
local WidgetsStub = {
    SetDropdownValue = function(_, dropdown, value, fallbackText)
        lastDropdownValue = value
        lastDropdownText = fallbackText
    end,
}

-- Copies of the controller logic under test (extracted verbatim).
local function OnVoiceChanged(self, row, payload)
    row.selectedPayload = tonumber(payload) or 0
    local path
    for _, item in ipairs(registryItems) do
        if tonumber(item.payload) == row.selectedPayload then
            path = item.path
            break
        end
    end
    row.selectedPath = path
    if row.selectedPayload == 0 then
        WidgetsStub:SetDropdownValue(row.voiceDropdown, 0, L("CDM_SELECT_VOICE"))
    end
    self:UpdateRowButtons(row)
    self:MarkRowDirty(row)
end

local function UpdateRowButtons(self, row)
    local hasVoice = tonumber(row.selectedPayload) and tonumber(row.selectedPayload) ~= 0
    local canTest = hasVoice and row.soundSupported
        and type(row.selectedPath) == "string" and row.selectedPath ~= ""
    local canSave = canTest
    local canApply = canSave and not row.inCombat
    row.testEnabled = canTest == true
    row.saveEnabled = canSave == true
    row.applyEnabled = canApply == true
end

local function MarkRowDirty(self, row)
    local draft = {
        category = self.category,
        cooldownID = row.cooldownID,
        payload = tonumber(row.selectedPayload),
    }
    self.dirtyDrafts = self.dirtyDrafts or {}
    local draftKey = draft.category .. ":" .. tostring(draft.cooldownID)
    if not tonumber(draft.payload) or tonumber(draft.payload) == 0 then
        self.dirtyDrafts[draftKey] = nil
        row.dirty = false
        return false
    end
    self.dirtyDrafts[draftKey] = draft
    row.dirty = true
    return true
end

local function MakeController()
    return {
        category = "essential",
        dirtyDrafts = {},
        UpdateRowButtons = UpdateRowButtons,
        MarkRowDirty = MarkRowDirty,
    }
end

local function MakeRow()
    return {
        cooldownID = 1001,
        voiceDropdown = { value = "sentinel" },
        soundSupported = true,
        selectedPayload = nil,
        selectedPath = nil,
        dirty = false,
        inCombat = false,
    }
end

-- Case 1: selecting a real voice keeps it and marks the row dirty.
do
    local ctrl = MakeController()
    local row = MakeRow()
    OnVoiceChanged(ctrl, row, -1000000001)
    Assert(row.selectedPayload == -1000000001, "case1: payload kept")
    Assert(row.selectedPath == "Sound\\A.ogg", "case1: path resolved")
    Assert(row.testEnabled and row.saveEnabled and row.applyEnabled, "case1: buttons enabled")
    Assert(row.dirty == true, "case1: row dirty")
    Assert(ctrl.dirtyDrafts["essential:1001"] ~= nil, "case1: draft collected")
end

-- Case 2: toggle-clear ("" from the popup) cancels the selection.
do
    local ctrl = MakeController()
    local row = MakeRow()
    row.selectedPayload = -1000000001
    OnVoiceChanged(ctrl, row, "")
    Assert(row.selectedPayload == 0, "case2: payload cleared to 0")
    Assert(row.selectedPath == nil, "case2: path cleared")
    Assert(lastDropdownValue == 0, "case2: dropdown restored to empty value")
    Assert(lastDropdownText == "CDM_SELECT_VOICE", "case2: dropdown restored to placeholder")
    Assert(not row.testEnabled and not row.saveEnabled and not row.applyEnabled, "case2: buttons disabled")
    Assert(row.dirty == false, "case2: row not dirty")
    Assert(ctrl.dirtyDrafts["essential:1001"] == nil, "case2: draft removed")
end

-- Case 3: clearing a row that already had a dirty draft removes it.
do
    local ctrl = MakeController()
    ctrl.dirtyDrafts["essential:1001"] = { category = "essential", cooldownID = 1001, payload = -1000000001 }
    local row = MakeRow()
    OnVoiceChanged(ctrl, row, "")
    Assert(ctrl.dirtyDrafts["essential:1001"] == nil, "case3: stale draft removed")
    Assert(row.dirty == false, "case3: row clean")
end

-- Case 4: switching to a different voice replaces the selection.
do
    local ctrl = MakeController()
    local row = MakeRow()
    row.selectedPayload = -1000000001
    OnVoiceChanged(ctrl, row, -1000000002)
    Assert(row.selectedPayload == -1000000002, "case4: payload switched")
    Assert(row.selectedPath == "Sound\\B.ogg", "case4: path switched")
    Assert(ctrl.dirtyDrafts["essential:1001"].payload == -1000000002, "case4: draft updated")
end

-- Case 5: nil payload from any source is treated as a cancel.
do
    local ctrl = MakeController()
    local row = MakeRow()
    OnVoiceChanged(ctrl, row, nil)
    Assert(row.selectedPayload == 0, "case5: nil payload becomes 0")
    Assert(lastDropdownValue == 0, "case5: placeholder restored")
end

print("test_cdm_voice_toggle_clear: all 5 cases passed")
