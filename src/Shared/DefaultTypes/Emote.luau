local AvatarEditorService = game:GetService("AvatarEditorService")
local InsertService = game:GetService("InsertService")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local Util = require(script.Parent.Parent:WaitForChild("Util"))

local _K, Remote

local emotes = {}
local emoteItemFromId = {}
local animationToEmoteId = {}
local emoteToAnimationId = {}

local function isEmote(id: number)
	if emoteItemFromId[id] then
		return emoteItemFromId[id]
	end

	local ok, result = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id)
	if ok and type(result) == "table" and result.AssetTypeId == Enum.AssetType.EmoteAnimation.Value then
		local item = {
			name = result.Name,
			nameLower = string.lower(result.Name),
			emoteId = id,
			canSell = result.IsForSale and not (result.isLimited or result.isLimitedUnique),
		}
		table.insert(emotes, item)
		emoteItemFromId[id] = item
		if item.canSell then
			_K.VIP.allowedBulkPurchaseIds[id] = true
		end
		return item
	end

	return false
end

local function getAnimationIdFromEmoteId(emoteId: number): number?
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

	local ok, result = pcall(function()
		local asset = InsertService:LoadAsset(emoteId)
		local animation = asset:FindFirstChildWhichIsA("Animation")
		local animationId = animation and animation.AnimationId
		asset:Destroy()
		return animationId
	end)

	if ok and result then
		result = string.match(result, "%d+$")
		if result then
			result = tonumber(result)
			animationToEmoteId[result] = emoteId
			emoteToAnimationId[emoteId] = result

			local item = emoteItemFromId[emoteId]
			if item then
				item.animationId = result
				if Remote then
					Remote:FireAllClients({ item })
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

local function pagesToTable(pages)
	local items = {}
	while true do
		local page = pages:GetCurrentPage()
		table.move(page, 1, #page, #items + 1, items)
		if pages.IsFinished then
			break
		end
		pages:AdvanceToNextPageAsync()
	end
	return items
end

task.spawn(function()
	if RunService:IsServer() then
		local params = CatalogSearchParams.new()
		params.AssetTypes = { Enum.AvatarAssetType.EmoteAnimation }
		params.CreatorId = 3403354
		params.CreatorType = Enum.CreatorTypeFilter.Group

		local okPages, pages = Util.Retry(function()
			return AvatarEditorService:SearchCatalogAsync(params)
		end)

		if not okPages then
			warn(pages)
			return
		end

		local okItems, items = Util.Retry(function()
			return pagesToTable(pages)
		end)

		if not okItems then
			warn(items)
			return
		end

		local tasks = Util.Tasks.new()
		for _, item in items do
			local emote = {
				default = true,
				animationId = 0,
				emoteId = item.Id,
				name = item.Name,
				nameLower = string.lower(item.Name),
			}
			table.insert(emotes, emote)
			emoteItemFromId[item.Id] = emote
			_K.VIP.allowedBulkPurchaseIds[item.Id] = true
			tasks:add(getAnimationIdFromEmoteId, item.Id)
		end
		tasks:wait()

		Remote = Instance.new("RemoteEvent", script)
		Remote.OnServerEvent:Connect(function(player)
			Remote:FireClient(player, emotes)
		end)
	else
		Remote = script:WaitForChild("RemoteEvent")
		Remote.OnClientEvent:Connect(function(data)
			for index, item in data do
				emoteToAnimationId[item.emoteId] = item.animationId
				animationToEmoteId[item.animationId] = item.emoteId
				local existing = emoteItemFromId[item.emoteId]
				if existing then
					table.clear(existing)
					for k, v in item do
						existing[k] = v
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
		Remote:FireServer()
	end
end)

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
	_K = context
	_K.Data.animationToEmoteId = animationToEmoteId
	_K.Data.emoteToAnimationId = emoteToAnimationId
	_K.Data.emoteItemFromId = emoteItemFromId
	_K.Data.emotes = emotes
	_K.Registry.registerType("emote", emoteType)
	_K.Registry.registerType("emotes", { listable = true }, emoteType)
end
