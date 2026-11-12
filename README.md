# ElvUI Liquid Bars

Smooth Animated Bars' liquid in ElvUI's bars: waves, swirls, bubbles, sparkles and lightning in the
health and power bars of ElvUI's unit frames and in its experience, reputation and pet experience
bars. For WoW: Forever.

## What you need

- **ElvUI**
- **Smooth Animated Bars**, installed and enabled. This plugin uses its liquid and its themes. Its
  own bars are on Blizzard's unit frames, which ElvUI hides; switch them and its nameplates off in
  `/sab` and it does nothing else.

## Settings

ElvUI → Plugins → **Liquid Bars**:

- **Unit frames:** player, target, focus, pet, target of target and party (party off by default),
  each with its health and power bar: a liquid or not, and its look.
- **Data bars:** experience, reputation, pet experience.
- **Power types:** the look of a power bar set to *By power type*, per mana, rage, energy, focus and
  astral power. A druid's bar changes with each form, with a splash.
- **Effects:** how much the liquids do, per group size: solo and party, raid, and a big raid (more
  members than you set, 20 by default). Each takes one of Smooth Animated Bars' levels
  (*Everything*, *Gentle*: waves and swirl, *Still*: a plain liquid) or *Custom*, its own effect
  switches. By default: Custom solo and in a party, Gentle in a raid, Still in a big raid; every
  liquid changes level as the group does. *Fade the front on a full bar* (on) fades the bright line
  on the liquid's edge over the last few percent.

**Liquid above ElvUI's overlays** (on by default) puts the liquid above ElvUI's ClipFrame on a bar,
which otherwise drew over it; the bar's texts stay on top. ElvUI's cutaway (the lost health or power
fading away) and power prediction (a spell's cost) are kept above the liquid; the prediction only
shows while it has a range, since after login ElvUI leaves it shown with none, filling the bar.

A look is **ElvUI's colour** (the bar's own colour, followed as ElvUI changes it), one of Smooth
Animated Bars' themes (Fire, Frost, Arcane, Class Color, ...), or for a power bar **By power type**.

On a bar filled from the right (ElvUI's *Reverse Fill*, as on a mirrored target frame) the liquid
flows from right to left. Vertical bars keep ElvUI's own fill.

---

## Technical part

### How it borrows Smooth Animated Bars

The .toc lists two of Smooth Animated Bars' files by a path into its folder:

```
Borrow.lua
..\SmoothAnimatedBars\Themes.lua
..\SmoothAnimatedBars\Liquid.lua
```

The client runs a file with the namespace of the addon whose .toc lists it, so `ns.Themes` and
`ns.Liquid` land in this plugin's namespace, not in Smooth Animated Bars'. Nothing is copied: a new
version of Smooth Animated Bars brings its new themes and physics along. `Borrow.lua` stands in for
the one thing `Themes.lua` asks of its own core (`ns.Core.Get`, at run time). The textures stay in
Smooth Animated Bars' folder, hence `RequiredDeps`.

These are Smooth Animated Bars' internals, not a published API: if it renames the files or changes
`Liquid.New`, `SetTheme`, `Splash`, `Update` or `Themes.FromColor`, this plugin breaks.
`annotations/Addon.lua` lists every part it uses.

### Files

- `Bar.lua`: the liquid on one status bar, any bar. `ns.Attach(bar, kind, look, owner)` hides the
  bar's fill (alpha 0, its size kept), puts a frame one bar wide on the fill's right edge and Smooth
  Animated Bars' liquid in it, always full on that frame. So ElvUI's value and smoothing move the
  liquid; the plugin never reads the value, which WoW: Forever hides in combat. A clip frame cuts it
  off at the bar. `ns.Detach(bar)` gives the fill back. One driver frame moves every liquid each
  frame, skipping bars that do not show, a liquid at rest at 30 frames a second only; it hides when
  there is no liquid. Every quarter second it looks at the bar's colour and fill again. ElvUI calls
  its configure functions often for a bar that has its liquid already (a power bar showing or hiding
  re-configures its frame), so `Attach` only snaps a liquid and gives it a new theme when it went
  live, turned round or got another height: a new theme resets the liquid's swirl and particles.
  ElvUI sets the fill's alpha on its own updates (a transparent bar gets less than 1; target of
  target is polled several times a second), so hooks on the fill's `SetAlpha` and `SetVertexColor`
  (whose fourth value sets the alpha, which is how `UF:SetStatusBarColor` makes a bar transparent)
  hide it again at once and keep ElvUI's alpha to give back on `Detach`. A hook on the bar's `OnSizeChanged` keeps
  the liquid as wide as the bar when ElvUI lays a frame out after configuring it, and gives a bar
  that had no size yet its liquid once it has one.
- The front: the liquid's bright line and glow (`liquid.tips`, `liquid.glow`, Smooth Animated Bars'
  fields) are moved onto a frame of their own (`holder.front`), since the liquid sets their alpha
  every frame. Each frame the plugin sets that frame's alpha: 1, fading to 0 between 97% and 100%.
  For a unit's health and power through `UnitHealthPercent`/`UnitPowerPercent` with a curve, which
  gives a value the client may keep secret but `SetAlpha` takes; other bars by their own values.
- Layers (`Bar.lua`, `Layer`): with *Liquid above ElvUI's overlays* the clip frame goes two levels
  above the bar (ElvUI's ClipFrame is one up, the power prediction in it two), the liquid's frame one
  more, its front one more. ElvUI's cutaway texture (`frame.Cutaway.Health`/`.Power`) is moved onto
  the front frame while the liquid is live and back into ElvUI's ClipFrame on `Detach` or with the
  option off; its anchors, colour and fading stay ElvUI's. The power prediction's bar
  (`frame.PowerPrediction.mainBar`) goes the same way, one level over the front. After login ElvUI
  leaves it shown with a range of 0..0, which fills the whole bar (that covered the liquid in
  Eltruism's light mode until ElvUI configured the bar again), so while it is above a liquid a hook
  on its `SetMinMaxValues` keeps its alpha at 0 without a range; a secret range counts as one.
- Levels (`Core.lua`): `ns.levels` holds Smooth Animated Bars' three levels as fixed tables, the
  custom level is the profile's `effects`. `ns.Effects()` picks by `IsInRaid`/`GetNumGroupMembers`;
  `GROUP_ROSTER_UPDATE` hands every liquid its table (`SetOptions`) when it changed.
- `Mirror.lua`: for a bar filled from the right. Smooth Animated Bars' liquid lays out every texture
  from its parent's left edge and asks the parent for nothing but `CreateTexture`. `ns.Mirror(frame)`
  stands in for the frame: its textures come out flipped (anchors from the right with offsets
  negated, texture coordinates and horizontal gradients swapped, rotations reversed), every other
  call goes to the real texture. Such a bar gets its own liquid through the mirror, on the fill's
  left edge. Should Smooth Animated Bars start anchoring from elsewhere than the left, the mirrored
  liquid would show in the wrong place (no error); `tests/mirror_spec.lua` pins down what is flipped.
- `Core.lua`: the ElvUI module. Settings in ElvUI's profile; hooks after `UF:Configure_HealthBar`,
  `UF:Configure_Power` and `DB:UpdateAll`; events: a change of health, power, experience, reputation
  or pet experience splashes the bar's liquid (at most every 0.15 s), `UNIT_DISPLAYPOWER` changes a
  power bar's look with a big splash, a new target, focus, pet or group lets Class Color pick again.
- `Options.lua`: the plugin's page in ElvUI's options.
- `Dev.lua`: development screenshots (below).
- `Locales\enUS.lua`: the strings.

Movement is scaled to the bar's height (`ns.Scaled`): the themes are made for an experience bar, so
a bar under 40 px moves less, down to a quarter at 10 px.

Looks are memoized (`Bar.lua`, `looks`): one per theme or colour and per height, shared by every
bar that needs it, and ElvUI's colour is taken in steps of a twentieth per channel. A liquid only
gets `SetTheme` when its look is another object, since Smooth Animated Bars' `SetTheme` builds a
dozen tables and drops the liquid's sparks and lightning; a bar coloured by value would otherwise get
one every quarter second. `ApplyAll` (any change in the settings) clears the cache. Class Color is
made anew per unit, on a new unit only.

### Development

`.lua\bin\lua.exe tests\check.lua` runs StyLua, WoW Lua LS (100% type coverage) and the busted
specs (100% line coverage). `tests\setup-lua.ps1` sets up `.lua\`. The test client (`tests\wow.lua`)
fakes Smooth Animated Bars' two files, since they live in the game folder only.

### Screenshots while testing in game

A copy straight from the repository has a **Dev screenshots** switch at the bottom of the plugin's
page. Switched on, the first time a bar gets its liquid (`liquid: player health`,
`liquid: experience`, ...) and the first time each power type comes with a change of form
(`form: RAGE`), a grey chat line says which and a screenshot follows. A bar counts when it gets its
liquid, not each time ElvUI configures it again (it does so often: class bars, power, toggling a
data bar). The kinds of one moment share one screenshot; one within two seconds of the last waits.
Each kind once, kept in ElvUI's global data until *Forget the screenshots taken*. The whole file is a
`--@debug@` block, so a release does not have it.
