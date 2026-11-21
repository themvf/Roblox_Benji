-- Run in Studio's Command Bar with exactly the imported MeshPart selected.
local Selection = game:GetService("Selection")
local selected = Selection:Get()
assert(#selected == 1 and selected[1]:IsA("MeshPart"), "Select one angular case MeshPart")
local part = selected[1]
part.Name = "GlossyAngularBlackOrangeCase"
part.Anchored = true
part.CanCollide = false
part.CanTouch = false
part.CanQuery = false
print("Configured decoration:", part:GetFullName(), part.Size)
