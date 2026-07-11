local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.Core = NS.Core or {}
NS.Core.VisualGroups = NS.Core.VisualGroups or {}

local VisualGroups = NS.Core.VisualGroups
local VALID_DIRECTIONS = {
    LEFT = true,
    RIGHT = true,
    UP = true,
    DOWN = true,
}

local function Round(value, fallback)
    local number = tonumber(value)
    if number == nil then
        number = tonumber(fallback) or 0
    end
    if number >= 0 then
        return math.floor(number + 0.5)
    end
    return math.ceil(number - 0.5)
end

local function NormalizeDirection(value)
    value = tostring(value or "RIGHT"):upper()
    if VALID_DIRECTIONS[value] then
        return value
    end
    return "RIGHT"
end

local function GetRootDB()
    if type(QFXSkillAlertsDB) ~= "table" then
        QFXSkillAlertsDB = {}
    end
    return QFXSkillAlertsDB
end

function VisualGroups:GetStore()
    local db = GetRootDB()
    if type(db.visualGroups) ~= "table" then
        db.visualGroups = {}
    end
    local store = db.visualGroups
    store.version = 1
    store.nextID = math.max(1, math.floor(tonumber(store.nextID) or 1))
    if type(store.groups) ~= "table" then store.groups = {} end
    if type(store.members) ~= "table" then store.members = {} end
    return store
end

function VisualGroups:GetMember(entryKey)
    entryKey = tostring(entryKey or "")
    if entryKey == "" then return nil end
    local member = self:GetStore().members[entryKey]
    return type(member) == "table" and member or nil
end

function VisualGroups:GetGroup(groupID)
    groupID = tostring(groupID or "")
    if groupID == "" then return nil end
    local group = self:GetStore().groups[groupID]
    return type(group) == "table" and group or nil
end

function VisualGroups:GetGroupForEntry(entryKey)
    local member = self:GetMember(entryKey)
    if not member then return nil, nil end
    local groupID = tostring(member.groupID or "")
    local group = self:GetGroup(groupID)
    if not group then return nil, nil end
    return group, member
end

function VisualGroups:GetOrderedMembers(groupID)
    groupID = tostring(groupID or "")
    local results = {}
    if groupID == "" then return results end
    local members = self:GetStore().members
    for entryKey, member in pairs(members) do
        if type(member) == "table" and tostring(member.groupID or "") == groupID then
            results[#results + 1] = {
                entryKey = tostring(entryKey),
                order = math.max(1, math.floor(tonumber(member.order) or 1)),
                member = member,
            }
        end
    end
    table.sort(results, function(left, right)
        if left.order ~= right.order then
            return left.order < right.order
        end
        return left.entryKey < right.entryKey
    end)
    return results
end

function VisualGroups:NormalizeOrders(groupID)
    local ordered = self:GetOrderedMembers(groupID)
    for index, item in ipairs(ordered) do
        item.member.order = index
    end
    return ordered
end

function VisualGroups:CreateGroup(x, y, direction, gap)
    local store = self:GetStore()
    local serial = store.nextID
    store.nextID = serial + 1
    local groupID = "visual-group:" .. tostring(serial)
    store.groups[groupID] = {
        x = Round(x, 0),
        y = Round(y, 120),
        direction = NormalizeDirection(direction),
        gap = math.max(0, Round(gap, 4)),
    }
    return groupID, store.groups[groupID]
end

function VisualGroups:SetGroupPosition(groupID, x, y)
    local group = self:GetGroup(groupID)
    if not group then return false end
    group.x = Round(x, group.x or 0)
    group.y = Round(y, group.y or 120)
    self:RefreshRuntime()
    return true
end

function VisualGroups:SetDirectionForEntry(entryKey, direction)
    local group = self:GetGroupForEntry(entryKey)
    if not group then return false end
    group.direction = NormalizeDirection(direction)
    self:RefreshRuntime()
    return true
end

function VisualGroups:SetGapForEntry(entryKey, gap)
    local group = self:GetGroupForEntry(entryKey)
    if not group then return false end
    group.gap = math.max(0, Round(gap, group.gap or 4))
    self:RefreshRuntime()
    return true
end

function VisualGroups:RemoveMember(entryKey, keepEmptyGroup)
    entryKey = tostring(entryKey or "")
    if entryKey == "" then return false end
    local store = self:GetStore()
    local member = store.members[entryKey]
    if type(member) ~= "table" then return false end
    local groupID = tostring(member.groupID or "")
    store.members[entryKey] = nil
    local ordered = self:NormalizeOrders(groupID)
    if #ordered == 0 and not keepEmptyGroup then
        store.groups[groupID] = nil
    elseif #ordered == 1 and not keepEmptyGroup then
        -- A one-item dynamic group has no layout benefit. Dissolve it so the
        -- remaining entry returns to its own saved X/Y position.
        store.members[ordered[1].entryKey] = nil
        store.groups[groupID] = nil
    end
    self:RefreshRuntime()
    return true
end

function VisualGroups:JoinAfter(entryKey, targetKey, direction, targetX, targetY)
    entryKey = tostring(entryKey or "")
    targetKey = tostring(targetKey or "")
    if entryKey == "" or targetKey == "" or entryKey == targetKey then
        return false, "invalid-target"
    end

    local store = self:GetStore()
    self:RemoveMember(entryKey, false)

    local targetMember = store.members[targetKey]
    local groupID
    local group
    if type(targetMember) == "table" then
        groupID = tostring(targetMember.groupID or "")
        group = store.groups[groupID]
    end

    if type(group) ~= "table" then
        groupID, group = self:CreateGroup(targetX, targetY, direction, 4)
        store.members[targetKey] = {
            groupID = groupID,
            order = 1,
        }
        targetMember = store.members[targetKey]
    end

    group.direction = NormalizeDirection(direction or group.direction)
    local ordered = self:NormalizeOrders(groupID)
    local targetOrder = 1
    for _, item in ipairs(ordered) do
        if item.entryKey == targetKey then
            targetOrder = item.order
            break
        end
    end
    for _, item in ipairs(ordered) do
        if item.order > targetOrder then
            item.member.order = item.order + 1
        end
    end
    store.members[entryKey] = {
        groupID = groupID,
        order = targetOrder + 1,
    }
    self:NormalizeOrders(groupID)
    self:RefreshRuntime()
    return true, groupID
end

function VisualGroups:MoveMember(entryKey, delta)
    entryKey = tostring(entryKey or "")
    delta = tonumber(delta) or 0
    if entryKey == "" or delta == 0 then return false end
    local member = self:GetMember(entryKey)
    if not member then return false end
    local groupID = tostring(member.groupID or "")
    local ordered = self:NormalizeOrders(groupID)
    local oldIndex
    for index, item in ipairs(ordered) do
        if item.entryKey == entryKey then
            oldIndex = index
            break
        end
    end
    if not oldIndex then return false end
    local newIndex = math.max(1, math.min(#ordered, oldIndex + (delta < 0 and -1 or 1)))
    if newIndex == oldIndex then return false end
    local other = ordered[newIndex]
    member.order, other.member.order = other.member.order, member.order
    self:NormalizeOrders(groupID)
    self:RefreshRuntime()
    return true
end

function VisualGroups:RefreshRuntime()
    local notifier = NS.Core and NS.Core.Notifier
    if notifier and type(notifier.LayoutVisualSlots) == "function" then
        notifier:LayoutVisualSlots()
    end
end

function VisualGroups:BuildEntryKey(cfg)
    if type(cfg) ~= "table" then return "" end
    local explicit = tostring(cfg.visualEntryKey or cfg.entryKey or "")
    if explicit ~= "" then return explicit end
    local index = math.floor(tonumber(cfg.index) or 0)
    if index <= 0 then return "" end
    return string.format(
        "%d:%d:%d",
        tonumber(cfg.scopeClassID) or 0,
        tonumber(cfg.scopeSpecID) or 0,
        index
    )
end

local function WrapRuntimeConfigBuilder()
    local builder = NS.Core and NS.Core.RuntimeConfigBuilder
    if not builder or type(builder.Rebuild) ~= "function" or builder.qfxsaVisualGroupsWrapped then
        return
    end
    builder.qfxsaVisualGroupsWrapped = true
    local original = builder.Rebuild
    builder.Rebuild = function(self, spellToPrimary, runtimeCfg)
        local result = original(self, spellToPrimary, runtimeCfg)
        if type(runtimeCfg) == "table" then
            for _, cfg in pairs(runtimeCfg) do
                if type(cfg) == "table" then
                    cfg.visualEntryKey = VisualGroups:BuildEntryKey(cfg)
                end
            end
        end
        return result
    end
end

local function GetSlotSize(frame)
    return math.max(1, tonumber(frame and frame.qfxsaImageSize) or 96)
end

local function PositionVisibleGroup(items, group)
    table.sort(items, function(left, right)
        if left.order ~= right.order then return left.order < right.order end
        return left.entryKey < right.entryKey
    end)
    local direction = NormalizeDirection(group and group.direction)
    local gap = math.max(0, tonumber(group and group.gap) or 4)
    local x = tonumber(group and group.x) or tonumber(items[1].frame.qfxsaBaseX) or 0
    local y = tonumber(group and group.y) or tonumber(items[1].frame.qfxsaBaseY) or 120
    local previousSize
    for index, item in ipairs(items) do
        local size = GetSlotSize(item.frame)
        if index > 1 then
            local distance = ((previousSize or size) / 2) + gap + (size / 2)
            if direction == "LEFT" then
                x = x - distance
            elseif direction == "UP" then
                y = y + distance
            elseif direction == "DOWN" then
                y = y - distance
            else
                x = x + distance
            end
        end
        item.frame:ClearAllPoints()
        item.frame:SetPoint("CENTER", UIParent, "CENTER", Round(x, 0), Round(y, 120))
        previousSize = size
    end
end

local function WrapNotifier()
    local notifier = NS.Core and NS.Core.Notifier
    if not notifier or notifier.qfxsaVisualGroupsWrapped then return end
    notifier.qfxsaVisualGroupsWrapped = true

    local originalShow = notifier.ShowVisualSlot
    if type(originalShow) == "function" then
        notifier.ShowVisualSlot = function(self, primaryKey, kind, cfg, fallbackText, duration)
            local shown = originalShow(self, primaryKey, kind, cfg, fallbackText, duration)
            local resolvedKey = tostring(self.activeVisualKey or primaryKey or "")
            local slot = self.visualSlots and self.visualSlots[resolvedKey]
            local frame = slot and slot.frame
            if shown and frame and type(cfg) == "table" then
                frame.qfxsaVisualEntryKey = VisualGroups:BuildEntryKey(cfg)
                frame.qfxsaImageSize = math.max(16, tonumber(cfg.imageSize) or 96)
                frame.qfxsaHasImage = cfg.imageEnabled == true or tostring(kind or "") == "image" or tostring(kind or "") == "visual"
                self:LayoutVisualSlots()
            end
            return shown
        end
    end

    notifier.LayoutVisualSlots = function(self)
        if type(self.activeVisualOrder) ~= "table" or type(self.visualSlots) ~= "table" then
            return false
        end
        local grouped = {}
        for _, primaryKey in ipairs(self.activeVisualOrder) do
            local slot = self.visualSlots[primaryKey]
            local frame = slot and slot.frame
            if frame and frame.qfxsaVisible == true and frame.IsShown and frame:IsShown() then
                local entryKey = tostring(frame.qfxsaVisualEntryKey or "")
                local group, member = VisualGroups:GetGroupForEntry(entryKey)
                if group and member and frame.qfxsaHasImage == true then
                    local groupID = tostring(member.groupID or "")
                    grouped[groupID] = grouped[groupID] or {
                        group = group,
                        items = {},
                    }
                    grouped[groupID].items[#grouped[groupID].items + 1] = {
                        frame = frame,
                        entryKey = entryKey,
                        order = math.max(1, math.floor(tonumber(member.order) or 1)),
                    }
                else
                    frame:ClearAllPoints()
                    frame:SetPoint(
                        "CENTER",
                        UIParent,
                        "CENTER",
                        tonumber(frame.qfxsaBaseX) or 0,
                        tonumber(frame.qfxsaBaseY) or 120
                    )
                end
            end
        end
        for _, bucket in pairs(grouped) do
            if #bucket.items > 0 then
                PositionVisibleGroup(bucket.items, bucket.group)
            end
        end
        return true
    end
end

WrapRuntimeConfigBuilder()
WrapNotifier()
