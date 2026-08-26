-- Regression test for WidgetDropdownPopup scroll positioning.
-- Guards against the first-open bug where a searchable dropdown opened at the
-- top of the list instead of the selected item: the initial search-box
-- SetText fires OnTextChanged (first SetText on a fresh box), and UpdateSearch
-- used to re-layout back to the top AFTER the popup was already scrolled to
-- the selection.  UpdateSearch now preserves the scroll for an empty search,
-- and Popup:Show jumps to the selected item as its final step.

local function Fail(message)
    error(message, 2)
end

local function Assert(condition, message)
    if not condition then
        Fail(message or "assertion failed")
    end
end

local DROPDOWN_MAX_VISIBLE_ROWS = 10

local function Clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

-- Stub frames mimicking WoW semantics:
--   * Slider:SetValue fires OnValueChanged only when the value changes
--   * EditBox:SetText fires OnTextChanged on the FIRST SetText ever (even for
--     an empty string) and on any actual text change afterwards
local function NewFrame(kind)
    return {
        kind = kind,
        shown = false,
        text = "",
        textEverSet = false,
        value = 0,
        min = 0,
        max = 0,
        scripts = {},
        SetScript = function(self, name, fn) self.scripts[name] = fn end,
        GetScript = function(self, name) return self.scripts[name] end,
        Show = function(self) self.shown = true end,
        Hide = function(self) self.shown = false end,
        SetText = function(self, text)
            text = tostring(text or "")
            local firstSet = not self.textEverSet
            self.textEverSet = true
            if self.text ~= text or firstSet then
                self.text = text
                if self.scripts.OnTextChanged then
                    self.scripts.OnTextChanged(self)
                end
            end
        end,
        GetText = function(self) return self.text end,
        SetValue = function(self, value)
            value = Clamp(value, self.min, self.max)
            if self.value ~= value then
                self.value = value
                if self.scripts.OnValueChanged then
                    self.scripts.OnValueChanged(self, value)
                end
            end
        end,
        GetValue = function(self) return self.value end,
        SetMinMaxValues = function(self, min, max) self.min, self.max = min, max end,
        ClearFocus = function() end,
        SetFocus = function() end,
        IsShown = function(self) return self.shown end,
    }
end

local function MakeSearchableDropdown(items, selectedIndex)
    local dropdown = {
        qfxsaItems = items,
        qfxsaValue = items[selectedIndex].value,
        qfxsaSearchable = true,
        qfxsaSearchText = "",
        qfxsaOnValueChanged = function() end,
    }
    dropdown.qfxsaBeginSearch = function(self)
        self.qfxsaSearchText = ""
        self.searchBox:Show()
        self.searchBox:SetText("")
        self.searchBox:SetFocus()
    end
    dropdown.qfxsaEndSearch = function(self)
        self.qfxsaSearchText = ""
        self.searchBox:SetText("")
        self.searchBox:ClearFocus()
        self.searchBox:Hide()
    end
    return dropdown
end

-- Popup logic copied from the addon (WidgetDropdownPopup.lua), including the
-- hardened UpdateSearch (empty search preserves the scroll).
local function MakePopup()
    local popup = NewFrame("Frame")
    local SetScroll -- forward declaration, mirrors the addon
    popup.rows = {}
    popup.offset = 0
    popup.visibleRows = 0
    popup.maxOffset = 0
    popup.hasScroll = false
    popup.filteredItems = nil
    popup.noResults = nil
    popup.owner = nil
    popup.popupWidth = 260

    popup.scrollBar = NewFrame("Slider")
    popup.scrollBar:SetMinMaxValues(0, 0)
    popup.scrollBar:SetValue(0)
    popup.scrollBar:SetScript("OnValueChanged", function(_, value)
        SetScroll(value, true)
    end)

    local function GetDisplayedItems()
        if type(popup.filteredItems) == "table" then
            return popup.filteredItems
        end
        local owner = popup.owner
        return owner and owner.qfxsaItems or {}
    end

    local function RenderRows()
        local owner = popup.owner
        if not owner then return end
        local items = GetDisplayedItems()
        local offset = math.floor(tonumber(popup.offset) or 0)
        local visibleRows = tonumber(popup.visibleRows) or 0
        local selected = owner.qfxsaValue
        for i = 1, visibleRows do
            local row = popup.rows[i] or {}
            popup.rows[i] = row
            local itemIndex = offset + i
            local item = items[itemIndex]
            row.itemIndex = item and itemIndex or nil
            row.itemValue = item and item.value or nil
            row.checked = (not owner.qfxsaMultiSelect) and selected == (item and item.value or nil) or false
        end
    end

    SetScroll = function(value, fromSlider)
        local maxOffset = math.max(0, tonumber(popup.maxOffset) or 0)
        value = math.floor(Clamp(tonumber(value) or 0, 0, maxOffset) + 0.5)
        popup.offset = value
        if not fromSlider then
            popup.scrollBar:SetValue(value)
        end
        RenderRows()
    end

    local function ConfigureListLayout(resetOffset)
        local items = GetDisplayedItems()
        local count = #items
        local visibleRows = math.min(math.max(1, count), DROPDOWN_MAX_VISIBLE_ROWS)
        popup.visibleRows = visibleRows
        popup.maxOffset = math.max(0, count - visibleRows)
        popup.hasScroll = count > visibleRows
        popup.scrollBar:SetMinMaxValues(0, popup.maxOffset)
        if resetOffset then
            SetScroll(0)
        else
            SetScroll(popup.offset or 0)
        end
    end

    local function UpdateSearch(owner, searchText)
        if popup.closing or popup.owner ~= owner or not owner or not owner.qfxsaSearchable then
            return
        end
        local normalized = tostring(searchText or ""):match("^%s*(.-)%s*$"):lower()
        local filtered = {}
        for _, item in ipairs(owner.qfxsaItems or {}) do
            local text = tostring(item.text or ""):lower()
            if normalized == "" or text:find(normalized, 1, true) then
                filtered[#filtered + 1] = item
            end
        end
        popup.filteredItems = filtered
        popup.noResults = #filtered == 0
        -- hardened: an empty search preserves the current scroll
        ConfigureListLayout(normalized ~= "")
    end

    popup.UpdateSearch = UpdateSearch
    popup.ConfigureListLayout = ConfigureListLayout
    popup.RenderRows = RenderRows
    popup.SetScroll = SetScroll
    popup.SetPopupScroll = SetScroll
    return popup
end

-- Popup:Show flow copied from the addon (search mode starts before the final
-- scroll-to-selected, which runs after popup:Show()).
local function RunShow(popup, dropdown, searchBox)
    dropdown.searchBox = searchBox
    local items = dropdown.qfxsaItems or {}
    popup.owner = dropdown
    popup.filteredItems = dropdown.qfxsaSearchable and {} or nil
    popup.noResults = nil
    if dropdown.qfxsaSearchable then
        for _, item in ipairs(items) do
            popup.filteredItems[#popup.filteredItems + 1] = item
        end
    end
    if dropdown.qfxsaSearchable and type(dropdown.qfxsaBeginSearch) == "function" then
        dropdown:qfxsaBeginSearch()
    end
    popup.ConfigureListLayout(true)
    local selectedIndex = 1
    for i, item in ipairs(items) do
        if dropdown.qfxsaValue == item.value then
            selectedIndex = i
            break
        end
    end
    local initialOffset = 0
    if popup.hasScroll and selectedIndex and selectedIndex > 1 then
        initialOffset = selectedIndex - math.ceil((popup.visibleRows or 1) / 2)
    end
    local finalOffset = Clamp(initialOffset, 0, popup.maxOffset or 0)
    popup:Show()
    popup.RenderRows()
    popup.SetPopupScroll(finalOffset)
end

local function RunClose(popup, dropdown)
    popup.owner:qfxsaEndSearch()
    popup.owner = nil
    popup.offset = 0
    popup.hasScroll = nil
    popup.filteredItems = nil
    popup.noResults = nil
    popup.closing = nil
end

local function MakeSearchBox(popup)
    local searchBox = NewFrame("EditBox")
    searchBox:SetScript("OnTextChanged", function(self)
        local dropdown = popup.owner
        if not dropdown then return end
        dropdown.qfxsaSearchText = self:GetText()
        popup.UpdateSearch(dropdown, dropdown.qfxsaSearchText)
    end)
    return searchBox
end

-- 50 items; the selection sits at index 40 -> expected offset 35
local items = {}
for i = 1, 50 do
    items[i] = { value = "voice_" .. i, text = "Voice " .. i }
end
local EXPECTED_OFFSET = 40 - math.ceil(DROPDOWN_MAX_VISIBLE_ROWS / 2)

-- Case 1: the FIRST open of a searchable dropdown jumps to the selected item.
do
    local popup = MakePopup()
    local searchBox = MakeSearchBox(popup)
    local dropdown = MakeSearchableDropdown(items, 40)
    RunShow(popup, dropdown, searchBox)
    Assert(popup.offset == EXPECTED_OFFSET, "case1: first open scrolls to the selected item")
    local checkedVisible = 0
    for _, row in ipairs(popup.rows) do
        if row.checked then checkedVisible = checkedVisible + 1 end
    end
    Assert(checkedVisible == 1, "case1: the selected row is visible and checked")
end

-- Case 2: the SECOND open (after a close) also jumps to the selected item.
do
    local popup = MakePopup()
    local searchBox = MakeSearchBox(popup)
    local dropdown = MakeSearchableDropdown(items, 40)
    RunShow(popup, dropdown, searchBox)
    RunClose(popup, dropdown)
    RunShow(popup, dropdown, searchBox)
    Assert(popup.offset == EXPECTED_OFFSET, "case2: second open scrolls to the selected item")
end

-- Case 3: UpdateSearch with an empty search preserves the scroll instead of
-- resetting it to the top.
do
    local popup = MakePopup()
    local searchBox = MakeSearchBox(popup)
    local dropdown = MakeSearchableDropdown(items, 40)
    RunShow(popup, dropdown, searchBox)
    RunClose(popup, dropdown)
    -- simulate the first SetText on a fresh box firing OnTextChanged with ""
    RunShow(popup, dropdown, searchBox)
    popup.UpdateSearch(dropdown, "")
    Assert(popup.offset == EXPECTED_OFFSET, "case3: empty search keeps the selected-item scroll")
end

-- Case 4: a real (non-empty) search still resets to the top of the filter.
do
    local popup = MakePopup()
    local searchBox = MakeSearchBox(popup)
    local dropdown = MakeSearchableDropdown(items, 40)
    RunShow(popup, dropdown, searchBox)
    popup.UpdateSearch(dropdown, "Voice 4")
    Assert(popup.offset == 0, "case4: non-empty search starts at the top of the filter")
    Assert(#popup.filteredItems == 11, "case4: filtered list contains matching voices")
end

-- Case 5: a searchable dropdown with the selection at the top needs no jump.
do
    local popup = MakePopup()
    local searchBox = MakeSearchBox(popup)
    local dropdown = MakeSearchableDropdown(items, 3)
    RunShow(popup, dropdown, searchBox)
    Assert(popup.offset == 0, "case5: selection near the top stays at offset 0")
end

print("test_dropdown_popup_scroll: all 5 cases passed")
