-- A mirror for a frame, so Smooth Animated Bars' liquid can flow right to left on a bar filled from
-- the right. The liquid lays out every texture from its parent's left edge and asks its parent for
-- nothing but CreateTexture. Given a mirror as its parent, it gets textures whose anchors come from
-- the right with offsets negated, whose texture coordinates and horizontal gradients are swapped and
-- whose rotations are reversed; every other call goes straight to the real texture.

local _, ns = ... ---@type string, AddonNamespace

-- Each anchor point and its mirror image.
---@type table<string, FramePoint>
local FLIP = {
    TOPLEFT = "TOPRIGHT",
    TOPRIGHT = "TOPLEFT",
    LEFT = "RIGHT",
    RIGHT = "LEFT",
    BOTTOMLEFT = "BOTTOMRIGHT",
    BOTTOMRIGHT = "BOTTOMLEFT",
}

---An anchor point's mirror image; CENTER, TOP and BOTTOM stay.
---@param point string
---@return FramePoint
local function Flip(point)
    return FLIP[point] or point --[[@as FramePoint]]
end

---The real region behind a mirror or a mirrored texture, else the region itself.
---@param region Region|AddonMirror|AddonMirrored
---@return Region
local function Real(region)
    return (rawget(region, "real") or region) --[[@as Region]]
end

-- The calls a mirrored texture changes. The rest are passed on (Forward below).
local Flipped = {}

---SetPoint in all three forms: a point alone, a point and an offset, or a point on another region.
---@param self AddonMirrored
---@param point string
---@param relative (Region|AddonMirror|AddonMirrored|number)?
---@param relativePoint (string|number)?
---@param x number?
---@param y number?
function Flipped.SetPoint(self, point, relative, relativePoint, x, y)
    local tex = self.real
    if relative == nil then
        tex:SetPoint(Flip(point))
    elseif type(relative) == "number" then
        tex:SetPoint(Flip(point), -relative, relativePoint --[[@as number]])
    else
        tex:SetPoint(Flip(point), Real(relative), Flip(relativePoint --[[@as string]]), -(x or 0), y or 0)
    end
end

---Four coordinates (left, right, top, bottom) or eight (the corners: upper left, lower left, upper
---right, lower right): left and right swap places.
---@param self AddonMirrored
---@param ... number
function Flipped.SetTexCoord(self, ...)
    if select("#", ...) == 4 then
        local left, right, top, bottom = ... ---@type number, number, number, number
        self.real:SetTexCoord(right, left, top, bottom)
        return
    end
    local ulx, uly, llx, lly, urx, ury, lrx, lry = ... ---@type number, number, number, number, number, number, number, number
    self.real:SetTexCoord(urx, ury, lrx, lry, ulx, uly, llx, lly)
end

---@param self AddonMirrored
---@param orientation "HORIZONTAL"|"VERTICAL"
---@param from colorRGBA
---@param to colorRGBA
function Flipped.SetGradient(self, orientation, from, to)
    if orientation == "HORIZONTAL" then
        from, to = to, from
    end
    self.real:SetGradient(orientation, from, to)
end

---@param self AddonMirrored
---@param radians number
function Flipped.SetRotation(self, radians)
    self.real:SetRotation(-radians)
end

-- One function per method name, shared by every mirror and mirrored texture: it calls the real one's.
---@type table<string, AddonForward>
local forwards = {}

---@param name string
---@return AddonForward
local function Forward(name)
    local f = forwards[name]
    if not f then
        ---@param self AddonMirrored
        ---@param ... AddonValue
        ---@return AddonValue ...
        f = function(self, ...)
            local real = self.real
            local method = real[name] --[[@as AddonForward]]
            return method(real, ...) --[[@as AddonValue]]
        end
        forwards[name] = f
    end
    return f
end

-- A method found is kept on the texture, so the liquid's hundreds of calls a frame skip __index.
local MirroredTexture = {
    ---@param tex AddonMirrored
    ---@param name string
    ---@return function
    __index = function(tex, name)
        local f = Flipped[name] or Forward(name)
        rawset(tex, name, f)
        return f
    end,
}

---A mirror of a frame: its CreateTexture makes mirrored textures, its other methods are the frame's.
---@param frame Frame
---@return AddonMirror
function ns.Mirror(frame)
    local mirror = { real = frame }
    ---@param _ AddonMirror
    ---@param ... any CreateTexture's arguments
    ---@return AddonMirrored
    function mirror.CreateTexture(_, ...)
        return setmetatable({ real = frame:CreateTexture(...) }, MirroredTexture) --[[@as AddonMirrored]]
    end
    return setmetatable(mirror, {
        ---@param _ AddonMirror
        ---@param name string
        ---@return function
        __index = function(_, name)
            local f = Forward(name)
            rawset(mirror, name, f)
            return f
        end,
    }) --[[@as AddonMirror]]
end
