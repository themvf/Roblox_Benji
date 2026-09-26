-- Sprint / crouch / slide: the server side.
--
-- Characters are client-owned, so the client moves itself -- sprint has to respond on the
-- frame the key goes down, not a round trip later. What the server owns is the STATE
-- everyone else sees and the rules around it: a player's `Stance` attribute on their
-- character (Sprint / Crouch / Slide, nil = walking), which every client uses to pose
-- crouching and sliding characters, and the slide cooldown. Illegal requests -- a slide
-- while mutated, celebrating or on cooldown, junk arguments, a flood of requests -- are
-- refused, and the stance stays what it was.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Movement = require(ReplicatedStorage.Shared.Movement)

local MovementService = Knit.CreateService({
    Name = "MovementService",
    Client = {
        -- (stance | nil) from a client whenever its stance changes. An event, not a request:
        -- the client never waits on the server to move.
        Stance = Knit.CreateSignal(),
    },
})

local RATE_WINDOW = 1 -- seconds
local RATE_MAX = 20 -- stance changes per window; a human mashing keys stays well under

local state = {} -- [player] = { LastSlide, Window, Count }

local function settings()
    return Movement.settings(Config.Movement, ReplicatedStorage:FindFirstChild("Tuning"))
end

-- Why a stance is not allowed right now, or nil.
function MovementService:Refusal(player, stance, now)
    if stance ~= nil and not Movement.STANCES[stance] then
        return "unknown stance"
    end
    local character = player.Character
    local hum = character and character:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then
        return "not alive"
    end
    if stance == nil or stance == "Sprint" then
        return nil
    end
    -- crouching and sliding
    if player:GetAttribute("Mutated") ~= nil then
        return "mutated"
    end
    if character:GetAttribute(Movement.PREFIX .. "Celebration") == 0 then
        return "celebrating"
    end
    if stance == "Slide" then
        local st = state[player]
        local s = settings()
        -- Measured start to start: the client ends a slide early on a jump and cannot tell the
        -- server when, so the server only refuses what no honest client sends.
        if st and st.LastSlide and now - st.LastSlide < s.SlideCooldown then
            return "cooldown"
        end
    end
    return nil
end

function MovementService:SetStance(player, stance, now)
    now = now or os.clock()
    local st = state[player] or {}
    state[player] = st
    if not st.Window or now - st.Window >= RATE_WINDOW then
        st.Window, st.Count = now, 0
    end
    st.Count += 1
    if st.Count > RATE_MAX then
        return false, "rate"
    end
    local why = self:Refusal(player, stance, now)
    if why then
        return false, why
    end
    if stance == "Slide" then
        st.LastSlide = now
    end
    player.Character:SetAttribute("Stance", stance)
    return true
end

function MovementService:KnitStart()
    self.Client.Stance:Connect(function(player, stance)
        if stance ~= nil and type(stance) ~= "string" then
            return
        end
        self:SetStance(player, stance)
    end)
    Players.PlayerRemoving:Connect(function(player)
        state[player] = nil
    end)
end

return MovementService
