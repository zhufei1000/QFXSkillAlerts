local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.Core = NS.Core or {}
NS.Core.MinimapButton = NS.Core.MinimapButton or {}

local MinimapButton = NS.Core.MinimapButton
local L = NS.L or function(key, ...) if select("#", ...) > 0 then return string.format(tostring(key), ...) end return tostring(key) end
local ADDON_NAME = "QFXSkillAlerts"
local OLD_BUTTON_NAME = "QFXSkillAlertsMinimapButton"
local DEFAULT_ANGLE = 225
local DEFAULT_RADIUS = 82
local ICON_PATH = NS.ADDON_ICON or "Interface\\AddOns\\QFXSkillAlerts\\AppIcon.png"

local function GetDisplayName()
    return NS.ADDON_DISPLAY_NAME or L("ADDON_DISPLAY_NAME")
end

local function EnsureDB()
    local db = QFXSkillAlertsDB
    if type(db) ~= "table" then
        db = {}
        QFXSkillAlertsDB = db
    end

    if type(db.minimap) ~= "table" then
        db.minimap = {}
    end

    -- Old custom minimap button used angle/radius.  LibDBIcon uses minimapPos.
    -- Keep the old fields for compatibility, but migrate the actual saved angle.
    if db.minimap.minimapPos == nil then
        db.minimap.minimapPos = tonumber(db.minimap.angle) or DEFAULT_ANGLE
    end
    if db.minimap.angle == nil then
        db.minimap.angle = tonumber(db.minimap.minimapPos) or DEFAULT_ANGLE
    end
    if db.minimap.radius == nil then
        db.minimap.radius = DEFAULT_RADIUS
    end
    if db.minimap.hide == nil then
        db.minimap.hide = false
    end
    if db.minimap.lock == nil then
        db.minimap.lock = false
    end

    return db.minimap
end

local function OpenMainFrame()
    if type(NS.LoadConfigAddon) == "function" then
        NS.LoadConfigAddon()
    end
    if NS.UI and NS.UI.MainFrame and type(NS.UI.MainFrame.Open) == "function" then
        NS.UI.MainFrame:Open()
    else
        print("[QFX-SA] " .. L("MSG_MAIN_NOT_READY"))
    end
end

local function OpenBlizzardOptions()
    if NS.Core and NS.Core.ConfigPanel and type(NS.Core.ConfigPanel.Open) == "function" then
        NS.Core.ConfigPanel:Open()
    else
        OpenMainFrame()
    end
end

local function HideOldManualButton()
    local old = _G[OLD_BUTTON_NAME]
    if old and old.Hide then
        old:Hide()
        old:SetParent(nil)
        old:SetScript("OnUpdate", nil)
        old:SetScript("OnClick", nil)
        old:SetScript("OnEnter", nil)
        old:SetScript("OnLeave", nil)
        old:SetScript("OnDragStart", nil)
        old:SetScript("OnDragStop", nil)
    end
end

local function CreateDataObject()
    if MinimapButton.dataObject then
        return MinimapButton.dataObject
    end

    local LibStubGlobal = rawget(_G, "LibStub")
    local LDB = LibStubGlobal and LibStubGlobal("LibDataBroker-1.1", true)
    if not LDB or type(LDB.NewDataObject) ~= "function" then
        return nil
    end

    local obj = LDB:NewDataObject(ADDON_NAME, {
        type = "launcher",
        text = GetDisplayName(),
        label = GetDisplayName(),
        icon = ICON_PATH,
        iconCoords = { 0.08, 0.92, 0.08, 0.92 },
        OnClick = function(_, mouseButton)
            if mouseButton == "RightButton" then
                OpenBlizzardOptions()
            else
                OpenMainFrame()
            end
        end,
        OnTooltipShow = function(tooltip)
            if not tooltip then return end
            tooltip:SetText(GetDisplayName(), 1, 0.82, 0)
            tooltip:AddLine(L("MINIMAP_LEFT"), 1, 1, 1)
            tooltip:AddLine(L("MINIMAP_RIGHT"), 1, 1, 1)
            tooltip:AddLine(L("MINIMAP_DRAG"), 0.7, 0.7, 0.7)
            tooltip:AddLine("LibDBIcon-1.0", 0.55, 0.75, 1)
        end,
    })

    MinimapButton.dataObject = obj
    return obj
end

local function GetIconLib()
    local LibStubGlobal = rawget(_G, "LibStub")
    if not LibStubGlobal then return nil end
    return LibStubGlobal("LibDBIcon-1.0", true)
end

local function RefreshButtonReference()
    local IconLib = GetIconLib()
    if IconLib and type(IconLib.GetMinimapButton) == "function" then
        MinimapButton.button = IconLib:GetMinimapButton(ADDON_NAME)
    else
        MinimapButton.button = _G["LibDBIcon10_" .. ADDON_NAME]
    end

    local button = MinimapButton.button
    if button then
        -- These hints make the button easier for skin/minimap addons to identify.
        button.qfxSkinTarget = true
        button.qfxSkinGroup = "LibDBIconMinimapButton"
        button.QFXSkillAlertsButton = true
    end
end

function MinimapButton:UpdatePosition()
    local db = EnsureDB()
    db.angle = tonumber(db.minimapPos) or tonumber(db.angle) or DEFAULT_ANGLE

    local IconLib = GetIconLib()
    if IconLib and type(IconLib.Refresh) == "function" then
        IconLib:Refresh(ADDON_NAME, db)
    end
    RefreshButtonReference()
end

function MinimapButton:UpdateDragPosition()
    -- Dragging is now handled by LibDBIcon.  This method is kept so older code
    -- calling it will not error.
    self:UpdatePosition()
end

function MinimapButton:Initialize()
    if self.initialized then
        self:UpdatePosition()
        return
    end
    self.initialized = true

    HideOldManualButton()

    local db = EnsureDB()
    local dataObject = CreateDataObject()
    local IconLib = GetIconLib()

    if not dataObject or not IconLib or type(IconLib.Register) ~= "function" then
        print("[QFX-SA] LibDBIcon-1.0 not available, minimap icon was not created.")
        return
    end

    if not (type(IconLib.IsRegistered) == "function" and IconLib:IsRegistered(ADDON_NAME)) then
        IconLib:Register(ADDON_NAME, dataObject, db)
    else
        IconLib:Refresh(ADDON_NAME, db)
    end

    RefreshButtonReference()
    self:UpdatePosition()
end

function MinimapButton:Show()
    local db = EnsureDB()
    db.hide = false
    local IconLib = GetIconLib()
    if IconLib and type(IconLib.Show) == "function" then
        IconLib:Show(ADDON_NAME)
    end
    self:UpdatePosition()
end

function MinimapButton:Hide()
    local db = EnsureDB()
    db.hide = true
    local IconLib = GetIconLib()
    if IconLib and type(IconLib.Hide) == "function" then
        IconLib:Hide(ADDON_NAME)
    elseif self.button then
        self.button:Hide()
    end
end
