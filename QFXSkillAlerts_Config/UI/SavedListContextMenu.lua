local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.UI = NS.UI or {}
NS.UI.SavedListContextMenu = NS.UI.SavedListContextMenu or {}

local ContextMenu = NS.UI.SavedListContextMenu
local Skin = NS.UI.Skin
local SavedListBuilder = NS.UI.SavedListBuilder or {}
local CollectionStore = NS.CollectionStore or {}
local L = NS.L or function(key, ...) if select("#", ...) > 0 then return string.format(tostring(key), ...) end return tostring(key) end

local CONTEXT_MENU_WIDTH = 220
local CONTEXT_MENU_ROW_HEIGHT = 24
local COLLECTION_PAGE_SIZE = 12

local function TrimText(value)
    if NS.Utils and type(NS.Utils.TrimText) == "function" then
        return NS.Utils.TrimText(value)
    end
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function SortedNumberKeys(map)
    local keys = {}
    for key, value in pairs(type(map) == "table" and map or {}) do
        local numberKey = tonumber(key)
        if numberKey and type(value) == "table" then
            keys[#keys + 1] = numberKey
        end
    end
    table.sort(keys)
    return keys
end

local function FindDirectCollectionID(scope, entryKey, classID, specID)
    entryKey = TrimText(entryKey)
    for groupID, group in pairs(type(scope) == "table" and scope.groups or {}) do
        for _, ref in ipairs(type(group) == "table" and group.entries or {}) do
            if CollectionStore.IsCDMEntryKey and CollectionStore.IsCDMEntryKey(entryKey) then
                if TrimText(ref) == entryKey then
                    return tostring(groupID)
                end
            elseif CollectionStore.EntryRefToKey then
                local refKey = CollectionStore.EntryRefToKey(classID, specID, ref)
                if refKey == entryKey then
                    return tostring(groupID)
                end
            end
        end
    end
    return nil
end

local function ResolveScopeLabel(classID, specID)
    local api = NS.API or {}
    local className = type(api.ResolveClassName) == "function" and api.ResolveClassName(classID) or L("FALLBACK_CLASS", classID)
    local specName = type(api.ResolveSpecName) == "function" and api.ResolveSpecName(classID, specID) or L("FALLBACK_SPEC", specID)
    return string.format("%s / %s", tostring(className or classID), tostring(specName or specID))
end

function ContextMenu:GetCollectionTargets(entryKey)
    local db = type(QFXSkillAlertsDB) == "table" and QFXSkillAlertsDB or nil
    local targets = {}
    if not db or type(db.collectionData) ~= "table" then
        return targets
    end

    for _, classID in ipairs(SortedNumberKeys(db.collectionData)) do
        local classMap = db.collectionData[classID]
        for _, specID in ipairs(SortedNumberKeys(classMap)) do
            local scope = classMap[specID]
            local groups = type(scope) == "table" and scope.groups or {}
            local currentGroupID = FindDirectCollectionID(scope, entryKey, classID, specID)
            local visited = {}
            local scopeLabel = ResolveScopeLabel(classID, specID)

            local function appendGroup(groupID, depth)
                groupID = tostring(groupID or "")
                local group = groups[groupID]
                if groupID == "" or type(group) ~= "table" or visited[groupID] then
                    return
                end
                visited[groupID] = true
                if groupID ~= currentGroupID then
                    local name = TrimText(group.name)
                    if name == "" then name = L("COLLECTION_UNNAMED") end
                    targets[#targets + 1] = {
                        key = CollectionStore.BuildGroupKey(classID, specID, groupID),
                        name = name,
                        scopeLabel = scopeLabel,
                        depth = tonumber(depth) or 0,
                    }
                end
                for _, ref in ipairs(group.entries or {}) do
                    local _, childGroupID = CollectionStore.IsSameScopeGroupRef(classID, specID, ref)
                    if childGroupID and type(groups[childGroupID]) == "table" then
                        appendGroup(childGroupID, (tonumber(depth) or 0) + 1)
                    end
                end
            end

            for _, item in ipairs(type(scope) == "table" and scope.root or {}) do
                if type(item) == "table" and item.type == "group" then
                    appendGroup(item.id, 0)
                end
            end
            local orphanIDs = {}
            for groupID, group in pairs(groups) do
                if type(group) == "table" and not visited[tostring(groupID)] then
                    orphanIDs[#orphanIDs + 1] = tostring(groupID)
                end
            end
            table.sort(orphanIDs)
            for _, groupID in ipairs(orphanIDs) do
                appendGroup(groupID, 0)
            end
        end
    end
    return targets
end

local function CloseNativeDropdowns()
    local closeDropDownMenus = rawget(_G, "CloseDropDownMenus")
    if type(closeDropDownMenus) == "function" then
        pcall(closeDropDownMenus)
    end

    local popup = rawget(_G, "QFXSkillAlertsNativeDropDownPopup")
    if popup and popup.Hide then
        popup:Hide()
    end
    local blocker = rawget(_G, "QFXSkillAlertsNativeDropDownBlocker")
    if blocker and blocker.Hide then
        blocker:Hide()
    end
end

function ContextMenu:Hide(list)
    if not list then
        return
    end
    if list.contextMenu then
        list.contextMenu:Hide()
    end
    if list.contextBlocker then
        list.contextBlocker:Hide()
    end
end

function ContextMenu:Open(list, items, options)
    if not list or type(items) ~= "table" or #items <= 0 then
        return
    end

    CloseNativeDropdowns()

    if not list.contextBlocker then
        local blocker = CreateFrame("Frame", "QFXSkillAlertsSavedListContextBlocker", UIParent)
        blocker:SetAllPoints(UIParent)
        blocker:SetFrameStrata("FULLSCREEN_DIALOG")
        blocker:SetFrameLevel(900)
        blocker:EnableMouse(true)
        blocker:Hide()
        blocker:SetScript("OnMouseDown", function()
            ContextMenu:Hide(list)
        end)
        list.contextBlocker = blocker
    end

    if not list.contextMenu then
        local menu = CreateFrame("Frame", "QFXSkillAlertsSavedListContextMenu", UIParent, "BackdropTemplate")
        menu:SetFrameStrata("TOOLTIP")
        menu:SetFrameLevel(1000)
        menu:EnableMouse(true)
        menu.rows = {}
        if menu.SetBackdrop then
            menu:SetBackdrop({
                bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true,
                tileSize = 16,
                edgeSize = 14,
                insets = { left = 3, right = 3, top = 3, bottom = 3 },
            })
            menu:SetBackdropColor(0, 0, 0, 0.92)
            menu:SetBackdropBorderColor(0.75, 0.75, 0.75, 0.90)
        end
        menu:SetScript("OnHide", function()
            if list.contextBlocker then
                list.contextBlocker:Hide()
            end
        end)
        list.contextMenu = menu
    end

    local menu = list.contextMenu
    for _, row in ipairs(menu.rows or {}) do
        row:Hide()
    end

    options = type(options) == "table" and options or {}
    local width = math.max(CONTEXT_MENU_WIDTH, tonumber(options.width) or CONTEXT_MENU_WIDTH)
    local rowHeight = CONTEXT_MENU_ROW_HEIGHT
    local height = (#items * rowHeight) + 8
    menu:SetSize(width, height)

    for i, item in ipairs(items) do
        local row = menu.rows[i]
        if not row then
            row = CreateFrame("Button", nil, menu)
            row:SetHeight(rowHeight)
            row:SetPoint("LEFT", menu, "LEFT", 4, 0)
            row:SetPoint("RIGHT", menu, "RIGHT", -4, 0)
            local hover = row:CreateTexture(nil, "HIGHLIGHT")
            hover:SetAllPoints(row)
            hover:SetColorTexture(0.24, 0.48, 1.00, 0.18)
            row.hover = hover
            local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            text:SetPoint("LEFT", row, "LEFT", 8, 0)
            text:SetPoint("RIGHT", row, "RIGHT", -8, 0)
            text:SetJustifyH("LEFT")
            text:SetJustifyV("MIDDLE")
            if text.SetWordWrap then
                text:SetWordWrap(false)
            end
            if text.SetMaxLines then
                text:SetMaxLines(1)
            end
            if Skin and Skin.StyleFont then
                Skin:StyleFont(text, "body")
            end
            row.text = text
            menu.rows[i] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", menu, "TOPLEFT", 4, -4 - ((i - 1) * rowHeight))
        row:SetPoint("RIGHT", menu, "RIGHT", -4, 0)
        row.text:SetText(tostring(item.text or ""))
        row:SetScript("OnClick", function()
            ContextMenu:Hide(list)
            if type(item.func) == "function" then
                item.func()
            end
        end)
        row:Show()
    end

    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale() or 1
    local uiWidth = UIParent:GetWidth() or 0
    local uiHeight = UIParent:GetHeight() or 0
    local left = ((x or 0) / scale) + 2
    local top = ((y or 0) / scale) - 2
    if uiWidth > 0 and left + width > uiWidth then
        left = math.max(4, uiWidth - width - 4)
    end
    if uiHeight > 0 and top > uiHeight - 4 then
        top = uiHeight - 4
    end
    if top - height < 4 then
        top = math.min(uiHeight - 4, height + 4)
    end

    list.contextBlocker:Show()
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    menu:Show()
end

function ContextMenu:OpenCollectionMenu(list, key, entryType, page)
    local targets = self:GetCollectionTargets(key)
    page = math.max(1, tonumber(page) or 1)
    local pageCount = math.max(1, math.ceil(#targets / COLLECTION_PAGE_SIZE))
    page = math.min(page, pageCount)
    local items = {
        {
            text = L("CONTEXT_MENU_BACK"),
            func = function()
                ContextMenu:OpenEntryMenu(list, key, entryType)
            end,
        },
    }

    if #targets == 0 then
        items[#items + 1] = { text = L("NO_AVAILABLE_COLLECTION") }
    else
        local firstIndex = ((page - 1) * COLLECTION_PAGE_SIZE) + 1
        local lastIndex = math.min(#targets, firstIndex + COLLECTION_PAGE_SIZE - 1)
        for index = firstIndex, lastIndex do
            local target = targets[index]
            local indent = string.rep("  ", math.min(tonumber(target.depth) or 0, 4))
            items[#items + 1] = {
                text = string.format("%s%s  |cff808080[%s]|r", indent, target.name, target.scopeLabel),
                func = function()
                    if NS.AceOptions and type(NS.AceOptions.MoveSavedListItem) == "function"
                        and NS.AceOptions:MoveSavedListItem(key, target.key .. ":inside", nil, true) then
                        print("[QFX-SA] " .. L("MSG_ENTRY_ADDED_TO_COLLECTION", target.name))
                        if NS.UI and NS.UI.MainFrame and type(NS.UI.MainFrame.RequestRefresh) == "function" then
                            NS.UI.MainFrame:RequestRefresh("list")
                        elseif list and type(list.RequestRefresh) == "function" then
                            list:RequestRefresh(0)
                        end
                    end
                end,
            }
        end
        if page > 1 then
            items[#items + 1] = {
                text = L("CONTEXT_MENU_PREVIOUS_PAGE", page - 1, pageCount),
                func = function() ContextMenu:OpenCollectionMenu(list, key, entryType, page - 1) end,
            }
        end
        if page < pageCount then
            items[#items + 1] = {
                text = L("CONTEXT_MENU_NEXT_PAGE", page + 1, pageCount),
                func = function() ContextMenu:OpenCollectionMenu(list, key, entryType, page + 1) end,
            }
        end
    end

    self:Open(list, items, { width = 340 })
end

function ContextMenu:OpenEntryMenu(list, key, entryType)
    if list and type(list.SelectKey) == "function" then
        list:SelectKey(key, entryType)
    end

    if tostring(entryType or "") == "cdmVoice" then
        self:Open(list, {
            {
                text = L("EDIT_ENTRY"),
                func = function()
                    if list and type(list.SelectKey) == "function" then
                        list:SelectKey(key, entryType)
                    end
                    if NS.UI and NS.UI.CDMVoiceEditor then
                        NS.UI.CDMVoiceEditor:OpenForEdit(key)
                    end
                end,
            },
            {
                text = L("EXPORT_ENTRY"),
                func = function()
                    if list and type(list.SelectKey) == "function" then
                        list:SelectKey(key, entryType)
                    end
                    local api = NS.API or {}
                    local exportText = type(api.ExportCDMVoiceEntryString) == "function"
                        and api.ExportCDMVoiceEntryString(key) or ""
                    if exportText ~= "" and NS.UI and NS.UI.MainFrame
                        and type(NS.UI.MainFrame.OpenExportDialog) == "function" then
                        NS.UI.MainFrame:OpenExportDialog(L("CDM_EXPORT_SINGLE_TITLE"), exportText)
                    end
                end,
            },
            {
                text = L("ADD_ENTRY_TO_COLLECTION"),
                func = function()
                    ContextMenu:OpenCollectionMenu(list, key, entryType, 1)
                end,
            },
            {
                text = L("DELETE_ENTRY"),
                func = function()
                    if list and type(list.SelectKey) == "function" then
                        list:SelectKey(key, entryType)
                    end
                    if NS.UI and NS.UI.MainFrame and type(NS.UI.MainFrame.DeleteCDMVoiceByKey) == "function" then
                        NS.UI.MainFrame:DeleteCDMVoiceByKey(key)
                    end
                end,
            },
        })
        return
    end

    if tostring(entryType or "") == "bloodlust" then
        self:Open(list, {
            {
                text = L("EDIT_ENTRY"),
                func = function()
                    if list and type(list.SelectKey) == "function" then
                        list:SelectKey(key, entryType)
                    end
                    if NS.UI and NS.UI.EditorFrame then
                        NS.UI.EditorFrame:OpenForEdit()
                    end
                end,
            },
            {
                text = L("EXPORT_ENTRY"),
                func = function()
                    if NS.UI and NS.UI.MainFrame and NS.AceOptions and type(NS.AceOptions.ExportEntryString) == "function" then
                        NS.UI.MainFrame:OpenExportDialog(L("EXPORT_ENTRY"), NS.AceOptions:ExportEntryString(key))
                    end
                end,
            },
        })
        return
    end

    self:Open(list, {
        {
            text = L("EDIT_ENTRY"),
            func = function()
                if list and type(list.SelectKey) == "function" then
                    list:SelectKey(key, entryType)
                end
                if NS.UI and NS.UI.EditorFrame then
                    NS.UI.EditorFrame:OpenForEdit()
                end
            end,
        },
        {
            text = L("EXPORT_ENTRY"),
            func = function()
                if NS.UI and NS.UI.MainFrame and NS.AceOptions and type(NS.AceOptions.ExportEntryString) == "function" then
                    NS.UI.MainFrame:OpenExportDialog(L("EXPORT_ENTRY"), NS.AceOptions:ExportEntryString(key))
                end
            end,
        },
        {
            text = L("ADD_ENTRY_TO_COLLECTION"),
            func = function()
                ContextMenu:OpenCollectionMenu(list, key, entryType, 1)
            end,
        },
        {
            text = L("DELETE_ENTRY"),
            func = function()
                if list and type(list.SelectKey) == "function" then
                    list:SelectKey(key, entryType)
                end
                NS.AceOptions:DeleteSelectedEntry(true)
                if NS.UI and NS.UI.MainFrame and type(NS.UI.MainFrame.RequestRefresh) == "function" then
                    NS.UI.MainFrame:RequestRefresh("list")
                elseif list then
                    list:RequestRefresh(0)
                end
            end,
        },
    })
end

function ContextMenu:OpenGroupMenu(list, key)
    local collapsed = false
    if SavedListBuilder and type(SavedListBuilder.IsGroupCollapsed) == "function" then
        collapsed = SavedListBuilder.IsGroupCollapsed(key) == true
    end

    self:Open(list, {
        {
            text = collapsed and L("EXPAND_COLLECTION") or L("COLLAPSE_COLLECTION"),
            func = function()
                if list and type(list.ToggleGroupCollapsed) == "function" then
                    list:ToggleGroupCollapsed(key)
                end
            end,
        },
        {
            text = L("CREATE_VOICE_IN_COLLECTION"),
            func = function()
                if NS.UI and NS.UI.MainFrame and type(NS.UI.MainFrame.OpenNewVoiceInCollection) == "function" then
                    NS.UI.MainFrame:OpenNewVoiceInCollection(key)
                end
            end,
        },
        {
            text = L("CREATE_CHILD_COLLECTION"),
            func = function()
                if NS.UI and NS.UI.MainFrame and type(NS.UI.MainFrame.OpenCollectionNameDialogForGroup) == "function" then
                    NS.UI.MainFrame:OpenCollectionNameDialogForGroup(key)
                end
            end,
        },
        {
            text = L("RENAME_COLLECTION"),
            func = function()
                if NS.UI and NS.UI.MainFrame and type(NS.UI.MainFrame.OpenRenameCollectionDialog) == "function" then
                    NS.UI.MainFrame:OpenRenameCollectionDialog(key)
                end
            end,
        },
        {
            text = L("EXPORT_COLLECTION"),
            func = function()
                if NS.UI and NS.UI.MainFrame and NS.AceOptions and type(NS.AceOptions.ExportCollectionString) == "function" then
                    NS.UI.MainFrame:OpenExportDialog(L("EXPORT_COLLECTION"), NS.AceOptions:ExportCollectionString(key))
                end
            end,
        },
        {
            text = L("DELETE_COLLECTION_WITH_ITEMS"),
            func = function()
                if NS.AceOptions:DeleteCollection(key, true) then
                    if NS.UI and NS.UI.MainFrame and type(NS.UI.MainFrame.RequestRefresh) == "function" then
                        NS.UI.MainFrame:RequestRefresh("list")
                    elseif list then
                        list:RequestRefresh(0)
                    end
                end
            end,
        },
    })
end
