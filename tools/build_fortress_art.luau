-- Persist approved uploaded meshes in Rojo; no runtime InsertService dependency.
local fs = require("@lune/fs")
local r = require("@lune/roblox")
local root = r.Instance.new("Folder")
root.Name = "SnowFortress"
local function mesh(name, id, size, maps)
    local p = r.Instance.new("MeshPart")
    p.Name = name
    p.MeshId = "rbxassetid://" .. id
    p.Size = r.Vector3.new(unpack(size))
    p.Anchored = true
    p.CanCollide = false
    p.CanTouch = false
    p.CanQuery = false
    p.Color = r.Color3.new(1, 1, 1)
    local surface = r.Instance.new("SurfaceAppearance")
    for property, asset in maps do
        surface[property] = "rbxassetid://" .. asset
    end
    surface.Parent = p
    p.Parent = root
end
mesh("Portal", "97514947286513", { 29.2, 19.027687, 5.525 }, {
    ColorMap = "107517388365642",
    NormalMap = "103003809608425",
    RoughnessMap = "138739624425386",
    MetalnessMap = "81206348446212",
})
mesh("WallBay", "76541940970822", { 10, 13, 3.45 }, {
    ColorMap = "139917916851753",
    NormalMap = "130646524800666",
    RoughnessMap = "88147658806080",
    MetalnessMap = "130198819519587",
})
mesh("Pier", "81731499308896", { 6.15, 21.045319, 5.45 }, {
    ColorMap = "79584707714479",
    NormalMap = "140539039530413",
    RoughnessMap = "112946414818366",
    MetalnessMap = "76184438733569",
})
mesh("Parapet", "130291006075346", { 10, 3.650051, 3.55 }, {
    ColorMap = "119777457502069",
    NormalMap = "136812887790775",
    RoughnessMap = "93705998232102",
    MetalnessMap = "136236996377801",
})
mesh("Floor", "86285295257538", { 10, 1.02, 10 }, {
    ColorMap = "106966321066648",
    NormalMap = "103613136663634",
    RoughnessMap = "72517354362782",
    MetalnessMap = "120719746464732",
})
fs.writeDir("assets/environment/runtime")
fs.writeFile("assets/environment/runtime/SnowFortress.rbxmx", r.serializeModel({ root }, true))
print("Built SnowFortress mesh templates")
