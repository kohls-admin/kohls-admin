local Util = require(script.Parent:WaitForChild("Util"))

local VIP = {}

local adminUGCMap = {}

for _, module in script:WaitForChild("UGC"):GetChildren() do
	local result = require(module)
	adminUGCMap[result.MatchId] = result
end

function VIP.UGCHandler(character)
	for _, child in character:GetChildren() do
		if not child:IsA("Accessory") then
			continue
		end

		local handle = child:FindFirstChild("Handle")
		if not handle then
			continue
		end

		local mesh
		if handle:IsA("MeshPart") then
			mesh = handle.MeshId
		else
			local specialMesh = handle:FindFirstChildOfClass("SpecialMesh")
			if specialMesh then
				mesh = specialMesh.MeshId
			end
		end

		local ugcEffect = adminUGCMap[mesh]
		if ugcEffect then
			ugcEffect.Method(character, child)
		end
	end
end

function VIP.CharacterAdded(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	humanoid.ApplyDescriptionFinished:Connect(function()
		VIP.UGCHandler(character)
	end)
end

Util.SafePlayerAdded(function(player)
	player.CharacterAdded:Connect(VIP.CharacterAdded)
	player.CharacterAppearanceLoaded:Connect(VIP.UGCHandler)
end)

return VIP
