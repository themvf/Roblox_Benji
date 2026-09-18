-- Uncommon: patterned wrap. Resolves the image from ReplicatedStorage.Uploads.BlueCamo (a Decal/Texture)
-- or a direct rbxassetid. Until the image exists the body still reads blue.
return {
    Id = "skn_shorty_uncommon_bluecamo",
    Weapon = "Shorty",
    Tier = "Uncommon",
    Concept = "The Shorty in bluecamo: a blue camo wrap with a dark business end",
    Materials = { Primary = "blue camo cloth", Accent = "gunmetal" },
    SoundPalette = "base",
    Systems = {
        Texture = {
            Asset = "upload:BlueCamo", -- upload a camo PNG in Studio and paste its rbxassetid here, or "upload:BlueCamo"
            Body = { Color = { 60, 110, 190 }, Material = "Fabric" },
            Overrides = {
                Barrel = { Color = { 40, 45, 55 }, Material = "Metal" },
                Muzzle = { Color = { 40, 45, 55 }, Material = "Metal" },
                Bolt = { Color = { 40, 45, 55 }, Material = "Metal" },
                Magazine = { Color = { 40, 45, 55 }, Material = "Metal" },
                Scope = { Color = { 40, 45, 55 }, Material = "Metal" },
                Core = { Color = { 40, 45, 55 }, Material = "Metal" },
                Emitter = { Color = { 40, 45, 55 }, Material = "Metal" },
                Barrels = { Color = { 40, 45, 55 }, Material = "Metal" },
                Edge = { Color = { 40, 45, 55 }, Material = "Metal" },
            },
        },
    },
}
