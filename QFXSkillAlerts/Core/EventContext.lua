local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.Core = NS.Core or {}
NS.Core.EventContext = NS.Core.EventContext or {}

local EventContext = NS.Core.EventContext

local CONTEXT_KEYS = { "world", "delve", "dungeon", "raid" }
local DELVE_STATE_FUNCTIONS = { "HasActiveDelve", "HasActiveLair", "HasActiveLFGLair", "IsInLair" }
local INSTANCE_MODE_ANY = "any"
local INSTANCE_MODE_SEASON = "season"
local INSTANCE_MODE_SPECIFIC = "specific"

local dungeonCatalog = { built = false, ids = {}, names = {}, nameByID = {}, items = {} }
local raidCatalog = { built = false, names = {}, nameByID = {}, items = {} }

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, a, b, c, d, e = pcall(fn, ...)
    if not ok then
        return nil
    end
    return a, b, c, d, e
end

local function NormalizeName(value)
    value = tostring(value or ""):lower()
    value = value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    value = value:gsub("[%s%p]", "")
    return value
end

local function AddName(catalog, value)
    local name = NormalizeName(value)
    if name ~= "" then
        catalog.names[name] = true
    end
end

local function NamesMatch(catalog, instanceName)
    local current = NormalizeName(instanceName)
    if current == "" then
        return false
    end
    if catalog.names[current] == true then
        return true
    end
    for name in pairs(catalog.names) do
        if #name >= 4 and (current:find(name, 1, true) or name:find(current, 1, true)) then
            return true
        end
    end
    return false
end

local function IsCombatLocked()
    return type(InCombatLockdown) == "function" and InCombatLockdown() == true
end

local function BuildDungeonCatalog()
    if dungeonCatalog.built or IsCombatLocked() then
        return dungeonCatalog.built
    end
    local challengeMode = rawget(_G, "C_ChallengeMode")
    local mapIDs = challengeMode and SafeCall(challengeMode.GetMapTable)
    if type(mapIDs) ~= "table" or #mapIDs == 0 then
        return false
    end
    for _, value in ipairs(mapIDs) do
        local challengeMapID = tonumber(value)
        if challengeMapID then
            dungeonCatalog.ids[challengeMapID] = true
            local name = SafeCall(challengeMode.GetMapUIInfo, challengeMapID)
            AddName(dungeonCatalog, name)
            name = tostring(name or "")
            dungeonCatalog.nameByID[tostring(challengeMapID)] = name
            dungeonCatalog.items[#dungeonCatalog.items + 1] = { value = tostring(challengeMapID), text = name }
        end
    end
    table.sort(dungeonCatalog.items, function(left, right) return tostring(left.text or "") < tostring(right.text or "") end)
    dungeonCatalog.built = next(dungeonCatalog.ids) ~= nil
    return dungeonCatalog.built
end

local function BitOr(left, right)
    local bitLib = rawget(_G, "bit") or rawget(_G, "bit32")
    if bitLib and type(bitLib.bor) == "function" then
        return bitLib.bor(tonumber(left) or 0, tonumber(right) or 0)
    end
    return (tonumber(left) or 0) + (tonumber(right) or 0)
end

local function GetRaidCategoryID()
    local globalID = tonumber(rawget(_G, "GROUP_FINDER_CATEGORY_ID_RAIDS"))
    if globalID then
        return globalID
    end
    local enum = rawget(_G, "Enum")
    local category = enum and enum.LFGListCategory
    return tonumber(category and (category.Raids or category.Raid)) or 3
end

local function GetCurrentSeasonFilter()
    local enum = rawget(_G, "Enum")
    local filters = enum and enum.LFGListFilter
    local currentSeason = tonumber(filters and filters.CurrentSeason)
    if not currentSeason then
        return nil
    end
    local pve = tonumber(filters and filters.PvE) or 0
    return BitOr(currentSeason, pve)
end

local function BuildRaidCatalog()
    if raidCatalog.built or IsCombatLocked() then
        return raidCatalog.built
    end
    local lfg = rawget(_G, "C_LFGList")
    local seasonFilter = GetCurrentSeasonFilter()
    if not lfg or not seasonFilter then
        return false
    end

    local categoryID = GetRaidCategoryID()
    local groupIDs = SafeCall(lfg.GetAvailableActivityGroups, categoryID, seasonFilter)
    if type(groupIDs) ~= "table" then
        return false
    end

    for _, value in ipairs(groupIDs) do
        local groupID = tonumber(value)
        if groupID then
            local groupName = tostring(SafeCall(lfg.GetActivityGroupInfo, groupID) or "")
            AddName(raidCatalog, groupName)
            raidCatalog.nameByID[tostring(groupID)] = groupName
            raidCatalog.items[#raidCatalog.items + 1] = { value = tostring(groupID), text = groupName }
            local activityIDs = SafeCall(lfg.GetAvailableActivities, categoryID, groupID, seasonFilter)
            if type(activityIDs) == "table" then
                for _, activityValue in ipairs(activityIDs) do
                    local info = SafeCall(lfg.GetActivityInfoTable, activityValue)
                    if type(info) == "table" then
                        AddName(raidCatalog, info.fullName)
                        AddName(raidCatalog, info.shortName)
                    end
                end
            end
        end
    end

    table.sort(raidCatalog.items, function(left, right) return tostring(left.text or "") < tostring(right.text or "") end)
    raidCatalog.built = next(raidCatalog.names) ~= nil
    return raidCatalog.built
end

local function IsDelveActive()
    local delves = rawget(_G, "C_DelvesUI")
    if type(delves) ~= "table" then
        return false
    end
    for _, name in ipairs(DELVE_STATE_FUNCTIONS) do
        if SafeCall(delves[name]) == true then
            return true
        end
    end
    return false
end

function EventContext:NormalizeLoadContexts(source)
    local result = {}
    if type(source) == "table" then
        for _, key in ipairs(CONTEXT_KEYS) do
            if source[key] == true then
                result[key] = true
            end
        end
    end
    if next(result) == nil then
        for _, key in ipairs(CONTEXT_KEYS) do
            result[key] = true
        end
    end
    return result
end

function EventContext:HasSelectedLoadContext(source)
    if type(source) ~= "table" then
        return false
    end
    for _, key in ipairs(CONTEXT_KEYS) do
        if source[key] == true then
            return true
        end
    end
    return false
end

function EventContext:NormalizeInstanceMode(value)
    value = tostring(value or "")
    if value == INSTANCE_MODE_SEASON or value == INSTANCE_MODE_SPECIFIC then
        return value
    end
    return INSTANCE_MODE_ANY
end

function EventContext:NormalizeInstanceSelections(source)
    local result = {}
    if type(source) == "table" then
        for key, selected in pairs(source) do
            local id = tonumber(key)
            if selected == true and id and id > 0 then
                result[tostring(math.floor(id))] = true
            end
        end
    end
    return result
end

function EventContext:NormalizeInstanceSelectionNames(source)
    local result = {}
    if type(source) == "table" then
        for key, value in pairs(source) do
            local id = tonumber(key)
            local name = tostring(value or "")
            if id and id > 0 and name ~= "" then
                result[tostring(math.floor(id))] = name
            end
        end
    end
    return result
end

local function SelectionSignature(source)
    local ids = {}
    for id in pairs(EventContext:NormalizeInstanceSelections(source)) do ids[#ids + 1] = tonumber(id) or 0 end
    table.sort(ids)
    return table.concat(ids, ",")
end

function EventContext:BuildLoadConditionSignature(entry)
    entry = type(entry) == "table" and entry or {}
    local contexts = self:NormalizeLoadContexts(entry.eventLoadContexts)
    local parts = {}
    for _, key in ipairs(CONTEXT_KEYS) do
        if contexts[key] == true then parts[#parts + 1] = key end
    end
    if contexts.dungeon then
        local mode = self:NormalizeInstanceMode(entry.eventDungeonMode)
        parts[#parts + 1] = "dungeon=" .. mode
        if mode == INSTANCE_MODE_SPECIFIC then
            parts[#parts + 1] = "dungeonIDs=" .. SelectionSignature(entry.eventDungeonSelectionIDs)
        end
    end
    if contexts.raid then
        local mode = self:NormalizeInstanceMode(entry.eventRaidMode)
        parts[#parts + 1] = "raid=" .. mode
        if mode == INSTANCE_MODE_SPECIFIC then
            parts[#parts + 1] = "raidIDs=" .. SelectionSignature(entry.eventRaidSelectionIDs)
        end
    end
    return table.concat(parts, ";")
end

local function SpecificSelectionsOverlap(left, right)
    left = EventContext:NormalizeInstanceSelections(left)
    right = EventContext:NormalizeInstanceSelections(right)
    for id in pairs(left) do
        if right[id] == true then return true end
    end
    return false
end

local function InstanceConditionsOverlap(leftMode, leftIDs, rightMode, rightIDs)
    leftMode = EventContext:NormalizeInstanceMode(leftMode)
    rightMode = EventContext:NormalizeInstanceMode(rightMode)
    if leftMode == INSTANCE_MODE_ANY or rightMode == INSTANCE_MODE_ANY then
        return true
    end
    if leftMode == INSTANCE_MODE_SEASON or rightMode == INSTANCE_MODE_SEASON then
        local specificIDs = leftMode == INSTANCE_MODE_SPECIFIC and leftIDs or rightIDs
        return leftMode ~= INSTANCE_MODE_SPECIFIC and rightMode ~= INSTANCE_MODE_SPECIFIC
            or next(EventContext:NormalizeInstanceSelections(specificIDs)) ~= nil
    end
    return SpecificSelectionsOverlap(leftIDs, rightIDs)
end

function EventContext:LoadConditionsOverlap(left, right)
    left = type(left) == "table" and left or {}
    right = type(right) == "table" and right or {}
    local leftContexts = self:NormalizeLoadContexts(left.eventLoadContexts)
    local rightContexts = self:NormalizeLoadContexts(right.eventLoadContexts)
    if leftContexts.world and rightContexts.world then return true end
    if leftContexts.delve and rightContexts.delve then return true end
    if leftContexts.dungeon and rightContexts.dungeon and InstanceConditionsOverlap(
        left.eventDungeonMode, left.eventDungeonSelectionIDs,
        right.eventDungeonMode, right.eventDungeonSelectionIDs) then
        return true
    end
    if leftContexts.raid and rightContexts.raid and InstanceConditionsOverlap(
        left.eventRaidMode, left.eventRaidSelectionIDs,
        right.eventRaidMode, right.eventRaidSelectionIDs) then
        return true
    end
    return false
end

function EventContext:GetInstanceModeOptions()
    local L = NS.L or function(key) return tostring(key) end
    return {
        { value = INSTANCE_MODE_ANY, text = L("EVENT_LOAD_MODE_ANY") },
        { value = INSTANCE_MODE_SEASON, text = L("EVENT_LOAD_MODE_CURRENT_SEASON") },
        { value = INSTANCE_MODE_SPECIFIC, text = L("EVENT_LOAD_MODE_SPECIFIC") },
    }
end

function EventContext:GetSeasonInstanceOptions(kind, selectedIDs, selectedNames)
    local catalog = tostring(kind or "") == "raid" and raidCatalog or dungeonCatalog
    if catalog == raidCatalog then BuildRaidCatalog() else BuildDungeonCatalog() end
    local options = {}
    for _, item in ipairs(catalog.items) do
        options[#options + 1] = { value = item.value, text = item.text }
    end
    table.sort(options, function(left, right) return tostring(left.text or "") < tostring(right.text or "") end)
    return options
end

function EventContext:FilterCurrentSeasonSelections(kind, selectedIDs)
    selectedIDs = self:NormalizeInstanceSelections(selectedIDs)
    local catalog = tostring(kind or "") == "raid" and raidCatalog or dungeonCatalog
    local ready
    if catalog == raidCatalog then
        ready = BuildRaidCatalog()
    else
        ready = BuildDungeonCatalog()
    end
    if not ready then
        return selectedIDs
    end
    local result = {}
    for id in pairs(selectedIDs) do
        local available
        if catalog == raidCatalog then
            available = catalog.nameByID[id] ~= nil
        else
            available = catalog.ids[tonumber(id)] == true
        end
        if available then result[id] = true end
    end
    return result
end

function EventContext:ResolveInstanceSelectionNames(kind, selectedIDs, savedNames)
    selectedIDs = self:NormalizeInstanceSelections(selectedIDs)
    savedNames = self:NormalizeInstanceSelectionNames(savedNames)
    local catalog = tostring(kind or "") == "raid" and raidCatalog or dungeonCatalog
    if catalog == raidCatalog then BuildRaidCatalog() else BuildDungeonCatalog() end
    local result = {}
    for id in pairs(selectedIDs) do
        if not catalog.built or catalog.nameByID[id] then
            result[id] = catalog.nameByID[id] or savedNames[id] or id
        end
    end
    return result
end

function EventContext:GetCurrentContext()
    local instanceName, instanceType, _, _, _, _, _, instanceID
    if type(GetInstanceInfo) == "function" then
        instanceName, instanceType, _, _, _, _, _, instanceID = GetInstanceInfo()
    end
    if IsDelveActive() then
        return "delve", tostring(instanceName or ""), tonumber(instanceID) or 0
    end
    instanceType = tostring(instanceType or "none")
    if instanceType == "party" then
        return "dungeon", tostring(instanceName or ""), tonumber(instanceID) or 0
    end
    if instanceType == "raid" then
        return "raid", tostring(instanceName or ""), tonumber(instanceID) or 0
    end
    return "world", tostring(instanceName or ""), tonumber(instanceID) or 0
end

function EventContext:GetCurrentContextKey()
    local context, instanceName, instanceID = self:GetCurrentContext()
    return table.concat({ tostring(context or "world"), tostring(instanceID or 0), NormalizeName(instanceName) }, ":")
end

function EventContext:IsCurrentSeasonDungeon(instanceName)
    if not BuildDungeonCatalog() then
        return true
    end
    local challengeMode = rawget(_G, "C_ChallengeMode")
    local activeMapID = challengeMode and tonumber(SafeCall(challengeMode.GetActiveChallengeMapID))
    if activeMapID and activeMapID > 0 then
        return dungeonCatalog.ids[activeMapID] == true
    end
    return NamesMatch(dungeonCatalog, instanceName)
end

function EventContext:IsCurrentSeasonRaid(instanceName)
    if not BuildRaidCatalog() then
        return true
    end
    return NamesMatch(raidCatalog, instanceName)
end

function EventContext:WarmForEntry(entry)
    if type(entry) ~= "table" or IsCombatLocked() then
        return false
    end
    local contexts = self:NormalizeLoadContexts(entry.eventLoadContexts)
    local dungeonMode = self:NormalizeInstanceMode(entry.eventDungeonMode)
    local raidMode = self:NormalizeInstanceMode(entry.eventRaidMode)
    if contexts.dungeon and (dungeonMode == INSTANCE_MODE_SEASON or dungeonMode == INSTANCE_MODE_SPECIFIC) then
        BuildDungeonCatalog()
    end
    if contexts.raid and (raidMode == INSTANCE_MODE_SEASON or raidMode == INSTANCE_MODE_SPECIFIC) then
        BuildRaidCatalog()
    end
    return true
end

function EventContext:MatchesEntry(entry)
    if type(entry) ~= "table" then
        return false
    end
    local context, instanceName = self:GetCurrentContext()
    local contexts = entry.eventLoadContexts
    local hasSelection = false
    if type(contexts) == "table" then
        for _, key in ipairs(CONTEXT_KEYS) do
            if contexts[key] == true then
                hasSelection = true
                break
            end
        end
    end
    if hasSelection and contexts[context] ~= true then
        return false
    end
    if context == "dungeon" and self:NormalizeInstanceMode(entry.eventDungeonMode) == INSTANCE_MODE_SEASON then
        return self:IsCurrentSeasonDungeon(instanceName)
    end
    if context == "dungeon" and self:NormalizeInstanceMode(entry.eventDungeonMode) == INSTANCE_MODE_SPECIFIC then
        if not BuildDungeonCatalog() then return false end
        local selected = self:NormalizeInstanceSelections(entry.eventDungeonSelectionIDs)
        local activeMapID = rawget(_G, "C_ChallengeMode")
            and tonumber(SafeCall(C_ChallengeMode.GetActiveChallengeMapID))
        if activeMapID and dungeonCatalog.ids[activeMapID] and selected[tostring(activeMapID)] then return true end
        for id in pairs(selected) do
            local name = dungeonCatalog.nameByID[id]
            if name and NamesMatch({ names = { [NormalizeName(name)] = true } }, instanceName) then return true end
        end
        return false
    end
    if context == "raid" and self:NormalizeInstanceMode(entry.eventRaidMode) == INSTANCE_MODE_SEASON then
        return self:IsCurrentSeasonRaid(instanceName)
    end
    if context == "raid" and self:NormalizeInstanceMode(entry.eventRaidMode) == INSTANCE_MODE_SPECIFIC then
        if not BuildRaidCatalog() then return false end
        local selected = self:NormalizeInstanceSelections(entry.eventRaidSelectionIDs)
        for id in pairs(selected) do
            local name = raidCatalog.nameByID[id]
            if name and NamesMatch({ names = { [NormalizeName(name)] = true } }, instanceName) then return true end
        end
        return false
    end
    return true
end
