local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.Core = NS.Core or {}
NS.Core.CDMVoiceEditorController = NS.Core.CDMVoiceEditorController or {}

local Controller = NS.Core.CDMVoiceEditorController

local function L(key, ...)
    if type(NS.L) == "function" then
        return NS.L(key, ...)
    end
    return tostring(key)
end

local function API()
    return NS.API or {}
end

local function CurrentScope()
    local api = API()
    if type(api.GetCDMVoiceCurrentClassSpec) == "function" then
        return api.GetCDMVoiceCurrentClassSpec()
    end
    if type(api.GetCurrentClassSpec) == "function" then
        return api.GetCurrentClassSpec()
    end
end

local function IsInCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown() == true
end

local function DraftKey(category, cooldownID)
    return tostring(category or "") .. ":" .. tostring(tonumber(cooldownID) or "")
end

local ERROR_KEYS = {
    combat = "CDM_COMBAT_BLOCKED",
    spec_changed = "CDM_SPEC_CHANGED",
    limit = "CDM_ALERT_LIMIT_REACHED",
    not_available = "CDM_NOT_AVAILABLE",
    not_loaded = "CDM_NOT_AVAILABLE",
    data_not_ready = "CDM_DATA_NOT_READY",
    invalid_cooldown = "CDM_DATA_NOT_READY",
    invalid_event = "CDM_EVENT_SOUND_UNSUPPORTED",
    invalid_payload = "CDM_SELECT_VOICE",
    unsupported = "CDM_EVENT_SOUND_UNSUPPORTED",
    not_found = "CDM_DELETE_FAILED",
}

function Controller:GetFrame()
    local builder = NS.UI and NS.UI.CDMVoiceEditorBuilder
    return builder and type(builder.Ensure) == "function" and builder:Ensure() or nil
end

function Controller:SetStatus(message, color)
    local frame = self:GetFrame()
    if not frame or not frame.statusText then
        return
    end
    frame.statusText:SetText(tostring(message or ""))
    color = color or { 0.78, 0.78, 0.78 }
    frame.statusText:SetTextColor(color[1], color[2], color[3], 1)
end

function Controller:GetRegistryItems()
    local api = API()
    local items = type(api.GetCDMVoiceRegistryItems) == "function" and api.GetCDMVoiceRegistryItems() or {}
    return type(items) == "table" and items or {}
end

function Controller:GetCategories()
    local api = API()
    local categories = type(api.GetCDMVoiceCategories) == "function" and api.GetCDMVoiceCategories() or {}
    return type(categories) == "table" and categories or {}
end

function Controller:ResolveInitialCategory(requested)
    local categories = self:GetCategories()
    local desired = requested
    local api = API()
    if desired == nil and type(api.GetCDMVoiceLastCategory) == "function" then
        desired = api.GetCDMVoiceLastCategory()
    end
    desired = desired or "essential"
    for _, category in ipairs(categories) do
        if category.key == desired then
            return desired
        end
    end
    return categories[1] and categories[1].key or "essential"
end

function Controller:Open(category, pendingEdit)
    local frame = self:GetFrame()
    if not frame then
        return false
    end
    local classID, specID, className, specName = CurrentScope()
    self.openedClassID = tonumber(classID)
    self.openedSpecID = tonumber(specID)
    self.openedClassName = className
    self.openedSpecName = specName
    self.category = self:ResolveInitialCategory(category)
    self.pendingEdit = pendingEdit
    frame:Show()
    frame:Raise()
    self:Refresh("open")
    return true
end

function Controller:FindCategory(cooldownID)
    local api = API()
    for _, category in ipairs(self:GetCategories()) do
        local rows = type(api.GetCDMVoiceCooldownsForCategory) == "function"
            and api.GetCDMVoiceCooldownsForCategory(category.key) or {}
        for _, info in ipairs(type(rows) == "table" and rows or {}) do
            if tonumber(info.cooldownID) == tonumber(cooldownID) then
                return category.key
            end
        end
    end
    return nil
end

function Controller:OpenForEdit(key)
    local api = API()
    local parsed = type(api.ParseCDMVoiceSavedKey) == "function" and api.ParseCDMVoiceSavedKey(key) or nil
    local classID, specID = CurrentScope()
    if not parsed or parsed.classID ~= tonumber(classID) or parsed.specID ~= tonumber(specID) then
        self:SetStatus(L("CDM_DATA_NOT_READY"), { 1, 0.25, 0.25 })
        return false
    end
    if parsed.keyType == "preset" then
        local savedEntry
        if type(api.GetCDMVoiceSavedEntries) == "function" then
            for _, entry in ipairs(api.GetCDMVoiceSavedEntries() or {}) do
                if tostring(entry.key or "") == tostring(key or "") then
                    savedEntry = entry
                    break
                end
            end
        end
        local category = parsed.category or (savedEntry and savedEntry.category)
        if savedEntry and savedEntry.cooldownID then
            return self:Open(category, {
                keyType = "preset",
                cooldownID = savedEntry.cooldownID,
                eventType = savedEntry.alertEvent,
                payload = savedEntry.voicePayload,
                recordKey = parsed.recordKey,
            })
        end
        local opened = self:Open(category)
        if opened then
            self:SetStatus(L("CDM_EDIT_SKILL_NOT_LOADED"), { 1, 0.3, 0.3 })
        end
        return opened
    end
    local category = self:FindCategory(parsed.cooldownID)
    if not category then
        self:SetStatus(L("CDM_DATA_NOT_READY"), { 1, 0.25, 0.25 })
        return false
    end
    return self:Open(category, parsed)
end

function Controller:OnCategoryChanged(category)
    self.category = self:ResolveInitialCategory(category)
    local api = API()
    if type(api.SetCDMVoiceLastCategory) == "function" then
        api.SetCDMVoiceLastCategory(self.category)
    end
    self.pendingEdit = nil
    self:Refresh("category")
end

function Controller:CheckScopeChanged()
    local classID, specID, className, specName = CurrentScope()
    classID, specID = tonumber(classID), tonumber(specID)
    local changed = self.openedClassID ~= nil
        and (classID ~= self.openedClassID or specID ~= self.openedSpecID)
    if changed then
        self.openedClassID = classID
        self.openedSpecID = specID
        self.openedClassName = className
        self.openedSpecName = specName
        self.pendingEdit = nil
        self.dirtyDrafts = {}
        self.category = self:ResolveInitialCategory(nil)
        local frame = NS.UI and NS.UI.CDMVoiceEditorBuilder and NS.UI.CDMVoiceEditorBuilder.frame
        for _, row in ipairs(frame and frame.rowPool or {}) do
            row.cooldownInfo = nil
            row.selectedEvent = nil
            row.selectedPayload = nil
            row.selectedPath = nil
        end
    end
    return changed
end

function Controller:Refresh(reason)
    local frame = self:GetFrame()
    if not frame or not frame:IsShown() then
        return
    end
    local api = API()
    local changed = self:CheckScopeChanged()
    if type(frame.RefreshLocale) == "function" then
        frame:RefreshLocale()
    end
    local available, availabilityReason = false, "not_available"
    if type(api.IsCDMVoiceAvailable) == "function" then
        available, availabilityReason = api.IsCDMVoiceAvailable()
    end

    frame.classValue:SetText(tostring(self.openedClassName or L("CDM_NOT_AVAILABLE")))
    frame.specValue:SetText(tostring(self.openedSpecName or L("CDM_NOT_AVAILABLE")))

    local categories = self:GetCategories()
    local categoryItems = {}
    for _, category in ipairs(categories) do
        categoryItems[#categoryItems + 1] = { value = category.key, text = category.name }
    end
    NS.UI.Widgets:SetDropdownItems(frame.categoryDropdown, categoryItems)
    NS.UI.Widgets:SetDropdownValue(frame.categoryDropdown, self.category, L("CDM_CATEGORY"))

    local cooldowns = {}
    if available and type(api.GetCDMVoiceCooldownsForCategory) == "function" then
        cooldowns = api.GetCDMVoiceCooldownsForCategory(self.category) or {}
    end
    local rows = NS.UI and NS.UI.CDMVoiceEditorRows
    if rows and type(rows.Render) == "function" then
        rows:Render(frame, cooldowns, self.pendingEdit)
    end
    local pendingSummary = type(api.GetCurrentSpecCDMPendingSummary) == "function"
        and api.GetCurrentSpecCDMPendingSummary() or {}
    local dirtyCount = 0
    for _ in pairs(self.dirtyDrafts or {}) do
        dirtyCount = dirtyCount + 1
    end
    local pendingCount = (tonumber(pendingSummary.pendingCount) or 0) + dirtyCount
    if frame.syncButton and frame.syncButton.SetEnabled then
        frame.syncButton:SetEnabled(not IsInCombat() and pendingCount > 0)
        frame.syncButton:SetText(L("CDM_APPLY_ALL_RELOAD_COUNT", pendingCount))
    end

    if changed then
        self:SetStatus(L("CDM_SPEC_CHANGED"), { 1, 0.82, 0 })
    elseif not available then
        self:SetStatus(L(ERROR_KEYS[availabilityReason] or "CDM_DATA_NOT_READY"), { 1, 0.3, 0.3 })
    elseif #cooldowns == 0 then
        self:SetStatus(L("CDM_CATEGORY_EMPTY"), { 0.75, 0.75, 0.75 })
    elseif reason ~= "apply" then
        self:SetStatus("")
    end
    self.pendingEdit = nil
end

function Controller:RefreshRowSelection(row, requestedPayload)
    if not row or not row.cooldownInfo then
        return
    end
    local api = API()
    local eventType = tonumber(NS.UI.Widgets:GetDropdownValue(row.eventDropdown))
    row.selectedEvent = eventType
    local configured = eventType and type(api.GetCDMVoiceConfiguredAlert) == "function"
        and api.GetCDMVoiceConfiguredAlert(row.cooldownInfo.cooldownID, eventType) or nil

    local payload = tonumber(requestedPayload)
    if not payload and type(api.GetCDMVoiceSavedEntries) == "function" then
        for _, entry in ipairs(api.GetCDMVoiceSavedEntries() or {}) do
            if tonumber(entry.cooldownID) == tonumber(row.cooldownInfo.cooldownID)
                and tonumber(entry.alertEvent) == eventType then
                payload = tonumber(entry.voicePayload)
                row.recordKey = entry.recordKey
                break
            end
        end
    end
    if not payload and configured and configured.isCustom then
        payload = tonumber(configured.payload)
    end
    payload = payload or 0

    local voiceItems = { { value = 0, text = L("CDM_SELECT_VOICE") } }
    local hasRequested = payload == 0
    local registryItems = self:GetRegistryItems()
    for _, item in ipairs(registryItems) do
        voiceItems[#voiceItems + 1] = { value = item.payload, text = item.name }
        if tonumber(item.payload) == payload then
            hasRequested = true
        end
    end
    if payload ~= 0 and not hasRequested then
        voiceItems[#voiceItems + 1] = { value = payload, text = L("CDM_MISSING_VOICE") }
    end
    NS.UI.Widgets:SetDropdownItems(row.voiceDropdown, voiceItems)
    NS.UI.Widgets:SetDropdownValue(row.voiceDropdown, payload, L("CDM_SELECT_VOICE"))
    row.selectedPayload = payload

    local selectedPath
    for _, item in ipairs(registryItems) do
        if tonumber(item.payload) == payload then
            selectedPath = item.path
            break
        end
    end
    local probePayload = (payload ~= 0 and selectedPath) and payload or (registryItems[1] and registryItems[1].payload)
    local supported = false
    if eventType and probePayload and type(api.CanConfigureCDMVoice) == "function" then
        supported = api.CanConfigureCDMVoice(row.cooldownInfo.cooldownID, eventType, probePayload) == true
    end
    row.soundSupported = supported
    row.selectedPath = selectedPath

    if configured and configured.hasNative and payload == 0 then
        row.hint:SetText(L("CDM_NATIVE_SOUND_WILL_REPLACE"))
        row.hint:SetTextColor(1, 0.82, 0, 1)
    elseif configured and configured.missing and payload ~= 0 then
        row.hint:SetText(L("CDM_MISSING_VOICE"))
        row.hint:SetTextColor(1, 0.25, 0.25, 1)
    elseif not supported then
        row.hint:SetText("")
    else
        row.hint:SetText("")
    end
    self:UpdateRowButtons(row)
end

function Controller:UpdateRowButtons(row)
    if not row then
        return
    end
    local hasVoice = tonumber(row.selectedPayload) and tonumber(row.selectedPayload) ~= 0
    local canTest = hasVoice and row.soundSupported
        and type(row.selectedPath) == "string" and row.selectedPath ~= ""
    local canSave = canTest
    local currentClassID, currentSpecID = CurrentScope()
    local scopeValid = tonumber(currentClassID) == tonumber(self.openedClassID)
        and tonumber(currentSpecID) == tonumber(self.openedSpecID)
    local canApply = canSave and scopeValid and not IsInCombat()
    row.testButton:SetEnabled(canTest == true)
    if row.saveButton then
        row.saveButton:SetEnabled(canSave == true)
    end
    if row.applyButton then
        row.applyButton:SetEnabled(canApply == true)
    end
    NS.UI.Widgets:SetDropdownEnabled(row.voiceDropdown, row.soundSupported == true)
end

function Controller:OnEventChanged(row, eventType)
    row.selectedEvent = tonumber(eventType)
    self:RefreshRowSelection(row)
    self:MarkRowDirty(row)
end

function Controller:OnVoiceChanged(row, payload)
    row.selectedPayload = tonumber(payload) or 0
    local path
    for _, item in ipairs(self:GetRegistryItems()) do
        if tonumber(item.payload) == row.selectedPayload then
            path = item.path
            break
        end
    end
    row.selectedPath = path
    if row.soundSupported then
        row.hint:SetText("")
    end
    self:UpdateRowButtons(row)
    self:MarkRowDirty(row)
end

function Controller:TestRow(row)
    if row and type(row.selectedPath) == "string" and row.selectedPath ~= "" and type(PlaySoundFile) == "function" then
        pcall(PlaySoundFile, row.selectedPath, "Master")
    end
end

function Controller:BuildRowDraft(row)
    if not row or not row.cooldownInfo then
        return nil
    end
    return {
        cooldownID = tonumber(row.cooldownInfo.cooldownID),
        category = self.category,
        spellID = tonumber(row.cooldownInfo.spellID),
        eventType = tonumber(row.selectedEvent),
        payload = tonumber(row.selectedPayload),
        classID = tonumber(self.openedClassID),
        specID = tonumber(self.openedSpecID),
    }
end

function Controller:MarkRowDirty(row)
    local draft = self:BuildRowDraft(row)
    if not draft then
        return
    end
    self.dirtyDrafts = self.dirtyDrafts or {}
    self.dirtyDrafts[DraftKey(draft.category, draft.cooldownID)] = draft
    row.dirty = true
end

function Controller:GetDirtyDraft(category, cooldownID)
    return self.dirtyDrafts and self.dirtyDrafts[DraftKey(category, cooldownID)] or nil
end

function Controller:ClearDirtyDraft(row)
    local draft = self:BuildRowDraft(row)
    if draft and self.dirtyDrafts then
        self.dirtyDrafts[DraftKey(draft.category, draft.cooldownID)] = nil
    end
    if row then
        row.dirty = false
    end
end

function Controller:CollectDirtyDrafts()
    local keys, drafts = {}, {}
    for key in pairs(self.dirtyDrafts or {}) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    for _, key in ipairs(keys) do
        drafts[#drafts + 1] = self.dirtyDrafts[key]
    end
    return drafts
end

function Controller:SaveRow(row)
    if not row or not row.cooldownInfo then
        return false
    end
    if self:CheckScopeChanged() then
        self:Refresh("spec")
        return false
    end
    local api = API()
    local save = api.SaveCDMVoicePresetOnly
    if type(save) ~= "function" then
        self:SetStatus(L("CDM_SAVE_FAILED"), { 1, 0.25, 0.25 })
        return false
    end
    local ok, recordKeyOrReason, syncState = save(
        row.cooldownInfo.cooldownID,
        row.selectedEvent,
        row.selectedPayload,
        self.openedClassID,
        self.openedSpecID,
        self.category
    )
    if not ok then
        self:SetStatus(L(ERROR_KEYS[recordKeyOrReason] or "CDM_SAVE_FAILED"), { 1, 0.25, 0.25 })
        return false
    end
    row.recordKey = recordKeyOrReason
    self:ClearDirtyDraft(row)
    if syncState == "loaded" then
        row.hint:SetText(L("CDM_STATUS_APPLIED"))
        row.hint:SetTextColor(0.2, 1, 0.25, 1)
        self:SetStatus(L("CDM_SAVE_ALREADY_APPLIED"), { 0.2, 1, 0.25 })
    else
        row.hint:SetText(L("CDM_STATUS_PENDING"))
        row.hint:SetTextColor(1, 0.82, 0, 1)
        self:SetStatus(L("CDM_SAVE_PENDING"), { 1, 0.82, 0 })
    end
    return true, recordKeyOrReason
end

function Controller:ApplyRow(row)
    if not row or not row.cooldownInfo or self:CheckScopeChanged() then
        self:Refresh("spec")
        return false
    end
    if IsInCombat() then
        self:SetStatus(L("CDM_COMBAT_BLOCKED"), { 1, 0.25, 0.25 })
        return false
    end
    local api = API()
    if type(api.ApplyCurrentCDMVoiceDraftAndReload) ~= "function" then
        self:SetStatus(L("CDM_NOT_AVAILABLE"), { 1, 0.25, 0.25 })
        return false
    end
    local draft = self:BuildRowDraft(row)
    local ok, _, reason, recordKey = api.ApplyCurrentCDMVoiceDraftAndReload(draft)
    if not ok then
        self:SetStatus(L(ERROR_KEYS[reason] or "CDM_APPLY_FAILED"), { 1, 0.25, 0.25 })
        return false
    end
    row.recordKey = recordKey or row.recordKey
    self:ClearDirtyDraft(row)
    if reason == "already_applied" or reason == "no_changes" then
        self:SetStatus(L("CDM_SAVE_ALREADY_APPLIED"), { 0.2, 1, 0.25 })
        self:Refresh("apply")
    end
    return true
end

function Controller:ApplyAllAndReload()
    if IsInCombat() then
        self:SetStatus(L("CDM_COMBAT_BLOCKED"), { 1, 0.25, 0.25 })
        return false
    end
    local api = API()
    if type(api.ApplyAllPendingCurrentSpecCDMVoicesAndReload) ~= "function" then
        self:SetStatus(L("CDM_NOT_AVAILABLE"), { 1, 0.25, 0.25 })
        return false
    end
    self:SetStatus(L("CDM_STATUS_APPLYING"), { 1, 0.82, 0 })
    local ok, _, reason, failedIndex = api.ApplyAllPendingCurrentSpecCDMVoicesAndReload(
        "editor_apply_all",
        self:CollectDirtyDrafts()
    )
    if not ok then
        local message = L(ERROR_KEYS[reason] or "CDM_APPLY_FAILED")
        if failedIndex then
            message = message .. " (#" .. tostring(failedIndex) .. ")"
        end
        self:SetStatus(message, { 1, 0.35, 0.15 })
        return false, reason
    end
    self.dirtyDrafts = {}
    if reason == "no_changes" then
        self:SetStatus(L("CDM_APPLY_NONE"), { 0.75, 0.75, 0.75 })
        self:Refresh("apply")
    end
    return true
end

function Controller:SyncCurrentSpec()
    return self:ApplyAllAndReload()
end

function Controller:ExportPresets()
    local api = API()
    local exportText = type(api.ExportCDMVoicePresetString) == "function" and api.ExportCDMVoicePresetString() or ""
    if exportText == "" then
        self:SetStatus(L("CDM_SAVE_FAILED"), { 1, 0.25, 0.25 })
        return
    end
    if NS.UI and NS.UI.MainFrame and type(NS.UI.MainFrame.OpenExportDialog) == "function" then
        NS.UI.MainFrame:OpenExportDialog(L("CDM_PRESET_EXPORT_TITLE"), exportText)
    end
end

function Controller:UpdateCombatState()
    local frame = self:GetFrame()
    if not frame or not frame:IsShown() then
        return
    end
    for _, row in ipairs(frame.rowPool or {}) do
        if row:IsShown() then
            self:UpdateRowButtons(row)
        end
    end
    if frame.syncButton and frame.syncButton.SetEnabled then
        local api = API()
        local summary = type(api.GetCurrentSpecCDMPendingSummary) == "function"
            and api.GetCurrentSpecCDMPendingSummary() or {}
        local dirtyCount = 0
        for _ in pairs(self.dirtyDrafts or {}) do
            dirtyCount = dirtyCount + 1
        end
        frame.syncButton:SetEnabled(
            not IsInCombat() and ((tonumber(summary.pendingCount) or 0) + dirtyCount) > 0
        )
    end
end

function Controller:OnExternalRefresh(reason)
    local frame = self:GetFrame()
    if frame and frame:IsShown() then
        self:Refresh(reason)
    end
    if NS.UI and NS.UI.MainFrame and NS.UI.MainFrame.frame and NS.UI.MainFrame.frame:IsShown()
        and type(NS.UI.MainFrame.RequestRefresh) == "function" then
        NS.UI.MainFrame:RequestRefresh("list")
    end
end

local api = API()
if type(api.SetCDMVoiceUIRefreshCallback) == "function" then
    api.SetCDMVoiceUIRefreshCallback(function(reason)
        Controller:OnExternalRefresh(reason)
    end)
end

if type(CreateFrame) == "function" then
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:SetScript("OnEvent", function()
        Controller:UpdateCombatState()
        if NS.UI and NS.UI.MainFrame and type(NS.UI.MainFrame.RequestRefresh) == "function" then
            NS.UI.MainFrame:RequestRefresh("buttons")
        end
    end)
    Controller.combatEventFrame = eventFrame
end
