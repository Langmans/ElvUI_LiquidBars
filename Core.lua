-- The plugin's ElvUI module: its settings in ElvUI's profile, which of ElvUI's bars get a liquid
-- (Bar.lua), and the events that stir them. How it all fits together: README.md, technical part.

local addon, ns = ... ---@type string, AddonNamespace
local E, P = ElvUI[1], ElvUI[4]
local UF = E:GetModule("UnitFrames")
local DB = E:GetModule("DataBars")

ns.NAME = addon
ns.L = LibStub("AceLocale-3.0"):GetLocale(addon)

---Whether the client hides a value (secret values: WoW: Forever in combat). Such a value may not be
---tested or compared, only passed on. A client without the check hides nothing.
---@param _ string|number|boolean|table|nil
---@return boolean
local function NeverSecret(_)
    return false
end
ns.IsSecret = issecretvalue or NeverSecret

-- The frames the plugin works on, by ElvUI's unitframeType, and their bars, in the options' order.
ns.unitOrder = { "player", "target", "focus", "pet", "targettarget", "party" }
ns.partOrder = { "health", "power" }
local PARTS = { health = "Health", power = "Power" }

-- ElvUI's data bars: the key in DB.StatusBars and the unit each follows.
ns.dataOrder = { "experience", "reputation", "petExperience" }
local DATA_BARS = { experience = "Experience", reputation = "Reputation", petExperience = "PetExperience" }
local DATA_UNITS = { experience = "player", reputation = "player", petExperience = "pet" }

-- The power types a power bar set to "By power type" knows, by UnitPowerType's token.
ns.powerOrder = { "MANA", "RAGE", "ENERGY", "FOCUS", "LUNAR_POWER" }

local units = {}
for _, key in ipairs(ns.unitOrder) do
    local on = key ~= "party" -- a liquid on every party frame adds up
    units[key] = { health = { on = on, theme = "elvui" }, power = { on = on, theme = "power" } }
end
local data = {}
for _, key in ipairs(ns.dataOrder) do
    data[key] = { on = true, theme = "elvui" }
end
local power = {}
for _, token in ipairs(ns.powerOrder) do
    power[token] = "elvui"
end

P[addon] = {
    units = units,
    data = data,
    power = power,
    -- Smooth Animated Bars' own switches, read live by every liquid.
    effects = { waves = true, swirl = true, bubbles = true, sparkles = true, ambient = true, lightning = true },
}

---The plugin's settings in the current ElvUI profile.
---@return AddonSettings
function ns.db()
    return E.db[addon]
end

---A frame's health and power bars, each with a liquid or without, as set.
---@param frame AddonFrame
function ns.AttachFrame(frame)
    local set = ns.db().units[frame.unitframeType]
    if not set then return end
    for _, part in ipairs(ns.partOrder) do
        local bar = frame[PARTS[part]] --[[@as StatusBar?]]
        if bar then
            if set[part].on then
                ns.Attach(bar, part, set[part].theme, frame)
            else
                ns.Detach(bar)
            end
        end
    end
end

---ElvUI's data bars, each with a liquid or without, as set.
function ns.AttachDataBars()
    local set = ns.db().data
    for _, key in ipairs(ns.dataOrder) do
        local bar = DB.StatusBars[DATA_BARS[key]] --[[@as StatusBar?]]
        if bar then
            if set[key].on then
                ns.Attach(bar, key, set[key].theme, DATA_UNITS[key])
            else
                ns.Detach(bar)
            end
        end
    end
end

---Every bar as set now.
function ns.ApplyAll()
    for _, frame in ipairs(E.oUF.objects) do
        ns.AttachFrame(frame)
    end
    ns.AttachDataBars()
end

---A power bar whose unit changed its power type (a druid's form): its look again, and a big splash.
---@param holder AddonHolder
function ns.Shift(holder)
    ns.Recolor(holder)
    ns.Splash(holder, 1, true)
end

local SPLASH = 0.25
-- What each event changes: a unit's bar of that kind, or a data bar.
local KINDS = {
    UNIT_HEALTH = "health",
    UNIT_MAXHEALTH = "health",
    UNIT_POWER_UPDATE = "power",
    UNIT_MAXPOWER = "power",
    PLAYER_XP_UPDATE = "experience",
    UPDATE_FACTION = "reputation",
    UNIT_PET_EXPERIENCE = "petExperience",
}
local UNIT_EVENTS = { UNIT_HEALTH = true, UNIT_MAXHEALTH = true, UNIT_POWER_UPDATE = true, UNIT_MAXPOWER = true }
-- Events that put another unit on a frame: a theme picking its colour by unit picks again. ElvUI
-- configures a frame before oUF gives it its unit, so entering the world counts too.
local NEW_UNIT = {
    "PLAYER_TARGET_CHANGED",
    "PLAYER_FOCUS_CHANGED",
    "UNIT_PET",
    "UNIT_TARGET",
    "GROUP_ROSTER_UPDATE",
    "PLAYER_ENTERING_WORLD",
}

local M = E:NewModule(addon, "AceHook-3.0", "AceEvent-3.0")

---ElvUI configured a frame's health or power bar.
---@param _ table the UnitFrames module
---@param frame AddonFrame
function M:Configure(_, frame)
    ns.AttachFrame(frame)
end

function M:DataBars()
    ns.AttachDataBars()
end

---A bar's value changed: its liquid splashes.
---@param event string
---@param unit string?
function M:Changed(event, unit)
    local kind = KINDS[event]
    for _, holder in ipairs(ns.Live()) do
        if holder.kind == kind and (not UNIT_EVENTS[event] or ns.UnitOf(holder) == unit) then
            ns.Splash(holder, SPLASH)
        end
    end
end

---@param _ string the event
---@param unit string
function M:UNIT_DISPLAYPOWER(_, unit)
    for _, holder in ipairs(ns.Live()) do
        if holder.kind == "power" and ns.UnitOf(holder) == unit then ns.Shift(holder) end
    end
end

function M:NewUnit()
    for _, holder in ipairs(ns.Live()) do
        ns.Recolor(holder, true)
    end
end

function M:Initialize()
    LibStub("LibElvUIPlugin-1.0"):RegisterPlugin(addon, ns.InsertOptions)
    self:SecureHook(UF, "Configure_HealthBar", "Configure")
    self:SecureHook(UF, "Configure_Power", "Configure")
    self:SecureHook(DB, "UpdateAll", "DataBars")
    ns.ApplyAll()
    for event in pairs(KINDS) do
        self:RegisterEvent(event, "Changed")
    end
    for _, event in ipairs(NEW_UNIT) do
        self:RegisterEvent(event, "NewUnit")
    end
    self:RegisterEvent("UNIT_DISPLAYPOWER")
end

E:RegisterModule(M:GetName())
