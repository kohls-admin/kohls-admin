local Players = game:GetService("Players")
local Util = require(script.Parent.Parent.Parent.Util)

local jailParts = {}

local Jail = {
    Parts = jailParts,
}

local function pointInBounds(point, lower, upper)
    return point.X >= lower.X and point.Y >= lower.Y and point.Z >= lower.Z
       and point.X <= upper.X and point.Y <= upper.Y and point.Z <= upper.Z
end

local function createWall(parent, size, position, transparency)
    local wall = Instance.new("Part")
    wall.Size = size
    wall.Position = position
    wall.Anchored = true
    wall.Transparency = transparency
    wall.Material = Enum.Material.Neon
    wall.Parent = parent
    return wall
end

function Jail.recapture(character)
    local player = Players:GetPlayerFromCharacter(character)
    if not (player and character and character.PrimaryPart) then
        return true
    end
    local existing = jailParts[player.UserId]
    if existing then
        task.defer(character.PivotTo, character, existing.CFrame)
        return true
    end
    return false
end

function Jail.new(player, jailColor, jailTransparency)
    local character = player.Character
    if Jail.recapture(character) then return end

    local root = character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not (player and root and humanoid) then return end

    local existing = jailParts[player.UserId]
    if existing then
        task.defer(character.PivotTo, character, existing.CFrame)
        return
    end

    local rootCFrame = root.CFrame
    local groundPos = rootCFrame.Position - Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0)

    local _, sizeChar = character:GetBoundingBox()
    local width = math.max(sizeChar.X, sizeChar.Y, sizeChar.Z) + 2
    local position = groundPos + Vector3.new(0, width / 2, 0)
    local size = Vector3.new(width, width, width)

    local kJail = Instance.new("Part")
    kJail.Name = "kJail"
    kJail.Anchored = true
    kJail.Size = size
    kJail.CFrame = CFrame.new(position)
    kJail.Color = jailColor or Color3.new(0, 0, 0) -- Default color
    kJail.Transparency = jailTransparency or 0.3 -- Default transparency
    kJail.Material = Enum.Material.Neon
    kJail.TopSurface = Enum.SurfaceType.Smooth
    kJail.BottomSurface = Enum.SurfaceType.Smooth

    jailParts[player.UserId] = kJail

    -- Create walls
    createWall(kJail, Vector3.new(1, width, width), position - Vector3.new(width/2, 0, 0), 1) -- Left
    createWall(kJail, Vector3.new(1, width, width), position + Vector3.new(width/2, 0, 0), 1) -- Right
    createWall(kJail, Vector3.new(width, width, 1), position - Vector3.new(0, 0, width/2), 1) -- Front
    createWall(kJail, Vector3.new(width, width, 1), position + Vector3.new(0, 0, width/2), 1) -- Back

    kJail.CanCollide = false
    kJail.Parent = workspace

    root.CFrame = rootCFrame

    local lowerBounds = position - size / 2
    local upperBounds = position + size / 2

    task.defer(function()
        repeat
            task.wait()
            if player and player.Character and not pointInBounds(player.Character:GetPivot().Position, lowerBounds, upperBounds) then
                Jail.recapture(player.Character)
            end
        until not player or jailParts[player.UserId] == nil
    end)

    return kJail
end

Util.SafePlayerAdded(function(player)
    local characterAddedConnection
    characterAddedConnection = player.CharacterAdded:Connect(function(character)
        Jail.recapture(character)
    end)
    
    if player.Character then
        Jail.recapture(player.Character)
    end

    -- Clean up connection when player leaves
    player.AncestryChanged:Connect(function(_, parent)
        if not parent then
            characterAddedConnection:Disconnect()
        end
    end)
end)

return Jail
