-- Standalone logic test for the dropdown toggle-clear behavior added to
-- WidgetDropdownPopup.lua (SelectItemByIndex).  Mirrors the exact branches
-- used in the addon so it can be run without the WoW frame environment.

local function Fail(message)
    error(message, 2)
end

local function Assert(condition, message)
    if not condition then
        Fail(message or "assertion failed")
    end
end

-- Copies of the addon helpers (WidgetDropdownPopup.lua) under test.
local function SelectDropdownValue(dropdown, value, text)
    dropdown.qfxsaValue = value
    dropdown.qfxsaText = tostring(text or "")
    if type(dropdown.qfxsaOnValueChanged) == "function" then
        dropdown.qfxsaOnValueChanged(dropdown.qfxsaValue)
    end
end

-- The modified SelectItemByIndex logic (extracted verbatim).
local function SelectItemByIndex(popup, itemIndex)
    local owner = popup.owner
    if not owner then
        return
    end
    local item = popup.items[tonumber(itemIndex) or 0]
    if not item or item.disabled == true then
        return
    end
    if owner.qfxsaMultiSelect then
        owner.qfxsaSelectedValues = owner.qfxsaSelectedValues or {}
        owner.qfxsaSelectedValues[item.value] = owner.qfxsaSelectedValues[item.value] ~= true
        return
    end
    if owner.qfxsaToggleClear and owner.qfxsaValue ~= nil and item.value == owner.qfxsaValue then
        SelectDropdownValue(owner, "", "")
        popup.hidden = true
        return
    end
    SelectDropdownValue(owner, item.value, item.text)
    popup.hidden = true
end

local function MakeDropdown(items, toggleClear, initialValue)
    local changes = {}
    local drop = {
        qfxsaItems = items,
        qfxsaValue = initialValue,
        qfxsaToggleClear = toggleClear == true,
        changes = changes,
        qfxsaOnValueChanged = function(value)
            changes[#changes + 1] = value
        end,
    }
    return drop
end

local ITEMS = {
    { value = "sound_a", text = "Sound A" },
    { value = "sound_b", text = "Sound B" },
}

-- Case 1: toggle-clear off (default) - clicking selected item re-selects.
do
    local popup = { hidden = false }
    local drop = MakeDropdown(ITEMS, false, "sound_a")
    popup.owner = drop
    popup.items = ITEMS
    SelectItemByIndex(popup, 1)
    Assert(drop.qfxsaValue == "sound_a", "case1: value must stay selected")
    Assert(drop.qfxsaText == "Sound A", "case1: text must stay")
    Assert(popup.hidden == true, "case1: popup closes")
end

-- Case 2: toggle-clear on - clicking the selected item clears it.
do
    local popup = { hidden = false }
    local drop = MakeDropdown(ITEMS, true, "sound_a")
    popup.owner = drop
    popup.items = ITEMS
    SelectItemByIndex(popup, 1)
    Assert(drop.qfxsaValue == "", "case2: value cleared")
    Assert(drop.qfxsaText == "", "case2: text cleared")
    Assert(drop.changes[1] == "", "case2: cleared value reported to handler")
    Assert(popup.hidden == true, "case2: popup closes")
end

-- Case 3: toggle-clear on - clicking a different item switches the selection.
do
    local popup = { hidden = false }
    local drop = MakeDropdown(ITEMS, true, "sound_a")
    popup.owner = drop
    popup.items = ITEMS
    SelectItemByIndex(popup, 2)
    Assert(drop.qfxsaValue == "sound_b", "case3: value switched")
    Assert(drop.qfxsaText == "Sound B", "case3: text switched")
    Assert(drop.changes[1] == "sound_b", "case3: new value reported")
end

-- Case 4: after clearing, clicking any item selects it again.
do
    local popup = { hidden = false }
    local drop = MakeDropdown(ITEMS, true, "")
    popup.owner = drop
    popup.items = ITEMS
    SelectItemByIndex(popup, 2)
    Assert(drop.qfxsaValue == "sound_b", "case4: re-select works after clear")
end

-- Case 5: never selected (nil) does not clear into a no-op weird state.
do
    local popup = { hidden = false }
    local drop = MakeDropdown(ITEMS, true, nil)
    popup.owner = drop
    popup.items = ITEMS
    SelectItemByIndex(popup, 1)
    Assert(drop.qfxsaValue == "sound_a", "case5: nil selection selects normally")
end

-- Case 6: disabled item is ignored even when selected.
do
    local popup = { hidden = false }
    local items = { { value = "sound_a", text = "Sound A", disabled = true } }
    local drop = MakeDropdown(items, true, "sound_a")
    popup.owner = drop
    popup.items = items
    SelectItemByIndex(popup, 1)
    Assert(drop.qfxsaValue == "sound_a", "case6: disabled item untouched")
    Assert(popup.hidden == false, "case6: popup stays open")
end

-- Case 7: multi-select dropdowns keep their toggle behavior, no clear.
do
    local popup = { hidden = false }
    local drop = MakeDropdown(ITEMS, true, {})
    drop.qfxsaMultiSelect = true
    drop.qfxsaSelectedValues = { sound_a = true }
    popup.owner = drop
    popup.items = ITEMS
    SelectItemByIndex(popup, 1)
    Assert(drop.qfxsaSelectedValues.sound_a == false, "case7: multi-select toggles off")
    Assert(drop.qfxsaSelectedValues.sound_b == nil, "case7: other values untouched")
end

print("test_dropdown_toggle_clear: all 7 cases passed")
