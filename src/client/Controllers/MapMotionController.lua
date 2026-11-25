-- Client-side ambient motion for CollectionService-tagged map decor (zero physics/server cost):
--   * SpinFan: rotates BasePart/Model around its local Z (or SpinAxis) continuously
--   * FlickerLight: organic industrial fault flicker on PointLight/SpotLight + parent Neon part
--   * CraneGlide: glides a Model/BasePart smoothly along local X using a sine cycle
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Knit = require(ReplicatedStorage.Packages.Knit)

local MapMotionController = Knit.CreateController({ Name = "MapMotionController" })

type FanEntry = { inst: Instance, base: CFrame, speed: number }
type FlickerEntry = { light: Light, neon: BasePart?, baseBrightness: number, phase: number }
type CraneEntry = { inst: Instance, base: CFrame, span: number, speed: number, phase: number }

local fans: { [Instance]: FanEntry } = {}
local flickers: { [Instance]: FlickerEntry } = {}
local cranes: { [Instance]: CraneEntry } = {}

local function getPivot(inst: Instance): CFrame?
    if inst:IsA("Model") then
        return inst:GetPivot()
    elseif inst:IsA("BasePart") then
        return inst.CFrame
    end
    return nil
end

local function setPivot(inst: Instance, cf: CFrame)
    if inst:IsA("Model") then
        inst:PivotTo(cf)
    elseif inst:IsA("BasePart") then
        inst.CFrame = cf
    end
end

local function addFan(inst: Instance)
    local base = getPivot(inst)
    if not base then
        return
    end
    local speed = inst:GetAttribute("SpinSpeed")
    fans[inst] = {
        inst = inst,
        base = base,
        speed = if typeof(speed) == "number" then speed else 3.2,
    }
end

local function addFlicker(inst: Instance)
    if not inst:IsA("Light") then
        return
    end
    local parentPart = if inst.Parent and inst.Parent:IsA("BasePart") then inst.Parent else nil
    flickers[inst] = {
        light = inst,
        neon = parentPart,
        baseBrightness = inst.Brightness,
        phase = math.random() * 100,
    }
end

local function addCrane(inst: Instance)
    local base = getPivot(inst)
    if not base then
        return
    end
    local span = inst:GetAttribute("GlideSpan")
    local speed = inst:GetAttribute("GlideSpeed")
    cranes[inst] = {
        inst = inst,
        base = base,
        span = if typeof(span) == "number" then span else 42,
        speed = if typeof(speed) == "number" then speed else 0.14,
        phase = 0,
    }
end

function MapMotionController:KnitStart()
    for _, inst in CollectionService:GetTagged("SpinFan") do
        addFan(inst)
    end
    CollectionService:GetInstanceAddedSignal("SpinFan"):Connect(addFan)
    CollectionService:GetInstanceRemovedSignal("SpinFan"):Connect(function(inst)
        fans[inst] = nil
    end)

    for _, inst in CollectionService:GetTagged("FlickerLight") do
        addFlicker(inst)
    end
    CollectionService:GetInstanceAddedSignal("FlickerLight"):Connect(addFlicker)
    CollectionService:GetInstanceRemovedSignal("FlickerLight"):Connect(function(inst)
        flickers[inst] = nil
    end)

    for _, inst in CollectionService:GetTagged("CraneGlide") do
        addCrane(inst)
    end
    CollectionService:GetInstanceAddedSignal("CraneGlide"):Connect(addCrane)
    CollectionService:GetInstanceRemovedSignal("CraneGlide"):Connect(function(inst)
        cranes[inst] = nil
    end)

    RunService.RenderStepped:Connect(function()
        local t = os.clock()

        for _, entry in fans do
            if entry.inst:IsDescendantOf(workspace) then
                setPivot(entry.inst, entry.base * CFrame.Angles(0, 0, t * entry.speed))
            end
        end

        for _, entry in flickers do
            if entry.light:IsDescendantOf(workspace) then
                -- Jagged industrial fault pulse (mostly on, brief sharp dips)
                local n = math.sin(t * 17 + entry.phase) + 0.6 * math.sin(t * 43 + entry.phase * 1.7)
                local dip = if n < -1.05 then 0.12 elseif n < -0.55 then 0.5 else 1.0
                entry.light.Brightness = entry.baseBrightness * dip
                if entry.neon then
                    entry.neon.Transparency = if dip < 0.3 then 0.72 else 0
                end
            end
        end

        for _, entry in cranes do
            if entry.inst:IsDescendantOf(workspace) then
                local offset = math.sin(t * entry.speed + entry.phase) * entry.span
                setPivot(entry.inst, entry.base * CFrame.new(offset, 0, 0))
            end
        end
    end)
end

return MapMotionController
