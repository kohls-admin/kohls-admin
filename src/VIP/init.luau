local Auth = require(script.Parent:WaitForChild("Auth"))
local Data = require(script.Parent:WaitForChild("Data"))
local Remote = require(script.Parent:WaitForChild("Remote"))
local Util = require(script.Parent:WaitForChild("Util"))


local VIP = { effects = {} }

-- vip, supervip, premium
local gamePassDonations = { 5391359, 5391361, 5411126 }
local assetDonations = { 313102724, 423601416 }

-- 5 group member
-- 4 subscriber
-- 3 premium donor
-- 2 super vip
-- 1 vip
local function getDonationLevel(player)
	local okRank, rank = Util.Retry(function()
		return player:GetRankInGroup(3403354)
	end)
	if okRank and rank > 1 then
		return 5
	end

	local okSubscription, status = Util.Retry(function()
		return Util.Services.MarketplaceService:GetUserSubscriptionStatusAsync(player, "EXP-4118475727682928968")
	end)
	if okSubscription and status.IsSubscribed then
		return 4
	end

	for level = #gamePassDonations, 1, -1 do
		local okGamePass, result = Util.Retry(function()
			return Util.Services.MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamePassDonations[level])
		end)
		if okGamePass and result then
			return level
		end
	end

	for level = #assetDonations, 1, -1 do
		local okAsset, result = Util.Retry(function()
			return Util.Services.MarketplaceService:PlayerOwnsAsset(player, assetDonations[level])
		end)
		if okAsset and result then
			return level
		end
	end

	return 0
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
	local ownedCache = {}
	local function ownsAsset(player, assetId)
		local ownedUGC = ownedCache[player.UserId]
		if not ownedUGC then
			ownedUGC = {}
			ownedCache[player.UserId] = ownedUGC
		end

		if ownedUGC[assetId] then
			return true
		end

		local ok, result = Util.Retry(function()
			return Util.Services.MarketplaceService:PlayerOwnsAsset(player, assetId)
		end)
		if ok then
			ownedUGC[assetId] = result
			return result
		end

		return
	end

	local ugcAssetMatch = {
		-- wings
		[133292294488871] = "rbxassetid://89119211625300", -- light
		[110848154960799] = "rbxassetid://89119211625300", -- dark
		[92807314389236] = "rbxassetid://89119211625300", -- gold
		-- crowns
		[18966788838] = "rbxassetid://18966762965", -- light
		[106645613603989] = "rbxassetid://18966762965", -- dark
		[99317257118206] = "rbxassetid://18966762965", -- gold
	}

	local cache = {}
	Remote.VIPUGCMethod.OnServerEvent:Connect(function(player, assetId, match, equip, name)
		if not Data.settings.vip then
			return
		end

		local ugcEffect = adminUGCMap[match]
		if not (ugcEffect and player.Character) then
			return
		end

		local userEffects = VIP.effects[player.UserId]
		if not userEffects then
			userEffects = {}
			VIP.effects[player.UserId] = userEffects
		end

		local existing = player.Character:FindFirstChild(ugcEffect.Name)
		if existing then
			existing:Destroy()
		end

		if not equip then
			userEffects[match] = nil
			return
		end

		if ugcAssetMatch[assetId] ~= match then
			return
		end

		local donationLevel = player:GetAttribute("_KDonationLevel") or 0
		local owned = donationLevel > 2
			or (match == "rbxassetid://18966762965" and donationLevel > 1)
			or ownsAsset(player, assetId)

		local tried = cache[assetId]
		if not tried then
			tried = {}
			cache[assetId] = tried
		end

		if owned or not tried[player.UserId] then
			local try
			if not tried[player.UserId] then
				try = true
				tried[player.UserId] = true
			end

			local ugc = ugcEffect.Method(player.Character, name)

			if try and not owned then
				task.delay(15, function()
					if ugc then
						ugc:Destroy()
					end
				end)
			else
				userEffects[match] = { Method = ugcEffect.Method, Params = { name } }
			end
		end
	end)

	function VIP.EffectHandler(character)
		if not Data.settings.vip then
			return
		end

		-- ugc avatar effects
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
				task.spawn(ugcEffect.Method, character, child)
			end
		end

		-- vip equipped effects
		local player = Util.Services.Players:GetPlayerFromCharacter(character)
		local effects = player and VIP.effects[player.UserId]
		if not effects then
			return
		end

		for _, effect in effects do
			task.spawn(effect.Method, character, unpack(effect.Params))
		end
	end

	function VIP.CharacterAdded(character)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end
		humanoid.ApplyDescriptionFinished:Connect(function()
			VIP.EffectHandler(character)
		end)
	end

	Util.SafePlayerAdded(function(player)
		task.spawn(setDonationLevel, player)
		player.CharacterAdded:Connect(VIP.CharacterAdded)
		player.CharacterAppearanceLoaded:Connect(VIP.EffectHandler)
		if player.Character then
			VIP.EffectHandler(player.Character)
		end
	end)

	Util.Services.MarketplaceService.PromptPurchaseFinished:Connect(function(player, assetId, purchased)
		if purchased then
			local ownedUGC = ownedCache[player.UserId]
			if not ownedUGC then
				ownedUGC = {}
				ownedCache[player.UserId] = ownedUGC
			end
			ownedUGC[assetId] = true
		end
	end)

	Util.Services.MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased then
			local level = player:GetAttribute("_KDonationLevel") or 0
			local vipIndex = table.find(gamePassDonations, passId)
			if vipIndex then
				level = math.max(level, vipIndex)
				if Data.settings.vip then
					Auth.userRoleAdd(player.UserId, "vip")
				end
			end
			player:SetAttribute("_KDonationLevel", level)
		end
	end)
end

return VIP
