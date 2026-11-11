--@debug@
-- Screenshots for development: the first time each kind of moment from the in-game checks happens
-- (a bar getting its liquid, a change of form), a grey chat line says which, then one screenshot.
-- It hooks in like any other addon could. The whole file is a --@debug@ block, so only a copy
-- straight from the repository has it; off until switched on, English only (README > Screenshots
-- while testing in game).

local addon, ns = ... ---@type string, AddonNamespace
local E, G = ElvUI[1], ElvUI[5]

local SHOT_DELAY = 0.3 -- seconds for the game to draw what changed before the screenshot
local SHOT_GAP = 2 -- seconds at least between two screenshots
local lastShot = -SHOT_GAP

G[addon] = { dev = { on = false, shots = {} } }

---@return AddonDevData
local function Dev()
    return E.global[addon].dev
end

---The screenshot itself. C_Timer.After takes only a Lua function, not the client's Screenshot.
local function TakeScreenshot()
    Screenshot()
end

---One screenshot for a kind not shot yet, said in chat first. Within SHOT_GAP of the last one there
---is none, and the kind stays unmarked, so it is shot the next time.
---@param kind string
local function Shoot(kind)
    local dev = Dev()
    if not dev.on or dev.shots[kind] or GetTime() - lastShot < SHOT_GAP then return end
    dev.shots[kind] = true
    print("|cff888888[" .. addon .. " dev] " .. kind .. "|r")
    lastShot = GetTime()
    C_Timer.After(SHOT_DELAY, TakeScreenshot)
end

---@param bar StatusBar
---@param kind string
---@param _ string the look
---@param owner (AddonFrame|string)?
hooksecurefunc(ns, "Attach", function(bar, kind, _, owner)
    local holder = ns.holders[bar]
    if not (holder and holder.live) then return end
    local frame = type(owner) == "table" and owner.unitframeType .. " " or ""
    Shoot("liquid: " .. frame .. kind)
end)

---@param holder AddonHolder
hooksecurefunc(ns, "Shift", function(holder)
    local _, token = UnitPowerType(ns.UnitOf(holder) or "player")
    Shoot("form: " .. token)
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
