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
local COLOR_STEPS = 20 -- ElvUI's colour is taken in steps of a twentieth per channel
local OVERLAYS = 2 -- levels above a bar ElvUI's overlays reach (ClipFrame +1, its bars +2)
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

-- ElvUI's power prediction in the liquid's colour; defined with the overlays below.
---@type fun(prediction: StatusBar)
local Tint

-- Looks made so far, by choice or colour and by height, shared by every bar that needs the same
-- one. Smooth Animated Bars' SetTheme builds a dozen tables and drops the liquid's particles, so a
-- liquid only gets another look when it is another object. Cleared when the settings change.
---@type table<string, AddonTheme>
local looks = {}

---Forgets every look made, so the next ones are made from the settings as they are now.
function ns.ForgetLooks()
    wipe(looks)
end

---A look from the cache, made the first time: from a theme, or without one from a colour in steps.
---@param key string
---@param height number
---@param theme AddonTheme? the theme; none: the colour
---@param r number the colour in steps of 1/COLOR_STEPS
---@param g number
---@param b number
---@return AddonTheme
local function Look(key, height, theme, r, g, b)
    local look = looks[key]
    if look then return look end
    local Themes = ns.Themes
    theme = theme or Themes.FromColor({ r / COLOR_STEPS, g / COLOR_STEPS, b / COLOR_STEPS }, Themes.Get(Themes.default))
    look = ns.Scaled(theme, height)
    looks[key] = look
    return look
end

---The liquid takes the bar's look: ElvUI's colour for the bar (in steps of 1/COLOR_STEPS, so a bar
---coloured by value does not get a new look with every bit of health), or a theme. Only on a change
---of either, or when forced (a theme picking its colour by unit, for a new unit); a colour the
---client hides keeps the last one.
---@param holder AddonHolder
---@param force boolean?
function ns.Recolor(holder, force)
    local choice, Themes = Choice(holder), ns.Themes
    local theme = Themes.Get(choice ~= "elvui" and choice or Themes.default)
    local own = choice == "elvui" or theme.Resolve ~= nil
    local r, g, b = 0, 0, 0
    if own then
        local cr, cg, cb = holder.bar:GetStatusBarColor()
        if ns.IsSecret(cr) then return end
        r = math.floor(cr * COLOR_STEPS + 0.5)
        g = math.floor(cg * COLOR_STEPS + 0.5)
        b = math.floor(cb * COLOR_STEPS + 0.5)
    end
    if not force and choice == holder.choice and r == holder.r and g == holder.g and b == holder.b then return end
    holder.choice, holder.r, holder.g, holder.b = choice, r, g, b
    local height = math.floor(holder.height + 0.5)
    ---@type AddonTheme?
    local look
    if choice ~= "elvui" and theme.Resolve then
        -- A colour picked by unit is made anew, on a new unit only; none for this unit: the bar's.
        local resolved = theme:Resolve(ns.UnitOf(holder))
        look = resolved and ns.Scaled(resolved, height)
    elseif choice ~= "elvui" then
        look = Look(choice .. "@" .. height, height, theme, r, g, b)
    end
    look = look or Look(r .. "," .. g .. "," .. b .. "@" .. height, height, nil, r, g, b)
    if look == holder.look then return end
    holder.look = look
    holder.liquid:SetTheme(look)
    if holder.prediction then Tint(holder.prediction) end
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

-- The fills whose SetAlpha and SetVertexColor are hooked, each once.
---@type table<Texture, boolean>
local hooked = {}
-- The calls that set a texture's alpha: SetVertexColor's fourth value does too, and that is how
-- ElvUI makes a bar transparent (UF:SetStatusBarColor).
local ALPHA_SETTERS = { "SetAlpha", "SetVertexColor" }

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
---so hooks hide it again at once, before it is drawn, keeping the alpha it was given.
---@param holder AddonHolder
local function Follow(holder)
    local fill = holder.bar:GetStatusBarTexture()
    if fill ~= holder.fill then
        holder.fill = fill
        if not hooked[fill] then
            hooked[fill] = true
            ---@param tex Texture
            local function Again(tex)
                Hide(holder, tex, tex:GetAlpha())
            end
            for _, method in ipairs(ALPHA_SETTERS) do
                hooksecurefunc(fill, method, Again)
            end
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

-- The front's alpha by the share of the bar filled: shown, then out over the last few percent, where
-- it would sit against the bar's end.
local FADE_FROM = 0.97
local FRONT_POINTS = { { 0, 1 }, { FADE_FROM, 1 }, { 1, 0 } }
-- The client's curve for it, made the first time; false on a client without curves.
---@type CurveObject|false|nil
local frontCurve

---@return CurveObject|false
local function FrontCurve()
    if frontCurve == nil then
        frontCurve = false
        if C_CurveUtil and UnitHealthPercent and UnitPowerPercent then
            local curve = C_CurveUtil.CreateCurve()
            curve:SetType(Enum.LuaCurveType.Linear)
            for _, point in ipairs(FRONT_POINTS) do
                curve:AddPoint(point[1], point[2])
            end
            frontCurve = curve
        end
    end
    return frontCurve
end

---How much of a bar's front shows. A unit's health or power: the client's own percentage on the
---curve, which may come back hidden (secret) and goes straight to SetAlpha. Other bars, or without
---curves: by the bar's own values; shown when those are hidden.
---@param holder AddonHolder
---@return number
local function FrontAlpha(holder)
    if not ns.db().fadeFront then return 1 end
    local unit, curve, kind = ns.UnitOf(holder), FrontCurve(), holder.kind
    if curve and unit and kind == "health" then
        return UnitHealthPercent(unit, false, curve) --[[@as number]]
    end
    if curve and unit and kind == "power" then
        return UnitPowerPercent(unit, nil, false, curve) --[[@as number]]
    end
    local bar = holder.bar
    local value, low, high = bar:GetValue(), bar:GetMinMaxValues()
    if ns.IsSecret(value) or ns.IsSecret(low) or ns.IsSecret(high) or high <= low then return 1 end
    local share = (value - low) / (high - low)
    if share < FADE_FROM then return 1 end
    return math.max(0, (1 - share) / (1 - FADE_FROM))
end

---One liquid's step: its look and fill looked at now and then, its front faded, the liquid moved on,
---a liquid at rest at IDLE_FPS only.
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
    holder.front:SetAlpha(FrontAlpha(holder))
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
    liquid = ns.Liquid.New(parent, holder.width + ROOM, holder.height, Themes.Get(Themes.default), ns.Effects())
    -- The front's line and glow onto the front frame, whose alpha the plugin sets: the liquid sets
    -- their own alpha each frame. Their anchors stay on the liquid's frame.
    for _, tip in ipairs(liquid.tips) do
        tip:SetParent(holder.front)
    end
    liquid.glow:SetParent(holder.front)
    holder.liquids[reversed] = liquid
    return liquid
end

-- ElvUI's cutaway texture on a frame, by the kind of bar (UF:Construct_Cutaway).
local CUTAWAY = { health = "Health", power = "Power" }
-- ElvUI's power prediction bars above a liquid now, by the liquid's holder, and those whose
-- SetMinMaxValues and SetStatusBarColor are hooked.
---@type table<StatusBar, AddonHolder>
local predictions = {}
---@type table<StatusBar, boolean>
local hookedPrediction = {}
-- The prediction in the liquid's colour: its look's main colour's hue and saturation at one fixed
-- lightness, dark enough for the bar's white text on any liquid, a little see-through.
local TINT_LIGHTNESS = 0.3
local TINT_ALPHA = 0.85

---A colour's hue and saturation (HSL) at TINT_LIGHTNESS; a grey stays grey.
---@param r number
---@param g number
---@param b number
---@return number r, number g, number b
local function Shade(r, g, b)
    local high, low = math.max(r, g, b), math.min(r, g, b)
    local spread = high - low
    if spread == 0 then return TINT_LIGHTNESS, TINT_LIGHTNESS, TINT_LIGHTNESS end
    local saturation = math.min(1, spread / (1 - math.abs(high + low - 1)))
    -- The hue in sixths of the circle, 0 up to 6.
    local hue
    if high == r then
        hue = ((g - b) / spread) % 6
    elseif high == g then
        hue = (b - r) / spread + 2
    else
        hue = (r - g) / spread + 4
    end
    local chroma = (1 - math.abs(2 * TINT_LIGHTNESS - 1)) * saturation
    local x = chroma * (1 - math.abs(hue % 2 - 1))
    local m = TINT_LIGHTNESS - chroma / 2
    local sector = math.floor(hue)
    if sector == 0 then return chroma + m, x + m, m end
    if sector == 1 then return x + m, chroma + m, m end
    if sector == 2 then return m, chroma + m, x + m end
    if sector == 3 then return m, x + m, chroma + m end
    if sector == 4 then return x + m, m, chroma + m end
    return chroma + m, m, x + m
end

---The prediction's colour: the liquid's (Tint above), or with the option off, without a liquid or for
---a look without a colour, ElvUI's own (the bar's status bar colour).
---@param prediction StatusBar
Tint = function(prediction)
    local holder = predictions[prediction]
    local color = holder and ns.db().tintPrediction and holder.look and holder.look.fillB
    local fill = prediction:GetStatusBarTexture()
    if color then
        local r, g, b = Shade(color[1], color[2], color[3])
        fill:SetVertexColor(r, g, b, TINT_ALPHA)
    else
        fill:SetVertexColor(prediction:GetStatusBarColor())
    end
end

---ElvUI's power prediction bar above a liquid shows only with a range: after login it is shown with
---none (0..0), which fills the whole bar. A range the client hides cannot be compared: shown.
---@param prediction StatusBar
local function ShowRange(prediction)
    if not predictions[prediction] then return end
    local low, high = prediction:GetMinMaxValues()
    if ns.IsSecret(low) or ns.IsSecret(high) then
        prediction:SetAlpha(1)
        return
    end
    prediction:SetAlpha(high > low and 1 or 0)
end

---ElvUI's power prediction (a spell's cost) above the liquid, one level over the overlay frame, in
---the liquid's colour, while the liquid is above ElvUI's overlays; else back in ElvUI's ClipFrame,
---shown and coloured as ElvUI does.
---@param holder AddonHolder
---@param frame AddonFrame
---@param above boolean
local function Prediction(holder, frame, above)
    local prediction = holder.kind == "power" and frame.PowerPrediction and frame.PowerPrediction.mainBar
    if not prediction then return end
    if not above then
        predictions[prediction], holder.prediction = nil, nil
        local clipFrame = (holder.bar --[[@as AddonBar]]).ClipFrame or holder.bar
        prediction:SetParent(clipFrame)
        prediction:SetFrameLevel(clipFrame:GetFrameLevel() + 1)
        prediction:SetAlpha(1)
        Tint(prediction)
        return
    end
    if not hookedPrediction[prediction] then
        hookedPrediction[prediction] = true
        hooksecurefunc(prediction, "SetMinMaxValues", ShowRange)
        hooksecurefunc(prediction, "SetStatusBarColor", Tint)
    end
    predictions[prediction], holder.prediction = holder, prediction
    prediction:SetParent(holder.over)
    prediction:SetFrameLevel(holder.over:GetFrameLevel() + 1)
    ShowRange(prediction)
    Tint(prediction)
end

---ElvUI's overlays on a unit frame's bar above the liquid, on the overlay frame (above the liquid's
---front, never faded), while the liquid is above them; else back in ElvUI's ClipFrame. The cutaway
---(the lost health or power fading away): its anchors, colour and fading stay ElvUI's. The power
---prediction: see Prediction.
---@param holder AddonHolder
---@param above boolean
local function Overlays(holder, above)
    local owner = holder.owner
    if type(owner) ~= "table" then return end
    local frame = owner --[[@as AddonFrame]]
    Prediction(holder, frame, above)
    local part, cutaways = CUTAWAY[holder.kind], frame.Cutaway
    if not part or not cutaways then return end
    ---@type Texture?
    local cutaway = cutaways[part]
    if not cutaway then return end
    local bar = holder.bar --[[@as AddonBar]]
    cutaway:SetParent(above and holder.over or bar.ClipFrame or bar)
end

---The liquid's frame levels, from the bar's: above ElvUI's overlays on the bar (its ClipFrame one
---level up, with the power prediction and the cutaway, which drew over the liquid) unless switched
---off; the liquid's frame one above that, its front one above the liquid, the overlay frame for
---ElvUI's overlays one above the front. Set again on every attach, as ElvUI may give the bar another
---level.
---@param holder AddonHolder
local function Layer(holder)
    local above = ns.db().aboveOverlays
    local level = holder.bar:GetFrameLevel() + (above and OVERLAYS or 0)
    holder.clip:SetFrameLevel(level)
    holder.mover:SetFrameLevel(level + 1)
    holder.front:SetFrameLevel(level + 2)
    holder.over:SetFrameLevel(level + 3)
    Overlays(holder, above)
end

---The frames and the liquid for a bar, made once.
---@param bar StatusBar
---@param width number
---@param height number
---@param reversed boolean
---@return AddonHolder
local function Build(bar, width, height, reversed)
    local clip = CreateFrame("Frame", nil, bar)
    clip:SetAllPoints(bar)
    clip:SetClipsChildren(true)
    clip:Hide()
    local mover = CreateFrame("Frame", nil, clip)
    -- The liquid's front, above the rest of it. The levels: Layer.
    local front = CreateFrame("Frame", nil, clip)
    front:SetAllPoints(clip)
    -- ElvUI's overlays (cutaway, power prediction) when above the liquid: over the front, never faded.
    local over = CreateFrame("Frame", nil, clip)
    over:SetAllPoints(clip)
    ---@type AddonHolder
    local holder = {
        bar = bar,
        clip = clip,
        over = over,
        mover = mover,
        front = front,
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
    Overlays(holder, false)
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
        holder.reversed, holder.anchored, holder.look = reversed, nil, nil
        holder.liquid = LiquidFor(holder, reversed)
    end
    holder.kind, holder.setting, holder.owner = kind, setting, owner
    holder.width, holder.height = width, height
    holder.mover:SetWidth(width)
    Layer(holder)
    local liquid = holder.liquid
    liquid:SetSize(width + ROOM, height)
    holder.effects = ns.Effects()
    liquid:SetOptions(holder.effects)
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
