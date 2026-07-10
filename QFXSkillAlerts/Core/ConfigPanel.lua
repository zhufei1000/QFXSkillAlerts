local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.Core = NS.Core or {}
NS.Core.ConfigPanel = NS.Core.ConfigPanel or {}

local ConfigPanel = NS.Core.ConfigPanel
local L = NS.L or function(key, ...) if select("#", ...) > 0 then return string.format(tostring(key), ...) end return tostring(key) end

local function GetDisplayName()
    return NS.ADDON_DISPLAY_NAME or L("ADDON_DISPLAY_NAME")
end

local function OpenMainFrame()
    if type(NS.LoadConfigAddon) == "function" then
        NS.LoadConfigAddon()
    end
    if NS.UI and NS.UI.MainFrame and type(NS.UI.MainFrame.Open) == "function" then
        NS.UI.MainFrame:Open()
    else
        print("[QFX-SA] " .. L("MSG_MAIN_NOT_READY_LATER"))
    end
end

local function CreateOptionsPanel()
    local panel = CreateFrame("Frame", "QFXSkillAlertsOptionsPanel", UIParent)
    panel.name = GetDisplayName()

    local logo = panel:CreateTexture(nil, "ARTWORK")
    logo:SetSize(42, 42)
    logo:SetPoint("TOPLEFT", 18, -18)
    logo:SetTexture(NS.ADDON_ICON or "Interface\\AddOns\\QFXSkillAlerts\\AppIcon.png")
    logo:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("LEFT", logo, "RIGHT", 12, 4)
    title:SetText(GetDisplayName())

    local author = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    author:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    author:SetText(L("AUTHOR_LINE"))

    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", logo, "BOTTOMLEFT", 0, -20)
    desc:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
    desc:SetJustifyH("LEFT")
    desc:SetJustifyV("TOP")
    desc:SetText(L("OPTIONS_DESC"))

    local openButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    openButton:SetSize(190, 32)
    openButton:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -20)
    openButton:SetText(L("OPEN_MAIN_SETTINGS"))
    openButton:SetScript("OnClick", OpenMainFrame)

    local slash = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    slash:SetPoint("TOPLEFT", openButton, "BOTTOMLEFT", 0, -12)
    slash:SetText(L("COMMANDS"))

    panel:SetScript("OnShow", function()
        ConfigPanel:Refresh()
    end)

    panel.qfxsaTitle = title
    panel.qfxsaAuthor = author
    panel.qfxsaDesc = desc
    panel.qfxsaOpenButton = openButton
    panel.qfxsaSlash = slash

    return panel
end

function ConfigPanel:Initialize()
    if self.initialized then
        return self.available == true
    end
    self.initialized = true

    local panel = CreateOptionsPanel()
    self.panel = panel

    local appName = GetDisplayName()
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, appName)
        Settings.RegisterAddOnCategory(category)
        self.category = category
        self.categoryID = category and category.ID
        self.available = true
        return true
    end

    if type(InterfaceOptions_AddCategory) == "function" then
        InterfaceOptions_AddCategory(panel)
        self.available = true
        return true
    end

    self.available = false
    return false
end

function ConfigPanel:Open()
    if not self.initialized then
        self:Initialize()
    end

    if Settings and type(Settings.OpenToCategory) == "function" and self.categoryID then
        Settings.OpenToCategory(self.categoryID)
        return true
    end

    if type(InterfaceOptionsFrame_OpenToCategory) == "function" and self.panel then
        InterfaceOptionsFrame_OpenToCategory(self.panel)
        InterfaceOptionsFrame_OpenToCategory(self.panel)
        return true
    end

    OpenMainFrame()
    return false
end

function ConfigPanel:Refresh()
    local panel = self.panel
    if not panel then
        return
    end
    panel.name = GetDisplayName()
    if panel.qfxsaTitle then panel.qfxsaTitle:SetText(GetDisplayName()) end
    if panel.qfxsaAuthor then panel.qfxsaAuthor:SetText(L("AUTHOR_LINE")) end
    if panel.qfxsaDesc then panel.qfxsaDesc:SetText(L("OPTIONS_DESC")) end
    if panel.qfxsaOpenButton then panel.qfxsaOpenButton:SetText(L("OPEN_MAIN_SETTINGS")) end
    if panel.qfxsaSlash then panel.qfxsaSlash:SetText(L("COMMANDS")) end
end
