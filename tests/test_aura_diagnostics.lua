local printed, diagnosed = {}, {}
function print(message) printed[#printed + 1] = message end
SlashCmdList = {}
QFXSkillAlertsNS = {
    Core = { CDMNativeAuraSounds = {
        PrintDiagnostics = function(_, spellID) diagnosed[#diagnosed + 1] = spellID end,
    } },
}
dofile("QFXSkillAlerts/Core/Commands.lua")
SlashCmdList.QFXSKILLALERTS("aura 444774")
assert(diagnosed[1] == 444774, "aura command passes the configured talent ID")
SlashCmdList.QFXSKILLALERTS("aura")
assert(diagnosed[2] == 0, "no ID diagnoses all configured auras")
assert(#printed == 0, "diagnostic routing must not open UI or execute legacy cleanup")
