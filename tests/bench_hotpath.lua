-- Micro-benchmark of the runtime hot path (Runtime.lua tick loop) using the
-- same logic as the addon.  Measures the per-tick cost of processing active
-- cooldown records with all three alert channels (voice + image + text).

local function EvaluateCooldownCondition(op, threshold, remaining, previousRemaining)
    if type(threshold) ~= "number" then
        threshold = tonumber(threshold) or 0
    end
    remaining = remaining or 0
    if op == "<" then
        return remaining < threshold
    elseif op == ">" then
        return remaining > threshold
    elseif op == ">=" then
        return remaining >= threshold
    elseif op == "==" then
        if threshold <= 0 then
            return remaining <= 0
        end
        if math.abs(remaining - threshold) <= 0.12 then
            return true
        end
        previousRemaining = tonumber(previousRemaining)
        return previousRemaining ~= nil and previousRemaining > threshold and remaining <= threshold
    end
    return remaining <= threshold
end

local function ProcessCooldownRecord(cd, now)
    if not cd then
        return false
    end
    local maxCharge = cd.maxCharge or math.max(1, math.floor(tonumber(cd.charge) or 1))
    local currentCharge = math.floor(tonumber(cd.currentCharge) or 0)
    if currentCharge < 0 then currentCharge = 0 end
    if currentCharge > maxCharge then currentCharge = maxCharge end
    local isFull = currentCharge >= maxCharge
    local remaining = 0
    if not isFull then
        local nextChargeAt = tonumber(cd.nextChargeAt) or 0
        remaining = nextChargeAt > 0 and math.max(0, nextChargeAt - now) or 0
    end
    -- voice channel
    if cd.voiceEnabled ~= false and not cd.voiceNotified
        and EvaluateCooldownCondition(cd.voiceConditionOp, cd.voiceConditionTime, remaining, cd.previousRemaining) then
        cd.voiceNotified = true
    end
    -- visual channels (finite-duration guard)
    local imageDone = cd.imageEnabled ~= true or (cd.imageDurationEnabled == true and cd.imageNotified == true)
    local textDone = cd.textEnabled ~= true or (cd.textDurationEnabled == true and cd.textNotified == true)
    if not (imageDone and textDone) then
        local imageReady = cd.imageEnabled == true and EvaluateCooldownCondition(cd.imageConditionOp, cd.imageConditionTime, remaining, cd.previousRemaining)
        local textReady = cd.textEnabled == true and EvaluateCooldownCondition(cd.textConditionOp, cd.textConditionTime, remaining, cd.previousRemaining)
        if imageReady and not cd.imageNotified then cd.imageNotified = true end
        if textReady and not cd.textNotified then cd.textNotified = true end
    end
    cd.previousRemaining = remaining
    return not isFull
end

-- 30 active cooldowns with all three channels enabled, 10s CD, mid-cycle
local records = {}
for i = 1, 30 do
    records[i] = {
        charge = 1, maxCharge = 1, currentCharge = 0,
        singleCD = 10, nextChargeAt = 8.5,
        voiceEnabled = true, voiceNotified = false,
        voiceConditionOp = "<=", voiceConditionTime = 2,
        imageEnabled = true, imageNotified = false, imageDurationEnabled = true,
        imageConditionOp = "<=", imageConditionTime = 2,
        textEnabled = true, textNotified = false, textDurationEnabled = true,
        textConditionOp = "<=", textConditionTime = 2,
        previousRemaining = 8.5,
    }
end

local now = 1000.0
local TICKS = 50000
local start = os.clock()
for tick = 1, TICKS do
    now = now + 0.1
    for _, cd in ipairs(records) do
        cd.nextChargeAt = 8.5
        ProcessCooldownRecord(cd, now)
    end
end
local elapsed = os.clock() - start
local perTick = elapsed / TICKS
print(string.format("30条记录 x %d ticks: %.3f s", TICKS, elapsed))
print(string.format("每 tick(30条): %.4f ms = %.1f 微秒/记录", perTick * 1000, perTick * 1000000 / 30))
print(string.format("模拟战斗(0.1s间隔): 每秒 CPU 成本约 %.2f ms", perTick * 1000 * 10))

-- Optional countdown branch: the hot loop only compares an integer every
-- tick; visible text is rebuilt when that integer changes (once per second).
local countdownRecords = {}
for i = 1, 30 do countdownRecords[i] = { countdownSecond = nil } end
local countdownUpdates = 0
local countdownStart = os.clock()
for tick = 1, TICKS do
    local remaining = 3600 - ((tick * 0.1) % 3600)
    for _, cd in ipairs(countdownRecords) do
        local displaySecond = math.max(0, math.ceil(remaining - 0.001))
        if cd.countdownSecond ~= displaySecond then
            cd.countdownSecond = displaySecond
            local minutes = math.floor(displaySecond / 60)
            local seconds = displaySecond % 60
            cd.display = minutes > 0 and (tostring(minutes) .. "m" .. (seconds > 0 and (tostring(seconds) .. "s") or "")) or (tostring(seconds) .. "s")
            countdownUpdates = countdownUpdates + 1
        end
    end
end
local countdownElapsed = os.clock() - countdownStart
local countdownPerTick = countdownElapsed / TICKS
print(string.format("30条倒计时 x %d ticks: %.3f s（文字实际刷新 %d 次）", TICKS, countdownElapsed, countdownUpdates))
print(string.format("倒计时分支每 tick(30条): %.4f ms；战斗每秒约 %.2f ms", countdownPerTick * 1000, countdownPerTick * 1000 * 10))

-- Idle-state cost: empty handler paths
local function BloodlustHandleUnitAura(unit, active)
    if unit ~= "player" or not active then
        return false
    end
    return true
end
local start2 = os.clock()
local IDLE_EVENTS = 200000
for i = 1, IDLE_EVENTS do
    BloodlustHandleUnitAura("player", false)   -- no config
end
local idleCost = (os.clock() - start2) / IDLE_EVENTS
print(string.format("无嗜血配置时单次 UNIT_AURA 门控成本: %.2f 纳秒", idleCost * 1e9))
print(string.format("模拟战斗(每秒30次 UNIT_AURA): 每秒 %.3f 毫秒", idleCost * 30 * 1000))
