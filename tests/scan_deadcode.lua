-- Heuristic dead-code scanner for the QFX Skill Alerts addons (run from the
-- project root).  For every `function <path>:<name>` / `function <path>.<name>`
-- definition, count how many times the bare method name is referenced through
-- `:name` / `.name` across all sources. A count of 1 means the only occurrence
-- is the definition itself -> likely dead code. Counting non-call references
-- avoids false positives for methods passed as callbacks or cached as aliases.

local roots = {
    "QFXSkillAlerts",
    "QFXSkillAlerts_Config",
}

local function CollectFiles(root)
    local files = {}
    -- `dir /s /b` returns absolute paths. Lua's Windows CRT cannot reliably
    -- reopen those paths when the workspace contains non-ASCII characters.
    -- ripgrep returns relative UTF-8 paths, which work in the same process.
    local handle = io.popen('rg --files "' .. root .. '" -g "*.lua"')
    if not handle then return files end
    for line in handle:lines() do
        line = line:gsub("\r$", "")
        if line:sub(-4) == ".lua" then
            files[#files + 1] = line
        end
    end
    handle:close()
    return files
end

local function ReadFile(path)
    local f = io.open(path, "rb")
    if not f then return "" end
    local data = f:read("*a")
    f:close()
    return data
end

local allCode = {}
local filesByRoot = {}
local pathIndex = {}
local readFailures = {}
for _, root in ipairs(roots) do
    local files = CollectFiles(root)
    filesByRoot[root] = files
    for _, path in ipairs(files) do
        local code = ReadFile(path)
        if code == "" then
            readFailures[#readFailures + 1] = path
        end
        allCode[#allCode + 1] = code
        pathIndex[#pathIndex + 1] = path
    end
end
local combined = table.concat(allCode, "\n")
print("scanned files:", #pathIndex, "total chars:", #combined)
if #readFailures > 0 then
    print("read failures:", #readFailures)
    for _, path in ipairs(readFailures) do
        print("   " .. path)
    end
end

-- definitions: `function X:name(` / `function X.name(` / `X.name = function(`
local defs = {}
for chunk in combined:gmatch("function%s+([%w_%.]+[:%.][%w_]+)%s*%(") do
    local path, name = chunk:match("^(.*)[:%.]([%w_]+)$")
    if path and name then
        defs[#defs + 1] = { path = path, name = name }
    end
end
for chunk in combined:gmatch("([%w_%.]+)%s*=%s*function%s*%(") do
    local path, name = chunk:match("^(.*)%.([%w_]+)$")
    if path and name then
        defs[#defs + 1] = { path = path, name = name }
    end
end
print("total definitions:", #defs)

-- Count method references, including callback/alias access without `()`.
local function CountBare(name)
    local n = 0
    for _ in combined:gmatch("[%.:]" .. name .. "%f[^%w_]") do
        n = n + 1
    end
    return n
end

local seen = {}
local byModule = {}
for _, def in ipairs(defs) do
    local bare = def.name
    if not seen[bare] then
        seen[bare] = true
        local referenceCount = CountBare(bare)
        if referenceCount <= 1 then
            byModule[def.path] = byModule[def.path] or {}
            byModule[def.path][#byModule[def.path] + 1] = def.name .. "  (引用次数: " .. referenceCount .. ")"
        end
    end
end

print("")
print("== 疑似死代码（定义但从未被调用）==")
local moduleOrder = {}
for module in pairs(byModule) do moduleOrder[#moduleOrder + 1] = module end
table.sort(moduleOrder)
for _, module in ipairs(moduleOrder) do
    print("-- " .. module)
    for _, name in ipairs(byModule[module]) do
        print("   " .. name)
    end
end
