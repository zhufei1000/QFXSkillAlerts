local function Equal(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s (expected %s, got %s)", message, tostring(expected), tostring(actual)), 2)
    end
end

local buildCount = 0
local renderCount = 0

QFXSkillAlertsNS = {
    UI = {
        SavedListBuilder = {
            BuildLayout = function()
                buildCount = buildCount + 1
                return { { key = "loaded" } }, {}, 1, 0
            end,
            CountVisibleHeaderItems = function(rows) return #(rows or {}) end,
        },
        SavedListRenderer = {
            RenderEntryRows = function()
                renderCount = renderCount + 1
                return true
            end,
        },
    },
    AceOptions = {
        GetState = function() return {} end,
    },
}

C_Timer = { After = function() end }
dofile("QFXSkillAlerts_Config/UI/SavedListRefresh.lua")

local Refresh = QFXSkillAlertsNS.UI.SavedListRefresh
local list = { state = {}, selectedKey = "" }

Refresh:Refresh(list, true)
Equal(buildCount, 1, "the first open must build the layout")
Equal(renderCount, 1, "the first open must render the layout")

Refresh:Refresh(list, true)
Equal(buildCount, 1, "a clean reopen must reuse the cached layout")
Equal(renderCount, 2, "a clean reopen must still repaint cached rows")

list._layoutDirty = true
Refresh:Refresh(list, true)
Equal(buildCount, 2, "a dirty cache must rebuild the layout")
Equal(renderCount, 3, "a rebuilt layout must render")

-- The full builder must not use the old duplicate all-entry scan.  Remaining
-- scopes are now appended through the same per-scope layout cache.
local scopeCalls = 0
QFXSkillAlertsNS.API = {
    GetCurrentClassSpec = function() return 1, 1 end,
}
QFXSkillAlertsNS.AceOptions = {
    GetAllSavedEntryList = function()
        error("duplicate all-entry scan must not run", 2)
    end,
    GetSavedListLayoutForScope = function(_, classID, specID)
        scopeCalls = scopeCalls + 1
        if classID == 2 and specID == 3 then
            return { { itemType = "entry", key = "2:3:1", isLoaded = false } }
        end
        return {}
    end,
}
QFXSkillAlertsDB = {
    specConfigs = { [2] = { [3] = { [1] = {} } } },
    collectionData = {},
    savedListOrder = {},
}

dofile("QFXSkillAlerts_Config/UI/SavedListBuilder.lua")
local loaded, unloaded = QFXSkillAlertsNS.UI.SavedListBuilder.BuildLayout({}, {})
Equal(#loaded, 0, "inactive test entry must not enter the loaded section")
Equal(#unloaded, 1, "remaining scopes must still be included")
Equal(unloaded[1].key, "2:3:1", "the remaining-scope row must be preserved")
Equal(scopeCalls, 4, "only the three active roots and one remaining scope should be built")

print("saved list cache regression tests passed")
