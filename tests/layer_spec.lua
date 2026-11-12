-- Where the liquid sits among the bar's frames (Bar.lua). ElvUI puts overlays one and two levels
-- above a bar (its ClipFrame with the power prediction and the cutaway), which drew over the liquid:
-- a grey block for a spell's cost, and on a power bar that was not transparent a cover until ElvUI
-- configured it again. By default the liquid goes above them, still under the bar's texts (ElvUI's
-- raised element parent, far higher); switched off it sits at the bar's own level.

local function levels(client, bar)
    local holder = client.ns.holders[bar]
    return holder.clip:GetFrameLevel(), holder.mover:GetFrameLevel(), holder.front:GetFrameLevel()
end

describe("the liquid's layer", function()
    it("is above ElvUI's overlays on the bar by default", function()
        local client = NewClient()
        local bar = client.frames.player.Power
        local base = bar:GetFrameLevel()
        local clip, mover, front = levels(client, bar)
        assert.are.equal(base + 2, clip)
        assert.are.equal(base + 3, mover)
        assert.are.equal(base + 4, front)
    end)

    it("follows the bar's level when ElvUI configures it again", function()
        local client = NewClient()
        local bar = client.frames.player.Power
        bar:SetFrameLevel(20)
        client:Configure("player")
        assert.are.same({ 22, 23, 24 }, { levels(client, bar) })
    end)

    it("keeps ElvUI's cutaway above the liquid, and gives it back", function()
        local client = NewClient()
        local frame = client.frames.player
        local holder = client.ns.holders[frame.Power]
        assert.are.equal(holder.front, frame.Cutaway.Power:GetParent())
        assert.are.equal(client.ns.holders[frame.Health].front, frame.Cutaway.Health:GetParent())
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

    it("keeps ElvUI's power prediction above the liquid", function()
        local client = NewClient()
        local frame = client.frames.player
        local holder = client.ns.holders[frame.Power]
        local prediction = frame.PowerPrediction.mainBar
        assert.are.equal(holder.front, prediction:GetParent())
        assert.are.equal(holder.front:GetFrameLevel() + 1, prediction:GetFrameLevel())
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
        assert.are.same({ base, base + 1, base + 2 }, { levels(client, bar) })
    end)
end)
