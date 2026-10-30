--[[
	Runs chat commands through TextChatCommands, the chat command path that keeps working with platform-integrated
	chat (PIC). PIC can't be detected from scripts, and with it Player.Chatted never fires and scripts can't read or
	send chat text, so this path is used whether PIC is on or off.
	https://create.roblox.com/docs/chat/platform-integrated-chat

	Every command gets instances whose aliases are the chat prefixes before its name and each of its aliases, two to
	an instance (";kill" with ":kill"), followed by "/kill". Matching is whole-word and ignores case. The matching
	line is hidden from chat and its full text reaches the server, which parses it like the command bar.

	An alias another TextChatCommand already uses, such as Roblox's own "/team" or "/e", is skipped and logged,
	because both commands would run.
]]

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

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

-- the aliases of every TextChatCommand under TextChatService that isn't in `folder`
local function takenAliases(folder: Instance?): { [string]: true }
	local taken = {}
	-- the defaults may not exist yet, they are only left free when the game turns them off
	local ok, createsDefaults = pcall(function()
		return TextChatService.CreateDefaultCommands
	end)
	if not ok or createsDefaults ~= false then
		for _, alias in DEFAULT_ALIASES do
			taken[alias] = true
		end
	end
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

--- Creates the chat commands for every registered command and keeps them in sync, returns the running instance
function ChatCommands.start(_K)
	local self = {
		folder = Instance.new("Folder"),
		instances = {} :: { [string]: { TextChatCommand } },
		aliases = {} :: { [string]: { string } },
		logged = {} :: { [string]: true },
		prefixes = {} :: { string },
		taken = {} :: { [string]: true },
	}
	self.folder.Name = FOLDER_NAME

	local function canPurchase(commandDefinition: any): boolean
		for role, roleData in _K.Data.roles do
			if
				(
					(role == "vip" and _K.Data.settings.vip)
					or (roleData.gamepasses and next(roleData.gamepasses))
					or (roleData.assets and next(roleData.assets))
					or (roleData.subscriptions and next(roleData.subscriptions))
				) and _K.Auth.roleCanUseCommand(role, commandDefinition)
			then
				return true
			end
		end
		return false
	end

	local function onTriggered(source: TextSource, text: string)
		local player = Players:GetPlayerByUserId(source.UserId)
		if not player or _K.Data.settings.chatCommands == false then
			return
		end
		text = _K.Util.String.trim(text)
		-- "/" is only a command prefix when it is configured as one
		local playerPrefix = _K.Data.playerPrefix[player.UserId]
		if
			string.sub(text, 1, 1) == SLASH
			and not table.find(_K.Data.settings.prefix, SLASH)
			and playerPrefix ~= SLASH
		then
			text = (playerPrefix or _K.Data.settings.prefix[1] or ";") .. string.sub(text, 2)
		end

		local word = string.match(text, "^%S+") or ""
		local nextChar = utf8.offset(word, 2) or #word + 1
		local usedPrefix = string.sub(word, 1, nextChar - 1)
		if usedPrefix ~= playerPrefix and not table.find(_K.Data.settings.prefix, usedPrefix) then
			return
		end
		local command = _K.Registry.commands[string.lower(string.sub(word, nextChar))]
		local hasCommand = command ~= nil and _K.Auth.hasCommand(player.UserId, command)
		local allowed = hasCommand or (command ~= nil and canPurchase(command))
		if
			command
			and allowed
			and _K.Data.settings.vip
			and VIP_BUBBLES[string.lower(command.name)]
			and player.Character
		then
			_K.Remote.DisplayBubble:FireAll(player.Character, word)
		end

		local ready = player:GetAttribute("_K_READY") == true
		if ready and hasCommand then
			local commandBarRank = _K.Data.settings.commandBarRank
			if commandBarRank == nil then
				commandBarRank = 0
			end
			if commandBarRank and _K.Auth.getRank(player.UserId) >= commandBarRank then
				local ok, _err, prepared = _K.Process.prepareCommands(_K, player.UserId, text)
				local lastCommand = not ok and prepared and prepared[#prepared]
				if
					lastCommand
					and (lastCommand.argMissing ~= nil or (#lastCommand.array == 2 and lastCommand.array[2][2] == ""))
				then
					_K.Remote.Command:Fire(player, text, true)
					return
				end
			end
		end

		local ok = _K.Process.runCommands(_K, player.UserId, text)
		-- the client runs its own part of the commands, opens windows and prompts purchases
		if ready and (ok or allowed) then
			_K.Remote.Command:Fire(player, text, true)
		end
	end

	local function sync(key: string, groups: { { string } })
		local list = self.instances[key] or {}
		self.instances[key] = list
		local enabled = _K.Data.settings.chatCommands ~= false
		local aliases = {}
		for i, group in groups do
			local instance = list[i]
			local reparent = false
			if not instance then
				instance = Instance.new("TextChatCommand")
				instance.Name = if i == 1 then key else `{key}{i}`
				instance.AutocompleteVisible = false
				local _ = instance.Triggered:Connect(onTriggered)
				list[i] = instance
				reparent = true
			elseif instance.PrimaryAlias ~= group[1] then
				instance.Parent = nil
				reparent = true
			end
			instance.PrimaryAlias = group[1]
			instance.SecondaryAlias = group[2] or ""
			instance.Enabled = enabled
			if reparent then
				instance.Parent = self.folder
			end
			table.move(group, 1, #group, #aliases + 1, aliases)
		end
		for i = #list, #groups + 1, -1 do
			list[i]:Destroy()
			list[i] = nil
		end
		self.aliases[key] = aliases
		if #list == 0 then
			self.instances[key] = nil
		end
	end

	local function logSkipped(skipped: { string })
		local new = {}
		for _, alias in skipped do
			if not self.logged[alias] then
				self.logged[alias] = true
				table.insert(new, alias)
			end
		end
		if #new > 0 then
			task.spawn(
				_K.log,
				`Skipped chat command aliases used by other TextChatCommands: {table.concat(new, ", ")}`,
				"INFO"
			)
		end
	end

	local scheduled = false

	--- Updates the instances of one command
	function self.refreshCommand(definition: any, batchSkipped: { string }?)
		local groups, skipped = ChatCommands.aliasGroups(definition, self.prefixes, self.taken)
		sync(string.lower(definition.name), groups)
		if batchSkipped then
			table.move(skipped, 1, #skipped, #batchSkipped + 1, batchSkipped)
		else
			logSkipped(skipped)
		end
	end

	--- Rereads the prefixes, settings and other TextChatCommands' aliases and updates every command
	function self.refresh()
		scheduled = false
		local rawPrefixes = table.clone(_K.Data.settings.prefix)
		for _, prefix in _K.Data.playerPrefix do
			table.insert(rawPrefixes, prefix)
		end
		self.prefixes = _K.Chat.commandPrefixes(rawPrefixes)
		self.taken = takenAliases(self.folder)
		local current, skipped = {}, {}
		for _, definition in _K.Registry.commandsList do
			current[string.lower(definition.name)] = true
			self.refreshCommand(definition, skipped)
		end
		for key in self.instances do
			if not current[key] then
				sync(key, {})
			end
		end
		logSkipped(skipped)
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

	local watched: { [Instance]: { RBXScriptConnection } } = {}
	local function watch(descendant: Instance)
		if descendant:IsA("TextChatCommand") and not descendant:IsDescendantOf(self.folder) then
			watched[descendant] = {
				descendant:GetPropertyChangedSignal("PrimaryAlias"):Connect(self.schedule),
				descendant:GetPropertyChangedSignal("SecondaryAlias"):Connect(self.schedule),
			}
			self.schedule()
		end
	end
	local _ = TextChatService.DescendantAdded:Connect(watch)
	local _ = TextChatService.DescendantRemoving:Connect(function(descendant)
		local connections = watched[descendant]
		if connections then
			watched[descendant] = nil
			for _, connection in connections do
				connection:Disconnect()
			end
			self.schedule()
		end
	end)
	for _, descendant in TextChatService:GetDescendants() do
		watch(descendant)
	end

	local _ = _K.Hook.commandRegistered:Connect(self.schedule)
	-- saved settings load and sync from other servers
	local _ = _K.Hook.postSyncMain:Connect(self.schedule)

	self.refresh()
	self.folder.Parent = TextChatService
	return self
end

return ChatCommands
