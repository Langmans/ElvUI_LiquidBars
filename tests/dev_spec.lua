-- Screenshots for development (Dev.lua): only in a copy straight from the repository, never in a
-- release (the packager comments it out), off until switched on. The first time each kind of moment
-- from tasks\01-todo\01-ingame.md happens, a grey chat line says which, then one screenshot. A bar
-- counts when it gets its liquid, not each time ElvUI configures it again (which it does often:
-- class bars, power, toggling a data bar), and the kinds of one moment share one screenshot.

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

---A frame's bars lose their liquid and ElvUI configures the frame: they get it again.
local function reattach(client, key)
    client.ns.Detach(client.frames[key].Health)
    client.ns.Detach(client.frames[key].Power)
    return client:Configure(key)
end

describe("development screenshots", function()
    it("take one when a bar gets its liquid, after saying which", function()
        local client = shooting()
        reattach(client, "player"):Advance(0.1)
        assert.is_true(printed(client, "|cff888888[" .. ADDON_NAME .. " dev] liquid: player health|r"))
        assert.are.equal(0, client.screenshots, "not before it is drawn")
        client:Advance(0.5)
        assert.are.equal(1, client.screenshots)
    end)

    it("say nothing when ElvUI configures bars that have their liquid already", function()
        local client = shooting()
        client:Configure("player"):Configure("target")
        client.DB:UpdateAll()
        client:Advance(3)
        assert.are.equal(0, client.screenshots)
        assert.is_false(printed(client, "dev]"))
    end)

    it("take the kinds of one moment in one screenshot", function()
        local client = shooting()
        reattach(client, "player"):Advance(1)
        assert.is_true(printed(client, "liquid: player health"))
        assert.is_true(printed(client, "liquid: player power"))
        assert.are.equal(1, client.screenshots)
    end)

    it("hold a kind that comes too soon after a screenshot, then take it", function()
        local client = shooting()
        reattach(client, "player"):Advance(0.5)
        reattach(client, "target"):Advance(0.5)
        assert.is_false(printed(client, "liquid: target health"), "within two seconds")
        assert.are.equal(1, client.screenshots)
        client:Advance(2)
        assert.is_true(printed(client, "liquid: target health"))
        assert.are.equal(2, client.screenshots)
    end)

    it("take each kind once, kept, until forgotten", function()
        local client, dev = shooting()
        reattach(client, "player"):Advance(3)
        reattach(client, "player"):Advance(3)
        assert.are.equal(1, client.screenshots)
        assert.is_true(client.E.global[ADDON_NAME].dev.shots["liquid: player health"])
        dev.forget.func()
        reattach(client, "player"):Advance(3)
        assert.are.equal(2, client.screenshots)
    end)

    it("know a change of form", function()
        local client = shooting()
        client.powerTypes.player = { 1, "RAGE" }
        client:Fire("UNIT_DISPLAYPOWER", "player"):Advance(1)
        assert.is_true(client.E.global[ADDON_NAME].dev.shots["form: RAGE"])
    end)

    it("take none while switched off", function()
        local client = NewClient({ dev = true })
        reattach(client, "player"):Advance(3)
        assert.are.equal(0, client.screenshots)
        assert.is_false(printed(client, "dev]"))
    end)

    it("are not there in a release", function()
        _G[ADDON_NAME .. "Dev"] = nil
        local client = NewClient()
        reattach(client, "player"):Advance(3)
        assert.are.equal(0, client.screenshots)
        assert.is_nil(client.ns.DevOptions)
        assert.is_nil(client:LoadOptions().args.dev)
        assert.is_nil(_G[ADDON_NAME .. "Dev"], "no global to look inside")
    end)
end)

describe("the development global", function()
    it("opens the plugin's namespace for /run probes, named from the folder", function()
        local client = NewClient({ dev = true, name = "Tester" })
        assert.are.equal(client.ns, TesterDev)
        TesterDev = nil
    end)
end)
