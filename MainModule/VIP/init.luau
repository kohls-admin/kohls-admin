local Auth = require(script.Parent:WaitForChild("Auth"))
local Util = require(script.Parent:WaitForChild("Util"))

local VIP = {}

local vipDonations = { 5411126, 5391361, 5391359 }
local smallDonations = { 5391356, 5391355 }

local function getDonationLevel(player)
	local ok, status = Util.Retry(function()
		return Util.Services.MarketplaceService:GetUserSubscriptionStatusAsync(player, "EXP-6178947350651470068")
	end, 5, 0.2, 1)
	if ok and status.IsSubscribed then
		return 4
	end

	for index, passId in vipDonations do
		local success, result = Util.Retry(function()
			return Util.Services.MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
		end, 5, 0.2, 1)
		if success and result then
			return 4 - index
		end
	end

	for index, passId in smallDonations do
		local success, result = Util.Retry(function()
			return Util.Services.MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
		end, 5, 0.2, 1)
		if success and result then
			return 0
		end
	end

	return
end

local function setDonationLevel(player)
	player:SetAttribute("_KDonationLevel", getDonationLevel(player))
end

local adminUGCMap = {}

for _, module in script:WaitForChild("UGC"):GetChildren() do
	local result = require(module)
	if result then
		adminUGCMap[result.MatchId] = result
	end
end

if Util.Services.RunService:IsServer() then
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
		task.spawn(setDonationLevel, player)
		player.CharacterAdded:Connect(VIP.CharacterAdded)
		player.CharacterAppearanceLoaded:Connect(VIP.UGCHandler)
		if player.Character then
			VIP.UGCHandler(player.Character)
		end
	end)

	Util.Services.MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased then
			local level = player:GetAttribute("_KDonationLevel")
			local vipIndex = table.find(vipDonations, passId)
			if vipIndex then
				level = math.max(level, 4 - vipIndex)
				Auth.userRoleAdd(player.UserId, "mod")
			end
			if table.find(smallDonations, passId) then
				level = math.max(level, 0)
			end
			player:SetAttribute("_KDonationLevel", level)
		end
	end)
end

return VIP
