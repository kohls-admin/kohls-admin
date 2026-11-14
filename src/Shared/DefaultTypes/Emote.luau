local AvatarEditorService = game:GetService("AvatarEditorService")
local InsertService = game:GetService("InsertService")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local _K
local Remote

local emotes = {}
local emoteItemFromId = {}
local animationToEmoteId = {}
local emoteToAnimationId = {}
local initializedContexts = setmetatable({}, { __mode = "k" })

local function isEmote(id: number)
	if type(id) ~= "number" or id < 1 or id > 2 ^ 53 or math.floor(id) ~= id then
		return false
	end
	if emoteItemFromId[id] ~= nil then
		return emoteItemFromId[id]
	end

	local ok, result = pcall(MarketplaceService.GetProductInfoAsync, MarketplaceService, id)
	if ok and type(result) == "table" and result.AssetTypeId == Enum.AssetType.EmoteAnimation.Value then
		local item = {
			animationId = 0,
			name = result.Name,
			nameLower = string.lower(result.Name),
			emoteId = id,
			canSell = result.IsForSale and not (result.IsLimited or result.IsLimitedUnique),
		}
		if RunService:IsClient() then
			table.insert(emotes, item)
		end
		emoteItemFromId[id] = item
		if item.canSell then
			_K.VIP.allowedBulkPurchaseIds[id] = true
		end
		return item
	end

	if ok then
		emoteItemFromId[id] = false
	end
	return false
end

local function getAnimationIdFromEmoteId(emoteId: number, skipBroadcast: boolean?): number?
	if emoteToAnimationId[emoteId] then
		return emoteToAnimationId[emoteId]
	end

	if not isEmote(emoteId) then
		return
	end

	-- clients can't LoadAsset
	if RunService:IsClient() then
		return 0
	end

	local ok, result = _K.Util.Retry(function()
		local asset = InsertService:LoadAsset(emoteId)
		local animation = asset:FindFirstChildWhichIsA("Animation")
		local animationId = animation and animation.AnimationId
		asset:Destroy()
		return animationId
	end, 3)

	if ok and result then
		result = string.match(result, "%d+$")
		if result then
			result = tonumber(result)
			animationToEmoteId[result] = emoteId
			emoteToAnimationId[emoteId] = result

			local item = emoteItemFromId[emoteId]
			if item then
				item.animationId = result
				if not table.find(emotes, item) then
					table.insert(emotes, item)
				end
				if not skipBroadcast then
					Remote:FireAll({ item })
				end
			end
			return result
		else
			warn("Invalid animationId")
		end
	else
		warn(result)
	end

	return
end

local emoteType = {
	filterLog = true,
	transform = function(v)
		return tonumber(v) or v
	end,
	validate = function(v)
		if type(v) == "number" and v ~= math.floor(v) then
			return false, "Only whole numbers are valid"
		end
		return v ~= nil, "Invalid emote"
	end,
	parse = function(v, self)
		if type(v) == "number" then
			local animationId = getAnimationIdFromEmoteId(v)
			if animationId then
				return animationId
			end
		elseif type(v) == "string" then
			local query = string.lower(v)
			local partial
			for _, emoteItem in emotes do
				if query == emoteItem.nameLower then
					return emoteItem.animationId
				end
				if not partial and string.find(emoteItem.nameLower, query, 1, true) == 1 then
					partial = emoteItem
				end
			end
			if partial then
				return partial.animationId
			end
		end
		if self.definition.optional and self.rawArg == "" then
			return ""
		end
		return nil, "Could not parse emote"
	end,
	suggestions = function(text)
		local suggestions = { if tonumber(text) then text else nil }
		for _, item in emotes do
			table.insert(suggestions, item.name)
		end
		return suggestions
	end,
}

return function(context)
	if initializedContexts[context] then
		return
	end
	initializedContexts[context] = true
	_K = context
	Remote = _K.Remote.EmoteType
	_K.Data.animationToEmoteId = animationToEmoteId
	_K.Data.emoteToAnimationId = emoteToAnimationId
	_K.Data.emoteItemFromId = emoteItemFromId
	_K.Data.emotes = emotes
	if not _K.Registry.types.emote then
		_K.Registry.registerType("emote", emoteType)
	end
	if not _K.Registry.types.emotes then
		_K.Registry.registerType("emotes", { listable = true }, emoteType)
	end

	if RunService:IsServer() then
		local loaded = false
		local sent: { [Player]: boolean } = {}
		local pending: { [Player]: boolean } = {}

		local _ = _K.Service.Players.PlayerRemoving:Connect(function(player)
			sent[player] = nil
			pending[player] = nil
		end)

		local _ = Remote:Connect(function(player)
			if sent[player] then
				return
			end
			if not loaded then
				pending[player] = true
				return
			end
			sent[player] = true
			Remote:Fire(player, emotes)
		end)

		task.spawn(function()
			local okLoad, loadErr = pcall(function()
				local params = CatalogSearchParams.new()
				params.AssetTypes = { Enum.AvatarAssetType.EmoteAnimation }
				params.CreatorId = 3403354
				params.CreatorType = Enum.CreatorTypeFilter.Group

				local okPages, pages = _K.Util.Retry(function()
					return AvatarEditorService:SearchCatalogAsync(params)
				end)

				if not okPages then
					warn(pages)
					return
				end

				local okItems, iter = pcall(_K.Util.iterPageItems, pages)

				if not okItems then
					warn(iter)
					return
				end

				local tasks = _K.Util.Tasks.new()
				local okIter, iterErr = pcall(function()
					for item in iter do
						local canSell = item.IsPurchasable ~= false
						local existing = emoteItemFromId[item.Id]
						if type(existing) == "table" then
							existing.default = true
							existing.name = item.Name
							existing.nameLower = string.lower(item.Name)
							existing.canSell = canSell
							if not table.find(emotes, existing) then
								table.insert(emotes, existing)
							end
						else
							local emote = {
								default = true,
								animationId = 0,
								emoteId = item.Id,
								name = item.Name,
								nameLower = string.lower(item.Name),
								canSell = canSell,
							}
							table.insert(emotes, emote)
							emoteItemFromId[item.Id] = emote
						end
						if canSell then
							_K.VIP.allowedBulkPurchaseIds[item.Id] = true
						end
						tasks:add(getAnimationIdFromEmoteId, item.Id, true)
					end
				end)
				if not okIter then
					warn(iterErr)
				end
				tasks:wait()
			end)
			if not okLoad then
				warn(loadErr)
			end

			loaded = true
			for player in pending do
				pending[player] = nil
				if not sent[player] then
					sent[player] = true
					Remote:Fire(player, emotes)
				end
			end
		end)
	else
		local _ = Remote:Connect(function(data)
			for _, item in data do
				if item.animationId and item.animationId ~= 0 then
					emoteToAnimationId[item.emoteId] = item.animationId
					animationToEmoteId[item.animationId] = item.emoteId
				end
				local existing = emoteItemFromId[item.emoteId]
				if type(existing) == "table" then
					local owned = existing.owned
					table.clear(existing)
					for k, v in item do
						existing[k] = v
					end
					if existing.owned == nil then
						existing.owned = owned
					end
				else
					table.insert(emotes, item)
					emoteItemFromId[item.emoteId] = item
				end
			end

			if
				_K
				and _K.Registry.commands.emotes
				and _K.Registry.commands.emotes.env
				and _K.Registry.commands.emotes.env.scroller
			then
				_K.Registry.commands.emotes.env.scroller:refreshList()
			end
		end)
		Remote:Fire()
	end
end
