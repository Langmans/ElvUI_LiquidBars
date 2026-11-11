-- The plugin borrows Smooth Animated Bars' Liquid class and themes: the .toc loads those two files
-- from the other addon's folder (..\SmoothAnimatedBars\), so they run with this plugin's namespace.
-- Themes.lua reads ns.Core at run time, which the plugin stands in for before it.

describe("the .toc", function()
    it("loads Smooth Animated Bars' themes and liquid into the plugin's namespace", function()
        local client = NewClient()
        assert.are.same({ "../SmoothAnimatedBars/Themes.lua", "../SmoothAnimatedBars/Liquid.lua" }, client.sabFiles)
        assert.is_table(client.ns.Liquid)
        assert.is_table(client.ns.Themes)
    end)

    it("stands in for Smooth Animated Bars' core before its files", function()
        local stub
        for i, file in ipairs(TOC_FILES) do
            if file:match("^%.%./") then break end
            stub = stub or (file == "Borrow.lua" and i)
        end
        assert.is_number(stub, "Borrow.lua comes before the borrowed files")
        local client = NewClient()
        assert.is_nil(client.ns.Core.Get("mobClassColor"), "no setting of its own: the theme's default")
    end)

    it("needs ElvUI and Smooth Animated Bars", function()
        local deps = TOC_METADATA.RequiredDeps
        assert.truthy(deps:find("ElvUI", 1, true))
        assert.truthy(deps:find("SmoothAnimatedBars", 1, true))
    end)
end)
