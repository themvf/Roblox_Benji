-- HUD icons: one white glyph per idea, tinted in game, so the HUD reads at a glance
-- instead of in sentences. The art is assets/ui/icons/*.png, drawn by
-- tools/ui/draw_icons.py.
--
-- Hooking them up is one Studio step: View > Asset Manager > Bulk Import the PNGs,
-- then copy each image id into IDS below. A Decal or StringValue named Icon<Name> in
-- ReplicatedStorage.Uploads overrides an id here without a code change (Shared/Uploads).
-- Until an id resolves, the icon draws its short text fallback, so the HUD is usable
-- before anything is uploaded.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Uploads = require(ReplicatedStorage.Shared.Uploads)

local Icons = {}

-- rbxassetid numbers, filled in after the upload. nil = not uploaded yet.
Icons.IDS = {
    Health = nil,
    Ammo = nil,
    Mutate = nil,
    Slam = nil,
    Brace = nil,
    Charge = nil,
    Fuel = nil,
    Scope = nil,
    Crouch = nil,
    Slide = nil,
    Scores = nil,
    Speed = nil,
    Info = nil,
    Zone = nil,
    Skip = nil,
}

-- Shown in place of the image until it is uploaded: short, so the layout holds.
Icons.FALLBACK = {
    Health = "+",
    Ammo = "AMMO",
    Mutate = "TITAN",
    Slam = "SLAM",
    Brace = "BRACE",
    Charge = "CHARGE",
    Fuel = "FUEL",
    Scope = "SCOPE",
    Crouch = "CROUCH",
    Slide = "SLIDE",
    Scores = "SCORES",
    Speed = "SPEED",
    Info = "i",
    Zone = "ZONE",
    Skip = "SKIP",
}

-- The ability names AlterEgos uses, mapped to their icon.
Icons.ABILITY = { GroundSlam = "Slam", Brace = "Brace", Charge = "Charge" }

function Icons.image(name)
    local override = Uploads.resolve("upload:Icon" .. name)
    if override then
        return override
    end
    local id = Icons.IDS[name]
    return id and ("rbxassetid://" .. id) or nil
end

-- An icon that fills `parent`'s given size. Returns the ImageLabel, or a TextLabel
-- carrying the fallback word; either way set its colour with Icons.tint.
function Icons.make(parent, name, size)
    local image = Icons.image(name)
    local inst
    if image then
        inst = Instance.new("ImageLabel")
        inst.Image = image
        inst.ScaleType = Enum.ScaleType.Fit
    else
        inst = Instance.new("TextLabel")
        inst.Text = Icons.FALLBACK[name] or name:upper()
        inst.TextScaled = true
        inst.Font = Enum.Font.GothamBlack
    end
    inst.Name = "Icon"
    inst.BackgroundTransparency = 1
    inst.Size = size or UDim2.fromScale(1, 1)
    inst:SetAttribute("Icon", name)
    inst.Parent = parent
    Icons.tint(inst, Color3.new(1, 1, 1))
    return inst
end

-- Swap an existing icon to another glyph (CROUCH -> SLIDE) without rebuilding it.
function Icons.set(inst, name)
    if inst:GetAttribute("Icon") == name then
        return
    end
    inst:SetAttribute("Icon", name)
    local image = Icons.image(name)
    if inst:IsA("ImageLabel") and image then
        inst.Image = image
    elseif inst:IsA("TextLabel") then
        inst.Text = Icons.FALLBACK[name] or name:upper()
    end
end

function Icons.tint(inst, color, transparency)
    if inst:IsA("ImageLabel") then
        inst.ImageColor3 = color
        inst.ImageTransparency = transparency or 0
    else
        inst.TextColor3 = color
        inst.TextTransparency = transparency or 0
    end
end

return Icons
