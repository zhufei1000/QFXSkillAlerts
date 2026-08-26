local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.UI = NS.UI or {}
NS.UI.VisualPositionPreview = NS.UI.VisualPositionPreview or {}

local Preview = NS.UI.VisualPositionPreview
local L = NS.L or function(key) return tostring(key) end

local function Trim(value)
    local utils = NS.Utils or {}
    if utils.TrimText then
        return utils.TrimText(value)
    end
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function Round(value)
    value = tonumber(value) or 0
    if value >= 0 then
        return math.floor(value + 0.5)
    end
    return math.ceil(value - 0.5)
end

local LEGACY_DEFAULT_X = 0
local LEGACY_DEFAULT_Y = 120
local EDITOR_OUTER_GAP = 14

local function IsLegacyDefaultPosition(x, y)
    return Round(x or LEGACY_DEFAULT_X) == LEGACY_DEFAULT_X and Round(y or LEGACY_DEFAULT_Y) == LEGACY_DEFAULT_Y
end

local function GetParentMetrics(parent)
    parent = parent or UIParent
    if not parent then return 0, 0, 0, 0 end
    local width = (parent.GetWidth and parent:GetWidth()) or 0
    local height = (parent.GetHeight and parent:GetHeight()) or 0
    local cx, cy = parent:GetCenter()
    return width, height, cx or (width / 2), cy or (height / 2)
end

function Preview:GetCompactFrameSize(state, forceKind)
    state = state or {}
    local imageEnabled = forceKind == "image" or state.imageEnabled == true
    local textEnabled = forceKind == "text" or state.textEnabled == true
    local imageSize = math.max(16, tonumber(state.imageSize) or 96)
    if imageEnabled then
        local textOutside = textEnabled and tostring(state.textAttachMode or "outside") ~= "inside"
        local width = math.max(imageSize + 48, textEnabled and 360 or (imageSize + 48))
        local height = math.max(imageSize + 40, 96)
        if textOutside then height = height + math.max(28, math.floor((tonumber(state.textSize) or 24) * 1.5)) end
        return width, height
    end
    return 360, math.max(80, math.floor((tonumber(state.textSize) or 24) * 2.2))
end

function Preview:GetEditorOuterDefaultPosition(editor, state, forceKind)
    local parent = UIParent
    local parentW, parentH, pcx, pcy = GetParentMetrics(parent)
    local width, height = self:GetCompactFrameSize(state, forceKind)
    local editorFrame = editor and editor.frame
    if not editorFrame or not editorFrame.GetLeft or not editorFrame:GetLeft() then
        -- Fallback: upper-left quarter of the screen, away from the center editor area.
        return Round(-math.max(260, parentW * 0.28)), Round(math.max(180, parentH * 0.24))
    end

    local left = editorFrame:GetLeft() or 0
    local top = editorFrame:GetTop() or parentH
    local right = editorFrame:GetRight() or (left + ((editorFrame.GetWidth and editorFrame:GetWidth()) or 0))
    local frameLeft, frameTop

    -- Preferred: outside the editor's upper-left side, so the preview will not cover settings.
    if left - EDITOR_OUTER_GAP - width >= 8 then
        frameLeft = left - EDITOR_OUTER_GAP - width
        frameTop = top
    -- If there is not enough room on the left, place it above the editor and align to the left edge.
    elseif top + EDITOR_OUTER_GAP + height <= parentH - 8 then
        frameLeft = math.max(8, left)
        frameTop = top + EDITOR_OUTER_GAP + height
    -- Last fallback: use the editor's top-left inside the screen, still away from most controls.
    else
        frameLeft = math.max(8, math.min(left, parentW - width - 8))
        frameTop = math.max(height + 8, math.min(top, parentH - 8))
    end

    frameLeft = math.max(8, math.min(frameLeft, math.max(8, parentW - width - 8)))
    frameTop = math.max(height + 8, math.min(frameTop, parentH - 8))
    local x = (frameLeft + (width / 2)) - pcx
    local y = (frameTop - (height / 2)) - pcy
    return Round(x), Round(y)
end

function Preview:ApplyEditorDefaultPositions(editor, state)
    state = state or {}
    -- Move only entries that are still on the old built-in center-ish default.
    -- Custom dragged/saved positions are left untouched.
    if IsLegacyDefaultPosition(state.imageX, state.imageY) then
        local x, y = self:GetEditorOuterDefaultPosition(editor, state, "image")
        state.imageX, state.imageY = x, y
    end
    if IsLegacyDefaultPosition(state.textX, state.textY) then
        local x, y = self:GetEditorOuterDefaultPosition(editor, state, "text")
        state.textX, state.textY = x, y
    end
end

function Preview:ResetEditorPosition(editor, kind)
    local state = NS.AceOptions and NS.AceOptions.GetState and NS.AceOptions:GetState() or {}
    local x, y = self:GetEditorOuterDefaultPosition(editor or self.editor, state, kind)
    local widgets = editor and editor.frame and editor.frame.widgets or (self.editor and self.editor.frame and self.editor.frame.widgets)
    if kind == "text" then
        state.textX, state.textY = x, y
        if widgets then
            if widgets.textX then widgets.textX:SetText(tostring(x)) end
            if widgets.textY then widgets.textY:SetText(tostring(y)) end
        end
    else
        state.imageX, state.imageY = x, y
        if widgets then
            if widgets.imageX then widgets.imageX:SetText(tostring(x)) end
            if widgets.imageY then widgets.imageY:SetText(tostring(y)) end
        end
    end
    if self.frame and self.frame:IsShown() then
        self:Layout(self.frame, state)
    end
end

local function ResolveSpellIcon(spellId)
    spellId = tonumber(spellId) or 0
    if spellId <= 0 then
        return nil
    end
    local api = NS.API or {}
    if type(api.ResolveSpellIcon) == "function" then
        local ok, texture = pcall(api.ResolveSpellIcon, spellId)
        if ok and texture then return texture end
    end
    if C_Spell and type(C_Spell.GetSpellTexture) == "function" then
        local ok, texture = pcall(C_Spell.GetSpellTexture, spellId)
        if ok and texture then return texture end
    end
    if type(GetSpellTexture) == "function" then
        local ok, texture = pcall(GetSpellTexture, spellId)
        if ok and texture then return texture end
    end
    return nil
end

local function ResolveItemIcon(itemID)
    itemID = tonumber(itemID) or 0
    if itemID <= 0 then return nil end
    local api = NS.API or {}
    if type(api.ResolveItemIcon) == "function" then
        local ok, texture = pcall(api.ResolveItemIcon, itemID)
        if ok and texture then return texture end
    end
    if C_Item and type(C_Item.GetItemIconByID) == "function" then
        local ok, texture = pcall(C_Item.GetItemIconByID, itemID)
        if ok and texture then return texture end
    end
    if type(GetItemIcon) == "function" then
        local ok, texture = pcall(GetItemIcon, itemID)
        if ok and texture then return texture end
    end
    return nil
end

local function ResolveImageTexture(state)
    local source = tostring(state.imageSource or "auto")
    if source == "spell" then
        return ResolveSpellIcon(state.imageIconID) or 134400
    elseif source == "item" then
        return ResolveItemIcon(state.imageIconID) or 134400
    elseif source == "icon" then
        local iconID = tonumber(state.imageIconID) or 0
        return iconID > 0 and math.floor(iconID) or 134400
    elseif source == "path" then
        local value = Trim(state.imagePath or "")
        return value ~= "" and (tonumber(value) or value) or 134400
    end
    return ResolveSpellIcon(state.spellId)
        or ((tonumber(state.imageIconID) or 0) > 0 and math.floor(tonumber(state.imageIconID) or 0) or nil)
        or (Trim(state.imagePath or "") ~= "" and (tonumber(Trim(state.imagePath or "")) or Trim(state.imagePath or "")) or nil)
        or 134400
end

function Preview:Ensure()
    if self.frame then
        return self.frame
    end
    local parent = UIParent
    if not parent then return nil end
    local frame = CreateFrame("Frame", "QFXSkillAlertsEditorVisualPositionPreview", parent)
    frame:SetSize(360, 120)
    frame:SetPoint("CENTER", parent, "CENTER", -360, 220)
    frame:SetFrameStrata("TOOLTIP")
    frame:SetFrameLevel(1000)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame:Hide()

    local image = frame:CreateTexture(nil, "OVERLAY")
    image:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    image:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.image = image

    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    text:SetWidth(520)
    frame.text = text

    local coord = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    coord:SetPoint("BOTTOM", frame, "TOP", 0, 4)
    coord:SetJustifyH("CENTER")
    frame.coord = coord

    local function StopMovingAndSave()
        frame:StopMovingOrSizing()
        self:SavePositionFromFrame()
    end
    frame:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    frame:SetScript("OnDragStop", StopMovingAndSave)
    frame:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then frame:StartMoving() end
    end)
    frame:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" then StopMovingAndSave() end
    end)

    self.frame = frame
    return frame
end

function Preview:SetEditor(editor)
    self.editor = editor
end

function Preview:Pull(editor)
    editor = editor or self.editor
    if editor and type(editor.PullFromWidgets) == "function" then
        editor:PullFromWidgets()
    end
end

function Preview:SavePositionFromFrame()
    local frame = self.frame
    local editor = self.editor
    if not frame or not editor or not editor.frame or not editor.frame.widgets then return end
    local parent = UIParent
    if not parent then return end
    local cx, cy = frame:GetCenter()
    local pcx, pcy = parent:GetCenter()
    local x = Round((cx or pcx) - (pcx or 0))
    local y = Round((cy or pcy) - (pcy or 0))
    local state = NS.AceOptions and NS.AceOptions.GetState and NS.AceOptions:GetState() or {}
    local widgets = editor.frame.widgets or {}
    if state.imageEnabled == true then
        state.imageX = x
        state.imageY = y
        if widgets.imageX then widgets.imageX:SetText(tostring(x)) end
        if widgets.imageY then widgets.imageY:SetText(tostring(y)) end
    else
        state.textX = x
        state.textY = y
        if widgets.textX then widgets.textX:SetText(tostring(x)) end
        if widgets.textY then widgets.textY:SetText(tostring(y)) end
    end
    if frame.coord then frame.coord:SetText("X: " .. tostring(x) .. "  Y: " .. tostring(y)) end
end

local function SetTextFont(fontString, size)
    if fontString and fontString.SetFont then
        local font, _, flags = fontString:GetFont()
        fontString:SetFont(font or "Fonts\\FRIZQT__.TTF", math.max(8, tonumber(size) or 24), flags or "OUTLINE")
    end
end

function Preview:Layout(frame, state)
    local imageEnabled = state.imageEnabled == true
    local textEnabled = state.textEnabled == true
    local imageSize = math.max(16, tonumber(state.imageSize) or 96)
    frame.image:ClearAllPoints()
    frame.text:ClearAllPoints()
    frame.image:SetSize(imageSize, imageSize)
    frame.image:SetTexture(ResolveImageTexture(state))
    if imageEnabled then frame.image:Show() else frame.image:Hide() end

    local text = Trim(state.textAlert or "")
    if text == "" then text = Trim(state.spellName or "") end
    if text == "" then text = L("TAB_TEXT") end
    SetTextFont(frame.text, state.textSize)
    frame.text:SetText(text)
    if textEnabled then frame.text:Show() else frame.text:Hide() end

    if imageEnabled then
        local frameW, frameH = self:GetCompactFrameSize(state, "image")
        frame:SetSize(frameW, frameH)
        if frame.text and frame.text.SetWidth then frame.text:SetWidth(math.max(120, frameW - 20)) end
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", Round(state.imageX or 0), Round(state.imageY or 120))
        frame.image:SetPoint("CENTER", frame, "CENTER", 0, 0)
        if textEnabled then
            local attach = tostring(state.textAttachMode or "outside")
            if attach ~= "inside" then attach = "outside" end
            local v = tostring(state.textVAlign or "bottom")
            if v ~= "top" and v ~= "middle" then v = "bottom" end
            local h = tostring(state.textHAlign or "center")
            if h ~= "left" and h ~= "right" then h = "center" end
            local ox = Round(state.textOffsetX or 0)
            local oy = Round(state.textOffsetY or 0)
            local x = ox
            if h == "left" then x = x - math.floor(imageSize / 2) elseif h == "right" then x = x + math.floor(imageSize / 2) end
            if attach == "inside" then
                local y = oy
                if v == "top" then y = y + math.floor(imageSize / 2) - 12 elseif v == "bottom" then y = y - math.floor(imageSize / 2) + 12 end
                frame.text:SetPoint("CENTER", frame.image, "CENTER", x, y)
            else
                if v == "top" then
                    frame.text:SetPoint("BOTTOM", frame.image, "TOP", x, 6 + oy)
                elseif v == "middle" then
                    frame.text:SetPoint("CENTER", frame.image, "CENTER", x, oy)
                else
                    frame.text:SetPoint("TOP", frame.image, "BOTTOM", x, -6 + oy)
                end
            end
        end
    else
        local frameW, frameH = self:GetCompactFrameSize(state, "text")
        frame:SetSize(frameW, frameH)
        if frame.text and frame.text.SetWidth then frame.text:SetWidth(math.max(120, frameW - 20)) end
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", Round(state.textX or 0), Round(state.textY or 120))
        frame.text:SetPoint("CENTER", frame, "CENTER", 0, 0)
    end
    local x = imageEnabled and Round(state.imageX or 0) or Round(state.textX or 0)
    local y = imageEnabled and Round(state.imageY or 120) or Round(state.textY or 120)
    if frame.qfxsaReference == true then
        local label = Trim(state.spellName or state.textAlert or state.previewSource or "")
        if label == "" then label = L("TAB_TEXT") end
        frame.coord:SetText(label .. "  X: " .. tostring(x) .. "  Y: " .. tostring(y))
    else
        frame.coord:SetText("X: " .. tostring(x) .. "  Y: " .. tostring(y))
    end
end

local function CreateReferenceFrame(index)
    local parent = UIParent
    if not parent then return nil end
    local frame = CreateFrame("Frame", "QFXSkillAlertsEditorVisualReference" .. tostring(index), parent)
    frame:SetSize(360, 120)
    frame:SetPoint("CENTER", parent, "CENTER", -360, 220)
    frame:SetFrameStrata("TOOLTIP")
    frame:SetFrameLevel(850 + (tonumber(index) or 0))
    frame:EnableMouse(false)
    frame:SetAlpha(0.45)
    frame.qfxsaReference = true
    frame:Hide()

    local image = frame:CreateTexture(nil, "OVERLAY")
    image:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    image:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.image = image

    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    text:SetWidth(520)
    frame.text = text

    local coord = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    coord:SetPoint("BOTTOM", frame, "TOP", 0, 4)
    coord:SetJustifyH("CENTER")
    frame.coord = coord
    return frame
end

function Preview:HideReferencePreviews()
    if type(self.referenceFrames) ~= "table" then
        return
    end
    for _, frame in ipairs(self.referenceFrames) do
        if frame then frame:Hide() end
    end
end

function Preview:GetLoadedReferenceConfigs()
    local getter = NS.GetLoadedVisualPreviewConfigs
    if type(getter) ~= "function" then
        return {}
    end
    local ok, configs = pcall(getter, NS)
    if not ok or type(configs) ~= "table" then
        return {}
    end

    local state = NS.AceOptions and NS.AceOptions.GetState and NS.AceOptions:GetState() or {}
    local selectedKey = tostring(state.selectedKey or "")
    local entryType = tostring(state.entryType or "")
    local results = {}
    for _, cfg in ipairs(configs) do
        if type(cfg) == "table" and (cfg.imageEnabled == true or cfg.textEnabled == true) then
            local sameSelectedEntry = selectedKey ~= "" and tostring(cfg.entryKey or "") == selectedKey
            local sameBloodlust = entryType == "bloodlust" and tostring(cfg.previewSource or "") == "bloodlust"
            if not sameSelectedEntry and not sameBloodlust then
                results[#results + 1] = cfg
                if #results >= 40 then
                    break
                end
            end
        end
    end
    return results
end

function Preview:ShowReferencePreviews(editor)
    self:SetEditor(editor or self.editor)
    self:HideReferencePreviews()
    local configs = self:GetLoadedReferenceConfigs()
    if #configs <= 0 then
        return
    end
    self.referenceFrames = self.referenceFrames or {}
    for index, cfg in ipairs(configs) do
        local frame = self.referenceFrames[index]
        if not frame then
            frame = CreateReferenceFrame(index)
            self.referenceFrames[index] = frame
        end
        if frame then
            self:Layout(frame, cfg)
            frame:Show()
        end
    end
end

function Preview:Show(editor)
    self:SetEditor(editor)
    self:Pull(editor)
    local state = NS.AceOptions and NS.AceOptions.GetState and NS.AceOptions:GetState() or {}
    if state.imageEnabled ~= true and state.textEnabled ~= true then return end
    local frame = self:Ensure()
    if not frame then return end
    self:Layout(frame, state)
    frame:Show()
    self:ShowReferencePreviews(editor)
end

function Preview:Refresh(editor)
    if not self.frame or not self.frame:IsShown() then return end
    self:SetEditor(editor or self.editor)
    self:Pull(self.editor)
    local state = NS.AceOptions and NS.AceOptions.GetState and NS.AceOptions:GetState() or {}
    self:Layout(self.frame, state)
    self:ShowReferencePreviews(self.editor)
end

function Preview:Hide()
    if self.frame then self.frame:Hide() end
    self:HideReferencePreviews()
end
