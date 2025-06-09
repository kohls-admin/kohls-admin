--!nocheck
--|   __________   |--
--|  |Core Setup|  |--

type CommandFunction = (Player, { any }) -> ()
type Log = { number | string }

local dataKey = {
	save = "KSave",
	logs = "KLogs",
	servers = "KPrivateServers",
}

local IS_PRIVATE_SERVER = game.PrivateServerId ~= "" and game.PrivateServerOwnerId ~= 0
local PRIVATE_OWNER_PERMISSIONS = false

script.Parent = nil
local version = 79
local f = { s = script }
local function new(className: string, parent: Instance?): (any) -> Instance
	return function(properties)
		local instance = Instance.new(className)
		for key, value in properties do
			if type(key) == "number" then
				value.Parent = instance
			else
				instance[key] = value
			end
		end
		instance.Parent = instance.Parent or parent
		return instance
	end
end
local function FindChild(parent: Instance, childName: string, recursive: boolean?): Instance?
	local found, childInstance = pcall(function()
		return parent[childName]
	end)
	if found then
		return childInstance
	end
	if recursive then
		for _, descendant in parent:GetChildren() do
			local child = FindChild(descendant, childName, true)
			if child then
				return child
			end
		end
	end
	return nil
end
local function WaitForChild(parent: Instance, childName: string): Instance
	local child
	repeat
		child = FindChild(parent, childName)
		task.wait()
	until child
	return child :: Instance
end
local function wrap(f, ...)
	local success, result = coroutine.resume(coroutine.create(f), ...)
	if not success then
		warn(`Kohl's Admin Infinite Error: {result} \n {debug.traceback()}`)
	end
	return success, result
end
local services = {
	Badge = game:GetService("BadgeService"),
	Collection = game:GetService("CollectionService"),
	Content = game:GetService("ContentProvider"),
	DataStore = game:GetService("DataStoreService"),
	Debris = game:GetService("Debris"),
	Group = game:GetService("GroupService"),
	HTTP = game:GetService("HttpService"),
	Insert = game:GetService("InsertService"),
	Lighting = game:GetService("Lighting"),
	Marketplace = game:GetService("MarketplaceService"),
	Players = game:GetService("Players"),
	ReplicatedFirst = game:GetService("ReplicatedFirst"),
	ReplicatedStorage = game:GetService("ReplicatedStorage"),
	Run = game:GetService("RunService"),
	ServerScript = game:GetService("ServerScriptService"),
	ServerStorage = game:GetService("ServerStorage"),
	StarterGui = game:GetService("StarterGui"),
	StarterPack = game:GetService("StarterPack"),
	StarterPlayer = game:GetService("StarterPlayer"),
	Teams = game:GetService("Teams"),
	Teleport = game:GetService("TeleportService"),
	Text = game:GetService("TextService"),
	TextChat = game:GetService("TextChatService"),
	Tween = game:GetService("TweenService"),
	Workspace = game:GetService("Workspace"),
}
wrap(function()
	services.Workspace.AllowThirdPartySales = true
end)
local state: {
	Commands: { { string } | number | CommandFunction },
	Logs: { Log },
	ChatLogs: { Log },
	Votes: { [number]: boolean },
	LastVote: number,
} =
	{
		Commands = {},
		Logs = {},
		ChatLogs = {},
		Votes = {},
		LastVote = 0,
	}

local Dependencies = script.D:Clone()
local BuildingTools
do
	BuildingTools = Dependencies.Tools["Building Tools"]:Clone()
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.8, 0.8, 0.8)
	handle.CastShadow = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.TopSurface = 0
	handle.BottomSurface = 0
	for _, face in Enum.NormalId:GetEnumItems() do
		local decal = Instance.new("Decal")
		decal.Face = face
		decal.Texture = "rbxassetid://129748355"
		decal.Parent = handle
	end
	handle.Parent = BuildingTools
end
local SuperCrown, Shine = require(Dependencies.SuperCrown):Clone(), new("Attachment")({ Name = "KShine" })
local shineParticle = Dependencies.Shine:Clone()
shineParticle.Enabled = true
shineParticle.Parent = Shine
local Client = Dependencies.Client:Clone()
Client.Name = "\n\a\n"
while FindChild(services.ReplicatedStorage, "\n\a\n") do
	services.ReplicatedStorage["\n\a\n"]:Destroy()
end
local SWORD = services.Insert:LoadAsset(47433):FindFirstChildOfClass("Tool")
if not SWORD then
	warn(`Sword failed to load, sword command won't work!`)
end
Client.Parent = services.ReplicatedStorage
Client.Enabled, Client.Archivable = true, false
Client.Changed:Connect(function()
	if Client.Parent ~= services.ReplicatedStorage then
		pcall(function()
			Client.Parent = services.ReplicatedStorage
		end)
	end
end)
local GlobalDataStore
do
	local ok, result = pcall(function()
		return services.DataStore:GetGlobalDataStore()
	end)
	if ok then
		GlobalDataStore = result
	else
		if services.Run:IsStudio() and type(result) == "string" then
			if string.find(result, "publish", 1, true) then
				warn("Data failed to load, enable Studio access to API services in Game Settings.")
			end
			if string.find(result, "502", 1, true) then
				warn("Data failed to load, enable Studio access to API services in Game Settings.")
			end
		end
	end
end
local ScriptName = "Kohl's Admin Infinite"
local NameCache = {}
local Admins = {}
local Bans = {}
local Set = {}
local StudioSet = {
	Color = Color3.new(),
	ColorTransparency = 0.8,
	AdminCredit = true,
	AutoCleanDelay = 30,
	CommandLimits = {
		[0] = { 1, 10 },
		[1] = { 16, 5 },
		[2] = { 32, 1 },
		[3] = { 64, 1 },
		[4] = { 128, 1 },
		[5] = { math.huge, 0 },
		[6] = { math.huge, 0 },
		[7] = { math.huge, 0 },
	},
	CommandBar = true,
	FunCommands = true,
	JoinMessage = true,
	Prefix = ":",
	GroupAdmin = {},
	VIPAdmin = {},
	Permissions = {},
}
local LocalSet, ClearObjects = { SLock = false }, {}
local OriginalLighting = {
	Ambient = services.Lighting.Ambient,
	Brightness = services.Lighting.Brightness,
	OutdoorAmbient = services.Lighting.OutdoorAmbient,
	ShadowColor = services.Lighting.ShadowColor,
	TimeOfDay = services.Lighting.TimeOfDay,
	FogColor = services.Lighting.FogColor,
	FogEnd = services.Lighting.FogEnd,
	FogStart = services.Lighting.FogStart,
	GlobalWind = services.Workspace.GlobalWind,
}
local oldRemoteEvent, admstr, banstr, logb, clogb =
	FindChild(services.ReplicatedStorage, "b\a\n\a\n\a"),
	new("StringValue")({ Name = "\admi\n" }),
	new("StringValue")({ Name = "\b\a\n" }),
	new("BoolValue")({ Name = "log" }),
	new("BoolValue")({ Name = "clog" })
if oldRemoteEvent then
	oldRemoteEvent:Destroy()
end
local RemoteEvent =
	new("RemoteEvent")({ Parent = services.ReplicatedStorage, Name = "b\a\n\a\n\a", Archivable = false })
admstr.Parent, banstr.Parent, logb.Parent, clogb.Parent = RemoteEvent, RemoteEvent, RemoteEvent, RemoteEvent
local loader = WaitForChild(services.ServerScript, ScriptName)
if loader:IsA("Model") or loader:IsA("Folder") then
	loader:Destroy()
	loader = WaitForChild(services.ServerScript, ScriptName)
end
if not loader then
	script:Destroy()
end
local CUSTOM = FindChild(loader, "Custom Commands") or FindChild(loader, "Custom_Commands")
local SETTINGS = FindChild(loader, "Settings") or FindChild(loader, "Legacy_Settings")
if CUSTOM then
	local b, e = pcall(function()
		CUSTOM = require(CUSTOM)
	end)
	if not b then
		print(ScriptName .. " Custom Command Error:\t" .. e)
		CUSTOM = {}
	end
end
if SETTINGS then
	SETTINGS = require(SETTINGS)
	for k, v in SETTINGS[1] do
		StudioSet[k] = v
	end
	if IS_PRIVATE_SERVER then
		for i, list in SETTINGS[2] do
			if i < 5 and table.find(list, game.PrivateServerOwnerId) then
				PRIVATE_OWNER_PERMISSIONS = true
			end
		end
	end
else
	script:Destroy()
end
for i, v in StudioSet do
	Set[i] = v
end
Set.FreeAdmin = math.clamp(Set.FreeAdmin or 0, 0, 5)
if PRIVATE_OWNER_PERMISSIONS then
	for k, v in dataKey do
		dataKey[k] ..= game.PrivateServerOwnerId
	end
end

local Closing, Closed, SaveData, SaveLogs = false, false, false, false
local creatorId = game.CreatorType == Enum.CreatorType.Group
		and FindChild(services.Group:GetGroupInfoAsync(game.CreatorId).Owner, "Id")
	or game.CreatorId
Admins[creatorId] = 7

local function getTextObject(stringToFilter: string, fromUserId: number): TextFilterResult | false
	local success, result = pcall(function()
		return services.Text:FilterStringAsync(stringToFilter, fromUserId)
	end)
	if success then
		return result
	else
		print("Error generating TextFilterResult:", result)
		return false
	end
end

local function getFilteredMessage(textObject: TextFilterResult, fromUserId: number, toUserId: number?): string
	local success, message = pcall(function()
		if toUserId and services.Players:GetPlayerByUserId(fromUserId) then
			if services.TextChat:CanUsersChatAsync(fromUserId, toUserId) then
				return textObject:GetNonChatStringForUserAsync(toUserId)
			else
				return "User cannot chat"
			end
		else
			if services.TextChat:CanUserChatAsync(fromUserId) then
				return textObject:GetNonChatStringForBroadcastAsync()
			else
				return "User cannot chat"
			end
		end
	end)
	if success then
		return message
	else
		print("Error filtering message:", message)
	end
	return ""
end

local DonorCache = {}

--|  Server Functions  |--

function f.AssetInfo(assetId: number)
	return services.Marketplace:GetProductInfo(assetId)
end
function f.Merge(mergeInto, mergeFrom)
	for key, value in mergeFrom do
		mergeInto[key] = value
	end
	return mergeInto
end
function f.CheckLogs(logs, value)
	for _, entry in logs do
		if entry[1] == value[1] and entry[2] == value[2] then
			return false
		end
	end
	return true
end
function f.LMerge(a, b, c)
	c = {}
	for i, v in a do
		c[i] = v
	end
	for i, v in b do
		if f.CheckLogs(a, v) then
			table.insert(c, v)
		end
	end
	return c
end
function f.ClearTab(a, b)
	for i, v in b do
		a[i] = nil
	end
	return a
end
function f.MapTab(a)
	local b = {}
	for i, v in a do
		if type(v) == "table" then
			b[tostring(i)] = f.MapTab(v)
		else
			b[tostring(i)] = v
		end
	end
	return b
end
function f.unMapTab(a)
	local b = {}
	for i, v in a do
		if type(v) == "table" then
			b[tostring(i)] = f.unMapTab(v)
		else
			b[tonumber(i)] = v
		end
	end
	return b
end
function f.AdminS(a)
	local b = ""
	for i, v in a do
		b = b .. " " .. i .. ":" .. v
	end
	return b
end
function f.Cache(a)
	local b = ""
	for i, v in a do
		if v < 0 then
			b = b .. " " .. i .. ":" .. v
		end
	end
	return b
end
function f.unCache(a)
	local b = {}
	for i in a:gmatch("%S+") do
		local c, d = i:match("(.+):(.+)")
		b[tonumber(c)] = tonumber(d)
	end
	return b
end
function f.SortLogs(logs)
	logs = logs or {}
	local sorted = {}
	table.sort(logs, function(a: Log, b: Log)
		return a[1] :: number > b[1] :: number
	end)
	for i = 1, math.min(#logs, 300) do
		sorted[i] = logs[i]
	end
	return sorted
end
function f.KUpdateLog(a)
	RemoteEvent:FireAllClients("KUpdateLog", a)
end
function f.KUpdateCLog(a)
	RemoteEvent:FireAllClients("KUpdateCLog", a)
end
function f.KUpdateLogs()
	RemoteEvent:FireAllClients("KUpdateLogs", state.Logs)
end
function f.KUpdateCLogs()
	RemoteEvent:FireAllClients("KUpdateCLogs", state.ChatLogs)
end
function f.SetAdmins()
	local a = {}
	for i, v in Admins do
		if v > 0 then
			a[i] = v
		end
	end
	return a
end
function f.SetBans(): { [Player | number]: number }
	local a = {}
	for i, v in Bans do
		if v > 0 then
			a[i] = v
		end
	end
	return a
end
function f.Players(): { Player }
	return services.Players:GetPlayers()
end
function f.getPlayer(name: string): Player
	local b = {}
	for i, player in f.Players() do
		if player and player.Name:lower() == name then
			b = { player, true }
		end
	end
	if not b[2] then
		for i, v in f.Players() do
			if v and v.DisplayName:lower() == name then
				b = { v, true }
			end
		end
	end
	if not b[2] then
		for i, v in f.Players() do
			if v.Name:lower():find(name, 1, true) == 1 or v.DisplayName:lower():find(name, 1, true) == 1 then
				b = { v }
			end
		end
	end
	return b[1] :: Player
end
function f.toPlayer(player: Player, name: string, id: number?): { Player }
	assert(name)
	local selected = {}
	name = name:lower()
	local pow = f.getPower(player)
	if not name:match("%S") or (pow < 2 and player.UserId ~= game.PrivateServerOwnerId) then
		selected = { player }
	elseif name == "all" then
		selected = f.Players()
	else
		for d in name:gmatch("[^,]+") do
			local plr = f.getPlayer(d)
			if d == "me" then
				selected[#selected + 1] = player
			elseif d == "random" then
				selected[#selected + 1] = f.Players()[math.random(#f.Players())]
			elseif d == "others" then
				for i, v in f.Players() do
					if v ~= player then
						selected[#selected + 1] = v
					end
				end
			elseif d == "friends" then
				for i, v in f.Players() do
					if v ~= player and v:IsFriendsWith(player.UserId) then
						selected[#selected + 1] = v
					end
				end
			elseif d == "vets" or d == "veterans" then
				for i, v in f.Players() do
					if v.AccountAge > 364 then
						selected[#selected + 1] = v
					end
				end
			elseif d == "alts" or d == "noobs" then
				for i, v in f.Players() do
					if v.AccountAge < 365 then
						selected[#selected + 1] = v
					end
				end
			elseif d == "close" then
				for i, v in f.Players() do
					if
						v
						and v.Character
						and player.Character
						and (v.Character:GetPivot().Position - player.Character:GetPivot().Position).Magnitude <= 50
					then
						selected[#selected + 1] = v
					end
				end
			elseif d == "far" then
				for i, v in f.Players() do
					if
						v
						and v.Character
						and player.Character
						and (v.Character:GetPivot().Position - player.Character:GetPivot().Position).Magnitude > 50
					then
						selected[#selected + 1] = v
					end
				end
			elseif d:find("rad") == 1 and d:match("%d+$") and d:match("%d+$") ~= d then
				local r = tonumber(d:match("%d+$"))
				for i, v in f.Players() do
					if
						v
						and v.Character
						and player.Character
						and (v.Character:GetPivot().Position - player.Character:GetPivot().Position).Magnitude <= r
					then
						selected[#selected + 1] = v
					end
				end
			elseif d:find("g") == 1 and d:match("%d+$") and d:match("%d+$") ~= d then
				local gp = tonumber(d:match("%d+$"))
				for i, v in f.Players() do
					if v:IsInGroup(gp) then
						selected[#selected + 1] = v
					end
				end
			elseif #d > 1 and string.find(d, "%", 1, true) == 1 then
				local teamName = string.sub(d, 2)
				for _, team in services.Teams:GetChildren() do
					if string.find(string.lower(team.Name), teamName, 1, true) == 1 then
						selected = team:GetPlayers()
						break
					end
				end
			elseif d:find("#") == 1 and d:match("%d+", 2) then
				local n, P = tonumber(d:match("%d+", 2)), {}
				for i, v in f.Players() do
					P[#P + 1] = v
				end
				for i = 1, math.min(#P, n) do
					i = math.ceil(math.random(#P))
					selected[#selected + 1] = P[i]
					table.remove(P, i)
				end
			elseif d == "admins" then
				for i, v in f.Players() do
					if math.abs(Admins[v.UserId] or 0) > 1 then
						selected[#selected + 1] = v
					end
				end
			elseif d == "nonadmins" then
				for i, v in f.Players() do
					if math.abs(Admins[v.UserId] or 0) < 2 then
						selected[#selected + 1] = v
					end
				end
			elseif plr then
				selected[#selected + 1] = plr
			elseif id and tonumber(d) and wrap(f.getNameFromId, tonumber(d)) then
				selected[#selected + 1] = tonumber(d)
			end
		end
	end
	if id then
		for i, v in selected do
			selected[i] = tonumber(v) or v.UserId
		end
	end
	return selected
end
function f.CastRay(fromPosition: Vector3, toPosition: Vector3, ignoreDescendantsTable: { Instance }?)
	local vector = toPosition - fromPosition
	local raycastParams = RaycastParams.new()
	if ignoreDescendantsTable then
		raycastParams.FilterDescendantsInstances = ignoreDescendantsTable
	end
	raycastParams.IgnoreWater = true
	return services.Workspace:Raycast(fromPosition, vector.Unit * math.min(vector.Magnitude, 999), raycastParams)
end
function f.hatPlayer(player, id, isVIP)
	if player and player.Character then
		if isVIP then
			local n = 0
			for i, v in player.Character:GetChildren() do
				if v and v.Name == "KHat" then
					n = n + 1
					if n > 9 then
						player.Character.KHat:Destroy()
					end
				end
			end
		end
		local hats = {}
		for i, v in services.Insert:LoadAsset(id):GetChildren() do
			if v:IsA("Accoutrement") then
				if isVIP then
					for _, s in v:GetDescendants() do
						if
							s:IsA("Script")
							or s:IsA("Tool")
							or s:IsA("HopperBin")
							or s:IsA("Model")
							or (s:IsA("BasePart") and s.Name ~= "Handle")
						then
							s:Destroy()
						end
					end
				end
				v.Name = "KHat"
				if isVIP then
					v.Changed:Once(function()
						if v then
							v:Destroy()
						end
					end)
				end
				table.insert(hats, v)
				v.Parent = player.Character
			end
		end
		return hats
	end
	return
end
function f.MatchClr(colorName: string): Color3
	local brickColor = BrickColor.new(colorName:sub(1, 1):upper() .. colorName:sub(2))
	brickColor = brickColor ~= BrickColor.new("") and brickColor or nil
	if not brickColor then
		for i, v in { "New Yeller", "Pastel Blue", "Dusty Rose", "CGA brown" } do
			if colorName:lower():find("^" .. v) then
				brickColor = BrickColor.new(v)
			end
		end
	end
	if not brickColor and colorName:find("^random") then
		brickColor = BrickColor.Random()
	end
	return brickColor and brickColor.Color
end
function f.Crash(player: Player)
	RemoteEvent:FireClient(player, "KCrash")
end
function f.Kick(player: Player, reason: string?)
	if not wrap(function()
		player:Kick(reason or "Kicked")
	end) then
		f.Crash(player)
	end
end
function f.setBan(player: number | string, value: number?)
	value = value or 0
	if type(player) == "string" then
		local success, result = pcall(function()
			return services.Players:GetUserIdFromNameAsync(player)
		end)
		if not (success and player) then
			return
		end
		player = result
	end
	if value == 0 then
		value = Bans[player]
		Bans[player] = nil
	else
		Bans[player] = value
	end
	banstr.Value = f.AdminS(Bans)
	if value < 1 then
		SaveData = 0
	end
end

function f.setPower(userIdOrName: number | string, power: number)
	power = power or 0
	local userId
	if type(userIdOrName) == "string" then
		local success, result = pcall(function()
			return services.Players:GetUserIdFromNameAsync(userIdOrName)
		end)
		if not (success and result) then
			return
		end
		userId = result
	elseif type(userIdOrName) == "number" then
		userId = userIdOrName
	end
	if power == 0 then
		power = Admins[userId]
		Admins[userId] = nil
	else
		Admins[userId] = math.clamp(power, -6, 6)
	end
	admstr.Value = f.AdminS(Admins)
	if power < 1 then
		SaveData = 0
	end
end
function f.getPower(player: number | Player): number
	player = tonumber(player) or FindChild(player, "UserId")
	return if Admins[player] and math.abs(Admins[player]) > (Set.FreeAdmin or 0)
		then math.abs(Admins[player])
		else (Set.FreeAdmin or 0)
end
function f.getTitle(powerOrPlayer: number | Player)
	local power = tonumber(powerOrPlayer) or f.getPower(powerOrPlayer)
	return power >= 6 and "Game Creator"
		or power == 5 and "Owner"
		or power == 4 and "Super Admin"
		or power == 3 and "Administrator"
		or power == 2 and "Moderator"
		or power == 1 and "VIP"
		or "Player"
end
function f.getMass(a, b)
	b = b or 0
	for i, v in a:GetChildren() do
		if v:IsA("BasePart") then
			b = b + v:GetMass()
		end
		f.getMass(v)
	end
	return b
end
function f.getTime(t, s)
	t = t % 86400
	s = { t % 60, t % 3600 / 60, t / 3600 }
	for i, v in s do
		v = math.floor(v)
		s[i] = (10 > v and "0" .. v or v)
	end
	return s[3] .. ":" .. s[2] .. ":" .. s[1]
end
function f.getNameFromId(userId: number): string
	local success, result = pcall(function()
		return NameCache[userId] or services.Players:GetNameFromUserIdAsync(userId)
	end)
	result = success and result or "???"
	if result ~= "???" then
		NameCache[userId] = result
	end
	return result
end
function f.getIdFromName(name: string)
	local _success, result = pcall(function()
		return services.Players:GetUserIdFromNameAsync(name)
	end)
	return result
end
function f.getWords(text: string)
	local words = {}
	for word in string.gmatch(text, "%S+") do
		table.insert(words, word)
	end
	return words
end
function f.addCommand(
	names: { string },
	description: { string },
	power: number,
	argumentTypes: { string },
	func: CommandFunction
)
	table.insert(state.Commands, { names, description, power, argumentTypes, func })
end
function f.Has(player: Player, assetId: number): boolean
	local _success, result = pcall(function()
		return services.Marketplace:PlayerOwnsAsset(player, assetId)
	end)
	return result
end
function f.HasPass(player: Player, gamePassId: number): boolean
	return services.Marketplace:UserOwnsGamePassAsync(player.UserId, gamePassId)
end
function f.Auth(from, subject, danger): boolean?
	-- always authorize self unless dangerous command
	if from == subject then
		return not danger
	end
	local difference = f.getPower(from) - f.getPower(subject)
	-- require higher power for danger execution
	return if danger then difference > 0 else difference >= 0
end

function f.GroupAdminAuth(from, to, diff): boolean?
	diff = diff and from == to
	if diff then
		return nil
	end
	if from == to then
		return true
	end
	if next(Set.GroupAdmin) then
		local success, result = pcall(function()
			return services.Group:GetGroupsAsync(to)
		end)
		if success and result then
			local power = 0
			for _, group in result do
				local ranks = Set.GroupAdmin[group.Id]
				local currentRank = group.Rank
				if ranks and currentRank then
					for rank, rankPower in ranks do
						if (Set.GroupAdminExactRank ~= true and currentRank >= rank) or currentRank == rank then
							power = math.clamp(rankPower, power, 6)
						end
					end
				end
			end
			return f.getPower(from) > math.max(f.getPower(to), power)
		elseif not success then
			return false
		end
	end
	return f.getPower(from) > f.getPower(to)
end
f.uID = ""
for i = 1, 11 do
	f.uID = f.uID .. math.random(os.time() % 9 + 1)
end
f.pePT = new("ParticleEmitter")({
	Enabled = false,
	Texture = "rbxassetid://3021790960",
	Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.1, 0.25, 0.25),
		NumberSequenceKeypoint.new(1, 0.5),
	}),
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.1, 0.25, 0.25),
		NumberSequenceKeypoint.new(0.9, 0.5, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	}),
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0 / 6, Color3.new(1, 0, 0)),
		ColorSequenceKeypoint.new(1 / 6, Color3.new(1, 0, 1)),
		ColorSequenceKeypoint.new(2 / 6, Color3.new(0, 0, 1)),
		ColorSequenceKeypoint.new(3 / 6, Color3.new(0, 1, 1)),
		ColorSequenceKeypoint.new(4 / 6, Color3.new(0, 1, 0)),
		ColorSequenceKeypoint.new(5 / 6, Color3.new(1, 1, 0)),
		ColorSequenceKeypoint.new(6 / 6, Color3.new(1, 0, 0)),
	}),
	Lifetime = NumberRange.new(5),
	Speed = NumberRange.new(0.5, 1),
	Rotation = NumberRange.new(0, 359),
	RotSpeed = NumberRange.new(-90, 90),
	Rate = 11,
	VelocitySpread = 180,
})
function f.isReal(player: Player)
	wrap(function()
		if player.UserId < 1 and player.Name:find("Player") then
			return
		end
		if player.Name ~= f.getNameFromId(player.UserId) then
			if not pcall(function()
				player:Kick()
			end) then
				RemoteEvent:FireClient(player, "KCrash")
			end
		end
	end)
end
-- use "GroupAdminExactRank=true;" in settings to enable exact rank group admin behavior
function f.isGroupAdmin(player: Player): number?
	local originalPower = f.getPower(player)
	local newPower = 0
	for groupId, ranks in Set.GroupAdmin do
		groupId = tonumber(groupId)
		if player:IsInGroup(groupId) then
			local currentRank = player:GetRankInGroup(groupId)
			for rank, rankPower in ranks do
				rank = tonumber(rank)
				if (Set.GroupAdminExactRank ~= true and currentRank >= rank) or currentRank == rank then
					newPower = math.clamp(rankPower, newPower, 6)
				end
			end
		end
	end
	if originalPower < newPower then
		f.setPower(player.UserId, newPower)
		return newPower
	end
	return nil
end
function f.isVIPAdmin(player: Player): number?
	local power = ((DonorCache[player.UserId] or 0) > 1) and 1 or 0
	for i, v in Set.VIPAdmin do
		i = tonumber(i)
		if (if i < 0 then f.HasPass else f.Has)(player, math.abs(i)) then
			power = math.clamp(v, power, 5)
		end
	end
	if power ~= 0 and f.getPower(player) < power then
		f.setPower(player.UserId, power)
		return power
	end
	return nil
end
function f.Id2Plr(userId: number): Player?
	for _, player in f.Players() do
		if player and player.UserId == userId then
			return player
		end
	end
	return nil
end
function f.rmv(a, b)
	services.Debris:AddItem(a, b or 0)
end
function f.rmvTools(player: Player)
	if FindChild(player, "Backpack") then
		for i, v in player:FindFirstChild("Backpack"):GetChildren() do
			if v:IsA("Tool") or v:IsA("HopperBin") then
				v:Destroy()
			end
		end
	end
	if player.Character then
		for i, v in player.Character:GetChildren() do
			if v:IsA("Tool") or v:IsA("HopperBin") then
				v:Destroy()
			end
		end
	end
end
function f.TP(a, b)
	b.OnTeleport:Connect(function(c)
		if c == Enum.TeleportState.Failed then
			task.wait(2)
			services.Teleport:Teleport(a, b)
		end
	end)
	services.Teleport:Teleport(a, b)
end
function f.Teleport(primaryPart: BasePart, cframe: CFrame)
	if not primaryPart.Parent then
		return
	end
	local humanoid = primaryPart.Parent:FindFirstChildOfClass("Humanoid")
	if humanoid then
		if humanoid.SeatPart then
			local weld = humanoid.SeatPart:FindFirstChild("SeatWeld")
			if weld then
				weld:Destroy()
			end
		end
		humanoid.Sit = false
	end
	for _, v in primaryPart.Parent:GetChildren() do
		if v:IsA("BasePart") then
			v.AssemblyLinearVelocity = Vector3.zero
		end
	end
	primaryPart.CFrame = cframe + Vector3.new(math.random(-40, 40), 0, math.random(-40, 40)) * 0.1
end
function f.Msg(player: Player, a, b)
	if b then
		RemoteEvent:FireClient(b, "KMsg", { a[1], a[2], a[3], player.UserId })
	else
		for i, b in f.Players() do
			RemoteEvent:FireClient(b, "KMsg", { a[1], a[2], a[3], player.UserId })
		end
	end
end
function f.filteredMsg(player: Player, a, b)
	local fromId = player.UserId
	local textObject = getTextObject(a[3], fromId)
	if b then
		RemoteEvent:FireClient(b, "KMsg", { a[1], a[2], getFilteredMessage(textObject, fromId, b.UserId), fromId })
	else
		for i, b in f.Players() do
			RemoteEvent:FireClient(b, "KMsg", { a[1], a[2], getFilteredMessage(textObject, fromId, b.UserId), fromId })
		end
	end
end
function f.Hint(playerFrom: Player, message: string, playerTo: Player?)
	local textObject = getTextObject(message, playerFrom.UserId)
	if playerTo then
		RemoteEvent:FireClient(playerTo, "KHint", getFilteredMessage(textObject, playerFrom.UserId, playerTo.UserId))
	else
		for _, player in f.Players() do
			RemoteEvent:FireClient(player, "KHint", getFilteredMessage(textObject, playerFrom.UserId, player.UserId))
		end
	end
end
function f.Error(message: string, player: Player)
	if player then
		if player:IsA("Player") then
			RemoteEvent:FireClient(player, "KError", message)
		end
	else
		RemoteEvent:FireAllClients("KError", message)
	end
end
function f.getArgReq(a)
	local b = 0
	for i, v in a do
		if not (v:find("/") or v:find("player")) then
			b = b + 1
		end
	end
	return b
end
function f.getExample(a)
	return Set.Prefix .. a[1][1] .. " " .. (#a[2] and a[2][2] or "")
end
function f.AdminMsg(powerOrPlayer: number | Player): string
	local title = f.getTitle(powerOrPlayer)
	return string.format(
		"You're a%s %s!\n Chat %scmds for all the commands\tChat %shelp for general usage",
		if title:sub(1, 1):lower():match("a?o?") ~= "" then "n" else "",
		title,
		Set.Prefix,
		Set.Prefix
	)
end
function f.getCmds(a: string)
	local b, c = {}, 0
	local al = a:lower()
	for _, word in f.getWords(a) do
		if string.find(word, Set.Prefix, 1, true) == 1 then
			word = string.sub(word, #Set.Prefix + 1):lower()
			for i2, v2 in state.Commands do
				for _, nm in v2[1] do
					if word == nm:lower() then
						c = c + al:sub(c + 1, #al):find(Set.Prefix:lower() .. word, 1, true)
						if #b > 0 then
							b[#b][3] = c - 1
						end
						b[#b + 1] = { v2, c }
					end
				end
			end
		end
	end
	return b
end
function f.getValue(a, b)
	for i in b do
		if i == a or (f.getNameFromId(i) or ""):lower():find("^" .. a) then
			return i
		end
	end
	return nil
end

local sP = new("BindableEvent", services.ServerScript)({ Name = "ksetPower" })
local gP = new("BindableEvent", services.ServerScript)({ Name = "kgetPower" })
sP.Event:Connect(f.setPower)
gP.Event:Connect(f.getPower)
_G.setPower = sP
_G.getPower = gP

local userPermissions: {
	[Player]: {
		[string]: true,
	},
} = {}
function _G.addPermissionsPlayer(plr: Player, ...: string)
	if not userPermissions[plr] then
		userPermissions[plr] = {}
	end
	for k in { ... } do
		userPermissions[plr][k] = true
	end
end

for i, list in SETTINGS[2] do
	for _, player in list do
		if player == 0 then
			continue
		end
		if player and i < 6 then
			if tonumber(tonumber(player) or f.getIdFromName(player)) ~= creatorId and f.getPower(player) < 6 - i then
				f.setPower(player, 6 - i)
			end
		elseif player then
			f.setBan(player, 1)
		end
	end
end
wrap(function()
	game:BindToClose(function()
		Closing = true
		Client:Destroy()
		RemoteEvent:Destroy()
		if services.HTTP.HttpEnabled and game.GameId > 0 then
			-- stylua: ignore
			pcall(services.HTTP.RequestAsync, services.HTTP, { Method = "POST", Url = `https://api.kohl.gg/update/{game.GameId}` })
		end
		repeat
			task.wait()
		until (not SaveData and not SaveLogs) or not GlobalDataStore
	end)
end)
function f.UpdateSave(n, merge)
	if n[1] then
		Admins = f.Merge(if merge then Admins else f.SetAdmins(), f.unCache(n[1]))
		admstr.Value = f.AdminS(Admins)
	end
	if n[2] then
		Bans = f.Merge(if merge then Bans else f.SetBans(), f.unCache(n[2]))
		banstr.Value = f.AdminS(Bans)
	end
	if n[3] then
		n[3] = services.HTTP:JSONDecode(n[3])
		if FindChild(n[3], "Color") then
			n[3].Color = Color3.new(n[3].Color:match("(.+)|(.+)|(.+)"))
		end
		n[3]["GroupAdmin"], n[3]["VIPAdmin"], n[3]["Permissions"], n[3]["CommandLimits"] = nil, nil, nil, nil
		for i, v in n[3] do
			Set[i] = v
		end
	end
	RemoteEvent:FireAllClients("KUpdate", f.MapTab(Set))
end
function f.UpdateLogs(n)
	state.Logs = f.SortLogs(f.LMerge(state.Logs, f.unMapTab(n[1])))
	state.ChatLogs = f.SortLogs(f.LMerge(state.ChatLogs, f.unMapTab(n[2])))
end
function f.ForceSave()
	local ok, err = wrap(function(a, b)
		a = { f.Cache(Admins), f.Cache(Bans) }
		if Set.IGS then
			b = {}
			for i, v in Set do
				if i == "Color" then
					b[i] = v.r .. "|" .. v.g .. "|" .. v.b
				elseif i ~= "GroupAdmin" and i ~= "VIPAdmin" and i ~= "Permissions" and i ~= "CommandLimits" then
					b[i] = v
				end
			end
			table.insert(a, services.HTTP:JSONEncode(b))
		end
		GlobalDataStore:SetAsync(dataKey.save, a)
	end)
	if not ok then
		print(ScriptName .. ":\tSaving data failed!", err or "")
	end
	return ok
end
function f.ForceLogs(a, b)
	local ok, err = wrap(function()
		GlobalDataStore:SetAsync(dataKey.logs, { f.MapTab(state.Logs), f.MapTab(state.ChatLogs) })
	end)
	if not ok then
		print(ScriptName .. ":\tSaving logs failed!", err or "")
	end
	return ok
end
do
	local success, result = wrap(function()
		if GlobalDataStore then
			if PRIVATE_OWNER_PERMISSIONS then
				local MainSave = GlobalDataStore:GetAsync("KSave")
				if MainSave then
					f.UpdateSave(MainSave)
				end
			end
			local KSave = GlobalDataStore:GetAsync(dataKey.save)
			if KSave then
				f.UpdateSave(KSave, true)
				if LoadCommands then
					LoadCommands()
				end
				-- recheck players
				for _, player in f.Players() do
					if player then
						f.LoadCheck(player)
					end
				end
			end

			local KLogs = GlobalDataStore:GetAsync(dataKey.logs)
			if KLogs then
				f.UpdateLogs(KLogs)
				GlobalDataStore:OnUpdate(dataKey.save, f.UpdateSave)
				GlobalDataStore:OnUpdate(dataKey.logs, f.UpdateLogs)
			end
		end
	end)
	if not success then
		print(ScriptName .. " Error: " .. result)
	end
end
wrap(function()
	repeat
		if SaveLogs and GlobalDataStore then
			SaveLogs = not f.ForceLogs()
		end
		local startTick = tick()
		repeat
			task.wait(1)
		until tick() - startTick >= 60 or Closing
	until Closed
end)
wrap(function()
	repeat
		if SaveData and GlobalDataStore then
			SaveData = not f.ForceSave()
		end
		local startTick = tick()
		repeat
			task.wait(1)
		until tick() - startTick >= 60 or Closing
	until Closed
end)

local MClr = {
	red = Color3.new(1, 0, 0),
	orange = Color3.new(1, 0.5, 0),
	yellow = Color3.new(1, 1, 0),
	green = Color3.new(0, 1, 0),
	cyan = Color3.new(0, 1, 1),
	blue = Color3.new(0, 0, 1),
	purple = Color3.new(0.4, 0, 1),
	pink = Color3.new(1, 0, 1),
	black = Color3.new(),
	white = Color3.new(1, 1, 1),
	navy = Color3.new(0, 0, 0.4),
	gray = Color3.new(0.6, 0.6, 0.6),
	grey = Color3.new(0.4, 0.4, 0.4),
}
local MTime = {
	d = 86400,
	h = 3600,
	m = 60,
	s = 1,
}
local chattedCache = {}
local CommandCooldown = {}
local fastCommands = { "credit", "prefix", "clean", "ping", "set", "settings" }
local serverContext = {
	DisplayName = "Server",
	Name = "SERVER",
	UserId = 0,
}
function f.Chatted(plr: Player | serverContext, msg: string, cmdbar: boolean?)
	local server = plr == serverContext
	local now = time()
	-- debounce f.Chatted
	if chattedCache[plr] ~= nil and now < chattedCache[plr] then
		return
	end
	chattedCache[plr] = now + 0.5
	-- command limits
	if CommandCooldown[plr] ~= nil then
		if now < CommandCooldown[plr] then
			if string.find(msg, "[%s]*%" .. Set.Prefix .. "%w+") then
				f.Error(
					`COMMAND USAGE ON COOLDOWN, TRY AGAIN IN {math.ceil((CommandCooldown[plr] or now + 1) - now)} SECONDS`,
					plr
				)
			end
			return
		end
		CommandCooldown[plr] = nil
	end
	local pow = if server then math.huge else f.getPower(plr)
	local limits = StudioSet.CommandLimits[pow]
	for i, v in fastCommands do
		if string.lower(msg) == v then
			msg = Set.Prefix .. msg
			break
		end
	end
	local filteredMessage = if server
		then msg:gsub("\n", "\t")
		else getFilteredMessage(getTextObject(msg:gsub("\n", "\t"), plr.UserId), plr.UserId)
	local CLog: Log = { os.time(), string.sub(`{plr.DisplayName} [@{plr.Name}]:\t{filteredMessage}`, 1, 99) }
	local Logs, CMD
	local success, _result = wrap(function()
		if not server then
			f.isReal(plr)
		end
		if not utf8.len(CLog[2]) then
			f.Error(`INVALID UTF8:\t{CLog[2]}`, plr)
			error(`{ScriptName} Error: User {plr.UserId} invalid UTF8 input`)
		end
		local Cmds = f.getCmds(msg)
		local isBatch, cmdobj
		if #Cmds > 1 then
			isBatch, cmdobj = true, new("BoolValue", script)({})
			table.insert(ClearObjects, cmdobj)
		end
		local cmdCache = {}
		for nCmd, v in Cmds do
			if isBatch and not (cmdobj and cmdobj.Parent) then
				break
			end
			if nCmd > (limits[1] or 10) then
				f.Error(`BATCH LIMIT ({limits[1] or 10}) EXCEEDED, IGNORED COMMANDS:\t{msg:sub(v[2])}`, plr)
				break
			end
			local ms = msg:sub(v[2], v[3] or #msg)
			local args = {}
			local syntax = 0
			local auth = pow >= v[1][3] or userPermissions[plr][v[1][1][1]]
			local words = f.getWords(ms)
			local reqargs = f.getArgReq(v[1][4])
			local cmd = table.remove(words, 1) :: string
			if #words >= reqargs and auth then
				for i2, arg in v[1][4] do
					local opt = arg:match("/")
					local ag = words[i2] and string.lower(words[i2]) or arg == "player" and ""
					if ag or opt then
						arg = string.lower(arg)
						arg = opt and arg:sub(1, -2) or arg
						if arg == "player" then
							arg = f.toPlayer(plr, ag) or {}
						elseif arg == "userid" then
							arg = f.toPlayer(plr, ag, 0) or {}
						elseif arg == "boolean" then
							if ag == "true" then
								arg = true
							elseif ag == "false" then
								arg = false
							else
								arg = {}
							end
						elseif arg == "color" then
							ag = (ag or ""):gsub("%W", " ")
							arg = MClr[ag] or f.MatchClr(ag) or {}
						elseif arg == "number" then
							arg = tonumber(ag) or {}
						elseif arg == "string" then
							arg = table.concat(words, " ", i2) or {}
						elseif arg == "word" then
							arg = words[i2] or {}
						elseif arg == "time" then
							local t, m = ag:match("(%d+) ?(%w+)")
							arg = t and t * (MTime[m] or 1) or {}
						elseif arg == "banned" then
							arg = if ag == "all" then "" elseif f.getValue(ag, Bans) then f.getValue(ag, Bans) else {}
						elseif arg == "admin" then
							arg = if ag == "all"
								then ""
								elseif f.getValue(ag, Admins) then f.getValue(ag, Admins)
								else {}
						else
							arg = {}
						end
						if opt and type(arg) == "table" and #arg < 1 then
							arg = nil
						end
						args[#args + 1] = arg
					end
				end
				local badsyn = {}
				for i, v in args do
					if type(v) == "table" and #v < 1 then
						words[i] = words[i] .. "*"
						syntax = false
					end
					table.insert(badsyn, words[i])
				end
				if syntax then
					if not CommandCooldown[plr] then
						CommandCooldown[plr] = time() + (limits[2] or 1)
					end
					if v[1][3] > 1 then
						CMD = true
					end
					-- Prevents VIP and lower from using duplicate commands other than hat
					if pow > 1 or v[1][1][1] == "hat" or not cmdCache[v[1][1][1]] then
						cmdCache[v[1][1][1]] = true
						v[1][5](plr, args)
					end
				else
					f.Error(
						string.format(
							"CMD:\t%s\tINVALID SYNTAX:\t%s %s",
							f.getExample(v[1]),
							cmd,
							table.concat(badsyn, " ")
						),
						plr
					)
				end
			elseif not auth then
				f.Error(
					string.format("INVALID PERMISSIONS FOR:\t%s\tRESTRICTED TO:\t%s", cmd, f.getTitle(v[1][3])),
					plr
				)
			else
				f.Error(string.format("CMD:\t%s\tINVALID SYNTAX:\t%s", f.getExample(v[1]), ms), plr)
			end
		end
		if cmdobj then
			cmdobj:Destroy()
		end
	end)
	if success and CMD then
		Logs = state.Logs
	else
		Logs = state.ChatLogs
	end
	if not FindChild(plr, "KHideLogs") then
		if #Logs > 300 then
			table.remove(Logs, #Logs)
		end
		table.insert(Logs, 1, CLog)
		if success and CMD then
			f.KUpdateLog(CLog)
		else
			f.KUpdateCLog(CLog)
		end
		SaveLogs = 0
	end
end
_G.KChatted = f.Chatted
_G.KServerCommand = function(msg: string)
	return f.Chatted(serverContext, msg, true)
end

-- Donor Stuff
function f.pe(plr: Player)
	if plr and plr.Character and FindChild(plr.Character, "HumanoidRootPart") then
		local nrml = (plr:GetRankInGroup(451053) or 0) <= 1
		local a, b = nrml and 176111410, nrml and Color3.new(1, 1, 1)
		if FindChild(plr.Character.HumanoidRootPart, "KPe") then
			plr.Character.HumanoidRootPart.KPe:Destroy()
			return false
		else
			local pe = f.pePT:Clone()
			if b then
				pe.Color = ColorSequence.new(b)
			end
			if a then
				pe.Texture = "rbxassetid://" .. a
			end
			pe.Name, pe.Enabled = "KPe", true
			pe.Parent = plr.Character.HumanoidRootPart
			return true
		end
	end
	return nil
end
function f.hat(plr: Player)
	if plr and plr.Character then
		if FindChild(plr.Character, "SuperCrown") then
			plr.Character.SuperCrown:Destroy()
			return false
		else
			local cl = SuperCrown:Clone()
			if cl:FindFirstChild("Handle") and cl.Handle:FindFirstChild("Fire") then
				cl.Handle.Color = plr:GetAttribute("KCrownColor") or Color3.new(1, 1, 1)
				cl.Handle.Fire.Color = plr:GetAttribute("KCrownFireColor") or Color3.new(0, 0, 0)
				cl.Handle.Fire.SecondaryColor = cl.Handle.Color
				services.Collection:AddTag(
					cl,
					(DonorCache[plr.UserId] > 3 and plr:GetAttribute("KCrownRainbow")) and "KAIRCrown" or "KAICrown"
				)
				cl.Parent = plr.Character
				return true
			end
		end
	end
	return nil
end
function f.shine(plr: Player)
	if plr and plr.Character and FindChild(plr.Character, "HumanoidRootPart") then
		local root = plr.Character.HumanoidRootPart
		if FindChild(root, "KShine") then
			root.KShine:Destroy()
			return false
		else
			Shine:Clone().Parent = root
			return true
		end
	end
	return nil
end

local displayNames = {}

local function displayName(player: Player)
	if not (player and player.Character) then
		return
	end
	local displayName = displayNames[player.UserId]
	local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
	if displayName and humanoid then
		humanoid.DisplayName = displayName
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	end
end

function f.CharacterLoad(plr: Player, character: Model)
	wrap(function()
		displayName(plr)
		local kshine, khat, ktrail = WaitForChild(plr, "KShine"), WaitForChild(plr, "KHat"), WaitForChild(plr, "KTrail")
		if kshine and kshine.Value then
			f.shine(plr)
		end
		if khat and khat.Value then
			f.hat(plr)
		end
		if ktrail and ktrail.Value then
			f.pe(plr)
		end
	end)
	if FindChild(plr, "KTBan") then
		local c, c2
		c = character.ChildAdded:Connect(function()
			if not (plr and FindChild(plr, "KTBan")) then
				c:Disconnect()
				c2:Disconnect()
			end
			f.rmvTools(plr)
		end)
		c2 = character.ChildAdded:Connect(function()
			if not (plr and FindChild(plr, "KTBan")) then
				c:Disconnect()
				c2:Disconnect()
			end
			f.rmvTools(plr)
		end)
	end
end
function f.LoadCheck(plr: Player)
	if plr.UserId == creatorId or services.Run:IsStudio() then
		-- give admin to developers
		Admins[plr.UserId] = 7
		return
	end

	if Bans[plr.UserId] then
		-- kicked ban players
		local b = Bans[plr.UserId]
		if b < -1 then
			b = (-b - os.time()) / 60
			if b < 0 then
				f.setBan(plr.UserId, 0)
				f.Msg(plr, { ScriptName, "", "You have been unbanned!" }, plr)
			else
				f.Kick(plr, string.format("Banned for:\t%d minutes!", b))
				return
			end
		else
			if b < 2 then
				f.Kick(plr, "Permanently banned!")
			else
				f.Kick(plr, "Banned from server!")
			end
			return
		end
	end

	f.isGroupAdmin(plr)

	if LocalSet.SLock and f.getPower(plr.UserId) < 2 then
		-- kick non-admins when server locked
		f.Kick(plr, "This server is locked!")
	elseif (Set.FreeAdmin or 0) > math.abs(Admins[plr.UserId] or 0) then
		-- give free admin if enabled in settings
		f.setPower(plr.UserId, (Set.FreeAdmin or 0))
	end

	f.isVIPAdmin(plr)
end
function f.Load(plr: Player)
	if not plr then
		return
	end
	userPermissions[plr] = {}
	plr.CharacterAdded:Connect(function(char)
		f.CharacterLoad(plr, char)
	end)
	if plr.Character then
		f.CharacterLoad(plr, plr.Character)
	end
	new("Color3Value")({
		Parent = plr,
		Name = "KCClr",
		Value = Color3.new(0.5 + math.random() * 0.5, 0.5 + math.random() * 0.5, 0.5 + math.random() * 0.5),
	})
	new("BoolValue")({ Parent = plr, Name = "KTrail", Value = false })
	new("BoolValue")({ Parent = plr, Name = "KHat", Value = false })
	new("BoolValue")({ Parent = plr, Name = "KShine", Value = false })
	local donorValue = 0
	if (plr:GetRankInGroup(451053) or 0) > 1 or f.HasPass(plr, 5411126) then
		donorValue = 4
	elseif f.HasPass(plr, 5391361) or f.Has(plr, 441134066) or f.Has(plr, 423601416) then
		donorValue = 3
	elseif f.HasPass(plr, 5391359) or f.Has(plr, 441133423) or f.Has(plr, 313102724) then
		donorValue = 2
	elseif f.HasPass(plr, 5391355) or f.HasPass(plr, 5391356) or f.Has(plr, 441133305) or f.Has(plr, 441133363) then
		donorValue = 1
	end
	donorValue = math.max(donorValue, (DonorCache[plr.UserId] or 0))
	DonorCache[plr.UserId] = donorValue
	if donorValue > 3 then
		plr:SetAttribute("KCrownRainbow", true)
	end
	new("IntValue")({ Parent = plr, Name = "KDonor", Value = donorValue })
	f.LoadCheck(plr)
	if Admins[plr.UserId] and Set.JoinMessage then
		wrap(function()
			WaitForChild(plr, "Character")
			f.Msg(plr, {
				ScriptName,
				"Welcome!",
				f.AdminMsg(plr) .. (plr.UserId == creatorId and "\nEnjoy the admin? Give it a thumbs up!" or ""),
			}, plr)
		end)
	end
	plr.Chatted:Connect(function(m)
		f.Chatted(plr, m)
	end)
end
game.Players.PlayerAdded:Connect(f.Load)
for _, player in f.Players() do
	if player:IsA("Player") then
		wrap(f.Load, player)
	end
end
KRefresh = {} -- sanitize loadcharacter calls :)

local allowedUpdateSettings = {
	IGS = true,
	Flat = true,
	ForcedColor = true,
	Color = true,
	ColorTransparency = true,
	AdminCredit = true,
	AutoClean = true,
	AutoCleanDelay = true,
	CommandBar = true,
	FunCommands = true,
	FreeAdmin = true,
	JoinMessage = true,
	PublicLogs = true,
	Prefix = true,
}

function ServerEvent(plr: Player, event, arguments, uID)
	if type(arguments) == "function" then
		return
	end
	uID, event = event:match("(%d*)(.+)")
	if event == "KuID" then
		RemoteEvent:FireClient(
			plr,
			"KuID",
			{ f.uID, f.MapTab(Admins), f.MapTab(Set), state.Commands, state.Logs, state.ChatLogs }
		)
		return
	end
	if uID ~= f.uID or not plr then
		return
	end
	if event == "KChat" then
		f.Chatted(plr, arguments[2])
		local textObject = getTextObject(arguments[2], plr.UserId)
		for _, v in f.Players() do
			if v ~= plr then
				RemoteEvent:FireClient(v, event, { arguments[1], getFilteredMessage(textObject, plr.UserId, v.UserId) })
			end
		end
	elseif event == "KCClr" and FindChild(plr, "KCClr") then
		plr.KCClr.Value = arguments
	elseif event == "KRefresh" then
		if KRefresh[plr] then
			KRefresh[plr] = nil
			plr:LoadCharacter()
		end
	elseif event == "KCmdBar" then
		f.Chatted(plr, arguments, 1)
	elseif event == "KDelete" and arguments and f.getPower(plr) > 4 then
		arguments:Destroy()
	elseif event == "KPaste" and f.getPower(plr) > 4 then
		for _, v in arguments[1] do
			v:Clone().Parent = arguments[2]
			if arguments[3] then
				v:Destroy()
			end
		end
	elseif event == "KUpdate" and arguments and f.getPower(plr) > 4 then
		if arguments.IGS then
			local power = f.getPower(plr)
			for i, v in arguments do
				if allowedUpdateSettings[i] then
					if i == "FreeAdmin" then
						v = math.min(power - 1, tonumber(v) or 0)
					end
					Set[i] = v
				end
			end
		else
			Set = {}
			for i, v in StudioSet do
				Set[i] = v
			end
		end
		RemoteEvent:FireAllClients("KUpdate", f.MapTab(Set))
		LoadCommands()
		SaveData = 0
	elseif event == "KVote" then
		state.Votes[plr.UserId] = arguments
	elseif event == "KHat" then
		if DonorCache[plr.UserId] > 2 then
			local hat = f.hat(plr)
			plr.KHat.Value = hat
		end
	elseif event == "KTrail" then
		if DonorCache[plr.UserId] > 0 then
			local pe = f.pe(plr)
			plr.KTrail.Value = pe
		end
	elseif event == "KShine" then
		if DonorCache[plr.UserId] > 3 then
			local shine = f.shine(plr)
			plr.KShine.Value = shine
		end
	end
end
RemoteEvent.OnServerEvent:Connect(ServerEvent)

local isCleaning
local function CleanUp()
	if not isCleaning then
		isCleaning = true
		for _, v in services.Workspace:GetChildren() do
			if v:IsA("Accoutrement") or v:IsA("Tool") then
				v:Destroy()
			end
		end
		task.delay(1, function()
			isCleaning = false
		end)
	end
end

wrap(function()
	repeat
		task.wait(Set.AutoCleanDelay)
		if Set.AutoClean then
			CleanUp()
		end
	until Closing
end)

services.Marketplace.PromptGamePassPurchaseFinished:Connect(function(plr, id, purchased)
	local value = id == 5411126 and 4
		or id == 5391361 and 3
		or id == 5391359 and 2
		or (id == 5391355 or id == 5391356) and 1
		or nil
	if value and purchased and plr:FindFirstChild("KDonor") and value > plr.KDonor.Value then
		plr.KDonor.Value = math.max(value, plr.KDonor.Value)
		DonorCache[plr.UserId] = math.max(value, DonorCache[plr.UserId])
		if f.isVIPAdmin(plr) then
			f.Msg(plr, { ScriptName, "Welcome!", f.AdminMsg(plr) }, plr)
		end
	end
end)

local loadAssetTextureTypes = {
	Enum.AssetType.Face.Value,
	Enum.AssetType.Shirt.Value,
	Enum.AssetType.Pants.Value,
	Enum.AssetType.TShirt.Value,
}

local textureProperty = {
	Decal = "Texture",
	Shirt = "ShirtTemplate",
	Pants = "PantsTemplate",
	ShirtGraphic = "Graphic",
}

local function getTexture(assetId)
	local assetType = f.AssetInfo(assetId).AssetTypeId
	if assetType == Enum.AssetType.Image.Value then
		return "rbxassetid://" .. assetId
	elseif table.find(loadAssetTextureTypes, assetType) then
		local success, model = pcall(function()
			return services.Insert:LoadAsset(assetId)
		end)
		if success then
			local object = model:GetChildren()[1]
			local texture = object[textureProperty[object.ClassName]]
			model:Destroy()
			return texture
		end
	end
	return "rbxthumb://type=Asset&id=" .. assetId .. "&w=420&h=420"
end

local function resizeCharacter(char, scale)
	local human = char and char:FindFirstChildOfClass("Humanoid")
	if not human then
		return
	end

	local diff = scale / (char:GetAttribute("KCharacterScale") or 1)
	local hipHeight = human.HipHeight + human.RootPart.Size.Y / 2

	if human.RigType == Enum.HumanoidRigType.R15 then
		for _, v in human:GetChildren() do
			if v:IsA("NumberValue") and string.find(v.Name, "Scale") then
				local base = v:GetAttribute("KOriginalScale")
				if not base then
					base = v.Value
					v:SetAttribute("KOriginalScale", base)
				end
				v.Value = base * scale
			end
		end
	elseif human.RigType == Enum.HumanoidRigType.R6 then
		hipHeight = human.RootPart.Size.Y * 1.5
		for _, v in char:GetDescendants() do
			if v:IsA("BasePart") then
				v.Size *= diff
			elseif v:IsA("JointInstance") then
				v.C0 -= v.C0.Position * (1 - diff)
				v.C1 -= v.C1.Position * (1 - diff)
			elseif v:IsA("SpecialMesh") and v.MeshType == Enum.MeshType.FileMesh then
				v.Scale *= diff
			end
		end
	end
	-- reposition rootpart to prevent falling
	human.RootPart.CFrame *= CFrame.new(0, hipHeight * (diff - 1), 0)
	char:SetAttribute("KCharacterScale", scale)
end

local function scaleHead(char, scale)
	local human = char and char:FindFirstChildOfClass("Humanoid")
	if not human then
		return
	end
	if human.RigType == Enum.HumanoidRigType.R15 then
		if human:FindFirstChild("HeadScale") then
			local headScale = human:GetAttribute("KHeadScale")
			if not headScale then
				headScale = human.HeadScale.Value
				human:SetAttribute("KHeadScale", headScale)
			end
			human.HeadScale.Value = headScale * scale
		end
	elseif human.RigType == Enum.HumanoidRigType.R6 then
		if char:FindFirstChild("Head") and char:FindFirstChild("Torso") then
			local meshScale = human:GetAttribute("KMeshScale")
			if not meshScale then
				meshScale = char.Head.Mesh.Scale
				human:SetAttribute("KMeshScale", meshScale)
			end
			char.Head.Mesh.Scale = meshScale * scale

			local headY = char.Head.Size.Y
			char.Torso.Neck.C0 = CFrame.new(0, headY / 2 + (headY * scale / 2), 0)
				* CFrame.Angles(math.pi / 2, math.pi, 0)
		end
	end
	if scale == 1 then
		human:SetAttribute("KHeadScale", nil)
		human:SetAttribute("KMeshScale", nil)
	end
end

--|  Commands  |--

local NameFilter = {
	"",
	"all",
	"me",
	"random",
	"others",
	"friends",
	"guests",
	"vets",
	"veterans",
	"alts",
	"noobs",
	"close",
	"far",
	"admins",
	"nonadmins",
	"scripth",
	"kohl",
}
function f.CheckNF(a)
	a = a:lower()
	for i, v in NameFilter do
		if a == v then
			return false
		end
	end
	return true
end
function f.LastC0(a)
	for i, v in a:GetChildren() do
		if v:IsA("Motor6D") then
			new("CFrameValue")({ Name = "LastC0", Value = v.C0, Parent = v })
		end
	end
end
local function isMaterialAllowed(materialName)
	if not materialName then
		return nil
	end
	for _, allowedMaterial in
		{
			"Plastic",
			"SmoothPlastic",
			"Neon",
			"Wood",
			"WoodPlanks",
			"Marble",
			"Basalt",
			"Slate",
			"CrackedLava",
			"Concrete",
			"Limestone",
			"Granite",
			"Pavement",
			"Brick",
			"Pebble",
			"Cobblestone",
			"Rock",
			"Sandstone",
			"CorrodedMetal",
			"DiamondPlate",
			"Foil",
			"Metal",
			"Grass",
			"LeafyGrass",
			"Sand",
			"Fabric",
			"Snow",
			"Mud",
			"Ground",
			"Asphalt",
			"Salt",
			"Ice",
			"Glacier",
			"Glass",
			-- no ForceField
		}
	do
		if string.lower(materialName) == string.lower(allowedMaterial) then
			return allowedMaterial
		end
	end
	return nil
end
function f.ColorHat(hat: Accoutrement, colorName: string, reflectance: number?, materialName: string?)
	if not (hat and hat:IsA("Accoutrement")) then
		return
	end
	local color, material = BrickColor.new(colorName), isMaterialAllowed(materialName)

	local kbc = FindChild(hat, "KBC") or new("BrickColorValue")({ Parent = hat, Name = "KBC" })
	local kmat = FindChild(hat, "KMat") or new("StringValue")({ Parent = hat, Name = "KMat" })
	kbc.Value, kmat.Value = hat.Handle.BrickColor, hat.Handle.Material.Value
	hat.Handle.BrickColor, hat.Handle.Reflectance = color, reflectance or hat.Handle.Reflectance
	if material then
		wrap(function()
			hat.Handle.Material = material
		end)
	end
	if hat.Handle:IsA("MeshPart") then
		if not hat.Handle:FindFirstChild("KTexture") then
			new("StringValue")({ Parent = hat.Handle, Name = "KTexture", Value = hat.Handle.TextureID })
		end
		hat.Handle.TextureID = ""
	end
	local mesh = hat.Handle:FindFirstChildOfClass("SpecialMesh")
	if mesh and not mesh:FindFirstChild("KTexture") then
		new("StringValue")({ Parent = mesh, Name = "KTexture", Value = mesh.TextureId })
		mesh.TextureId = ""
	end
end
function f.ColorChar(
	character: Model,
	colorName: string,
	affectAccoutrements: true?,
	reflectance: number?,
	materialName: string?
)
	local color, material = BrickColor.new(colorName), isMaterialAllowed(materialName)
	if FindChild(character, "Body Colors") then
		FindChild(character, "Body Colors"):Destroy()
		task.wait()
	end
	for i, v in character:GetChildren() do
		if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then
			if v:IsA("MeshPart") then
				if not v:FindFirstChild("KTexture") then
					new("StringValue")({ Parent = v, Name = "KTexture", Value = v.TextureID })
				end
				v.TextureID = ""
			end
			local kbc = FindChild(v, "KBC") or new("BrickColorValue")({ Parent = v, Name = "KBC" })
			local kmat = FindChild(v, "KMat") or new("StringValue")({ Parent = v, Name = "KMat" })
			kbc.Value, kmat.Value = v.BrickColor, v.Material.Value
			v.BrickColor, v.Reflectance = color, reflectance or v.Reflectance
			if material then
				wrap(function()
					v.Material = material
				end)
			end
		elseif affectAccoutrements and v:IsA("Accoutrement") then
			f.ColorHat(v, colorName, reflectance, materialName)
		end
	end
end
function f.Normal(_, args)
	for i, plr in args[1] do
		if plr and plr.Character and FindChild(plr.Character, "HumanoidRootPart") then
			local c, t = plr.Character, nil
			local torso = c:FindFirstChild("Torso")
			t = c.HumanoidRootPart
			while FindChild(c, "KTShirt") do
				c.KTShirt:Destroy()
			end
			while FindChild(c, "KShirt") do
				c.KShirt:Destroy()
			end
			while FindChild(c, "KPants") do
				c.KPants:Destroy()
			end
			while FindChild(c, "KTorso") do
				c.KTorso:Destroy()
			end
			while FindChild(c, "KInfect") do
				c.KInfect:Destroy()
			end
			if FindChild(t, "Shirt Graphic") then
				t["Shirt Graphic"].Parent = plr.Character
			end
			if FindChild(t, "Shirt") then
				t.Shirt.Parent = plr.Character
			end
			if FindChild(t, "Pants") then
				t.Pants.Parent = plr.Character
			end
			for i2, v2 in c:GetChildren() do
				if v2:IsA("BasePart") and v2.Name ~= "HumanoidRootPart" then
					v2.Reflectance = 0
					v2.Transparency = 0
					v2.BrickColor = FindChild(v2, "KBC") and v2.KBC.Value or v2.BrickColor
					v2.Material = FindChild(v2, "KMat") and v2.KMat.Value or v2.Material
					if FindChild(v2, "KBC") then
						v2.KBC:Destroy()
					end
					if FindChild(v2, "KMat") then
						v2.KMat:Destroy()
					end
					if v2:IsA("MeshPart") and v2:FindFirstChild("KTexture") then
						v2.TextureID = v2.KTexture.Value
					end
				elseif v2:IsA("Accoutrement") then
					v2.Handle.Reflectance = 0
					v2.Handle.Transparency = 0
					v2.Handle.BrickColor = FindChild(v2, "KBC") and v2.KBC.Value or v2.Handle.BrickColor
					v2.Handle.Material = FindChild(v2, "KMat") and v2.KMat.Value or v2.Handle.Material
					if FindChild(v2, "KBC") then
						v2.KBC:Destroy()
					end
					if FindChild(v2, "KMat") then
						v2.KMat:Destroy()
					end
					if v2.Handle:IsA("MeshPart") and v2.Handle:FindFirstChild("KTexture") then
						v2.Handle.TextureID = v2.Handle.KTexture.Value
					end
					local mesh = v2.Handle:FindFirstChildOfClass("SpecialMesh")
					if mesh then
						mesh.TextureId = FindChild(mesh, "KTexture") and mesh.KTexture.Value or mesh.TextureId
						if FindChild(mesh, "KTexture") then
							mesh.KTexture:Destroy()
						end
					end
				end
			end
			for i, v in t:GetChildren() do
				if v:IsA("Motor6D") and FindChild(v, "LastC0") then
					v.C0 = v.LastC0.Value
					v.LastC0:Destroy()
				end
			end
			if torso then
				for i, v in torso:GetChildren() do
					if v:IsA("Motor6D") and FindChild(v, "LastC0") then
						v.C0 = v.LastC0.Value
						v.LastC0:Destroy()
					end
				end
			end
		end
	end
end
function f.Infect(pl, args)
	for i, plr in args[1] do
		if
			plr
			and plr.Character
			and FindChild(plr.Character, "HumanoidRootPart")
			and not FindChild(plr.Character, "KInfect")
		then
			if FindChild(plr.Character, "Shirt") then
				plr.Character.Shirt.Parent = plr.Character.HumanoidRootPart
			end
			if FindChild(plr.Character, "Pants") then
				plr.Character.Pants.Parent = plr.Character.HumanoidRootPart
			end
			while FindChild(plr.Character, "KShirt") do
				plr.Character.KShirt:Destroy()
			end
			while FindChild(plr.Character, "KPants") do
				plr.Character.KPants:Destroy()
			end
			for i2, v2 in plr.Character:GetChildren() do
				if v2:IsA("BasePart") and v2.Name ~= "HumanoidRootPart" then
					new("BrickColorValue")({ Parent = v2, Name = "KBC", Value = v2.BrickColor })
					v2.BrickColor = BrickColor.new("Medium green")
					if v2.Name:find("Leg") or v2.Name == "Torso" then
						v2.BrickColor = BrickColor.new("Reddish brown")
					end
				end
			end
			local infct, c = new("BoolValue")({ Parent = plr.Character, Name = "KInfect" })
			c = plr.Character.HumanoidRootPart.Touched:Connect(function(a)
				if not (plr and plr.Character and infct and infct.Parent == plr.Character) then
					c:Disconnect()
					return
				end
				if
					a
					and a.Parent
					and not a:IsDescendantOf(plr.Character)
					and FindChild(services.Players, a.Parent.Name)
				then
					f.Infect(pl, { { services.Players[a.Parent.Name] } })
				end
			end)
		end
	end
end
local function setGlobalWind(vector)
	services.Tween
		:Create(services.Workspace, TweenInfo.new(5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
			GlobalWind = vector,
		})
		:Play()
end
local function _getenv()
	local env = {}
	setmetatable(env, {
		__index = function(a, b)
			local e = getfenv()
			if e[b] then
				return e[b]
			end
			return nil
		end,
	})
	env.server = RemoteEvent
	env.wrap = wrap
	env.f = f
	env.s = f.Merge(f.Merge({}, state), services) -- deprecated
	env.state = state
	env.services = services
	return env
end
local commandsLoading = false
function LoadCommands()
	if commandsLoading then
		repeat
			task.wait()
		until not commandsLoading
	end
	commandsLoading = true
	state.Commands = {}
	--@@commands
	f.addCommand({ "credit" }, { "Shows you the admin credit." }, 0, {}, function(pl)
		RemoteEvent:FireClient(pl, "KCredit")
	end)
	f.addCommand({ "prefix" }, { "Shows you the current prefix." }, 0, {}, function(pl)
		f.Msg(pl, { ScriptName, "Prefix", "The Prefix is:\t" .. Set.Prefix }, pl)
	end)
	f.addCommand({ "version" }, { "Checks the version of Kohl's Admin Infinite." }, 0, {}, function(pl, args)
		f.Msg(pl, { ScriptName, "Version", version }, pl)
	end)
	f.addCommand({ "clean" }, { "Cleans up the game." }, 2, {}, function()
		CleanUp()
	end)
	f.addCommand({ "rejoin" }, { "Rejoins the game." }, 0, {}, function(pl)
		f.TP(game.PlaceId, pl)
	end)
	f.addCommand({ "ping" }, { "Shows your connection to the server." }, 0, {}, function(pl, args)
		local a, connection = tick()
		RemoteEvent:FireClient(pl, "KPing")
		connection = RemoteEvent.OnServerEvent:Connect(function(plr, c)
			if plr == pl and c == f.uID .. "KPing" then
				connection:Disconnect()
				f.Msg(pl, { ScriptName, "Ping Test", math.floor((tick() - a) * 1e3) .. "ms" }, pl)
			end
		end)
	end)
	f.addCommand({ "wait" }, { "Waits before continuing.", "1337" }, 0, { "time" }, function(pl, args)
		task.wait(args[1])
	end)

	f.addCommand({ "help", "faq", "guide", "info" }, { "Shows the Help GUI." }, 0, {}, function(pl, args)
		RemoteEvent:FireClient(pl, "KHelp")
	end)
	f.addCommand({ "cmds", "commands" }, { "Shows the commands list." }, 0, {}, function(pl, args)
		RemoteEvent:FireClient(pl, "KCmds", { state.Commands, f.getPower(pl), userPermissions[pl] })
	end)
	f.addCommand({ "settings", "set" }, { "Shows the in-game settings." }, 5, {}, function(pl, args)
		RemoteEvent:FireClient(pl, "KSettings", f.MapTab(Set))
	end)
	f.addCommand({ "admins", "adminlist" }, { "Shows the list of admins." }, 2, {}, function(pl, args)
		RemoteEvent:FireClient(pl, "KAdmins")
	end)
	f.addCommand({ "bans", "banlist", "banland" }, { "Shows the list of banned users." }, 2, {}, function(pl, args)
		RemoteEvent:FireClient(pl, "KBans", f.MapTab(Bans))
	end)

	f.addCommand({ "logs" }, { "Shows the command logs." }, Set.PublicLogs and 0 or 2, {}, function(pl, args)
		RemoteEvent:FireClient(pl, "KLogs", "Command Logs")
	end)
	f.addCommand({ "chatlogs", "clogs" }, { "Shows the chat logs." }, Set.PublicLogs and 0 or 2, {}, function(pl, args)
		RemoteEvent:FireClient(pl, "KCLogs", "Chat Logs")
	end)
	f.addCommand({ "hidelogs" }, { "Hides your commands from the logs." }, 5, {}, function(pl, args)
		Instance.new("BoolValue", pl).Name = "KHideLogs"
	end)
	f.addCommand({ "unhidelogs", "showlogs" }, { "Shows your commands in the logs." }, 5, {}, function(pl, args)
		while FindChild(pl, "KHideLogs") do
			pl.KHideLogs:Destroy()
		end
	end)

	f.addCommand({ "fix", "undisco" }, { "Reverts any changes made to Lighting." }, 2, {}, function(pl, args)
		if FindChild(script, "KLightEF") then
			script.KLightEF:Destroy()
		end
		services.Lighting.Ambient = OriginalLighting.Ambient
		services.Lighting.Brightness = OriginalLighting.Brightness
		services.Lighting.OutdoorAmbient = OriginalLighting.OutdoorAmbient
		services.Lighting.ShadowColor = OriginalLighting.ShadowColor
		services.Lighting.TimeOfDay = OriginalLighting.TimeOfDay
		services.Lighting.FogColor = OriginalLighting.FogColor
		services.Lighting.FogEnd = OriginalLighting.FogEnd
		services.Lighting.FogStart = OriginalLighting.FogStart
		services.Workspace.GlobalWind = OriginalLighting.GlobalWind
	end)
	f.addCommand({ "clear", "clr" }, { "Clears everything from the admin." }, 2, {}, function(pl, args)
		for i, v in ClearObjects do
			if v then
				v:Destroy()
			end
		end
		ClearObjects = {}
	end)
	f.addCommand({ "clearterrain", "cterrain" }, { "Removes terrain." }, 5, {}, function(pl, args)
		services.Workspace.Terrain:Clear()
	end)
	f.addCommand({ "clearlogs" }, { "Clears the command logs." }, 5, {}, function(pl, args)
		state.Logs = {}
		f.KUpdateLogs()
	end)
	f.addCommand({ "clearchatlogs" }, { "Clears the chat logs." }, 5, {}, function(pl, args)
		state.ChatLogs = {}
		f.KUpdateCLogs()
	end)

	f.addCommand({ "owner" }, { "Grants permanent owner powers.", "Kohl" }, 6, { "userid" }, function(pl, args)
		for i, id in args[1] do
			if id and f.Auth(pl.UserId, id, 0) then
				f.setPower(id, -5)
				id = f.Id2Plr(id)
				if id then
					f.Msg(pl, { ScriptName, pl.DisplayName, f.AdminMsg(5) }, id)
				end
			end
		end
	end)
	f.addCommand(
		{ "superadmin" },
		{ "Grants permanent superadmin powers.", "Kohl" },
		5,
		{ "userid" },
		function(pl, args)
			for i, id in args[1] do
				if id and f.Auth(pl.UserId, id, 0) then
					f.setPower(id, -4)
					id = f.Id2Plr(id)
					if id then
						f.Msg(pl, { ScriptName, pl.DisplayName, f.AdminMsg(4) }, id)
					end
				end
			end
		end
	)
	f.addCommand({ "admin" }, { "Grants permanent admin powers.", "Kohl" }, 4, { "userid" }, function(pl, args)
		for i, id in args[1] do
			if id and f.Auth(pl.UserId, id, 0) then
				f.setPower(id, -3)
				id = f.Id2Plr(id)
				if id then
					f.Msg(pl, { ScriptName, pl.DisplayName, f.AdminMsg(3) }, id)
				end
			end
		end
	end)
	f.addCommand({ "mod" }, { "Grants permanent moderator powers.", "Kohl" }, 4, { "userid" }, function(pl, args)
		for i, id in args[1] do
			if id and f.Auth(pl.UserId, id, 0) then
				f.setPower(id, -2)
				id = f.Id2Plr(id)
				if id then
					f.Msg(pl, { ScriptName, pl.DisplayName, f.AdminMsg(2) }, id)
				end
			end
		end
	end)
	f.addCommand({ "vip" }, { "Grants permanent VIP powers.", "Kohl" }, 4, { "userid" }, function(pl, args)
		for i, id in args[1] do
			if id and f.Auth(pl.UserId, id, 0) then
				f.setPower(id, -1)
				id = f.Id2Plr(id)
				if id then
					f.Msg(pl, { ScriptName, pl.DisplayName, f.AdminMsg(1) }, id)
				end
			end
		end
	end)
	f.addCommand({ "tempowner" }, { "Grants temporary owner powers.", "Kohl" }, 6, { "player" }, function(pl, args)
		for i, plr in args[1] do
			if plr and f.Auth(pl, plr, 0) then
				f.setPower(plr.UserId, 5)
				f.Msg(pl, { ScriptName, pl.DisplayName, f.AdminMsg(5) }, plr)
			end
		end
	end)
	f.addCommand(
		{ "tempsuperadmin" },
		{ "Grants temporary superadmin powers.", "player" },
		5,
		{ "player" },
		function(pl, args)
			for i, plr in args[1] do
				if plr and f.Auth(pl, plr, 0) then
					f.setPower(plr.UserId, 4)
					f.Msg(pl, { ScriptName, pl.DisplayName, f.AdminMsg(4) }, plr)
				end
			end
		end
	)
	f.addCommand({ "tempadmin" }, { "Grants temporary admin powers.", "Kohl" }, 4, { "player" }, function(pl, args)
		for i, plr in args[1] do
			if plr and f.Auth(pl, plr, 0) then
				f.setPower(plr.UserId, 3)
				f.Msg(pl, { ScriptName, pl.DisplayName, f.AdminMsg(3) }, plr)
			end
		end
	end)
	f.addCommand({ "tempmod" }, { "Grants temporary moderator powers.", "Kohl" }, 3, { "player" }, function(pl, args)
		for i, plr in args[1] do
			if plr and f.Auth(pl, plr, 0) then
				f.setPower(plr.UserId, 2)
				f.Msg(pl, { ScriptName, pl.DisplayName, f.AdminMsg(2) }, plr)
			end
		end
	end)
	f.addCommand({ "tempvip" }, { "Grants temporary VIP powers.", "Kohl" }, 3, { "player" }, function(pl, args)
		for i, plr in args[1] do
			if plr and f.Auth(pl, plr, 0) then
				f.setPower(plr.UserId, 1)
				f.Msg(pl, { ScriptName, pl.DisplayName, f.AdminMsg(1) }, plr)
			end
		end
	end)
	f.addCommand({ "unowner" }, { "Removes owner powers.", "Kohl" }, 6, { "admin" }, function(pl, args)
		local p = f.getPower(pl)
		if args[1] == "" then
			for i, v in Admins do
				v = math.abs(v)
				if v < p and v == 5 then
					f.setPower(i, 0)
				end
			end
		elseif args[1] and f.Auth(pl.UserId, args[1], 0) then
			f.setPower(args[1], 0)
		end
	end)
	f.addCommand({ "unsuperadmin" }, { "Removes superadmin powers.", "Kohl" }, 5, { "admin" }, function(pl, args)
		local p = f.getPower(pl)
		if args[1] == "" then
			for i, v in Admins do
				v = math.abs(v)
				if v < p and v == 4 then
					f.setPower(i, 0)
				end
			end
		elseif args[1] and f.Auth(pl.UserId, args[1], 0) then
			f.setPower(args[1], 0)
		end
	end)
	f.addCommand({ "unadmin" }, { "Removes admin powers.", "Kohl" }, 4, { "admin" }, function(pl, args)
		local p = f.getPower(pl)
		if args[1] == "" then
			for i, v in Admins do
				v = math.abs(v)
				if v < p and v == 3 then
					f.setPower(i, 0)
				end
			end
		elseif args[1] and f.Auth(pl.UserId, args[1], 0) then
			f.setPower(args[1], 0)
		end
	end)
	f.addCommand({ "unmod" }, { "Removes mod powers.", "Kohl" }, 3, { "admin" }, function(pl, args)
		local p = f.getPower(pl)
		if args[1] == "" then
			for i, v in Admins do
				v = math.abs(v)
				if v < p and v == 2 then
					f.setPower(i, 0)
				end
			end
		elseif args[1] and f.Auth(pl.UserId, args[1], 0) then
			f.setPower(args[1], 0)
		end
	end)
	f.addCommand({ "unvip" }, { "Removes VIP powers.", "Kohl" }, 3, { "admin" }, function(pl, args)
		local p = f.getPower(pl)
		if args[1] == "" then
			for i, v in Admins do
				v = math.abs(v)
				if v < p and v == 1 then
					f.setPower(i, 0)
				end
			end
		elseif args[1] and f.Auth(pl.UserId, args[1], 0) then
			f.setPower(args[1], 0)
		end
	end)

	f.addCommand({ "pban" }, { "Permanently bans players from the game.", "Kohl" }, 4, { "userid" }, function(pl, args)
		for i, id in args[1] do
			if id and f.GroupAdminAuth(pl.UserId, id, 0) and f.getPower(id) < 7 then
				f.setBan(id, -1)
				id = f.Id2Plr(id)
				if id then
					f.Kick(id, "Permanently banned!")
				end
			end
		end
	end)
	f.addCommand(
		{ "tban" },
		{ "Temporarily bans players.", "Kohl 60s [s/m/h/d]" },
		4,
		{ "userid", "time" },
		function(pl, args)
			for i, id in args[1] do
				if id and f.GroupAdminAuth(pl.UserId, id, 0) and f.getPower(id) < 7 then
					f.setBan(id, -os.time() - args[2])
					id = f.Id2Plr(id)
					if id then
						f.Kick(id, "Banned for:\t" .. math.floor(args[2] / 60) .. " minutes!")
					end
				end
			end
		end
	)
	f.addCommand({ "ban" }, { "Bans players from the server.", "Kohl" }, 3, { "userid" }, function(pl, args)
		for i, id in args[1] do
			if id and f.GroupAdminAuth(pl.UserId, id, 0) then
				f.setBan(id, 2)
				id = f.Id2Plr(id)
				if id then
					f.Kick(id, "Banned from server!")
				end
			end
		end
	end)
	f.addCommand({ "unban" }, { "Removes a ban from players.", "Kohl" }, 3, { "banned" }, function(pl, args)
		if args[1] == "" then
			for i, v in Bans do
				if v > 0 or f.getPower(pl) > 3 then
					f.setBan(i, 0)
				end
			end
		elseif Bans[args[1]] > 0 or f.getPower(pl) > 3 then
			f.setBan(args[1], 0)
		end
	end)
	f.addCommand({ "unbanid" }, { "Removes a ban from a userid.", "123" }, 3, { "number" }, function(pl, args)
		if tonumber(Bans[args[1]]) then
			if Bans[args[1]] > 0 or f.getPower(pl) > 3 then
				f.setBan(args[1], 0)
			end
		end
	end)
	f.addCommand({ "crash" }, { "Crashes players.", "Kohl" }, 3, { "player" }, function(pl, args)
		for i, plr in args[1] do
			if plr and f.Auth(pl, plr, 0) then
				RemoteEvent:FireClient(plr, "KCrash")
			end
		end
	end)
	f.addCommand({ "kick" }, { "Kicks players.", "Kohl" }, 2, { "player", "string/" }, function(pl, args)
		local textObject = getTextObject(args[2], pl.UserId)
		for i, plr in args[1] do
			if plr and f.Auth(pl, plr, 0) then
				if not pcall(plr.Kick, plr, getFilteredMessage(textObject, pl.UserId, plr.UserId)) then
					RemoteEvent:FireClient(plr, "KCrash")
				end
			end
		end
	end)

	f.addCommand({ "mute", "silence", "stfu" }, { "Mutes players.", "Kohl" }, 2, { "player" }, function(pl, args)
		for _, plr in args[1] do
			if plr and f.Auth(pl, plr) then
				RemoteEvent:FireClient(plr, "KMute", true)
				if services.TextChat:FindFirstChild("TextChannels") then
					for _, v in services.TextChat.TextChannels:GetDescendants() do
						if v.ClassName == "TextSource" and v.Name == plr.Name and v.CanSend then
							v:SetAttribute("CouldSend", true)
							v.CanSend = false
						end
					end
				end
			end
		end
	end)
	f.addCommand(
		{ "unmute", "unsilence", "unstfu" },
		{ "Unmutes players.", "Kohl" },
		2,
		{ "player" },
		function(pl, args)
			for _, plr in args[1] do
				if plr and f.Auth(pl, plr) then
					RemoteEvent:FireClient(plr, "KMute", false)
					if services.TextChat:FindFirstChild("TextChannels") then
						for _, v in services.TextChat.TextChannels:GetDescendants() do
							if v.ClassName == "TextSource" and v.Name == plr.Name and v:GetAttribute("CouldSend") then
								v.CanSend = true
							end
						end
					end
				end
			end
		end
	)

	f.addCommand({ "serverlock", "slock" }, { "Prevents nonadmins from joining." }, 3, {}, function(pl, args)
		f.Hint(pl, "SERVERLOCK: ON")
		LocalSet.SLock = 1
	end)
	f.addCommand({ "unserverlock", "unslock", "serverunlock" }, { "Unlocks the server." }, 3, {}, function(pl, args)
		f.Hint(pl, "SERVERLOCK: OFF")
		LocalSet.SLock = nil
	end)
	f.addCommand({ "shutdown" }, { "Shut the game down.", "10(optional)" }, 4, { "number/" }, function(pl, args)
		if args[1] then
			for i = args[1], 1, -1 do
				f.Msg(pl, { "SHUTTING DOWN", pl.DisplayName, i })
				task.wait(1)
			end
		end
		local function Kill(v)
			if v then
				if not pcall(function()
					v:Kick(pl.DisplayName .. " has shutdown the game.")
				end) then
					v:Destroy()
				end
			end
		end
		for i, v in f.Players() do
			Kill(v)
		end
		game.Players.PlayerAdded:Connect(Kill)
	end)
	f.addCommand(
		{ "reserve", "r" },
		{ "Reserves a private server.", "r PrivetServer 1337" },
		4,
		{ "word", "number/" },
		function(pl, args)
			local id = args[2] or game.PlaceId
			local ok = pcall(function()
				GlobalDataStore:UpdateAsync(dataKey.servers, function(data)
					data = data or {}
					data[args[1]] = { Code = services.Teleport:ReserveServer(id), Id = id }
					return data
				end)
			end)
			if ok then
				f.Hint(
					pl,
					"Private Server:\t" .. args[1] .. "\thas been created! Use the place command to visit it!",
					pl
				)
			end
		end
	)
	f.addCommand(
		{ "unreserve", "unr" },
		{ "Removes a reserved private server.", "unr PrivetServer" },
		4,
		{ "word" },
		function(pl, args)
			pcall(function()
				GlobalDataStore:UpdateAsync(dataKey.servers, function(data)
					data = data or {}
					if data[args[1]] then
						data[args[1]] = nil
						f.Hint(pl, "Private Server:\t" .. args[1] .. " has been removed!", pl)
					else
						f.Hint(pl, "Private Server:\t" .. args[1] .. "\thas NOT been found!", pl)
					end
					return data
				end)
			end)
		end
	)
	f.addCommand(
		{ "btools", "build" },
		{ "Gives a player building tools.", "Kohl" },
		3,
		{ "player" },
		function(pl, args)
			for i, plr in args[1] do
				if plr and plr.Character and FindChild(plr, "Backpack") then
					new("HopperBin")({ Name = "Move", BinType = "GameTool", Parent = plr.Backpack })
					new("HopperBin")({ Name = "Clone", BinType = "Clone", Parent = plr.Backpack })
					new("HopperBin")({ Name = "Delete", BinType = "Hammer", Parent = plr.Backpack })
				end
			end
		end
	)
	f.addCommand({ "f3x" }, { "Gives a player F3X building tools.", "Kohl" }, 5, { "player" }, function(pl, args)
		for i, plr in args[1] do
			if plr and plr.Character and FindChild(plr, "Backpack") then
				BuildingTools:Clone().Parent = plr.Backpack
			end
		end
	end)

	-- don't give privateserverowner's scripting access or they can affect the main game!
	if not IS_PRIVATE_SERVER then
		f.addCommand({ "explorer" }, { "Gives player an explorer.", "anaminus" }, 4, { "player" }, function(pl, args)
			for i, plr in args[1] do
				if plr and FindChild(plr, "PlayerGui") then
					pl = Dependencies.Extras.Explorer:Clone()
					new("StringValue")({ Parent = pl.Explorer.LocalScript, Name = "uID", Value = f.uID })
					pl.Parent = plr.PlayerGui
				end
			end
		end)
		f.addCommand(
			{ "s", "script" },
			{ "Creates a script.", "game.Players:Destroy()" },
			5,
			{ "string" },
			function(pl, args)
				if pcall(loadstring("a=0")) == false then
					f.Error("LoadString must be enabled to use the script command!", pl)
				else
					local success, err = pcall(loadstring(args[1]))
					if success == false then
						f.Error("SCRIPT ERROR\t" .. err, pl)
					end
				end
			end
		)
		f.addCommand(
			{ "ls", "localscript" },
			{ "Creates a localscript.", "game.Players:Destroy()" },
			5,
			{ "string" },
			function(pl, args)
				if not (pl and pl.Character) then
					return
				end
				local localScript = Dependencies.LocalScriptBase:Clone()
				localScript.Parent = pl.Character
				table.insert(ClearObjects, localScript)
				new("StringValue")({ Name = "Code", Value = args[1], Parent = localScript })
				Dependencies.Loadstring:Clone().Parent = localScript
				localScript.Disabled = false
			end
		)
		f.addCommand(
			{ "lsplr", "localscriptplr" },
			{ "Creates a localscript in a player.", "Kohl game.Players.LocalPlayer:Destroy()" },
			5,
			{ "player", "string" },
			function(pl, args)
				for i, plr in args[1] do
					if plr and plr.Character then
						local localScript = Dependencies.LocalScriptBase:Clone()
						localScript.Parent = plr.Character
						table.insert(ClearObjects, localScript)
						new("StringValue")({ Name = "Code", Value = args[2], Parent = localScript })
						Dependencies.Loadstring:Clone().Parent = localScript
						localScript.Disabled = false
					end
				end
			end
		)
	end

	f.addCommand(
		{ "copytools", "copytool", "ctools" },
		{ "Copies a player's tools to another player.", "WickedMemory Kohl" },
		2,
		{ "player", "player/" },
		function(pl, args)
			args[2] = args[2] or { pl }
			local t = {}
			for i, plr in args[1] do
				if plr and (FindChild(plr, "Backpack") or plr.Character) and f.Auth(pl, plr) then
					if FindChild(plr, "Backpack") then
						for i, v in plr.Backpack:GetChildren() do
							if v:IsA("BackpackItem") then
								t[#t + 1] = v
							end
						end
					end
					if plr.Character then
						for i, v in plr.Character:GetChildren() do
							if v:IsA("BackpackItem") then
								t[#t + 1] = v
							end
						end
					end
				end
			end
			for i, plr in args[2] do
				if plr and FindChild(plr, "Backpack") then
					for i, v in t do
						v:Clone().Parent = plr.Backpack
					end
				end
			end
		end
	)
	f.addCommand(
		{ "viewtools", "viewtool", "vtools" },
		{ "Shows a player's tools.", "WickedMemory" },
		2,
		{ "player" },
		function(pl, args)
			local t = {}
			for i, plr in args[1] do
				if plr and (FindChild(plr, "Backpack") or plr.Character) then
					if FindChild(plr, "Backpack") then
						for i, v in plr.Backpack:GetChildren() do
							if v:IsA("BackpackItem") then
								t[#t + 1] = plr.DisplayName .. "\t" .. v.Name
							end
						end
					end
					if plr.Character then
						for i, v in plr.Character:GetChildren() do
							if v:IsA("BackpackItem") then
								t[#t + 1] = plr.DisplayName .. "\t" .. v.Name
							end
						end
					end
				end
			end
			RemoteEvent:FireClient(pl, "KTools", t)
		end
	)
	f.addCommand(
		{ "tools", "toollist" },
		{ "Shows the tools from the Lighting and ServerStorage." },
		2,
		{},
		function(pl, args)
			local tools = {}
			for i, v in services.Lighting:GetChildren() do
				if v:IsA("Tool") or v:IsA("HopperBin") then
					table.insert(tools, v.Name)
				end
			end
			for i, v in services.ServerStorage:GetChildren() do
				if v:IsA("Tool") or v:IsA("HopperBin") then
					table.insert(tools, v.Name)
				end
			end
			RemoteEvent:FireClient(pl, "KTools", tools)
		end
	)
	f.addCommand(
		{ "toolban", "bantools", "restricttools" },
		{ "Bans a player from using tools.", "Kohl" },
		2,
		{ "player" },
		function(pl, args)
			for i, plr in args[1] do
				if
					plr
					and f.Auth(pl, plr)
					and plr.Character
					and FindChild(plr, "Backpack")
					and not FindChild(plr, "KTBan")
				then
					new("StringValue")({ Parent = plr, Name = "KTBan" })
					f.rmvTools(plr)
					local c, c2
					c = plr.Character.ChildAdded:Connect(function()
						if not (plr and FindChild(plr, "KTBan")) then
							c:Disconnect()
							c2:Disconnect()
						end
						f.rmvTools(plr)
					end)
					c2 = plr.Character.ChildAdded:Connect(function()
						if not (plr and FindChild(plr, "KTBan")) then
							c:Disconnect()
							c2:Disconnect()
						end
						f.rmvTools(plr)
					end)
				end
			end
		end
	)
	f.addCommand(
		{ "untoolban", "unbantools", "unrestricttools" },
		{ "Removes a toolban from a player.", "Kohl" },
		2,
		{ "player" },
		function(pl, args)
			for i, plr in args[1] do
				if plr and f.Auth(pl, plr) and FindChild(plr, "KTBan") then
					plr.KTBan:Destroy()
				end
			end
		end
	)
	f.addCommand(
		{ "give" },
		{ "Gives a player a tool from the Lighting or ServerStorage.", "Kohl all" },
		2,
		{ "player", "string" },
		function(pl, args)
			for i, plr in args[1] do
				if plr and plr.Character and FindChild(plr, "Backpack") then
					for i, v in services.Lighting:GetChildren() do
						if
							v.Name:lower():find("^" .. args[2]:lower())
							or (args[2]:lower() == "all" and (v:IsA("Tool") or v:IsA("HopperBin")))
						then
							v:Clone().Parent = plr.Backpack
						end
					end
					for i, v in services.ServerStorage:GetChildren() do
						if
							v.Name:lower():find("^" .. args[2]:lower())
							or (args[2]:lower() == "all" and (v:IsA("Tool") or v:IsA("HopperBin")))
						then
							v:Clone().Parent = plr.Backpack
						end
					end
				end
			end
		end
	)
	f.addCommand(
		{ "startergive", "sgive" },
		{ "Permanently gives a player a tool from the lighting.", "Kohl all" },
		2,
		{ "player", "string" },
		function(pl, args)
			for i, plr in args[1] do
				if plr and plr.Character and FindChild(plr, "Backpack") and FindChild(plr, "StarterGear") then
					for i, v in services.Lighting:GetChildren() do
						if
							v.Name:lower():find("^" .. args[2]:lower())
							or (args[2]:lower() == "all" and (v:IsA("Tool") or v:IsA("HopperBin")))
						then
							v:Clone().Parent = plr.Backpack
							v:Clone().Parent = plr.StarterGear
						end
					end
					for i, v in services.ServerStorage:GetChildren() do
						if
							v.Name:lower():find("^" .. args[2]:lower())
							or (args[2]:lower() == "all" and (v:IsA("Tool") or v:IsA("HopperBin")))
						then
							v:Clone().Parent = plr.Backpack
							v:Clone().Parent = plr.StarterGear
						end
					end
				end
			end
		end
	)
	f.addCommand(
		{ "starterremove", "sremove", "unstartergive", "unsgive" },
		{ "Removes a tool from StarterGear.", "Kohl all" },
		2,
		{ "player", "string" },
		function(pl, args)
			for i, plr in args[1] do
				if plr and plr.Character and FindChild(plr, "Backpack") and FindChild(plr, "StarterGear") then
					for i, v in plr.StarterGear:GetChildren() do
						if
							v.Name:lower():find("^" .. args[2]:lower())
							or (args[2]:lower() == "all" and (v:IsA("Tool") or v:IsA("HopperBin")))
						then
							v:Destroy()
						end
					end
					for i, v in plr.Backpack:GetChildren() do
						if
							v.Name:lower():find("^" .. args[2]:lower())
							or (args[2]:lower() == "all" and (v:IsA("Tool") or v:IsA("HopperBin")))
						then
							v:Destroy()
						end
					end
				end
			end
		end
	)
	f.addCommand(
		{ "starttools", "stools" },
		{ "Gives tools from the StarterPack.", "Kohl" },
		2,
		{ "player" },
		function(pl, args)
			for i, plr in args[1] do
				if plr and plr.Character and FindChild(plr, "Backpack") then
					for i2, v in services.StarterPack:GetChildren() do
						v:Clone().Parent = plr.Backpack
					end
				end
			end
		end
	)
	f.addCommand({ "sword" }, { "Gives a player a sword.", "Kohl" }, 2, { "player" }, function(pl, args)
		if not SWORD then
			return
		end
		for i, plr in args[1] do
			if plr and FindChild(plr, "Backpack") then
				SWORD:Clone().Parent = plr.Backpack
			end
		end
	end)

	f.addCommand(
		{ "plrcount", "playercount", "countplayers", "countplrs" },
		{ "Returns the number of players in-game." },
		2,
		{},
		function(pl, args)
			args = 0
			for i, v in f.Players() do
				args = args + 1
			end
			f.Msg(pl, { ScriptName, "Player Count", args .. " Player" .. (args ~= 1 and "s!" or "!") }, pl)
		end
	)
	f.addCommand({ "serverage" }, { "Checks the age of the server." }, 2, {}, function(pl, args)
		f.Msg(pl, { ScriptName, "Server Age", f.getTime(services.Workspace.DistributedGameTime) }, pl)
	end)
	f.addCommand({ "age" }, { "Checks the age of a player.", "Kohl" }, 2, { "player" }, function(pl, args)
		for i, plr in args[1] do
			if plr then
				f.Msg(pl, { ScriptName, plr.DisplayName .. "'s Age", plr.AccountAge }, pl)
			end
		end
	end)
	f.addCommand(
		{ "rank" },
		{ "Checks the rank of a player in a group.", "Kohl 451053" },
		2,
		{ "player", "number" },
		function(pl, args)
			for i, plr in args[1] do
				if not (plr and plr:IsInGroup(args[2])) then
					return
				end
				f.Msg(pl, {
					ScriptName,
					plr.DisplayName .. "'s Group Rank",
					"[" .. plr:GetRankInGroup(args[2]) .. "] " .. plr:GetRoleInGroup(args[2]),
				}, pl)
			end
		end
	)
	f.addCommand(
		{ "buy", "purchase" },
		{ "Prompts a purchase for a player.", "Kohl 1337" },
		2,
		{ "player", "number" },
		function(pl, args)
			for i, plr in args[1] do
				if plr then
					RemoteEvent:FireClient(plr, "KBuy", args[2])
				end
			end
		end
	)
	f.addCommand(
		{ "buybundle", "purchasebundle" },
		{ "Prompts a bundle purchase for a player.", "Kohl 1337" },
		2,
		{ "player", "number" },
		function(pl, args)
			for i, plr in args[1] do
				if plr then
					RemoteEvent:FireClient(plr, "KBuyBundle", args[2])
				end
			end
		end
	)
	f.addCommand(
		{ "buypass", "purchasepass" },
		{ "Prompts a gamepass purchase for a player.", "Kohl 1337" },
		2,
		{ "player", "number" },
		function(pl, args)
			for i, plr in args[1] do
				if plr then
					RemoteEvent:FireClient(plr, "KBuyGamePass", args[2])
				end
			end
		end
	)
	f.addCommand(
		{ "buyproduct", "purchaseproduct" },
		{ "Prompts a developer product purchase for a player.", "Kohl 1337" },
		2,
		{ "player", "number" },
		function(pl, args)
			for i, plr in args[1] do
				if plr then
					RemoteEvent:FireClient(plr, "KBuyProduct", args[2])
				end
			end
		end
	)
	f.addCommand(
		{ "has" },
		{ "Checks if they have an asset.", "WickedMemory 1337" },
		2,
		{ "player", "number" },
		function(pl, args)
			for i, plr in args[1] do
				if plr then
					f.Hint(
						pl,
						plr.DisplayName .. (f.Has(plr, args[2]) and " has" or " does NOT have") .. " the asset!",
						pl
					)
				end
			end
		end
	)
	f.addCommand(
		{ "badge", "awardbadge" },
		{ "Awards badge to a player.", "WickedMemory 1337" },
		5,
		{ "player", "number" },
		function(pl, args)
			for i, plr in args[1] do
				if plr then
					if services.Badge:UserHasBadgeAsync(plr.UserId, args[2]) then
						f.Hint(pl, plr.DisplayName .. " already has the badge!", pl)
					else
						f.Hint(pl, "Awarding badge to: " .. plr.DisplayName, pl)
						services.Badge:AwardBadge(plr.UserId, args[2])
					end
				end
			end
		end
	)
	f.addCommand(
		{ "vote", "makevote", "startvote" },
		{ "Creates a yes/no vote and displays the results.", "Kohl Do you like pie?" },
		2,
		{ "player", "string" },
		function(pl, args)
			local t = tick()
			state.LastVote = t
			state.Votes = {}
			local textObject = getTextObject(args[2], pl.UserId)
			for i, plr in args[1] do
				if plr then
					RemoteEvent:FireClient(plr, "KVote", getFilteredMessage(textObject, pl.UserId, plr.UserId))
				end
			end
			task.delay(10, function()
				if t == state.LastVote then
					local y, n, t = 0, 0, 0
					for i, v in state.Votes do
						if v then
							y += 1
						else
							n += 1
						end
						t += 1
					end
					f.Msg(pl, {
						ScriptName,
						"Vote Results",
						string.format(
							"%s\nYES: %d (%.0f%%)\t NO: %d (%.0f%%)",
							args[2],
							y,
							(y / t) * 100,
							n,
							(n / t) * 100
						),
					}, pl)
				end
			end)
		end
	)

	f.addCommand(
		{ "announce", "an", "sm" },
		{ "Shouts an announcement.", "I'm banning everyone." },
		3,
		{ "string" },
		function(pl, args)
			f.filteredMsg(pl, { ScriptName, "Announcement", args[1] })
		end
	)
	f.addCommand(
		{ "m", "msg", "shout" },
		{ "Shouts a message.", "The cake is a lie." },
		2,
		{ "string" },
		function(pl, args)
			f.filteredMsg(pl, { pl.DisplayName, f.getTitle(pl), args[1] })
		end
	)
	f.addCommand({ "h", "hint" }, { "Hints a message.", "Don't look at this." }, 2, { "string" }, function(pl, args)
		f.Hint(pl, pl.DisplayName .. ": " .. args[1])
	end)
	f.addCommand(
		{ "pm", "pmsg" },
		{ "Privately shouts a message.", "Kohl I like you." },
		2,
		{ "player", "string" },
		function(pl, args)
			for i, plr in args[1] do
				f.filteredMsg(pl, { pl.DisplayName, "Private Message", args[2] }, plr)
			end
		end
	)
	f.addCommand(
		{ "ph", "phint" },
		{ "Privately hints a message.", "Why hello there." },
		2,
		{ "player", "string" },
		function(pl, args)
			for i, plr in args[1] do
				f.Hint(pl, pl.DisplayName .. ": " .. args[2], plr)
			end
		end
	)
	f.addCommand({ "notify", "n" }, { "Places a permanent message.", "I'm afk." }, 2, { "string" }, function(pl, args)
		local a = FindChild(RemoteEvent, "KNotify") or new("StringValue")({ Parent = RemoteEvent, Name = "KNotify" })
		local textObject = getTextObject(args[1], pl.UserId)
		a.Value = getFilteredMessage(textObject, pl.UserId)
		RemoteEvent:FireAllClients("KNotify", a.Value)
	end)
	f.addCommand({ "rnotify", "rn" }, { "Removes a permanent message." }, 2, {}, function(a)
		a = FindChild(RemoteEvent, "KNotify")
		if a then
			a:Destroy()
		end
		RemoteEvent:FireAllClients("KNotify")
	end)
	f.addCommand({ "countdown", "cd" }, { "Counts down from a number.", "69" }, 2, { "number" }, function(pl, args)
		local cd = FindChild(RemoteEvent, "KCountDown")
		if cd then
			cd:Destroy()
		end
		local duration = math.min(args[1], 120)
		cd = new("IntValue")({ Parent = RemoteEvent, Name = "KCountDown", Value = duration })
		table.insert(ClearObjects, cd)
		task.delay(duration, cd.Destroy, cd)
		RemoteEvent:FireAllClients("KCountDown", { cd, duration })
	end)

	f.addCommand(
		{ "name", "nick", "nickname", "nn" },
		{ "Modify player's names.", "Scripth Kohl" },
		2,
		{ "player", "string" },
		function(pl, args)
			local filtered = getFilteredMessage(getTextObject(args[2], pl.UserId), pl.UserId)
			for i, plr in args[1] do
				if
					args[2]
					and f.CheckNF(args[2])
					and plr
					and plr.Character
					and FindChild(plr.Character, "Humanoid")
					and f.Auth(pl, plr)
				then
					displayNames[plr.UserId] = filtered
					displayName(plr)
				end
			end
		end
	)
	f.addCommand(
		{ "unname", "unnick", "unnickname", "unnn", "showname" },
		{ "Removes a player's name.", "Scripth" },
		2,
		{ "player" },
		function(pl, args)
			for i, plr in args[1] do
				if plr and plr.Character and FindChild(plr.Character, "Humanoid") and f.Auth(pl, plr) then
					displayNames[plr.UserId] = plr.DisplayName
					displayName(plr)
				end
			end
		end
	)
	f.addCommand({ "hidename", "hname" }, { "Hides a player's name.", "Kohl" }, 2, { "player" }, function(pl, args)
		for i, plr in args[1] do
			if plr and plr.Character and FindChild(plr.Character, "Humanoid") and f.Auth(pl, plr) then
				plr.Character.Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			end
		end
	end)

	f.addCommand({ "kill", "slay" }, { "Kills a player.", "Kohl" }, 2, { "player" }, function(pl, args)
		for i, plr in args[1] do
			if plr and plr.Character and f.Auth(pl, plr) then
				plr.Character:BreakJoints()
			end
		end
	end)
	f.addCommand({ "loopkill", "loopslay" }, { "Loopkills a player.", "Kohl" }, 3, { "player" }, function(pl, args)
		for i, plr in args[1] do
			if plr and f.Auth(pl, plr) then
				local loopObject = new("ObjectValue")({ Parent = script, Name = "Loop", Value = plr })
				local connection
				local function loopkill(character)
					if not loopObject or loopObject.Parent ~= script then
						connection:Disconnect()
						return
					end
					if character then
						task.wait()
						character:BreakJoints()
					end
				end
				table.insert(ClearObjects, loopObject)
				connection = plr.CharacterAdded:Connect(loopkill)
				loopkill(plr.Character)
			end
		end
	end)
	f.addCommand(
		{ "unloopkill", "unloopslay" },
		{ "Unloopkills a player.", "Kohl" },
		3,
		{ "player" },
		function(pl, args)
			for i, plr in args[1] do
				if plr and plr.Character and f.Auth(pl, plr) then
					for i, v in ClearObjects do
						if v and v.Name == "Loop" and v.Value == plr then
							v:Destroy()
						end
					end
				end
			end
		end
	)

	f.addCommand({ "refresh", "re" }, { "Refreshes a player.", "Kohl" }, 2, { "player" }, function(pl, args)
		for i, plr in args[1] do
			if plr and f.Auth(pl, plr) and plr.Character and FindChild(plr.Character, "HumanoidRootPart") then
				RemoteEvent:FireClient(plr, "KRefresh")
				KRefresh[plr] = true
			end
		end
	end)
	f.addCommand({ "respawn", "spawn" }, { "Respawns a player.", "Kohl" }, 2, { "player" }, function(pl, args)
		for i, plr in args[1] do
			if plr and f.Auth(pl, plr) then
				plr:LoadCharacter()
			end
		end
	end)
	f.addCommand(
		{ "damage", "dmg" },
		{ "Damages a player.", "Kohl 1337" },
		2,
		{ "player", "number" },
		function(pl, args)
			for i, plr in args[1] do
				if plr and plr.Character and FindChild(plr.Character, "Humanoid") then
					plr.Character.Humanoid:TakeDamage(math.abs(args[2]))
				end
			end
		end
	)
	f.addCommand({ "heal" }, { "Heals a player.", "Kohl" }, 2, { "player", "number/" }, function(pl, args)
		for i, plr in args[1] do
			if plr and plr.Character and FindChild(plr.Character, "Humanoid") then
				plr.Character.Humanoid.Health = args[2] and plr.Character.Humanoid.Health + args[2]
					or plr.Character.Humanoid.MaxHealth
			end
		end
	end)
	f.addCommand(
		{ "health", "hp", "maxhealth", "maxhp" },
		{ "Modify a player's health.", "Kohl 1337" },
		2,
		{ "player", "number" },
		function(pl, args)
			for i, plr in args[1] do
				if plr and plr.Character and FindChild(plr.Character, "Humanoid") then
					plr.Character.Humanoid.MaxHealth = math.max(1, args[2])
					wrap(function()
						repeat
							task.wait()
							plr.Character.Humanoid.Health = plr.Character.Humanoid.MaxHealth
						until plr.Character.Humanoid.Health == plr.Character.Humanoid.MaxHealth
							or plr.Character.Humanoid.Health <= 0
					end)
				end
			end
		end
	)
	f.addCommand(
		{ "speed", "spd", "walkspeed" },
		{ "Modify a player's walkspeed.", "Kohl 1337" },
		2,
		{ "player", "number" },
		function(pl, args)
			for i, plr in args[1] do
				if plr and plr.Character and FindChild(plr.Character, "Humanoid") then
					plr.Character.Humanoid.WalkSpeed = f.Auth(pl, plr) and args[2] or math.clamp(args[2], -9e9, 9e9)
				end
			end
		end
	)
	f.addCommand(
		{ "jumppower" },
		{ "Modify a player's jump power.", "Kohl 1337" },
		2,
		{ "player", "number" },
		function(pl, args)
			for i, plr in args[1] do
				if plr and plr.Character and FindChild(plr.Character, "Humanoid") then
					plr.Character.Humanoid.JumpPower = f.Auth(pl, plr) and args[2] or math.min(200, args[2])
				end
			end
		end
	)
	f.addCommand({ "god" }, { "Gives a player infinite health.", "Kohl" }, 2, { "player" }, function(pl, args)
		for i, plr in args[1] do
			if plr and plr.Character and FindChild(plr.Character, "Humanoid") then
				local hum, kg, c = plr.Character.Humanoid, new("IntValue")({ Parent = plr.Character, Name = "KGod" })
				hum.Health, hum.MaxHealth = math.huge, math.huge
				c = hum.HealthChanged:Connect(function()
					if not (kg and kg.Parent == plr.Character) then
						c:Disconnect()
						return
					end
					hum.Health, hum.MaxHealth = math.huge, math.huge
				end)
			end
		end
	end)
	f.addCommand({ "ungod" }, { "Removes god from a player.", "Kohl" }, 2, { "player" }, function(pl, args)
		for i, plr in args[1] do
			if plr and plr.Character and FindChild(plr.Character, "Humanoid") then
				while FindChild(plr.Character, "KGod") do
					plr.Character.KGod:Destroy()
				end
				local hum = plr.Character.Humanoid
				wrap(function()
					repeat
						task.wait()
						hum.MaxHealth, hum.Health = 100, 100
					until hum.MaxHealth == 100 and hum.Health == 100
				end)
			end
		end
	end)
	f.addCommand({ "ff", "forcefield" }, { "Gives players a force field.", "Kohl" }, 2, { "player" }, function(pl, args)
		for i, plr in args[1] do
			if plr and plr.Character then
				new("ForceField")({ Parent = plr.Character })
			end
		end
	end)
	f.addCommand(
		{ "unff", "unforcefield", "unffbomb" },
		{ "Removes force fields from players.", "Kohl" },
		2,
		{ "player" },
		function(pl, args)
			for i, plr in args[1] do
				if plr and plr.Character then
					for i2, ff in plr.Character:GetChildren() do
						if ff:IsA("ForceField") then
							ff:Destroy()
						end
					end
				end
			end
		end
	)

	f.addCommand(
		{ "place", "pl" },
		{ "Makes a player teleport places.", "Kohl 1337/PrivetServer" },
		3,
		{ "player", "word" },
		function(pl, args)
			for i, plr in args[1] do
				if plr and f.Auth(pl, plr) then
					if tonumber(args[2]) then
						f.TP(tonumber(args[2]), plr)
					else
						local ok, data = pcall(function()
							GlobalDataStore:GetAsync(dataKey.servers)
						end)
						if not ok then
							f.Hint(pl, "Failed to load reserved servers", pl)
							return
						end
						local server = data[args[2]]
						if server then
							services.Teleport:TeleportToPrivateServer(server.Id, server.Code, args[1])
						else
							f.Hint(pl, "No place with that name found!", pl)
						end
					end
				end
			end
		end
	)
	f.addCommand(
		{ "tp", "teleport", "tele" },
		{ "Teleports a player to a player.", "Kohl me" },
		2,
		{ "player", "player" },
		function(pl, args)
			local to = args[2] and args[2][1]
			for i, plr in args[1] do
				if
					plr
					and plr.Character
					and plr.Character.PrimaryPart
					and to
					and to.Character
					and to.Character.PrimaryPart
				then
					f.Teleport(plr.Character.PrimaryPart, to.Character.PrimaryPart.CFrame)
				end
			end
		end
	)
	f.addCommand({ "to", "goto" }, { "Teleports a you to a player.", "Kohl" }, 2, { "player" }, function(pl, args)
		for i, plr in args[1] do
			if
				plr
				and plr.Character
				and plr.Character.PrimaryPart
				and pl
				and pl.Character
				and pl.Character.PrimaryPart
			then
				f.Teleport(pl.Character.PrimaryPart, plr.Character.PrimaryPart.CFrame)
			end
		end
	end)
	f.addCommand({ "bring" }, { "Teleports a player to you.", "Kohl" }, 2, { "player" }, function(pl, args)
		for i, plr in args[1] do
			if
				plr
				and plr.Character
				and plr.Character.PrimaryPart
				and pl
				and pl.Character
				and pl.Character.PrimaryPart
			then
				f.Teleport(plr.Character.PrimaryPart, pl.Character.PrimaryPart.CFrame)
			end
		end
	end)

	f.addCommand(
		{ "resetstats", "rs" },
		{ "Resets the leaderstats of a player.", "Kohl" },
		2,
		{ "player" },
		function(pl, args)
			for i, plr in args[1] do
				if plr and FindChild(plr, "leaderstats") then
					for i2, v in plr.leaderstats:GetChildren() do
						if not v:IsA("StringValue") then
							v.Value = Instance.new(v.ClassName).Value
						end
					end
				end
			end
		end
	)
	f.addCommand(
		{ "change" },
		{ "Modify a stat of a player.", "Kohl kills 0" },
		2,
		{ "player", "word", "string" },
		function(pl, args)
			local filtered = getFilteredMessage(getTextObject(args[3], pl.UserId), pl.UserId)
			for i, plr in args[1] do
				if plr and FindChild(plr, "leaderstats") then
					for i2, v in plr.leaderstats:GetChildren() do
						if v.Name:lower():find("^" .. args[2]:lower()) then
							if v:IsA("StringValue") then
								v.Value = filtered
							else
								v.Value = tonumber(args[3])
							end
						end
					end
				end
			end
		end
	)
	f.addCommand(
		{ "team", "tm" },
		{ "Modify the team of a player.", "Kohl raiders" },
		2,
		{ "player", "string" },
		function(pl, args)
			local tm
			for i, v in services.Teams:GetChildren() do
				if v.Name:lower():find("^" .. args[2]:lower()) then
					tm = v
				end
			end
			for i, plr in args[1] do
				if plr and plr.Character and tm then
					plr.TeamColor = tm.TeamColor
				end
			end
		end
	)
	f.addCommand(
		{ "randomizeteams", "randomiseteams", "randomteams", "rteams", "rteam", "rt" },
		{ "Randomly places players between two teams.", "all blue red" },
		2,
		{ "player", "word", "word" },
		function(pl, args)
			local tm, t1, t2 = false, nil
			for i, v in game.Teams:GetChildren() do
				if v.Name:lower():find("^" .. args[2]:lower()) then
					t1 = v.TeamColor
				elseif v.Name:lower():find("^" .. args[3]:lower()) then
					t2 = v.TeamColor
				end
			end
			local ntab = {}
			for i, v in args[1] do
				table.insert(ntab, math.ceil(math.random(#ntab + 1)), v)
			end
			for i, plr in ntab do
				if plr and t1 and t2 then
					tm = not tm
					if tm then
						plr.TeamColor = t1
					else
						plr.TeamColor = t2
					end
				end
			end
		end
	)

	f.addCommand({ "music", "audio", "sound" }, { "Plays a sound.", "1337" }, 2, { "number" }, function(pl, args)
		for i, v in services.Workspace:GetChildren() do
			if v.Name == "KMusic" then
				v:Stop()
				v:Destroy()
			end
		end
		services.Content:Preload("rbxassetid://" .. args[1])
		while services.Content.RequestQueueSize > 0 do
			task.wait()
		end
		RemoteEvent:FireAllClients(
			"KPlaySound",
			new("Sound")({
				Parent = services.Workspace,
				Looped = true,
				Name = "KMusic",
				SoundId = "rbxassetid://" .. args[1],
			}) :: Sound
		)
	end)
	f.addCommand(
		{ "togglemusic", "toggleaudio", "togglesound" },
		{ "Mutes sounds from the music command.", "" },
		0,
		{},
		function(pl, args)
			RemoteEvent:FireClient(pl, "KMuteMusic")
		end
	)
	f.addCommand({ "stop", "stopmusic" }, { "Stops a sound." }, 2, {}, function(pl, args)
		for i, v in services.Workspace:GetChildren() do
			if v.Name == "KMusic" then
				v:Stop()
				v:Destroy()
			end
		end
	end)
	f.addCommand({ "play" }, { "Plays a sound." }, 3, {}, function(pl, args)
		for i, v in services.Workspace:GetChildren() do
			if v.Name == "KMusic" then
				v:Play()
			end
		end
	end)
	f.addCommand({ "pause" }, { "Pauses a sound." }, 3, {}, function(pl, args)
		for i, v in services.Workspace:GetChildren() do
			if v.Name == "KMusic" then
				v:Pause()
			end
		end
	end)
	f.addCommand({ "pitch" }, { "Modify the pitch of a sound.", "1337" }, 2, { "number" }, function(pl, args)
		for i, v in services.Workspace:GetChildren() do
			if v.Name == "KMusic" then
				v.Pitch = args[1]
			end
		end
	end)
	f.addCommand({ "volume" }, { "Modify the volume of a sound.", "1337" }, 2, { "number" }, function(pl, args)
		for i, v in services.Workspace:GetChildren() do
			if v.Name == "KMusic" then
				v.Volume = args[1]
			end
		end
	end)

	f.addCommand({ "time", "tod" }, { "Modify the TimeOfDay.", "12:30" }, 2, { "string" }, function(pl, args)
		services.Lighting.TimeOfDay = args[1]
	end)
	f.addCommand({ "brightness", "bright" }, { "Modify the TimeOfDay.", "1" }, 2, { "number" }, function(pl, args)
		services.Lighting.Brightness = args[1]
	end)
	f.addCommand(
		{ "ambient" },
		{ "Modify the Ambient.", "255 255 255" },
		2,
		{ "number", "number", "number" },
		function(pl, args)
			services.Lighting.Ambient = Color3.new(args[1] / 255, args[2] / 255, args[3] / 255)
		end
	)
	f.addCommand(
		{ "outdoorambient" },
		{ "Modify the OutdoorAmbient.", "255 255 255" },
		2,
		{ "number", "number", "number" },
		function(pl, args)
			services.Lighting.OutdoorAmbient = Color3.new(args[1] / 255, args[2] / 255, args[3] / 255)
		end
	)
	f.addCommand(
		{ "fogcolor" },
		{ "Modify the FogColor.", "255 255 255" },
		2,
		{ "number", "number", "number" },
		function(pl, args)
			services.Lighting.FogColor = Color3.new(args[1] / 255, args[2] / 255, args[3] / 255)
		end
	)
	f.addCommand({ "fogend" }, { "Modify the FogEnd.", "1337" }, 2, { "number" }, function(pl, args)
		services.Lighting.FogEnd = args[1]
	end)
	f.addCommand({ "fogstart" }, { "Modify the FogStart.", "1337" }, 2, { "number" }, function(pl, args)
		services.Lighting.FogStart = args[1]
	end)

	f.addCommand({ "winddirection", "winddir" }, { "Orient the wind along your camera." }, 2, {}, function(pl, args)
		RemoteEvent:FireClient(pl, "KCam")
		local connection
		connection = RemoteEvent.OnServerEvent:Connect(function(plr, a, b)
			if plr == pl and a == f.uID .. "KCam" then
				connection:Disconnect()
				setGlobalWind(
					b.LookVector
						* if services.Workspace.GlobalWind.Magnitude > 0
							then services.Workspace.GlobalWind.Magnitude
							else 5
				)
			end
		end)
	end)
	f.addCommand({ "windspeed" }, { "Modify the wind speed." }, 2, { "number" }, function(pl, args)
		setGlobalWind(
			args[1]
				* if services.Workspace.GlobalWind.Magnitude > 0
					then services.Workspace.GlobalWind.Unit
					else -Vector3.xAxis
		)
	end)

	f.addCommand(
		{ "removetools", "rtools" },
		{ "Removes all tools from a player.", "Kohl" },
		2,
		{ "player" },
		function(pl, args)
			for i, plr in args[1] do
				if plr and f.Auth(pl, plr) then
					f.rmvTools(plr)
				end
			end
		end
	)
	f.addCommand(
		{ "removehats", "rhats" },
		{ "Remove a players hats. Optional boolean to remove hats given by the 'hat' command.", "Kohl" },
		1,
		{ "player", "boolean/" },
		function(pl, args)
			for i, plr in args[1] do
				if plr and f.Auth(pl, plr) and plr.Character then
					for i, v in plr.Character:GetChildren() do
						if v:IsA("Accoutrement") and (not args[2] or v.Name == "KHat") then
							v:Destroy()
						end
					end
				end
			end
		end
	)
	f.addCommand({ "removelimbs", "rlimbs" }, { "Remove a players limbs.", "Kohl" }, 2, { "player" }, function(pl, args)
		for i, plr in args[1] do
			if plr and f.Auth(pl, plr) and plr.Character then
				for i, v in plr.Character:GetChildren() do
					if v.Name:find(" Leg") or v.Name:find(" Arm") then
						v:Destroy()
					end
				end
			end
		end
	end)
	f.addCommand({ "removearms", "rarms" }, { "Remove a players arms.", "Kohl" }, 2, { "player" }, function(pl, args)
		for i, plr in args[1] do
			if plr and f.Auth(pl, plr) and plr.Character then
				for i, v in plr.Character:GetChildren() do
					if v.Name:find(" Arm") then
						v:Destroy()
					end
				end
			end
		end
	end)
	f.addCommand({ "removelegs", "rlegs" }, { "Remove a players legs.", "Kohl" }, 2, { "player" }, function(pl, args)
		for i, plr in args[1] do
			if plr and f.Auth(pl, plr) and plr.Character then
				for i, v in plr.Character:GetChildren() do
					if v.Name:find(" Leg") then
						v:Destroy()
					end
				end
			end
		end
	end)

	f.addCommand({ "fly" }, { "Gives a player flight.", "Kohl" }, 2, { "player" }, function(pl, args)
		for i, plr in args[1] do
			if plr and f.Auth(pl, plr) then
				RemoteEvent:FireClient(plr, "KFly", 0)
			end
		end
	end)
	f.addCommand({ "unfly" }, { "Removes a player flight.", "Kohl" }, 2, { "player" }, function(pl, args)
		for i, plr in args[1] do
			if plr and f.Auth(pl, plr) then
				RemoteEvent:FireClient(plr, "KFly")
			end
		end
	end)
	f.addCommand({ "noclip" }, { "Gives a player noclip.", "Kohl" }, 2, { "player" }, function(pl, args)
		for i, plr in args[1] do
			if plr and f.Auth(pl, plr) then
				plr.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam
				RemoteEvent:FireClient(plr, "KNoclip", 0)
			end
		end
	end)
	f.addCommand({ "clip", "unnoclip" }, { "Removes a player noclip.", "Kohl" }, 2, { "player" }, function(pl, args)
		for i, plr in args[1] do
			if plr and f.Auth(pl, plr) then
				plr.DevCameraOcclusionMode = services.StarterPlayer.DevCameraOcclusionMode
				RemoteEvent:FireClient(plr, "KNoclip")
			end
		end
	end)

	f.addCommand(
		{ "link", "connect" },
		{ "Links two players with a line.", "Kohl Kensai" },
		2,
		{ "player", "player" },
		function(pl, args)
			for i, plr in args[1] do
				if plr and plr.Character and FindChild(plr.Character, "Humanoid") then
					for i2, plr2 in args[2] do
						if plr2 and plr2.Character and FindChild(plr2.Character, "HumanoidRootPart") then
							local pt = new("SelectionPartLasso")({
								Parent = plr.Character,
								Color = BrickColor.Random(),
								Name = "KLink",
								Humanoid = plr.Character.Humanoid,
								Part = plr2.Character.HumanoidRootPart,
							})
							wrap(function()
								repeat
									task.wait(0.1)
								until not plr
									or not plr.Character
									or not FindChild(plr.Character, "Humanoid")
									or not pt
									or not pt.Parent
									or not plr2
									or not plr2.Character
									or not FindChild(plr2.Character, "HumanoidRootPart")
								pt:Destroy()
							end)
						end
					end
				end
			end
		end
	)
	f.addCommand(
		{ "unlink", "unconnect" },
		{ "Removes links from a player.", "Kohl" },
		2,
		{ "player" },
		function(pl, args)
			for i, plr in args[1] do
				if plr and plr.Character and FindChild(plr.Character, "KLink") then
					repeat
						plr.Character.KLink:Destroy()
					until not FindChild(plr.Character, "KLink")
				end
			end
		end
	)
	f.addCommand({ "watch", "spectate", "spy" }, { "Watches a player.", "Kohl" }, 2, { "player" }, function(pl, args)
		for i, plr in args[1] do
			if plr and plr.Character then
				RemoteEvent:FireClient(pl, "KWatch", plr.Character)
			end
		end
	end)
	f.addCommand({ "unwatch", "unspectate", "unspy", "camfix" }, { "Unwatches a player." }, 2, {}, function(pl, args)
		RemoteEvent:FireClient(pl, "KWatch")
	end)
	f.addCommand(
		{ "fov", "fieldofview" },
		{ "Changes a player's field of view.", "Kohl 1-120" },
		2,
		{ "player", "number" },
		function(pl, args)
			for i, plr in args[1] do
				if plr then
					RemoteEvent:FireClient(plr, "KFOV", args[2])
				end
			end
		end
	)

	f.addCommand({ "lock" }, { "Locks a player.", "Kohl" }, 2, { "player" }, function(pl, args)
		for i, plr in args[1] do
			if plr and plr.Character and f.Auth(pl, plr) then
				for i2, v in plr.Character:GetChildren() do
					if v:IsA("BasePart") then
						v.Locked = true
					elseif FindChild(v, "Handle") then
						v.Handle.Locked = true
					end
				end
			end
		end
	end)
	f.addCommand({ "unlock" }, { "Unlocks a player.", "Kohl" }, 2, { "player" }, function(pl, args)
		for i, plr in args[1] do
			if plr and plr.Character and f.Auth(pl, plr) then
				for i2, v in plr.Character:GetChildren() do
					if v:IsA("BasePart") then
						v.Locked = false
					elseif FindChild(v, "Handle") then
						v.Handle.Locked = false
					end
				end
			end
		end
	end)
	f.addCommand({ "punish", "oblivion" }, { "Punishes a player.", "Kohl" }, 2, { "player" }, function(pl, args)
		for i, plr in args[1] do
			if plr and plr.Character and FindChild(plr.Character, "HumanoidRootPart") and f.Auth(pl, plr) then
				new("BodyForce")({
					Parent = plr.Character.HumanoidRootPart,
					Name = "KPun",
					force = Vector3.new(0, 9e9, 0),
					new("Vector3Value")({ Name = "OP", Value = plr.Character.HumanoidRootPart.Position }),
				})
			end
		end
	end)
	f.addCommand({ "unpunish", "unoblivion" }, { "Punishes a player.", "Kohl" }, 2, { "player" }, function(pl, args)
		for i, plr in args[1] do
			if plr and plr.Character and FindChild(plr.Character, "HumanoidRootPart") and f.Auth(pl, plr) then
				for i2, v in plr.Character.HumanoidRootPart:GetChildren() do
					if v.Name == "KPun" then
						if FindChild(v, "OP") then
							f.Teleport(plr.Character.HumanoidRootPart, CFrame.new(v.OP.Value))
						end
						v:Destroy()
					end
				end
			end
		end
	end)
	f.addCommand({ "jail", "cage" }, { "Jails a player.", "Kohl" }, 2, { "player" }, function(pl, args)
		for i, plr in args[1] do
			if plr and plr.Character and FindChild(plr.Character, "HumanoidRootPart") and f.Auth(pl, plr) then
				f.rmvTools(plr)
				local j, jv, j1, j2, j3, j4, j5, j6 =
					new("Model")({ Parent = services.Workspace, Name = "KJail " .. plr.DisplayName })
				jv = plr.DisplayName
				table.insert(ClearObjects, j)
				j1 = new("Part")({
					Parent = j,
					Anchored = true,
					BrickColor = BrickColor.new("Really black"),
					Transparency = 0.2,
					TopSurface = 0,
					BottomSurface = 0,
					FormFactor = 3,
					Size = Vector3.new(6, 0.2, 6),
					CFrame = plr.Character.HumanoidRootPart.CFrame * CFrame.new(0, -2.9, 0),
				})
				j2 = j1:Clone()
				j2.Parent = j
				j2.CFrame = j1.CFrame * CFrame.new(0, 7.2, 0)
				j3 = j1:Clone()
				j3.Parent = j
				j3.Size = Vector3.new(6, 7.4, 0.2)
				j3.CFrame = (j1.CFrame * CFrame.new(0, 3.6, 2.9))
				j4 = j3:Clone()
				j4.Parent = j
				j4.CFrame = (j1.CFrame * CFrame.new(0, 3.6, -2.9))
				j5 = j1:Clone()
				j5.Parent = j
				j5.Size = Vector3.new(0.2, 7.4, 6)
				j5.CFrame = (j1.CFrame * CFrame.new(2.9, 3.6, 0))
				j6 = j5:Clone()
				j6.Parent = j
				j6.CFrame = (j1.CFrame * CFrame.new(-2.9, 3.6, 0))
				wrap(function()
					while j and j.Parent == services.Workspace do
						local p = FindChild(game.Players, jv)
						if
							p
							and p.Character
							and FindChild(p.Character, "HumanoidRootPart")
							and (p.Character.HumanoidRootPart.Position - j1.Position).Magnitude > 6
						then
							f.rmvTools(p)
							local HumanoidRootPart: Part = p.Character.HumanoidRootPart
							HumanoidRootPart.CFrame = j1.CFrame * CFrame.new(0, 3, 0)
						end
						task.wait(0.1)
					end
				end)
			end
		end
	end)
	f.addCommand({ "unjail", "uncage" }, { "Unjails a player.", "Kohl" }, 2, { "player" }, function(pl, args)
		for i, plr in args[1] do
			if plr and f.Auth(pl, plr) then
				for i, v in services.Workspace:GetChildren() do
					if v.Name == "KJail " .. plr.DisplayName then
						v:Destroy()
					end
				end
			end
		end
	end)
	f.addCommand({ "lag", "lagify" }, { "Lags a player.", "Kohl" }, 2, { "player" }, function(pl, args)
		for i, plr in args[1] do
			if plr and plr.Character and f.Auth(pl, plr) and not FindChild(plr, "KLag") then
				new("IntValue")({ Parent = plr, Name = "KLag" })
				RemoteEvent:FireClient(plr, "KLag")
			end
		end
	end)
	f.addCommand({ "unlag", "unlagify" }, { "Unlags a player.", "Kohl" }, 2, { "player" }, function(pl, args)
		for i, plr in args[1] do
			if plr and plr.Character and f.Auth(pl, plr) and FindChild(plr, "KLag") then
				plr.KLag:Destroy()
			end
		end
	end)
	f.addCommand({ "freeze" }, { "Freezes a player.", "Kohl" }, 2, { "player" }, function(pl, args)
		for i, plr in args[1] do
			if
				plr
				and plr.Character
				and FindChild(plr.Character, "Humanoid")
				and FindChild(plr.Character, "HumanoidRootPart")
				and f.Auth(pl, plr)
				and not FindChild(plr.Character, "KFreeze")
			then
				plr.Character.Humanoid.WalkSpeed = 0
				for i, v in plr.Character:GetChildren() do
					if v:IsA("BasePart") then
						v.Anchored = true
					end
				end
				(new("Part")({
					Parent = plr.Character,
					Name = "KFreeze",
					Anchored = true,
					TopSurface = 0,
					BottomSurface = 0,
					FormFactor = 3,
					BrickColor = BrickColor.new("Medium blue"),
					Reflectance = 1,
					Material = "Ice",
					Transparency = 0.3,
					Size = Vector3.new(5, 7, 5),
				}) :: Part).CFrame = plr.Character.HumanoidRootPart.CFrame
					+ Vector3.new(0, 0.5, 0)
			end
		end
	end)
	f.addCommand({ "thaw", "unfreeze" }, { "Thaws a player.", "Kohl" }, 2, { "player" }, function(pl, args)
		for i, plr in args[1] do
			if plr and plr.Character and FindChild(plr.Character, "Humanoid") then
				plr.Character.Humanoid.WalkSpeed = 16
				for i, v in plr.Character:GetChildren() do
					if v:IsA("BasePart") then
						v.Anchored = false
					end
				end
				if FindChild(plr.Character, "KFreeze") then
					plr.Character.KFreeze:Destroy()
				end
			end
		end
	end)
	f.addCommand({ "blind" }, { "Blinds players.", "Kohl" }, 2, { "player" }, function(pl, args)
		for i, plr in args[1] do
			if plr and f.Auth(pl, plr) then
				RemoteEvent:FireClient(plr, "KBlind", 0)
			end
		end
	end)
	f.addCommand({ "unblind" }, { "Unblinds players.", "Kohl" }, 2, { "player" }, function(pl, args)
		for i, plr in args[1] do
			if plr and f.Auth(pl, plr) then
				RemoteEvent:FireClient(plr, "KBlind")
			end
		end
	end)

	f.addCommand(
		{ "tshirt" },
		{ "Gives a player a t-shirt.", "Kohl 1337" },
		1,
		{ "player", "number" },
		function(pl, args)
			for i, plr in args[1] do
				if plr and plr.Character and plr.Character.PrimaryPart then
					if FindChild(plr.Character, "Shirt Graphic") then
						plr.Character["Shirt Graphic"].Parent = plr.Character.PrimaryPart
					end
					while FindChild(plr.Character, "KTShirt") do
						plr.Character.KTShirt:Destroy()
					end
					new("ShirtGraphic")({ Parent = plr.Character, Name = "KTShirt", Graphic = getTexture(args[2]) })
				end
			end
		end
	)
	f.addCommand({ "untshirt" }, { "Returns a player's t-shirt.", "Kohl" }, 1, { "player" }, function(pl, args)
		for i, plr in args[1] do
			if plr and plr.Character and plr.Character.PrimaryPart then
				while FindChild(plr.Character, "KTShirt") do
					plr.Character.KTShirt:Destroy()
				end
				if FindChild(plr.Character.PrimaryPart, "Shirt Graphic") then
					plr.Character.PrimaryPart["Shirt Graphic"].Parent = plr.Character
				elseif FindChild(plr.Character.PrimaryPart, "roblox") then
					plr.Character.PrimaryPart.roblox.Texture = ""
				end
			end
		end
	end)
	f.addCommand({ "shirt" }, { "Gives a player a shirt.", "Kohl 1337" }, 1, { "player", "number" }, function(pl, args)
		for i, plr in args[1] do
			if plr and plr.Character and FindChild(plr.Character, "HumanoidRootPart") then
				if FindChild(plr.Character, "Shirt") then
					plr.Character.Shirt.Parent = plr.Character.HumanoidRootPart
				end
				while FindChild(plr.Character, "KShirt") do
					plr.Character.KShirt:Destroy()
				end
				new("Shirt")({ Parent = plr.Character, Name = "KShirt", ShirtTemplate = getTexture(args[2]) })
			end
		end
	end)
	f.addCommand({ "unshirt" }, { "Returns a player's shirt.", "Kohl" }, 1, { "player" }, function(pl, args)
		for i, plr in args[1] do
			if plr and plr.Character and FindChild(plr.Character, "HumanoidRootPart") then
				while FindChild(plr.Character, "KShirt") do
					plr.Character.KShirt:Destroy()
				end
				if FindChild(plr.Character.HumanoidRootPart, "Shirt") then
					plr.Character.HumanoidRootPart.Shirt.Parent = plr.Character
				end
			end
		end
	end)
	f.addCommand({ "pants" }, { "Gives a player pants.", "Kohl 1337" }, 1, { "player", "number" }, function(pl, args)
		for i, plr in args[1] do
			if plr and plr.Character and FindChild(plr.Character, "HumanoidRootPart") then
				if FindChild(plr.Character, "Pants") then
					plr.Character.Pants.Parent = plr.Character.HumanoidRootPart
				end
				while FindChild(plr.Character, "KPants") do
					plr.Character.KPants:Destroy()
				end
				new("Pants")({ Parent = plr.Character, Name = "KPants", PantsTemplate = getTexture(args[2]) })
			end
		end
	end)
	f.addCommand({ "unpants" }, { "Returns a player's pants.", "Kohl" }, 1, { "player" }, function(pl, args)
		for i, plr in args[1] do
			if plr and plr.Character and FindChild(plr.Character, "HumanoidRootPart") then
				while FindChild(plr.Character, "KPants") do
					plr.Character.KPants:Destroy()
				end
				if FindChild(plr.Character.HumanoidRootPart, "Pants") then
					plr.Character.HumanoidRootPart.Pants.Parent = plr.Character
				end
			end
		end
	end)
	f.addCommand({ "face" }, { "Gives a player a face.", "Kohl 1337" }, 1, { "player", "number" }, function(pl, args)
		for i, plr in args[1] do
			if plr and plr.Character and FindChild(plr.Character, "Head") and FindChild(plr.Character, "Humanoid") then
				while FindChild(plr.Character.Head, "KFace") do
					plr.Character.Head.KFace:Destroy()
				end
				if FindChild(plr.Character.Head, "face") then
					plr.Character.Head.face.Transparency = 1
					plr.Character.Head.face.Parent = plr.Character.Humanoid
				end
				new("Decal")({ Parent = plr.Character.Head, Name = "KFace", Texture = getTexture(args[2]) })
			end
		end
	end)
	f.addCommand({ "unface" }, { "Returns a player's face.", "Kohl" }, 1, { "player" }, function(pl, args)
		for i, plr in args[1] do
			if plr and plr.Character and FindChild(plr.Character, "Head") and FindChild(plr.Character, "Humanoid") then
				while FindChild(plr.Character.Head, "KFace") do
					plr.Character.Head.KFace:Destroy()
				end
				if FindChild(plr.Character.Humanoid, "face") then
					plr.Character.Humanoid.face.Parent = plr.Character.Head
					plr.Character.Head.face.Transparency = 0
				end
			end
		end
	end)

	f.addCommand({ "jump" }, { "Jumps a player.", "Kohl" }, 1, { "player" }, function(pl, args)
		for i, plr in args[1] do
			if plr and plr.Character and FindChild(plr.Character, "Humanoid") then
				plr.Character.Humanoid.Jump = true
			end
		end
	end)
	f.addCommand({ "sit" }, { "Sits a player.", "Kohl" }, 2, { "player" }, function(pl, args)
		for i, plr in args[1] do
			if plr and plr.Character and FindChild(plr.Character, "Humanoid") then
				plr.Character.Humanoid.Sit = true
			end
		end
	end)
	f.addCommand({ "unsit" }, { "Unsits a player.", "Kohl" }, 2, { "player" }, function(pl, args)
		for i, plr in args[1] do
			if plr and plr.Character and FindChild(plr.Character, "Humanoid") then
				plr.Character.Humanoid.Sit = false
			end
		end
	end)
	f.addCommand({ "normal" }, { "Returns a player to normal.", "Kohl" }, 1, { "player" }, f.Normal)

	f.addCommand({ "crownrainbow" }, { "Toggles the crown rainbow.", "" }, 1, {}, function(pl, args)
		if pl and DonorCache[pl.UserId] > 3 then
			local value = not pl:GetAttribute("KCrownRainbow")
			pl:SetAttribute("KCrownRainbow", value)
			if pl.Character and pl.Character:FindFirstChild("SuperCrown") then
				if value then
					services.Collection:RemoveTag(pl.Character.SuperCrown, "KAICrown")
					services.Collection:AddTag(pl.Character.SuperCrown, "KAIRCrown")
				else
					services.Collection:RemoveTag(pl.Character.SuperCrown, "KAIRCrown")
					services.Collection:AddTag(pl.Character.SuperCrown, "KAICrown")
					task.defer(function()
						pl.Character.SuperCrown.Handle.Color = pl:GetAttribute("KCrownColor") or Color3.new(1, 1, 1)
						pl.Character.SuperCrown.Handle.Fire.Color = pl:GetAttribute("KCrownFireColor")
							or Color3.new(0, 0, 0)
						pl.Character.SuperCrown.Handle.Fire.SecondaryColor = pl.Character.SuperCrown.Handle.Color
					end)
				end
			end
		end
	end)

	f.addCommand(
		{ "crowncolor" },
		{ "Changes the VIP crown color.", "white black" },
		1,
		{ "color/", "color/" },
		function(pl, args)
			if pl then
				local color1 = args[1] or Color3.new(1, 1, 1)
				local color2 = args[2] or args[1] or Color3.new(0, 0, 0)
				pl:SetAttribute("KCrownRainbow", false)
				pl:SetAttribute("KCrownColor", color1)
				pl:SetAttribute("KCrownFireColor", color2)
				if pl.Character and pl.Character:FindFirstChild("SuperCrown") then
					if services.Collection:HasTag(pl.Character.SuperCrown, "KAIRCrown") then
						services.Collection:RemoveTag(pl.Character.SuperCrown, "KAIRCrown")
						services.Collection:AddTag(pl.Character.SuperCrown, "KAICrown")
					end
					task.defer(function()
						pl.Character.SuperCrown.Handle.Color = color1
						pl.Character.SuperCrown.Handle.Fire.Color = color2
						pl.Character.SuperCrown.Handle.Fire.SecondaryColor = color1
					end)
				end
			end
		end
	)

	-- |||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
	if Set.FunCommands then
		-- |||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||

		f.addCommand({ "clone" }, { "Clones a player.", "Kohl" }, 2, { "player" }, function(pl, args)
			for i, plr in args[1] do
				if plr and plr.Character then
					plr.Character.Archivable = true
					local cl = plr.Character:Clone()
					plr.Character.Archivable = false
					cl.Parent = game.Workspace
					cl:MakeJoints()
					cl:MoveTo(plr.Character:GetModelCFrame().p)
					table.insert(ClearObjects, cl)
				end
			end
		end)
		f.addCommand(
			{ "char", "character" },
			{ "Modify a player's appearance.", "Kohl 261" },
			2,
			{ "player", "number" },
			function(pl, args)
				for i, plr in args[1] do
					if plr and f.Auth(pl, plr) then
						plr.CharacterAppearanceId = args[2]
						plr:LoadCharacter()
					end
				end
			end
		)
		f.addCommand({ "unchar", "uncharacter" }, { "Resets a player's.", "Kohl" }, 2, { "player" }, function(pl, args)
			for i, plr in args[1] do
				if plr and f.Auth(pl, plr) then
					plr.CharacterAppearanceId = plr.UserId
					plr:LoadCharacter()
				end
			end
		end)

		f.addCommand(
			{ "hat", "crmhat" },
			{ "Gives a player a hat with an optional color, reflectance and material.", "Kohl 1337 pink 1 neon" },
			1,
			{ "player", "number", "color/", "number/", "word/" },
			function(pl, args)
				local isVIP = math.abs(f.getPower(pl)) == 1
				for i, plr in args[1] do
					if plr and plr.Character then
						if isVIP then
							local n = 0
							for i, v in plr.Character:GetChildren() do
								if v and v.Name == "KHat" then
									n = n + 1
									if n > 9 then
										plr.Character.KHat:Destroy()
									end
								end
							end
						end

						-- meshpart loading hack for crm neon compatibility
						local accessoryTypes = {
							[8] = "HatAccessory",
							[41] = "HairAccessory",
							[42] = "FaceAccessory",
							[43] = "NeckAccessory",
							[44] = "ShouldersAccessory",
							[45] = "FrontAccessory",
							[46] = "BackAccessory",
							[47] = "WaistAccessory",
						}
						local _ok, info = pcall(services.Marketplace.GetProductInfo, services.Marketplace, args[2])
						local accessoryType = accessoryTypes[info.AssetTypeId]
						local description = Instance.new("HumanoidDescription")
						if accessoryType then
							description[accessoryType] = args[2]
							local model = services.Players:CreateHumanoidModelFromDescription(
								description,
								Enum.HumanoidRigType.R15
							)
							local hat = model:FindFirstChildOfClass("Accessory")

							if hat then
								if isVIP then
									for _, s in hat:GetDescendants() do
										if
											s:IsA("Script")
											or s:IsA("Tool")
											or s:IsA("HopperBin")
											or s:IsA("Model")
											or (s:IsA("BasePart") and s.Name ~= "Handle")
										then
											s:Destroy()
										end
									end
								end
								hat.Name = "KHat"
								if args[3] then
									f.ColorHat(hat, args[3], args[4], args[5])
								end
								hat.Parent = plr.Character
								if isVIP then
									hat.Changed:Once(function()
										if hat then
											hat:Destroy()
										end
									end)
								end
								model:Destroy()
								continue
							end
						end

						-- legacy fallback
						for i, hat in services.Insert:LoadAsset(args[2]):GetChildren() do
							if hat:IsA("Accoutrement") then
								if isVIP then
									for _, s in hat:GetDescendants() do
										if
											s:IsA("Script")
											or s:IsA("Tool")
											or s:IsA("HopperBin")
											or s:IsA("Model")
											or (s:IsA("BasePart") and s.Name ~= "Handle")
										then
											s:Destroy()
										end
									end
								end
								hat.Name = "KHat"
								if args[3] then
									f.ColorHat(hat, args[3], args[4], args[5])
								end
								hat.Parent = plr.Character
								if isVIP then
									hat.Changed:Once(function()
										if hat then
											hat:Destroy()
										end
									end)
								end
							end
						end
					end
				end
			end
		)

		f.addCommand(
			{ "gear" },
			{ "Gives a player a gear.", "Kohl 1337" },
			3,
			{ "player", "number" },
			function(pl, args)
				for i, plr in args[1] do
					if plr and plr.Character then
						for i2, v2 in services.Insert:LoadAsset(args[2]):GetChildren() do
							if v2:IsA("Tool") or v2:IsA("HopperBin") then
								v2.Parent = plr.Character
							end
						end
					end
				end
			end
		)
		f.addCommand(
			{ "insert", "ins" },
			{ "Inserts a model at the player's position.", "1337" },
			3,
			{ "number" },
			function(pl, args)
				local blocked = { 59524079, 59524162, 59524102, 59524044, 59524124, 59524006 }
				if table.find(blocked, tonumber(args[1])) then
					return -- block dispensers
				end
				local imod = services.Insert:LoadAsset(args[1])
				local packageRef = imod:FindFirstChild("packageRef", true)
				if packageRef and packageRef:FindFirstChildOfClass("ObjectValue") then
					imod:Destroy()
					return -- block dev modules
				end
				imod.Parent = game.Workspace
				imod:MoveTo(pl.Character:GetModelCFrame().Position)
				imod:MakeJoints()
				table.insert(ClearObjects, imod)
			end
		)

		f.addCommand({ "disco" }, { "Try it out." }, 2, {}, function(pl, args)
			if FindChild(script, "KLightEF") then
				script.KLightEF:Destroy()
			end
			local d, c = new("StringValue")({ Name = "KLightEF", Parent = script })
			wrap(function()
				repeat
					c = Color3.new(math.random(), math.random(), math.random())
					services.Lighting.Ambient = c
					services.Lighting.FogColor = c
					task.wait(0.1)
				until not d or d.Parent ~= script
			end)
		end)
		--f.addCommand({ "flash" }, { "Try it out." }, 2, {}, function(pl, args)
		--	if FindChild(script, "KLightEF") then
		--		script.KLightEF:Destroy()
		--	end
		--	local d, c = new("StringValue")({ Name = "KLightEF", Parent = script })
		--	wrap(function()
		--		repeat
		--			if services.Lighting.Ambient ~= Color3.new() then
		--				services.Lighting.Brightness = 0
		--				c = Color3.new()
		--			else
		--				services.Lighting.Brightness = 5
		--				c = Color3.new(5, 5, 5)
		--			end
		--			services.Lighting.Ambient = c
		--			services.Lighting.FogColor = c
		--			task.wait(0.1)
		--		until not d or d.Parent ~= script
		--	end)
		--end)
		f.addCommand(
			{ "freaky" },
			{ "SUPER FREAKY.", "255 255 255" },
			2,
			{ "number/", "number/", "number/" },
			function(pl, args)
				services.Lighting.FogColor =
					Color3.new((args[1] or 255) * -4e4, (args[2] or 255) * -4e4, (args[3] or 255) * -4e4)
				services.Lighting.FogEnd = 9e9
			end
		)

		f.addCommand(
			{ "invisible", "inv" },
			{ "Makes a player invisible.", "Kohl" },
			2,
			{ "player" },
			function(pl, args)
				for i, plr in args[1] do
					if plr and plr.Character then
						for i2, v in plr.Character:GetChildren() do
							if v:IsA("BasePart") then
								if FindChild(v, "face") then
									v.face.Parent = plr
								end
								v.Transparency = 1
							elseif FindChild(v, "Handle") and not v:IsA("Tool") then
								v.Handle.Transparency = 1
							elseif FindChild(v, "Head") then
								v.Head.Transparency = 1
							end
						end
					end
				end
			end
		)
		f.addCommand({ "visible", "vis" }, { "Makes a player visible.", "Kohl" }, 2, { "player" }, function(pl, args)
			for i, plr in args[1] do
				if plr and plr.Character then
					if FindChild(plr, "face") then
						plr.face.Parent = plr.Character:FindFirstChild("Head")
					end
					for i2, v in plr.Character:GetChildren() do
						if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then
							v.Transparency = 0
						elseif FindChild(v, "Handle") and not v:IsA("Tool") then
							v.Handle.Transparency = 0
						elseif FindChild(v, "Head") then
							v.Head.Transparency = 0
						end
					end
				end
			end
		end)

		f.addCommand({ "explode", "ex" }, { "Explodes a player.", "Kohl" }, 2, { "player" }, function(pl, args)
			for i, plr in args[1] do
				if plr and plr.Character and FindChild(plr.Character, "HumanoidRootPart") and f.Auth(pl, plr) then
					new("Explosion")({ Position = plr.Character.HumanoidRootPart.Position, Parent = services.Workspace })
				end
			end
		end)
		f.addCommand({ "nuke" }, { "Nukes a player.", "Kohl" }, 3, { "player" }, function(pl, args)
			for _, plr in args[1] do
				if plr and plr.Character and plr.Character.PrimaryPart and f.Auth(pl, plr) then
					local o, p1, p2 = plr.Character.PrimaryPart.CFrame, nil
					p1 = new("Part")({
						Parent = services.Workspace,
						TopSurface = 0,
						BottomSurface = 0,
						Anchored = true,
						CanCollide = false,
						BrickColor = BrickColor.new("New Yeller"),
						Transparency = 0.75,
						FormFactor = 3,
						Size = Vector3.new(1, 1, 1),
						CFrame = o,
					})
					p2 = p1:Clone()
					p2.BrickColor = BrickColor.new("Really red")
					local m1, m2 = new("SpecialMesh")({ Parent = p1, MeshType = "Sphere" })
					m2 = m1:Clone()
					m2.Parent = p2
					table.insert(ClearObjects, p1)
					f.rmv(p1, 15)
					wrap(function()
						local ex
						for i = 1, 333 do
							task.wait()
							i = i * 2
							m1.Scale = Vector3.new(i, i, i)
							if i == 50 then
								p2.Parent = p1
							elseif i > 50 then
								m2.Scale = Vector3.new(i - 50, i - 50, i - 50)
							end
							if not ex then
								new("Explosion")({
									BlastRadius = i,
									BlastPressure = 9001,
									Position = o.p,
									Parent = services.Workspace,
								})
							end
							ex = not ex
						end
						if p1 then
							p1:Destroy()
						end
					end)
				end
			end
		end)
		f.addCommand({ "smite" }, { "Smites a player.", "Kohl" }, 2, { "player" }, function(pl, args)
			for _, plr in args[1] do
				if plr and plr.Character and plr.Character.PrimaryPart and f.Auth(pl, plr) then
					local pp = plr.Character.PrimaryPart.Position - Vector3.new(0, 3, 0)
					local sound =
						new("Sound")({ SoundId = "rbxassetid://178090362", Volume = 1, Parent = services.Workspace })
					local p1, p2, p3, p4, p5
					sound:Play()
					f.rmv(sound, 7)
					sound, p2 = f.CastRay(pp, pp - Vector3.new(0, 9, 0), { plr.Character })
					p1 = new("Part")({
						Transparency = 0.9,
						Parent = services.Workspace,
						Material = "Neon",
						FormFactor = 3,
						BrickColor = BrickColor.new("Institutional white"),
						CanCollide = false,
						Anchored = true,
						Size = Vector3.new(0.2, 0.2, 0.2),
						CFrame = CFrame.new((sound and p2 or pp) + Vector3.new(0, 1e3, 0)),
						new("BlockMesh")({ Scale = Vector3.new(10, 10000, 10) }),
					})
					p2, p3, p4, p5 = p1:Clone(), p1:Clone(), p1:Clone(), p1:Clone()
					for i, p in { p2, p3, p4, p5 } do
						i = i * 0.1
						p.Parent, p.Size = p1, Vector3.new(0.2 + i, 0.2, 0.2 + i)
						p.CFrame = p1.CFrame
					end
					f.rmv(p1, 0.5)
					plr.Character:BreakJoints()
				end
			end
		end)

		f.addCommand({ "creeper" }, { "Creepy..", "Kohl" }, 2, { "player" }, function(pl, args)
			f.Normal(pl, args)
			for i, plr in args[1] do
				if plr and plr.Character and FindChild(plr.Character, "HumanoidRootPart") then
					if FindChild(plr.Character, "Shirt") then
						plr.Character.Shirt.Parent = plr.Character.HumanoidRootPart
					end
					if FindChild(plr.Character, "Pants") then
						plr.Character.Pants.Parent = plr.Character.HumanoidRootPart
					end
					local c, t, cf1, cf2, ca1, ca2 =
						plr.Character,
						plr.Character.Torso,
						CFrame.new(0, -1.5, -0.5),
						CFrame.new(0, -1, 0.5),
						CFrame.Angles(0, math.rad(90), 0),
						CFrame.Angles(0, math.rad(-90), 0)
					wrap(function()
						t.Transparency = 0
						f.LastC0(t)
						t.Neck.C0 = CFrame.new(0, 1, 0) * CFrame.Angles(math.rad(90), math.rad(180), 0)
						t["Right Shoulder"].C0 = cf1 * ca1
						t["Left Shoulder"].C0 = cf1 * ca2
						t["Right Hip"].C0 = cf2 * ca1
						t["Left Hip"].C0 = cf2 * ca2
						f.ColorChar(c, "Bright green")
					end)
				end
			end
		end)
		f.addCommand({ "uncreeper" }, { "Returns a player to normal.", "Kohl" }, 2, { "player" }, f.Normal)
		f.addCommand({ "dog" }, { "Makes a player a dog.", "Kohl" }, 2, { "player" }, function(pl, args)
			f.Normal(pl, args)
			for i, plr in args[1] do
				if plr and plr.Character and FindChild(plr.Character, "HumanoidRootPart") then
					if FindChild(plr.Character, "Shirt") then
						plr.Character.Shirt.Parent = plr.Character.HumanoidRootPart
					end
					if FindChild(plr.Character, "Pants") then
						plr.Character.Pants.Parent = plr.Character.HumanoidRootPart
					end
					local c, t, ca1, ca2 =
						plr.Character,
						plr.Character.Torso,
						CFrame.Angles(0, math.rad(90), 0),
						CFrame.Angles(0, math.rad(-90), 0)
					wrap(function()
						t.Transparency = 1
						f.LastC0(t)
						t.Neck.C0 = CFrame.new(0, -0.5, -2) * CFrame.Angles(math.rad(90), math.rad(180), 0)
						t["Right Shoulder"].C0 = CFrame.new(0.5, -1.5, -1.5) * ca1
						t["Left Shoulder"].C0 = CFrame.new(-0.5, -1.5, -1.5) * ca2
						t["Right Hip"].C0 = CFrame.new(1.5, -1, 1.5) * ca1
						t["Left Hip"].C0 = CFrame.new(-1.5, -1, 1.5) * ca2
						local st = new("Seat")({
							Name = "KTorso",
							FormFactor = 0,
							TopSurface = 0,
							BottomSurface = 0,
							Size = Vector3.new(3, 1, 4),
							new("BodyForce")({ force = Vector3.new(0, 2e3, 0) }),
						})
						st.CFrame = t.CFrame
						st.Parent = c
						new("Weld")({ Parent = st, Part0 = t, Part1 = st, C1 = CFrame.new(0, 0.5, 0) })
						f.ColorChar(c, "Brown")
					end)
				end
			end
		end)
		f.addCommand({ "undog" }, { "Returns a player to normal.", "Kohl" }, 2, { "player" }, f.Normal)

		f.addCommand({ "infect" }, { "Infects a player.", "Kohl" }, 2, { "player" }, f.Infect)
		f.addCommand({ "uninfect" }, { "Returns a player to normal.", "Kohl" }, 2, { "player" }, f.Normal)

		f.addCommand(
			{ "cape" },
			{ "Gives a player a cape.", "Kohl red 1337" },
			1,
			{ "player", "color", "number/" },
			function(pl, args)
				for i, plr in args[1] do
					if plr and plr.Character then
						RemoteEvent:FireAllClients("KCape", { plr.Character, args[2], args[3], 0 })
					end
				end
			end
		)
		f.addCommand({ "uncape" }, { "Removes a player's cape.", "Kohl" }, 1, { "player" }, function(pl, args)
			for i, plr in args[1] do
				if plr then
					RemoteEvent:FireAllClients("KCape", { plr.Character })
				end
			end
		end)

		f.addCommand({ "swagify", "swag" }, { "Swag.", "Kohl" }, 1, { "player" }, function(pl, args)
			for i, plr in args[1] do
				if plr and plr.Character and FindChild(plr.Character, "HumanoidRootPart") then
					if FindChild(plr.Character, "Shirt") then
						plr.Character.Shirt.Parent = plr.Character.HumanoidRootPart
					end
					if FindChild(plr.Character, "Pants") then
						plr.Character.Pants.Parent = plr.Character.HumanoidRootPart
					end
					new("Shirt")({ Name = "KShirt", ShirtTemplate = "rbxassetid://109163376", Parent = plr.Character })
					new("Pants")({ Name = "KPants", PantsTemplate = "rbxassetid://109163376", Parent = plr.Character })
					RemoteEvent:FireAllClients("KCape", { plr.Character, Color3.new(1, 0, 1), 109301474 })
				end
			end
		end)
		f.addCommand(
			{ "unswagify", "unswag" },
			{ "Returns a player to normal.", "Kohl" },
			1,
			{ "player" },
			function(pl, args)
				f.Normal(pl, args)
				for i, plr in args[1] do
					if plr then
						RemoteEvent:FireClient(plr, "KCape")
					end
				end
			end
		)
		f.addCommand({ "goldify", "gold" }, { "Glimmer like gold.", "Kohl" }, 1, { "player" }, function(pl, args)
			for i, plr in args[1] do
				if plr and plr.Character and FindChild(plr.Character, "HumanoidRootPart") then
					if FindChild(plr.Character, "Shirt") then
						plr.Character.Shirt.Parent = plr.Character.HumanoidRootPart
					end
					if FindChild(plr.Character, "Pants") then
						plr.Character.Pants.Parent = plr.Character.HumanoidRootPart
					end
					f.ColorChar(plr.Character, "Gold", true, 0.4)
				end
			end
		end)
		f.addCommand({ "ungoldify", "ungold" }, { "Returns a player to normal.", "Kohl" }, 1, { "player" }, f.Normal)
		f.addCommand({ "shiny", "shine" }, { "Shine like a diamond.", "Kohl" }, 1, { "player" }, function(pl, args)
			for i, plr in args[1] do
				if plr and plr.Character and FindChild(plr.Character, "HumanoidRootPart") then
					if FindChild(plr.Character, "Shirt") then
						plr.Character.Shirt.Parent = plr.Character.HumanoidRootPart
					end
					if FindChild(plr.Character, "Pants") then
						plr.Character.Pants.Parent = plr.Character.HumanoidRootPart
					end
					f.ColorChar(plr.Character, "Institutional white", true, 1)
				end
			end
		end)
		f.addCommand({ "unshiny", "unshine" }, { "Returns a player to normal.", "Kohl" }, 1, { "player" }, f.Normal)
		f.addCommand(
			{ "crm" },
			{ "Changes the color/reflection/material of a player.", "Kohl pink 1 neon" },
			1,
			{ "player", "color/", "number/", "word/" },
			function(pl, args)
				local color, reflectance, material =
					args[2] or Color3.new(1, 1, 1), args[3] or 0, args[4] or "SmoothPlastic"
				for i, plr in args[1] do
					if plr and plr.Character and FindChild(plr.Character, "HumanoidRootPart") then
						if FindChild(plr.Character, "Shirt") then
							plr.Character.Shirt.Parent = plr.Character.HumanoidRootPart
						end
						if FindChild(plr.Character, "Pants") then
							plr.Character.Pants.Parent = plr.Character.HumanoidRootPart
						end
						f.ColorChar(plr.Character, color, true, reflectance, material)
					end
				end
			end
		)
		f.addCommand({ "uncrm" }, { "Returns a player to normal.", "Kohl" }, 1, { "player" }, f.Normal)

		f.addCommand(
			{ "highlight", "hl" },
			{ "Highlights a player.", "Kohl red blue 0.5 0" },
			1,
			{ "player", "color/", "color/", "number/", "number/" },
			function(pl, args)
				for i, plr in args[1] do
					if plr and plr.Character then
						if FindChild(plr.Character, "KHighlight") then
							plr.Character.KHighlight:Destroy()
						end
						new("Highlight")({
							Parent = plr.Character,
							Name = "KHighlight",
							FillColor = args[2] or Color3.new(1, 1, 1),
							FillTransparency = args[4] or 0.5,
							OutlineColor = args[3] or args[2] or Color3.new(1, 1, 1),
							OutlineTransparency = args[5] or args[4] or 0,
							DepthMode = 1,
						})
					end
				end
			end
		)
		f.addCommand(
			{ "unhighlight", "unhl" },
			{ "Removes a KHighlight from a player.", "Kohl" },
			1,
			{ "player" },
			function(pl, args)
				for i, plr in args[1] do
					if plr and plr.Character and FindChild(plr.Character, "KHighlight") then
						plr.Character.KHighlight:Destroy()
					end
				end
			end
		)

		f.addCommand(
			{ "grav", "gravity" },
			{ "Resets a player's gravity.", "Kohl" },
			2,
			{ "player" },
			function(pl, args)
				for i, plr in args[1] do
					if
						plr
						and plr.Character
						and FindChild(plr.Character, "HumanoidRootPart")
						and FindChild(plr.Character.HumanoidRootPart, "KGrav")
					then
						plr.Character.HumanoidRootPart.KGrav:Destroy()
					end
				end
			end
		)
		f.addCommand(
			{ "setgrav", "setgravity", "setg" },
			{ "Sets a player's gravity.", "Kohl 1" },
			2,
			{ "player", "number" },
			function(pl, args)
				for i, plr in args[1] do
					if plr and plr.Character and FindChild(plr.Character, "HumanoidRootPart") then
						if FindChild(plr.Character.HumanoidRootPart, "KGrav") then
							plr.Character.HumanoidRootPart.KGrav:Destroy()
						end
						new("BodyForce")({
							Parent = plr.Character.HumanoidRootPart,
							Name = "KGrav",
							force = Vector3.new(0, f.getMass(plr.Character) * -args[2] * services.Workspace.Gravity, 0),
						})
					end
				end
			end
		)
		f.addCommand({ "nograv", "nog" }, { "Removes a player's gravity.", "Kohl" }, 2, { "player" }, function(pl, args)
			for i, plr in args[1] do
				if plr and plr.Character and FindChild(plr.Character, "HumanoidRootPart") then
					if FindChild(plr.Character.HumanoidRootPart, "KGrav") then
						plr.Character.HumanoidRootPart.KGrav:Destroy()
					end
					new("BodyForce")({
						Parent = plr.Character.HumanoidRootPart,
						Name = "KGrav",
						force = Vector3.new(0, f.getMass(plr.Character) * services.Workspace.Gravity, 0),
					})
				end
			end
		end)
		f.addCommand({ "skydive", "freefall" }, { "Skydives a player.", "Kohl" }, 2, { "player" }, function(pl, args)
			for i, plr in args[1] do
				if plr and plr.Character and plr.Character.PrimaryPart and f.Auth(pl, plr) then
					plr.Character.PrimaryPart.CFrame = plr.Character.PrimaryPart.CFrame + Vector3.new(0, 9e3, 0)
				end
			end
		end)
		f.addCommand({ "trip", "flip" }, { "Trips a player.", "Kohl" }, 2, { "player" }, function(pl, args)
			for i, plr in args[1] do
				if
					plr
					and plr.Character
					and FindChild(plr.Character, "HumanoidRootPart")
					and FindChild(plr.Character, "Humanoid")
					and not plr.Character.Humanoid.Sit
					and f.Auth(pl, plr)
				then
					plr.Character.HumanoidRootPart.CFrame = plr.Character.HumanoidRootPart.CFrame
						* CFrame.Angles(math.rad(180), 0, 0)
				end
			end
		end)
		f.addCommand({ "fling" }, { "Flings a player.", "Kohl" }, 2, { "player" }, function(pl, args)
			for i, plr in args[1] do
				if plr and plr.Character and FindChild(plr.Character, "HumanoidRootPart") and f.Auth(pl, plr) then
					plr.Character.HumanoidRootPart.CFrame = plr.Character.HumanoidRootPart.CFrame
						* CFrame.Angles(math.rad(180), 0, 0)
					f.rmv(
						new("BodyForce")({
							Parent = plr.Character.HumanoidRootPart,
							force = Vector3.new(math.random(-3e4, 3e4), math.random(3e4, 5e4), math.random(-3e4, 3e4)),
						}),
						0.3
					)
				end
			end
		end)
		f.addCommand({ "loopfling" }, { "Loopflings a player.", "Kohl" }, 3, { "player" }, function(pl, args)
			for i, plr in args[1] do
				if plr and plr.Character and FindChild(plr.Character, "HumanoidRootPart") and f.Auth(pl, plr) then
					local t, L =
						plr.Character.HumanoidRootPart,
						new("ObjectValue")({ Parent = script, Name = "Loop", Value = plr })
					table.insert(ClearObjects, L)
					wrap(function()
						repeat
							if t and t.Parent == plr.Character then
								t.CFrame = t.CFrame * CFrame.Angles(math.rad(180), 0, 0)
								f.rmv(
									new("BodyForce")({
										Parent = t,
										force = Vector3.new(
											math.random(-3e4, 3e4),
											math.random(3e4, 5e4),
											math.random(-3e4, 3e4)
										),
									}),
									0.3
								)
								task.wait(2)
							end
						until not L or L.Parent ~= script
					end)
				end
			end
		end)
		f.addCommand({ "unloopfling" }, { "Unloopflings a player.", "Kohl" }, 3, { "player" }, function(pl, args)
			for i, plr in args[1] do
				if plr and plr.Character and f.Auth(pl, plr) then
					for i, v in ClearObjects do
						if v and v.Name == "Loop" and v.Value == plr then
							v:Destroy()
						end
					end
				end
			end
		end)
		f.addCommand({ "stun" }, { "Stuns a player.", "Kohl" }, 2, { "player" }, function(pl, args)
			for i, plr in args[1] do
				if plr and plr.Character and FindChild(plr.Character, "Humanoid") and f.Auth(pl, plr) then
					plr.Character.Humanoid.PlatformStand = true
				end
			end
		end)
		f.addCommand({ "unstun" }, { "Unstuns a player.", "Kohl" }, 2, { "player" }, function(pl, args)
			for i, plr in args[1] do
				if plr and plr.Character and FindChild(plr.Character, "Humanoid") and f.Auth(pl, plr) then
					plr.Character.Humanoid.PlatformStand = false
				end
			end
		end)
		f.addCommand({ "rocket" }, { "Rockets a player.", "Kohl" }, 2, { "player" }, function(pl, args)
			for i, plr in args[1] do
				if plr and plr.Character and FindChild(plr.Character, "HumanoidRootPart") and f.Auth(pl, plr) then
					local pt = new("Part")({
						Parent = plr.Character,
						Size = Vector3.new(1, 6, 1),
						Anchored = false,
						TopSurface = 0,
						BottomSurface = 0,
						new("BodyForce")({ force = Vector3.new(0, 9e3, 0) }),
					})
					new("Weld")({
						Parent = pt,
						Part0 = pt,
						Part1 = plr.Character.HumanoidRootPart,
						C1 = CFrame.new(0, 0, 1),
					})
					wrap(function()
						task.wait(5)
						Instance.new("Explosion", plr.Character).Position = pt.Position
						plr.Character:BreakJoints()
					end)
				end
			end
		end)
		f.addCommand({ "disable" }, { "Disables a player.", "Kohl" }, 2, { "player" }, function(pl, args)
			for i, plr in args[1] do
				if plr and plr.Character and FindChild(plr.Character, "HumanoidRootPart") and f.Auth(pl, plr) then
					plr.Character.HumanoidRootPart:Destroy()
				end
			end
		end)
		f.addCommand(
			{ "seizure", "seize" },
			{ "Gives a player a seizure.", "Kohl" },
			2,
			{ "player" },
			function(pl, args)
				for i, plr in args[1] do
					if
						plr
						and plr.Character
						and FindChild(plr.Character, "HumanoidRootPart")
						and FindChild(plr.Character, "Humanoid")
						and f.Auth(pl, plr)
					then
						local t, h, s = plr.Character.HumanoidRootPart, plr.Character.Humanoid, nil
						t.CFrame = t.CFrame * CFrame.Angles(math.rad(90), 0, 0)
						s = new("IntValue")({ Parent = plr.Character, Name = "KSeizure" })
						wrap(function()
							repeat
								task.wait()
								h.PlatformStand = true
								t.Velocity = Vector3.new(math.random(-10, 10), math.random(-5, 1), math.random(-10, 10))
								t.RotVelocity = Vector3.new(math.random(-5, 5), math.random(-5, 5), math.random(-5, 5))
							until not (s and t and h) or s.Parent ~= plr.Character
							if h then
								h.PlatformStand = false
							end
							if s then
								s:Destroy()
							end
						end)
					end
				end
			end
		)
		f.addCommand(
			{ "unseizure", "unseize" },
			{ "Saves a player from a seizure.", "Kohl" },
			2,
			{ "player" },
			function(pl, args)
				for i, plr in args[1] do
					if plr and plr.Character and FindChild(plr.Character, "KSeizure") and f.Auth(pl, plr) then
						plr.Character.KSeizure:Destroy()
					end
				end
			end
		)

		f.addCommand(
			{ "confuse", "reverse" },
			{ "Reverses a player's walkspeed.", "Kohl" },
			2,
			{ "player" },
			function(pl, args)
				for i, plr in args[1] do
					if plr and plr.Character and FindChild(plr.Character, "Humanoid") then
						plr.Character.Humanoid.WalkSpeed = -plr.Character.Humanoid.WalkSpeed
					end
				end
			end
		)
		f.addCommand(
			{ "unconfuse", "unreverse" },
			{ "Resets a player's walkspeed.", "Kohl" },
			2,
			{ "player" },
			function(pl, args)
				for i, plr in args[1] do
					if plr and plr.Character and FindChild(plr.Character, "Humanoid") then
						plr.Character.Humanoid.WalkSpeed = 16
					end
				end
			end
		)
		f.addCommand({ "spin" }, { "Spins a player.", "Kohl" }, 2, { "player" }, function(pl, args)
			for i, plr in args[1] do
				if plr and plr.Character and FindChild(plr.Character, "HumanoidRootPart") and f.Auth(pl, plr) then
					local bg = new("BodyGyro")({
						Parent = plr.Character.HumanoidRootPart,
						Name = "KSpin",
						maxTorque = Vector3.new(0, math.huge, 0),
						P = 1e5,
						cframe = plr.Character.HumanoidRootPart.CFrame,
					})
					table.insert(ClearObjects, bg)
					wrap(function()
						repeat
							bg.cframe = bg.cframe * CFrame.Angles(0, math.rad(30), 0)
							task.wait()
						until not bg or not bg.Parent
					end)
				end
			end
		end)
		f.addCommand({ "unspin" }, { "Removes spin from a player.", "Kohl" }, 2, { "player" }, function(pl, args)
			for i, plr in args[1] do
				if
					plr
					and plr.Character
					and FindChild(plr.Character, "HumanoidRootPart")
					and FindChild(plr.Character.HumanoidRootPart, "KSpin")
				then
					plr.Character.HumanoidRootPart.KSpin:Destroy()
				end
			end
		end)
		f.addCommand(
			{ "glitch", "g" },
			{ "Makes a player glitch.", "Kohl 5" },
			2,
			{ "player", "number/" },
			function(pl, args)
				for i, plr in args[1] do
					if plr and f.Auth(pl, plr) then
						RemoteEvent:FireClient(plr, "KGlitch", args[2] or 1)
					end
				end
			end
		)
		f.addCommand(
			{ "unglitch", "ung" },
			{ "Makes a player stop glitching.", "Kohl" },
			2,
			{ "player" },
			function(pl, args)
				for i, plr in args[1] do
					if plr and f.Auth(pl, plr) then
						RemoteEvent:FireClient(plr, "KGlitch")
					end
				end
			end
		)
		f.addCommand(
			{ "glitch2", "g2" },
			{ "Makes a player glitch2.", "Kohl 5" },
			2,
			{ "player", "number/" },
			function(pl, args)
				for i, plr in args[1] do
					if plr and f.Auth(pl, plr) then
						RemoteEvent:FireClient(plr, "KGlitch2", args[2] or 1)
					end
				end
			end
		)
		f.addCommand(
			{ "unglitch2", "ung2" },
			{ "Makes a player stop glitch2ing.", "Kohl" },
			2,
			{ "player" },
			function(pl, args)
				for i, plr in args[1] do
					if plr and f.Auth(pl, plr) then
						RemoteEvent:FireClient(plr, "KGlitch2")
					end
				end
			end
		)
		f.addCommand(
			{ "vibrate", "vb" },
			{ "Makes a player vibrate.", "Kohl 5" },
			2,
			{ "player", "number/" },
			function(pl, args)
				for i, plr in args[1] do
					if plr and f.Auth(pl, plr) then
						RemoteEvent:FireClient(plr, "KVibrate", args[2] or 1)
					end
				end
			end
		)
		f.addCommand(
			{ "unvibrate", "unvb" },
			{ "Makes a player stop vibrating.", "Kohl" },
			2,
			{ "player" },
			function(pl, args)
				for i, plr in args[1] do
					if plr and f.Auth(pl, plr) then
						RemoteEvent:FireClient(plr, "KVibrate")
					end
				end
			end
		)

		f.addCommand(
			{ "bighead", "hugehead", "largehead" },
			{ "Gives a player a big head.", "Kohl" },
			1,
			{ "player" },
			function(pl, args)
				for _, plr in args[1] do
					scaleHead(plr and plr.Character, 3)
				end
			end
		)
		f.addCommand(
			{ "minihead", "smallhead", "tinyhead", "littlehead" },
			{ "Gives a player a mini head.", "Kohl" },
			1,
			{ "player" },
			function(pl, args)
				for _, plr in args[1] do
					scaleHead(plr and plr.Character, 0.5)
				end
			end
		)
		f.addCommand(
			{ "normalhead", "unbighead", "unminihead" },
			{ "Gives a player a normal head.", "Kohl" },
			1,
			{ "player" },
			function(pl, args)
				for _, plr in args[1] do
					scaleHead(plr and plr.Character, 1)
				end
			end
		)
		f.addCommand(
			{ "light", "lite", "lamp" },
			{ "Gives a player light.", "Kohl 5 blue" },
			1,
			{ "player", "number/", "color/" },
			function(pl, args)
				local isVIP = f.getPower(pl) == 1
				for i, plr in args[1] do
					if plr and plr.Character and FindChild(plr.Character, "HumanoidRootPart") then
						if FindChild(plr.Character.HumanoidRootPart, "KLight") then
							plr.Character.HumanoidRootPart.KLight:Destroy()
						end
						new("PointLight")({
							Parent = plr.Character.HumanoidRootPart,
							Name = "KLight",
							Range = isVIP and math.min(10, args[2]) or args[2] or 8,
							Color = args[3] or Color3.new(1, 1, 1),
						})
					end
				end
			end
		)
		f.addCommand(
			{ "unlight", "unlite", "unlamp" },
			{ "Removes a player's light.", "Kohl" },
			1,
			{ "player" },
			function(pl, args)
				for i, plr in args[1] do
					if
						plr
						and plr.Character
						and FindChild(plr.Character, "HumanoidRootPart")
						and FindChild(plr.Character.HumanoidRootPart, "KLight")
					then
						plr.Character.HumanoidRootPart.KLight:Destroy()
					end
				end
			end
		)
		f.addCommand(
			{ "fire" },
			{ "Gives a player fire.", "Kohl 5 black white" },
			1,
			{ "player", "number/", "color/", "color/" },
			function(pl, args)
				local isVIP = f.getPower(pl) == 1
				for i, plr in args[1] do
					if plr and plr.Character and FindChild(plr.Character, "HumanoidRootPart") then
						if FindChild(plr.Character.HumanoidRootPart, "KFire") then
							plr.Character.HumanoidRootPart.KFire:Destroy()
						end
						local fire = new("Fire")({
							Parent = plr.Character.HumanoidRootPart,
							Name = "KFire",
							Size = (isVIP and math.min(5, args[2] or 5) or args[2]) or 5,
						})
						if args[3] then
							fire.Color, fire.SecondaryColor = args[3], args[4] or args[3]
						end
					end
				end
			end
		)
		f.addCommand({ "unfire" }, { "Removes a player's fire.", "Kohl" }, 1, { "player" }, function(pl, args)
			for i, plr in args[1] do
				if
					plr
					and plr.Character
					and FindChild(plr.Character, "HumanoidRootPart")
					and FindChild(plr.Character.HumanoidRootPart, "KFire")
				then
					plr.Character.HumanoidRootPart.KFire:Destroy()
				end
			end
		end)
		f.addCommand({ "smoke" }, { "Gives a player smoke.", "Kohl red" }, 1, { "player", "color/" }, function(pl, args)
			for i, plr in args[1] do
				if plr and plr.Character and FindChild(plr.Character, "HumanoidRootPart") then
					if FindChild(plr.Character.HumanoidRootPart, "KSmoke") then
						plr.Character.HumanoidRootPart.KSmoke:Destroy()
					end
					new("Smoke")({
						Parent = plr.Character.HumanoidRootPart,
						Name = "KSmoke",
						Opacity = 0.1,
						RiseVelocity = 0,
						Color = args[2] or Color3.new(1, 1, 1),
					})
				end
			end
		end)
		f.addCommand({ "unsmoke" }, { "Removes a player's smoke.", "Kohl" }, 1, { "player" }, function(pl, args)
			for i, plr in args[1] do
				if
					plr
					and plr.Character
					and FindChild(plr.Character, "HumanoidRootPart")
					and FindChild(plr.Character.HumanoidRootPart, "KSmoke")
				then
					plr.Character.HumanoidRootPart.KSmoke:Destroy()
				end
			end
		end)
		f.addCommand(
			{ "sparkles" },
			{ "Gives a player sparkles.", "Kohl pink" },
			1,
			{ "player", "color/" },
			function(pl, args)
				for i, plr in args[1] do
					if plr and plr.Character and FindChild(plr.Character, "HumanoidRootPart") then
						if FindChild(plr.Character.HumanoidRootPart, "KSpark") then
							plr.Character.HumanoidRootPart.KSpark:Destroy()
						end
						new("Sparkles")({
							Parent = plr.Character.HumanoidRootPart,
							Name = "KSpark",
							SparkleColor = args[2] or Color3.new(1, 1, 1),
						})
					end
				end
			end
		)
		f.addCommand({ "unsparkles" }, { "Removes a player's sparkles.", "Kohl" }, 1, { "player" }, function(pl, args)
			for i, plr in args[1] do
				if
					plr
					and plr.Character
					and FindChild(plr.Character, "HumanoidRootPart")
					and FindChild(plr.Character.HumanoidRootPart, "KSpark")
				then
					plr.Character.HumanoidRootPart.KSpark:Destroy()
				end
			end
		end)
		f.addCommand(
			{ "particle", "pe" },
			{ "Gives a player a particle.", "Kohl 1337 pink" },
			1,
			{ "player", "number/", "color/" },
			function(pl, args)
				local ex = args[2] or args[3]
				local nrml = (pl:GetRankInGroup(451053) or 0) <= 1
				args[2], args[3] = args[2] or nrml and 176111410, args[3] or nrml and Color3.new(1, 1, 1)
				for i, plr in args[1] do
					if plr and plr.Character and FindChild(plr.Character, "HumanoidRootPart") then
						if not ex and FindChild(plr.Character.HumanoidRootPart, "KPe") then
							plr.Character.HumanoidRootPart.KPe:Destroy()
						else
							if FindChild(plr.Character.HumanoidRootPart, "KPe") then
								plr.Character.HumanoidRootPart.KPe:Destroy()
							end
							local pe = f.pePT:Clone()
							if args[3] then
								pe.Color = ColorSequence.new(args[3])
							end
							if args[2] then
								pe.Texture = getTexture(args[2])
							end
							pe.Name, pe.Enabled = "KPe", true
							pe.Parent = plr.Character.HumanoidRootPart
						end
					end
				end
			end
		)
		f.addCommand(
			{ "unparticle", "unpe" },
			{ "Removes a player's particle.", "Kohl" },
			1,
			{ "player" },
			function(pl, args)
				for i, plr in args[1] do
					if
						plr
						and plr.Character
						and FindChild(plr.Character, "HumanoidRootPart")
						and FindChild(plr.Character.HumanoidRootPart, "KPe")
					then
						plr.Character.HumanoidRootPart.KPe:Destroy()
					end
				end
			end
		)

		f.addCommand(
			{ "size", "resize" },
			{ "Resizes a player.", "Kohl 5" },
			2,
			{ "player", "number" },
			function(pl, args)
				for i, plr in args[1] do
					if plr and plr.Character then
						resizeCharacter(plr.Character, math.clamp(args[2], 0.2, 10))
					end
				end
			end
		)
		f.addCommand(
			{ "unsize", "unresize" },
			{ "Resets a player's size.", "Kohl" },
			2,
			{ "player" },
			function(pl, args)
				for i, plr in args[1] do
					if plr and plr.Character then
						resizeCharacter(plr.Character, 1)
					end
				end
			end
		)

		f.addCommand({ "slim" }, { "Slims a player.", "Kohl" }, 2, { "player" }, function(pl, args)
			for i, plr in args[1] do
				if
					plr
					and plr.Character
					and FindChild(plr.Character, "Torso")
					and FindChild(plr.Character, "HumanoidRootPart")
					and f.Auth(pl, plr)
				then
					local ags = { c = plr.Character, t = plr.Character.Torso, r = plr.Character.HumanoidRootPart }
					ags.t.Anchored = true
					ags.t.BottomSurface = 0
					ags.t.TopSurface = 0
					local welds = {}
					for i2, v2 in ags.c:GetChildren() do
						if v2:IsA("BasePart") and v2.Parent.Name ~= "Infinite" then
							v2.Anchored = true
						elseif v2:IsA("ShirtGraphic") then
							v2.Parent = ags.t
						end
					end
					local function size(p)
						for i2, v2 in p:GetChildren() do
							if v2.Parent.Name ~= "Infinite" then
								if
									(v2:IsA("Weld") or v2:IsA("Motor") or v2:IsA("Motor6D"))
									and v2.Part1
									and v2.Part1.Parent.Name ~= "Infinite"
								then
									local p1 = v2.Part1
									p1.Anchored = true
									v2.Part1 = nil
									if p1 ~= FindChild(ags.c, "Head") and p1 ~= ags.t then
										p1.FormFactor = 3
										p1.Size = Vector3.new(p1.Size.X, p1.Size.Y, 0.2)
									elseif p1 ~= ags.t then
										p1.Anchored = true
										for i3, v3 in p1:GetChildren() do
											if v3:IsA("Weld") then
												v3.Part0 = nil
												v3.Part1.Anchored = true
											end
										end
										p1.FormFactor = 3
										p1.Size = Vector3.new(p1.Size.X, p1.Size.Y, 0.2)
										for i3, v3 in p1:GetChildren() do
											if v3:IsA("Weld") then
												v3.Part0 = p1
												v3.Part1.Anchored = false
											end
										end
									end
									if v2.Parent == ags.t then
										p1.BottomSurface = 0
										p1.TopSurface = 0
									end
									p1.Anchored = false
									v2.Part1 = p1
									if v2.Part0 == ags.t then
										table.insert(welds, v2)
										p1.Anchored = true
										v2.Part0 = nil
									end
								elseif v2:IsA("CharacterMesh") then
									local bp = tostring(v2.BodyPart):match("%w+.%w+.(%w+)")
									local msh = Instance.new("SpecialMesh")
									if bp and FindChild(ags.c, bp:sub(1, #bp - 3) .. " " .. bp:sub(#bp - 2)) then
										msh.Parent = FindChild(ags.c, bp:sub(1, #bp - 3) .. " " .. bp:sub(#bp - 2))
									elseif bp and FindChild(ags.c, bp) then
										msh.Parent = FindChild(ags.c, bp)
									end
									if v2.MeshId and v2.MeshId ~= 0 then
										msh.MeshId = "http://www.roblox.com/asset/?id=" .. v2.MeshId
									end
									if v2.BaseTextureId ~= 0 or v2.BaseTextureId ~= "0" then
										msh.TextureId = "http://www.roblox.com/asset/?id=" .. v2.BaseTextureId
									end
									msh.Scale = Vector3.new(msh.Scale.X, msh.Scale.Y, 0.2)
									v2:Destroy()
								elseif v2:IsA("SpecialMesh") and v2.Parent.Name ~= "Head" then
									v2.Scale = Vector3.new(v2.Scale.X, v2.Scale.Y, 0.2)
								end
								size(v2)
							end
						end
					end
					size(ags.c)
					ags.t.FormFactor = 3
					ags.t.Size = Vector3.new(ags.t.Size.X, ags.t.Size.Y, 0.2)
					for i2, v2 in welds do
						v2.Part0 = ags.t
						v2.Part1.Anchored = false
					end
					for i2, v2 in ags.c:GetChildren() do
						if v2:IsA("BasePart") and v2.Parent.Name ~= "Infinite" then
							v2.Anchored = false
						end
					end
					new("Weld")({
						Parent = ags.r,
						Part0 = ags.r,
						Part1 = ags.t,
						C0 = ags.t.Size.Y * 2.5 <= 1.3 and CFrame.new(0, -1.3 + (ags.t.Size.Y * (3 / 2)), 0)
							or CFrame.new(),
					})
				end
			end
		end)

		f.addCommand({ "unslim" }, { "Resets a player's slim.", "Kohl" }, 2, { "player" }, function(pl, args)
			for i, plr in args[1] do
				if
					plr
					and plr.Character
					and FindChild(plr.Character, "Torso")
					and FindChild(plr.Character, "HumanoidRootPart")
					and f.Auth(pl, plr)
				then
					local ags = { c = plr.Character, t = plr.Character.Torso, r = plr.Character.HumanoidRootPart }
					ags.t.Anchored = true
					ags.t.BottomSurface = 0
					ags.t.TopSurface = 0
					local welds = {}
					for i2, v2 in ags.t:GetChildren() do
						if v2:IsA("ShirtGraphic") then
							v2.Parent = ags.c
						end
					end
					for i2, v2 in ags.c:GetChildren() do
						if v2:IsA("BasePart") and v2.Parent.Name ~= "Infinite" then
							v2.Anchored = true
						end
					end
					local function size(p)
						for i2, v2 in p:GetChildren() do
							if v2.Parent.Name ~= "Infinite" then
								if
									(v2:IsA("Weld") or v2:IsA("Motor") or v2:IsA("Motor6D"))
									and v2.Part1
									and v2.Part1.Parent.Name ~= "Infinite"
								then
									local p1 = v2.Part1
									p1.Anchored = true
									v2.Part1 = nil
									if p1 ~= FindChild(ags.c, "Head") and p1 ~= ags.t then
										p1.FormFactor = 3
										p1.Size = Vector3.new(p1.Size.X, p1.Size.Y, 1)
									elseif p1 ~= ags.t then
										p1.Anchored = true
										for i3, v3 in p1:GetChildren() do
											if v3:IsA("Weld") then
												v3.Part0 = nil
												v3.Part1.Anchored = true
											end
										end
										p1.FormFactor = 3
										p1.Size = Vector3.new(p1.Size.X, p1.Size.Y, 1)
										for i3, v3 in p1:GetChildren() do
											if v3:IsA("Weld") then
												v3.Part0 = p1
												v3.Part1.Anchored = false
											end
										end
									end
									if v2.Parent == ags.t then
										p1.BottomSurface = 0
										p1.TopSurface = 0
									end
									p1.Anchored = false
									v2.Part1 = p1
									if v2.Part0 == ags.t then
										table.insert(welds, v2)
										p1.Anchored = true
										v2.Part0 = nil
									end
								elseif v2:IsA("CharacterMesh") then
									local bp = tostring(v2.BodyPart):match("%w+.%w+.(%w+)")
									local msh = Instance.new("SpecialMesh")
									if bp and FindChild(ags.c, bp:sub(1, #bp - 3) .. " " .. bp:sub(#bp - 2)) then
										msh.Parent = FindChild(ags.c, bp:sub(1, #bp - 3) .. " " .. bp:sub(#bp - 2))
									elseif bp and FindChild(ags.c, bp) then
										msh.Parent = FindChild(ags.c, bp)
									end
									if v2.MeshId and v2.MeshId ~= 0 then
										msh.MeshId = "http://www.roblox.com/asset/?id=" .. v2.MeshId
									end
									if v2.BaseTextureId ~= 0 or v2.BaseTextureId ~= "0" then
										msh.TextureId = "http://www.roblox.com/asset/?id=" .. v2.BaseTextureId
									end
									msh.Scale = Vector3.new(msh.Scale.X, msh.Scale.Y, msh.Scale.X)
									v2:Destroy()
								elseif v2:IsA("SpecialMesh") and v2.Parent.Name ~= "Head" then
									v2.Scale = Vector3.new(v2.Scale.X, v2.Scale.Y, v2.Scale.X)
								end
								size(v2)
							end
						end
					end
					size(ags.c)
					ags.t.FormFactor = 3
					ags.t.Size = Vector3.new(ags.t.Size.X, ags.t.Size.Y, 1)
					for i2, v2 in welds do
						v2.Part0 = ags.t
						v2.Part1.Anchored = false
					end
					for i2, v2 in ags.c:GetChildren() do
						if v2:IsA("BasePart") and v2.Parent.Name ~= "Infinite" then
							v2.Anchored = false
						end
					end
					new("Weld")({
						Parent = ags.r,
						Part0 = ags.r,
						Part1 = ags.t,
						C0 = ags.t.Size.Y * 2.5 <= 1.3 and CFrame.new(0, -1.3 + (ags.t.Size.Y * (3 / 2)), 0)
							or CFrame.new(),
					})
				end
			end
		end)
	end
	--@@endcommands
	local perms_blacklist = { credit = true, prefix = true, help = true, faq = true, guide = true, info = true }
	for _, c in state.Commands do
		for i, n in c[1] do
			i = perms_blacklist[n] ~= true and Set.Permissions[n:lower()]
			if i then
				c[3] = i
			end
		end
	end

	local function Override(a)
		for i, v in state.Commands do
			if v[1][1] == a then
				table.remove(state.Commands, i)
			end
		end
	end
	local _fenv = _getenv()
	local b, e = wrap(function()
		for i, v in CUSTOM do
			local nf = v[5]
			if nf then
				setfenv(nf, _fenv)
				Override(v[1][1])
				f.addCommand(v[1], { v[2][1], v[2][2] }, v[3], v[4], nf)
			end
		end
	end)
	if not b then
		print(ScriptName .. " Custom Command Error:\t" .. e)
	end
	banstr.Value = f.AdminS(Bans)
	admstr.Value = f.AdminS(Admins)
	commandsLoading = false
end
LoadCommands()

function _G.KPrintCmds()
	local a = ""
	for i, v in state.Commands do
		a = a .. i .. ". " .. v[1][1] .. " " .. (v[2][2] or "") .. " - " .. v[2][1] .. "\n"
	end
	print(a)
end

return true
