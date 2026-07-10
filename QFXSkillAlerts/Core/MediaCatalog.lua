local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.AceOptions = NS.AceOptions or {}
NS.MediaCatalog = NS.MediaCatalog or {}

local LibStubGlobal = rawget(_G, "LibStub")
local C = NS.Constants or {}
local Utils = NS.Utils or {}

local SOUND_ROOT = C.SOUND_ROOT or "Interface\\AddOns\\QFXSkillAlerts\\Media\\Sounds\\"
local DEFAULT_BUILTIN_SOUND_FILE = C.DEFAULT_BUILTIN_SOUND_FILE or "AirHorn.ogg"
local MODE_TTS = C.MODE_TTS or "tts"
local MODE_SOUND = C.MODE_SOUND or "sound"

local function TrimText(value)
    if Utils.TrimText then
        return Utils.TrimText(value)
    end
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function CanonicalSoundPath(value)
    if Utils.CanonicalPath then
        return Utils.CanonicalPath(value)
    end
    local path = TrimText(value)
    if path == "" then
        return ""
    end
    return (path:gsub("/", "\\"))
end

local function StripAudioExtension(fileName)
    if Utils.StripAudioExtension then
        return Utils.StripAudioExtension(fileName)
    end
    local value = tostring(fileName or "")
    return (value:gsub("%.[Oo][Gg][Gg]$", ""):gsub("%.[Mm][Pp]3$", ""))
end

local function GetFileNameFromPath(value)
    if Utils.GetFileNameFromPath then
        return Utils.GetFileNameFromPath(value)
    end
    local path = tostring(value or ""):gsub("/", "\\")
    return path:match("([^\\]+)$") or path
end

local BUILTIN_SOUND_FILES = {
    "AcousticGuitar.ogg",
    "Adds.ogg",
    "aggro.ogg",
    "AirHorn.ogg",
    "Applause.ogg",
    "Arrow_Swoosh.ogg",
    "bam.ogg",
    "BananaPeelSlip.ogg",
    "BatmanPunch.ogg",
    "bear_polar.ogg",
    "bigkiss.ogg",
    "BikeHorn.ogg",
    "BITE.ogg",
    "Blast.ogg",
    "Bleat.ogg",
    "Boss.ogg",
    "BoxingArenaSound.ogg",
    "Brass.mp3",
    "burp4.ogg",
    "CartoonVoiceBaritone.ogg",
    "CartoonWalking.ogg",
    "cat2.ogg",
    "CatMeow2.ogg",
    "chant2.ogg",
    "chant4.ogg",
    "ChickenAlarm.ogg",
    "chimes.ogg",
    "Circle.ogg",
    "cookie.ogg",
    "CowMooing.ogg",
    "Cross.ogg",
    "Diamond.ogg",
    "DontRelease.ogg",
    "DoubleWhoosh.ogg",
    "Drums.ogg",
    "Empowered.ogg",
    "ErrorBeep.ogg",
    "ESPARK1.ogg",
    "Fireball.ogg",
    "Focus.ogg",
    "Gasp.ogg",
    "Glass.mp3",
    "GoatBleating.ogg",
    "heartbeat.ogg",
    "HeartbeatSingle.ogg",
    "hic3.ogg",
    "huh_1.ogg",
    "hurricane.ogg",
    "hyena.ogg",
    "Idiot.ogg",
    "kaching.ogg",
    "KittenMeow.ogg",
    "Left.ogg",
    "moan.ogg",
    "Moon.ogg",
    "Next.ogg",
    "OhNo.ogg",
    "panther1.ogg",
    "phone.ogg",
    "Portal.ogg",
    "Protected.ogg",
    "PUNCH.ogg",
    "rainroof.ogg",
    "Release.ogg",
    "Right.ogg",
    "RingingPhone.ogg",
    "RoaringLion.ogg",
    "RobotBlip.ogg",
    "rocket.ogg",
    "RoosterChickenCalls.ogg",
    "RunAway.ogg",
    "SharpPunch.ogg",
    "SheepBleat.ogg",
    "shipswhistle.ogg",
    "shot.ogg",
    "Shotgun.ogg",
    "Skull.ogg",
    "snakeatt.ogg",
    "sneeze.ogg",
    "sonar.ogg",
    "splash.ogg",
    "Spread.ogg",
    "Square.ogg",
    "Squeakypig.ogg",
    "SqueakyToyShort.ogg",
    "SquishFart.ogg",
    "Stack.ogg",
    "Star.ogg",
    "Switch.ogg",
    "swordecho.ogg",
    "SynthChord.ogg",
    "TadaFanfare.ogg",
    "Taunt.ogg",
    "TempleBellHuge.ogg",
    "throwknife.ogg",
    "thunder.ogg",
    "Torch.ogg",
    "Triangle.ogg",
    "WarningSiren.ogg",
    "WaterDrop.ogg",
    "wickedmalelaugh1.ogg",
    "wilhelm.ogg",
    "wlaugh.ogg",
    "wolf5.ogg",
    "Xylophone.ogg",
    "yeehaw.ogg",
}

local BUILTIN_SOUND_LIST = nil
local BUILTIN_SOUND_ALIASES = nil

local Catalog = NS.MediaCatalog

function Catalog:GetBuiltinSoundFiles()
    return BUILTIN_SOUND_FILES
end

function Catalog:EnsureBuiltinSoundTables()
    if BUILTIN_SOUND_LIST and BUILTIN_SOUND_ALIASES then
        return
    end

    BUILTIN_SOUND_LIST = {}
    BUILTIN_SOUND_ALIASES = {}

    for _, fileName in ipairs(BUILTIN_SOUND_FILES) do
        local fullPath = SOUND_ROOT .. fileName
        local displayName = StripAudioExtension(fileName)
        BUILTIN_SOUND_LIST[fullPath] = displayName

        local noExtPath = SOUND_ROOT .. StripAudioExtension(fileName)
        local relativePath = "Media\\Sounds\\" .. fileName
        local relativeNoExt = "Media\\Sounds\\" .. StripAudioExtension(fileName)

        BUILTIN_SOUND_ALIASES[string.lower(fullPath)] = fullPath
        BUILTIN_SOUND_ALIASES[string.lower(noExtPath)] = fullPath
        BUILTIN_SOUND_ALIASES[string.lower(relativePath)] = fullPath
        BUILTIN_SOUND_ALIASES[string.lower(relativeNoExt)] = fullPath
        BUILTIN_SOUND_ALIASES[string.lower(fileName)] = fullPath
        BUILTIN_SOUND_ALIASES[string.lower(StripAudioExtension(fileName))] = fullPath
    end
end

function Catalog:GetBuiltinSoundList()
    self:EnsureBuiltinSoundTables()
    return BUILTIN_SOUND_LIST
end

function Catalog:GetDefaultBuiltinSoundPath()
    self:EnsureBuiltinSoundTables()
    local defaultPath = SOUND_ROOT .. DEFAULT_BUILTIN_SOUND_FILE
    if BUILTIN_SOUND_LIST[defaultPath] then
        return defaultPath
    end
    local first = BUILTIN_SOUND_FILES[1]
    return first and (SOUND_ROOT .. first) or ""
end

function Catalog:NormalizeSoundPath(value)
    local path = CanonicalSoundPath(value)
    if path == "" then
        return ""
    end

    self:EnsureBuiltinSoundTables()
    return BUILTIN_SOUND_ALIASES[string.lower(path)] or path
end

function Catalog:IsBuiltinSoundPath(value)
    local path = self:NormalizeSoundPath(value)
    if path == "" then
        return false
    end

    self:EnsureBuiltinSoundTables()
    return BUILTIN_SOUND_LIST[path] ~= nil
end

function Catalog:GetBuiltinSoundDisplayName(value)
    local path = self:NormalizeSoundPath(value)
    if path == "" then
        return ""
    end

    self:EnsureBuiltinSoundTables()
    return BUILTIN_SOUND_LIST[path] or StripAudioExtension(GetFileNameFromPath(path))
end

function Catalog:GetSharedMediaLibrary()
    if type(LibStubGlobal) == "table" and type(LibStubGlobal.GetLibrary) == "function" then
        return LibStubGlobal:GetLibrary("LibSharedMedia-3.0", true)
    end
    return nil
end

function Catalog:GetSharedMediaSoundList()
    local values = {}
    local LSM = self:GetSharedMediaLibrary()
    if not LSM or type(LSM.List) ~= "function" then
        return values
    end

    local ok, names = pcall(LSM.List, LSM, "sound")
    if not ok or type(names) ~= "table" then
        return values
    end

    for _, name in ipairs(names) do
        name = TrimText(name)
        if name ~= "" then
            values[name] = name
        end
    end
    return values
end

function Catalog:HasSharedMediaSounds()
    return next(self:GetSharedMediaSoundList()) ~= nil
end

function Catalog:FetchSharedMediaSoundPath(name)
    name = TrimText(name)
    if name == "" then
        return ""
    end

    local LSM = self:GetSharedMediaLibrary()
    if not LSM or type(LSM.Fetch) ~= "function" then
        return ""
    end

    local ok, path = pcall(LSM.Fetch, LSM, "sound", name, true)
    if ok then
        return CanonicalSoundPath(path)
    end
    return ""
end

function Catalog:FindSharedMediaSoundNameByPath(path)
    path = self:NormalizeSoundPath(path)
    if path == "" then
        return ""
    end

    local target = string.lower(CanonicalSoundPath(path))
    for name in pairs(self:GetSharedMediaSoundList()) do
        local mediaPath = self:FetchSharedMediaSoundPath(name)
        if mediaPath ~= "" and string.lower(CanonicalSoundPath(mediaPath)) == target then
            return name
        end
    end
    return ""
end

function Catalog:ResolveSharedMediaSoundPath(name, fallbackPath)
    local path = self:FetchSharedMediaSoundPath(name)
    if path ~= "" then
        return self:NormalizeSoundPath(path)
    end
    return self:NormalizeSoundPath(fallbackPath or "")
end

function Catalog:ResolveSoundSourceFields(entry, modeTts, modeSound)
    entry = type(entry) == "table" and entry or {}
    modeTts = tostring(modeTts or MODE_TTS)
    modeSound = tostring(modeSound or MODE_SOUND)

    local notifyMode = tostring(entry.notifyMode or modeSound)
    if notifyMode ~= modeTts then
        notifyMode = modeSound
    end

    local soundSource = tostring(entry.soundSource or ""):lower()
    local soundPath = self:NormalizeSoundPath(entry.soundPath or "")

    -- 1.0.186: be defensive with older/imported records.  Some save paths
    -- keep the visible selection in builtinSoundPath/customSoundPath while
    -- soundPath is empty.  Runtime playback must still resolve to a real file.
    if soundPath == "" and soundSource == "builtin" then
        soundPath = self:NormalizeSoundPath(entry.builtinSoundPath or "")
    end
    if soundPath == "" and soundSource == "custom" then
        soundPath = self:NormalizeSoundPath(entry.customSoundPath or "")
    end
    if soundPath == "" and soundSource == "custom" and type(entry.customSoundPaths) == "table" then
        for i = 1, 5 do
            local candidate = self:NormalizeSoundPath(entry.customSoundPaths[i] or "")
            if candidate ~= "" then
                soundPath = candidate
                break
            end
        end
    end
    if soundPath == "" and soundSource == "" then
        soundPath = self:NormalizeSoundPath(entry.builtinSoundPath or entry.customSoundPath or "")
    end

    local sharedMediaSound = TrimText(entry.sharedMediaSound or entry.sharedMediaName or "")
    local sharedPath = ""

    if notifyMode == modeTts or soundSource == "tts" then
        return {
            notifyMode = modeTts,
            soundSource = "tts",
            soundPath = "",
            builtinSoundPath = self:GetDefaultBuiltinSoundPath(),
            customSoundPath = "",
            sharedMediaSound = "",
            useCustomSound = false,
            useSharedMediaSound = false,
        }
    end

    if sharedMediaSound ~= "" then
        sharedPath = self:FetchSharedMediaSoundPath(sharedMediaSound)
        if sharedPath ~= "" then
            sharedPath = self:NormalizeSoundPath(sharedPath)
        end
    end

    if sharedMediaSound == "" and soundPath ~= "" then
        local foundName = self:FindSharedMediaSoundNameByPath(soundPath)
        if foundName ~= "" then
            local foundPath = self:FetchSharedMediaSoundPath(foundName)
            if foundPath ~= "" then
                sharedMediaSound = foundName
                sharedPath = self:NormalizeSoundPath(foundPath)
            end
        end
    end

    if (soundSource == "sharedmedia" or soundSource == "") and sharedMediaSound ~= "" and sharedPath ~= "" then
        return {
            notifyMode = modeSound,
            soundSource = "sharedmedia",
            soundPath = sharedPath,
            builtinSoundPath = self:GetDefaultBuiltinSoundPath(),
            customSoundPath = "",
            sharedMediaSound = sharedMediaSound,
            useCustomSound = false,
            useSharedMediaSound = true,
        }
    end

    if soundSource == "sharedmedia" then
        return {
            notifyMode = modeSound,
            soundSource = "sharedmedia",
            soundPath = sharedPath ~= "" and sharedPath or soundPath,
            builtinSoundPath = self:GetDefaultBuiltinSoundPath(),
            customSoundPath = "",
            sharedMediaSound = sharedMediaSound,
            useCustomSound = false,
            useSharedMediaSound = sharedMediaSound ~= "",
        }
    end

    if soundSource == "builtin" or (soundSource == "" and self:IsBuiltinSoundPath(soundPath)) then
        local builtinPath = self:IsBuiltinSoundPath(soundPath) and soundPath or self:GetDefaultBuiltinSoundPath()
        return {
            notifyMode = modeSound,
            soundSource = "builtin",
            soundPath = builtinPath,
            builtinSoundPath = builtinPath,
            customSoundPath = "",
            sharedMediaSound = "",
            useCustomSound = false,
            useSharedMediaSound = false,
        }
    end

    if (soundSource == "sharedmedia" or soundSource == "") and sharedMediaSound ~= "" then
        return {
            notifyMode = modeSound,
            soundSource = "sharedmedia",
            soundPath = soundPath,
            builtinSoundPath = self:GetDefaultBuiltinSoundPath(),
            customSoundPath = "",
            sharedMediaSound = sharedMediaSound,
            useCustomSound = false,
            useSharedMediaSound = true,
        }
    end

    if soundSource == "custom" or soundPath ~= "" then
        return {
            notifyMode = modeSound,
            soundSource = "custom",
            soundPath = soundPath,
            builtinSoundPath = self:GetDefaultBuiltinSoundPath(),
            customSoundPath = soundPath,
            sharedMediaSound = "",
            useCustomSound = soundPath ~= "",
            useSharedMediaSound = false,
        }
    end

    local defaultBuiltin = self:GetDefaultBuiltinSoundPath()
    return {
        notifyMode = modeSound,
        soundSource = "builtin",
        soundPath = defaultBuiltin,
        builtinSoundPath = defaultBuiltin,
        customSoundPath = "",
        sharedMediaSound = "",
        useCustomSound = false,
        useSharedMediaSound = false,
    }
end

local function Bridge(methodName)
    NS.AceOptions[methodName] = function(_, ...)
        return Catalog[methodName](Catalog, ...)
    end
end

Bridge("GetBuiltinSoundFiles")
Bridge("GetBuiltinSoundList")
Bridge("GetDefaultBuiltinSoundPath")
Bridge("NormalizeSoundPath")
Bridge("IsBuiltinSoundPath")
Bridge("GetBuiltinSoundDisplayName")
Bridge("GetSharedMediaSoundList")
Bridge("HasSharedMediaSounds")
Bridge("FetchSharedMediaSoundPath")
Bridge("FindSharedMediaSoundNameByPath")
Bridge("ResolveSharedMediaSoundPath")
Bridge("ResolveSoundSourceFields")
