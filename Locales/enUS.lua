-- English strings, also the fallback for every other client language. Each says where it appears.
local addon = ...
local L = LibStub("AceLocale-3.0"):NewLocale(addon, "enUS", true)

-- stylua: ignore start

-- ElvUI's options: the plugin's page in the side bar and its text.
L.OPTIONS = "Liquid Bars"
L.OPTIONS_DESC = "Smooth Animated Bars' liquid in ElvUI's bars. Only its files are used: switch off its own bars and nameplates (/sab), which ElvUI hides anyway, and it costs nothing. On a bar filled from the right the liquid flows the other way; vertical bars keep ElvUI's fill."

L.ABOVE_OVERLAYS = "Liquid above ElvUI's overlays"
L.ABOVE_OVERLAYS_DESC = "The liquid above ElvUI's overlay frame on the bar, which otherwise draws over it. ElvUI's power prediction (a spell's cost) and cutaway are kept above the liquid; the bar's texts stay on top."
L.TINT_PREDICTION = "Power prediction in the liquid's colour"
L.TINT_PREDICTION_DESC = "ElvUI's power prediction above the liquid takes the liquid's colour, darker, instead of ElvUI's power prediction colour."

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

-- The Effects tab: how much the liquids do per group size, Smooth Animated Bars' three levels or the
-- switches above, and the fading front.
L.LEVELS = "By group size"
L.GROUP_party = "Solo and party"
L.GROUP_raid = "Raid"
L.GROUP_bigRaid = "Big raid"
L.BIG_RAID_SIZE = "Big raid: more members than"
L.LEVEL_custom = "Custom"
L.LEVEL_full = "Everything"
L.LEVEL_gentle = "Gentle: waves and swirl"
L.LEVEL_still = "Still: a plain liquid"
L.FADE_FRONT = "Fade the front on a full bar"
L.FADE_FRONT_DESC = "The bright line and glow on the liquid's edge fade out over the last few percent, so a full bar has no line at its end."

-- stylua: ignore end
