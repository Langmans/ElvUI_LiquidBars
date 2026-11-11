-- The liquid on one status bar, whatever bar it is. The bar's own fill turns invisible but keeps
-- its size, so ElvUI's value and its smoothing still move it; a frame one bar wide rides on the
-- fill's front edge and holds Smooth Animated Bars' liquid, always full on that frame. On a bar
-- filled from the right that is the fill's left edge, and the liquid is drawn through a mirror
-- (Mirror.lua). A clip frame over the bar cuts the liquid off at the bar. One driver moves every
-- liquid each frame. How it fits together: README.md, technical part.

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
-- Where the liquid's frame sits on the fill: its front edge, by whether the bar fills from the right.
---@type table<boolean, FramePoint[]>
local EDGE = { [false] = { "TOPRIGHT", "BOTTOMRIGHT" }, [true] = { "TOPLEFT", "BOTTOMLEFT" } }

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

-- The fills whose SetAlpha is hooked, each once.
---@type table<Texture, boolean>
local hooked = {}

---Hides a bar's fill, keeping the alpha ElvUI gave it (a transparent bar has less than 1) to give back
---when the liquid goes.
---@param holder AddonHolder
---@param fill Texture
---@param alpha number|AddonSecret
local function Hide(holder, fill, alpha)
    if not holder.live or fill ~= holder.fill then return end
    if ns.IsSecret(alpha) then
        fill:SetAlpha(0)
        return
    end
    ---@cast alpha number
    if alpha == 0 then return end
    holder.alpha = alpha
    fill:SetAlpha(0)
end

---The bar's fill: hidden, and the liquid's frame on its edge. The bar may have swapped it. ElvUI sets
---the fill's alpha on its own updates (a transparent bar, target of target several times a second),
---so a hook hides it again at once, before it is drawn.
---@param holder AddonHolder
local function Follow(holder)
    local fill = holder.bar:GetStatusBarTexture()
    if fill ~= holder.fill then
        holder.fill = fill
        if not hooked[fill] then
            hooked[fill] = true
            ---@param tex Texture
            ---@param alpha number
            hooksecurefunc(fill, "SetAlpha", function(tex, alpha)
                Hide(holder, tex, alpha)
            end)
        end
    end
    Hide(holder, fill, fill:GetAlpha())
    if fill == holder.anchored then return end
    holder.anchored = fill
    local mover, top, bottom = holder.mover, unpack(EDGE[holder.reversed])
    mover:ClearAllPoints()
    mover:SetPoint(top, fill, top)
    mover:SetPoint(bottom, fill, bottom)
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

---A bar's liquid for one direction, made the first time: drawn on its frame, or through a mirror of
---it for a bar filled from the right.
---@param holder AddonHolder
---@param reversed boolean
---@return AddonLiquid
local function LiquidFor(holder, reversed)
    local liquid = holder.liquids[reversed]
    if liquid then return liquid end
    local parent = reversed and ns.Mirror(holder.mover) or holder.mover
    local Themes = ns.Themes
    liquid = ns.Liquid.New(parent, holder.width + ROOM, holder.height, Themes.Get(Themes.default), ns.db().effects)
    holder.liquids[reversed] = liquid
    return liquid
end

---The frames and the liquid for a bar, made once.
---@param bar StatusBar
---@param width number
---@param height number
---@param reversed boolean
---@return AddonHolder
local function Build(bar, width, height, reversed)
    local clip = CreateFrame("Frame", nil, bar)
    clip:SetFrameLevel(bar:GetFrameLevel())
    clip:SetAllPoints(bar)
    clip:SetClipsChildren(true)
    clip:Hide()
    ---@type AddonHolder
    local holder = {
        bar = bar,
        clip = clip,
        mover = CreateFrame("Frame", nil, clip),
        liquids = {},
        reversed = reversed,
        live = false,
        setting = "elvui",
        kind = "",
        width = width,
        height = height,
        check = 0,
        idle = 0,
        splashAt = 0,
        alpha = 1,
    } --[[@as AddonHolder]]
    holder.liquid = LiquidFor(holder, reversed)
    ns.holders[bar] = holder
    return holder
end

-- What each bar was last asked to show, so a change of its size can bring it up to date: ElvUI lays
-- out some frames (party, its config mode) after configuring them, and a bar without a size then
-- gets its liquid once it has one. Detach forgets it.
---@type table<StatusBar, string>
local wantKind = {}
---@type table<StatusBar, string>
local wantSetting = {}
---@type table<StatusBar, AddonFrame|string>
local wantOwner = {}
-- The bars whose OnSizeChanged is hooked, each once.
---@type table<StatusBar, boolean>
local sized = {}

---@param bar StatusBar
local function Resized(bar)
    local kind = wantKind[bar]
    if kind then ns.Attach(bar, kind, wantSetting[bar], wantOwner[bar]) end
end

---The liquid off the bar, the bar's own fill back at the alpha ElvUI last gave it.
---@param bar StatusBar
local function Drop(bar)
    local holder = ns.holders[bar]
    if not holder or not holder.live then return end
    holder.live = false
    for i, other in ipairs(live) do
        if other == holder then
            table.remove(live, i)
            break
        end
    end
    holder.clip:Hide()
    holder.liquid:HideAll()
    bar:GetStatusBarTexture():SetAlpha(holder.alpha)
    if #live == 0 then ns.driver:Hide() end
end

---Takes a bar's liquid away for good: its own fill back, and a new size no longer brings it back.
---@param bar StatusBar
function ns.Detach(bar)
    wantKind[bar], wantSetting[bar], wantOwner[bar] = nil, nil, nil
    Drop(bar)
end

---Puts a liquid on a bar, or brings it up to date: its size, its look, the effects. ElvUI calls this
---often for a bar that has its liquid already (each configure), so a liquid is only snapped and given
---a new theme when something changed: it went live, turned round or got another height. It follows
---the bar's size from then on. A bar it cannot follow (vertical, without a size) keeps its own fill.
---@param bar StatusBar
---@param kind string what the bar shows: "health", "power", "experience", ...
---@param setting string its look: "elvui", "power" or a theme's key
---@param owner (AddonFrame|string)? the frame it is on, or the unit it follows
---@return AddonHolder?
function ns.Attach(bar, kind, setting, owner)
    wantKind[bar], wantSetting[bar], wantOwner[bar] = kind, setting, owner
    if not sized[bar] then
        sized[bar] = true
        bar:HookScript("OnSizeChanged", Resized)
    end
    local width, height = bar:GetWidth(), bar:GetHeight()
    if bar:GetOrientation() ~= "HORIZONTAL" or not (Usable(width) and Usable(height)) then
        Drop(bar)
        return nil
    end
    ---@cast width number
    ---@cast height number
    local reversed = bar:GetReverseFill() and true or false
    local holder = ns.holders[bar] or Build(bar, width, height, reversed)
    local fresh = not holder.live or reversed ~= holder.reversed or height ~= holder.height
    if reversed ~= holder.reversed then
        holder.liquid:HideAll()
        holder.reversed, holder.anchored = reversed, nil
        holder.liquid = LiquidFor(holder, reversed)
    end
    holder.kind, holder.setting, holder.owner = kind, setting, owner
    holder.width, holder.height = width, height
    holder.mover:SetWidth(width)
    local liquid = holder.liquid
    liquid:SetSize(width + ROOM, height)
    liquid:SetOptions(ns.db().effects)
    if not holder.live then
        holder.live = true
        live[#live + 1] = holder
        holder.clip:Show()
        ns.driver:Show()
    end
    Follow(holder)
    if fresh then liquid:Snap(width) end
    ns.Recolor(holder, fresh)
    return holder
end

---Whether a bar's look picks its colour by unit (Class Color), so a new unit needs a new theme.
---@param holder AddonHolder
---@return boolean
function ns.ByUnit(holder)
    local choice = holder.choice
    return choice ~= nil and choice ~= "elvui" and ns.Themes.Get(choice).Resolve ~= nil
end

---Every bar with a liquid, for the events that stir them.
---@return AddonHolder[]
function ns.Live()
    return live
end
