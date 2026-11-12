-- A simulated WoW: Forever client for the plugin. The game: frames, status bars and textures as far
-- as the plugin uses them, unit power types, timers and events. ElvUI: E with its profile and global
-- data, the UnitFrames module (Configure_HealthBar, Configure_Power) with oUF's frames, the DataBars
-- module (UpdateAll, StatusBars), LibElvUIPlugin and the options table. Smooth Animated Bars: the
-- .toc's ..\SmoothAnimatedBars lines get a fake Liquid class and Themes table (below), since the real
-- files live in the game folder only.
-- NewClient() resets the globals, loads the .toc's files and logs in.

---@class TestClientOptions
---@field name string? the addon's folder name, the repository's by default
---@field dev boolean? a copy straight from the repository: `--@debug@` blocks run (Dev.lua)
---@field noOptions boolean? ElvUI_Options not loaded
---@field noSecretCheck boolean? a client without issecretvalue, which hides nothing
---@field noCurves boolean? a client without C_CurveUtil and the unit percent functions

-- What the client returns for a value it hides (issecretvalue says so).
SECRET = setmetatable({}, {
    __tostring = function()
        return "<secret>"
    end,
})

-- The size of each bar, as ElvUI's defaults roughly have them.
local SIZES = { Health = { 200, 30 }, Power = { 200, 10 }, data = { 400, 10 } }

---A file's source as the client gets it: from a release, where the packager comments out every line
---between `--@debug@` and `--@end-debug@`, unless `dev`.
---@param file string
---@param dev boolean
---@return string
local function AsPackaged(file, dev)
    local handle = assert(io.open(file, "rb"))
    local source = handle:read("*a")
    handle:close()
    if dev or not source:find("--@debug@", 1, true) then return source end
    local lines, inDebug = {}, false
    for line in (source .. "\n"):gmatch("(.-)\r?\n") do
        if line:match("^%s*%-%-@end%-debug@") then
            inDebug = false
        elseif inDebug then
            line = "--" .. line
        elseif line:match("^%s*%-%-@debug@") then
            inDebug = true
        end
        lines[#lines + 1] = line
    end
    return table.concat(lines, "\n")
end

---@param opts TestClientOptions?
function NewClient(opts)
    opts = opts or {}
    local name = opts.name or ADDON_NAME
    local client = {
        now = 1000,
        calls = {},
        events = {},
        modules = {},
        ns = {},
        frames = {},
        timers = {},
        printed = {},
        screenshots = 0,
        liquids = {},
        powerTypes = { player = { 0, "MANA" } },
        classColors = {},
        sabFiles = {},
    }

    local function record(what, ...)
        client.calls[#client.calls + 1] = { what, ... }
    end
    ---The calls recorded under a name, each without it.
    function client:called(what)
        local found = {}
        for _, call in ipairs(self.calls) do
            if call[1] == what then found[#found + 1] = { unpack(call, 2) } end
        end
        return found
    end

    issecretvalue = not opts.noSecretCheck and function(v)
        return v == SECRET
    end or nil
    function GetTime()
        return client.now
    end
    function print(...)
        client.printed[#client.printed + 1] = table.concat({ ... }, " ")
    end
    function Screenshot()
        client.screenshots = client.screenshots + 1
    end
    function wipe(t)
        for k in pairs(t) do
            t[k] = nil
        end
        return t
    end
    function tContains(t, value)
        for _, v in ipairs(t) do
            if v == value then return true end
        end
        return false
    end
    function hooksecurefunc(object, method, hook)
        local original = object[method]
        object[method] = function(...)
            local results = { original(...) }
            hook(...)
            return unpack(results)
        end
    end
    C_Timer = {
        After = function(delay, fn)
            client.timers[#client.timers + 1] = { at = client.now + delay, fn = fn }
        end,
    }
    -- The group: client.group.raid and .members, as the tests set them.
    client.group = { raid = false, members = 0 }
    function IsInRaid()
        return client.group.raid
    end
    function GetNumGroupMembers()
        return client.group.members
    end

    -- Curves and the client's own percentages: client.percent[unit] = { health = 0..1, power = 0..1 },
    -- full where not set. A client without curves (opts.noCurves) has neither.
    Enum = { LuaCurveType = { Linear = 0 } }
    client.percent = {}
    if not opts.noCurves then
        local Curve = {}
        Curve.__index = Curve
        function Curve:SetType(kind)
            self.kind = kind
        end
        function Curve:AddPoint(x, y)
            self.points[#self.points + 1] = { x, y }
        end
        ---Linear between the points, flat beyond them.
        function Curve:Evaluate(x)
            local points = self.points
            if x <= points[1][1] then return points[1][2] end
            for i = 2, #points do
                local a, b = points[i - 1], points[i]
                if x <= b[1] then return a[2] + (b[2] - a[2]) * (x - a[1]) / (b[1] - a[1]) end
            end
            return points[#points][2]
        end
        C_CurveUtil = {
            CreateCurve = function()
                return setmetatable({ points = {} }, Curve)
            end,
        }
        local function percent(unit, kind, curve)
            local p = client.percent[unit] and client.percent[unit][kind] or 1
            if p == SECRET then return SECRET end
            return curve and curve:Evaluate(p) or p
        end
        function UnitHealthPercent(unit, _, curve)
            return percent(unit, "health", curve)
        end
        function UnitPowerPercent(unit, _, _, curve)
            return percent(unit, "power", curve)
        end
    else
        C_CurveUtil, UnitHealthPercent, UnitPowerPercent = nil, nil, nil
    end

    function UnitPowerType(unit)
        local t = client.powerTypes[unit] or { 0, "MANA" }
        return t[1], t[2]
    end

    ---------------------------------------------------------------------------
    -- Frames
    ---------------------------------------------------------------------------

    local shown = {} -- every frame with an OnUpdate script, for Advance

    local Region = {}
    Region.__index = Region
    function Region:SetPoint(...)
        self.points[#self.points + 1] = { ... }
    end
    function Region:ClearAllPoints()
        self.points = {}
    end
    function Region:SetAllPoints(other)
        self.points = { { "ALL", other } }
    end
    function Region:SetSize(w, h)
        self.width, self.height = w, h
        local script = self.scripts and self.scripts.OnSizeChanged
        if script then script(self, w, h) end
    end
    function Region:SetWidth(w)
        self.width = w
    end
    function Region:SetHeight(h)
        self.height = h
    end
    function Region:GetWidth()
        return self.width
    end
    function Region:GetHeight()
        return self.height
    end
    function Region:Show()
        self.shown = true
    end
    function Region:Hide()
        self.shown = false
    end
    function Region:SetShown(on)
        self.shown = on and true or false
    end
    function Region:IsShown()
        return self.shown
    end
    function Region:IsVisible()
        local r = self
        while r do
            if not r.shown then return false end
            r = r.parent
        end
        return true
    end
    function Region:SetAlpha(a)
        self.alpha = a
    end
    function Region:SetParent(parent)
        self.parent = parent
    end
    function Region:GetParent()
        return self.parent
    end
    function Region:GetAlpha()
        return self.alpha
    end
    ---As a texture's: a fourth value sets its alpha too (ElvUI's transparent bars).
    function Region:SetVertexColor(r, g, b, a)
        self.vertex = { r, g, b, a }
        if a then self.alpha = a end
    end
    function Region:SetTexCoord(...)
        self.texCoord = { ... }
    end
    function Region:SetGradient(orientation, from, to)
        self.gradient = { orientation, from, to }
    end
    function Region:SetRotation(radians)
        self.rotation = radians
    end

    local function NewRegion(kind, parent)
        return setmetatable(
            { kind = kind, parent = parent, points = {}, shown = true, alpha = 1, width = 0, height = 0 },
            Region
        )
    end

    local Frame = setmetatable({}, { __index = Region })
    Frame.__index = Frame
    function Frame:SetScript(script, fn)
        self.scripts[script] = fn
        if script == "OnUpdate" then shown[self] = fn and true or nil end
    end
    function Frame:GetScript(script)
        return self.scripts[script]
    end
    function Frame:HookScript(script, fn)
        local original = self.scripts[script]
        self.scripts[script] = function(...)
            if original then original(...) end
            fn(...)
        end
    end
    function Frame:RegisterEvent(event)
        self.registered[event] = true
    end
    function Frame:UnregisterEvent(event)
        self.registered[event] = nil
    end
    function Frame:SetFrameLevel(level)
        self.level = level
    end
    function Frame:GetFrameLevel()
        return self.level
    end
    function Frame:SetClipsChildren(on)
        self.clips = on
    end
    function Frame:CreateTexture()
        return NewRegion("Texture", self)
    end
    -- Status bars.
    function Frame:GetStatusBarTexture()
        return self.fill
    end
    ---As the client's: the colour goes onto the fill texture too.
    function Frame:SetStatusBarColor(r, g, b, a)
        self.color = { r, g, b, a or 1 }
        if self.fill then self.fill.vertex = { r, g, b, a or 1 } end
    end
    function Frame:GetStatusBarColor()
        return self.color[1], self.color[2], self.color[3], self.color[4] or 1
    end
    function Frame:SetOrientation(o)
        self.orientation = o
    end
    function Frame:GetOrientation()
        return self.orientation
    end
    function Frame:SetReverseFill(on)
        self.reverse = on
    end
    function Frame:GetReverseFill()
        return self.reverse
    end
    ---The bar's value and range: bar.value, bar.min, bar.max, half full where not set.
    function Frame:GetValue()
        return self.value or 50
    end
    function Frame:GetMinMaxValues()
        return self.min or 0, self.max or 100
    end
    function Frame:SetMinMaxValues(low, high)
        self.min, self.max = low, high
    end

    client.allFrames = {}
    function CreateFrame(kind, _, parent)
        local f = NewRegion(kind, parent)
        f.scripts, f.registered, f.level = {}, {}, parent and parent.level or 1
        setmetatable(f, Frame)
        client.allFrames[#client.allFrames + 1] = f
        return f
    end
    UIParent = CreateFrame("Frame")

    ---A status bar as ElvUI makes one: horizontal, filled from the left, in a colour.
    local function NewBar(parent, w, h)
        local bar = CreateFrame("StatusBar", nil, parent)
        bar:SetSize(w, h)
        bar.fill = bar:CreateTexture()
        bar.orientation, bar.reverse = "HORIZONTAL", false
        bar.color = { 0.1, 0.8, 0.1 }
        return bar
    end

    ---------------------------------------------------------------------------
    -- Smooth Animated Bars' Liquid and Themes, faked: what the plugin calls, recorded.
    ---------------------------------------------------------------------------

    local Liquid = {}
    Liquid.__index = Liquid
    function Liquid.New(parent, width, height, theme, options)
        local l = setmetatable({
            parent = parent,
            width = width,
            height = height,
            theme = theme,
            opts = options,
            splashes = {},
            updates = 0,
            dt = 0,
            quiet = false,
        }, Liquid)
        -- The front: the bright line's slices and the glow, as the real liquid makes them.
        l.tips = { parent:CreateTexture(), parent:CreateTexture() }
        l.glow = parent:CreateTexture()
        client.liquids[#client.liquids + 1] = l
        return l
    end
    function Liquid:SetTheme(theme)
        self.theme = theme
        self.sets = (self.sets or 0) + 1
    end
    function Liquid:SetSize(w, h)
        self.width, self.height = w, h
    end
    function Liquid:SetOptions(options)
        self.opts = options
    end
    function Liquid:Snap(edge)
        self.edge = edge
    end
    function Liquid:Splash(intensity, from, to)
        self.splashes[#self.splashes + 1] = { intensity, from, to }
    end
    function Liquid:Update(dt, edge)
        self.updates, self.dt, self.edge = self.updates + 1, self.dt + dt, edge
    end
    function Liquid:HideAll()
        self.hidden = true
    end
    function Liquid:IsQuiet()
        return self.quiet
    end

    local Themes = { list = {}, order = {}, default = "luxthos" }
    function Themes.Register(key, theme)
        Themes.list[key] = theme
        Themes.order[#Themes.order + 1] = key
    end
    function Themes.Get(key)
        return Themes.list[key] or Themes.list[Themes.default]
    end
    function Themes.FromColor(c, template)
        return setmetatable({ color = c, fillB = c }, { __index = template })
    end
    function Themes.UnitColor(unit)
        return client.classColors[unit]
    end
    Themes.Register("luxthos", { name = "Luxthos", physics = { amplitude = 10, crest = 7, ambient = 1, slosh = 0.18 } })
    Themes.Register("fire", { name = "Fire" })
    Themes.Register("class", {
        name = "Class Color",
        Resolve = function(self, unit)
            local c = Themes.UnitColor(unit)
            if c then return Themes.FromColor(c, self) end
            return nil
        end,
    })

    ---The fake for one of Smooth Animated Bars' files, put into the loading addon's namespace as the
    ---real one would be.
    local function LoadSAB(file, ns)
        client.sabFiles[#client.sabFiles + 1] = file
        if file:match("Liquid%.lua$") then
            ns.Liquid = Liquid
        elseif file:match("Themes%.lua$") then
            ns.Themes = Themes
        end
    end

    ---------------------------------------------------------------------------
    -- ElvUI
    ---------------------------------------------------------------------------

    local E = {
        db = {},
        global = {},
        oUF = { objects = {} },
    }
    local P, G = {}, {}
    client.E = E
    local UF = { name = "UnitFrames" }
    function UF:Configure_HealthBar() end
    function UF:Configure_Power() end
    local DB = { name = "DataBars", StatusBars = {} }
    function DB:UpdateAll() end
    client.UF, client.DB = UF, DB
    function E:GetModule(module)
        return module == "UnitFrames" and UF or DB
    end
    function E:NewModule(module)
        local m = { name = module }
        client.modules[module] = m
        function m:GetName()
            return self.name
        end
        ---As AceHook's SecureHook: the handler runs after the original, with its arguments.
        function m:SecureHook(object, method, handler)
            hooksecurefunc(object, method, function(...)
                m[handler](m, ...)
            end)
        end
        function m:RegisterEvent(event, handler)
            client.events[event] = handler or event
        end
        return m
    end
    function E:RegisterModule(module)
        record("RegisterModule", module)
    end
    ElvUI = { E, {}, {}, P, G }

    local L = setmetatable({}, {
        __newindex = function(t, k, v)
            rawset(t, k, v)
        end,
    })
    local libs = {
        ["AceLocale-3.0"] = {
            NewLocale = function()
                return L
            end,
            GetLocale = function()
                return L
            end,
        },
        ["LibElvUIPlugin-1.0"] = {
            RegisterPlugin = function(_, plugin, callback)
                record("RegisterPlugin", plugin)
                client.insertOptions = callback
            end,
        },
    }
    function LibStub(lib)
        return libs[lib]
    end

    -- oUF's frames: each kind of frame the plugin knows, with ElvUI's unitframeType and oUF's unit.
    local UNITS = {
        player = "player",
        target = "target",
        focus = "focus",
        pet = "pet",
        targettarget = "targettarget",
        party = "party1",
    }
    for key, unit in pairs(UNITS) do
        local frame = CreateFrame("Button", nil, UIParent)
        frame.unitframeType, frame.__unit = key, unit
        frame.Health = NewBar(frame, SIZES.Health[1], SIZES.Health[2])
        frame.Power = NewBar(frame, SIZES.Power[1], SIZES.Power[2])
        frame.Power.color = { 0, 0.4, 1 }
        -- ElvUI's ClipFrame on each bar, and the cutaway's textures in them (UF:Construct_Cutaway).
        frame.Health.ClipFrame = CreateFrame("Frame", nil, frame.Health)
        frame.Power.ClipFrame = CreateFrame("Frame", nil, frame.Power)
        frame.Cutaway = {
            Health = frame.Health.ClipFrame:CreateTexture(),
            Power = frame.Power.ClipFrame:CreateTexture(),
        }
        -- ElvUI's power prediction bar in the power bar's ClipFrame, with no range yet (as after login).
        local prediction = CreateFrame("StatusBar", nil, frame.Power.ClipFrame)
        prediction.fill = prediction:CreateTexture()
        prediction.min, prediction.max = 0, 0
        prediction:SetStatusBarColor(1, 1, 1, 0.7)
        frame.PowerPrediction = { mainBar = prediction }
        client.frames[key] = frame
        E.oUF.objects[#E.oUF.objects + 1] = frame
    end
    for _, key in ipairs({ "Experience", "Reputation", "PetExperience" }) do
        DB.StatusBars[key] = NewBar(UIParent, SIZES.data[1], SIZES.data[2])
    end

    ---------------------------------------------------------------------------
    -- Loading and logging in
    ---------------------------------------------------------------------------

    for _, file in ipairs(TOC_FILES) do
        if file:match("^%.%./SmoothAnimatedBars/") then
            LoadSAB(file, client.ns)
        else
            assert(loadstring(AsPackaged(file, opts.dev), "@" .. file))(name, client.ns)
        end
    end

    -- ElvUI fills the profile and global data from the defaults, then initialises its modules.
    local function deepCopy(t)
        local c = {}
        for k, v in pairs(t) do
            c[k] = type(v) == "table" and deepCopy(v) or v
        end
        return c
    end
    for key, value in pairs(P) do
        E.db[key] = deepCopy(value)
    end
    for key, value in pairs(G) do
        E.global[key] = deepCopy(value)
    end
    for _, m in pairs(client.modules) do
        if m.Initialize then m:Initialize() end
    end

    ---An event, to the plugin's module and to every frame registered for it.
    function client:Fire(event, ...)
        local handler = self.events[event]
        if handler then
            local m = assert(next(self.modules) and self.modules[name])
            m[handler](m, event, ...)
        end
        for _, f in ipairs(self.allFrames) do
            if f.registered[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
        end
        return self
    end

    ---Time passes in steps of 0.05 s: every frame's OnUpdate runs while it is shown, timers fire.
    function client:Advance(seconds)
        local step = 0.05
        local done = 0
        while done < seconds - 1e-9 do
            local dt = math.min(step, seconds - done)
            self.now = self.now + dt
            done = done + dt
            for f in pairs(shown) do
                if f:IsShown() and f.scripts.OnUpdate then f.scripts.OnUpdate(f, dt) end
            end
            local due = {}
            for i = #self.timers, 1, -1 do
                if self.timers[i].at <= self.now then due[#due + 1] = table.remove(self.timers, i) end
            end
            for i = #due, 1, -1 do
                due[i].fn()
            end
        end
        return self
    end

    ---ElvUI_Options loads: the plugin's page, as LibElvUIPlugin would insert it.
    function client:LoadOptions()
        if opts.noOptions then return nil end
        E.Options = { args = {} }
        self.insertOptions()
        return E.Options.args[name]
    end

    ---The plugin's settings in the profile.
    function client:db()
        return E.db[name]
    end

    ---ElvUI configures a frame's bars again, as after a change in its own options.
    function client:Configure(key)
        local frame = self.frames[key]
        UF:Configure_HealthBar(frame)
        UF:Configure_Power(frame)
        return self
    end

    ---The liquid on a bar, if the plugin put one there.
    function client:LiquidOn(bar)
        local holder = self.ns.holders[bar]
        return holder and holder.live and holder.liquid or nil
    end

    return client
end
