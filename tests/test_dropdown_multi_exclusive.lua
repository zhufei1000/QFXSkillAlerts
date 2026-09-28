-- Multi-select dropdown behavior used by the scope controls: the "All ..."
-- entry is exclusive (selecting it clears concrete choices and vice versa) and
-- long selections collapse to a localized count summary. Mirrors the logic in
-- WidgetDropdownPopup.lua (ToggleDropdownMultiValue / BuildMultiDropdownText)
-- and WidgetDropdown.lua (SetMultiDropdownValues).

local function Fail(message)
    error(message, 2)
end

local function Assert(condition, message)
    if not condition then
        Fail(message or "assertion failed")
    end
end

local function Equal(actual, expected, message)
    if actual ~= expected then
        Fail(string.format("%s (expected %s, got %s)", message or "values differ", tostring(expected), tostring(actual)))
    end
end

-- Extracted addon logic under test.
local function BuildMultiDropdownText(dropdown)
    local selected = dropdown.qfxsaSelectedValues or {}
    local parts = {}
    for _, item in ipairs(dropdown.qfxsaItems or {}) do
        if selected[item.value] == true then
            parts[#parts + 1] = tostring(item.text or item.value or "")
        end
    end
    if #parts == 0 then
        return tostring(dropdown.qfxsaFallbackText or "")
    end
    local limit = tonumber(dropdown.qfxsaSummaryLimit) or 0
    if limit > 0 and #parts > limit and type(dropdown.qfxsaSummaryFormat) == "string" then
        return string.format(dropdown.qfxsaSummaryFormat, #parts)
    end
    return table.concat(parts, ", ")
end

local function ToggleDropdownMultiValue(dropdown, value)
    local selected = dropdown.qfxsaSelectedValues or {}
    dropdown.qfxsaSelectedValues = selected
    selected[value] = selected[value] ~= true
    local exclusive = dropdown.qfxsaExclusiveValue
    if exclusive ~= nil then
        if value == exclusive and selected[value] == true then
            for key in pairs(selected) do
                if key ~= exclusive then
                    selected[key] = nil
                end
            end
        elseif value ~= exclusive and selected[value] == true then
            selected[exclusive] = nil
        end
    end
    dropdown.qfxsaText = BuildMultiDropdownText(dropdown)
end

local ITEMS = {
    { value = 0, text = "All" },
    { value = 71, text = "Arms" },
    { value = 72, text = "Fury" },
    { value = 73, text = "Protection" },
}

-- Case 1: selecting a concrete entry clears "All".
do
    local drop = {
        qfxsaItems = ITEMS,
        qfxsaSelectedValues = { [0] = true },
        qfxsaExclusiveValue = 0,
    }
    ToggleDropdownMultiValue(drop, 71)
    Assert(drop.qfxsaSelectedValues[0] ~= true, "case1: all cleared")
    Assert(drop.qfxsaSelectedValues[71] == true, "case1: concrete selected")
end

-- Case 2: selecting "All" clears concrete entries.
do
    local drop = {
        qfxsaItems = ITEMS,
        qfxsaSelectedValues = { [71] = true, [72] = true },
        qfxsaExclusiveValue = 0,
    }
    ToggleDropdownMultiValue(drop, 0)
    Assert(drop.qfxsaSelectedValues[0] == true, "case2: all selected")
    Assert(drop.qfxsaSelectedValues[71] ~= true, "case2: concrete cleared")
    Assert(drop.qfxsaSelectedValues[72] ~= true, "case2: concrete cleared 2")
end

-- Case 3: unchecking "All" leaves nothing selected (falls back to placeholder).
do
    local drop = {
        qfxsaItems = ITEMS,
        qfxsaSelectedValues = { [0] = true },
        qfxsaExclusiveValue = 0,
        qfxsaFallbackText = "Select",
    }
    ToggleDropdownMultiValue(drop, 0)
    Equal(drop.qfxsaText, "Select", "case3: placeholder")
end

-- Case 4: long selections collapse to the count summary.
do
    local drop = {
        qfxsaItems = ITEMS,
        qfxsaSelectedValues = { [71] = true, [72] = true, [73] = true },
        qfxsaSummaryLimit = 2,
        qfxsaSummaryFormat = "%d Specs",
    }
    Equal(BuildMultiDropdownText(drop), "3 Specs", "case4: count summary")

    drop.qfxsaSummaryLimit = 3
    Equal(BuildMultiDropdownText(drop), "Arms, Fury, Protection", "case4: joined under limit")
end

print("test_dropdown_multi_exclusive: OK")
