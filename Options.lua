-- The plugin's page in ElvUI's options, among the plugins in its side bar: the unit frames (a page
-- per kind of frame, a box per bar), the data bars, the look per power type and the effects. Every
-- change applies at once.

local addon, ns = ... ---@type string, AddonNamespace
local E = ElvUI[1]
local L = ns.L

-- The plugin's name in the side bar.
local TITLE = "|cff4fc3ff%s|r"

---The looks to pick from: ElvUI's colour, every theme of Smooth Animated Bars, and for a power bar
---"By power type".
---@param withPower boolean
---@return table<string, string>
local function Looks(withPower)
    local values = { elvui = L.THEME_ELVUI }
    for _, key in ipairs(ns.Themes.order) do
        values[key] = ns.Themes.list[key].name
    end
    if withPower then values.power = L.THEME_POWER end
    return values
end

---A bar's box: a liquid or not, and its look.
---@param order number
---@param name string
---@param settings fun(): AddonBarSettings
---@param withPower boolean
---@return table
local function BarBox(order, name, settings, withPower)
    return {
        type = "group",
        inline = true,
        order = order,
        name = name,
        ---@param info string[]
        ---@return string|boolean
        get = function(info)
            return settings()[info[#info]] --[[@as string|boolean]]
        end,
        ---@param info string[]
        ---@param value string|boolean
        set = function(info, value)
            settings()[info[#info]] = value
            ns.ApplyAll()
        end,
        args = {
            on = { type = "toggle", order = 1, name = L.ON },
            theme = { type = "select", order = 2, name = L.THEME, values = Looks(withPower) },
        },
    }
end

---@return table
local function UnitsTab()
    local args = {}
    for order, key in ipairs(ns.unitOrder) do
        local page = { type = "group", order = order, name = L[key], args = {} }
        for i, part in ipairs(ns.partOrder) do
            page.args[part] = BarBox(i, L[part], function()
                return ns.db().units[key][part] --[[@as AddonBarSettings]]
            end, part == "power")
        end
        args[key] = page
    end
    return { type = "group", order = 1, name = L.UNITS, args = args }
end

---@return table
local function DataTab()
    local args = {}
    for order, key in ipairs(ns.dataOrder) do
        args[key] = BarBox(order, L[key], function()
            return ns.db().data[key]
        end, false)
    end
    return { type = "group", order = 2, name = L.DATA, args = args }
end

---@return table
local function PowerTab()
    local args = { desc = { type = "description", order = 0, name = L.POWER_DESC } }
    local looks = Looks(false)
    for order, token in ipairs(ns.powerOrder) do
        args[token] = { type = "select", order = order, name = L[token], values = looks }
    end
    return {
        type = "group",
        order = 3,
        name = L.POWER,
        ---@param info string[]
        ---@return string
        get = function(info)
            return ns.db().power[info[#info]] --[[@as string]]
        end,
        ---@param info string[]
        ---@param value string
        set = function(info, value)
            ns.db().power[info[#info]] = value
            ns.ApplyAll()
        end,
        args = args,
    }
end

-- Smooth Animated Bars' effect switches, in its order.
local EFFECTS = { "waves", "swirl", "bubbles", "sparkles", "ambient", "lightning" }

---The level per group size and how big a big raid is, as a box.
---@return table
local function LevelsBox()
    local levels = {}
    for _, key in ipairs(ns.levelOrder) do
        levels[key] = L["LEVEL_" .. key]
    end
    local args = {
        size = {
            type = "range",
            order = 10,
            name = L.BIG_RAID_SIZE,
            min = 6,
            max = 40,
            step = 1,
            ---@return number
            get = function()
                return ns.db().bigRaid
            end,
            ---@param _ table AceConfig's info
            ---@param value number
            set = function(_, value)
                ns.db().bigRaid = value
                ns.ApplyAll()
            end,
        },
    }
    for order, group in ipairs(ns.groupOrder) do
        args[group] = {
            type = "select",
            order = order,
            name = L["GROUP_" .. group],
            values = levels,
            sorting = ns.levelOrder,
        }
    end
    return {
        type = "group",
        inline = true,
        order = 1,
        name = L.LEVELS,
        ---@param info string[]
        ---@return string
        get = function(info)
            return ns.db().levels[info[#info]]
        end,
        ---@param info string[]
        ---@param value string
        set = function(info, value)
            ns.db().levels[info[#info]] = value
            ns.ApplyAll()
        end,
        args = args,
    }
end

---The custom level's switches, as a box.
---@return table
local function CustomBox()
    local args = {}
    for order, key in ipairs(EFFECTS) do
        args[key] = { type = "toggle", order = order, name = L[key] }
    end
    return {
        type = "group",
        inline = true,
        order = 3,
        name = L.LEVEL_custom,
        ---@param info string[]
        ---@return boolean
        get = function(info)
            return ns.db().effects[info[#info]] --[[@as boolean]]
        end,
        ---@param info string[]
        ---@param value boolean
        set = function(info, value)
            ns.db().effects[info[#info]] = value
            ns.ApplyAll()
        end,
        args = args,
    }
end

---@return table
local function EffectsTab()
    return {
        type = "group",
        order = 4,
        name = L.EFFECTS,
        args = {
            levels = LevelsBox(),
            fadeFront = {
                type = "toggle",
                order = 2,
                width = "full",
                name = L.FADE_FRONT,
                desc = L.FADE_FRONT_DESC,
                ---@return boolean
                get = function()
                    return ns.db().fadeFront
                end,
                ---@param _ table AceConfig's info
                ---@param value boolean
                set = function(_, value)
                    ns.db().fadeFront = value
                end,
            },
            custom = CustomBox(),
        },
    }
end

---A switch on the plugin's page for one of its settings, applied at once.
---@param order number
---@param key "aboveOverlays"|"tintPrediction"
---@param name string
---@param desc string
---@return table
local function Switch(order, key, name, desc)
    return {
        type = "toggle",
        order = order,
        width = "full",
        name = name,
        desc = desc,
        ---@return boolean
        get = function()
            return ns.db()[key]
        end,
        ---@param _ table AceConfig's info
        ---@param value boolean
        set = function(_, value)
            ns.db()[key] = value
            ns.ApplyAll()
        end,
    }
end

---LibElvUIPlugin calls this once ElvUI's options are loaded.
function ns.InsertOptions()
    if not E.Options then return end
    E.Options.args[addon] = {
        type = "group",
        name = TITLE:format(L.OPTIONS),
        childGroups = "tab",
        args = {
            desc = { type = "description", order = 0, name = L.OPTIONS_DESC },
            aboveOverlays = Switch(1, "aboveOverlays", L.ABOVE_OVERLAYS, L.ABOVE_OVERLAYS_DESC),
            tintPrediction = Switch(2, "tintPrediction", L.TINT_PREDICTION, L.TINT_PREDICTION_DESC),
            units = UnitsTab(),
            data = DataTab(),
            power = PowerTab(),
            effects = EffectsTab(),
            dev = ns.DevOptions and ns.DevOptions(),
        },
    }
end
