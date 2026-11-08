-- Stateful frame stand-ins exercise the real factory and host outside WoW.
local unpack = table.unpack or unpack
local frames, deferred = {}, {}
local hardwareEvent = false
local methods = {}
local function noop() end
local function object(kind, parent)
    local o = { kind = kind, parent = parent, children = {}, regions = {}, scripts = {}, shown = true, enabled = true, width = 200, height = 100, text = "", level = 1 }
    setmetatable(o, { __index = function(_, key)
        if methods[key] then return methods[key] end
        if key == "SetColumns" or key == "TitleText" then return nil end
        if key:match("^%u") then return noop end
    end })
    if parent then
        local list = (kind == "Texture" or kind == "FontString" or kind == "MaskTexture" or kind == "Line") and parent.regions or parent.children
        list[#list + 1] = o
    end
    frames[#frames + 1] = o
    return o
end
function methods:GetObjectType() return self.kind end
function methods:GetChildren() return unpack(self.children) end
function methods:GetRegions() return unpack(self.regions) end
function methods:GetParent() return self.parent end
function methods:SetParent(parent)
    for i, child in ipairs(self.parent.children) do if child == self then table.remove(self.parent.children, i); break end end
    self.parent = parent; parent.children[#parent.children + 1] = self
end
function methods:CreateTexture(_, layer, _, sub)
    local texture = object("Texture", self); texture.layer, texture.subLevel = layer, sub; return texture
end
function methods:CreateMaskTexture() return object("MaskTexture", self) end
function methods:CreateFontString() return object("FontString", self) end
function methods:CreateLine() return object("Line", self) end
function methods:CreateAnimationGroup()
    self.animationGroup = object("AnimationGroup")
    return self.animationGroup
end
function methods:CreateAnimation(kind)
    self.animations = self.animations or {}
    self.animation = object(kind)
    self.animations[#self.animations + 1] = self.animation
    return self.animation
end
function methods:SetTarget(target) self.target = target; return true end
function methods:SetFromAlpha(value) self.fromAlpha = value end
function methods:SetToAlpha(value) self.toAlpha = value end
function methods:SetStartDelay(value) self.startDelay = value end
function methods:SetEndDelay(value) self.endDelay = value end
function methods:SetSmoothing(value) self.smoothing = value end
function methods:Play() self.playing, self.paused = true, false end
function methods:Stop() self.playing, self.paused = false, false end
function methods:Pause() self.playing, self.paused = false, true end
function methods:IsPlaying() return self.playing == true end
function methods:SetRadians(value) self.radians = value end
function methods:SetOrigin(...) self.origin = { ... } end
function methods:SetLooping(value) self.looping = value end
function methods:SetOffset(x, y) self.offset = { x, y } end
function methods:SetScrollChild(child) self.scrollChild = child end
function methods:SetHorizontalScroll(value) self.horizontalScroll = value end
function methods:GetHorizontalScroll() return self.horizontalScroll or 0 end
function methods:SetFlipBookRows(v) self.rows = v end
function methods:SetFlipBookColumns(v) self.columns = v end
function methods:SetFlipBookFrames(v) self.flipFrames = v end
function methods:SetDuration(v) self.duration = v end
function methods:SetAtlas(v)
    self.atlas, self.texture = v, nil
    if v:match("^classicon%-") then self.coords = { 0.125, 0.375, 0.5, 0.75 } end
end
function methods:SetTexCoord(...) self.coords = { ... } end
function methods:SetDesaturated(v) self.desaturated = v end
function methods:EnableMouse(v) self.mouseEnabled = v end
function methods:SetVertexColor(...) self.tint = { ... } end
function methods:SetScript(event, fn) self.scripts[event] = fn end
function methods:GetScript(event) return self.scripts[event] end
function methods:HookScript(event, fn)
    local old = self.scripts[event]
    self.scripts[event] = function(...) if old then old(...) end; fn(...) end
end
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:SetWidth(w) self.width = w end
function methods:SetHeight(h) self.height = h end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:SetAllPoints(other) self.width, self.height = (other or self.parent).width, (other or self.parent).height end
function methods:SetPoint(point, relative, relativePoint, x, y)
    if type(relative) == "number" then x, y, relative, relativePoint = relative, relativePoint, self.parent, point end
    relative, relativePoint, x, y = relative or self.parent, relativePoint or point, x or 0, y or 0
    self.point = { point, relative, relativePoint, x, y }
    self.points = self.points or {}
    for i, old in ipairs(self.points) do if old[1] == point then self.points[i] = self.point; return end end
    self.points[#self.points + 1] = self.point
end
function methods:ClearAllPoints() self.point, self.points = nil, {} end
function methods:GetNumPoints() return #(self.points or {}) end
function methods:GetPoint(i) return unpack((self.points or {})[i or 1] or { "CENTER", UIParent, "CENTER", 0, 0 }) end
function methods:GetFrameLevel() return self.level end
function methods:SetFrameLevel(v) self.level = v end
function methods:SetFrameStrata(v) self.strata = v end
function methods:GetFrameStrata() return self.strata or (self.parent and self.parent:GetFrameStrata()) or "MEDIUM" end
function methods:SetScale(value) self.scale = value end
function methods:GetEffectiveScale() return self:GetScale() * (self.parent and self.parent:GetEffectiveScale() or 1) end
function methods:GetScale() return self.scale or 1 end
function methods:GetLeft() return 0 end
function methods:GetRight() return self.width end
function methods:GetTop() return self.height end
function methods:GetBottom() return 0 end
function methods:SetColorTexture(...) self.color = { ... } end
function methods:SetTextColor(...) self.textColor = { ... } end
function methods:SetTexture(v, _, _, filter) self.texture, self.atlas, self.filterMode = v, nil, filter end
function methods:SetSnapToPixelGrid(value) self.snapToPixelGrid = value end
function methods:GetTexture() return self.texture end
function methods:SetAlpha(v) self.alpha = v end
function methods:GetAlpha() return self.alpha or 1 end
function methods:SetText(v)
    v = tostring(v or ""); if self.text == v then return end
    self.text = v; if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end
end
function methods:GetText() return self.text end
function methods:SetFont(_, size) self.fontSize = size end
function methods:GetStringWidth() return #self.text * (self.fontSize or 12) * 0.45 end
function methods:GetStringHeight() return self.fontSize or 12 end
function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
local function visibleTree(frame, list)
    if frame:IsVisible() then list[#list + 1] = frame end
    for _, child in ipairs(frame.children) do visibleTree(child, list) end
end
function methods:Show()
    if self.shown then return end
    self.shown = true
    local list = {}; visibleTree(self, list)
    for _, frame in ipairs(list) do if frame.scripts.OnShow then frame.scripts.OnShow(frame) end end
end
function methods:Hide()
    if not self.shown then return end
    local list = {}; visibleTree(self, list); self.shown = false
    for _, frame in ipairs(list) do if frame.scripts.OnHide then frame.scripts.OnHide(frame) end end
end
function methods:IsShown() return self.shown end
function methods:SetShown(v) if v then self:Show() else self:Hide() end end
function methods:IsEnabled() return self.enabled end
function methods:SetEnabled(v) self.enabled = v end
function methods:Enable() self.enabled = true; if self.scripts.OnEnable then self.scripts.OnEnable(self) end end
function methods:Disable() self.enabled = false; if self.scripts.OnDisable then self.scripts.OnDisable(self) end end
function methods:HasFocus() return self.focused end
function methods:SetFocus() self.focused = true end
function methods:ClearFocus()
    local focused = self.focused; self.focused = false
    if focused and self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end
end
function methods:IsMouseOver() return false end
function methods:Click()
    if not self.enabled or not self.scripts.OnClick then return end
    local previous = hardwareEvent; hardwareEvent = true
    self.scripts.OnClick(self, "LeftButton")
    hardwareEvent = previous
end
function methods:DoubleClick()
    if not self.enabled or not self.scripts.OnDoubleClick then return end
    local previous = hardwareEvent; hardwareEvent = true
    self.scripts.OnDoubleClick(self, "LeftButton")
    hardwareEvent = previous
end
UIParent = object("Frame"); UIParent:SetSize(1920, 1080)
GameTooltip = object("Frame", UIParent)
function GameTooltip:SetText(text) self.text, self.lineCount = text, 1 end
function GameTooltip:AddLine() self.lineCount = self.lineCount + 1 end
function CreateFrame(kind, name, parent, template)
    assert(not template, "Unexpected Blizzard UI template: " .. tostring(template))
    local f = object(kind, parent or UIParent); if name then _G[name] = f end; return f
end
STANDARD_TEXT_FONT = "Fonts/FRIZQT__.TTF"
UISpecialFrames = {}
C_Timer = { After = function(_, fn) deferred[#deferred + 1] = fn end }
local clipboardText
C_Clipboard = { SetClipboard = function(text) clipboardText = text end }
C_Texture = { GetAtlasInfo = function()
    return { leftTexCoord = .1, rightTexCoord = .6, topTexCoord = .2, bottomTexCoord = .8 }
end }
local combat = false
function InCombatLockdown() return combat end
function GetLocale() return arg[1] or "enUS" end
function GetTime() return 0 end
function GetPhysicalScreenSize() return 1920, 1080 end
function GetScreenWidth() return 1920 end
function GetScreenHeight() return 1080 end
function CreateColor(r,g,b,a) return { r = r, g = g, b = b, a = a } end
