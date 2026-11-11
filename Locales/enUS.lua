-- English strings, also the fallback for every other client language. Each says where it appears.
local addon = ...
local L = LibStub("AceLocale-3.0"):NewLocale(addon, "enUS", true)

-- stylua: ignore start

-- ElvUI's options: the plugin's page in the side bar and its text.
L.OPTIONS = "Liquid Bars"
L.OPTIONS_DESC = "Smooth Animated Bars' liquid in ElvUI's bars. Only its files are used: switch off its own bars and nameplates (/sab), which ElvUI hides anyway, and it costs nothing. Vertical bars and bars filled from the right keep ElvUI's fill."

-- The look of a bar: ElvUI's colour, by power type, or one of Smooth Animated Bars' themes.
L.THEME = "Look"
L.THEME_ELVUI = "ElvUI's colour"
L.THEME_POWER = "By power type"
L.ON = "Liquid"

-- The Unit frames tab: a page per kind of frame, a box per bar.
L.UNITS = "Unit frames"
L.player = "Player"
L.target = "Target"
L.focus = "Focus"
L.pet = "Pet"
L.targettarget = "Target of target"
L.party = "Party"
L.health = "Health"
L.power = "Power"

-- The Data bars tab.
L.DATA = "Data bars"
L.experience = "Experience"
L.reputation = "Reputation"
L.petExperience = "Pet experience"

-- The Power types tab.
L.POWER = "Power types"
L.POWER_DESC = "The look of power bars set to \"By power type\". A druid's bar changes with each form."
L.MANA = "Mana"
L.RAGE = "Rage"
L.ENERGY = "Energy"
L.FOCUS = "Focus"
L.LUNAR_POWER = "Astral Power"

-- The Effects tab: Smooth Animated Bars' own switches, for every liquid.
L.EFFECTS = "Effects"
L.waves = "Waves"
L.swirl = "Swirl"
L.bubbles = "Bubbles"
L.sparkles = "Sparkles"
L.ambient = "Ambient particles"
L.lightning = "Lightning"

-- stylua: ignore end
