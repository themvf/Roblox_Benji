-- Fit visible geometry to both viewport dimensions, leaving a consistent framing margin.
local WeaponPreview = {}

function WeaponPreview.distance(halfWidth, halfHeight, halfDepth, aspect, verticalFov)
    local tangent = math.tan(math.rad(verticalFov / 2))
    local fit = math.max(halfHeight / tangent, halfWidth / (tangent * math.max(aspect, 0.1)))
    return math.max(0.1, halfDepth + fit * 1.12)
end

return WeaponPreview
