local InsertService = game:GetService("InsertService")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local _K

local animationToEmoteId = {}
local emoteToAnimationId = {}
local emoteItemFromId = {}
local emotes = {
	{
		name = "Aura",
		animationId = 115838519466885,
		emoteId = 88753579128439,
	},
	{
		name = "Box",
		animationId = 101350367122161,
		emoteId = 83194012641579,
	},
	{
		name = "Hide",
		animationId = 123543644842799,
		emoteId = 132448394391960,
	},
	{
		name = "Dog",
		animationId = 88276748301589,
		emoteId = 77670698747413,
	},
	{
		name = "Focus",
		animationId = 107132020813478,
		emoteId = 79391937339603,
	},
	{
		name = "Protect",
		animationId = 71804788958142,
		emoteId = 96782264040461,
	},
	{
		name = "Phase",
		animationId = 136482078271100,
		emoteId = 104339810974997,
	},
	{
		name = "Reset",
		animationId = 94627802956613,
		emoteId = 96519077691177,
	},
	{
		name = "Spin",
		animationId = 138111357779914,
		emoteId = 136523996372200,
	},
	{
		name = "Trip",
		animationId = 108359446512277,
		emoteId = 124892295531922,
	},
}

local function getInfo(id: number)
	return MarketplaceService:GetProductInfo(id)
end

local function updateEmoteName(emoteItem)
	local ok, result = pcall(getInfo, emoteItem)
	if ok and type(result) == "table" and result.AssetTypeId == Enum.AssetType.EmoteAnimation.Value then
		emoteItem.name = result.Name
		emoteItem.nameLower = string.lower(result.Name)
	end
end

for _, item in emotes do
	item.default = true
	emoteItemFromId[item.emoteId] = item
	emoteToAnimationId[item.emoteId] = item.animationId
	animationToEmoteId[item.animationId] = item.emoteId
	item.nameLower = string.lower(item.name)
	task.spawn(updateEmoteName, item)
end

local isEmoteCache = {}
local function isEmote(id: number)
	if isEmoteCache[id] then
		return isEmoteCache[id]
	end

	local ok, result = pcall(getInfo, id)
	if ok and type(result) == "table" and result.AssetTypeId == Enum.AssetType.EmoteAnimation.Value then
		isEmoteCache[id] = true
		if not emoteItemFromId[id] then
			local item = {
				name = result.Name,
				nameLower = string.lower(result.Name),
				emoteId = id,
			}
			table.insert(emotes, item)
			emoteItemFromId[id] = item
		end
		return true
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

	-- clients can't LoadAsset (request from server?)
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
			emoteToAnimationId[emoteId] = result
			local item = emoteItemFromId[emoteId]
			if item then
				item.animationId = result
			end
			return result
		else
			warn("Invalid animationId")
		end
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
	_K = context
	_K.Data.animationToEmoteId = animationToEmoteId
	_K.Data.emoteToAnimationId = emoteToAnimationId
	_K.Data.emoteItemFromId = emoteItemFromId
	_K.Data.emotes = emotes
	_K.Registry.registerType("emote", emoteType)
	_K.Registry.registerType("emotes", { listable = true }, emoteType)

	for _, item in emotes do
		_K.VIP.allowedBulkPurchaseIds[item.emoteId] = true
	end
end
