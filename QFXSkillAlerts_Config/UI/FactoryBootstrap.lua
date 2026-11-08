local _, config = ...
local W = rawget(_G, "QFXWidgets") or (config and config.QFXWidgets)
if not W then return end
local root = [[Interface\AddOns\QFXSkillAlerts_Config\Media\]]
-- Fill only unconfigured media; an already loaded shared factory keeps its
-- theme, media and callbacks when this independent configuration is opened.
for _, entry in ipairs({
    {"CircleTexture", "SetCircleTexture", "circle-crisp.blp"},
    {"PillTexture", "SetPillTexture", "pill-crisp.blp"},
    {"SliderThumbTexture", "SetSliderThumbTexture", "slider-thumb-crisp.blp"},
    {"ArrowTexture", "SetArrowTexture", "dropdown-chevron.blp"},
    {"CloseTexture", "SetCloseTexture", "close-x.blp"},
}) do
    if W[entry[1]] == nil then W[entry[2]](W, root .. entry[3]) end
end

local brand = W.Brand or {}
local defaults = {}
for key, filename in pairs({
    logo = "brand-extension-emblem.blp",
    watermark = "brand-watermark-v3.blp",
    contactRoot = "",
}) do
    if brand[key] == nil then defaults[key] = root .. filename end
end
W:SetBrand(defaults)

