-- Paste into the Roblox Studio Command Bar after importing BlueTube_NeonYellowCore.glb.
-- Select the imported model first. This touches only its independently named core mesh.
local Selection = game:GetService("Selection")
local selected = Selection:Get()[1]
assert(selected, "Select the imported neon-yellow tube model first")

local core = selected:FindFirstChild("Tube_Neon_yellow_energy_core", true)
assert(core and core:IsA("MeshPart"), "Imported Tube_Neon_yellow_energy_core MeshPart not found")
core.Material = Enum.Material.Neon
core.Color = Color3.fromRGB(225, 255, 12)
print("Set yellow core to Neon:", core:GetFullName())
