return function(_K)
	local Package = _K.script

	local Shared = Package.Shared

	Package:SetAttribute("ServerStartTime", workspace:GetServerTimeNow())

	local Client = Package:WaitForChild("Client")
	local Server = _K.Server
	local Util = _K.Util

	local characterCleanup = {}

	local function characterRemoving(character: Model)
		_K.Flux.cleanup(characterCleanup[character])
		characterCleanup[character] = nil
		task.defer(game.Destroy, character)
	end

	local function characterAdded(character: Model)
		local cleanup = {}
		characterCleanup[character] = cleanup
		local player = _K.Service.Players:GetPlayerFromCharacter(character)
		local humanoid = character:FindFirstChildOfClass("Humanoid")

		-- damage logs
		local alive, lastHealth = true, humanoid.Health
		local damageBatch = {}
		local function logDamage(from)
			local damage = damageBatch[from]
			damageBatch[from] = nil
			if not damage then
				return
			end
			damage = math.round(damage)
			if from and from ~= game then
				_K.log(`damaged {player} for {damage} damage.`, "DAMAGE", from.UserId)
			else
				_K.log(`{player} took {damage} damage.`, "DAMAGE", player.UserId)
			end
		end
		local logDamageDebounce = _K.Util.Function.debounce(1, logDamage)
		table.insert(
			cleanup,
			humanoid.HealthChanged:Connect(function(health)
				if alive then
					local tag = humanoid:FindFirstChild("creator")
					local from = (tag and tag.Value) or game
					local damage = lastHealth - health
					lastHealth = health
					if damage > 0 and health >= 0 then
						damageBatch[from] = (damageBatch[from] or 0) + damage
						logDamageDebounce(from)
					end
				end
			end)
		)

		-- kill logs
		table.insert(
			cleanup,
			humanoid.Died:Connect(function()
				alive = false
				local tag = humanoid:FindFirstChild("creator")
				local from = tag and tag.Value
				for attacker in damageBatch do
					logDamage(attacker)
				end
				if from then
					_K.log(`died to {from}.`, "DEATH", player.UserId)
					if typeof(from) == "Instance" and from:IsA("Player") then
						_K.log(`killed {player}.`, "KILL", from.UserId)
					end
				else
					_K.log(`died.`, "DEATH", player.UserId)
				end
			end)
		)
	end

	local function awardBadge(userId: number, badgeId: number)
		local ok, result = _K.Util.Retry(_K.Service.Badge.GetBadgeInfoAsync, 5, 2, _K.Service.Badge, badgeId)
		if ok and result.IsEnabled then
			_K.Util.Retry(_K.Service.Badge.AwardBadge, 5, 2, _K.Service.Badge, userId, badgeId)
		end
	end

	local _initialized
	function _K.initialize(config: Configuration | ModuleScript | { [string]: any }, oldAddonStructure: Folder?)
		if _initialized then
			return _K
		end
		_initialized = true
		local initStart = os.clock()
		_K.LoadScript = require(Server.LoadScript)

		local settings: { [string]: any } = {}
		if typeof(config) == "Instance" then
			if config:IsA("ModuleScript") then
				settings = require(config)
			elseif config:IsA("Configuration") then
				config.Parent = Package
				local addons = config:FindFirstChild("Addons")
				addons.Parent = Server
				local settingsModule = config:FindFirstChild("Settings")
				if settingsModule and settingsModule:IsA("ModuleScript") then
					settings = require(settingsModule)
				end
				local studioThemes = config:FindFirstChild("Themes")
				if studioThemes then
					Client.UI.Theme.Themes:ClearAllChildren()
					for _, child in studioThemes:GetChildren() do
						child.Parent = Client.UI.Theme.Themes
					end
				end
			end
		elseif type(config) == "table" then
			settings = config
		end

		_K.Data.settingsModuleData = settings

		if type(settings.prefix) == "string" then
			settings.prefix = { settings.prefix }
		end

		-- format array role hierarchy
		do
			if settings.roles.default then
				settings.roles.everyone = settings.roles.default
				settings.roles.default = nil
			end
			local roles = {}
			for rank, definition in settings.roles do
				if definition.permissions.targetOthers == nil then
					definition.permissions.targetOthers = not definition.onlyTargetSelf
				end
				if type(rank) == "number" then
					if definition._key == "default" then
						definition._key = "everyone"
					end
					settings.roles[rank] = nil
					definition._rank = rank - 1
					roles[definition._key] = definition
				else
					definition._key = rank
				end
			end
			Util.Table.merge(settings.roles, roles)
		end

		_K.Data.bans = table.clone(settings.bans)
		_K.Data.roles = table.clone(settings.roles)

		_K.Data.Migrate.Settings(settings)

		local ignoredSettings = {
			bans = true,
			userRoles = true,
			assetRoles = true,
			gamepassRoles = true,
			subscriptionRoles = true,
			groupRoles = true,
			friendRoles = true,
			commands = true,
			roles = true,
		}
		for _, data in { _K.Data.settings, settings } do
			for key, value in data do
				if not ignoredSettings[key] then
					_K.Data.defaultSettings[key] = value
					_K.Data.savedSettings[key] = if type(value) == "table" then table.clone(value) else value
				end
			end
		end
		_K.Data.settings = _K.Data.savedSettings :: any

		for role, roleData in _K.Data.roles do
			table.insert(_K.Data.rolesList, roleData)
		end
		table.sort(_K.Data.rolesList, function(a, b)
			return a._rank < b._rank
		end)

		task.spawn(function() -- populate ban names
			for userId, ban in _K.Data.bans do
				if not ban[1] then
					ban[1] = Util.getUserInfo(userId).Username
				end
			end
		end)

		if settings.commands then
			for role, commands in settings.commands do
				local roleData = _K.Data.roles[role]
				if roleData then
					if roleData.commands then
						_K.Util.Table.merge(roleData.commands, commands)
					else
						roleData.commands = commands
					end
				end
			end
		end

		task.spawn(function()
			repeat
				task.wait()
			until _K.creatorId

			_K.Data.SEPARATE_DATASTORE = _K.Data.IS_PRIVATE_SERVER and game.PrivateServerOwnerId ~= _K.creatorId

			local dataStoreScope = "_K_0.1" -- WARN: REQUIRES DATA MIGRATION WHEN CHANGED
			if _K.Data.SEPARATE_DATASTORE then
				for role, users in settings.userRoles do
					if table.find(users, game.PrivateServerOwnerId) then
						dataStoreScope ..= game.PrivateServerOwnerId
						break
					end
				end
			end

			_K.Data.initialize(dataStoreScope)

			if _K.Data.settings.vip then
				local VIP_UGC_ID = "110019084552349"
				local VIP_UGC_SALE_ID = "115444443724463"

				for _, cmd in _K.Registry.commandsList do
					if cmd.group ~= "VIP" then
						continue
					end

					local chatCommand = Instance.new("TextChatCommand")
					chatCommand.Enabled = true
					chatCommand.AutocompleteVisible = true
					chatCommand.PrimaryAlias = "/" .. cmd.name
					if cmd.aliases and cmd.aliases[1] then
						chatCommand.SecondaryAlias = "/" .. cmd.aliases[1]
					end
					chatCommand.Parent = _K.Service.TextChat

					chatCommand.Triggered:Connect(function(source: TextSource, rawText: string)
						local player = _K.Service.Players:GetPlayerByUserId(source.UserId)
						if not player then
							return
						end

						if (player:GetAttribute("_KDonationLevel") or 0) > 0 then
							local cmd = `{_K.getCommandPrefix()}{string.sub(rawText, 2)}`
							_K.Process.runCommands(_K, source.UserId, cmd)
							return
						end

						local initialJoin = player:GetAttribute("_KInitialJoin") or 0
						local id = if workspace:GetServerTimeNow() - initialJoin > 15 * 60
							then VIP_UGC_ID
							else VIP_UGC_SALE_ID

						local items = { { Type = Enum.MarketplaceProductType.AvatarAsset, Id = id } }
						_K.Service.Marketplace:PromptBulkPurchase(player, items, {})
					end)
				end
			end
		end)

		-- define user roles
		for role, users in settings.userRoles do
			for _, user in users do
				task.spawn(function()
					local userId
					if type(user) == "string" then
						local ok, result = _K.Util.Retry(function()
							return _K.Service.Players:GetUserIdFromNameAsync(user)
						end)
						if ok then
							userId = result
						end
					elseif (tonumber(user) or 0) > 0 then
						userId = tonumber(user)
					end
					if userId then
						task.spawn(_K.Auth.userRoleAdd, userId, role)
					end
				end)
			end
		end

		function _K.setupPurchasables(purchasables, key)
			for id, roles in purchasables do
				for _, role in roles do
					local roleData = _K.Data.roles[role]
					if roleData then
						roleData[key] = roleData[key] or {}
						table.insert(roleData[key], id)
					end
				end
			end
		end

		if settings.assetRoles then
			Util.Table.deepMerge(_K.Data.async.asset, settings.assetRoles, true)
			_K.setupPurchasables(settings.assetRoles, "assets")
		end
		if settings.gamepassRoles then
			Util.Table.deepMerge(_K.Data.async.gamepass, settings.gamepassRoles, true)
			_K.setupPurchasables(settings.gamepassRoles, "gamepasses")
		end
		if settings.subscriptionRoles then
			Util.Table.deepMerge(_K.Data.async.subscription, settings.subscriptionRoles, true)
			_K.setupPurchasables(settings.subscriptionRoles, "subscriptions")
		end

		if settings.groupRoles then
			_K.Util.Table.deepMerge(_K.Data.async.group, settings.groupRoles, true)
		end

		if settings.friendRoles and #settings.friendRoles > 0 then
			task.spawn(function()
				local friendPages = _K.Service.Players:GetFriendsAsync(_K.creatorId)
				for item, _pageNo in Util.iterPageItems(friendPages) do
					if item.Id then
						for _, role in settings.friendRoles do
							_K.Auth.userRoleAdd(item.Id, role)
						end
					end
				end
			end)
		end

		for role, roleData in _K.Data.roles do
			for _, key in { "asset", "gamepass", "subscription" } do
				local id = roleData[key]
				if id then
					local listKey = key .. if string.find(key, "s$", 1, true) then "es" else "s"
					roleData[listKey] = roleData[listKey] or {}
					table.insert(roleData[listKey], id)

					if not _K.Data.async[key][id] then
						_K.Data.async[key][id] = { role }
					else
						table.insert(_K.Data.async[key][id], role)
					end
				end
			end
		end

		_K.Service.Marketplace.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, purchaseSuccess)
			if not purchaseSuccess then
				return
			end
			_K.log(`bought gamepass {gamePassId}`, "PURCHASE", player.UserId)
			for id, roles in _K.Data.async.gamepass do
				if gamePassId ~= id then
					continue
				end
				local rolesAdded = {}
				for _, role in roles do
					local roleAdded = _K.Auth.userRoleAdd(player.UserId, role)
					if roleAdded then
						local roleData = _K.Data.roles[role]
						table.insert(rolesAdded, `<b><font color="{roleData.color}">{roleData.name}</font></b>`)
					end
				end

				if player and #rolesAdded > 0 then
					local prefix = _K.getCommandPrefix(player.UserId)
					_K.Remote.Notify:FireClient(player, {
						Text = `You got the {table.concat(rolesAdded, ", ")} role{if #rolesAdded > 1 then "s" else ""}!\nSay <b>{prefix}cmds</b> or <b>{prefix}info</b> for details.`,
						From = "_K",
					})
				end
			end
		end)

		-- addons
		local serverAddons = Instance.new("Folder", _K.Service.ServerStorage)
		serverAddons.Name = "_KServerAddons"

		local sharedAddons = Instance.new("Folder", Package)
		sharedAddons.Name = "Addons"

		local function loadAddons(list)
			for _, object in list do
				if object:IsA("ModuleScript") then
					if string.find(object.Name, "Server", 1, true) then
						object.Parent = serverAddons
						task.spawn(function()
							require(object)(_K)
						end)
					elseif not string.find(object.Name, "Client", 1, true) then
						object.Parent = sharedAddons
						task.spawn(function()
							require(object)(_K)
						end)
					else
						object.Parent = sharedAddons
					end
				else
					loadAddons(object:GetChildren())
				end
			end
		end

		loadAddons(Shared.DefaultAddons:GetChildren())
		loadAddons(_K.Service.Collection:GetTagged(_K._addonTag))
		if oldAddonStructure and not oldAddonStructure:HasTag(_K._addonTag) then
			loadAddons(oldAddonStructure:GetChildren())
		end

		Package.Name = "Kohl's Admin Source"
		Package.Parent = _K.Service.ReplicatedStorage

		local attributeSchema = { Platform = "string", SessionStart = "number" }

		-- server network events
		local lastLog, cachedLogsBuffer
		_K.Remote.Init.OnServerEvent:Connect(function(player, initData)
			local attributes = initData.Attributes
			if attributes then
				for attribute, valueType in attributeSchema do
					local value = attributes[attribute]
					if typeof(value) == valueType then
						player:SetAttribute("_K" .. attribute, value)
					end
				end
			end

			local logs
			if _K.Auth.hasPermission(player.UserId, "serverlogs") then
				if lastLog ~= _K.Data.logs[#_K.Data.logs] or not cachedLogsBuffer then
					lastLog = _K.Data.logs[#_K.Data.logs]
					local err
					cachedLogsBuffer, err = _K.Z.ser(_K.Data.Schema.logs, _K.Data.logs)
					if not cachedLogsBuffer then
						warn("Failed to serialize logs:", err)
					end
				end
				logs = cachedLogsBuffer
			end

			local bans = _K.Auth.hasCommand(player.UserId, "ban") and _K.Data.bans
			local members = if _K.Auth.hasCommand(player.UserId, "members")
				then _K.Data.members
				else {
					[tostring(player.UserId)] = _K.Data.members[tostring(player.UserId)],
				}
			local roles = _K.Data.roles
			local servers = (
				_K.Auth.hasCommand(player.UserId, "place") or _K.Auth.hasCommand(player.UserId, "unreserve")
			) and _K.Data.reservedServers
			local savedSettings = _K.Data.savedSettings
			local defaultSettings = _K.Data.defaultSettings

			_K.Remote.Init:FireClient(player, bans, logs, members, roles, servers, savedSettings, defaultSettings)
			player:SetAttribute("_K_READY", true)

			if
				settings.vip
				and settings.addToCharts
				and not _K.Service.Http.HttpEnabled
				and _K.Auth.hasPermission(player.UserId, "settings")
			then
				task.delay(4, function()
					_K.Remote.Notify:FireClient(player, {
						From = "_K",
						Text = `Your game is unable to participate in the <b>Kohl's Admin Games Hub</b> because <b><font color='#{_K.Data.settings.themeInvalid:ToHex()}'>HTTP Requests are disabled in your game settings</font></b>.\n\n<i><font transparency='0.5'>Enable HTTP Requests in your Roblox game settings to avoid missing out on free advertising and other benefits!</font></i>`,
						Sound = "Call_Leave",
					})
				end)
			end
		end)

		-- enable client
		Client.Enabled = true

		_K.Remote.Command.OnServerEvent:Connect(function(player: Player, message: string)
			_K.Process.runCommands(_K, player.UserId, message)
		end)

		-- handle custom command prefix
		_K.Remote.PlayerPrefix.OnServerEvent:Connect(function(player, prefix)
			_K.Data.playerPrefix[player.UserId] = prefix
		end)

		-- handle changing of settings
		_K.Remote.Settings.OnServerEvent:Connect(function(player, changes)
			local themeAuthority = _K.Data.settings.changeThemeAuthority
			--TODO: make the Client authority save each players' theming

			if not _K.Auth.hasPermission(player.UserId, "settings") then
				return
			end

			local changeStrings = {}
			for key, value in changes do
				if _K.Data.savedSettings[key] == nil then
					continue
				end

				if string.find(key, "theme", 1, true) and themeAuthority == "Studio" then
					continue
				end

				_K.Data.savedSettings[key] = value
				table.insert(changeStrings, `[{key}]: {value}`)

				local cacheValue, valueType = value, typeof(value)
				if valueType == "Color3" then
					cacheValue = { "color", value.R, value.G, value.B }
				elseif valueType == "EnumItem" then
					cacheValue = { "enum", tostring(value.EnumType), value.Name }
				elseif valueType == "UDim" then
					cacheValue = { "udim", value.Scale, value.Offset }
				elseif valueType == "Font" then
					cacheValue = value.Family
				end

				_K.Data.Sync.settings[key] = cacheValue
			end

			for _, toPlayer in _K.Service.Players:GetPlayers() do
				if toPlayer ~= player then
					_K.Remote.Settings:FireClient(toPlayer, changes)
				end
			end

			_K.Data.settings = if _K.Data.savedSettings.useSavedSettings
				then _K.Data.savedSettings
				else _K.Data.defaultSettings

			_K.log(`changed settings: {table.concat(changeStrings, " ")}`, "COMMAND", player.UserId)
		end)

		-- handle ban events
		_K.Remote.Ban.OnServerEvent:Connect(function(player: Player, userId: number, reason: string?, duration: number?)
			local canBan = _K.Auth.hasCommand(player.UserId, "ban")
			if not (tonumber(userId) and canBan) then
				return
			end

			local fauxArg = {
				_K = _K,
				definition = _K.Registry.commands.ban.args[1],
				command = {
					from = player.UserId,
					fromRank = _K.Auth.getRank(player.UserId),
					fromRole = {},
					rank = canBan or 0,
				},
			}

			if _K.Auth.targetUserArgument(fauxArg, userId, userId) then
				if
					not _K.Auth.hasPermission(player.UserId, "banasync") or not _K.Auth.hasRestrictedRole(player.UserId)
				then
					duration = 0
				end
				_K.log(`{_K.getCommandPrefix()}ban {userId} {duration} {reason}`, "COMMAND", player.UserId)
				_K.Auth.banUsers({ userId }, reason, duration, player.UserId)
			end
		end)

		_K.Remote.Unban.OnServerEvent:Connect(function(player: Player, userId: number)
			local ban = _K.Data.bans[tostring(userId)]
			if ban and _K.Auth.hasCommand(player.UserId, "unban") then
				_K.log(`{_K.getCommandPrefix()}unban {userId}`, "COMMAND", player.UserId)
				_K.Auth.unbanUsers({ userId }, player.UserId, true)
			end
		end)

		_K.Remote.Idled.OnServerEvent:Connect(function(player: Player, idleTime: number)
			if type(idleTime) == "number" then
				player:SetAttribute("_KIdleTime", idleTime)
			end
		end)

		local initialJoin = {}
		local playerCleanup = {}

		_K.Util.SafePlayerAdded(function(player: Player)
			local initialJoinTime = initialJoin[player.UserId]
			if not initialJoinTime then
				initialJoinTime = workspace:GetServerTimeNow()
				initialJoin[player.UserId] = initialJoinTime
			end
			player:SetAttribute("_KInitialJoin", initialJoinTime)

			if (_K.Data.settings.welcomeBadgeId or 0) > 0 then
				task.spawn(awardBadge, player.UserId, _K.Data.settings.welcomeBadgeId)
			end

			task.spawn(_K.log, "joined the server.", "JOIN", player.UserId)

			local cleanup = {}
			playerCleanup[player.UserId] = cleanup
			table.insert(cleanup, player.CharacterAdded:Connect(characterAdded))
			table.insert(cleanup, player.CharacterRemoving:Connect(characterRemoving))
			table.insert(
				cleanup,
				player.Chatted:Connect(function(message: string)
					local emote = string.find(message, "/e", 1, true) == 1
					if not emote then
						task.spawn(_K.log, _K.Util.String.unescapeRichText(message), "CHAT", player.UserId, true)
					end
					local v = _K.Service.TextChat.ChatVersion
					if
						_K.Data.settings.chatCommands ~= false
						and (
							(v == Enum.ChatVersion.TextChatService and emote)
							or v == Enum.ChatVersion.LegacyChatService
						)
					then
						_K.Remote.Command:FireClient(player, message)
					end
				end)
			)

			if player.Character then
				task.spawn(characterAdded, player.Character)
			end

			local warning = tick() + 10
			while not _K.Data.roles do
				task.wait()
				if tick() > warning then
					warn("Unexpected yield while waiting for _K.Data.roles")
					warning = math.huge
				end
			end

			if _K.Auth.banHandler(player) then
				return
			end

			-- group admin and gamepass roles
			_K.Auth.userAsyncRoles(player.UserId, true)
			player:SetAttribute("_KRolesLoaded", true)

			if _K._serverLock and not _K.Auth.hasRestrictedRole(player.UserId) then
				player:Kick(`Server has been locked by {_K._serverLock}`)
				return
			end
		end)

		_K.Service.Players.PlayerRemoving:Connect(function(player)
			local userId = player.UserId

			task.spawn(_K.log, "left the server.", "LEAVE", player.UserId)

			_K.Flux.cleanup(playerCleanup[userId])
			playerCleanup[userId] = nil
		end)

		task.spawn(_K.log, `Initialized in {math.round((os.clock() - initStart) * 1000)} ms`, "DEBUG")
		_K.ready = true
		_K.Hook.init:Fire()

		return _K
	end
end
