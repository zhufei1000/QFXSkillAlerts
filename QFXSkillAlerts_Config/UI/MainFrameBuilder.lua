local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.UI = NS.UI or {}
local NativeCreateFrame = CreateFrame
local function CreateFrame(kind, name, parent, template)
    local bridge = NS.UI.Renderer
    if bridge then return bridge.CreateFrame(kind, name, parent, template) end
    return NativeCreateFrame(kind, name, parent, template)
end
NS.UI.MainFrameBuilder = NS.UI.MainFrameBuilder or {}

local Builder = NS.UI.MainFrameBuilder
local Widgets = NS.UI.Widgets
local W = NS.UI.Renderer.Widgets
local L = NS.L or function(key, ...)
    if select("#", ...) > 0 then
        return string.format(tostring(key), ...)
    end
    return tostring(key)
end
local MainFrameLocale = NS.UI.MainFrameLocale or {}

function Builder:EnsureFrame(owner)
    owner = owner or (NS.UI and NS.UI.MainFrame)
    if not owner then
        return nil
    end
    if owner.frame then
        return owner.frame
    end

    local frame = CreateFrame("Frame", "QFXSkillAlertsMainFrame", UIParent, "BackdropTemplate")
    frame:SetSize(1040, 700)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:Hide()
    tinsert(UISpecialFrames, frame:GetName())
    local chrome = W:AddonWindow(frame, {
        title = NS.ADDON_DISPLAY_NAME or L("ADDON_DISPLAY_NAME"), version = "--",
        locale = NS.LOCALE, repository = "https://github.com/zhufei1000/QFXSkillAlerts",
        onClose = function() owner:Close() end,
    })
    local content = chrome.content
    local summary = Widgets:CreateLabel(content, "", "GameFontHighlightSmall")
    summary:SetPoint("TOPLEFT", content, "TOPLEFT", 8, -4)
    summary:SetPoint("RIGHT", content, "RIGHT", -340, 0)

    local languageLabel = Widgets:CreateLabel(content, L("LABEL_LANGUAGE"), "GameFontNormal")
    local languageDrop = Widgets:CreateDropdown(content, "QFXSkillAlertsLanguageDropDown", 180)
    languageDrop:ClearAllPoints()
    languageDrop:SetPoint("TOPRIGHT", content, "TOPRIGHT", -8, 0)
    languageLabel:ClearAllPoints()
    languageLabel:SetPoint("RIGHT", languageDrop, "LEFT", -8, 0)
    languageLabel:SetJustifyH("RIGHT")
    Widgets:SetDropdownItems(languageDrop, MainFrameLocale:BuildLanguageItems())
    Widgets:SetDropdownValue(languageDrop, NS.GetLanguageMode and NS.GetLanguageMode() or "auto", L("LANGUAGE_AUTO"))
    languageDrop.qfxsaOnValueChanged = function(value)
        if NS.SetLanguageMode then
            NS.SetLanguageMode(value)
            local label = NS.GetLanguageDisplayName and NS.GetLanguageDisplayName(value) or tostring(value or "auto")
            print("[QFX-SA] " .. L("MSG_LANGUAGE_CHANGED", label))
        end
        owner:RefreshLocale()
    end


    local addBtn = Widgets:CreateButton(content, L("BTN_ADD_VOICE"), 112, 32)
    addBtn:SetPoint("TOPLEFT", summary, "BOTTOMLEFT", 0, -16)

    local addGroupBtn = Widgets:CreateButton(content, L("BTN_ADD_COLLECTION"), 112, 32)
    addGroupBtn:SetPoint("LEFT", addBtn, "RIGHT", 8, 0)

    local editBtn = Widgets:CreateButton(content, L("BTN_EDIT"), 104, 32)
    editBtn:SetPoint("LEFT", addGroupBtn, "RIGHT", 8, 0)

    local deleteBtn = Widgets:CreateButton(content, L("BTN_DELETE"), 104, 32)
    deleteBtn:SetPoint("LEFT", editBtn, "RIGHT", 8, 0)

    local refreshBtn = Widgets:CreateButton(content, L("BTN_REFRESH"), 104, 32)
    refreshBtn:SetPoint("LEFT", deleteBtn, "RIGHT", 8, 0)

    local importBtn = Widgets:CreateButton(content, L("BTN_IMPORT"), 104, 32)
    importBtn:SetPoint("LEFT", refreshBtn, "RIGHT", 8, 0)

    local exportAllBtn = Widgets:CreateButton(content, L("BTN_EXPORT_FULL"), 112, 32)
    exportAllBtn:SetPoint("LEFT", importBtn, "RIGHT", 8, 0)

    local toolbarButtons = { addBtn, addGroupBtn, editBtn, deleteBtn, refreshBtn, importBtn, exportAllBtn }
    local toolbarMinWidths = { 116, 120, 96, 96, 96, 96, 116 }
    local function FitToolbarButton(button, minWidth)
        if not button then
            return
        end
        local width = tonumber(minWidth) or 96
        local text = button.GetFontString and button:GetFontString() or nil
        if text and text.GetStringWidth then
            width = math.max(width, math.ceil((text:GetStringWidth() or 0) + 34))
        end
        button:SetSize(width, 32)
    end

    local function LayoutToolbar()
        for index, button in ipairs(toolbarButtons) do
            FitToolbarButton(button, toolbarMinWidths[index])
            button:ClearAllPoints()
            if index == 1 then
                button:SetPoint("TOPLEFT", summary, "BOTTOMLEFT", 0, -16)
            else
                button:SetPoint("LEFT", toolbarButtons[index - 1], "RIGHT", 8, 0)
            end
        end
    end
    LayoutToolbar()
    frame:HookScript("OnShow", LayoutToolbar)

    local authorLabel, versionLabel = chrome.footer.author, chrome.footer.version
    authorLabel:SetWidth(250)
    local contacts = {
        { key = "qq", titleKey = "CONTACT_QQ", value = "1049855225", icon = "contact-qq.blp" },
        { key = "discord", titleKey = "CONTACT_DISCORD", value = "https://discord.gg/HVJ2y4v7k4", icon = "contact-discord.blp" },
        { key = "github", titleKey = "CONTACT_GITHUB", value = "https://github.com/zhufei1000/QFXSkillAlerts", icon = "contact-github.blp" },
    }
    local contactButtons = {}
    local function RefreshFooter()
        local metadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
        local version = "--"
        if type(metadata) == "function" then
            local ok, value = pcall(metadata, "QFXSkillAlerts", "Version")
            if ok and type(value) == "string" and value ~= "" then version = value end
        end
        local entries = {}
        for index, info in ipairs(contacts) do
            entries[index] = { key = info.key, title = L(info.titleKey), value = info.value,
                texture = [[Interface\AddOns\QFXSkillAlerts_Config\Media\]] .. info.icon }
        end
        chrome:Update({ title = NS.ADDON_DISPLAY_NAME or L("ADDON_DISPLAY_NAME"),
            version = version, locale = NS.LOCALE, contacts = entries })
        authorLabel:SetText(L("AUTHOR_LINE"))
        versionLabel:SetText(L("VERSION_LINE", version))
        for index, info in ipairs(contacts) do
            local button = chrome.footer.buttons[index]
            button:ClearAllPoints()
            button:SetPoint("LEFT", authorLabel, "RIGHT", 8 + (index - 1) * 28, 0)
            contactButtons[info.key] = button
        end
    end
    RefreshFooter()
    frame:HookScript("OnShow", RefreshFooter)
    local listHost = CreateFrame("Frame", nil, content, "BackdropTemplate")
    listHost:SetPoint("TOPLEFT", addBtn, "BOTTOMLEFT", 0, -18)
    listHost:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -8, 8)
    Widgets:ApplyPanelChrome(listHost, { inset = true, noFooter = true, topHeight = 20 })

    local savedList = NS.UI.SavedList:Create(listHost)

    if type(owner.BindActions) == "function" then
        owner:BindActions({
            addBtn = addBtn,
            addGroupBtn = addGroupBtn,
            editBtn = editBtn,
            deleteBtn = deleteBtn,
            refreshBtn = refreshBtn,
            importBtn = importBtn,
            exportAllBtn = exportAllBtn,
            savedList = savedList,
        })
    end

    owner.frame = frame
    owner.chrome = chrome
    owner.headerTitle = chrome.title
    owner.layoutHeader = function() chrome:Layout() end
    owner.summary = summary
    owner.languageLabel = languageLabel
    owner.languageDrop = languageDrop
    owner.addBtn = addBtn
    owner.addGroupBtn = addGroupBtn
    owner.editBtn = editBtn
    owner.deleteBtn = deleteBtn
    owner.refreshBtn = refreshBtn
    owner.importBtn = importBtn
    owner.exportAllBtn = exportAllBtn
    owner.layoutToolbar = LayoutToolbar
    owner.savedList = savedList
    owner.authorLabel = authorLabel
    owner.versionLabel = versionLabel
    owner.contactButtons = contactButtons
    owner.refreshFooter = RefreshFooter
    return frame
end
