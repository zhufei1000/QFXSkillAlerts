-- The native addon has no factory dependency. A suite-owned renderer may
-- install itself before any config frame is built; absence keeps native UI.
local NS = rawget(_G, "QFXSkillAlertsNS")
local AM = rawget(_G, "QFXAddonManager")
if not NS or not AM then return end
if not AM.EnsureConfigLoaded or not AM.EnsureConfigLoaded() then return end
if not AM.EnsureAdaptersLoaded or not AM.EnsureAdaptersLoaded() then return end
if AM.SkillAlertsUI and AM.SkillAlertsUI.Install then AM.SkillAlertsUI.Install(NS) end
