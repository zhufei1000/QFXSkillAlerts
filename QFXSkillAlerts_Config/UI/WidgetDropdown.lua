local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.UI = NS.UI or {}
NS.UI.Widgets = NS.UI.Widgets or {}

local Widgets = NS.UI.Widgets
local Skin = NS.UI.Skin
local DropdownPopup = NS.UI.WidgetDropdownPopup
local WidgetUtils = NS.UI.WidgetUtils or {}
local MakeSingleLine = WidgetUtils.MakeSingleLine
local SafeCreateFrame = WidgetUtils.SafeCreateFrame
local CloseDropDownMenus = rawget(_G, "CloseDropDownMenus")

local DROPDOWN_TEXT_LEFT_INSET = 8
local DROPDOWN_TEXT_RIGHT_INSET = 30
local DROPDOWN_CONTROL_HEIGHT = 30

local function StyleDropDownClosedControl(dropdown)
    if not dropdown then
        return
    end
    -- Native-friendly closed control: one clipped text area + one native scroll
    -- button.  The popup itself lives in WidgetDropdownPopup.lua so the closed
    -- control can stay small and easy to maintain.
    if dropdown.SetBackdrop then
        dropdown:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        dropdown:SetBackdropColor(0, 0, 0, 0.82)
        dropdown:SetBackdropBorderColor(0.48, 0.48, 0.48, 0.95)
    end
end

local function EnsureDropDownTextOverlay(dropdown)
    if not dropdown then
        return nil
    end
    if dropdown.qfxsaTextOverlay then
        return dropdown.qfxsaTextOverlay
    end

    local mask = CreateFrame("Frame", nil, dropdown)
    mask:SetPoint("TOPLEFT", dropdown, "TOPLEFT", DROPDOWN_TEXT_LEFT_INSET, -3)
    mask:SetPoint("BOTTOMRIGHT", dropdown, "BOTTOMRIGHT", -DROPDOWN_TEXT_RIGHT_INSET, 3)
    mask:SetFrameLevel((dropdown.GetFrameLevel and dropdown:GetFrameLevel() or 1) + 5)
    if mask.SetClipsChildren then
        mask:SetClipsChildren(true)
    end

    local text = mask:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("LEFT", mask, "LEFT", 0, 0)
    text:SetPoint("RIGHT", mask, "RIGHT", 0, 0)
    text:SetHeight(DROPDOWN_CONTROL_HEIGHT - 8)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("MIDDLE")
    if MakeSingleLine then
        MakeSingleLine(text, math.max(1, (tonumber(dropdown.qfxsaOuterWidth) or 180) - DROPDOWN_TEXT_LEFT_INSET - DROPDOWN_TEXT_RIGHT_INSET))
    end
    if Skin and Skin.StyleFont then
        Skin:StyleFont(text, "body")
    end

    dropdown.qfxsaTextMask = mask
    dropdown.qfxsaTextOverlay = text
    return text
end

local function SetDropDownVisualText(dropdown, text)
    text = tostring(text or "")
    local visualText = EnsureDropDownTextOverlay(dropdown)
    if visualText and visualText.SetText then
        if MakeSingleLine then
            MakeSingleLine(visualText, math.max(1, (tonumber(dropdown.qfxsaOuterWidth) or 180) - DROPDOWN_TEXT_LEFT_INSET - DROPDOWN_TEXT_RIGHT_INSET))
        end
        visualText:SetText(text)
    elseif dropdown.SetText then
        dropdown:SetText(text)
    end
end

local function HideDropdownPopup(dropdown)
    if DropdownPopup and DropdownPopup.HideForOwner then
        DropdownPopup:HideForOwner(dropdown)
        return
    end
    local popup = Widgets._nativeDropdownPopup
    if popup and (not dropdown or popup.owner == dropdown) then
        popup:Hide()
    end
end

local function EnsureDropdownSearchBox(dropdown)
    if not dropdown or dropdown.qfxsaSearchBox then
        return dropdown and dropdown.qfxsaSearchBox or nil
    end
    EnsureDropDownTextOverlay(dropdown)
    local mask = dropdown.qfxsaTextMask
    if not mask then
        return nil
    end

    local searchBox = CreateFrame("EditBox", nil, mask)
    searchBox:SetAllPoints(mask)
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(80)
    searchBox:SetFontObject("GameFontHighlightSmall")
    searchBox:SetJustifyH("LEFT")
    searchBox:SetTextInsets(0, 0, 0, 0)
    searchBox:SetFrameLevel((mask.GetFrameLevel and mask:GetFrameLevel() or 1) + 2)
    searchBox:EnableMouse(true)
    searchBox:Hide()

    local placeholder = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    placeholder:SetPoint("LEFT", searchBox, "LEFT", 0, 0)
    placeholder:SetPoint("RIGHT", searchBox, "RIGHT", 0, 0)
    placeholder:SetJustifyH("LEFT")
    placeholder:SetWordWrap(false)
    searchBox.qfxsaPlaceholder = placeholder

    local function RefreshPlaceholder(self)
        local text = tostring(self:GetText() or "")
        placeholder:SetText(tostring(dropdown.qfxsaSearchPlaceholder or ""))
        placeholder:SetShown(text == "")
    end

    searchBox:SetScript("OnTextChanged", function(self)
        dropdown.qfxsaSearchText = tostring(self:GetText() or "")
        RefreshPlaceholder(self)
        if DropdownPopup and type(DropdownPopup.UpdateSearch) == "function" then
            DropdownPopup:UpdateSearch(dropdown, dropdown.qfxsaSearchText)
        end
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        HideDropdownPopup(dropdown)
    end)
    searchBox:SetScript("OnEnterPressed", function(self)
        if DropdownPopup and type(DropdownPopup.SelectSingleFilteredItem) == "function"
            and DropdownPopup:SelectSingleFilteredItem(dropdown) then
            self:ClearFocus()
        end
    end)

    dropdown.qfxsaSearchBox = searchBox
    dropdown.qfxsaBeginSearch = function(self)
        if not self.qfxsaSearchable or not self.qfxsaSearchBox then
            return
        end
        self.qfxsaSearchText = ""
        if self.qfxsaTextOverlay then
            self.qfxsaTextOverlay:Hide()
        end
        self.qfxsaSearchBox:Show()
        self.qfxsaSearchBox:SetText("")
        RefreshPlaceholder(self.qfxsaSearchBox)
        self.qfxsaSearchBox:SetFocus()
    end
    dropdown.qfxsaEndSearch = function(self)
        self.qfxsaSearchText = ""
        if self.qfxsaSearchBox then
            self.qfxsaSearchBox:SetText("")
            self.qfxsaSearchBox:ClearFocus()
            self.qfxsaSearchBox:Hide()
        end
        if self.qfxsaTextOverlay then
            self.qfxsaTextOverlay:Show()
        end
        SetDropDownVisualText(self, self.qfxsaText or "")
    end
    return searchBox
end

function Widgets:CreateDropdown(parent, name, width)
    width = width or 180
    local dropdown = SafeCreateFrame("Button", name, parent, { "BackdropTemplate" })
    dropdown:SetSize(width, DROPDOWN_CONTROL_HEIGHT)
    dropdown.qfxsaItems = {}
    dropdown.qfxsaValue = nil
    dropdown.qfxsaText = ""
    dropdown.qfxsaDisabled = false
    dropdown.qfxsaOuterWidth = width
    dropdown.qfxsaUnifiedPopup = true
    dropdown.qfxsaSetVisualText = SetDropDownVisualText
    dropdown:RegisterForClicks("LeftButtonUp")
    dropdown:EnableMouse(true)
    StyleDropDownClosedControl(dropdown)

    local highlight = dropdown:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetPoint("TOPLEFT", dropdown, "TOPLEFT", 3, -3)
    highlight:SetPoint("BOTTOMRIGHT", dropdown, "BOTTOMRIGHT", -3, 3)
    highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    highlight:SetBlendMode("ADD")
    dropdown:SetHighlightTexture(highlight)

    local arrow = SafeCreateFrame("Button", nil, dropdown, {
        "UIPanelScrollDownButtonTemplate",
        "UIPanelButtonTemplate",
    })
    arrow:SetSize(22, 22)
    arrow:SetPoint("RIGHT", dropdown, "RIGHT", -2, 0)
    arrow:SetFrameLevel((dropdown.GetFrameLevel and dropdown:GetFrameLevel() or 1) + 8)
    arrow:RegisterForClicks("LeftButtonUp")
    arrow:SetScript("OnClick", function()
        if dropdown:GetScript("OnClick") then
            dropdown:GetScript("OnClick")(dropdown, "LeftButton")
        end
    end)
    dropdown.qfxsaArrow = arrow

    SetDropDownVisualText(dropdown, "")

    dropdown:SetScript("OnClick", function(self)
        if self.qfxsaDisabled then
            return
        end
        if CloseDropDownMenus then
            CloseDropDownMenus()
        end
        if DropdownPopup and DropdownPopup.Show then
            DropdownPopup:Show(self)
        end
    end)

    dropdown:HookScript("OnHide", function(self)
        HideDropdownPopup(self)
    end)

    if Skin and Skin.SkinDropDown then
        Skin:SkinDropDown(dropdown)
    end
    return dropdown
end

function Widgets:SetDropdownItems(dropdown, items)
    if not dropdown then
        return
    end
    items = items or {}
    if dropdown.qfxsaItems == items then
        return
    end
    dropdown.qfxsaItems = items
    if dropdown.qfxsaMultiSelect and self.SetMultiDropdownValues then
        self:SetMultiDropdownValues(dropdown, dropdown.qfxsaSelectedValues or {}, dropdown.qfxsaFallbackText)
    end
    HideDropdownPopup(dropdown)
    if CloseDropDownMenus then
        CloseDropDownMenus()
    end
end

function Widgets:SetDropdownSearchable(dropdown, enabled, placeholder)
    if not dropdown then
        return
    end
    dropdown.qfxsaSearchable = enabled == true
    dropdown.qfxsaSearchPlaceholder = tostring(placeholder or "")
    if dropdown.qfxsaSearchable then
        local searchBox = EnsureDropdownSearchBox(dropdown)
        if searchBox and searchBox.qfxsaPlaceholder then
            searchBox.qfxsaPlaceholder:SetText(dropdown.qfxsaSearchPlaceholder)
        end
    elseif dropdown.qfxsaEndSearch then
        dropdown:qfxsaEndSearch()
    end
end

function Widgets:SetDropdownValue(dropdown, value, fallbackText)
    if not dropdown then
        return
    end
    dropdown.qfxsaValue = value
    local text = fallbackText or ""
    for _, item in ipairs(dropdown.qfxsaItems or {}) do
        if item.value == value then
            text = tostring(item.text or "")
            break
        end
    end
    dropdown.qfxsaText = text
    SetDropDownVisualText(dropdown, text)
end

function Widgets:GetDropdownValue(dropdown)
    return dropdown and dropdown.qfxsaValue or nil
end

function Widgets:CreateMultiSelectDropdown(parent, name, width)
    local dropdown = self:CreateDropdown(parent, name, width)
    dropdown.qfxsaMultiSelect = true
    dropdown.qfxsaSelectedValues = {}
    dropdown.qfxsaFallbackText = ""
    dropdown.qfxsaValue = dropdown.qfxsaSelectedValues
    return dropdown
end

function Widgets:SetMultiDropdownValues(dropdown, values, fallbackText)
    if not dropdown then
        return
    end
    dropdown.qfxsaSelectedValues = {}
    if type(values) == "table" then
        for key, value in pairs(values) do
            if value == true then
                dropdown.qfxsaSelectedValues[key] = true
            end
        end
    end
    dropdown.qfxsaFallbackText = tostring(fallbackText or dropdown.qfxsaFallbackText or "")
    dropdown.qfxsaValue = dropdown.qfxsaSelectedValues
    local parts = {}
    for _, item in ipairs(dropdown.qfxsaItems or {}) do
        if dropdown.qfxsaSelectedValues[item.value] == true then
            parts[#parts + 1] = tostring(item.text or item.value or "")
        end
    end
    local text = #parts > 0 and table.concat(parts, ", ") or dropdown.qfxsaFallbackText
    dropdown.qfxsaText = text
    SetDropDownVisualText(dropdown, text)
end

function Widgets:GetMultiDropdownValues(dropdown)
    local copy = {}
    if dropdown and type(dropdown.qfxsaSelectedValues) == "table" then
        for key, value in pairs(dropdown.qfxsaSelectedValues) do
            if value == true then
                copy[key] = true
            end
        end
    end
    return copy
end

function Widgets:SetDropdownEnabled(dropdown, enabled)
    if not dropdown then
        return
    end
    dropdown.qfxsaDisabled = not enabled
    if enabled then
        if dropdown.Enable then
            dropdown:Enable()
        end
        if dropdown.qfxsaArrow and dropdown.qfxsaArrow.Enable then
            dropdown.qfxsaArrow:Enable()
        end
        dropdown:EnableMouse(true)
        dropdown:SetAlpha(1)
    else
        HideDropdownPopup(dropdown)
        if CloseDropDownMenus then
            CloseDropDownMenus()
        end
        if dropdown.Disable then
            dropdown:Disable()
        end
        if dropdown.qfxsaArrow and dropdown.qfxsaArrow.Disable then
            dropdown.qfxsaArrow:Disable()
        end
        dropdown:SetAlpha(0.55)
    end
end
