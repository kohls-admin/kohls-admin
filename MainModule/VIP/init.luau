local Auth = require(script.Parent:WaitForChild("Auth"))
local Data = require(script.Parent:WaitForChild("Data"))
local Remote = require(script.Parent:WaitForChild("Remote"))
local Util = require(script.Parent:WaitForChild("Util"))

local VIP = {}

-- premium, supervip, vip
local legacyDonations = { 5411126, 5391361, 5391359 }

local function getDonationLevel(player)
	local ok, status = Util.Retry(function()
		return Util.Services.MarketplaceService:GetUserSubscriptionStatusAsync(player, "EXP-7266962490056769807")
	end, 5, 0.2, 1)
	if ok and status.IsSubscribed then
		return 4
	end

	for index, passId in legacyDonations do
		local success, result = Util.Retry(function()
			return Util.Services.MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
		end, 5, 0.2, 1)
		if success and result then
			return 4 - index
		end
	end

	return
end

local function setDonationLevel(player)
	player:SetAttribute("_KDonationLevel", getDonationLevel(player))
end

local adminUGCMap = {}

for _, module in script:WaitForChild("UGC"):GetChildren() do
	task.spawn(function()
		local result = require(module)
		if result then
			adminUGCMap[result.MatchId] = result
		end
	end)
end

if Util.Services.RunService:IsServer() then
	Remote.VIPUGCMethod.OnServerEvent:Connect(function(player, assetId, match, equip, name)
		if not Data.settings.vip then
			return
		end

		local donationLevel = player:GetAttribute("_KDonationLevel") or 0
		local ok, result = true, true
		if donationLevel < 4 then -- confirm UGC ownership if not VIP sub
			ok, result = Util.Retry(function()
				return Util.Services.MarketplaceService:PlayerOwnsAsset(player, assetId)
			end, 5, 1, 2)
		end

		if ok and result then
			local ugcEffect = adminUGCMap[match]
			if ugcEffect and player.Character then
				if not equip then
					local existing = player.Character:FindFirstChild(ugcEffect.Name)
					if existing then
						existing:Destroy()
					end
					return
				end
				ugcEffect.Method(player.Character, { Name = name, Destroy = tick })
			end
		end
	end)

	function VIP.UGCHandler(character)
		if not Data.settings.vip then
			return
		end
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
			local level = player:GetAttribute("_KDonationLevel") or 0
			local vipIndex = table.find(legacyDonations, passId)
			if vipIndex then
				level = math.max(level, 4 - vipIndex)
				if Data.settings.vip then
					Auth.userRoleAdd(player.UserId, "vip")
				end
			end
			player:SetAttribute("_KDonationLevel", level)
		end
	end)
end

return VIP
