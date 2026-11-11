-- What a liquid looks like (Bar.lua): ElvUI's own colour for the bar, a Smooth Animated Bars theme,
-- or for a power bar the theme set for its power type, so a druid's bar changes with each form.
-- Themes that pick their colour per unit (Class Color) do so again when the unit changes. Movement
-- is scaled down for low bars, as the themes are made for an experience bar. A look is made once per
-- choice, colour (in steps of a twentieth) and height, and a liquid only gets a new one when it is
-- another: Smooth Animated Bars' SetTheme builds a dozen tables and drops the liquid's particles.

describe("the look", function()
    it("is made once per colour and height, shared by bars", function()
        local client = NewClient()
        local player = client:LiquidOn(client.frames.player.Health)
        local target = client:LiquidOn(client.frames.target.Health)
        assert.are.equal(player.theme, target.theme)
        assert.are_not.equal(player.theme, client:LiquidOn(client.frames.player.Power).theme, "another colour")
    end)

    it("follows ElvUI's colour in steps, not with each small change", function()
        local client = NewClient()
        local bar = client.frames.player.Health
        local liquid = client:LiquidOn(bar)
        local theme, sets = liquid.theme, liquid.sets
        bar:SetStatusBarColor(0.11, 0.79, 0.1) -- ElvUI colouring by value, a little less health
        client:Advance(0.5)
        assert.are.equal(theme, liquid.theme)
        assert.are.equal(sets, liquid.sets, "SetTheme not called")
        bar:SetStatusBarColor(0.3, 0.6, 0.1)
        client:Advance(0.5)
        assert.are.same({ 0.3, 0.6, 0.1 }, liquid.theme.color)
    end)

    it("is made again after a change in the settings", function()
        local client = NewClient()
        local before = client:LiquidOn(client.frames.player.Health).theme
        client.ns.ApplyAll()
        client.ns.Detach(client.frames.player.Health)
        client:Configure("player")
        assert.are_not.equal(before, client:LiquidOn(client.frames.player.Health).theme)
    end)

    it("is ElvUI's own colour by default, and follows it", function()
        local client = NewClient()
        local bar = client.frames.player.Health
        local liquid = client:LiquidOn(bar)
        assert.are.same({ 0.1, 0.8, 0.1 }, liquid.theme.color)
        local theme = liquid.theme
        client:Advance(0.5)
        assert.are.equal(theme, liquid.theme, "no new theme while the colour stays")
        bar:SetStatusBarColor(1, 0, 0)
        client:Advance(0.5)
        assert.are.same({ 1, 0, 0 }, liquid.theme.color)
    end)

    it("keeps its colour while the client hides the bar's", function()
        local client = NewClient()
        local bar = client.frames.player.Health
        local liquid = client:LiquidOn(bar)
        bar.color = { SECRET, SECRET, SECRET }
        client:Advance(0.5)
        assert.are.same({ 0.1, 0.8, 0.1 }, liquid.theme.color)
    end)

    it("is a theme when one is set", function()
        local client = NewClient()
        client:db().units.player.health.theme = "fire"
        client:Configure("player")
        local liquid = client:LiquidOn(client.frames.player.Health)
        assert.are.equal("Fire", liquid.theme.name)
    end)

    it("of a power bar is its power type's", function()
        local client = NewClient()
        local db = client:db()
        db.power.RAGE = "fire"
        local liquid = client:LiquidOn(client.frames.player.Power)
        assert.are.same({ 0, 0.4, 1 }, liquid.theme.color, "mana: ElvUI's colour")
        client.powerTypes.player = { 1, "RAGE" }
        client:Fire("UNIT_DISPLAYPOWER", "player")
        assert.are.equal("Fire", liquid.theme.name, "bear form")
        assert.are.equal(1, liquid.splashes[#liquid.splashes][1], "a big splash for the change")
        client.powerTypes.player = { 8, "LUNAR_POWER" }
        client:Fire("UNIT_DISPLAYPOWER", "player")
        assert.is_table(liquid.theme.color, "a power type without a setting: ElvUI's colour")
    end)

    it("by power type, on a bar given a unit rather than a frame, takes that unit's", function()
        local client = NewClient()
        client:db().power.ENERGY = "fire"
        client.powerTypes.pet = { 3, "ENERGY" }
        local bar = client.DB.StatusBars.PetExperience
        local holder = client.ns.Attach(bar, "cast", "power", "pet")
        assert.are.equal("Fire", holder.liquid.theme.name)
    end)

    it("changes form only on the bars of that unit", function()
        local client = NewClient()
        local target = client:LiquidOn(client.frames.target.Power)
        client:Fire("UNIT_DISPLAYPOWER", "player")
        assert.are.equal(0, #target.splashes)
    end)

    it("by class colour picks the unit's, else ElvUI's, and again for a new target", function()
        local client = NewClient()
        client:db().units.target.health.theme = "class"
        client.classColors.target = { 0.6, 0.2, 1 }
        client:Configure("target")
        local liquid = client:LiquidOn(client.frames.target.Health)
        assert.are.same({ 0.6, 0.2, 1 }, liquid.theme.color)
        client.classColors.target = nil
        client:Fire("PLAYER_TARGET_CHANGED")
        assert.are.same({ 0.1, 0.8, 0.1 }, liquid.theme.color, "a mob: the bar's own colour")
    end)

    it("by class colour picks again on entering the world, for a frame configured without a unit", function()
        local client = NewClient()
        local frame = client.frames.target
        frame.__unit = nil
        client:db().units.target.health.theme = "class"
        client:Configure("target")
        local liquid = client:LiquidOn(frame.Health)
        assert.are.same({ 0.1, 0.8, 0.1 }, liquid.theme.color, "no unit yet: the bar's colour")
        frame.__unit = "target"
        client.classColors.target = { 0.6, 0.2, 1 }
        client:Fire("PLAYER_ENTERING_WORLD")
        assert.are.same({ 0.6, 0.2, 1 }, liquid.theme.color)
    end)

    it("of a theme that does not pick by unit stays when the unit changes", function()
        local client = NewClient()
        local liquid = client:LiquidOn(client.frames.player.Health)
        local theme = liquid.theme
        client:Fire("PLAYER_TARGET_CHANGED"):Fire("GROUP_ROSTER_UPDATE")
        assert.are.equal(theme, liquid.theme, "no new theme, which would reset the liquid")
    end)

    it("by class colour picks again for the target's target, not for every unit's", function()
        local client = NewClient()
        client:db().units.targettarget.health.theme = "class"
        client:Configure("targettarget")
        local liquid = client:LiquidOn(client.frames.targettarget.Health)
        local theme = liquid.theme
        client:Fire("UNIT_TARGET", "nameplate3")
        assert.are.equal(theme, liquid.theme, "a mob in the crowd changed target")
        client.classColors.targettarget = { 0.6, 0.2, 1 }
        client:Fire("UNIT_TARGET", "target")
        assert.are.same({ 0.6, 0.2, 1 }, liquid.theme.color)
    end)

    it("moves less on a low bar", function()
        local client = NewClient()
        client:db().units.player.health.theme = "luxthos"
        client:db().units.player.power.theme = "luxthos"
        client:Configure("player")
        local health = client:LiquidOn(client.frames.player.Health).theme.physics
        local power = client:LiquidOn(client.frames.player.Power).theme.physics
        assert.is_near(7.5, health.amplitude, 1e-9, "30 px high: three quarters")
        assert.is_near(2.5, power.amplitude, 1e-9, "10 px: a quarter, the least")
        assert.is_near(0.25 * 0.18, power.slosh, 1e-9)
        local fire = client.ns.Scaled({ name = "no physics" }, 40).physics
        assert.are.equal(10, fire.amplitude, "the defaults, at full size")
    end)
end)
