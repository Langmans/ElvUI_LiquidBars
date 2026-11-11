-- Screenshots for development (Dev.lua): only in a copy straight from the repository, never in a
-- release (the packager comments it out), off until switched on. The first time each kind of moment
-- from tasks\01-todo\01-ingame.md happens, a grey chat line says which, then one screenshot.

---A development copy with the screenshots switched on.
local function shooting()
    local client = NewClient({ dev = true })
    local dev = client:LoadOptions().args.dev.args
    assert.is_false(dev.on.get(), "off until switched on")
    dev.on.set(nil, true)
    return client, dev
end

---Whether a chat line contains text.
local function printed(client, text)
    for _, line in ipairs(client.printed) do
        if line:find(text, 1, true) then return true end
    end
    return false
end

describe("development screenshots", function()
    it("take one the first time a bar gets its liquid, after saying which", function()
        local client = shooting()
        client:Configure("player")
        assert.is_true(printed(client, "|cff888888[" .. ADDON_NAME .. " dev] liquid: player health|r"))
        assert.are.equal(0, client.screenshots, "not before it is drawn")
        client:Advance(0.5)
        assert.are.equal(1, client.screenshots)
    end)

    it("take each kind once, kept, until forgotten", function()
        local client, dev = shooting()
        client:Configure("player"):Advance(3):Configure("player"):Advance(3)
        local shots = client.E.global[ADDON_NAME].dev.shots
        assert.is_true(shots["liquid: player health"])
        local taken = client.screenshots
        dev.forget.func()
        client:Configure("player"):Advance(3)
        assert.are.equal(taken + 1, client.screenshots)
    end)

    it("take at most one every two seconds; a kind skipped comes again later", function()
        local client = shooting()
        client:Configure("player"):Advance(0.5)
        client.DB:UpdateAll()
        local shots = client.E.global[ADDON_NAME].dev.shots
        assert.is_nil(shots["liquid: experience"], "too soon, not marked")
        client:Advance(3)
        client.DB:UpdateAll()
        assert.is_true(shots["liquid: experience"])
    end)

    it("know a change of form", function()
        local client = shooting()
        client.powerTypes.player = { 1, "RAGE" }
        client:Fire("UNIT_DISPLAYPOWER", "player")
        assert.is_true(client.E.global[ADDON_NAME].dev.shots["form: RAGE"])
    end)

    it("take none while switched off", function()
        local client = NewClient({ dev = true })
        client:Configure("player"):Advance(3)
        assert.are.equal(0, client.screenshots)
        assert.is_false(printed(client, "dev]"))
    end)

    it("are not there in a release", function()
        local client = NewClient()
        client:Configure("player"):Advance(3)
        assert.are.equal(0, client.screenshots)
        assert.is_nil(client.ns.DevOptions)
        assert.is_nil(client:LoadOptions().args.dev)
    end)
end)
