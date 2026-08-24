local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.Core = NS.Core or {}
NS.Core.Notifier = NS.Core.Notifier or {}
NS.Notifier = NS.Core.Notifier

local Notifier = NS.Core.Notifier
local CONST = NS.Constants or {}
local Utils = NS.Utils or {}

local MODE_TTS = CONST.MODE_TTS or "tts"
local MODE_SOUND = CONST.MODE_SOUND or "sound"
local TextToSpeech_SpeakText = rawget(_G, "TextToSpeech_SpeakText")

local function L(key, ...)
    if type(NS.L) == "function" then
        return NS.L(key, ...)
    end
    if select("#", ...) > 0 then
        return string.format(tostring(key), ...)
    end
    return tostring(key)
end

local function TrimText(value)
    if Utils.TrimText then
        return Utils.TrimText(value)
    end
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

function Notifier:GetSelectedVoiceID()
    if C_TTSSettings and C_TTSSettings.GetVoiceOptionID then
        local ok, voiceID = pcall(C_TTSSettings.GetVoiceOptionID)
        if ok and tonumber(voiceID) and tonumber(voiceID) >= 0 then
            return tonumber(voiceID)
        end
    end

    if C_VoiceChat and C_VoiceChat.GetTtsVoices then
        local ok, voices = pcall(C_VoiceChat.GetTtsVoices)
        if ok and type(voices) == "table" then
            for _, voice in ipairs(voices) do
                local voiceID = tonumber(type(voice) == "table" and (voice.voiceID or voice[1])) or -1
                if voiceID >= 0 then
                    return voiceID
                end
            end
        end
    end

    return nil
end

function Notifier:SpeakTextTTS(text, rate)
    text = TrimText(text)
    if text == "" then
        return false
    end

    rate = math.max(-10, math.min(10, tonumber(rate) or 0))

    local voiceID = self:GetSelectedVoiceID()
    if not voiceID then
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage((NS.ADDON_CHAT_PREFIX or "") .. " " .. L("MSG_NO_TTS"))
        end
        return false
    end

    if C_VoiceChat and C_VoiceChat.SpeakText then
        local ok = pcall(C_VoiceChat.SpeakText, voiceID, text, rate, 100, false)
        if ok then
            return true
        end
    end

    if type(TextToSpeech_SpeakText) == "function" then
        local ok = pcall(TextToSpeech_SpeakText, text)
        if ok then
            return true
        end
    end

    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage((NS.ADDON_CHAT_PREFIX or "") .. " " .. L("MSG_TTS_FAILED", text))
    end
    return false
end

function Notifier:NormalizeSoundPath(path)
    path = TrimText(path)
    if path == "" then
        return ""
    end

    if NS.MediaCatalog and type(NS.MediaCatalog.NormalizeSoundPath) == "function" then
        return NS.MediaCatalog:NormalizeSoundPath(path)
    end

    if NS.AceOptions and type(NS.AceOptions.NormalizeSoundPath) == "function" then
        return NS.AceOptions:NormalizeSoundPath(path)
    end

    if Utils.CanonicalPath then
        return Utils.CanonicalPath(path)
    end
    return (path:gsub("/", "\\"))
end

function Notifier:ResolveEntrySoundPath(entry)
    if type(entry) == "table" then
        if entry.resolvedSoundPath ~= nil then
            return tostring(entry.resolvedSoundPath or "")
        end
        local soundSource = tostring(entry.soundSource or "")
        if soundSource == "tts" or tostring(entry.notifyMode or "") == MODE_TTS then
            return ""
        end

        -- 1.0.186: always route table entries through the same sound-source
        -- resolver used by the editor/exporter.  This preserves builtin,
        -- SharedMedia and custom paths even if a save/import only populated
        -- builtinSoundPath/customSoundPath instead of soundPath.
        if NS.AceOptions and type(NS.AceOptions.ResolveSoundSourceFields) == "function" then
            local fields = NS.AceOptions:ResolveSoundSourceFields(entry, MODE_TTS, MODE_SOUND)
            if type(fields) == "table" and tostring(fields.soundSource or "") ~= "tts" then
                local resolved = self:NormalizeSoundPath(fields.soundPath or "")
                if resolved ~= "" then
                    return resolved
                end
            end
        end

        if NS.AceOptions and type(NS.AceOptions.ResolveSharedMediaSoundPath) == "function" then
            local sharedMediaSound = TrimText(entry.sharedMediaSound or entry.sharedMediaName or "")
            if soundSource == "sharedmedia" and sharedMediaSound ~= "" then
                local resolved = NS.AceOptions:ResolveSharedMediaSoundPath(sharedMediaSound, entry.soundPath or "")
                resolved = self:NormalizeSoundPath(resolved)
                if resolved ~= "" then
                    return resolved
                end
            end
        end

        local path = self:NormalizeSoundPath(entry.soundPath or "")
        return path
    end
    return self:NormalizeSoundPath(entry)
end

function Notifier:PlayVoiceFile(path, pathIsResolved)
    path = pathIsResolved and tostring(path or "") or self:NormalizeSoundPath(path)
    if path == "" then
        return false
    end

    if type(PlaySoundFile) ~= "function" then
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage((NS.ADDON_CHAT_PREFIX or "") .. " " .. L("MSG_NO_CUSTOM_AUDIO"))
        end
        return false
    end

    -- PlaySoundFile returns true only when the sound is actually queued.
    -- nil means it did not play, so do not treat nil as success.
    local ok, willPlay = pcall(PlaySoundFile, path, "Master")
    if ok and willPlay == true then
        return true
    end

    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage((NS.ADDON_CHAT_PREFIX or "") .. " " .. L("MSG_SOUND_FAILED", path))
    end
    return false
end

function Notifier:GetRandomNonEmptyPath(paths)
    local candidates = {}
    if type(paths) ~= "table" then
        return nil
    end

    for _, value in ipairs(paths) do
        value = self:NormalizeSoundPath(value)
        if value ~= "" then
            candidates[#candidates + 1] = value
        end
    end

    if #candidates <= 0 then
        return nil
    end

    if #candidates == 1 then
        return candidates[1]
    end

    return candidates[math.random(1, #candidates)]
end


local visualFrameSerial = 0
local visualAnonymousSerial = 0
local VISUAL_STACK_GAP = 10

local function GetScreenParent()
    return rawget(_G, "UIParent")
end

local function ClampVisualDuration(duration, fallback)
    return math.max(0.1, tonumber(duration) or tonumber(fallback) or 2)
end

local function ResolveSpellIcon(spellId)
    spellId = tonumber(spellId) or 0
    if spellId <= 0 then
        return nil
    end
    if C_Spell and type(C_Spell.GetSpellTexture) == "function" then
        local ok, texture = pcall(C_Spell.GetSpellTexture, spellId)
        if ok and texture then
            return texture
        end
    end
    if type(GetSpellTexture) == "function" then
        local ok, texture = pcall(GetSpellTexture, spellId)
        if ok and texture then
            return texture
        end
    end
    return nil
end

local function ResolveItemIcon(itemID)
    itemID = tonumber(itemID) or 0
    if itemID <= 0 then
        return nil
    end
    local api = NS.API or {}
    if type(api.ResolveItemIcon) == "function" then
        local ok, icon = pcall(api.ResolveItemIcon, itemID)
        if ok and icon then
            return icon
        end
    end
    if C_Item and type(C_Item.GetItemIconByID) == "function" then
        local ok, icon = pcall(C_Item.GetItemIconByID, itemID)
        if ok and icon then
            return icon
        end
    end
    if type(GetItemIcon) == "function" then
        local ok, icon = pcall(GetItemIcon, itemID)
        if ok and icon then
            return icon
        end
    end
    return nil
end

function Notifier:ResolveImageTexture(cfgOrValue)
    if type(cfgOrValue) ~= "table" then
        local value = TrimText(cfgOrValue)
        if value == "" then return nil end
        return tonumber(value) or value
    end

    if cfgOrValue.resolvedImageTexture ~= nil then
        return cfgOrValue.resolvedImageTexture or nil
    end

    local source = tostring(cfgOrValue.imageSource or "auto")
    if source == "spell" then
        return ResolveSpellIcon(cfgOrValue.imageIconID)
    elseif source == "item" then
        return ResolveItemIcon(cfgOrValue.imageIconID)
    elseif source == "icon" then
        local iconID = tonumber(cfgOrValue.imageIconID) or 0
        return iconID > 0 and math.floor(iconID) or nil
    elseif source == "path" then
        local value = TrimText(cfgOrValue.imagePath or "")
        return value ~= "" and (tonumber(value) or value) or nil
    end

    local objectID = cfgOrValue.spellId or cfgOrValue.objectID or cfgOrValue.triggerSpellID
    local objectIcon = (tostring(cfgOrValue.objectType or "") == "item") and ResolveItemIcon(objectID) or ResolveSpellIcon(objectID)
    local iconID = tonumber(cfgOrValue.imageIconID or cfgOrValue.icon or cfgOrValue.iconID or cfgOrValue.iconId) or 0
    local imagePath = TrimText(cfgOrValue.imagePath or "")
    return objectIcon
        or (iconID > 0 and math.floor(iconID) or nil)
        or (imagePath ~= "" and (tonumber(imagePath) or imagePath) or nil)
end

local function ResolveDuration(enabled, duration, cfg)
    if enabled == true then
        return ClampVisualDuration(duration, 2)
    end
    -- When the Image/Text "limit display time" checkbox is not enabled, do not
    -- start any auto-hide timer.  CD visuals are still cleared by Runtime when
    -- their condition becomes invalid; cast-success visuals remain until another
    -- explicit hide/refresh/cleanup touches that visual key.
    return nil
end

local function MakeVisualKey(cfg, fallback)
    if type(cfg) == "table" then
        local value = cfg.primaryKey or cfg.key or cfg.selectedKey or cfg.objectID or cfg.spellId or cfg.triggerSpellID
        value = tostring(value or "")
        if value ~= "" and value ~= "0" then
            return value
        end
    end
    fallback = tostring(fallback or "")
    if fallback ~= "" then
        return fallback
    end
    visualAnonymousSerial = visualAnonymousSerial + 1
    return "anonymous:" .. tostring(visualAnonymousSerial)
end

local function InvalidateVisualTimer(frame)
    if frame then
        frame.qfxsaTicket = (tonumber(frame.qfxsaTicket) or 0) + 1
    end
end

local function CancelVisualTimer(frame)
    if frame and frame.qfxsaTimer then
        if type(frame.qfxsaTimer.Cancel) == "function" then
            frame.qfxsaTimer:Cancel()
        end
        frame.qfxsaTimer = nil
    end
end

local function PrepareVisualFrame(frame)
    if not frame then
        return
    end
    if not frame.texture then
        frame.texture = frame:CreateTexture(nil, "OVERLAY")
        frame.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    if not frame.text then
        frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
        frame.text:SetJustifyH("CENTER")
        frame.text:SetJustifyV("MIDDLE")
        frame.text:SetWidth(520)
    end
end

local function ClearVisualFrame(frame)
    if not frame then
        return
    end
    CancelVisualTimer(frame)
    InvalidateVisualTimer(frame)
    frame.qfxsaVisible = false
    frame.qfxsaPrimaryKey = nil
    frame.qfxsaVisualEntryKey = nil
    frame.qfxsaVisualUID = nil
    frame.qfxsaVisualGroupID = nil
    frame.qfxsaVisualGroupOrder = nil
    frame.qfxsaImageSize = nil
    frame.qfxsaHasImage = nil
    frame.qfxsaHasText = nil
    frame.qfxsaChannel = nil
    frame.qfxsaBaseX = nil
    frame.qfxsaBaseY = nil
    frame.qfxsaLayoutHeight = nil
    if frame.Hide then
        frame:Hide()
    end
    if frame.texture then
        if frame.texture.SetTexture then
            frame.texture:SetTexture(nil)
        end
        if frame.texture.Hide then
            frame.texture:Hide()
        end
    end
    if frame.text then
        if frame.text.SetText then
            frame.text:SetText("")
        end
        if frame.text.Hide then
            frame.text:Hide()
        end
    end
end

local function StartVisualTimer(frame, duration)
    if not frame then
        return
    end

    -- Always advance the ticket when a visual is shown, even for state-based
    -- visuals without a fixed duration. Older timers may then only hide their
    -- own visual slot and cannot hide a newer alert for another spell/item.
    CancelVisualTimer(frame)
    InvalidateVisualTimer(frame)

    if duration and C_Timer and type(C_Timer.NewTimer) == "function" then
        local ticket = frame.qfxsaTicket
        local primaryKey = frame.qfxsaPrimaryKey
        local timer
        timer = C_Timer.NewTimer(duration, function()
            if frame and frame.qfxsaTimer == timer then
                frame.qfxsaTimer = nil
            end
            if frame and frame.qfxsaTicket == ticket and frame.qfxsaPrimaryKey == primaryKey then
                local owner = frame.qfxsaOwner
                if owner and primaryKey and type(owner.HideVisualAlertForKey) == "function" then
                    owner:HideVisualAlertForKey(primaryKey)
                else
                    ClearVisualFrame(frame)
                end
            end
        end)
        frame.qfxsaTimer = timer
    end
end

local VISUAL_SLOT_LIMIT = 12

function Notifier:GetVisualSlot(primaryKey)
    primaryKey = tostring(primaryKey or "")
    if primaryKey == "" then
        return nil
    end

    local parent = GetScreenParent()
    if not parent then
        return nil
    end

    self.visualSlots = self.visualSlots or {}
    self.activeVisualOrder = self.activeVisualOrder or {}

    local slot = self.visualSlots[primaryKey]
    if slot and slot.frame then
        return slot
    end

    -- Bound the number of retained (hidden) visual frames so long sessions
    -- with many distinct alerts cannot grow memory without limit.  Before
    -- allocating a new frame, drop one inactive slot (never an actively
    -- visible alert).
    local count = 0
    for _ in pairs(self.visualSlots) do
        count = count + 1
    end
    if count >= VISUAL_SLOT_LIMIT then
        for key, oldSlot in pairs(self.visualSlots) do
            local oldFrame = oldSlot and oldSlot.frame
            if oldFrame and oldFrame.qfxsaVisible ~= true then
                CancelVisualTimer(oldFrame)
                oldFrame:Hide()
                oldFrame:SetParent(nil)
                self.visualSlots[key] = nil
                self:ForgetVisualKey(key)
                break
            end
        end
    end

    visualFrameSerial = visualFrameSerial + 1
    local frame = CreateFrame("Frame", "QFXSkillAlertsVisualAlert" .. tostring(visualFrameSerial), parent)
    frame:SetPoint("CENTER", parent, "CENTER", 0, 120)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(900 + visualFrameSerial)
    frame:Hide()
    frame.qfxsaOwner = self
    PrepareVisualFrame(frame)

    slot = {
        key = primaryKey,
        frame = frame,
    }
    self.visualSlots[primaryKey] = slot
    return slot
end

function Notifier:RememberVisualKey(primaryKey)
    primaryKey = tostring(primaryKey or "")
    if primaryKey == "" then
        return false
    end
    self.activeVisualOrder = self.activeVisualOrder or {}
    for _, value in ipairs(self.activeVisualOrder) do
        if value == primaryKey then
            return true
        end
    end
    self.activeVisualOrder[#self.activeVisualOrder + 1] = primaryKey
    return true
end

function Notifier:ForgetVisualKey(primaryKey)
    primaryKey = tostring(primaryKey or "")
    if primaryKey == "" or type(self.activeVisualOrder) ~= "table" then
        return false
    end
    for index = #self.activeVisualOrder, 1, -1 do
        if self.activeVisualOrder[index] == primaryKey then
            table.remove(self.activeVisualOrder, index)
        end
    end
    return true
end

function Notifier:LayoutVisualSlots()
    if type(self.activeVisualOrder) ~= "table" or type(self.visualSlots) ~= "table" then
        return false
    end

    -- 1.0.155: keep every saved entry at its own configured preview position.
    -- Earlier multi-visual stacking pushed the 2nd/3rd alert down even when the
    -- user had already dragged that entry to a specific location, so B could
    -- appear away from its preset position.  Multi-instance isolation should be
    -- handled by independent visual slots; positioning must stay user-controlled.
    for _, primaryKey in ipairs(self.activeVisualOrder) do
        local slot = self.visualSlots[primaryKey]
        local frame = slot and slot.frame
        if frame and frame.qfxsaVisible == true and frame.IsShown and frame:IsShown() then
            local x = tonumber(frame.qfxsaBaseX) or 0
            local y = tonumber(frame.qfxsaBaseY) or 120
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", GetScreenParent(), "CENTER", x, y)
        end
    end
    return true
end

function Notifier:HideVisualAlertForKey(primaryKey)
    primaryKey = tostring(primaryKey or "")
    if primaryKey == "" or type(self.visualSlots) ~= "table" then
        return false
    end
    local slot = self.visualSlots[primaryKey]
    if not slot then
        return false
    end
    ClearVisualFrame(slot.frame)
    self:ForgetVisualKey(primaryKey)
    self:LayoutVisualSlots()
    return true
end

function Notifier:HideVisualAlerts(primaryKeyOrMode)
    local mode = tostring(primaryKeyOrMode or "")

    -- Editor preview frames live on their own UI layer and must not clear real
    -- runtime visual alerts.  Saving from the editor rebuilds config tables, but
    -- active visual slots should remain visible for alignment/reference.
    if mode == "__editorPreview" or mode == "__editorSave" then
        return true
    end

    -- When a concrete primaryKey is supplied, hide only that key.
    -- Important: do not fall back to clearing every slot when the key is not
    -- currently visible.  Runtime calls this when a spell is used to clear that
    -- spell's own old ready alert; if B has no visible slot yet, clearing all
    -- slots here would incorrectly make A disappear.
    if mode ~= "" then
        return self:HideVisualAlertForKey(mode)
    end

    if type(self.visualSlots) == "table" then
        for _, slot in pairs(self.visualSlots) do
            ClearVisualFrame(slot and slot.frame)
        end
    end
    self.visualSlots = self.visualSlots or {}
    if type(self.activeVisualOrder) == "table" then
        wipe(self.activeVisualOrder)
    else
        self.activeVisualOrder = {}
    end

    -- Compatibility cleanup for frames created by older builds.
    if type(self.visualFrames) == "table" then
        for _, frame in pairs(self.visualFrames) do
            ClearVisualFrame(frame)
        end
    end
    ClearVisualFrame(self.visualGroupFrame)

    if mode == "" then
        self.activeVisualKey = nil
    end
    return true
end

function Notifier:IsAnyVisualShown()
    if type(self.visualSlots) == "table" then
        for _, slot in pairs(self.visualSlots) do
            local frame = slot and slot.frame
            if frame and frame.qfxsaVisible == true and frame.IsShown and frame:IsShown() then
                return true
            end
        end
    end
    if type(self.visualFrames) == "table" then
        for _, frame in pairs(self.visualFrames) do
            if frame and frame.IsShown and frame:IsShown() then
                return true
            end
        end
    end
    return self.visualGroupFrame and self.visualGroupFrame.IsShown and self.visualGroupFrame:IsShown() or false
end

function Notifier:IsActiveVisualForKey(primaryKey)
    primaryKey = tostring(primaryKey or "")
    if primaryKey == "" then
        return false
    end
    local slot = self.visualSlots and self.visualSlots[primaryKey]
    local frame = slot and slot.frame
    if frame and frame.qfxsaVisible == true and frame.IsShown and frame:IsShown() then
        return true
    end
    return tostring(self.activeVisualKey or "") == primaryKey and self:IsAnyVisualShown() == true
end

function Notifier:RefreshActiveVisualForKey(primaryKey, cfg, fallbackText)
    primaryKey = tostring(primaryKey or "")
    if primaryKey == "" or type(cfg) ~= "table" or not self:IsActiveVisualForKey(primaryKey) then
        return false
    end

    local showImage = cfg.imageEnabled == true
    local showText = cfg.textEnabled == true
    if not showImage and not showText then
        self:HideVisualAlertForKey(primaryKey)
        return true
    end

    local channel
    if showImage and showText then
        channel = "visual"
    elseif showImage then
        channel = "image"
    else
        channel = "text"
    end
    self:ShowVisualAlerts(cfg, fallbackText, channel, primaryKey)
    return true
end

local function SetFrameFontString(fontString, size)
    if fontString and fontString.SetFont then
        local font, _, flags = fontString:GetFont()
        fontString:SetFont(font or "Fonts\\FRIZQT__.TTF", size, flags or "OUTLINE")
    end
end

function Notifier:ApplyImageTextLayout(frame, texture, text, imageSize, textSize, cfg, fallbackText)
    PrepareVisualFrame(frame)

    local attach = tostring(cfg.textAttachMode or "outside")
    if attach ~= "inside" then attach = "outside" end
    local v = tostring(cfg.textVAlign or "bottom")
    if v ~= "top" and v ~= "middle" then v = "bottom" end
    local h = tostring(cfg.textHAlign or "center")
    if h ~= "left" and h ~= "right" then h = "center" end
    local ox = tonumber(cfg.textOffsetX) or 0
    local oy = tonumber(cfg.textOffsetY) or 0

    frame:SetSize(math.max(520, imageSize + 120), math.max(160, imageSize + 100))
    frame.texture:ClearAllPoints()
    frame.texture:SetSize(imageSize, imageSize)
    frame.texture:SetTexture(texture)
    if texture then
        frame.texture:SetPoint("CENTER", frame, "CENTER", 0, 0)
        frame.texture:Show()
    else
        frame.texture:SetPoint("CENTER", frame, "CENTER", 0, 0)
        frame.texture:Hide()
    end

    frame.text:ClearAllPoints()
    SetFrameFontString(frame.text, textSize)
    frame.text:SetText(text)
    if TrimText(text) ~= "" then
        frame.text:Show()
    else
        frame.text:Hide()
    end

    if not texture then
        frame.text:SetPoint("CENTER", frame, "CENTER", ox, oy)
        return
    end

    local x, y = ox, oy
    if h == "left" then
        x = x - math.floor(imageSize / 2)
    elseif h == "right" then
        x = x + math.floor(imageSize / 2)
    end

    if attach == "inside" then
        if v == "top" then
            y = y + math.floor(imageSize / 2) - math.floor(textSize / 2)
        elseif v == "bottom" then
            y = y - math.floor(imageSize / 2) + math.floor(textSize / 2)
        end
        frame.text:SetPoint("CENTER", frame.texture, "CENTER", x, y)
    else
        local gap = 6
        if v == "top" then
            frame.text:SetPoint("BOTTOM", frame.texture, "TOP", x, gap + oy)
        elseif v == "middle" then
            frame.text:SetPoint("CENTER", frame.texture, "CENTER", x, oy)
        else
            frame.text:SetPoint("TOP", frame.texture, "BOTTOM", x, -gap + oy)
        end
    end
end

function Notifier:ApplyVisualGroupMetadata(frame, cfg, kind)
    if not frame then
        return
    end
    cfg = type(cfg) == "table" and cfg or {}
    kind = tostring(kind or "visual")
    local groups = NS.Core and NS.Core.VisualGroups
    local entryKey = tostring(cfg.visualEntryKey or "")
    if entryKey == "" and groups and type(groups.BuildEntryKey) == "function" then
        entryKey = groups:BuildEntryKey(cfg)
    end
    local visualUID = tostring(cfg.visualUID or "")
    if visualUID == "" and groups and type(groups.ResolveIdentity) == "function" then
        visualUID = tostring(groups:ResolveIdentity(entryKey ~= "" and entryKey or cfg) or "")
    end
    frame.qfxsaVisualEntryKey = entryKey ~= "" and entryKey or nil
    frame.qfxsaVisualUID = visualUID ~= "" and visualUID or nil
    frame.qfxsaImageSize = math.max(16, tonumber(cfg.imageSize) or 96)
    frame.qfxsaHasImage = kind == "image" or kind == "visual"
    frame.qfxsaHasText = kind == "text" or kind == "visual"
    frame.qfxsaVisualGroupID = nil
    frame.qfxsaVisualGroupOrder = nil
end

function Notifier:ShowVisualSlot(primaryKey, kind, cfg, fallbackText, duration)
    primaryKey = MakeVisualKey(cfg, primaryKey)
    cfg = type(cfg) == "table" and cfg or {}
    kind = tostring(kind or "visual")

    local slot = self:GetVisualSlot(primaryKey)
    if not slot or not slot.frame then
        return false
    end
    local frame = slot.frame
    PrepareVisualFrame(frame)

    frame.qfxsaOwner = self
    frame.qfxsaPrimaryKey = primaryKey
    frame.qfxsaVisible = true
    frame.qfxsaBaseX = tonumber((kind == "text") and cfg.textX or cfg.imageX) or 0
    frame.qfxsaBaseY = tonumber((kind == "text") and cfg.textY or cfg.imageY) or 120
    frame.qfxsaLayoutHeight = 100
    frame.qfxsaChannel = kind

    if kind == "image" then
        local texture = self:ResolveImageTexture(cfg)
        if not texture then
            self:HideVisualAlertForKey(primaryKey)
            return false
        end
        local imageSize = math.max(16, tonumber(cfg.imageSize) or 96)
        frame:SetSize(imageSize, imageSize)
        frame.qfxsaLayoutHeight = imageSize
        frame.texture:ClearAllPoints()
        frame.texture:SetAllPoints(frame)
        frame.texture:SetTexture(texture)
        frame.texture:Show()
        frame.text:SetText("")
        frame.text:Hide()
    elseif kind == "text" then
        local text = TrimText(cfg.qfxsaTextOverride or cfg.textAlert or "")
        if text == "" then
            text = tostring(fallbackText or cfg.spellName or cfg.spellId or "")
        end
        if TrimText(text) == "" then
            self:HideVisualAlertForKey(primaryKey)
            return false
        end
        local textSize = math.max(8, tonumber(cfg.textSize) or 24)
        frame:SetSize(520, 80)
        frame.qfxsaLayoutHeight = 80
        frame.texture:SetTexture(nil)
        frame.texture:Hide()
        frame.text:ClearAllPoints()
        frame.text:SetPoint("CENTER", frame, "CENTER", 0, 0)
        frame.text:SetJustifyH("CENTER")
        frame.text:SetJustifyV("MIDDLE")
        frame.text:SetWidth(520)
        SetFrameFontString(frame.text, textSize)
        frame.text:SetText(text)
        frame.text:Show()
    else
        local texture = self:ResolveImageTexture(cfg)
        local text = TrimText(cfg.qfxsaTextOverride or cfg.textAlert or "")
        if text == "" then
            text = tostring(fallbackText or cfg.spellName or cfg.spellId or "")
        end
        if not texture and TrimText(text) == "" then
            self:HideVisualAlertForKey(primaryKey)
            return false
        end
        local imageSize = math.max(16, tonumber(cfg.imageSize) or 96)
        local textSize = math.max(8, tonumber(cfg.textSize) or 24)
        frame.qfxsaLayoutHeight = math.max(160, imageSize + 100)
        self:ApplyImageTextLayout(frame, texture, text, imageSize, textSize, cfg, fallbackText)
    end

    self:ApplyVisualGroupMetadata(frame, cfg, kind)
    self.activeVisualKey = primaryKey
    self:RememberVisualKey(primaryKey)
    frame:Show()
    self:LayoutVisualSlots()
    StartVisualTimer(frame, duration)
    return true
end

local COUNTDOWN_KEY_SUFFIX = ":qfxsa-countdown"

function Notifier:FormatCooldownCountdown(remaining)
    local seconds = math.max(0, math.ceil((tonumber(remaining) or 0) - 0.001))
    if seconds >= 60 then
        local minutes = math.floor(seconds / 60)
        local rest = seconds % 60
        if rest > 0 then
            return tostring(minutes) .. "m" .. tostring(rest) .. "s", seconds
        end
        return tostring(minutes) .. "m", seconds
    end
    return tostring(seconds) .. "s", seconds
end

function Notifier:GetCooldownCountdownKey(primaryKey)
    primaryKey = tostring(primaryKey or "")
    if primaryKey == "" then
        return ""
    end
    return primaryKey .. COUNTDOWN_KEY_SUFFIX
end

function Notifier:UpdateCooldownCountdown(cfg, remaining, primaryKey)
    if type(cfg) ~= "table" or cfg.textEnabled ~= true or cfg.textCooldownCountdown ~= true then
        return false
    end
    local countdownKey = self:GetCooldownCountdownKey(primaryKey)
    if countdownKey == "" then
        return false
    end

    local countdown = self:FormatCooldownCountdown(remaining)
    local label = TrimText(cfg.textAlert or "")
    if label == "" then
        label = TrimText(cfg.spellName or "")
    end
    if label == "" then
        label = tostring(cfg.objectID or cfg.spellId or "")
    end
    local displayText = label ~= "" and (label .. " " .. countdown) or countdown
    local slot = self.visualSlots and self.visualSlots[countdownKey]
    local visualFrame = slot and slot.frame
    if visualFrame and visualFrame.qfxsaVisible == true and visualFrame.text then
        visualFrame.text:SetText(displayText)
        visualFrame.text:Show()
        return true
    end

    cfg.qfxsaTextOverride = displayText
    local kind = cfg.imageEnabled == true and "visual" or "text"
    local shown = self:ShowVisualSlot(countdownKey, kind, cfg, displayText, nil)
    cfg.qfxsaTextOverride = nil
    return shown
end

function Notifier:HideCooldownCountdown(primaryKey)
    local countdownKey = self:GetCooldownCountdownKey(primaryKey)
    if countdownKey == "" then
        return false
    end
    return self:HideVisualAlertForKey(countdownKey)
end

function Notifier:ShowImageTextGroup(cfg, fallbackText, primaryKey)
    cfg = type(cfg) == "table" and cfg or {}
    local linkedDurationEnabled = cfg.imageEnabled == true and cfg.textEnabled == true and (cfg.imageDurationEnabled == true or cfg.textDurationEnabled == true)
    local imageDuration = ResolveDuration(linkedDurationEnabled or cfg.imageDurationEnabled, cfg.imageDuration, cfg)
    local textDuration = ResolveDuration(linkedDurationEnabled or cfg.textDurationEnabled, cfg.textDuration, cfg)
    local duration = nil
    -- Image + text are displayed as one linked visual group. When one side has
    -- a duration limit, the linked group must be timed as a whole; otherwise the
    -- unchecked side would make the entire group stay visible forever.
    if imageDuration and textDuration then
        duration = math.max(imageDuration, textDuration)
    end
    return self:ShowVisualSlot(primaryKey or MakeVisualKey(cfg, "group"), "visual", cfg, fallbackText, duration)
end

function Notifier:ShowVisualAlerts(cfg, fallbackText, alertChannel, primaryKey)
    if type(cfg) ~= "table" then
        return false
    end

    primaryKey = MakeVisualKey(cfg, primaryKey)
    self.activeVisualKey = primaryKey
    local channel = tostring(alertChannel or cfg.alertChannel or "all")
    local shown = false
    local showImage = (channel == "all" or channel == "visual" or channel == "image") and cfg.imageEnabled == true
    local showText = (channel == "all" or channel == "visual" or channel == "text") and cfg.textEnabled == true

    -- One visual slot belongs to one saved entry. Re-triggering the same entry
    -- refreshes its slot; different entries can remain visible at the same time.
    if showImage and showText then
        return self:ShowImageTextGroup(cfg, fallbackText, primaryKey)
    end
    if showImage then
        shown = self:ShowVisualSlot(primaryKey, "image", cfg, fallbackText, ResolveDuration(cfg.imageDurationEnabled, cfg.imageDuration, cfg)) or shown
    end
    if showText then
        shown = self:ShowVisualSlot(primaryKey, "text", cfg, fallbackText, ResolveDuration(cfg.textDurationEnabled, cfg.textDuration, cfg)) or shown
    end
    if not shown then
        self:HideVisualAlertForKey(primaryKey)
    end
    return shown
end

function Notifier:PlayReadyNotification(cfg, alertChannel, remaining, primaryKey)
    if type(cfg) ~= "table" then
        return false
    end

    local fallbackText = (tostring(cfg.spellName or "") ~= "" and tostring(cfg.spellName) or tostring(cfg.spellId or "")) .. L("TTS_READY_DEFAULT")
    local channel = tostring(alertChannel or cfg.alertChannel or "all")
    local visualShown = self:ShowVisualAlerts(cfg, fallbackText, channel, primaryKey)
    if channel ~= "all" and channel ~= "voice" then
        return visualShown
    end
    if cfg.voiceEnabled == false then
        return visualShown
    end

    local mode = tostring(cfg.notifyMode or MODE_SOUND)
    if mode == MODE_TTS then
        local text = TrimText(cfg.ttsText or "")
        if text == "" then
            text = fallbackText
        end
        return self:SpeakTextTTS(text, cfg.ttsRate) or visualShown
    end

    local path = self:ResolveEntrySoundPath(cfg)
    if path == "" then
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage((NS.ADDON_CHAT_PREFIX or "") .. " " .. L("MSG_NO_SOUND_PATH"))
        end
        return visualShown
    end
    return self:PlayVoiceFile(path, cfg.resolvedSoundPath ~= nil) or visualShown
end

function Notifier:PlayCastSuccessNotification(cfg, triggerSpellID, castGUID)
    if type(cfg) ~= "table" then
        return false
    end

    local fallbackText = (tostring(cfg.spellName or "") ~= "" and tostring(cfg.spellName) or tostring(cfg.spellId or "")) .. L("TTS_CAST_SUCCESS_DEFAULT")
    local channel = tostring(cfg.alertChannel or "all")
    local visualShown = self:ShowVisualAlerts(cfg, fallbackText)
    if channel ~= "all" and channel ~= "voice" then
        return visualShown
    end
    if cfg.voiceEnabled == false then
        return visualShown
    end

    local mode = tostring(cfg.notifyMode or MODE_SOUND)
    if mode == MODE_TTS then
        local text = TrimText(cfg.ttsText or "")
        if text == "" then
            text = fallbackText
        end
        return self:SpeakTextTTS(text, cfg.ttsRate) or visualShown
    end

    local path = self:ResolveEntrySoundPath(cfg)
    if path == "" then
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage((NS.ADDON_CHAT_PREFIX or "") .. " " .. L("MSG_NO_CAST_SOUND_PATH"))
        end
        return visualShown
    end
    return self:PlayVoiceFile(path, cfg.resolvedSoundPath ~= nil) or visualShown
end

function Notifier:PlayBloodlustNotification(cfg, fallbackPaths)
    cfg = type(cfg) == "table" and cfg or {}
    local fallbackText = L("ENTRY_TYPE_BLOODLUST")
    local channel = tostring(cfg.alertChannel or "all")
    local visualShown = self:ShowVisualAlerts(cfg, fallbackText)
    if channel ~= "all" and channel ~= "voice" then
        return visualShown
    end
    if cfg.voiceEnabled == false then
        return visualShown
    end

    local mode = tostring(cfg.notifyMode or MODE_SOUND)
    local source = tostring(cfg.soundSource or "")
    if mode == MODE_TTS or source == "tts" then
        local text = TrimText(cfg.ttsText or "")
        if text == "" then
            text = fallbackText
        end
        return self:SpeakTextTTS(text, cfg.ttsRate) or visualShown
    end

    local path = ""
    if source == "custom" then
        path = self:GetRandomNonEmptyPath(type(cfg.customSoundPaths) == "table" and cfg.customSoundPaths or fallbackPaths) or ""
        if path == "" then
            path = self:NormalizeSoundPath(cfg.customSoundPath or cfg.soundPath or "")
        end
    elseif source == "sharedmedia" or source == "builtin" then
        path = self:ResolveEntrySoundPath(cfg)
    else
        path = self:ResolveEntrySoundPath(cfg)
        if path == "" then
            path = self:GetRandomNonEmptyPath(type(cfg.customSoundPaths) == "table" and cfg.customSoundPaths or fallbackPaths) or ""
        end
    end

    if path == "" then
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage((NS.ADDON_CHAT_PREFIX or "") .. " " .. L("MSG_NO_BLOODLUST_SOUND_PATH"))
        end
        return visualShown
    end
    return self:PlayVoiceFile(path) or visualShown
end
