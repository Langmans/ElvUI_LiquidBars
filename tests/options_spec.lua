-- The plugin's page in ElvUI's options (Options.lua): a page per kind of frame (health and power, on
-- or off, the look), the data bars, the look per power type and the effects. Every change applies at
-- once.

---@return table client, table args
local function options()
    local client = NewClient()
    return client, client:LoadOptions().args
end

describe("the options", function()
    it("are not built without ElvUI_Options", function()
        assert.is_nil(NewClient({ noOptions = true }):LoadOptions())
    end)

    it("switch a frame's bar and set its look", function()
        local client, args = options()
        local health = args.units.args.target.args.health
        assert.is_true(health.get({ "on" }))
        health.set({ "on" }, false)
        assert.is_nil(client:LiquidOn(client.frames.target.Health))
        health.set({ "theme" }, "fire")
        assert.are.equal("fire", client:db().units.target.health.theme)
        assert.are.equal("fire", health.get({ "theme" }))
    end)

    it("offer ElvUI's colour and every theme, power bars also by power type", function()
        local _, args = options()
        local healthThemes = args.units.args.player.args.health.args.theme.values
        local powerThemes = args.units.args.player.args.power.args.theme.values
        assert.is_string(healthThemes.elvui)
        assert.are.equal("Fire", healthThemes.fire)
        assert.are.equal("Class Color", healthThemes.class)
        assert.is_nil(healthThemes.power)
        assert.is_string(powerThemes.power)
    end)

    it("switch a data bar and set its look", function()
        local client, args = options()
        local xp = args.data.args.experience
        xp.set({ "on" }, false)
        assert.is_false(xp.get({ "on" }))
        assert.is_nil(client:LiquidOn(client.DB.StatusBars.Experience))
    end)

    it("set the look per power type", function()
        local client, args = options()
        local power = args.power
        assert.is_table(power.args.MANA)
        assert.is_table(power.args.LUNAR_POWER)
        power.set({ "RAGE" }, "fire")
        assert.are.equal("fire", power.get({ "RAGE" }))
        assert.are.equal("fire", client:db().power.RAGE)
    end)

    it("switch the custom level's effects on every liquid", function()
        local client, args = options()
        local custom = args.effects.args.custom
        assert.is_true(custom.get({ "lightning" }))
        custom.set({ "lightning" }, false)
        assert.is_false(client:db().effects.lightning)
        assert.is_false(client:LiquidOn(client.frames.player.Health).opts.lightning)
    end)

    it("set the level per group size and the size of a big raid", function()
        local client, args = options()
        local levels = args.effects.args.levels
        assert.are.equal("custom", levels.get({ "party" }))
        assert.is_string(levels.args.party.values.gentle)
        levels.set({ "party" }, "still")
        assert.are.equal("still", client:db().levels.party)
        assert.is_false(client:LiquidOn(client.frames.player.Health).opts.waves, "applied at once")
        local size = levels.args.size
        assert.are.equal(20, size.get())
        size.set(nil, 10)
        assert.are.equal(10, client:db().bigRaid)
    end)

    it("switch the liquid above ElvUI's overlays", function()
        local client, args = options()
        local above = args.aboveOverlays
        assert.is_true(above.get())
        above.set(nil, false)
        assert.is_false(client:db().aboveOverlays)
        local bar = client.frames.player.Power
        assert.are.equal(bar:GetFrameLevel(), client.ns.holders[bar].clip:GetFrameLevel(), "applied at once")
    end)

    it("switch the fading front", function()
        local client, args = options()
        local fade = args.effects.args.fadeFront
        assert.is_true(fade.get())
        fade.set(nil, false)
        assert.is_false(client:db().fadeFront)
    end)
end)
