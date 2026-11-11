---@meta
-- Types for the plugin, for WoW Lua LS only: not in the .toc, not packaged. The parts of ElvUI and
-- of Smooth Animated Bars' borrowed files the plugin touches, and the plugin's own tables.

---ElvUI's global: { E, L, V, P, G }; the plugin uses the engine (E), the profile defaults (P) and
---the global defaults (G).
---@class ElvUIGlobal
---@field [1] ElvUIEngine
---@field [4] table<string, AddonSettings>
---@field [5] table<string, {dev: AddonDevData}>

---@type ElvUIGlobal
ElvUI = nil

---@class ElvUIEngine
---@field db table<string, AddonSettings> the profile
---@field global table<string, {dev: AddonDevData}>
---@field oUF {objects: AddonFrame[]} ElvUI's oUF, with every frame it spawned
---@field Options? {args: table<string, table>}
---@field GetModule fun(self: ElvUIEngine, name: "UnitFrames"|"DataBars"): table
---@field NewModule fun(self: ElvUIEngine, name: string, ...: string): AddonModule
---@field RegisterModule fun(self: ElvUIEngine, name: string)

---The plugin's ElvUI module, with AceHook and AceEvent.
---@class AddonModule
---@field GetName fun(self: AddonModule): string
---@field SecureHook fun(self: AddonModule, object: table, method: string, handler: string)
---@field RegisterEvent fun(self: AddonModule, event: string, handler: string?)

---A value the client hides from addons (WoW: Forever in combat): it can be passed on, never
---compared or tested.
---@class AddonSecret

---One of ElvUI's unit frames, the fields the plugin reads.
---@class AddonFrame: Button
---@field __unit string? oUF's unit for the frame (ElvUI's frames have no frame.unit)
---@field unitframeType string
---@field Health StatusBar?
---@field Power StatusBar?

---Smooth Animated Bars' theme (Themes.lua), as far as the plugin reads it.
---@class AddonTheme
---@field name string
---@field physics? table<string, number>
---@field Resolve? fun(self: AddonTheme, unit: string?, preview: boolean?): AddonTheme?

---Smooth Animated Bars' themes (Themes.lua).
---@class AddonThemes
---@field list table<string, AddonTheme>
---@field order string[]
---@field default string
---@field Get fun(key: string): AddonTheme
---@field FromColor fun(color: number[], template: AddonTheme, deep: boolean?): AddonTheme
---@field UnitColor fun(unit: string?, preview: boolean?): number[]?

---Smooth Animated Bars' liquid (Liquid.lua), the methods the plugin calls.
---@class AddonLiquid
---@field SetTheme fun(self: AddonLiquid, theme: AddonTheme)
---@field SetSize fun(self: AddonLiquid, width: number, height: number)
---@field SetOptions fun(self: AddonLiquid, options: AddonEffects)
---@field Snap fun(self: AddonLiquid, edge: number)
---@field Splash fun(self: AddonLiquid, intensity: number, fromX: number, toX: number)
---@field Update fun(self: AddonLiquid, dt: number, edge: number)
---@field HideAll fun(self: AddonLiquid)
---@field IsQuiet fun(self: AddonLiquid): boolean

---@class AddonLiquidClass
---@field New fun(parent: Frame, width: number, height: number, theme: AddonTheme, options: AddonEffects): AddonLiquid

---A frame seen through a mirror (Mirror.lua): its textures are made mirrored, its other methods are
---the frame's.
---@class AddonMirror: Frame
---@field real Frame

---A texture made through a mirror: the calls that place it flipped, the rest passed on.
---@class AddonMirrored: Texture
---@field real Texture

---Whatever a passed-on call takes or gives back.
---@alias AddonValue number|string|boolean|table|nil

---A method a mirror or a mirrored texture passes on to the real region.
---@alias AddonForward fun(self: table, ...: AddonValue): AddonValue

---What Themes.lua asks of Smooth Animated Bars' core, stood in for by Borrow.lua.
---@class AddonBorrowedCore
---@field Get fun(setting: string): nil

---The addon's namespace, the `...` every file gets.
---@class AddonNamespace
---@field NAME string the folder's name, which every name the game sees comes from
---@field L table<string, string> the client's strings (Locales\)
---@field Core AddonBorrowedCore
---@field Themes AddonThemes
---@field Liquid AddonLiquidClass
---@field IsSecret fun(value: string|number|boolean|table|nil): boolean
---@field unitOrder string[]
---@field partOrder string[]
---@field dataOrder string[]
---@field powerOrder string[]
---@field holders table<StatusBar, AddonHolder>
---@field driver Frame
---@field db fun(): AddonSettings
---@field Scaled fun(theme: AddonTheme, height: number): AddonTheme
---@field UnitOf fun(holder: AddonHolder): string?
---@field Recolor fun(holder: AddonHolder, force: boolean?)
---@field Splash fun(holder: AddonHolder, intensity: number, force: boolean?)
---@field Shift fun(holder: AddonHolder)
---@field Attach fun(bar: StatusBar, kind: string, setting: string, owner: (AddonFrame|string)?): AddonHolder?
---@field ByUnit fun(holder: AddonHolder): boolean
---@field Mirror fun(frame: Frame): AddonMirror
---@field Detach fun(bar: StatusBar)
---@field Live fun(): AddonHolder[]
---@field AttachFrame fun(frame: AddonFrame)
---@field AttachDataBars fun()
---@field ApplyAll fun()
---@field InsertOptions fun()
---@field DevOptions? fun(): table

---The liquid on one bar and its frames (Bar.lua).
---@class AddonHolder
---@field bar StatusBar
---@field clip Frame cuts the liquid off at the bar
---@field mover Frame one bar wide, on the fill's right edge
---@field fill Texture? the bar's fill, kept hidden while the liquid is live
---@field anchored Texture? the fill the mover is anchored to
---@field alpha number the alpha ElvUI gave the fill, given back when the liquid goes
---@field liquid AddonLiquid the liquid for the way the bar fills now
---@field liquids table<boolean, AddonLiquid> each way's liquid, by reversed, made when first needed
---@field reversed boolean the bar fills from the right: the liquid is mirrored
---@field live boolean
---@field kind string what the bar shows: "health", "power", "experience", ...
---@field setting string its look as set: "elvui", "power" or a theme's key
---@field choice? string the look it has now
---@field owner (AddonFrame|string)? the frame it is on, or the unit it follows
---@field width number
---@field height number
---@field r? number|AddonSecret the bar's colour the look was made from
---@field g? number|AddonSecret
---@field b? number|AddonSecret
---@field check number seconds since the colour and fill were looked at
---@field idle number seconds a liquid at rest has waited
---@field splashAt number when the next splash may come

---@class AddonBarSettings
---@field on boolean
---@field theme string "elvui", "power" (power bars) or a theme's key

---@class AddonUnitSettings
---@field health AddonBarSettings
---@field power AddonBarSettings

---Smooth Animated Bars' effect switches, read live by every liquid.
---@class AddonEffects
---@field waves boolean
---@field swirl boolean
---@field bubbles boolean
---@field sparkles boolean
---@field ambient boolean
---@field lightning boolean

---The plugin's settings in ElvUI's profile.
---@class AddonSettings
---@field units table<string, AddonUnitSettings>
---@field data table<string, AddonBarSettings>
---@field power table<string, string> the look per power type token
---@field effects AddonEffects

---Development screenshots' saved data (Dev.lua), in ElvUI's global data.
---@class AddonDevData
---@field on boolean
---@field shots table<string, boolean>
