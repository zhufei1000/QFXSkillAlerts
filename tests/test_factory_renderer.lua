-- Build the complete original editor through its embedded factory. Reject
-- any native control template and exercise selection and scrolling contracts.
local projectRoot = arg[2] and arg[2] ~= "" and (arg[2]:gsub("[/\\]+$", "") .. "/") or ""
assert(loadfile(projectRoot .. "tests/frame_fixture.lua"))()
local managerRoot = arg[5] and (arg[5]:gsub("[/\\]+$", "") .. "/")
unpack = table.unpack or unpack
tinsert, wipe = table.insert, function(t) for key in pairs(t) do t[key] = nil end return t end
strtrim = function(s) return tostring(s):match("^%s*(.-)%s*$") end
local nativeCreate = CreateFrame
local frames = {}
local withManager = arg[3] == "manager"
local client = arg[4] or "retail"
CreateFrame = function(kind, name, parent, template)
    local frame = nativeCreate(kind, name, parent, template)
    frame._name = name
    frame.GetName = function(self) return self._name end
    frame.IsObjectType = function(self, value) return self.kind == value end
    frame.GetMinMaxValues = function(self) return self.low or 0, self.high or 1 end
    frame.SetMinMaxValues = function(self, low, high) self.low, self.high = low, high end
    frame.GetValue = function(self) return self.value or 0 end
    frame.SetValue = function(self, value)
        value = math.min(self.high or value, math.max(self.low or value, value))
        if self.value == value then return end
        self.value = value
        if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, value) end
    end
    frame.SetOrientation = function(self, value) self.orientation = value end
    frame.GetOrientation = function(self) return self.orientation or "HORIZONTAL" end
    frame.SetVerticalScroll = function(self, value) self.offset = value end
    frame.GetVerticalScroll = function(self) return self.offset or 0 end
    frame.GetNumLines = function(self) local _, count = (self:GetText() or ""):gsub("\n", "\n"); return count+1 end
    frame.SetFrameStrata = function(self, value) self.strata = value end
    frame.GetFrameStrata = function(self)
        return self.strata or (self.parent and self.parent.GetFrameStrata and self.parent:GetFrameStrata()) or "MEDIUM"
    end
    frame.GetHighestFrameLevel = function(self, allChildren)
        local highest = self:GetFrameLevel()
        for _, child in ipairs(self.children) do
            highest = math.max(highest, allChildren and child:GetHighestFrameLevel(true) or child:GetFrameLevel())
        end
        return highest
    end
    frame.GetChecked = function(self) return self.checked end
    frame.SetChecked = function(self, value) self.checked = value and true or false end
    frames[#frames+1] = frame
    return frame
end
function UnitClass() return "Mage", "MAGE", 8 end
function UnitName() return "Tester" end
function GetSpecialization() return 1 end
function GetSpecializationInfo() return 62, "Arcane", "", 1 end
function GetNumSpecializations() return 3 end
function GetNumClasses() return 13 end
function GetClassInfo(id) return "Class"..id, "CLASS"..id, id end
C_CreatureInfo = {GetClassInfo = function(id) return {className = "Class"..id, classFile = "CLASS"..id, classID = id} end}
C_SpecializationInfo = {GetSpecializationInfoForClassID = function(id, index) return id*10+index, "Spec"..index end}
GetSpecializationInfoForClassID = function(id, index) return id*10+index, "Spec"..index end
C_SpecializationInfo.GetNumSpecializationsForClassID = function() return 3 end
C_Spell = {GetSpellInfo = function(id) return {name = "Spell"..id, iconID = 1, spellID = id} end}
C_VoiceChat = {GetTtsVoices = function() return {} end}
RAID_CLASS_COLORS = setmetatable({}, {__index = function() return {r=1,g=1,b=1} end})
GameTooltip_Hide = function() GameTooltip:Hide() end
GetBuildInfo = function() return client == "forever" and "1.60.1" or "12.1.5", "review", "", client == "forever" and 16001 or 120105 end
if client == "forever" then
    GetSpecialization, GetSpecializationInfo = nil, nil
    C_SpecializationInfo.GetSpecialization = function() return 1 end
    C_SpecializationInfo.GetSpecializationInfo = function() return 1482, "Mage" end
    C_SpecializationInfo.GetNumSpecializationsForClassID = function() return 1 end
    GetSpecializationInfoForClassID = function(id) return id == 8 and 1482 or 1400+id, "Class"..id end
end
QFXSkillAlertsDB = {uiLanguage = arg[1] or "enUS"}
QFXSkillAlertsNS = {API = {GetModes = function() return "tts", "sound" end}}
local NS = QFXSkillAlertsNS
local function sourcePath(path) return projectRoot .. path end
local function addon(path) return assert(loadfile(sourcePath(path)))() end
assert(not NS.UI or not NS.UI.Renderer, "Configuration remains lazy before its TOC is loaded")
addon("QFXSkillAlerts/Localization.lua")
addon("QFXSkillAlerts/Core/Constants.lua")
addon("QFXSkillAlerts/Core/Compat.lua")
addon("QFXSkillAlerts/Core/Utils.lua")
addon("QFXSkillAlerts/Core/MediaCatalog.lua")
addon("QFXSkillAlerts/Core/Scope.lua")
addon("QFXSkillAlerts/Core/CollectionStore.lua")
addon("QFXSkillAlerts/Core/VisualGroups.lua")
local AM = {AdapterUtils = {IsInstalled = function(name) return name == "QFXSkillAlerts" end,
    Text = function(en, cn, tw) return GetLocale() == "zhCN" and cn or GetLocale() == "zhTW" and tw or en end,
    Register = function(_, spec) assert(not spec.embeddedSettings); AM_SPEC = spec end}, RegisterAddon = function() end}
local managerLoads = 0
if withManager then
    QFXAddonManager = AM
    assert(loadfile(assert(managerRoot, "Pass the manager source root for the platform scenario") .. "QFXAddonManager_Config/Libs/QFXWidgets.lua"))("QFXAddonManager_Config", AM)
    QFXWidgets:SetCircleTexture([[Interface\AddOns\QFXAddonManager\Media\circle-crisp.blp]])
    QFXWidgets:SetBrand({logo = "platform-logo"})
    AM.GetWidgets = function() return QFXWidgets end
    AM.EnsureConfigLoaded = function() managerLoads = managerLoads + 1; error("Renderer must not load manager config") end
    AM.EnsureAdaptersLoaded = function() managerLoads = managerLoads + 1; error("Renderer must not load manager adapters") end
    assert(loadfile(managerRoot .. "QFXAddonManager_Config/Integration/Adapters/QFXSkillAlerts.lua"))("QFXAddonManager_Adapters", AM)
    assert(not AM.SkillAlertsUI and not AM_SPEC.embeddedSettings and AM_SPEC.nativeOptions)
end
local previousFactory = QFXWidgets
local previousCircle = previousFactory and previousFactory.CircleTexture
local previousBrand = previousFactory and previousFactory.Brand.logo
local configNamespace = {}
local toc = assert(io.open(sourcePath("QFXSkillAlerts_Config/QFXSkillAlerts_Config.toc"), "r"))
for line in toc:lines() do
    if line:match("^Core\\") or line:match("^UI\\") or line == "Libs\\QFXWidgets.lua" then
        if line:match("%.lua$") then
            assert(loadfile(sourcePath("QFXSkillAlerts_Config/"..line:gsub("\\", "/"))))("QFXSkillAlerts_Config", configNamespace)
        end
    end
end
toc:close()
-- Verify contact routing and live TOC version reads in both renderers.
local reportedVersion = "1.0.240"
C_AddOns = C_AddOns or {}
C_AddOns.GetAddOnMetadata = function(name, field)
    assert(name == "QFXSkillAlerts" and field == "Version")
    return reportedVersion
end
local contactOwner = NS.UI.MainFrame
local contactFrame = assert(contactOwner:EnsureFrame())
local complete, missing = QFXWidgets:ValidateAddonWindow(contactFrame)
assert(complete, "Incomplete factory window: "..table.concat(missing, ", "))
assert(contactOwner.summary:GetParent() == contactOwner.chrome.content
    and contactOwner.addBtn:GetParent() == contactOwner.chrome.content,
    "Business controls must stay inside the factory content region")
assert(contactOwner.authorLabel:GetText() == NS.L("AUTHOR_LINE"))
assert(contactOwner.versionLabel:GetText() == NS.L("VERSION_LINE", reportedVersion))
reportedVersion = "9.9.9"
contactOwner.refreshFooter()
assert(contactOwner.versionLabel:GetText() == NS.L("VERSION_LINE", reportedVersion), "Version must come from metadata")
reportedVersion = "1.0.240"
contactOwner.refreshFooter()
local contactValues = {
    qq = "1049855225", discord = "https://discord.gg/HVJ2y4v7k4",
    github = "https://github.com/zhufei1000/QFXSkillAlerts",
}
for key, value in pairs(contactValues) do
    local button = contactOwner.contactButtons[key]
    assert(button:GetWidth() == 20 and button:GetHeight() == 20, "Contacts must use compact square icons")
    assert(button._icon:GetTexture() == [[Interface\AddOns\QFXSkillAlerts_Config\Media\contact-]] .. key .. ".blp")
    assert(button._qfx == "iconButton", "Contacts use the embedded factory icon button")
    button:GetScript("OnEnter")(button)
    assert(GameTooltip:GetText() == NS.L("CONTACT_" .. key:upper()), "Contact tooltip must use the active language")
    button:GetScript("OnLeave")(button)
    assert(not GameTooltip:IsShown())
    button:Click()
    local dialog = assert(contactOwner.chrome.copyDialog)
    assert(dialog.editBox:GetText() == value, "Factory copy dialog must use the consumer's contact value")
    button:Click()
    assert(not dialog:IsShown(), "Repeated contact clicks must replace the previous copy dialog")
    contactOwner.chrome:CloseCopyDialog()
end
contactOwner:OpenExportDialog("Export", "Original export data")
assert(contactOwner.importExportDialog.desc:GetText() == NS.L("EXPORT_DESC"), "Export guidance must reset after copying contacts")
contactOwner.importExportDialog:Hide()
contactFrame:Show()
contactOwner.contactButtons.qq:Click()
local hiddenCopy = contactOwner.chrome.copyDialog
contactFrame:Hide()
assert(not hiddenCopy:IsShown(), "Closing the host must close its copy dialog")
for _, locale in ipairs({"enUS", "zhCN", "zhTW"}) do
    NS.SetLanguageMode(locale)
    contactOwner.refreshFooter()
    assert(contactOwner.chrome.locale == locale and contactOwner.authorLabel:GetText() == NS.L("AUTHOR_LINE"))
    assert(contactOwner.contactButtons.qq.contact.title == NS.L("CONTACT_QQ"))
    assert(contactOwner.chrome:Validate())
end
NS.SetLanguageMode(arg[1] or "enUS")
contactOwner.refreshFooter()
assert(managerLoads == 0, "Independent rendering must not call manager load gates")
assert(not previousFactory or previousFactory == QFXWidgets, "Embedded factory retains an existing singleton")
if previousFactory then
    assert(QFXWidgets.CircleTexture == previousCircle and QFXWidgets.Brand.logo == previousBrand,
        "Independent config preserves an existing provider's media and branding")
end
assert(NS.UI.Renderer and NS.UI.Renderer.Widgets == QFXWidgets)
QFXWidgets:SetMotionEnabled(false)
assert(NS.UI.Renderer and NS.UI.Renderer.Widgets == QFXWidgets)
assert(type(NS.UI.Renderer.StyleMenuRow) == "function" and type(NS.UI.Renderer.SetRowDragging) == "function"
    and type(NS.UI.Renderer.RowAccent) == "function" and type(NS.UI.Renderer.Divider) == "function",
    "Independent renderer exposes the menu/drag style helpers")
local probeRow = QFXWidgets:DetachedControl(UIParent, "button")
assert(pcall(function() NS.UI.Renderer.StyleMenuRow(probeRow, 1) end),
    "Menu row styling through the bridge must not error")
NS.UI.Renderer.SetRowDragging(probeRow, true)
NS.UI.Renderer.SetRowDragging(probeRow, false)
local W = NS.UI.Widgets
assert(type(QFXWidgets.RowCheck) == "function", "Factory must expose the shared row checkbox")
assert(type(QFXWidgets.StyleMenuRow) == "function", "Factory must expose the shared menu row style")
local rowBox, rowMark = QFXWidgets.RowCheck(UIParent, 16)
assert(rowBox and rowMark and rowBox._mark == rowMark and rowBox._bg and rowBox._brd,
    "Row checkbox must mirror the CheckGrid box+fill")
local check = W:CreateCheckButton(UIParent, "Enabled")
local changes = 0
check:SetScript("OnClick", function() changes = changes + 1 end)
check:SetChecked(true); check:Click(); assert(not check:GetChecked() and changes == 1)
local dropdown = W:CreateDropdown(UIParent, "TestPicker", 180)
assert(dropdown:GetNumPoints() == 0, "Legacy-layout dropdowns must not keep a factory RIGHT anchor")
dropdown:SetPoint("LEFT", UIParent, "LEFT", 10, 0)
assert(dropdown:GetNumPoints() == 1 and dropdown:GetPoint() == "LEFT")
W:SetDropdownItems(dropdown, {{value=1,text="One",marked=true},{value=2,text="Two",disabled=true}})
dropdown.qfxsaToggleClear = true
dropdown:qfxsaPick(1); assert(W:GetDropdownValue(dropdown)==1)
local checkTexture = "|TInterface\\Buttons\\UI-CheckBox-Check:16:16:0:0|t"
assert(dropdown:GetText() == "One  " .. checkTexture, "The selected label must use the built-in check texture")
dropdown:qfxsaPick(1); assert(W:GetDropdownValue(dropdown)==nil)
assert(dropdown:GetText() == "", "Clearing selection must clear the mark")
dropdown._openMenu()
assert(dropdown._menu:IsShown() and dropdown._menu:GetHeight() == 60)
assert(not dropdown._editorSearch:IsShown(), "A short list does not need a search row")
local markedRow
for _, frame in ipairs(frames) do
    if frame.hit and frame.hit:GetText() == "One  " .. checkTexture then markedRow = frame; break end
end
assert(markedRow and markedRow:GetPoint(2) == "TOPRIGHT" and markedRow:GetParent():GetPoint(2) == "TOPRIGHT",
    "Marked menu rows must span the full list width")
dropdown:Hide(); assert(not dropdown._menu:IsShown())
W:SetDropdownSearchable(dropdown, true)
dropdown:Show(); dropdown._openMenu()
assert(dropdown._editorSearch:IsShown())
dropdown._editorSearch:SetText("one")
assert(markedRow.hit:GetText() == "One  " .. checkTexture)
dropdown._editorSearch:SetText("UI-CheckBox-Check")
assert(markedRow.hit:GetText() == NS.L("SEARCH_NO_RESULTS"), "The texture path must not be searchable")
dropdown:Hide()
local multi = W:CreateMultiSelectDropdown(UIParent, "TestMultiPicker", 180)
multi.qfxsaExclusiveValue = 0
W:SetDropdownItems(multi, {{value=0,text="All"},{value=1,text="One"},{value=2,text="Two"}})
multi:qfxsaPick(0); multi:qfxsaPick(1)
assert(not W:GetMultiDropdownValues(multi)[0] and W:GetMultiDropdownValues(multi)[1])
multi:qfxsaPick(0); assert(not W:GetMultiDropdownValues(multi)[1])
local box = W:CreateEditBox(UIParent, 180, 20)
box:SetText("Preserved input"); QFXWidgets:Refresh(); assert(box:GetText()=="Preserved input")
local host, content, viewport, slider = W:CreateScrollableContent(UIParent, {bottomPadding=0})
host:SetContentHeight(1400); slider:SetValue(200)
assert(viewport:GetVerticalScroll()==200 and host.page:GetOffset()==200)
host.page:ScrollTo(300); assert(slider:GetValue()==300)
local main = assert(NS.UI.MainFrame:EnsureFrame())
assert(main:GetWidth()==1040 and main:GetHeight()==700)
local editor = assert(NS.UI.EditorFrame:EnsureFrame())
assert(editor.widgets and editor.contentHost and editor.contentHost.page)
-- Real legacy builders add their own anchors without clearing first. Click
-- each live dropdown after the containing editor has been raised above 300.
NS.AceOptions:GetState().entryType = "cooldown"
NS.UI.EditorFrame:PushToWidgets()
if client == "forever" then
    assert(NS.Core.Compat:IsForever(), "The Forever scenario must load the actual compatibility layer")
    assert(#NS.OptionsState:GetSpecOptionList(NS.AceOptions, 8) == 2,
        "Forever must expose all-specs plus its real class specialization")
    NS.AceOptions:GetState().checkTalent = true
    NS.AceOptions:GetState().loadTalentEnabled = true
    editor.qfxsaAdvancedExpanded = true
    NS.UI.EditorFrame:PushToWidgets()
    for _, key in ipairs({"advancedToggle", "checkTalent", "talentId", "loadTalentEnabled", "loadTalentId"}) do
        assert(editor.widgets[key]:IsShown(), "Forever must expose the talent control: "..key)
    end
end
editor:Show(); editor:SetFrameLevel(850)
local objectType = assert(editor.widgets.objectTypeDrop)
objectType:Click()
assert(objectType._menu:GetWidth() == 170 and objectType._menu:GetHeight() == 104,
    "The four object types need a wider popup that fits exactly four rows")
objectType._menu:Hide()
editor.widgets.sourceDrop:GetParent():SetFrameLevel(1100)
-- Exercise mode changes without forcing the execution picker enabled: only
-- numeric conditions are disabled for API readiness/cooldown edge alerts.
for _, mode in ipairs({"ready", "cooldown", "fixed", "ready"}) do
    editor.widgets.cdModeDrop:qfxsaPick(mode)
    assert(NS.AceOptions:GetState().cdMode == mode)
    local picker = editor.widgets.conditionActionsDrop
    assert(picker.qfxsaDisabled == false, mode.." must allow selecting alert actions")
    assert(editor.widgets.conditionOp.qfxsaDisabled == (mode ~= "fixed"),
        mode.." must preserve the numeric-condition restriction")
    picker:Click()
    assert(picker._menu:IsShown(), mode.." execution menu must open after changing CD mode")
    for _, action in ipairs({"voice", "image", "text"}) do
        local state = NS.AceOptions:GetState()
        local field = action.."Enabled"
        local before = state[field] == true
        picker:qfxsaPick(action)
        assert(NS.AceOptions:GetState()[field] == not before, mode.." must update "..action)
        picker:qfxsaPick(action)
        assert(NS.AceOptions:GetState()[field] == before, mode.." must preserve action selections")
    end
    picker._menu:Hide()
end
local strataRank = {BACKGROUND=1, LOW=2, MEDIUM=3, HIGH=4, DIALOG=5, FULLSCREEN_DIALOG=6, FULLSCREEN=7, TOOLTIP=8}
local lastMenu
for _, key in ipairs({"sourceDrop", "scopeRaceDrop", "scopeClassDrop", "scopeSpecDrop", "conditionActionsDrop"}) do
    local picker = assert(editor.widgets[key], key)
    assert(picker:GetNumPoints() == 1, key.." has conflicting layout anchors")
    W:SetDropdownEnabled(picker, true)
    picker:Show(); picker:Click()
    assert(picker._menu:IsShown(), key.." must open via its actual click handler")
    assert(picker._menu:GetFrameStrata() == "TOOLTIP" and picker._editorCatcher:GetFrameStrata() == "TOOLTIP",
        key.." menu must use TOOLTIP so no host window layer can cover it")
    assert(strataRank[picker._menu:GetFrameStrata()] > strataRank[editor:GetFrameStrata()],
        key.." menu strata must outrank the toplevel editor, whatever its frame level is")
    assert(picker._menu:GetFrameLevel() > editor:GetHighestFrameLevel(true), key.." must appear above its owner")
    assert(picker._editorCatcher:GetFrameLevel() < picker._menu:GetFrameLevel())
    if lastMenu then assert(not lastMenu:IsShown(), "Only one picker may own the outside-click catcher") end
    lastMenu = picker._menu
end
editor:SetFrameLevel(1300)
editor.widgets.conditionActionsDrop._editorRender()
assert(lastMenu:GetFrameLevel() > editor:GetHighestFrameLevel(true), "Multi-select refresh must keep the menu above a raised editor")
editor.widgets.conditionActionsDrop._editorCatcher.scripts.OnMouseDown()
assert(not lastMenu:IsShown())
for _, name in ipairs({"tabCooldown", "tabCast", "tabBloodlust", "tabSettings", "tabVoice", "tabImage", "tabText"}) do
    assert(editor.widgets[name], "Missing editor control: "..name)
end
for _, entryType in ipairs({"cooldown", "cast", "aura", "event", "bloodlust", "custom"}) do
    NS.AceOptions:GetState().entryType = entryType
    NS.UI.EditorFrame:PushToWidgets()
    NS.UI.EditorFrame:PullFromWidgets()
end
local export = NS.UI.MainFrame:EnsureImportExportDialog()
export.editBox:SetText("Export data\nSecond line")
QFXWidgets:Refresh(); assert(export.editBox:GetText() == "Export data\nSecond line")
NS.UI.MainFrame:EnsureCollectionDialog()
if NS.UI.CDMVoiceEditorBuilder then
    local cdm = NS.UI.CDMVoiceEditorBuilder:Ensure()
    local cdmRow = NS.UI.CDMVoiceEditorRows:Acquire(cdm, 1)
    assert(cdmRow.eventDropdown and cdmRow.voiceDropdown and cdmRow.testButton and cdmRow.saveButton and cdmRow.applyButton)
end
NS.UI.VisualGroupEditor:EnsurePanel(NS.UI.EditorFrame)
local accepted, cancelled = 0, 0
local data = {key = "test"}
StaticPopupDialogs = {TEST = {button1 = "Delete", button2 = "Cancel",
    OnAccept = function(_, value) assert(value == data); accepted = accepted+1 end,
    OnCancel = function() cancelled = cancelled+1 end}}
local confirm = NS.UI.Renderer.ShowConfirmation("TEST", "Delete test?", data)
confirm._cancel:Click(); assert(cancelled == 1 and accepted == 0)
confirm = NS.UI.Renderer.ShowConfirmation("TEST", "Delete test?", data)
assert(confirm:GetFrameLevel() == 500)
confirm._accept:Click(); assert(accepted == 1)
local row = NS.UI.SavedListRowFactory:EnsureRow(NS.UI.MainFrame.savedList, 1)
assert(row.main and row.icon and row.bg and row.dropLine and row.scripts.OnDragStart and row.scripts.OnDragStop)
if withManager then assert(AM_SPEC.openOptions and not AM_SPEC.embeddedSettings) end
local version, singleton = QFXWidgets.VERSION, QFXWidgets
assert(loadfile(sourcePath("QFXSkillAlerts_Config/Libs/QFXWidgets.lua")))("other", {})
assert(QFXWidgets==singleton and QFXWidgets.VERSION==version)
local oldDropdownBuilder = QFXWidgets.EditorDropdown
QFXWidgets.DETACHED_CONTROLS_REVISION = 7
assert(loadfile(sourcePath("QFXSkillAlerts_Config/Libs/QFXWidgets.lua")))("other", {})
assert(QFXWidgets == singleton and QFXWidgets.VERSION == version and QFXWidgets.DETACHED_CONTROLS_REVISION == 8)
assert(QFXWidgets.EditorDropdown ~= oldDropdownBuilder, "An earlier winning singleton must receive the popup fix")
local fieldCount = 0; for _ in pairs(editor.widgets) do fieldCount = fieldCount + 1 end
assert(fieldCount == 223, "Preserve the complete editor field contract, got "..fieldCount)
print("PASS: "..GetLocale().." full original builders and "..fieldCount.." editor fields, factory-only controls, dropdown anchors/clicks/raised-owner layers/single active catcher, pickers, checkboxes, scrolling, dialogs, drag rows, singleton upgrade and independent window ("..client..", "..(withManager and "platform" or "standalone")..")")
