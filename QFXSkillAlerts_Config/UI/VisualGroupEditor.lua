local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS
NS.UI = NS.UI or {}
NS.UI.VisualGroupEditor = NS.UI.VisualGroupEditor or {}

local M = NS.UI.VisualGroupEditor
local P = NS.UI.VisualPositionPreview or {}
local G = NS.Core and NS.Core.VisualGroups
local locale = type(GetLocale) == "function" and GetLocale() or "enUS"

local function T(en, cn, tw)
    if locale == "zhCN" then return cn end
    if locale == "zhTW" then return tw end
    return en
end

local L = {
    open = T("Dynamic Group", "动态组", "動態組"),
    title = T("Image Dynamic Group", "图片动态组", "圖片動態組"),
    copy = T("Copy Size", "复制大小", "複製大小"),
    join = T("Join Target", "加入目标组", "加入目標組"),
    remove = T("Ungroup", "解除分组", "解除分組"),
    earlier = T("Earlier", "向前", "向前"),
    later = T("Later", "向后", "向後"),
    idle = T("Choose an action, then click another preview image.", "选择操作后，点击另一张预览图片。", "選擇操作後，點擊另一張預覽圖片。"),
    copyWait = T("Click the image whose size should be copied.", "点击要复制大小的目标图片。", "點擊要複製大小的目標圖片。"),
    joinWait = T("Click the image whose dynamic group should be joined.", "点击要加入的目标组图片。", "點擊要加入的目標組圖片。"),
    saved = T("Save this alert once before grouping it.", "请先保存一次该提醒，再设置动态组。", "請先儲存一次該提醒，再設定動態組。"),
    noGroup = T("This image is not grouped.", "当前图片不在动态组中。", "目前圖片不在動態組中。"),
    joined = T("Joined the target dynamic group.", "已加入目标图片的动态组。", "已加入目標圖片的動態組。"),
    ungrouped = T("Removed from the dynamic group.", "已解除动态组。", "已解除動態組。"),
    invalid = T("Invalid target image.", "目标图片无效。", "目標圖片無效。"),
}

local glyph = { RIGHT = "→", LEFT = "←", UP = "↑", DOWN = "↓" }
local validDirection = { RIGHT = true, LEFT = true, UP = true, DOWN = true }

local function Round(value, fallback)
    local n = tonumber(value)
    if n == nil then n = tonumber(fallback) or 0 end
    return n >= 0 and math.floor(n + 0.5) or math.ceil(n - 0.5)
end

local function State()
    return NS.AceOptions and NS.AceOptions.GetState and NS.AceOptions:GetState() or {}
end

local function SelectedKey()
    return tostring(State().selectedKey or "")
end

local function SelectedIdentity()
    local state = State()
    local uid = tostring(state.visualUID or "")
    if uid == "" and G then
        uid = tostring(G:ResolveIdentity(state.selectedKey) or "")
        if uid ~= "" then state.visualUID = uid end
    end
    return uid
end

local function EntryKey(cfg)
    if type(cfg) ~= "table" then return "" end
    local key = tostring(cfg.entryKey or cfg.visualEntryKey or "")
    if key ~= "" then return key end
    local index = math.floor(tonumber(cfg.index) or 0)
    if index <= 0 then return "" end
    return string.format("%d:%d:%d", tonumber(cfg.classID or cfg.scopeClassID) or 0, tonumber(cfg.specID or cfg.scopeSpecID) or 0, index)
end

local function EntryIdentity(cfg)
    if type(cfg) ~= "table" then return "" end
    local uid = tostring(cfg.visualUID or "")
    if uid == "" and G then
        uid = tostring(G:ResolveIdentity(cfg) or "")
        if uid ~= "" then cfg.visualUID = uid end
    end
    return uid ~= "" and uid or EntryKey(cfg)
end

local function Button(parent, text, width)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width or 82, 23)
    b:SetText(text)
    return b
end

local function SetBackdrop(frame)
    if not frame.SetBackdrop then return end
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0.03, 0.04, 0.06, 0.96)
    frame:SetBackdropBorderColor(0.72, 0.55, 0.18, 0.95)
end

function M:SetStatus(text)
    if self.panel and self.panel.status then self.panel.status:SetText(text or "") end
end

function M:Direction()
    local direction = tostring(self.direction or "RIGHT")
    return validDirection[direction] and direction or "RIGHT"
end

function M:SetDirection(direction)
    self.direction = validDirection[direction] and direction or "RIGHT"
    local identity = SelectedIdentity()
    if identity ~= "" and G and G:GetMember(identity) then G:SetDirectionForEntry(identity, self.direction) end
    self:UpdateDirectionButtons()
    self:RefreshLayout()
end

function M:UpdateDirectionButtons()
    if not self.panel or not self.panel.directions then return end
    for direction, button in pairs(self.panel.directions) do
        local fs = button:GetFontString()
        if fs then
            if direction == self:Direction() then fs:SetTextColor(1, 0.82, 0.25)
            else fs:SetTextColor(1, 1, 1) end
        end
    end
end

function M:EnsurePanel(editor)
    if self.panel then return self.panel end
    local f = CreateFrame("Frame", "QFXSkillAlertsVisualGroupPanel", UIParent, "BackdropTemplate")
    f:SetSize(500, 126)
    f:SetPoint("TOP", UIParent, "TOP", 0, -70)
    f:SetFrameStrata("TOOLTIP")
    f:SetFrameLevel(1200)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    SetBackdrop(f)
    f:Hide()

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -10)
    title:SetText(L.title)
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -3, -3)
    close:SetScript("OnClick", function() M:Exit() end)

    local copy = Button(f, L.copy, 88)
    copy:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -36)
    copy:SetScript("OnClick", function() M.action = "copy"; M:SetStatus(L.copyWait) end)
    local join = Button(f, L.join, 98)
    join:SetPoint("LEFT", copy, "RIGHT", 5, 0)
    join:SetScript("OnClick", function()
        if SelectedKey() == "" then M:SetStatus(L.saved); return end
        M.action = "join"; M:SetStatus(L.joinWait)
    end)
    local remove = Button(f, L.remove, 82)
    remove:SetPoint("LEFT", join, "RIGHT", 5, 0)
    remove:SetScript("OnClick", function() M:Ungroup() end)
    local earlier = Button(f, L.earlier, 70)
    earlier:SetPoint("LEFT", remove, "RIGHT", 5, 0)
    earlier:SetScript("OnClick", function() M:Move(-1) end)
    local later = Button(f, L.later, 70)
    later:SetPoint("LEFT", earlier, "RIGHT", 5, 0)
    later:SetScript("OnClick", function() M:Move(1) end)

    f.directions = {}
    local previous
    for _, direction in ipairs({ "LEFT", "RIGHT", "UP", "DOWN" }) do
        local d = direction
        local b = Button(f, glyph[d], 36)
        if previous then b:SetPoint("LEFT", previous, "RIGHT", 4, 0)
        else b:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -66) end
        b:SetScript("OnClick", function() M:SetDirection(d) end)
        f.directions[d] = b
        previous = b
    end

    local status = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("LEFT", previous, "RIGHT", 10, 0)
    status:SetPoint("RIGHT", f, "RIGHT", -12, 0)
    status:SetJustifyH("LEFT")
    status:SetText(L.idle)
    f.status = status

    self.panel = f
    self.editor = editor or self.editor
    self:UpdateDirectionButtons()
    return f
end

function M:Augment(editor, frame)
    if not frame or not frame.widgets or frame.qfxsaVGAdded then return end
    local section = frame.widgets.imagePositionSection
    if not section then return end
    frame.qfxsaVGAdded = true
    local b = Button(section, L.open, 88)
    b:SetPoint("TOPRIGHT", section, "TOPRIGHT", -12, -10)
    b:SetScript("OnClick", function() if M.active then M:Exit() else M:Enter(editor) end end)
    frame.widgets.visualGroupButton = b
end

function M:Badge(frame, entryKey)
    if not frame then return end
    local label = frame.qfxsaVGBadge
    if not label then
        label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetTextColor(1, 0.82, 0.2)
        frame.qfxsaVGBadge = label
    end
    label:ClearAllPoints()
    if frame.image then label:SetPoint("BOTTOM", frame.image, "TOP", 0, 3)
    else label:SetPoint("BOTTOM", frame, "TOP", 0, 3) end
    local group, member = G and G:GetGroupForEntry(entryKey)
    if group and member then
        label:SetText((glyph[group.direction] or "→") .. tostring(math.max(1, math.floor(tonumber(member.order) or 1))))
        label:Show()
    else label:Hide() end
end

function M:Hit(frame, cfg)
    if not frame then return end
    local hit = frame.qfxsaVGHit
    if not hit then
        hit = CreateFrame("Button", nil, frame, "BackdropTemplate")
        hit:SetFrameLevel((frame:GetFrameLevel() or 1) + 20)
        hit:RegisterForClicks("LeftButtonUp")
        if hit.SetBackdrop then
            hit:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
            hit:SetBackdropBorderColor(1, 0.75, 0.2, 0.95)
        end
        hit:SetScript("OnEnter", function(self) if self.SetBackdropColor then self:SetBackdropColor(1, 0.8, 0.2, 0.12) end end)
        hit:SetScript("OnLeave", function(self) if self.SetBackdropColor then self:SetBackdropColor(0, 0, 0, 0) end end)
        hit:SetScript("OnClick", function(self) M:Target(self.cfg) end)
        frame.qfxsaVGHit = hit
    end
    hit:ClearAllPoints()
    if frame.image then
        hit:SetPoint("TOPLEFT", frame.image, "TOPLEFT", -2, 2)
        hit:SetPoint("BOTTOMRIGHT", frame.image, "BOTTOMRIGHT", 2, -2)
    else hit:SetAllPoints(frame) end
    hit.cfg = cfg
    if self.active and cfg and cfg.imageEnabled == true then hit:Show() else hit:Hide() end
end

local function Place(items, group)
    table.sort(items, function(a, b) return a.order == b.order and a.key < b.key or a.order < b.order end)
    local direction = validDirection[group.direction] and group.direction or "RIGHT"
    local gap = math.max(0, tonumber(group.gap) or 4)
    local x, y = tonumber(group.x) or items[1].x or 0, tonumber(group.y) or items[1].y or 120
    local previous
    for index, item in ipairs(items) do
        local size = math.max(16, tonumber(item.size) or 96)
        if index > 1 then
            local step = ((previous or size) + size) / 2 + gap
            if direction == "LEFT" then x = x - step
            elseif direction == "UP" then y = y + step
            elseif direction == "DOWN" then y = y - step
            else x = x + step end
        end
        item.frame:ClearAllPoints()
        item.frame:SetPoint("CENTER", UIParent, "CENTER", Round(x, 0), Round(y, 120))
        previous = size
    end
end

function M:RefreshLayout()
    if not self.active or not G then return end
    local state, selected = State(), SelectedIdentity()
    local configs = P.GetLoadedReferenceConfigs and P:GetLoadedReferenceConfigs() or {}
    local buckets = {}
    local function Add(frame, cfg, key)
        if not frame or key == "" then return end
        local group, member = G:GetGroupForEntry(key)
        if group and member then
            local id = tostring(member.groupID or "")
            buckets[id] = buckets[id] or { group = group, items = {} }
            buckets[id].items[#buckets[id].items + 1] = {
                frame = frame, key = key,
                order = math.max(1, math.floor(tonumber(member.order) or 1)),
                size = tonumber(cfg.imageSize) or 96,
                x = tonumber(cfg.imageX) or 0, y = tonumber(cfg.imageY) or 120,
            }
        end
        M:Badge(frame, key)
    end
    if P.frame and P.frame:IsShown() and selected ~= "" then Add(P.frame, state, selected) end
    for index, cfg in ipairs(configs) do
        local frame = P.referenceFrames and P.referenceFrames[index]
        if frame then
            frame:SetAlpha(0.72)
            M:Hit(frame, cfg)
            Add(frame, cfg, EntryIdentity(cfg))
        end
    end
    for _, bucket in pairs(buckets) do if #bucket.items > 0 then Place(bucket.items, bucket.group) end end
end

function M:Soon()
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function() M:RefreshLayout() end)
        C_Timer.After(0.05, function() M:RefreshLayout() end)
    else self:RefreshLayout() end
end

function M:SyncWidgets()
    local s = State()
    local w = self.editor and self.editor.frame and self.editor.frame.widgets
    if w and w.imageX then w.imageX:SetText(tostring(Round(s.imageX, 0))) end
    if w and w.imageY then w.imageY:SetText(tostring(Round(s.imageY, 120))) end
end

function M:Target(cfg)
    if type(cfg) ~= "table" then return end
    local s = State()
    if self.action == "copy" then
        local size = math.max(16, Round(cfg.imageSize, 96))
        s.imageSize = size
        local w = self.editor and self.editor.frame and self.editor.frame.widgets
        if w and w.imageSize and w.imageSize.SetValue then w.imageSize:SetValue(size) end
        self.action = nil
        self:SetStatus(L.copy .. ": " .. tostring(size))
        if P.Refresh then P:Refresh(self.editor) end
        self:Soon()
        return
    end
    if self.action ~= "join" then return end
    local selected, target = SelectedIdentity(), EntryIdentity(cfg)
    if SelectedKey() == "" or selected == "" then self:SetStatus(L.saved); return end
    if target == "" or target == selected then self:SetStatus(L.invalid); return end
    if G:JoinAfter(selected, target, self:Direction(), cfg.imageX, cfg.imageY) then
        local group = G:GetGroupForEntry(selected)
        if group then s.imageX, s.imageY = group.x or 0, group.y or 120 end
        self:SyncWidgets()
        self.action = nil
        self:SetStatus(L.joined)
        self:Soon()
    else self:SetStatus(L.invalid) end
end

function M:Move(delta)
    if not G or not G:MoveMember(SelectedIdentity(), delta) then self:SetStatus(L.noGroup); return end
    self:Soon()
end

function M:Ungroup()
    local key = SelectedIdentity()
    local group = G and G:GetGroupForEntry(key)
    if not group then self:SetStatus(L.noGroup); return end
    local s = State()
    if P.frame and P.frame.GetCenter and UIParent.GetCenter then
        local x, y = P.frame:GetCenter(); local px, py = UIParent:GetCenter()
        s.imageX, s.imageY = Round((x or px) - px, s.imageX), Round((y or py) - py, s.imageY)
    end
    G:RemoveMember(key, false)
    self:SyncWidgets()
    self:SetStatus(L.ungrouped)
    if P.Refresh then P:Refresh(self.editor) end
    self:Soon()
end

function M:HookPreview(frame)
    if not frame or frame.qfxsaVGHooked then return end
    frame.qfxsaVGHooked = true
    local function Capture(_, button)
        if button and button ~= "LeftButton" then return end
        local group, member = G and G:GetGroupForEntry(SelectedIdentity())
        if not group or not member then self.drag = nil; return end
        local x, y = frame:GetCenter()
        self.drag = { x = x or 0, y = y or 0, gx = group.x or 0, gy = group.y or 120, id = member.groupID }
    end
    frame:HookScript("OnMouseDown", Capture)
    frame:HookScript("OnDragStart", Capture)
end

function M:Dragged()
    local d = self.drag; self.drag = nil
    if not d or not G or not P.frame then return end
    local x, y = P.frame:GetCenter()
    G:SetGroupPosition(d.id, d.gx + (x - d.x), d.gy + (y - d.y))
    local group = G:GetGroup(d.id); local s = State()
    if group then s.imageX, s.imageY = group.x, group.y end
    self:SyncWidgets(); self:Soon()
end

function M:SyncFromGroup()
    local group = G and G:GetGroupForEntry(SelectedIdentity())
    if not group then return false end
    local s = State()
    s.imageX, s.imageY = group.x or 0, group.y or 120
    self.direction = group.direction or "RIGHT"
    self:SyncWidgets(); self:UpdateDirectionButtons()
    return true
end

function M:SyncToGroup()
    if self.opening or not G then return end
    local group, member = G:GetGroupForEntry(SelectedIdentity())
    if not group or not member then return end
    local s = State(); local x, y = Round(s.imageX, group.x), Round(s.imageY, group.y)
    if x ~= Round(group.x, 0) or y ~= Round(group.y, 120) then G:SetGroupPosition(member.groupID, x, y) end
end

function M:Enter(editor)
    self.editor = editor or self.editor or NS.UI.EditorFrame
    if State().imageEnabled ~= true then return end
    self.active, self.action = true, nil
    self:EnsurePanel(self.editor):Show()
    self:SetStatus(L.idle); self:SyncFromGroup()
    if P.Show then P:Show(self.editor) end
    if P.frame then self:HookPreview(P.frame) end
    self:Soon()
end

function M:Exit()
    self.active, self.action, self.drag = false, nil, nil
    if self.panel then self.panel:Hide() end
    if type(P.referenceFrames) == "table" then
        for _, frame in ipairs(P.referenceFrames) do
            if frame then
                frame:SetAlpha(0.45)
                if frame.qfxsaVGHit then frame.qfxsaVGHit:Hide() end
                if frame.qfxsaVGBadge then frame.qfxsaVGBadge:Hide() end
            end
        end
    end
    if P.frame and P.frame.qfxsaVGBadge then P.frame.qfxsaVGBadge:Hide() end
end

local B = NS.UI.EditorFrameBuilder
if B and B.EnsureFrame and not B.qfxsaVGWrapped then
    B.qfxsaVGWrapped = true
    local old = B.EnsureFrame
    B.EnsureFrame = function(self, owner)
        local frame = old(self, owner); M:Augment(owner, frame); return frame
    end
end

if P.Ensure and not P.qfxsaVGEnsure then
    P.qfxsaVGEnsure = true; local old = P.Ensure
    P.Ensure = function(self, ...) local frame = old(self, ...); M:HookPreview(frame); return frame end
end
if P.ShowReferencePreviews and not P.qfxsaVGRefs then
    P.qfxsaVGRefs = true; local old = P.ShowReferencePreviews
    P.ShowReferencePreviews = function(self, ...) local r = old(self, ...); if M.active then M:Soon() end; return r end
end
if P.Show and not P.qfxsaVGShow then
    P.qfxsaVGShow = true; local old = P.Show
    P.Show = function(self, ...) local r = old(self, ...); if not M.opening then M:SyncToGroup() end; if M.active then M:Soon() end; return r end
end
if P.Refresh and not P.qfxsaVGRefresh then
    P.qfxsaVGRefresh = true; local old = P.Refresh
    P.Refresh = function(self, ...) local r = old(self, ...); if not M.opening then M:SyncToGroup() end; if M.active then M:Soon() end; return r end
end
if P.SavePositionFromFrame and not P.qfxsaVGSave then
    P.qfxsaVGSave = true; local old = P.SavePositionFromFrame
    P.SavePositionFromFrame = function(self, ...) local r = old(self, ...); M:Dragged(); return r end
end

local E = NS.UI.EditorFrame

if E and E.OpenForNew and not E.qfxsaVGNew then
    E.qfxsaVGNew = true; local old = E.OpenForNew
    E.OpenForNew = function(self, ...)
        State().visualUID = nil
        return old(self, ...)
    end
end
if E and E.OpenForEdit and not E.qfxsaVGOpen then
    E.qfxsaVGOpen = true; local old = E.OpenForEdit
    E.OpenForEdit = function(self, ...)
        M.opening = true; local r = old(self, ...); M.opening = false; M.editor = self
        if M:SyncFromGroup() then self:Refresh(); if P.Refresh then P:Refresh(self) end end
        return r
    end
end
if E and E.Close and not E.qfxsaVGClose then
    E.qfxsaVGClose = true; local old = E.Close
    E.Close = function(self, ...) M:Exit(); return old(self, ...) end
end
