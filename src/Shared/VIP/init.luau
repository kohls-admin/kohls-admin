local Auth = require(script.Parent:WaitForChild("Auth"))
local Data = require(script.Parent:WaitForChild("Data"))
local Util = require(script.Parent:WaitForChild("Util"))

local Popup = require(script:WaitForChild("Popup"))
local Purchasables = require(script:WaitForChild("Purchasables"))
local Title = require(script:WaitForChild("Title"))

local Remote = Util.Remote

local VIP = {
	ORIGINAL_ASSET_ID = 110019084552349,
	SALE_ASSET_ID = 115444443724463,
	SALE_DELAY = 600,
	allowedBulkPurchaseIds = {},
	effects = {},
	popup = Popup,
	purchasables = Purchasables,
	saleStateChanged = Util.Signal.new(),
	titleDefinition = Title.definition,
}

local priceCache: { [string]: number } = {}

function VIP.isOnSale(): boolean
	local player = Util.Service.Players.LocalPlayer
	local initialJoin = player and player:GetAttribute("_KInitialJoin")
	if not initialJoin then
		return false
	end
	return workspace:GetServerTimeNow() - initialJoin >= VIP.SALE_DELAY
end

function VIP.getActiveAssetId(): number
	return if VIP.isOnSale() then VIP.SALE_ASSET_ID else VIP.ORIGINAL_ASSET_ID
end

function VIP.getPriceAsync(id: number, productType: Enum.InfoType): number?
	local key = `{productType.Name}:{id}`
	if priceCache[key] then
		return priceCache[key]
	end
	local ok, result = Util.Retry(function()
		return Util.Service.Marketplace:GetProductInfoAsync(id, productType).PriceInRobux
	end)
	if ok and type(result) == "number" then
		priceCache[key] = result
		return result
	end
	return nil
end

function VIP.updatePurchasePrice(purchase: { role: string?, gamepass: number? }, button: any)
	local isVIPAsset = purchase.role == "vip" and Data.settings.vip
	local onSale = isVIPAsset and VIP.isOnSale()
	local targetId = if isVIPAsset then VIP.getActiveAssetId() else purchase.gamepass
	if not targetId then
		return
	end
	local productType = if isVIPAsset then Enum.InfoType.Asset else Enum.InfoType.GamePass
	local price = VIP.getPriceAsync(targetId, productType)
	local text = if price then tostring(price) else if isVIPAsset then (if onSale then "479" else "799") else "?"
	button._content.Price.Text = if onSale then `<font color="#0f0"><b>{text}</b></font>` else `<b>{text}</b>`
end

-- vip, supervip, premium
local gamePassDonations = { 5391359, 5391361, 5411126 }
local assetDonations = {
	{ 88978146769822, 441133423, 313102724 },
	{ 115403290087767, 441134066, 423601416 },
}

-- 5 group member
-- 4 chat commands/subscriber
-- 3 premium donor
-- 2 super vip
-- 1 vip
local function getDonationLevel(player)
	if Util.Service.Run:IsStudio() and shared._K_INTERFACE and shared._K_INTERFACE.DEBUG then
		return Util.Service.ReplicatedStorage:GetAttribute("DonationLevel") or 0
	end

	local okRank, info = Util.Retry(function()
		return Util.Service.Group:GetRolesInGroupAsync(player.UserId, 3403354)
	end)
	-- a user can hold several roles and their order doesn't follow Rank
	if okRank and type(info) == "table" and type(info.Roles) == "table" then
		for _, role in info.Roles do
			if role.Rank > 1 then
				return 5
			end
		end
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
			Auth.asyncRoleAdd(player.UserId, "vip")
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
	local checkingAsset = {}
	local function ownsAsset(player, assetId)
		local ownedUGC = ownedCache[player.UserId]
		if not ownedUGC then
			ownedUGC = {}
			ownedCache[player.UserId] = ownedUGC
		end

		if ownedUGC[assetId] ~= nil then
			return ownedUGC[assetId]
		end

		local checkKey = `{player.UserId}:{assetId}`
		if checkingAsset[checkKey] then
			return false
		end
		checkingAsset[checkKey] = true

		local ok, result = Util.Retry(function()
			return Util.Service.Marketplace:PlayerOwnsAssetAsync(player, assetId)
		end)
		checkingAsset[checkKey] = nil
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
		-- clients only send a color name; an Instance here would let them destroy anything with a Handle
		if
			type(assetId) ~= "number"
			or type(match) ~= "string"
			or ugcAssetMatch[assetId] ~= match
			or type(equip) ~= "boolean"
			or (name ~= nil and (type(name) ~= "string" or #name > 64))
		then
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

		if checkingAsset[`{player.UserId}:{assetId}`] then
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

	local _ = Remote.VIPUGCMethod:Connect(VIP.Effect)

	local checkingTitle = {}
	function VIP.Title(player: Player, title, ...)
		local key = title and string.lower(title)
		local definition = Title.definition[key]
		if definition and definition.gamepass then
			local cachedOwner = definition.ownerCache[player.UserId]
			if cachedOwner == false then
				return
			elseif cachedOwner ~= true then -- known owners skip the marketplace requests
				local checkKey = `{player.UserId}:{key}`
				if checkingTitle[checkKey] then
					return
				end
				checkingTitle[checkKey] = true
				local owned = false
				local allChecked = true
				if definition.assetId then
					local assets = if typeof(definition.assetId) == "table"
						then definition.assetId
						else { definition.assetId }
					for _, assetId in assets do
						if not (player and player.Parent) then
							checkingTitle[checkKey] = nil
							return
						end
						local okAsset, result = Util.Retry(function()
							return Util.Service.Marketplace:PlayerOwnsAssetAsync(player, assetId)
						end)
						if okAsset then
							if result then
								owned = true
								definition.ownerCache[player.UserId] = true
								break
							end
						else
							allChecked = false
						end
					end
				end
				if not (player and player.Parent) then
					checkingTitle[checkKey] = nil
					return
				end
				if not owned and definition.gamepass then
					local okGamePass, result = Util.Retry(function()
						return Util.Service.Marketplace:UserOwnsGamePassAsync(player.UserId, definition.gamepass)
					end)
					if okGamePass and result then
						owned = true
						definition.ownerCache[player.UserId] = true
					elseif okGamePass and allChecked then
						definition.ownerCache[player.UserId] = false
					end
				end
				checkingTitle[checkKey] = nil
				if not owned or not (player and player.Parent) then
					return -- early return if they don't own or left during the check
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

	local _ = Remote.Title:Connect(function(player: Player, title: string?)
		if not Data.settings.vip then
			return
		end
		if type(title) ~= "string" then
			title = nil
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
	local _ = Util.Service.Players.PlayerRemoving:Connect(function(player)
		if playerCleanup[player] then
			for _, connection in playerCleanup[player] do
				if connection and connection.Connected then
					connection:Disconnect()
				end
			end
			table.clear(playerCleanup[player])
		end
		playerCleanup[player] = nil
		ownedCache[player.UserId] = nil
		VIP.effects[player.UserId] = nil
	end)

	Util.SafePlayerAdded(function(player)
		task.spawn(setDonationLevel, player)
		playerCleanup[player] = {}
		table.insert(playerCleanup[player], player.CharacterAdded:Connect(VIP.CharacterAdded))
		table.insert(playerCleanup[player], player.CharacterAppearanceLoaded:Connect(VIP.EffectHandler))
		local charRemovingConn = player.CharacterRemoving:Connect(function(character)
			if characterCleanup[character] and characterCleanup[character].Connected then
				characterCleanup[character]:Disconnect()
			end
			characterCleanup[character] = nil
		end)
		table.insert(playerCleanup[player], charRemovingConn)
		if player.Character then
			VIP.EffectHandler(player.Character)
		end
	end)

	-- exploits can fake purchased, so only verify ids KA grants something for, one check per player and id at a time
	local verifying = {}
	local function verifyPurchase(player: Player, id: number, titles: { any }, ownsAsync: () -> boolean): boolean
		local key = `{player.UserId}:{id}`
		if verifying[key] then
			return false
		end
		verifying[key] = true
		-- ownership can lag a few seconds behind a real purchase
		local owned = Util.Retry(function()
			assert(ownsAsync(), "not owned")
		end, 3)
		verifying[key] = nil

		for _, definition in titles do
			if owned then
				definition.ownerCache[player.UserId] = true
			elseif definition.ownerCache[player.UserId] == false then
				-- let VIP.Title check again later instead of staying locked out until rejoin
				definition.ownerCache[player.UserId] = nil
			end
		end
		return owned
	end

	local function handleAssetPurchase(player: Player, assetId: number, fromBulk: boolean?)
		local titles = {}
		for _, definition in Title.definition do
			if
				definition.assetId == assetId
				or (type(definition.assetId) == "table" and table.find(definition.assetId, assetId))
			then
				table.insert(titles, definition)
			end
		end

		local chatLevel = if fromBulk
			then (if table.find(Purchasables.chatCommands, assetId)
				then 4
				else table.find(Purchasables.chatCommandsLower, assetId) or 0)
			else 0

		if
			(ugcAssetMatch[assetId] or titles[1] or chatLevel > 0)
			and verifyPurchase(player, assetId, titles, function()
				return Util.Service.Marketplace:PlayerOwnsAssetAsync(player, assetId)
			end)
		then
			local ownedUGC = ownedCache[player.UserId]
			if not ownedUGC then
				ownedUGC = {}
				ownedCache[player.UserId] = ownedUGC
			end
			ownedUGC[assetId] = true
			if chatLevel > 0 then
				setDonationLevel(player, chatLevel)
				Remote.RolesNotification:Fire(player)
			end
		end
	end

	local _ = Remote.VIPCheck:Connect(function(player, id)
		if type(id) ~= "number" or not VIP.allowedBulkPurchaseIds[id] then
			return
		end
		handleAssetPurchase(player, id, true)
	end)

	local _ = Util.Service.Marketplace.PromptPurchaseFinished:Connect(function(player, assetId, purchased)
		if not purchased then
			return
		end
		handleAssetPurchase(player, assetId, false)
	end)

	local _ = Util.Service.Marketplace.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end

		local vipIndex = table.find(gamePassDonations, passId)
		local titles = {}
		for _, definition in Title.definition do
			if definition.gamepass == passId then
				table.insert(titles, definition)
			end
		end

		if
			(vipIndex or titles[1])
			and verifyPurchase(player, passId, titles, function()
				return Util.Service.Marketplace:UserOwnsGamePassAsync(player.UserId, passId)
			end)
		then
			local level = player:GetAttribute("_KDonationLevel") or 0
			if vipIndex then
				level = math.max(level, vipIndex)
				if Data.settings.vip then
					Auth.asyncRoleAdd(player.UserId, "vip")
					Remote.RolesNotification:Fire(player)
				end
			end
			player:SetAttribute("_KDonationLevel", level)
		end
	end)

	local _ = Util.Remote.PromptBulkPurchase:Connect(function(player, id)
		if type(id) == "number" and VIP.allowedBulkPurchaseIds[id] then
			local items = { { Type = Enum.MarketplaceProductType.AvatarAsset, Id = tostring(id) } }
			Util.Service.Marketplace:PromptBulkPurchase(player, items, {})
		end
	end)

	for _, id in Purchasables.chatCommands do
		VIP.allowedBulkPurchaseIds[id] = true
	end

	for _, id in Purchasables.chatCommandsLower do
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
