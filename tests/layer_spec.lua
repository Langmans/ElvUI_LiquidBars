-- Where the liquid sits among the bar's frames (Bar.lua). ElvUI puts overlays one and two levels
-- above a bar (its ClipFrame with the power prediction and the cutaway), which drew over the liquid:
-- a grey block for a spell's cost, and on a power bar that was not transparent a cover until ElvUI
-- configured it again. By default the liquid goes above them, still under the bar's texts (ElvUI's
-- raised element parent, far higher); switched off it sits at the bar's own level. ElvUI's cutaway
-- and power prediction then go onto a frame of the plugin's own above the liquid and its front, one
-- that never fades (the front does, on a full bar), the prediction in the liquid's colour.

local function levels(client, bar)
    local holder = client.ns.holders[bar]
    return holder.clip:GetFrameLevel(),
        holder.mover:GetFrameLevel(),
        holder.front:GetFrameLevel(),
        holder.over:GetFrameLevel()
end

describe("the liquid's layer", function()
    it("is above ElvUI's overlays on the bar by default", function()
        local client = NewClient()
        local bar = client.frames.player.Power
        local base = bar:GetFrameLevel()
        assert.are.same({ base + 2, base + 3, base + 4, base + 5 }, { levels(client, bar) })
    end)

    it("follows the bar's level when ElvUI configures it again", function()
        local client = NewClient()
        local bar = client.frames.player.Power
        bar:SetFrameLevel(20)
        client:Configure("player")
        assert.are.same({ 22, 23, 24, 25 }, { levels(client, bar) })
    end)

    it("keeps ElvUI's cutaway above the liquid, and gives it back", function()
        local client = NewClient()
        local frame = client.frames.player
        local holder = client.ns.holders[frame.Power]
        assert.are.equal(holder.over, frame.Cutaway.Power:GetParent())
        assert.are.equal(client.ns.holders[frame.Health].over, frame.Cutaway.Health:GetParent())
        client.ns.Detach(frame.Power)
        assert.are.equal(frame.Power.ClipFrame, frame.Cutaway.Power:GetParent(), "back in ElvUI's ClipFrame")
    end)

    it("leaves the cutaway in ElvUI's ClipFrame when switched off, or without one", function()
        local client = NewClient()
        client:db().aboveOverlays = false
        client.ns.ApplyAll()
        local frame = client.frames.player
        assert.are.equal(frame.Power.ClipFrame, frame.Cutaway.Power:GetParent())
        frame.Cutaway = nil
        client:db().aboveOverlays = true
        client.ns.ApplyAll()
        assert.is_table(client:LiquidOn(frame.Power), "a frame without a cutaway")
    end)

    it("keeps ElvUI's power prediction above the liquid, also on a full bar", function()
        local client = NewClient()
        local frame = client.frames.player
        local holder = client.ns.holders[frame.Power]
        local prediction = frame.PowerPrediction.mainBar
        assert.are.equal(holder.over, prediction:GetParent())
        assert.are.equal(holder.over:GetFrameLevel() + 1, prediction:GetFrameLevel())
        client.percent.player = { power = 1 }
        client:Advance(0.05)
        assert.are.equal(0, holder.front:GetAlpha(), "the front gone on a full bar")
        assert.are.equal(1, holder.over:GetAlpha(), "the prediction's frame stays")
    end)

    it("hides the prediction while it has no range, as after login, and shows it with one", function()
        local client = NewClient()
        local prediction = client.frames.player.PowerPrediction.mainBar
        assert.are.equal(0, prediction:GetAlpha(), "0..0 would fill the whole bar")
        prediction:SetMinMaxValues(0, 314) -- ElvUI updating it for a cast
        assert.are.equal(1, prediction:GetAlpha())
        prediction:SetMinMaxValues(0, 0)
        assert.are.equal(0, prediction:GetAlpha())
        prediction:SetMinMaxValues(0, SECRET)
        assert.are.equal(1, prediction:GetAlpha(), "a range the client hides: shown")
    end)

    it("gives the prediction back to ElvUI on detach and with the option off", function()
        local client = NewClient()
        local frame = client.frames.player
        local prediction = frame.PowerPrediction.mainBar
        client.ns.Detach(frame.Power)
        assert.are.equal(frame.Power.ClipFrame, prediction:GetParent())
        assert.are.equal(1, prediction:GetAlpha())
        prediction:SetMinMaxValues(0, 0)
        assert.are.equal(1, prediction:GetAlpha(), "left alone without a liquid")
        client:db().aboveOverlays = false
        client:Configure("player")
        assert.are.equal(frame.Power.ClipFrame, prediction:GetParent())
    end)

    it("is the bar's own when switched off", function()
        local client = NewClient()
        client:db().aboveOverlays = false
        client.ns.ApplyAll()
        local bar = client.frames.player.Power
        local base = bar:GetFrameLevel()
        assert.are.same({ base, base + 1, base + 2, base + 3 }, { levels(client, bar) })
    end)
end)

describe("the power prediction's colour", function()
    ---The prediction's fill colour as drawn: r, g, b, a.
    local function drawn(prediction)
        local v = prediction.fill.vertex
        return { v[1], v[2], v[3], v[4] }
    end

    ---Whether two colours are the same, to rounding.
    local function near(expected, actual)
        for i = 1, #expected do
            if math.abs(expected[i] - actual[i]) > 1e-9 then return false end
        end
        return true
    end

    it("is the liquid's, darker, and follows its look", function()
        local client = NewClient()
        local frame = client.frames.player
        local prediction = frame.PowerPrediction.mainBar
        assert.is_true(near({ 0, 0.24, 0.6, 0.85 }, drawn(prediction)), "mana: ElvUI's blue, darker")
        frame.Power:SetStatusBarColor(1, 0, 0)
        client:Advance(0.3)
        assert.is_true(near({ 0.6, 0, 0, 0.85 }, drawn(prediction)))
    end)

    it("keeps the hue all round the circle, at a lightness of 0.3", function()
        local client = NewClient()
        local frame = client.frames.player
        local prediction = frame.PowerPrediction.mainBar
        -- One colour per sixth of the hue circle, and which channel is strongest in it.
        for _, case in ipairs({
            { { 1, 0.5, 0 }, 1 },
            { { 0.5, 1, 0 }, 2 },
            { { 0, 1, 0.5 }, 2 },
            { { 0, 0.5, 1 }, 3 },
            { { 0.5, 0, 1 }, 3 },
            { { 1, 0, 0.5 }, 1 },
        }) do
            local color, strongest = case[1], case[2]
            frame.Power:SetStatusBarColor(color[1], color[2], color[3])
            client:Advance(0.3)
            local c = drawn(prediction)
            local high, low = math.max(c[1], c[2], c[3]), math.min(c[1], c[2], c[3])
            assert.is_near(0.3, (high + low) / 2, 1e-9, "lightness")
            assert.are.equal(high, c[strongest], "the same channel strongest")
        end
    end)

    it("is as dark for a light liquid, its hue and saturation kept, for the bar's white text", function()
        local client = NewClient()
        local frame = client.frames.player
        local prediction = frame.PowerPrediction.mainBar
        frame.Power:SetStatusBarColor(0.6, 0.8, 1) -- a light blue: lightness 0.8
        client:Advance(0.3)
        local c = drawn(prediction)
        assert.is_near(0, c[1], 1e-9)
        assert.is_near(0.3, c[2], 1e-9)
        assert.is_near(0.6, c[3], 1e-9, "hue 210, fully saturated, lightness 0.3")
        frame.Power:SetStatusBarColor(0.5, 0.5, 0.5)
        client:Advance(0.3)
        c = drawn(prediction)
        assert.is_near(0.3, c[1], 1e-9, "a grey stays grey")
        assert.is_near(0.3, c[3], 1e-9)
    end)

    it("stays the liquid's when ElvUI colours it again", function()
        local client = NewClient()
        local prediction = client.frames.player.PowerPrediction.mainBar
        prediction:SetStatusBarColor(1, 1, 1, 0.7) -- Eltruism's white
        assert.is_true(near({ 0, 0.24, 0.6, 0.85 }, drawn(prediction)))
    end)

    it("is ElvUI's when switched off, on detach, or for a look without a colour", function()
        local client = NewClient()
        local frame = client.frames.player
        local prediction = frame.PowerPrediction.mainBar
        prediction:SetStatusBarColor(1, 1, 1, 0.7)
        client:db().tintPrediction = false
        client.ns.ApplyAll()
        assert.are.same({ 1, 1, 1, 0.7 }, drawn(prediction))
        client:db().tintPrediction = true
        client.ns.ApplyAll()
        client.ns.Detach(frame.Power)
        assert.are.same({ 1, 1, 1, 0.7 }, drawn(prediction))
        prediction:SetStatusBarColor(1, 1, 1, 0.5)
        assert.are.same({ 1, 1, 1, 0.5 }, drawn(prediction), "left alone without a liquid")
        client:db().power.MANA = "fire" -- a theme of the fake client without a fill colour
        client:Configure("player")
        assert.are.same({ 1, 1, 1, 0.5 }, drawn(prediction))
    end)
end)
