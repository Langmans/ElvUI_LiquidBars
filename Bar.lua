-- The liquid on one status bar, whatever bar it is. The bar's own fill turns invisible but keeps
-- its size, so ElvUI's value and its smoothing still move it; a frame one bar wide rides on the
-- fill's right edge and holds Smooth Animated Bars' liquid, always full on that frame. A clip frame
-- over the bar cuts the liquid off at the bar. One driver moves every liquid each frame. How it fits
-- together: README.md, technical part.

local _, ns = ... ---@type string, AddonNamespace

local ROOM = 10 -- px of liquid past the bar's right end, for the waves of a full bar
local IDLE_FPS = 30 -- a liquid at rest moves on this often only
local CHECK_EVERY = 0.25 -- seconds between looks at the bar's colour and fill
local MAX_STEP = 0.1 -- the longest step the liquid takes after a hitch
local SPLASH_EVERY = 0.15 -- seconds at least between two splashes on one bar
local SPLASH_FROM = 8 -- px back from the front the splash's motes start
-- The themes' movement is made for an experience bar; a bar lower than this moves less, down to
-- the least share for a bar a dozen pixels high.
local FULL_HEIGHT = 40
local LEAST = 0.25
-- Smooth Animated Bars' defaults for the movement a theme scales.
local PHYSICS = { amplitude = 10, crest = 7, ambient = 1, slosh = 0.18 }

---@type table<StatusBar, AddonHolder>
ns.holders = {}
---@type AddonHolder[]
local live = {}

---@param value number|AddonSecret|nil
---@return boolean
local function Usable(value)
    return not ns.IsSecret(value) and value ~= nil and value > 0
end

---A theme with its movement scaled to a bar's height.
---@param theme AddonTheme
---@param height number
---@return AddonTheme
function ns.Scaled(theme, height)
    local share = math.max(LEAST, math.min(1, height / FULL_HEIGHT))
    local physics = {}
    for key, value in pairs(theme.physics or PHYSICS) do
        physics[key] = value
    end
    for key, value in pairs(PHYSICS) do
        physics[key] = (physics[key] or value) * share
    end
    return setmetatable({ physics = physics }, { __index = theme })
end

---The unit a bar's liquid follows: its frame's, or the one it was given.
---@param holder AddonHolder
---@return string?
function ns.UnitOf(holder)
    local owner = holder.owner
    if type(owner) == "table" then return owner.__unit end
    return owner --[[@as string?]]
end

---The look a bar takes now: its setting, or for "power" the setting for the unit's power type.
---@param holder AddonHolder
---@return string
local function Choice(holder)
    if holder.setting ~= "power" then return holder.setting end
    local _, token = UnitPowerType(ns.UnitOf(holder) or "player")
    return ns.db().power[token] or "elvui"
end

---The liquid takes the bar's look: ElvUI's colour for the bar, or a theme. Only on a change of
---either, or when forced (a theme picking its colour by unit, for a new unit); a colour the client
---hides keeps the last one.
---@param holder AddonHolder
---@param force boolean?
function ns.Recolor(holder, force)
    local choice, Themes = Choice(holder), ns.Themes
    local theme = Themes.Get(choice ~= "elvui" and choice or Themes.default)
    local r, g, b = holder.bar:GetStatusBarColor()
    local own = choice == "elvui" or theme.Resolve ~= nil
    if own and ns.IsSecret(r) then return end
    if not force and choice == holder.choice and (not own or (r == holder.r and g == holder.g and b == holder.b)) then
        return
    end
    holder.choice, holder.r, holder.g, holder.b = choice, r, g, b
    -- ElvUI's colour, or a theme picking one by unit that has none for this unit: the bar's colour.
    ---@type AddonTheme?
    local look = theme
    if choice == "elvui" then
        look = nil
    elseif theme.Resolve then
        look = theme:Resolve(ns.UnitOf(holder))
    end
    look = look or Themes.FromColor({ r, g, b }, Themes.Get(Themes.default))
    holder.liquid:SetTheme(ns.Scaled(look, holder.height))
end

---Ripples the liquid's front and throws motes off it, at most every SPLASH_EVERY seconds unless
---forced.
---@param holder AddonHolder
---@param intensity number 0..1
---@param force boolean?
function ns.Splash(holder, intensity, force)
    local now = GetTime()
    if not force and now < holder.splashAt then return end
    holder.splashAt = now + SPLASH_EVERY
    holder.liquid:Splash(intensity, holder.width - SPLASH_FROM, holder.width)
end

---The bar's fill: hidden, and the liquid's frame on its edge. The bar may have swapped it.
---@param holder AddonHolder
local function Follow(holder)
    local fill = holder.bar:GetStatusBarTexture()
    if fill:GetAlpha() ~= 0 then fill:SetAlpha(0) end
    if fill == holder.fill then return end
    holder.fill = fill
    local mover = holder.mover
    mover:ClearAllPoints()
    mover:SetPoint("TOPRIGHT", fill, "TOPRIGHT")
    mover:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT")
end

---One liquid's step: its look and fill looked at now and then, the liquid moved on, a liquid at
---rest at IDLE_FPS only.
---@param holder AddonHolder
---@param dt number
local function Step(holder, dt)
    if not holder.bar:IsVisible() then return end
    holder.check = holder.check + dt
    if holder.check >= CHECK_EVERY then
        holder.check = 0
        Follow(holder)
        ns.Recolor(holder)
    end
    local liquid = holder.liquid
    if liquid:IsQuiet() then
        holder.idle = holder.idle + dt
        if holder.idle < 1 / IDLE_FPS then return end
        dt, holder.idle = holder.idle, 0
    else
        holder.idle = 0
    end
    liquid:Update(dt, holder.width)
end

---@param _ Frame
---@param elapsed number
local function OnUpdate(_, elapsed)
    local dt = math.min(elapsed, MAX_STEP)
    if dt <= 0 then return end
    for _, holder in ipairs(live) do
        Step(holder, dt)
    end
end

ns.driver = CreateFrame("Frame")
ns.driver:Hide()
ns.driver:SetScript("OnUpdate", OnUpdate)

---The frames and the liquid for a bar, made once.
---@param bar StatusBar
---@param width number
---@param height number
---@return AddonHolder
local function Build(bar, width, height)
    local clip = CreateFrame("Frame", nil, bar)
    clip:SetFrameLevel(bar:GetFrameLevel())
    clip:SetAllPoints(bar)
    clip:SetClipsChildren(true)
    clip:Hide()
    local mover = CreateFrame("Frame", nil, clip)
    local Themes = ns.Themes
    local liquid = ns.Liquid.New(mover, width + ROOM, height, Themes.Get(Themes.default), ns.db().effects)
    ---@type AddonHolder
    local holder = {
        bar = bar,
        clip = clip,
        mover = mover,
        liquid = liquid,
        live = false,
        setting = "elvui",
        kind = "",
        width = width,
        height = height,
        check = 0,
        idle = 0,
        splashAt = 0,
    }
    ns.holders[bar] = holder
    return holder
end

---Takes a bar's liquid away: the bar's own fill back.
---@param bar StatusBar
function ns.Detach(bar)
    local holder = ns.holders[bar]
    if not holder or not holder.live then return end
    holder.live, holder.fill = false, nil
    for i, other in ipairs(live) do
        if other == holder then
            table.remove(live, i)
            break
        end
    end
    holder.clip:Hide()
    holder.liquid:HideAll()
    bar:GetStatusBarTexture():SetAlpha(1)
    if #live == 0 then ns.driver:Hide() end
end

---Puts a liquid on a bar, or brings it up to date: its size, its look, the effects. A bar it cannot
---follow (vertical, filled from the right, without a size) keeps its own fill.
---@param bar StatusBar
---@param kind string what the bar shows: "health", "power", "experience", ...
---@param setting string its look: "elvui", "power" or a theme's key
---@param owner (AddonFrame|string)? the frame it is on, or the unit it follows
---@return AddonHolder?
function ns.Attach(bar, kind, setting, owner)
    local width, height = bar:GetWidth(), bar:GetHeight()
    if bar:GetOrientation() ~= "HORIZONTAL" or bar:GetReverseFill() or not (Usable(width) and Usable(height)) then
        ns.Detach(bar)
        return nil
    end
    ---@cast width number
    ---@cast height number
    local holder = ns.holders[bar] or Build(bar, width, height)
    holder.kind, holder.setting, holder.owner = kind, setting, owner
    holder.width, holder.height = width, height
    holder.mover:SetWidth(width)
    holder.liquid:SetSize(width + ROOM, height)
    holder.liquid:SetOptions(ns.db().effects)
    holder.fill = nil
    Follow(holder)
    if not holder.live then
        holder.live = true
        live[#live + 1] = holder
        holder.clip:Show()
        holder.liquid:Snap(width)
        ns.driver:Show()
    end
    ns.Recolor(holder, true)
    return holder
end

---Every bar with a liquid, for the events that stir them.
---@return AddonHolder[]
function ns.Live()
    return live
end
