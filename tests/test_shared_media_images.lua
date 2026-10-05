local function Equal(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s (expected %s, got %s)", message, tostring(expected), tostring(actual)), 2)
    end
end

-- Shared-image picker coverage: the picker must list every LSM media type that
-- carries display textures (texture / background / statusbar / border), not
-- only the non-standard "texture" type, and resolve a name across those types
-- in the same order. This is what lets media packs that register artwork as
-- background (for example QFX_SharedMedia PersonalTags) show up in the editor.
local registered = {
    texture = {
        ["Texture Only"] = "Interface\\AddOns\\Pack\\texture_only.tga",
        ["Same Name"] = "Interface\\AddOns\\Pack\\texture_same.tga",
    },
    background = {
        ["QFX Personal Tag Red White"] = "Interface\\AddOns\\QFX_SharedMedia\\Media\\Textures\\PersonalTags\\QFX_PersonalTag_RedWhite.tga",
        ["Same Name"] = "Interface\\AddOns\\Pack\\background_same.tga",
    },
    statusbar = {
        ["QFX Smooth"] = "Interface\\AddOns\\QFX_SharedMedia\\Media\\Textures\\Statusbar\\QFX_Smooth.tga",
    },
    border = {
        ["Border Only"] = "Interface\\AddOns\\Pack\\border_only.tga",
    },
}

local LSM = {
    media = registered,
    List = function(self, mediatype)
        local names = self.media[mediatype]
        if not names then
            return nil
        end
        local list = {}
        for name in pairs(names) do
            list[#list + 1] = name
        end
        table.sort(list)
        return list
    end,
    Fetch = function(self, mediatype, key, noDefault)
        local names = self.media[mediatype]
        return names and names[key] or nil
    end,
}

_G.LibStub = {
    GetLibrary = function(_, name)
        if name == "LibSharedMedia-3.0" then
            return LSM
        end
        return nil
    end,
}

_G.QFXSkillAlertsNS = nil
dofile("QFXSkillAlerts/Core/MediaCatalog.lua")

local NS = _G.QFXSkillAlertsNS
Equal(type(NS.AceOptions.GetSharedMediaTextureList), "function", "texture list bridge must be registered")
Equal(type(NS.AceOptions.FetchSharedMediaTexturePath), "function", "texture fetch bridge must be registered")

local list = NS.AceOptions:GetSharedMediaTextureList()
Equal(list["Texture Only"], "Texture Only", "texture entries must be listed")
Equal(list["Border Only"], "Border Only", "border entries must be listed")
Equal(list["QFX Smooth"], "QFX Smooth", "statusbar entries must be listed")
Equal(list["QFX Personal Tag Red White"], "QFX Personal Tag Red White", "background entries must be listed")
Equal(list["Same Name"], "Same Name", "duplicate names must collapse to one entry")

local count = 0
for _ in pairs(list) do
    count = count + 1
end
Equal(count, 5, "the merged list must contain exactly the five unique names")

Equal(
    NS.AceOptions:FetchSharedMediaTexturePath("QFX Personal Tag Red White"),
    "Interface\\AddOns\\QFX_SharedMedia\\Media\\Textures\\PersonalTags\\QFX_PersonalTag_RedWhite.tga",
    "background artwork must resolve to its registered path"
)
Equal(
    NS.AceOptions:FetchSharedMediaTexturePath("QFX Smooth"),
    "Interface\\AddOns\\QFX_SharedMedia\\Media\\Textures\\Statusbar\\QFX_Smooth.tga",
    "statusbar artwork must resolve to its registered path"
)
Equal(
    NS.AceOptions:FetchSharedMediaTexturePath("Same Name"),
    "Interface\\AddOns\\Pack\\texture_same.tga",
    "a name registered by several types must prefer the texture library"
)
Equal(NS.AceOptions:FetchSharedMediaTexturePath("Missing"), "", "unknown names must resolve to an empty path")

print("shared media image tests passed")
