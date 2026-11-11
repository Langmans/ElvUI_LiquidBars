-- The two files the .toc borrows from Smooth Animated Bars (Themes.lua, Liquid.lua) run with this
-- plugin's namespace, so their ns.Themes and ns.Liquid land here. Themes.lua asks its own addon's core
-- for one setting at run time (Class Color on mobs); this stands in for that core, with no settings,
-- so every theme takes its default.

local _, ns = ... ---@type string, AddonNamespace

---@param _ string the setting's name
---@return nil
local function NoSetting(_)
    return nil
end

ns.Core = { Get = NoSetting }
