local Auth = require(script.Parent:WaitForChild("Auth"))
local Data = require(script.Parent:WaitForChild("Data"))
local Util = require(script.Parent:WaitForChild("Util"))

local Popup = require(script:WaitForChild("Popup"))
local Purchasables = require(script:WaitForChild("Purchasables"))
local Title = require(script:WaitForChild("Title"))

local Remote = Util.Remote

local VIP = { allowedBulkPurchaseIds = {}, effects = {}, popup = Popup, purchasables = Purchasables }

-- vip, supervip, premium
local gamePassDonations = { 5391359, 5391361, 5411126 }
local assetDonations = { { 441133423, 313102724 }, { 441134066, 423601416 } }

-- 5 group member
-- 4 chat commands/subscriber
-- 3 premium donor
-- 2 super vip
-- 1 vip
local function getDonationLevel(player)
	if Util.Service.Run:IsStudio() and shared._K_INTERFACE and shared._K_INTERFACE.DEBUG then
		return Util.Service.ReplicatedStorage:GetAttribute("DonationLevel") or 0
	end

	local okRank, rank = Util.Retry(function()
		return player:GetRankInGroupAsync(3403354)
	end)
	if okRank and rank > 1 then
		return 5
	end

	for _, ugcId in Purchasables.chatCommands do
		local ok, result = Util.Retry(function()
			return Util.Service.Marketplace:PlayerOwnsAssetAsync(player, ugcId)
		end)
		if ok and result then
			return 4
		end
	end

	for level = #gamePassDonations, 1, -1 do
		local okGamePass, result = Util.Retry(function()
			return Util.Service.Marketplace:UserOwnsGamePassAsync(player.UserId, gamePassDonations[level])
		end)
		if okGamePass and result then
			return level
		end
	end

	for level = #assetDonations, 1, -1 do
		for _, assetId in assetDonations[level] do
			local okAsset, result = Util.Retry(function()
				return Util.Service.Marketplace:PlayerOwnsAssetAsync(player, assetId)
			end)
			if okAsset and result then
				return level
			end
		end
	end

	return 0
end

local function setDonationLevel(player: Player, level: number?)
	if not level then
		level = getDonationLevel(player)
	end

	local current = player:GetAttribute("_KDonationLevel")
	player:SetAttribute("_KDonationLevel", math.max(level :: number, current or 0))

	if Data.settings.vip then
		if level > 0 then
			Auth.userRoleAdd(player.UserId, "vip")
		end
		if level < 3 then
			task.delay(8, Remote.VIPNotification.Fire, Remote.VIPNotification, player)
		end
	end
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

if Util.Service.Run:IsServer() then
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
			return Util.Service.Marketplace:PlayerOwnsAssetAsync(player, assetId)
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
	function VIP.Effect(player: Player, assetId: number, match: string, equip: boolean, name: string)
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
	end

	Remote.VIPUGCMethod:Connect(VIP.Effect)

	function VIP.Title(player: Player, title, ...)
		local definition = Title.definition[title and string.lower(title)]
		if definition and definition.gamepass then
			if definition.ownerCache[player.UserId] == false then
				return
			else
				local owned = false
				if definition.assetId then
					local assets = if typeof(definition.assetId) == "table"
						then definition.assetId
						else { definition.assetId }
					for _, assetId in assets do
						if not (player and player.Parent) then
							return
						end
						local okAsset, result = Util.Retry(function()
							return Util.Service.Marketplace:PlayerOwnsAssetAsync(player, assetId)
						end)
						if okAsset then
							definition.ownerCache[player.UserId] = result
							if result then
								owned = true
								break
							end
						end
					end
				end
				if not owned and definition.gamepass and player and player.Parent then
					local okGamePass, result = Util.Retry(function()
						return Util.Service.Marketplace:UserOwnsGamePassAsync(player.UserId, definition.gamepass)
					end)
					if okGamePass then
						definition.ownerCache[player.UserId] = result
					end
					if not (okGamePass and result) then
						return -- early return if they don't own
					end
				end
			end
		end

		local userEffects = VIP.effects[player.UserId]
		if not userEffects then
			userEffects = {}
			VIP.effects[player.UserId] = userEffects
		end

		userEffects.Title = if title then { Method = Title.Method, Params = { title, ... } } else nil

		if player.Character then
			Title.Method(player.Character, title, ...)
		end
	end

	Remote.Title:Connect(function(player: Player, title: string?)
		if not Data.settings.vip then
			return
		end
		local titleDefinition = Title.definition[title and string.lower(title)]
		if titleDefinition then
			VIP.Title(player, title)
		else
			VIP.Title(player)
		end
	end)

	function VIP.EffectHandler(character)
		if not Data.settings.vip or not character then
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
		local player = Util.Service.Players:GetPlayerFromCharacter(character)
		local effects = player and VIP.effects[player.UserId]
		if not effects then
			return
		end

		for _, effect in effects do
			task.spawn(effect.Method, character, unpack(effect.Params))
		end
	end

	local characterCleanup = {}

	function VIP.CharacterAdded(character)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end
		characterCleanup[character] = humanoid.ApplyDescriptionFinished:Connect(function()
			VIP.EffectHandler(character)
		end)
	end

	local playerCleanup = {}
	Util.Service.Players.PlayerRemoving:Connect(function(player)
		if playerCleanup[player] then
			for _, connection in playerCleanup[player] do
				if connection and connection.Connected then
					connection:Disconnect()
				end
			end
			table.clear(playerCleanup[player])
		end
		playerCleanup[player] = nil
	end)

	Util.SafePlayerAdded(function(player)
		task.spawn(setDonationLevel, player)
		playerCleanup[player] = {}
		table.insert(playerCleanup[player], player.CharacterAdded:Connect(VIP.CharacterAdded))
		table.insert(playerCleanup[player], player.CharacterAppearanceLoaded:Connect(VIP.EffectHandler))
		table.insert(
			playerCleanup[player],
			player.CharacterRemoving:Connect(function(character)
				if characterCleanup[character] and characterCleanup[character].Connected then
					characterCleanup[character]:Disconnect()
				end
				characterCleanup[character] = nil
			end)
		)
		if player.Character then
			VIP.EffectHandler(player.Character)
		end
	end)

	do
		local checking = {}
		Remote.VIPCheck:Connect(function(player, id)
			if table.find(Purchasables.chatCommands, id) and not checking[player] then
				checking[player] = true
				local ok, result = Util.Retry(function()
					return Util.Service.Marketplace:PlayerOwnsAssetAsync(player, id)
				end)
				if ok and result then
					setDonationLevel(player, 4)
					Remote.RolesNotification:Fire(player)
				end
				checking[player] = nil
			end
		end)
	end

	Util.Service.Marketplace.PromptPurchaseFinished:Connect(function(player, assetId, purchased)
		if purchased then
			local ownedUGC = ownedCache[player.UserId]
			if not ownedUGC then
				ownedUGC = {}
				ownedCache[player.UserId] = ownedUGC
			end
			ownedUGC[assetId] = true

			for title, definition in Title.definition do
				if definition.assetId then
					local assets = if type(definition.assetId) == "table"
						then definition.assetId
						else { definition.assetId }
					for _, id in assets do
						if id == assetId then
							definition.ownerCache[player.UserId] = true
							break
						end
					end
				end
			end
		end
	end)

	Util.Service.Marketplace.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased then
			local level = player:GetAttribute("_KDonationLevel") or 0
			local vipIndex = table.find(gamePassDonations, passId)
			if vipIndex then
				level = math.max(level, vipIndex)
				if Data.settings.vip then
					Auth.userRoleAdd(player.UserId, "vip")
					Remote.RolesNotification:Fire(player)
				end
			end
			player:SetAttribute("_KDonationLevel", level)

			for title, definition in Title.definition do
				if definition.gamepass == passId then
					definition.ownerCache[player.UserId] = true
				end
			end
		end
	end)

	Util.Remote.PromptBulkPurchase:Connect(function(player, id)
		if type(id) == "number" and VIP.allowedBulkPurchaseIds[id] then
			local items = { { Type = Enum.MarketplaceProductType.AvatarAsset, Id = tostring(id) } }
			Util.Service.Marketplace:PromptBulkPurchase(player, items, {})
		end
	end)

	for _, id in Purchasables.chatCommands do
		VIP.allowedBulkPurchaseIds[id] = true
	end

	for _, data in Purchasables.donations do
		VIP.allowedBulkPurchaseIds[data.assetId] = true
	end

	for _, data in Purchasables.scriptedUGC do
		VIP.allowedBulkPurchaseIds[data.id] = true
	end
end

return VIP
