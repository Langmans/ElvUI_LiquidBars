--@debug@
-- Screenshots for development: the first time each kind of moment from the in-game checks happens
-- (a bar getting its liquid, a change of form), a grey chat line says which, then one screenshot.
-- The kinds of one moment share a screenshot. A bar counts when it gets its liquid, not each time
-- ElvUI configures it again. It hooks in like any other addon could. The whole file is a --@debug@
-- block, so only a copy straight from the repository has it; off until switched on, English only
-- (README > Screenshots while testing in game).

local addon, ns = ... ---@type string, AddonNamespace
local E, G = ElvUI[1], ElvUI[5]

local SHOT_DELAY = 0.3 -- seconds for the game to draw what changed before the screenshot
local SHOT_GAP = 2 -- seconds at least between two screenshots
local lastShot = -SHOT_GAP
-- The kinds noticed since the last screenshot, for the next one, and whether it is on its way.
---@type string[]
local pending = {}
local flushing = false
-- The bars that have their liquid, as far as the screenshots have seen.
---@type table<StatusBar, boolean>
local seen = {}

G[addon] = { dev = { on = false, shots = {} } }

-- The namespace as a global, <folder>Dev, for /run probes in game: holders, looks, settings.
_G[addon .. "Dev"] = ns

---@return AddonDevData
local function Dev()
    return E.global[addon].dev
end

---The screenshot itself. C_Timer.After takes only a Lua function, not the client's Screenshot.
local function TakeScreenshot()
    Screenshot()
end

---One screenshot for the kinds noticed, each said in chat first. Within SHOT_GAP of the last one it
---waits for the gap to pass.
local function Flush()
    local wait = lastShot + SHOT_GAP - GetTime()
    if wait > 0 then
        C_Timer.After(wait, Flush)
        return
    end
    flushing = false
    local shots = Dev().shots
    for _, kind in ipairs(pending) do
        shots[kind] = true
        print("|cff888888[" .. addon .. " dev] " .. kind .. "|r")
    end
    wipe(pending)
    lastShot = GetTime()
    C_Timer.After(SHOT_DELAY, TakeScreenshot)
end

---Notes a kind for the next screenshot, when switched on and not shot or noted yet.
---@param kind string
local function Notice(kind)
    local dev = Dev()
    if not dev.on or dev.shots[kind] or tContains(pending, kind) then return end
    pending[#pending + 1] = kind
    if flushing then return end
    flushing = true
    C_Timer.After(0, Flush)
end

---@param bar StatusBar
---@param kind string
---@param _ string the look
---@param owner (AddonFrame|string)?
hooksecurefunc(ns, "Attach", function(bar, kind, _, owner)
    local holder = ns.holders[bar]
    if not (holder and holder.live) or seen[bar] then return end
    seen[bar] = true
    local frame = type(owner) == "table" and owner.unitframeType .. " " or ""
    Notice("liquid: " .. frame .. kind)
end)

---@param bar StatusBar
hooksecurefunc(ns, "Detach", function(bar)
    seen[bar] = nil
end)

---@param holder AddonHolder
hooksecurefunc(ns, "Shift", function(holder)
    local _, token = UnitPowerType(ns.UnitOf(holder) or "player")
    Notice("form: " .. token)
end)

---The switch and the forget button, a box on the plugin's page.
---@return table
function ns.DevOptions()
    return {
        type = "group",
        inline = true,
        name = "Development",
        order = 100,
        args = {
            on = {
                type = "toggle",
                name = "Dev screenshots",
                desc = "A screenshot the first time each kind of moment from the in-game checks happens. Repository copies only.",
                order = 1,
                get = function()
                    return Dev().on
                end,
                ---@param _ table AceConfig's info
                ---@param value boolean
                set = function(_, value)
                    Dev().on = value
                end,
            },
            forget = {
                type = "execute",
                name = "Forget the screenshots taken",
                order = 2,
                func = function()
                    wipe(Dev().shots)
                end,
            },
        },
    }
end
--@end-debug@
