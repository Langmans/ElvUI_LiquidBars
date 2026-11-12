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

    it("is the bar's own when switched off", function()
        local client = NewClient()
        client:db().aboveOverlays = false
        client.ns.ApplyAll()
        local bar = client.frames.player.Power
        local base = bar:GetFrameLevel()
        assert.are.same({ base, base + 1, base + 2 }, { levels(client, bar) })
    end)
end)
