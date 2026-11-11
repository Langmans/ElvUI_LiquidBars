-- The liquid's front (Bar.lua): the bright line and the glow on its edge. On a full bar it would sit
-- against the bar's end, so it fades out from 97% to 100%. Its textures go onto a frame of their own
-- whose alpha the plugin sets. For a unit's health and power the client's own percentage is evaluated
-- on a curve, which works with values the client hides; other bars go by their values.

describe("the front", function()
    it("sits on a frame of its own", function()
        local client = NewClient()
        local holder = client.ns.holders[client.frames.player.Health]
        local liquid = holder.liquid
        assert.are.equal(holder.front, liquid.tips[1]:GetParent())
        assert.are.equal(holder.front, liquid.tips[2]:GetParent())
        assert.are.equal(holder.front, liquid.glow:GetParent())
    end)

    it("fades out as a unit's bar fills, by the client's own percentage", function()
        local client = NewClient()
        local front = client.ns.holders[client.frames.player.Health].front
        local power = client.ns.holders[client.frames.player.Power].front
        client.percent.player = { health = 1, power = 0.5 }
        client:Advance(0.05)
        assert.are.equal(0, front:GetAlpha(), "full: gone")
        assert.are.equal(1, power:GetAlpha(), "half: shown")
        client.percent.player.health = 0.985
        client:Advance(0.05)
        assert.is_near(0.5, front:GetAlpha(), 1e-9, "on its way out")
    end)

    it("passes a percentage the client hides straight on", function()
        local client = NewClient()
        local front = client.ns.holders[client.frames.target.Health].front
        client.percent.target = { health = SECRET }
        client:Advance(0.05)
        assert.are.equal(SECRET, front:GetAlpha())
    end)

    it("fades out on a data bar by its value", function()
        local client = NewClient()
        local bar = client.DB.StatusBars.Experience
        local front = client.ns.holders[bar].front
        bar.value, bar.min, bar.max = 400, 0, 400
        client:Advance(0.05)
        assert.are.equal(0, front:GetAlpha())
        bar.value = 394
        client:Advance(0.05)
        assert.is_near(0.5, front:GetAlpha(), 1e-9)
        bar.value = 100
        client:Advance(0.05)
        assert.are.equal(1, front:GetAlpha())
    end)

    it("stays for values it cannot read, an empty range, a client without curves", function()
        local client = NewClient({ noCurves = true })
        local bar = client.frames.player.Health
        local front = client.ns.holders[bar].front
        bar.value, bar.max = 100, 100
        client:Advance(0.05)
        assert.are.equal(0, front:GetAlpha(), "no curves: by the bar's own value")
        bar.value = SECRET
        client:Advance(0.05)
        assert.are.equal(1, front:GetAlpha(), "a hidden value")
        bar.value, bar.max = 0, 0
        client:Advance(0.05)
        assert.are.equal(1, front:GetAlpha(), "no range")
    end)

    it("stays when its unit is gone", function()
        local client = NewClient()
        local frame = client.frames.target
        frame.__unit = nil
        client.percent.target = { health = 1 }
        frame.Health.value = 50
        client:Advance(0.05)
        assert.are.equal(1, client.ns.holders[frame.Health].front:GetAlpha())
    end)

    it("stays when switched off", function()
        local client = NewClient()
        client:db().fadeFront = false
        client.percent.player = { health = 1 }
        client:Advance(0.05)
        assert.are.equal(1, client.ns.holders[client.frames.player.Health].front:GetAlpha())
    end)
end)
