-- The liquid on one status bar (Bar.lua), whatever bar it is: ElvUI's unit frame bars and data
-- bars here, a cast bar later. The bar's own fill turns invisible but keeps its size, and the liquid
-- rides on its edge, so ElvUI's own value and smoothing move it. A bar filled from the right gets a
-- mirrored liquid on the fill's left edge. Bars it cannot follow (vertical, no size yet) keep their
-- own fill.

---A plain horizontal status bar of the test client.
local function newBar(client, w, h)
    local bar = CreateFrame("StatusBar", nil, UIParent)
    bar:SetSize(w or 120, h or 20)
    bar.fill = bar:CreateTexture()
    bar.orientation, bar.reverse, bar.color = "HORIZONTAL", false, { 1, 0, 0 }
    return bar
end

describe("a liquid on a bar", function()
    it("hides the bar's fill and rides on its edge, a bar wide", function()
        local client = NewClient()
        local bar = newBar(client)
        local holder = client.ns.Attach(bar, "cast", "fire")
        assert.are.equal(0, bar.fill:GetAlpha())
        assert.is_true(holder.live)
        assert.are.equal(120, holder.mover:GetWidth())
        assert.are.same({ "TOPRIGHT", bar.fill, "TOPRIGHT" }, holder.mover.points[1])
        assert.are.same({ "BOTTOMRIGHT", bar.fill, "BOTTOMRIGHT" }, holder.mover.points[2])
        assert.is_true(holder.clip.clips, "cut off at the bar")
        assert.are.equal(holder.mover, holder.liquid.parent)
        assert.are.equal(20, holder.liquid.height)
        assert.are.equal(120, holder.liquid.edge, "full on its frame")
    end)

    it("takes the plugin's effects", function()
        local client = NewClient()
        local holder = client.ns.Attach(newBar(client), "cast", "fire")
        assert.are.equal(client:db().effects, holder.liquid.opts)
    end)

    it("is made once per bar and follows a new size", function()
        local client = NewClient()
        local bar = newBar(client)
        local first = client.ns.Attach(bar, "cast", "fire")
        bar:SetSize(150, 24)
        local again = client.ns.Attach(bar, "cast", "fire")
        assert.are.equal(first, again)
        assert.are.equal(150, again.mover:GetWidth())
        assert.are.equal(24, again.liquid.height)
    end)

    it("stays as it is when ElvUI configures the bar again", function()
        local client = NewClient()
        local bar = newBar(client)
        local holder = client.ns.Attach(bar, "cast", "fire")
        local liquid, theme = holder.liquid, holder.liquid.theme
        liquid.edge = 50
        client.ns.Attach(bar, "cast", "fire")
        assert.are.equal(theme, liquid.theme, "no new theme, which would reset the liquid")
        assert.are.equal(50, liquid.edge, "not snapped")
        client.ns.Attach(bar, "cast", "luxthos")
        assert.are.equal("Luxthos", liquid.theme.name, "a new look set: taken")
        bar:SetSize(120, 30)
        local before = liquid.theme
        client.ns.Attach(bar, "cast", "luxthos")
        assert.are_not.equal(before, liquid.theme, "a new height: movement scaled again")
    end)

    it("leaves a bar it cannot follow to its own fill", function()
        local client = NewClient()
        local vertical, unsized = newBar(client), newBar(client, 0, 0)
        vertical.orientation = "VERTICAL"
        local secret = newBar(client, SECRET, 20)
        for _, bar in ipairs({ vertical, unsized, secret }) do
            assert.is_nil(client.ns.Attach(bar, "cast", "fire"))
            assert.are.equal(1, bar.fill:GetAlpha())
        end
    end)

    it("is mirrored on a bar filled from the right, riding on the fill's left edge", function()
        local client = NewClient()
        local bar = newBar(client)
        bar.reverse = true
        local holder = client.ns.Attach(bar, "cast", "fire")
        assert.are.equal(0, bar.fill:GetAlpha())
        assert.are.same({ "TOPLEFT", bar.fill, "TOPLEFT" }, holder.mover.points[1])
        assert.are.same({ "BOTTOMLEFT", bar.fill, "BOTTOMLEFT" }, holder.mover.points[2])
        assert.are.equal(holder.mover, holder.liquid.parent.real, "a mirror of the frame")
    end)

    it("turns round with the bar, each way's liquid made once", function()
        local client = NewClient()
        local bar = newBar(client)
        local holder = client.ns.Attach(bar, "cast", "fire")
        local plain = holder.liquid
        bar.reverse = true
        client.ns.Attach(bar, "cast", "fire")
        local mirrored = holder.liquid
        assert.are_not.equal(plain, mirrored)
        assert.is_true(plain.hidden, "the other way's liquid hidden")
        assert.are.same({ "TOPLEFT", bar.fill, "TOPLEFT" }, holder.mover.points[1])
        assert.are.equal("Fire", mirrored.theme.name, "with the bar's look")
        bar.reverse = false
        client.ns.Attach(bar, "cast", "fire")
        assert.are.equal(plain, holder.liquid)
        assert.are.same({ "TOPRIGHT", bar.fill, "TOPRIGHT" }, holder.mover.points[1])
    end)

    it("works on a client that hides nothing", function()
        local client = NewClient({ noSecretCheck = true })
        assert.is_false(client.ns.IsSecret(SECRET))
        assert.is_table(client.ns.Attach(newBar(client), "cast", "fire"))
    end)

    it("goes when a bar turns into one it cannot follow", function()
        local client = NewClient()
        local bar = newBar(client)
        local holder = client.ns.Attach(bar, "cast", "fire")
        bar.orientation = "VERTICAL"
        client.ns.Attach(bar, "cast", "fire")
        assert.is_false(holder.live)
        assert.are.equal(1, bar.fill:GetAlpha())
    end)

    it("goes when detached: the fill back, the liquid hidden", function()
        local client = NewClient()
        local bar = newBar(client)
        local holder = client.ns.Attach(bar, "cast", "fire")
        client.ns.Detach(bar)
        assert.is_false(holder.live)
        assert.is_false(holder.clip:IsShown())
        assert.is_true(holder.liquid.hidden)
        assert.are.equal(1, bar.fill:GetAlpha())
        client.ns.Detach(bar)
        client.ns.Detach(newBar(client))
    end)

    it("keeps the fill hidden and follows a fill the bar swapped", function()
        local client = NewClient()
        local bar = newBar(client)
        local holder = client.ns.Attach(bar, "cast", "fire")
        bar.fill:SetAlpha(1)
        bar.fill = bar:CreateTexture()
        client:Advance(0.5)
        assert.are.equal(0, bar.fill:GetAlpha())
        assert.are.same({ "TOPRIGHT", bar.fill, "TOPRIGHT" }, holder.mover.points[1])
    end)
end)
