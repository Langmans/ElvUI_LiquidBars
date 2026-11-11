-- A change to a bar stirs its liquid (Core.lua): health and power for the frames showing that unit,
-- experience, reputation and pet experience for their data bars. The values themselves may be hidden
-- (secret) in combat, so every change splashes alike, at most a few times a second per bar.

describe("a splash", function()
    it("comes with a change to the unit's health or power", function()
        local client = NewClient()
        local health = client:LiquidOn(client.frames.player.Health)
        local power = client:LiquidOn(client.frames.player.Power)
        local target = client:LiquidOn(client.frames.target.Health)
        client:Fire("UNIT_HEALTH", "player")
        assert.are.same({ { 0.25, 192, 200 } }, health.splashes)
        assert.are.equal(0, #power.splashes)
        assert.are.equal(0, #target.splashes)
        client:Advance(0.2):Fire("UNIT_POWER_UPDATE", "player", "MANA")
        assert.are.equal(1, #power.splashes)
    end)

    it("comes with experience, reputation and pet experience", function()
        local client = NewClient()
        local bars = client.DB.StatusBars
        client:Fire("PLAYER_XP_UPDATE", "player"):Fire("UPDATE_FACTION"):Fire("UNIT_PET_EXPERIENCE")
        for _, key in ipairs({ "Experience", "Reputation", "PetExperience" }) do
            assert.are.equal(1, #client:LiquidOn(bars[key]).splashes, key)
        end
    end)

    it("comes at most every 0.15 seconds per bar", function()
        local client = NewClient()
        local health = client:LiquidOn(client.frames.player.Health)
        client:Fire("UNIT_HEALTH", "player"):Fire("UNIT_HEALTH", "player")
        assert.are.equal(1, #health.splashes)
        client:Advance(0.2):Fire("UNIT_HEALTH", "player")
        assert.are.equal(2, #health.splashes)
    end)
end)
