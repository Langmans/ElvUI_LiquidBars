-- How much each liquid does (Core.lua), by the size of the group: Smooth Animated Bars' three levels
-- (everything; gentle: waves and swirl only; still: a plain liquid) or the plugin's own effect
-- switches. Solo and in a party the switches (all on), in a raid gentle, in a raid above 20 members
-- still. Every liquid changes level at once when the group does.

---@return table client, table liquid the player's health liquid
local function playing()
    local client = NewClient()
    return client, client:LiquidOn(client.frames.player.Health)
end

describe("the level of the effects", function()
    it("is the effect switches solo and in a party", function()
        local client, liquid = playing()
        assert.are.equal(client:db().effects, liquid.opts)
        client.group.members = 5
        client:Fire("GROUP_ROSTER_UPDATE")
        assert.are.equal(client:db().effects, liquid.opts)
    end)

    it("turns gentle in a raid and still in a big raid, on every liquid at once", function()
        local client, liquid = playing()
        local xp = client:LiquidOn(client.DB.StatusBars.Experience)
        client.group = { raid = true, members = 12 }
        client:Fire("GROUP_ROSTER_UPDATE")
        assert.is_true(liquid.opts.waves)
        assert.is_true(liquid.opts.swirl)
        assert.is_false(liquid.opts.sparkles)
        assert.is_false(liquid.opts.lightning)
        client.group.members = 25
        client:Fire("GROUP_ROSTER_UPDATE")
        assert.is_false(liquid.opts.waves)
        assert.is_false(xp.opts.swirl)
        client.group = { raid = false, members = 0 }
        client:Fire("GROUP_ROSTER_UPDATE")
        assert.are.equal(client:db().effects, liquid.opts)
    end)

    it("counts a small raid as a party", function()
        local client, liquid = playing()
        client.group = { raid = true, members = 4 }
        client:Fire("GROUP_ROSTER_UPDATE")
        assert.are.equal(client:db().effects, liquid.opts)
    end)

    it("follows the levels and the size set", function()
        local client, liquid = playing()
        local db = client:db()
        db.levels.party = "full"
        db.bigRaid = 10
        client.ns.ApplyAll()
        assert.is_true(liquid.opts.lightning)
        assert.are_not.equal(db.effects, liquid.opts)
        client.group = { raid = true, members = 12 }
        client:Fire("GROUP_ROSTER_UPDATE")
        assert.is_false(liquid.opts.waves, "above 10: still")
    end)

    it("is given to a liquid made in a raid", function()
        local client = NewClient()
        client.group = { raid = true, members = 30 }
        client.ns.Detach(client.frames.focus.Health)
        client:Configure("focus")
        assert.is_false(client:LiquidOn(client.frames.focus.Health).opts.waves)
    end)
end)
