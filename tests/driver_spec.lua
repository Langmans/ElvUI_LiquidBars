-- One frame drives every liquid (Bar.lua): each frame the liquids on bars that show move on, those
-- hidden (no focus, no pet, a data bar switched off) cost nothing. A liquid at rest moves on at 30
-- frames a second only. With no liquid at all the driver is hidden.

describe("the driver", function()
    it("moves the liquids on bars that show, not hidden ones", function()
        local client = NewClient()
        local player = client:LiquidOn(client.frames.player.Health)
        local focus = client:LiquidOn(client.frames.focus.Health)
        client.frames.focus:Hide()
        client:Advance(0.5)
        assert.are.equal(10, player.updates)
        assert.is_near(0.5, player.dt, 1e-9)
        assert.are.equal(200, player.edge)
        assert.are.equal(0, focus.updates)
    end)

    it("moves a liquid at rest at 30 frames a second, with the time gone by", function()
        local client = NewClient()
        local liquid = client:LiquidOn(client.frames.player.Health)
        liquid.quiet = true
        local driver = client.ns.driver
        for _ = 1, 50 do
            driver.scripts.OnUpdate(driver, 0.01)
        end
        assert.are.equal(12, liquid.updates, "every fourth frame of a hundred a second")
        assert.is_near(0.48, liquid.dt, 1e-9)
    end)

    it("hides with no liquid left, and shows again with one", function()
        local client = NewClient()
        local driver = client.ns.driver
        assert.is_true(driver:IsShown())
        for _, frame in pairs(client.frames) do
            client.ns.Detach(frame.Health)
            client.ns.Detach(frame.Power)
        end
        for _, bar in pairs(client.DB.StatusBars) do
            client.ns.Detach(bar)
        end
        assert.is_false(driver:IsShown())
        client.ns.Attach(client.frames.player.Health, "health", "fire", client.frames.player)
        assert.is_true(driver:IsShown())
    end)

    it("takes at most a tenth of a second in one step, after a hitch", function()
        local client = NewClient()
        local liquid = client:LiquidOn(client.frames.player.Health)
        client.ns.driver.scripts.OnUpdate(client.ns.driver, 2)
        assert.is_near(0.1, liquid.dt, 1e-9)
        client.ns.driver.scripts.OnUpdate(client.ns.driver, 0)
        assert.are.equal(1, liquid.updates, "no time, no step")
    end)
end)
