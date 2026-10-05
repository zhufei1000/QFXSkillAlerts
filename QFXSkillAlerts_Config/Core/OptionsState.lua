local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.OptionsState = NS.OptionsState or {}

local GetNumClasses = rawget(_G, "GetNumClasses")
local GetClassInfo = rawget(_G, "GetClassInfo")
local GetNumSpecializationsForClassID = rawget(_G, "GetNumSpecializationsForClassID")
local GetSpecializationInfoForClassID = rawget(_G, "GetSpecializationInfoForClassID")

local L = NS.L or function(key, ...)
    if select("#", ...) > 0 then
        return string.format(tostring(key), ...)
    end
    return tostring(key)
end

local CONST = NS.Constants or {}
local Utils = NS.Utils or {}

local ALL_CLASSES_ID = CONST.ALL_CLASSES_ID or 0
local ALL_SPECS_ID = CONST.ALL_SPECS_ID or 0
local ALL_RACES_ID = CONST.ALL_RACES_ID or 0
local OBJECT_TYPE_SPELL = CONST.OBJECT_TYPE_SPELL or "spell"
local OBJECT_TYPE_ITEM = CONST.OBJECT_TYPE_ITEM or "item"
local ITEM_LOAD_NONE = CONST.ITEM_LOAD_NONE or "none"
local ITEM_LOAD_EQUIPPED = CONST.ITEM_LOAD_EQUIPPED or "equipped"
local ITEM_LOAD_BAGS = CONST.ITEM_LOAD_BAGS or "bags"


local function NormalizeConditionOp(value)
    value = tostring(value or "<=")
    if value == "<" or value == "<=" or value == ">" or value == ">=" or value == "==" then
        return value
    end
    if value == "=" then
        return "=="
    end
    return "<="
end

local function TrimText(value)
    if Utils.TrimText then
        return Utils.TrimText(value)
    end
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function NormalizeVisualStrata(value)
    local options = CONST.VISUAL_STRATA_OPTIONS or { "FULLSCREEN_DIALOG" }
    local strata = tostring(value or "")
    for _, option in ipairs(options) do
        if option == strata then
            return strata
        end
    end
    return CONST.VISUAL_STRATA_DEFAULT or "FULLSCREEN_DIALOG"
end

local function NormalizeEndEventMap(value)
    if type(value) ~= "table" then
        return {}
    end
    local normalized = {}
    for key, enabled in pairs(value) do
        if enabled == true and type(key) == "string" and key ~= "" then
            normalized[key] = true
        end
    end
    return normalized
end

local function GetApi()
    return NS.API
end

local function BuildInlineTexture(texture, size, left, right, top, bottom)
    if type(texture) ~= "string" and type(texture) ~= "number" then
        return ""
    end

    size = tonumber(size) or 14
    if left and right and top and bottom then
        return string.format("|T%s:%d:%d:0:0:256:256:%d:%d:%d:%d|t ", tostring(texture), size, size, left, right, top, bottom)
    end
    return string.format("|T%s:%d:%d|t ", tostring(texture), size, size)
end

local function GetClassColorCode(classFile)
    local color = RAID_CLASS_COLORS and classFile and RAID_CLASS_COLORS[classFile]
    if not color then
        return nil
    end

    local r = math.floor(((tonumber(color.r) or 1) * 255) + 0.5)
    local g = math.floor(((tonumber(color.g) or 1) * 255) + 0.5)
    local b = math.floor(((tonumber(color.b) or 1) * 255) + 0.5)
    return string.format("|cff%02x%02x%02x", r, g, b)
end

local function BuildClassDisplayText(className, classFile)
    local icon = ""
    local coords = CLASS_ICON_TCOORDS and classFile and CLASS_ICON_TCOORDS[classFile]
    if coords then
        icon = BuildInlineTexture(
            "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES",
            14,
            math.floor((coords[1] or 0) * 256),
            math.floor((coords[2] or 1) * 256),
            math.floor((coords[3] or 0) * 256),
            math.floor((coords[4] or 1) * 256)
        )
    end

    local text = tostring(className or "-")
    local colorCode = GetClassColorCode(classFile)
    if colorCode then
        return icon .. colorCode .. text .. "|r"
    end
    return icon .. text
end

local function BuildSpecDisplayText(specName, specIcon)
    return BuildInlineTexture(specIcon, 14) .. tostring(specName or "-")
end

local function NormalizeItemLoadMode(value)
    value = tostring(value or ITEM_LOAD_NONE):lower()
    if value == ITEM_LOAD_EQUIPPED or value == ITEM_LOAD_BAGS then
        return value
    end
    return ITEM_LOAD_NONE
end

local function CopyNumberBoolMap(source)
    local copy = {}
    if type(source) == "table" then
        for key, value in pairs(source) do
            local numberKey = tonumber(key)
            if value == true and numberKey and numberKey >= 0 then
                copy[numberKey] = true
            end
        end
    end
    return copy
end

local function NormalizeRaceMap(source)
    local copy = CopyNumberBoolMap(source)
    if next(copy) == nil or copy[ALL_RACES_ID] == true then
        return { [ALL_RACES_ID] = true }
    end
    return copy
end

function NS.OptionsState:GetState(owner)
    owner = owner or NS.AceOptions or self
    owner.state = owner.state or {}
    local api = GetApi()
    if not api then
        return owner.state
    end

    if owner.state.classID == nil or owner.state.specID == nil then
        self:SyncScopeToCurrentSpec(owner)
    end
    local classID = tonumber(owner.state.classID) or 0
    if classID == ALL_CLASSES_ID then
        owner.state.specID = ALL_SPECS_ID
    end
    local modeTts, modeSound = api.GetModes()
    owner.state.notifyMode = owner.state.notifyMode or modeSound
    owner.state.fixedCD = true
    owner.state.checkTalent = owner.state.checkTalent == true
    local cdMode = tostring(owner.state.cdMode or "")
    if cdMode ~= "ready" and cdMode ~= "fixed" and cdMode ~= "cooldown" then
        cdMode = owner.state.gameStateCD == true and "ready" or "fixed"
    end
    owner.state.cdMode = cdMode
    owner.state.gameStateCD = cdMode ~= "fixed"
    owner.state.itemLoadMode = NormalizeItemLoadMode(owner.state.itemLoadMode)
    if tostring(owner.state.objectType or ""):lower() ~= OBJECT_TYPE_ITEM then
        owner.state.itemLoadMode = ITEM_LOAD_NONE
    end
    owner.state.itemLoadSameName = owner.state.itemLoadMode == ITEM_LOAD_BAGS and owner.state.itemLoadSameName == true
    owner.state.alertRaceIDs = NormalizeRaceMap(owner.state.alertRaceIDs)
    owner.state.customRaceIDs = owner.state.alertRaceIDs
    owner.state.talentId = tonumber(owner.state.talentId) or 0
    owner.state.talentName = tostring(owner.state.talentName or "")
    owner.state.talentCD = tonumber(owner.state.talentCD) or 0
    owner.state.talentLoadFilter = owner.state.talentLoadFilter == true
    owner.state.loadTalentEnabled = owner.state.loadTalentEnabled == true
    owner.state.loadTalentId = tonumber(owner.state.loadTalentId) or 0
    owner.state.loadTalentName = tostring(owner.state.loadTalentName or "")
    owner.state.eventKey = tostring(owner.state.eventKey or "combat_start")
    owner.state.eventThrottle = math.max(0, math.min(300, tonumber(owner.state.eventThrottle) or 1))
    owner.state.eventLoadContexts = type(api.NormalizeEventLoadContexts) == "function"
        and api.NormalizeEventLoadContexts(owner.state.eventLoadContexts)
        or (owner.state.eventLoadContexts or { world = true, delve = true, dungeon = true, raid = true })
    owner.state.eventDungeonMode = type(api.NormalizeEventInstanceMode) == "function"
        and api.NormalizeEventInstanceMode(owner.state.eventDungeonMode) or "any"
    owner.state.eventRaidMode = type(api.NormalizeEventInstanceMode) == "function"
        and api.NormalizeEventInstanceMode(owner.state.eventRaidMode) or "any"
    owner.state.eventDungeonSelectionIDs = type(api.NormalizeEventInstanceSelections) == "function"
        and api.NormalizeEventInstanceSelections(owner.state.eventDungeonSelectionIDs) or (owner.state.eventDungeonSelectionIDs or {})
    owner.state.eventRaidSelectionIDs = type(api.NormalizeEventInstanceSelections) == "function"
        and api.NormalizeEventInstanceSelections(owner.state.eventRaidSelectionIDs) or (owner.state.eventRaidSelectionIDs or {})
    owner.state.eventDungeonSelectionNames = type(api.NormalizeEventInstanceSelectionNames) == "function"
        and api.NormalizeEventInstanceSelectionNames(owner.state.eventDungeonSelectionNames) or (owner.state.eventDungeonSelectionNames or {})
    owner.state.eventRaidSelectionNames = type(api.NormalizeEventInstanceSelectionNames) == "function"
        and api.NormalizeEventInstanceSelectionNames(owner.state.eventRaidSelectionNames) or (owner.state.eventRaidSelectionNames or {})
    owner.state.delayEnabled = owner.state.delayEnabled == true
    owner.state.delaySeconds = math.max(0, tonumber(owner.state.delaySeconds) or 0)
    owner.state.castDelayMode = "show"
    owner.state.cooldownAlertTime = math.max(0, tonumber(owner.state.cooldownAlertTime) or 0)
    owner.state.voiceEnabled = owner.state.voiceEnabled ~= false
    local legacyAlertTime = math.max(0, tonumber(owner.state.cooldownAlertTime or owner.state.alertLeadTime) or 0)
    owner.state.voiceConditionOp = NormalizeConditionOp(owner.state.voiceConditionOp)
    owner.state.voiceConditionTime = math.max(0, tonumber(owner.state.voiceConditionTime) or legacyAlertTime)
    owner.state.activeAlertTab = tostring(owner.state.activeAlertTab or "settings")
    if owner.state.activeAlertTab ~= "settings" and owner.state.activeAlertTab ~= "voice" and owner.state.activeAlertTab ~= "image" and owner.state.activeAlertTab ~= "text" then
        owner.state.activeAlertTab = "settings"
    end
    owner.state.imageEnabled = owner.state.imageEnabled == true
    owner.state.imageConditionOp = NormalizeConditionOp(owner.state.imageConditionOp)
    owner.state.imageConditionTime = math.max(0, tonumber(owner.state.imageConditionTime) or legacyAlertTime)
    owner.state.imageSource = tostring(owner.state.imageSource or "auto")
    if owner.state.imageSource ~= "spell" and owner.state.imageSource ~= "item" and owner.state.imageSource ~= "icon" and owner.state.imageSource ~= "path" and owner.state.imageSource ~= "sharedmedia" then
        owner.state.imageSource = "auto"
    end
    owner.state.imageIconID = math.max(0, tonumber(owner.state.imageIconID) or 0)
    owner.state.imagePath = TrimText(owner.state.imagePath or "")
    owner.state.imageSharedMedia = TrimText(owner.state.imageSharedMedia or "")
    owner.state.imageSize = math.max(16, tonumber(owner.state.imageSize) or 96)
    owner.state.imageStrata = NormalizeVisualStrata(owner.state.imageStrata)
    owner.state.imageEndEvents = NormalizeEndEventMap(owner.state.imageEndEvents)
    owner.state.imageDurationEnabled = owner.state.imageDurationEnabled == true
    owner.state.imageDuration = math.max(0.1, tonumber(owner.state.imageDuration) or 2)
    owner.state.imageX = tonumber(owner.state.imageX) or 0
    owner.state.imageY = tonumber(owner.state.imageY) or 120
    owner.state.textEnabled = owner.state.textEnabled == true
    owner.state.textCooldownCountdown = owner.state.textCooldownCountdown == true
    owner.state.textConditionOp = NormalizeConditionOp(owner.state.textConditionOp)
    owner.state.textConditionTime = math.max(0, tonumber(owner.state.textConditionTime) or legacyAlertTime)
    owner.state.textAlert = tostring(owner.state.textAlert or "")
    owner.state.textSize = math.max(8, tonumber(owner.state.textSize) or 24)
    owner.state.textDurationEnabled = owner.state.textDurationEnabled == true
    owner.state.textDuration = math.max(0.1, tonumber(owner.state.textDuration) or 2)
    if Utils.SyncLinkedVisualDurations then
        Utils.SyncLinkedVisualDurations(owner.state)
    end
    owner.state.textX = tonumber(owner.state.textX) or 0
    owner.state.textY = tonumber(owner.state.textY) or 120
    owner.state.textAttachMode = tostring(owner.state.textAttachMode or "outside")
    if owner.state.textAttachMode ~= "inside" then owner.state.textAttachMode = "outside" end
    owner.state.textVAlign = tostring(owner.state.textVAlign or "bottom")
    if owner.state.textVAlign ~= "top" and owner.state.textVAlign ~= "middle" then owner.state.textVAlign = "bottom" end
    owner.state.textHAlign = tostring(owner.state.textHAlign or "center")
    if owner.state.textHAlign ~= "left" and owner.state.textHAlign ~= "right" then owner.state.textHAlign = "center" end
    owner.state.textOffsetX = tonumber(owner.state.textOffsetX) or 0
    owner.state.textOffsetY = tonumber(owner.state.textOffsetY) or 0
    owner.state.textEndEvents = NormalizeEndEventMap(owner.state.textEndEvents)

    local defaultBuiltin = owner:GetDefaultBuiltinSoundPath()
    owner.state.builtinSoundPath = owner:NormalizeSoundPath(owner.state.builtinSoundPath or defaultBuiltin)
    if owner.state.builtinSoundPath == "" or not owner:IsBuiltinSoundPath(owner.state.builtinSoundPath) then
        owner.state.builtinSoundPath = defaultBuiltin
    end
    owner.state.sharedMediaSound = TrimText(owner.state.sharedMediaSound or "")
    owner.state.useSharedMediaSound = owner.state.useSharedMediaSound == true
    owner.state.customSoundPath = owner:NormalizeSoundPath(owner.state.customSoundPath or "")
    owner.state.customSoundPaths = type(owner.state.customSoundPaths) == "table" and owner.state.customSoundPaths or { owner.state.customSoundPath or "", "", "", "", "" }
    for i = 1, 5 do
        owner.state.customSoundPaths[i] = owner:NormalizeSoundPath(owner.state.customSoundPaths[i] or "")
    end
    if TrimText(owner.state.customSoundPath or "") ~= "" and TrimText(owner.state.customSoundPaths[1] or "") == "" then
        owner.state.customSoundPaths[1] = owner.state.customSoundPath
    end
    owner.state.useCustomSound = owner.state.useCustomSound == true
    owner.state.soundSource = tostring(owner.state.soundSource or "")

    if TrimText(owner.state.soundPath or "") == "" and tostring(owner.state.notifyMode or "") ~= tostring(modeTts) then
        owner.state.soundPath = owner.state.builtinSoundPath
    else
        owner.state.soundPath = owner:NormalizeSoundPath(owner.state.soundPath or "")
    end

    if owner.state.soundSource == "" then
        local resolved = owner:ResolveSoundSourceFields(owner.state, modeTts, modeSound)
        owner.state.notifyMode = resolved.notifyMode
        owner.state.soundSource = resolved.soundSource
        owner.state.soundPath = resolved.soundPath
        owner.state.builtinSoundPath = resolved.builtinSoundPath
        owner.state.customSoundPath = resolved.customSoundPath
        owner.state.sharedMediaSound = resolved.sharedMediaSound
        owner.state.useCustomSound = resolved.useCustomSound == true
        owner.state.useSharedMediaSound = resolved.useSharedMediaSound == true
    end

    return owner.state
end

function NS.OptionsState:SyncScopeToCurrentSpec(owner)
    owner = owner or NS.AceOptions or self
    local api = GetApi()
    owner.state = owner.state or {}
    if not api or type(api.GetCurrentClassSpec) ~= "function" then
        return
    end

    local classID, specID = api.GetCurrentClassSpec()
    owner.state.classID = tonumber(classID) or 0
    owner.state.specID = tonumber(specID) or 0
    owner.state.selectedKey = nil
    owner.state.selectedCollectionKey = nil
end

function NS.OptionsState:GetClassOptionList(owner)
    local options = {
        { classID = ALL_CLASSES_ID, className = L("ALL_CLASSES"), classFile = nil },
    }
    if type(GetNumClasses) ~= "function" or type(GetClassInfo) ~= "function" then
        return options
    end

    local classCount = tonumber(GetNumClasses()) or 0
    for classIndex = 1, classCount do
        local ok, className, classFile, classID = pcall(GetClassInfo, classIndex)
        classID = tonumber(classID) or 0
        if ok and classID > 0 and type(className) == "string" and className ~= "" then
            options[#options + 1] = {
                classID = classID,
                className = className,
                classFile = classFile,
            }
        end
    end

    return options
end

function NS.OptionsState:GetClassValues(owner)
    local values = {}
    local classList = self:GetClassOptionList(owner)
    for _, option in ipairs(classList) do
        values[option.classID] = BuildClassDisplayText(option.className, option.classFile)
    end
    return values
end

function NS.OptionsState:GetSpecOptionList(owner, classID)
    classID = tonumber(classID) or 0
    local options = {
        {
            specID = ALL_SPECS_ID,
            specName = L("ALL_SPECS"),
            specIcon = nil,
        }
    }
    if classID == ALL_CLASSES_ID then
        return options
    end
    if classID < 0 then
        return options
    end

    if type(GetNumSpecializationsForClassID) ~= "function" or type(GetSpecializationInfoForClassID) ~= "function" then
        return options
    end

    local specCount = tonumber(GetNumSpecializationsForClassID(classID)) or 0
    for specIndex = 1, specCount do
        local ok, specID, specName, _, specIcon = pcall(GetSpecializationInfoForClassID, classID, specIndex)
        specID = tonumber(specID) or 0
        if ok and specID > 0 then
            options[#options + 1] = {
                specID = specID,
                specName = (type(specName) == "string" and specName ~= "") and specName or L("FALLBACK_SPEC", " " .. tostring(specID)),
                specIcon = specIcon,
            }
        end
    end

    return options
end

function NS.OptionsState:GetSpecValues(owner, classID)
    local values = {}
    for _, option in ipairs(self:GetSpecOptionList(owner, classID)) do
        values[option.specID] = BuildSpecDisplayText(option.specName, option.specIcon)
    end
    return values
end

function NS.OptionsState:EnsureValidScope(owner)
    owner = owner or NS.AceOptions or self
    local state = self:GetState(owner)
    if state.classID == nil then
        self:SyncScopeToCurrentSpec(owner)
    end
    state.classID = tonumber(state.classID) or 0
    state.specID = tonumber(state.specID) or 0

    if state.classID == ALL_CLASSES_ID then
        state.specID = ALL_SPECS_ID
        return
    end

    if state.classID < 0 then
        self:SyncScopeToCurrentSpec(owner)
    end

    local specValues = self:GetSpecValues(owner, state.classID)
    if not specValues[state.specID] then
        state.specID = ALL_SPECS_ID
    end
end

function NS.OptionsState:ClearEditorFields(owner)
    owner = owner or NS.AceOptions or self
    local api = GetApi()
    local state = self:GetState(owner)
    if not api or type(api.GetModes) ~= "function" then
        return
    end
    local _, modeSound = api.GetModes()

    state.selectedKey = nil
    state.spellId = 0
    state.objectType = OBJECT_TYPE_SPELL
    state.itemLoadMode = ITEM_LOAD_NONE
    state.itemLoadSameName = false
    state.alertRaceIDs = { [ALL_RACES_ID] = true }
    state.customRaceIDs = state.alertRaceIDs
    local classID, specID = 0, 0
    if api and type(api.GetCurrentClassSpec) == "function" then
        classID, specID = api.GetCurrentClassSpec()
    end
    classID = tonumber(classID) or 0
    specID = tonumber(specID) or 0
    state.alertClassIDs = { [classID > 0 and classID or ALL_CLASSES_ID] = true }
    state.customClassIDs = state.alertClassIDs
    state.alertSpecIDs = { [specID > 0 and specID or ALL_SPECS_ID] = true }
    state.customSpecIDs = state.alertSpecIDs
    state.spellName = ""
    state.baseCD = 0
    state.fixedCD = true
    state.checkTalent = false
    -- New cooldown entries default to the game readiness edge ("Ready"):
    -- no manual cooldown number is needed. Existing saved entries keep the
    -- mode they were stored with; item/cast entries still force "fixed".
    state.cdMode = "ready"
    state.gameStateCD = true
    state.talentId = 0
    state.talentName = ""
    state.talentCD = 0
    state.talentLoadFilter = false
    state.loadTalentEnabled = false
    state.loadTalentId = 0
    state.loadTalentName = ""
    state.eventKey = "combat_start"
    state.eventThrottle = 1
    state.eventLoadContexts = { world = true, delve = true, dungeon = true, raid = true }
    state.eventDungeonMode = "any"
    state.eventRaidMode = "any"
    state.eventDungeonSelectionIDs = {}
    state.eventRaidSelectionIDs = {}
    state.eventDungeonSelectionNames = {}
    state.eventRaidSelectionNames = {}
    state.delayEnabled = false
    state.delaySeconds = 0
    state.castDelayMode = "show"
    state.cooldownAlertTime = 0
    state.notifyMode = modeSound
    state.ttsText = ""
    state.ttsRate = 0
    state.builtinSoundPath = owner:GetDefaultBuiltinSoundPath()
    state.sharedMediaSound = ""
    state.useSharedMediaSound = false
    state.customSoundPath = ""
    state.customSoundPaths = { "", "", "", "", "" }
    state.useCustomSound = false
    -- New alerts default to the SharedMedia library instead of the built-in
    -- sound list; the concrete sound is picked in the sound section.
    state.soundSource = "sharedmedia"
    state.soundPath = ""
    state.voiceEnabled = false
    state.voiceConditionOp = "<="
    state.voiceConditionTime = 0
    state.activeAlertTab = "settings"
    state.imageEnabled = false
    state.imageConditionOp = "<="
    state.imageConditionTime = 0
    state.imageSource = "auto"
    state.imageIconID = 0
    state.imagePath = ""
    state.imageSharedMedia = ""
    state.imageSize = 96
    state.imageStrata = CONST.VISUAL_STRATA_DEFAULT or "FULLSCREEN_DIALOG"
    state.imageEndEvents = {}
    state.imageDurationEnabled = false
    state.imageDuration = 2
    state.imageX = 0
    state.imageY = 120
    state.textEnabled = false
    state.textCooldownCountdown = false
    state.textConditionOp = "<="
    state.textConditionTime = 0
    state.textAlert = ""
    state.textSize = 24
    state.textDurationEnabled = false
    state.textDuration = 2
    state.textX = 0
    state.textY = 120
    state.textAttachMode = "outside"
    state.textVAlign = "bottom"
    state.textHAlign = "center"
    state.textOffsetX = 0
    state.textOffsetY = 0
    state.textEndEvents = {}
end

