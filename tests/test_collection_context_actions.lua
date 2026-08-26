local function Assert(value, message)
    if not value then error(message or "assertion failed", 2) end
end

local function Equal(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s (expected %s, got %s)", message, tostring(expected), tostring(actual)), 2)
    end
end

QFXSkillAlertsDB = {
    collectionData = {
        [1] = {
            [2] = {
                root = {
                    { type = "group", id = "g1" },
                    { type = "group", id = "g3" },
                },
                groups = {
                    g1 = { name = "Current", entries = { "1:2:1", "group:1:2:g2" } },
                    g2 = { name = "Child", entries = {} },
                    g3 = { name = "Other", entries = {} },
                },
            },
        },
        [2] = {
            [3] = {
                root = { { type = "group", id = "g4" } },
                groups = { g4 = { name = "Inactive", entries = {} } },
            },
        },
    },
}

QFXSkillAlertsNS = {
    Constants = {},
    Utils = {},
    UI = { SavedListBuilder = {} },
    API = {
        ResolveClassName = function(id) return "Class" .. tostring(id) end,
        ResolveSpecName = function(_, id) return "Spec" .. tostring(id) end,
    },
    L = function(key, ...)
        if select("#", ...) > 0 then return string.format(key, ...) end
        return key
    end,
}

dofile("QFXSkillAlerts/Core/CollectionStore.lua")
dofile("QFXSkillAlerts_Config/UI/SavedListContextMenu.lua")

local ContextMenu = QFXSkillAlertsNS.UI.SavedListContextMenu
local targets = ContextMenu:GetCollectionTargets("1:2:1")
Equal(#targets, 3, "the current direct collection should be omitted")
Equal(targets[1].key, "group:1:2:g2", "nested collections should remain selectable")
Equal(targets[2].key, "group:1:2:g3", "same-scope collections should follow root order")
Equal(targets[3].key, "group:2:3:g4", "collections in other saved scopes should be selectable")

local openedItems
local movedSource, movedTarget
ContextMenu.Open = function(_, _, items) openedItems = items end
QFXSkillAlertsNS.AceOptions = {
    MoveSavedListItem = function(_, source, target)
        movedSource, movedTarget = source, target
        return true
    end,
}
local refreshes = 0
QFXSkillAlertsNS.UI.MainFrame = {
    RequestRefresh = function() refreshes = refreshes + 1 end,
}
ContextMenu:OpenCollectionMenu({}, "1:2:1", "cooldown", 1)
Equal(openedItems[1].text, "CONTEXT_MENU_BACK", "collection picker should provide a back action")
openedItems[2].func()
Equal(movedSource, "1:2:1", "collection action should move the selected entry")
Equal(movedTarget, "group:1:2:g2:inside", "collection action should use the existing inside-drop path")
Equal(refreshes, 1, "a successful context move should refresh the list once")

-- Creating from a collection must preserve that collection and open the type
-- chooser instead of immediately opening a fixed-cooldown editor.
local state = {}
local selectedListKey
local selectorKey
QFXSkillAlertsNS.AceOptions = {
    IsGroupKey = function(_, key) return tostring(key):match("^group:") ~= nil end,
    GetState = function() return state end,
}
QFXSkillAlertsNS.UI.MainFrame = {
    savedList = { SetSelectedKey = function(_, key) selectedListKey = key end },
    OpenAddTypeSelector = function(_, key) selectorKey = key end,
}
dofile("QFXSkillAlerts_Config/UI/MainFrameCollectionDialog.lua")
QFXSkillAlertsNS.UI.MainFrame:OpenNewVoiceInCollection("group:1:2:g2")
Equal(state.selectedCollectionKey, "group:1:2:g2", "collection creation should retain its destination")
Equal(selectedListKey, "group:1:2:g2", "collection creation should keep the saved-list selection")
Equal(selectorKey, "group:1:2:g2", "collection creation should open the type selector in collection mode")

-- The top Add Group dialog must ignore a stale selected collection, while the
-- explicit context action must preserve the requested parent.
local dialog = {
    title = { SetText = function() end },
    saveButton = { SetText = function() end },
    editBox = { SetText = function() end, SetFocus = function() end },
    iconEditBox = { SetText = function() end },
    UpdateIconPreview = function() end,
    Show = function() end,
    Raise = function() end,
}
QFXSkillAlertsNS.UI.MainFrame.EnsureCollectionDialog = function() return dialog end
state.selectedKey = "group:1:2:g1"
state.selectedCollectionKey = "group:1:2:g1"
QFXSkillAlertsNS.UI.MainFrame:OpenCollectionNameDialog()
Assert(dialog.parentGroupKey == nil, "top Add Group must always open in root mode")
QFXSkillAlertsNS.UI.MainFrame:OpenCollectionNameDialogForGroup("group:1:2:g2")
Equal(dialog.parentGroupKey, "group:1:2:g2", "context child-group action must pass its explicit parent")

-- The store controller must enforce the same rule even if a caller leaves a
-- selected group in state.
QFXSkillAlertsDB = {
    collectionSerial = 1,
    collectionData = {
        [1] = {
            [2] = {
                root = {
                    { type = "group", id = "g1" },
                    { type = "group", id = "g2" },
                },
                groups = {
                    g1 = { name = "Existing", entries = {} },
                    g2 = { name = "Must Survive", entries = { "1:2:1" } },
                },
            },
        },
    },
}
local controllerState = {
    classID = 1,
    specID = 2,
    selectedKey = "group:1:2:g1",
    selectedCollectionKey = "group:1:2:g1",
}
QFXSkillAlertsNS.API = {
    GetCurrentClassSpec = function() return 1, 2 end,
    GetStoredEntryMap = function() return { [1] = { spellId = 123 } } end,
    GetOrderedEntryIndices = function() return { 1 } end,
    GetEntry = function(entryMap, index) return entryMap[index] end,
}
local owner = { GetState = function() return controllerState end }
dofile("QFXSkillAlerts_Config/Core/CollectionController.lua")
Assert(QFXSkillAlertsNS.CollectionController:CreateCollection(owner, "Parallel", nil, nil, true),
    "top-level collection creation should succeed")
local scope = QFXSkillAlertsDB.collectionData[1][2]
Equal(#scope.root, 3, "a stale selected collection must not capture the new root collection")
Equal(scope.root[1].id, "g1", "the existing root collection must remain intact")
Equal(scope.root[2].id, "g2", "the collection at the stale counter's next ID must survive")
Equal(scope.root[3].id, "g3", "the new collection must skip every existing group ID")
Equal(scope.groups.g2.name, "Must Survive", "new collection creation must not overwrite an existing group")
Equal(scope.groups.g2.entries[1], "1:2:1", "existing group membership must survive ID repair")
Equal(QFXSkillAlertsDB.collectionSerial, 3, "the stale group counter must synchronize to saved group IDs")
Equal(#scope.groups.g1.entries, 0, "root creation must not change the existing collection membership")
Assert(QFXSkillAlertsNS.CollectionController:CreateCollection(owner, "Child", nil, "group:1:2:g1", true),
    "explicit child collection creation should succeed")
Equal(#scope.root, 3, "an explicit child must not become another root")
Equal(scope.groups.g1.entries[1], "group:1:2:g4", "only the explicit child action may create nesting")

-- Repairing a stale serial must not interfere with either the drag/drop or
-- context-menu move path, both of which use the same :inside destination.
QFXSkillAlertsNS.SavedListOrder = {
    RecordSavedListDisplayMove = function() return true end,
}
dofile("QFXSkillAlerts_Config/Core/SavedListDropKey.lua")
dofile("QFXSkillAlerts_Config/Core/SavedListMoveContext.lua")
dofile("QFXSkillAlerts_Config/Core/SavedListMoveController.lua")
Assert(QFXSkillAlertsNS.SavedListMoveController:MoveSavedListItem(
    owner, "1:2:1", "group:1:2:g3:inside", nil, true
), "a saved entry should remain movable after creating a collection")
Equal(#scope.groups.g2.entries, 0, "moving an entry should remove it from its old collection")
Equal(scope.groups.g3.entries[1], "1:2:1", "moving an entry should add it to the chosen collection")

-- All ordinary entries now use global 0:0 keys, but legacy/current collections
-- may still live in a class/spec scope. Dragging such an entry to its 0:0 root
-- must remove the reference from the actual foreign-scope parent collection.
local globalEntries = {
    [1] = { entryType = "event", eventKey = "role_check_start" },
    [2] = { entryType = "event", eventKey = "ready_check" },
}
QFXSkillAlertsDB = {
    specConfigs = { [0] = { [0] = globalEntries } },
    collectionData = {
        [0] = { [0] = { root = {}, groups = {} } },
        [1] = {
            [71] = {
                root = { { type = "group", id = "g5" } },
                groups = { g5 = { name = "Events", entries = { "0:0:1" } } },
            },
        },
    },
}
QFXSkillAlertsNS.API.GetCurrentClassSpec = function() return 1, 71 end
QFXSkillAlertsNS.API.GetStoredEntryMap = function(classID, specID)
    if classID == 0 and specID == 0 then return globalEntries end
    return {}
end
QFXSkillAlertsNS.API.GetOrderedEntryIndices = function(entryMap)
    return entryMap == globalEntries and { 1, 2 } or {}
end
QFXSkillAlertsNS.API.GetEntry = function(entryMap, index)
    return type(entryMap) == "table" and entryMap[index] or nil
end
QFXSkillAlertsNS.API.IsActiveScopeLoaded = function() return true end
local scopedGroup = QFXSkillAlertsDB.collectionData[1][71].groups.g5
Assert(QFXSkillAlertsNS.SavedListMoveController:MoveSavedListItem(
    owner, "0:0:1", "root:0:0:after", nil, true
), "a global event entry should move out of a scoped collection")
Equal(#scopedGroup.entries, 0,
    "moving to the global root must remove the entry from its real scoped parent")
Assert(QFXSkillAlertsNS.SavedListMoveController:MoveSavedListItem(
    owner, "0:0:1", "group:1:71:g5:inside", nil, true
), "a global event entry should move back into a scoped collection")
Equal(scopedGroup.entries[1], "0:0:1",
    "moving into a scoped collection must preserve the global entry key")

-- The same global entry also exists as root layout metadata in scope 0:0.
-- When another global entry is its visible target inside a scoped collection,
-- the group location must win over that root fallback.
scopedGroup.entries = { "0:0:1", "0:0:2" }
Assert(QFXSkillAlertsNS.SavedListMoveController:MoveSavedListItem(
    owner, "0:0:1", "0:0:2:after", nil, true
), "global event entries should reorder inside a scoped collection")
Equal(scopedGroup.entries[1], "0:0:2",
    "the target event should retain its scoped collection position")
Equal(scopedGroup.entries[2], "0:0:1",
    "the dragged event should remain in the collection after reordering")
scopedGroup.entries = { "0:0:1", "0:0:2" }
Assert(QFXSkillAlertsNS.SavedListMoveController:MoveSavedListItem(
    owner, "0:0:1", "0:0:2", nil, true
), "an event already before its target should remain before it")
Equal(scopedGroup.entries[1], "0:0:1",
    "removing the source must not leave a stale target position")
Equal(scopedGroup.entries[2], "0:0:2",
    "before-mode reordering must preserve the target behind the source")
local globalRoot = QFXSkillAlertsDB.collectionData[0][0].root
for _, item in ipairs(globalRoot or {}) do
    Assert(not (type(item) == "table" and item.type == "entry" and item.index == 1),
        "reordering inside a scoped collection must not move the source to the global root")
end

-- An explicit empty destination comes from the top-level Add Alert selector.
-- It must not fall back to a collection left in state by the previous save.
local editorState = {
    selectedKey = "0:0:1",
    selectedCollectionKey = "group:1:71:g5",
    classID = 0,
    specID = 0,
}
local requestedCollection
QFXSkillAlertsNS.UI.EditorFields = {
    PullFromWidgets = function() end,
    PushToWidgets = function() end,
    RefreshLocale = function() end,
}
QFXSkillAlertsNS.UI.EditorDrafts = {
    NormalizeEntryType = function(_, value) return value end,
}
QFXSkillAlertsNS.AceOptions = {
    GetState = function() return editorState end,
    IsGroupKey = function(_, key) return tostring(key):match("^group:") ~= nil end,
    GetCollectionInfo = function(_, key)
        requestedCollection = key
        return { classID = 1, specID = 71, key = key }
    end,
    SyncScopeToCurrentSpec = function()
        editorState.classID = 1
        editorState.specID = 71
        editorState.selectedKey = nil
        editorState.selectedCollectionKey = nil
    end,
    EnsureValidScope = function() end,
    ClearEditorFields = function() editorState.selectedKey = nil end,
}
dofile("QFXSkillAlerts_Config/UI/EditorFrame.lua")
local editorFrame = {
    title = { SetText = function() end },
    IsShown = function() return true end,
    Show = function() end,
    Raise = function() end,
}
QFXSkillAlertsNS.UI.EditorFrame.EnsureFrame = function(self)
    self.frame = editorFrame
    return editorFrame
end
QFXSkillAlertsNS.UI.EditorFrame:OpenForNew("event", "")
Assert(requestedCollection == nil,
    "top-level alert creation must not request the stale collection")
Assert(editorState.selectedCollectionKey == nil,
    "an explicit empty destination must keep the new alert outside collections")

print("collection context action regression tests passed")
