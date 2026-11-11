-- Which bars get a liquid (Core.lua): the health and power bars of ElvUI's unit frames and its data
-- bars, each as set. Whenever ElvUI configures a frame's bars or updates its data bars, the plugin
-- follows. Party frames are off by default: a liquid per frame adds up.

describe("the bars", function()
    it("of the unit frames get a liquid, party off by default", function()
        local client = NewClient()
        for _, key in ipairs({ "player", "target", "focus", "pet", "targettarget" }) do
            assert.is_table(client:LiquidOn(client.frames[key].Health), key)
            assert.is_table(client:LiquidOn(client.frames[key].Power), key)
        end
        assert.is_nil(client:LiquidOn(client.frames.party.Health))
        assert.is_nil(client:LiquidOn(client.frames.party.Power))
    end)

    it("of the data bars get a liquid", function()
        local client = NewClient()
        for _, key in ipairs({ "Experience", "Reputation", "PetExperience" }) do
            assert.is_table(client:LiquidOn(client.DB.StatusBars[key]), key)
        end
    end)

    it("follow ElvUI configuring a frame", function()
        local client = NewClient()
        local db = client:db().units
        db.party.health.on = true
        db.player.power.on = false
        client:Configure("party"):Configure("player")
        assert.is_table(client:LiquidOn(client.frames.party.Health))
        assert.is_nil(client:LiquidOn(client.frames.player.Power))
        assert.are.equal(1, client.frames.player.Power.fill:GetAlpha())
    end)

    it("follow ElvUI updating its data bars", function()
        local client = NewClient()
        client:db().data.reputation.on = false
        client.DB:UpdateAll()
        assert.is_nil(client:LiquidOn(client.DB.StatusBars.Reputation))
    end)

    it("skip a frame the plugin does not know, and a missing part", function()
        local client = NewClient()
        local raid = client.frames.party
        raid.unitframeType = "raid1"
        raid.Power = nil
        client.UF:Configure_HealthBar(raid)
        client.frames.player.Power = nil
        client:Configure("player")
        assert.is_nil(client:LiquidOn(raid.Health))
    end)

    it("skip a data bar ElvUI does not have", function()
        local client = NewClient()
        client.DB.StatusBars.PetExperience = nil
        client.DB:UpdateAll()
        assert.is_table(client:LiquidOn(client.DB.StatusBars.Experience))
    end)

    it("all follow a change in the settings at once", function()
        local client = NewClient()
        client:db().units.target.health.on = false
        client:db().data.experience.on = false
        client.ns.ApplyAll()
        assert.is_nil(client:LiquidOn(client.frames.target.Health))
        assert.is_nil(client:LiquidOn(client.DB.StatusBars.Experience))
    end)
end)
