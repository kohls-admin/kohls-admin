--[[
	Runs chat commands through TextChatCommands, the chat command path that keeps working with platform-integrated
	chat (PIC). PIC can't be detected from scripts, and with it Player.Chatted never fires and scripts can't read or
	send chat text, so this path is used whether PIC is on or off.
	https://create.roblox.com/docs/chat/platform-integrated-chat

	Every command gets instances whose aliases are the chat prefixes before its name and each of its aliases, two to
	an instance (";kill" with ":kill"), followed by "/kill". Matching is whole-word and ignores case. Its full text
	reaches the server, which parses it like the command bar, while the client re-sends non-"/" lines to chat.

	An alias another TextChatCommand already uses, such as Roblox's own "/team" or "/e", is skipped and logged,
	because both commands would run.
]]

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local Shared = if script.Parent:FindFirstChild("Shared") and script.Parent.Shared.Value
	then script.Parent.Shared.Value
	else script.Parent.Parent:WaitForChild("Shared")
local Table = require(Shared:WaitForChild("Util"):WaitForChild("Table") :: ModuleScript)

local FOLDER_NAME = "TextChatCommands_KA"
local SLASH = "/"
-- Roblox's default commands, reserved even before TextChatService creates them
local DEFAULT_ALIASES = {
	"/console",
	"/help",
	"/?",
	"/mute",
	"/m",
	"/unmute",
	"/um",
	"/version",
	"/v",
	"/emote",
	"/e",
	"/team",
	"/t",
	"/whisper",
	"/w",
	"/clear",
	"/cls",
}
-- these show their alias above the speaker's head, it advertises the VIP chat commands
local VIP_BUBBLES = {
	headless = true,
	korblox = true,
	vampire = true,
	werewolf = true,
	cape = true,
	fire = true,
	light = true,
	particle = true,
	trail = true,
	shine = true,
}

local ChatCommands = {
	DEFAULT_ALIASES = DEFAULT_ALIASES,
	FOLDER_NAME = FOLDER_NAME,
}

--[=[
	Returns the alias pairs of a command's instances and the aliases skipped because they are in `taken`. Aliases are
	lowercase: the first untaken "/" alias comes first (so the command's first instance has a "/" PrimaryAlias that
	ExperienceChat can show in autocomplete), followed by each prefix before the name and aliases, then any remaining
	"/" aliases unless "/" is already a prefix.
]=]
function ChatCommands.aliasGroups(
	definition: any,
	prefixes: { string },
	taken: { [string]: any }
): ({ { string } }, { string })
	local words = { string.lower(definition.name) }
	for _, alias in definition.aliases or {} do
		table.insert(words, string.lower(alias))
	end

	local aliases, skipped = {}, {}
	local function add(alias: string)
		if taken[alias] then
			if not table.find(skipped, alias) then
				table.insert(skipped, alias)
			end
		elseif not table.find(aliases, alias) then
			table.insert(aliases, alias)
		end
	end
	if not table.find(prefixes, SLASH) then
		for _, word in words do
			if word ~= "" and not string.find(word, "%s") and not taken[SLASH .. word] then
				add(SLASH .. word)
				break
			end
		end
	end
	for _, word in words do
		-- a word with a space could never match, chat matches the first word
		if word ~= "" and not string.find(word, "%s") then
			for _, prefix in prefixes do
				add(prefix .. word)
			end
		end
	end
	if not table.find(prefixes, SLASH) then
		for _, word in words do
			if word ~= "" and not string.find(word, "%s") then
				add(SLASH .. word)
			end
		end
	end

	local groups = {}
	for i = 1, #aliases, 2 do
		table.insert(groups, { aliases[i], aliases[i + 1] })
	end
	return groups, skipped
end

local DEFAULT_ALIASES_MAP = Table.toHashMap(DEFAULT_ALIASES)

-- the aliases of every TextChatCommand under TextChatService that isn't in `folder`
local function takenAliases(folder: Instance?): { [string]: true }
	-- the defaults may not exist yet, they are only left free when the game turns them off
	local ok, createsDefaults = pcall(function()
		return TextChatService.CreateDefaultCommands
	end)
	local taken = if not ok or createsDefaults ~= false then table.clone(DEFAULT_ALIASES_MAP) else {}
	for _, descendant in TextChatService:GetDescendants() do
		if descendant:IsA("TextChatCommand") and not (folder and descendant:IsDescendantOf(folder)) then
			for _, alias in { descendant.PrimaryAlias, descendant.SecondaryAlias } do
				if alias ~= "" then
					taken[string.lower(alias)] = true
				end
			end
		end
	end
	return taken
end

local function handleTriggered(_K: any, source: TextSource, text: string)
	local player = Players:GetPlayerByUserId(source.UserId)
	if not player or _K.Data.settings.chatCommands == false then
		return
	end
	text = _K.Util.String.trim(text)
	local isSlash = string.sub(text, 1, 1) == SLASH
	-- "/" is only a command prefix when it is configured as one
	local playerPrefix = _K.Data.playerPrefix[player.UserId]
	if isSlash and not table.find(_K.Data.settings.prefix, SLASH) and playerPrefix ~= SLASH then
		text = (playerPrefix or _K.Data.settings.prefix[1] or ";") .. string.sub(text, 2)
	end

	local word = string.match(text, "^%S+") or ""
	local nextChar = utf8.offset(word, 2) or #word + 1
	local usedPrefix = string.sub(word, 1, nextChar - 1)
	if usedPrefix ~= playerPrefix and not table.find(_K.Data.settings.prefix, usedPrefix) then
		return
	end
	local onCooldown = _K.Process.onCooldown(_K, player.UserId)
	local cmdName = string.lower(string.sub(word, nextChar))
	local command = not onCooldown and _K.Registry.commands[cmdName]
	local hasCommand = command and _K.Auth.hasCommand(player.UserId, command)
	local allowed = hasCommand or (command ~= nil and _K.VIP.canPurchaseCommand(command))
	if
		isSlash
		and command
		and allowed
		and _K.Data.settings.vip
		and VIP_BUBBLES[string.lower(command.name)]
		and player.Character
	then
		_K.Remote.DisplayBubble:FireAll(player.Character, (_K.Data.settings.prefix[1] or ";") .. cmdName)
	end

	local ready = player:GetAttribute("_K_READY") == true
	if ready and hasCommand then
		local commandBarRank = _K.Data.settings.commandBarRank
		if commandBarRank == nil then
			commandBarRank = 0
		end
		if commandBarRank and _K.Auth.getRank(player.UserId) >= commandBarRank then
			local ok, _err, prepared = _K.Process.prepareCommands(_K, player.UserId, text, nil, true)
			local lastCommand = not ok and prepared and prepared[#prepared]
			if
				lastCommand
				and (lastCommand.argMissing ~= nil or (#lastCommand.array == 2 and lastCommand.array[2][2] == ""))
			then
				_K.Process.countCommand(_K, player.UserId, #prepared)
				_K.Remote.Command:Fire(player, text, true)
				return
			end
		end
	end

	if not hasCommand and allowed then
		_K.Process.countCommand(_K, player.UserId)
		if ready and not onCooldown then
			_K.Remote.Command:Fire(player, text, true)
		end
		return
	end

	local ok = _K.Process.runCommands(_K, player.UserId, text)
	-- the client runs its own part of the commands, opens windows and prompts purchases
	if ready and not onCooldown and ok then
		_K.Remote.Command:Fire(player, text, true)
	end
end

local function flattenGroups(groups: { { string } }): { string }
	local aliases = {}
	for _, group in groups do
		Table.mergeList(aliases, group)
	end
	return aliases
end

local function syncInstances(self: any, key: string, groups: { { string } })
	local list = self.instances[key] or {}
	self.instances[key] = list
	local enabled = self._K.Data.settings.chatCommands ~= false
	for i, group in groups do
		local instance = list[i]
		local reparent = false
		local secondaryAlias = group[2] or ""
		if not instance then
			instance = Instance.new("TextChatCommand")
			instance.Name = if i == 1 then key else `{key}{i}`
			instance.AutocompleteVisible = false
			local _ = instance.Triggered:Connect(self.onTriggered)
			list[i] = instance
			reparent = true
		elseif instance.PrimaryAlias ~= group[1] or instance.SecondaryAlias ~= secondaryAlias then
			instance.Parent = nil
			reparent = true
		end
		instance.PrimaryAlias = group[1]
		instance.SecondaryAlias = secondaryAlias
		instance.Enabled = enabled
		if reparent then
			instance.Parent = self.folder
		end
	end
	for i = #list, #groups + 1, -1 do
		list[i]:Destroy()
		list[i] = nil
	end
	if #list == 0 then
		self.instances[key] = nil
	end
end

local function logSkipped(self: any, skipped: { string })
	local new = {}
	for _, alias in skipped do
		if not self.logged[alias] then
			self.logged[alias] = true
			table.insert(new, alias)
		end
	end
	if #new > 0 then
		task.spawn(
			self._K.log,
			`Skipped chat command aliases used by other TextChatCommands: {table.concat(new, ", ")}`,
			"INFO"
		)
	end
end

local function watchExternalCommands(folder: Instance, schedule: () -> ()): () -> ()
	local watched: { [Instance]: { RBXScriptConnection } } = {}
	local function watch(descendant: Instance)
		if descendant:IsA("TextChatCommand") and not watched[descendant] and not descendant:IsDescendantOf(folder) then
			watched[descendant] = {
				descendant:GetPropertyChangedSignal("PrimaryAlias"):Connect(schedule),
				descendant:GetPropertyChangedSignal("SecondaryAlias"):Connect(schedule),
			}
			schedule()
		end
	end
	local addedConn = TextChatService.DescendantAdded:Connect(watch)
	local removingConn = TextChatService.DescendantRemoving:Connect(function(descendant)
		local connections = watched[descendant]
		if connections then
			watched[descendant] = nil
			for _, connection in connections do
				connection:Disconnect()
			end
			schedule()
		end
	end)
	for _, descendant in TextChatService:GetDescendants() do
		watch(descendant)
	end
	return function()
		addedConn:Disconnect()
		removingConn:Disconnect()
		for _, connections in watched do
			for _, connection in connections do
				connection:Disconnect()
			end
		end
		table.clear(watched)
	end
end

--- Creates the chat commands for every registered command and keeps them in sync, returns the running instance
function ChatCommands.start(_K)
	local self = {
		_K = _K,
		folder = Instance.new("Folder"),
		instances = {} :: { [string]: { TextChatCommand } },
		playerInstances = {} :: { [string]: { [string]: { TextChatCommand } } },
		playerConnections = {} :: { [string]: { [string]: { RBXScriptConnection } } },
		aliases = {} :: { [string]: { string } },
		logged = {} :: { [string]: true },
		prefixes = {} :: { string },
		taken = {} :: { [string]: true },
		onTriggered = function(source: TextSource, text: string)
			handleTriggered(_K, source, text)
		end,
	}
	self.folder.Name = FOLDER_NAME

	local scheduled = false

	local function destroyPlayerCommand(prefix: string, key: string)
		local conns = self.playerConnections[prefix]
		if conns and conns[key] then
			for _, conn in conns[key] do
				conn:Disconnect()
			end
			conns[key] = nil
		end
		local bucket = self.playerInstances[prefix]
		if bucket and bucket[key] then
			for _, instance in bucket[key] do
				instance:Destroy()
			end
			bucket[key] = nil
		end
	end

	local function destroyPlayerBucket(prefix: string)
		local conns = self.playerConnections[prefix]
		if conns then
			for _, keyConns in conns do
				for _, conn in keyConns do
					conn:Disconnect()
				end
			end
			self.playerConnections[prefix] = nil
		end
		local bucket = self.playerInstances[prefix]
		if bucket then
			for _, instances in bucket do
				for _, instance in instances do
					instance:Destroy()
				end
			end
			self.playerInstances[prefix] = nil
		end
	end

	local function syncPlayerCommand(prefix: string, definition: any, skipped: { string })
		local key = string.lower(definition.name)
		local candidates = { key }
		for _, alias in definition.aliases or {} do
			table.insert(candidates, string.lower(alias))
		end

		local words = {}
		for _, word in candidates do
			if word ~= "" and not string.find(word, "%s") then
				local fullAlias = prefix .. word
				if self.taken[fullAlias] then
					if not table.find(skipped, fullAlias) then
						table.insert(skipped, fullAlias)
					end
				elseif not table.find(words, word) then
					table.insert(words, word)
				end
			end
		end

		if not words[1] then
			destroyPlayerCommand(prefix, key)
			return
		end

		local bucket = self.playerInstances[prefix]
		if not bucket then
			bucket = {}
			self.playerInstances[prefix] = bucket
		end
		local conns = self.playerConnections[prefix]
		if not conns then
			conns = {}
			self.playerConnections[prefix] = conns
		end

		local instances = bucket[key]
		if not instances then
			instances = {}
			bucket[key] = instances
		end
		local keyConns = conns[key]
		if not keyConns then
			keyConns = {}
			conns[key] = keyConns
		end

		local enabled = self._K.Data.settings.chatCommands ~= false
		local codepoint = utf8.codepoint(prefix)
		local pairIndex = 0
		for i = 1, #words, 2 do
			pairIndex += 1
			local primaryAlias = prefix .. words[i]
			local secondary = words[i + 1]
			local secondaryAlias = if secondary then prefix .. secondary else ""
			local instance = instances[pairIndex]
			local reparent = false

			if not instance then
				instance = Instance.new("TextChatCommand")
				instance.Name = if pairIndex == 1
					then string.format("_KPlayer_%d_%s", codepoint, key)
					else string.format("_KPlayer_%d_%s_%d", codepoint, key, pairIndex)
				instance.AutocompleteVisible = false
				instance:SetAttribute("PlayerPrefix", prefix)
				keyConns[pairIndex] = instance.Triggered:Connect(self.onTriggered)
				instances[pairIndex] = instance
				reparent = true
			elseif instance.PrimaryAlias ~= primaryAlias or instance.SecondaryAlias ~= secondaryAlias then
				instance.Parent = nil
				reparent = true
			end

			instance:SetAttribute("PlayerPrefix", prefix)
			instance.PrimaryAlias = primaryAlias
			instance.SecondaryAlias = secondaryAlias
			instance.Enabled = enabled
			if reparent then
				instance.Parent = self.folder
			end
		end

		for i = #instances, pairIndex + 1, -1 do
			if keyConns[i] then
				keyConns[i]:Disconnect()
				keyConns[i] = nil
			end
			instances[i]:Destroy()
			instances[i] = nil
		end
	end

	local leaving: { [Player]: true } = setmetatable({}, { __mode = "k" }) :: any

	local function getConnectedPlayers(): { Player }
		local connected = {}
		for _, player in Players:GetPlayers() do
			if not leaving[player] then
				table.insert(connected, player)
			end
		end
		return connected
	end

	local function collectActivePlayerPrefixes(players: { Player }): { [string]: { Player } }
		local active: { [string]: { Player } } = {}
		for _, player in players do
			local prefix = _K.Data.playerPrefix[player.UserId]
			if
				type(prefix) == "string"
				and prefix ~= SLASH
				and not table.find(self.prefixes, prefix)
				and #_K.Chat.commandPrefixes({ prefix }) == 1
			then
				local bucket = active[prefix]
				if not bucket then
					bucket = {}
					active[prefix] = bucket
				end
				table.insert(bucket, player)
			end
		end
		return active
	end

	local function isCommandActiveGlobal(definition: any, players: { Player }): boolean
		if _K.VIP.canPurchaseCommand(definition) then
			return true
		end
		if #players == 0 then
			return _K.Auth.roleCanUseCommand("everyone", definition)
		end
		for _, player in players do
			if _K.Auth.hasCommand(player.UserId, definition) then
				return true
			end
		end
		return false
	end

	local function isCommandActiveForPrefix(definition: any, prefixPlayers: { Player }): boolean
		if _K.VIP.canPurchaseCommand(definition) then
			return true
		end
		for _, player in prefixPlayers do
			if _K.Auth.hasCommand(player.UserId, definition) then
				return true
			end
		end
		return false
	end

	--- Updates the instances of one command
	function self.refreshCommand(definition: any, batchSkipped: { string }?)
		local key = string.lower(definition.name)
		local players = getConnectedPlayers()
		local activePlayerPrefixes = collectActivePlayerPrefixes(players)
		for prefix in self.playerInstances do
			if not activePlayerPrefixes[prefix] then
				destroyPlayerBucket(prefix)
			end
		end

		local groups, skipped = ChatCommands.aliasGroups(definition, self.prefixes, self.taken)
		self.aliases[key] = flattenGroups(groups)
		if isCommandActiveGlobal(definition, players) then
			syncInstances(self, key, groups)
		else
			syncInstances(self, key, {})
		end
		for prefix, prefixPlayers in activePlayerPrefixes do
			if isCommandActiveForPrefix(definition, prefixPlayers) then
				syncPlayerCommand(prefix, definition, skipped)
			else
				destroyPlayerCommand(prefix, key)
			end
		end
		if batchSkipped then
			Table.mergeList(batchSkipped, skipped)
		else
			logSkipped(self, skipped)
		end
	end

	--- Rereads the prefixes, settings and other TextChatCommands' aliases and updates every command
	function self.refresh()
		scheduled = false
		self.prefixes = _K.Chat.commandPrefixes(_K.Data.settings.prefix)
		self.taken = takenAliases(self.folder)
		local players = getConnectedPlayers()
		local activePlayerPrefixes = collectActivePlayerPrefixes(players)
		for prefix in self.playerInstances do
			if not activePlayerPrefixes[prefix] then
				destroyPlayerBucket(prefix)
			end
		end

		local current, skipped = {}, {}
		for _, definition in _K.Registry.commandsList do
			local key = string.lower(definition.name)
			current[key] = true
			local groups, cmdSkipped = ChatCommands.aliasGroups(definition, self.prefixes, self.taken)
			self.aliases[key] = flattenGroups(groups)
			if isCommandActiveGlobal(definition, players) then
				syncInstances(self, key, groups)
			else
				syncInstances(self, key, {})
			end
			Table.mergeList(skipped, cmdSkipped)
			for prefix, prefixPlayers in activePlayerPrefixes do
				if isCommandActiveForPrefix(definition, prefixPlayers) then
					syncPlayerCommand(prefix, definition, skipped)
				else
					destroyPlayerCommand(prefix, key)
				end
			end
		end
		for key in self.instances do
			if not current[key] then
				syncInstances(self, key, {})
			end
		end
		for key in self.aliases do
			if not current[key] then
				self.aliases[key] = {}
			end
		end
		for prefix, bucket in self.playerInstances do
			for key in bucket do
				if not current[key] then
					destroyPlayerCommand(prefix, key)
				end
			end
			if next(bucket) == nil then
				destroyPlayerBucket(prefix)
			end
		end
		logSkipped(self, skipped)
	end

	function self.resync(_self: any?)
		self.schedule()
	end

	--- The first chat alias of a command name or alias, e.g. ";kill", or nil when it has none
	function self.alias(name: string): string?
		local word = string.lower(name)
		local command = _K.Registry.commands[word]
		local aliases = command and self.aliases[string.lower(command.name)]
		if not aliases then
			return nil
		end
		for _, prefix in self.prefixes do
			if table.find(aliases, prefix .. word) then
				return prefix .. word
			end
		end
		return if table.find(aliases, SLASH .. word) then SLASH .. word else nil
	end

	-- batch refreshes, registering many commands or adding another game's commands fires many times
	function self.schedule()
		if not scheduled then
			scheduled = true
			task.defer(function()
				if scheduled then
					self.refresh()
				end
			end)
		end
	end

	local playerAddedConn = Players.PlayerAdded:Connect(function()
		self.schedule()
	end)
	local playerRemovingConn = Players.PlayerRemoving:Connect(function(leavingPlayer)
		leaving[leavingPlayer] = true
		local prefix = _K.Data.playerPrefix[leavingPlayer.UserId]
		_K.Data.playerPrefix[leavingPlayer.UserId] = nil
		if type(prefix) == "string" and self.playerInstances[prefix] then
			local stillUsed = false
			for _, other in Players:GetPlayers() do
				if other ~= leavingPlayer and _K.Data.playerPrefix[other.UserId] == prefix then
					stillUsed = true
					break
				end
			end
			if not stillUsed then
				destroyPlayerBucket(prefix)
			end
		end
		self.schedule()
	end)

	local disconnectExternal = watchExternalCommands(self.folder, self.schedule)
	local cmdRegisteredConn = _K.Hook.commandRegistered:Connect(self.schedule)
	-- saved settings load and sync from other servers
	local postSyncMainConn = _K.Hook.postSyncMain:Connect(self.schedule)
	local roleAddedConn = _K.Hook.roleAdded:Connect(self.schedule)
	local roleRemovedConn = _K.Hook.roleRemoved:Connect(self.schedule)
	local authChangedConn = _K.Hook.authChanged:Connect(self.schedule)

	local _ = self.folder.Destroying:Once(function()
		scheduled = false
		disconnectExternal()
		playerAddedConn:Disconnect()
		playerRemovingConn:Disconnect()
		cmdRegisteredConn:Disconnect()
		postSyncMainConn:Disconnect()
		roleAddedConn:Disconnect()
		roleRemovedConn:Disconnect()
		authChangedConn:Disconnect()
	end)

	self.refresh()
	self.folder.Parent = TextChatService
	return self
end

return ChatCommands
