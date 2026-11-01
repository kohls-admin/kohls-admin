return function(_K)
	local Package = _K.script

	local Shared = Package.Shared

	Package:SetAttribute("ServerStartTime", workspace:GetServerTimeNow())

	local Client = Package:WaitForChild("Client")
	local Server = _K.Server
	local Util = _K.Util

	local SharedReference = Instance.new("ObjectValue")
	SharedReference.Name = "Shared"
	SharedReference.Value = Shared
	SharedReference.Parent = Server

	local Servers = require(script.Servers)
	local ServersSubscribers = Servers.Subscribers

	_K.Data.servers = Servers.Map

	if Util.Service.Run:IsClient() then
		error("Cannot load server-side code on the client")
	end

	local characterCleanup = {}

	local function characterRemoving(character: Model)
		_K.Flux.dispose(characterCleanup[character])
		characterCleanup[character] = nil
		task.defer(game.Destroy, character)
	end

	local function characterAdded(character: Model)
		local cleanup = {}
		characterCleanup[character] = cleanup
		local player = _K.Service.Players:GetPlayerFromCharacter(character)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not (player and humanoid) then
			return -- custom characters can spawn without a humanoid
		end

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
			-- creator tags can point at any instance, only players have a UserId
			if typeof(from) == "Instance" and from:IsA("Player") then
				_K.log(`damaged {player} for {damage} damage.`, "DAMAGE", from.UserId)
			else
				_K.log(`{player} took {damage} damage.`, "DAMAGE", player.UserId)
			end
		end
		local logDamageDebounce = _K.Util.Function.debounce(1, logDamage)
		local healthConn = humanoid.HealthChanged:Connect(function(health)
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
		table.insert(cleanup, healthConn)

		-- kill logs
		local diedConn = humanoid.Died:Connect(function()
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
		table.insert(cleanup, diedConn)
	end

	local function awardBadge(userId: number, badgeId: number)
		local ok, result = _K.Util.Retry(function()
			return _K.Service.Badge:GetBadgeInfoAsync(badgeId)
		end)
		if ok and result.IsEnabled then
			_K.Util.Retry(function()
				if not _K.Service.Badge:UserHasBadgeAsync(userId, badgeId) then
					_K.Service.Badge:AwardBadge(userId, badgeId)
				end
			end)
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
		_K.Data.settings = _K.Data.savedSettings

		for role, roleData in _K.Data.roles do
			if not table.find(_K.Data.rolesList, roleData) then
				table.insert(_K.Data.rolesList, roleData)
			end
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

			if _K.Data.canSave == false then
				for _, player in _K.Service.Players:GetPlayers() do
					if player:GetAttribute("_K_READY") then
						task.spawn(_K.alert, player, `<b>DataStores failed to load!\n{_K.Data.saveError}</b>`, true)
					end
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

		if type(settings.groupRoles) == "table" then
			local defaultRoles = { "vip", "mod", "admin", "superadmin", "creator" }
			local group = {}
			for groupId, rules in settings.groupRoles do
				if type(rules) ~= "table" then
					continue
				end
				if rules.rank ~= nil or rules.roles ~= nil then
					rules = { rules }
				end
				local definition = {}
				for k, rule in rules do
					if type(rule) == "table" then
						local rank = tonumber(rule.rank)
						local roles = if type(rule.roles) == "string"
							then { rule.roles }
							elseif type(rule.roles) == "table" then rule.roles
							else nil
						if rank and roles then
							table.insert(definition, { rank = rank, roles = roles, exactRank = rule.exactRank })
						end
					elseif tonumber(k) then
						local roleId = if type(rule) == "string"
							then rule
							elseif tonumber(rule) then defaultRoles[math.clamp(
								math.abs(tonumber(rule) :: number),
								1,
								5
							)]
							else nil
						if roleId and _K.Data.roles[roleId] then
							table.insert(definition, { rank = tonumber(k) :: number, roles = { roleId } })
						end
					end
				end
				group[groupId] = definition
			end
			_K.Util.Table.deepMerge(_K.Data.async.group, group, true)
			_K.Auth.prefetchGroupEntryRanks()
		end

		if settings.friendRoles and #settings.friendRoles > 0 then
			_K.Data.friendRoles = table.clone(settings.friendRoles)
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

		local _ = _K.Service.Marketplace.PromptGamePassPurchaseFinished:Connect(
			function(player, gamePassId, purchaseSuccess)
				if not purchaseSuccess then
					return
				end
				_K.log(`bought gamepass {gamePassId}`, "PURCHASE", player.UserId)
				for id, roles in _K.Data.async.gamepass do
					if gamePassId ~= id then
						continue
					end
					-- exploits can fake purchaseSuccess, and ownership can lag a few seconds behind a real purchase
					local owned = _K.Util.Retry(function()
						assert(_K.Service.Marketplace:UserOwnsGamePassAsync(player.UserId, gamePassId), "not owned")
					end, 3)
					if not owned then
						return
					end
					local rolesAdded = {}
					for _, role in roles do
						local roleAdded = _K.Auth.asyncRoleAdd(player.UserId, role)
						if roleAdded then
							local roleData = _K.Data.roles[role]
							table.insert(rolesAdded, `<b><font color="{roleData.color}">{roleData.name}</font></b>`)
						end
					end

					if player and #rolesAdded > 0 then
						local prefix = _K.getCommandPrefix(player.UserId)
						_K.Remote.Notify:Fire(player, {
							Text = `You got the {table.concat(rolesAdded, ", ")} role{if #rolesAdded > 1
								then "s"
								else ""}!\nSay <b>{prefix}cmds</b> or <b>{prefix}info</b> for details.`,
							From = "_K",
						})
					end
				end
			end
		)

		-- addons
		local serverAddons = Instance.new("Folder")
		serverAddons.Name = "_KServerAddons"
		serverAddons.Parent = _K.Service.ServerStorage

		local sharedAddons = Instance.new("Folder")
		sharedAddons.Name = "Addons"
		sharedAddons.Parent = Package

		local function loadAddons(list)
			for _, object in list do
				if object:IsA("ModuleScript") then
					if string.find(object.Name, "Server", 1, true) then
						object.Parent = serverAddons
						task.spawn(function()
							require(object :: ModuleScript)(_K)
						end)
					elseif not string.find(object.Name, "Client", 1, true) then
						object.Parent = sharedAddons
						task.spawn(function()
							require(object :: ModuleScript)(_K)
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

		-- ;whois shows Platform as RichText, so only take what the client sets it to (UI.Platform)
		local platforms = { Console = true, Mobile = true, PC = true, VR = true }
		local function isValidSessionStart(value)
			return type(value) == "number" and value == value and math.abs(value) ~= math.huge
		end
		local attributeSchema = {
			Platform = function(value)
				return platforms[value] == true
			end,
			SessionStart = isValidSessionStart,
		}

		-- server network events
		local lastLog, cachedLogsBuffer
		local _ = _K.Remote.Init:Connect(function(player, initData)
			local attributes = type(initData) == "table" and initData.Attributes
			if type(attributes) == "table" then
				for attribute, isValid in attributeSchema do
					local value = attributes[attribute]
					if isValid(value) then
						player:SetAttribute("_K" .. attribute, value)
					end
				end
			end

			if player:GetAttribute("_K_READY") then
				return
			end

			local logs
			if _K.Auth.hasPermission(player.UserId, "serverlogs") then
				if lastLog ~= _K.Data.logs[#_K.Data.logs] or not cachedLogsBuffer then
					lastLog = _K.Data.logs[#_K.Data.logs]
					local err
					cachedLogsBuffer, err = _K.Z.ser(_K.Data.Schema.logsRemote, _K.Data.logs)
					if not cachedLogsBuffer then
						warn("Failed to serialize logs:", err)
					end
				end
				logs = cachedLogsBuffer
			end

			local bans = if _K.Auth.hasCommand(player.UserId, "ban") then _K.Data.bans else nil
			local members = if _K.Auth.hasCommand(player.UserId, "members")
				then _K.Data.members
				else {
					[tostring(player.UserId)] = _K.Data.members[tostring(player.UserId)],
				}
			local roles = _K.Data.roles
			local reservedServers = if (
					_K.Auth.hasCommand(player.UserId, "place") or _K.Auth.hasCommand(player.UserId, "unreserve")
				)
				then _K.Data.reservedServers
				else nil
			local servers = if _K.Auth.hasCommand(player.UserId, "servers") then Servers.Map else nil
			local savedSettings = _K.Data.savedSettings
			local defaultSettings = _K.Data.defaultSettings

			_K.Remote.Init:Fire(
				player,
				bans,
				logs,
				members,
				roles,
				reservedServers,
				servers,
				savedSettings,
				defaultSettings
			)
			player:SetAttribute("_K_READY", true)

			if type(_K.Data.savedSettings.announcement) == "table" then
				local msg, from = unpack(_K.Data.savedSettings.announcement)
				_K.Chat.send(
					{ global = true, from = from, fromPlayer = from and _K.Service.Players:GetPlayerByUserId(from) },
					"announce",
					msg,
					{ player },
					_K.Data.savedSettings.announcement
				)
			end

			if _K.Data.canSave == false then
				_K.alert(player, `<b>Global save data failed to load:</b>\n{_K.Data.saveError}`, true)
			end

			if
				settings.vip
				and settings.addToCharts
				and not _K.Service.Http.HttpEnabled
				and _K.Auth.hasPermission(player.UserId, "settings")
			then
				task.delay(4, function()
					_K.Remote.Notify:Fire(player, {
						From = "_K",
						Text = `Your game is unable to participate in the <b>Kohl's Admin Games Hub</b> because <b><font color='#{_K.Data.settings.themeInvalid:ToHex()}'>HTTP Requests are disabled in your game settings</font></b>.\n\n<i><font transparency='0.5'>Enable HTTP Requests in your Roblox game settings to avoid missing out on free advertising and other benefits!</font></i>`,
						Sound = "Call_Leave",
					})
				end)
			end
		end)

		-- chat commands are TextChatCommands, Player.Chatted never fires with platform-integrated chat
		_K.ChatCommands = require(script.ChatCommands).start(_K)

		-- enable client
		Client.Enabled = true

		-- initialize core remotes
		local _
		_ = _K.Remote.Announce
		_ = _K.Remote.Bans
		_ = _K.Remote.DisplayBubble
		_ = _K.Remote.Member
		_ = _K.Remote.Members
		_ = _K.Remote.Log
		_ = _K.Remote.Logs
		_ = _K.Remote.Notify
		_ = _K.Remote.RequestCommand
		-- TODO: implement in-game role creation
		_ = _K.Remote.Role
		_ = _K.Remote.Roles
		_ = _K.Remote.RolesNotification
		_ = _K.Remote.SetCore
		_ = _K.Remote.VIPNotification

		local _ = _K.Remote.Command:Connect(function(player: Player, message: string)
			if type(message) ~= "string" then
				return
			end
			_K.Process.runCommands(_K, player.UserId, message)
		end)

		local reservedPrefixes = { ",", " ", "`", '"', "@", "$", "%", "*", "~" }

		-- handle custom command prefix
		local _ = _K.Remote.PlayerPrefix:Connect(function(player, prefix)
			if
				type(prefix) == "string"
				and utf8.len(prefix) == 1
				and not table.find(reservedPrefixes, prefix)
				and _K.Data.playerPrefix[player.UserId] ~= prefix
				and not _K.Chat.cooldown(player.UserId, "playerPrefix", 1)
			then
				_K.Data.playerPrefix[player.UserId] = prefix
				if _K.ChatCommands then
					_K.ChatCommands.schedule()
				end
			end
		end)

		local handledSettings = {
			freeAdmin = true,
			announcement = true,
			announcements = true,
			notifications = true,
			prefix = true,
			splitKey = true,
		}

		local function isValidSetting(key: any, value: any): boolean
			if type(key) ~= "string" then
				return false
			end
			if handledSettings[key] then
				return true
			end
			local default = _K.Data.defaultSettings[key]
			if default == nil then
				return false
			end
			if string.sub(key, -4) == "Rank" then
				return value == false or (type(value) == "number" and value == value and math.abs(value) ~= math.huge)
			elseif key == "themeBackgroundImage" then
				return type(value) == "string" and string.match(value, "^rbxassetid://%d+$") ~= nil
			elseif key == "theme" then
				return type(value) == "string" and #value <= 64 and string.match(value, "^[%w ()%-_]+$") ~= nil
			elseif key == "changeThemeAuthority" then
				return value == "Client" or value == "Server" or value == "Studio"
			elseif key == "saveChatLogs" then
				return value == false -- chat text is never logged
			end
			local defaultType = typeof(default)
			if defaultType == "string" or defaultType == "table" then
				return false
			elseif defaultType == "number" then
				return type(value) == "number" and value == value and math.abs(value) ~= math.huge
			elseif defaultType == "EnumItem" then
				return typeof(value) == "EnumItem" and value.EnumType == default.EnumType
			end
			return typeof(value) == defaultType
		end

		-- handle changing of settings
		local _ = _K.Remote.Settings:Connect(function(player, changes)
			local themeAuthority = _K.Data.settings.changeThemeAuthority
			--TODO: make the Client authority save each players' theming

			if type(changes) ~= "table" or not _K.Auth.hasPermission(player.UserId, "settings") then
				return
			end

			local isDeveloper = _K.Auth.hasRestrictedRole(player.UserId)

			if changes.freeAdmin ~= nil then
				if type(changes.freeAdmin) ~= "table" or not isDeveloper then
					changes.freeAdmin = nil
				else
					local rank = _K.Auth.getRank(player.UserId)
					for _, roleId in changes.freeAdmin do
						local role = type(roleId) == "string" and _K.Data.roles[roleId]
						if
							not role
							or role == _K.Data.roles.everyone
							or (player.UserId ~= _K.creatorId and rank <= role._rank)
						then
							changes.freeAdmin = nil
							break
						end
					end
				end
			end

			-- announcements and notifications are user text shown to everyone, so new ones are filtered and rate
			-- limited like ;announce
			local announcement = changes.announcement
			changes.announcement = nil
			local newAnnouncement = type(announcement) == "table"
				and type(announcement[1]) == "string"
				and #announcement[1] <= 1000
				and utf8.len(announcement[1]) ~= nil
			local newCount = if newAnnouncement then 1 else 0

			-- these settings are lists, existing entries are kept as is and only new ones need the rate limit
			local function itemKey(item)
				return `{item.From}\0{item.Duration}\0{item.Text}`
			end
			local lists = {}
			for _, key in { "announcements", "notifications" } do
				local items = changes[key]
				changes[key] = nil
				if type(items) ~= "table" then
					continue
				end
				local existing, existingCounts, entries = {}, {}, {}
				for _, item in _K.Data.savedSettings[key] or {} do
					local k = itemKey(item)
					existing[k] = item
					existingCounts[k] = (existingCounts[k] or 0) + 1
				end
				for _, item in items do
					if
						type(item) == "table"
						and type(item.Text) == "string"
						and #item.Text <= 1000
						and utf8.len(item.Text) ~= nil
					then
						local k = itemKey(item)
						if (existingCounts[k] or 0) > 0 then
							existingCounts[k] -= 1
							table.insert(entries, existing[k])
						else
							newCount += 1
							table.insert(entries, { new = item })
						end
					end
				end
				lists[key] = entries
			end

			local err
			if newCount > 0 then
				-- a rejected burst doesn't start the cooldown shared with ;announce
				err = if _K.Data.SEPARATE_DATASTORE
					then "Announcements are disabled in private servers."
					elseif newCount > 1 then "Please wait before adding another message."
					else _K.Chat.limitBroadcast(player.UserId)
				if err then
					_K.alert(player, err, true)
				end
			end

			if announcement == false then
				changes.announcement = false -- clearing it, like ;unannounce
			elseif not err and newAnnouncement then
				changes.announcement = {
					_K.Util.String.filterForBroadcast(announcement[1], player.UserId),
					player.UserId,
					0,
					_K.Service.Http:GenerateGUID(false), -- shows again when the same text is pinned again
				}
			end

			for key, entries in lists do
				local items = {}
				for _, entry in entries do
					if not entry.new then
						table.insert(items, entry)
					elseif not err then
						local rawDuration = tonumber(entry.new.Duration)
						table.insert(items, {
							From = player.UserId,
							Duration = if rawDuration and rawDuration == rawDuration
								then math.clamp(rawDuration, 0, 600)
								else nil,
							Text = _K.Util.String.filterForBroadcast(entry.new.Text, player.UserId),
						})
					end
				end
				changes[key] = items
			end

			-- the prefix and split key are shown to everyone, users are limited to single valid characters like the
			-- settings UI, and non-developers are rate limited
			do
				local current = _K.Data.savedSettings
				local existingPrefixes = current.prefix or {}
				-- nil when invalid, otherwise number of newly added characters
				local function countAddedCharacters(values, existing, isPrefix: boolean): number?
					if type(values) ~= "table" or #values == 0 or #values > math.max(#existing, 1) then
						return nil
					end
					local added = 0
					local seen = {}
					for _, value in values do
						if
							type(value) ~= "string"
							or utf8.len(value) ~= 1
							or seen[value]
							or (isPrefix and table.find(reservedPrefixes, value))
						then
							return nil
						end
						seen[value] = true
						if not table.find(existing, value) then
							added += 1
						end
					end
					return added
				end
				if type(changes.prefix) == "table" then
					local deduped, seen = {}, {}
					for _, v in changes.prefix do
						if not seen[v] then
							seen[v] = true
							table.insert(deduped, v)
						end
					end
					changes.prefix = deduped
				end
				local invalid, totalAdded = false, 0
				for key, existing in { prefix = existingPrefixes, splitKey = { current.splitKey } } do
					local value = changes[key]
					if value == nil then
						continue
					end
					local added =
						countAddedCharacters(if key == "splitKey" then { value } else value, existing, key == "prefix")
					if added == nil or (not isDeveloper and added > 1) then
						changes[key], invalid = nil, true
					else
						totalAdded += added
					end
				end
				if invalid then
					_K.alert(player, "Prefixes and split keys are limited to a single character.", true)
				elseif not isDeveloper and totalAdded > 0 then
					local cooldownError = _K.Chat.cooldown(player.UserId, "prefix")
					if cooldownError then
						changes.prefix, changes.splitKey = nil, nil
						_K.alert(player, cooldownError, true)
					end
				end
			end

			local changeStrings = {}
			for key, value in changes do
				-- skipped keys aren't sent to other players either
				if
					(_K.Data.savedSettings[key] == nil and not handledSettings[key])
					or (string.find(key, "theme", 1, true) and themeAuthority == "Studio")
					or not isValidSetting(key, value)
				then
					changes[key] = nil
					continue
				end

				_K.Data.savedSettings[key] = value
				local logValue = if type(value) == "string"
					then _K.Util.String.filterForBroadcast(value, player.UserId)
					elseif key == "announcement" and type(value) == "table" then value[1] -- already filtered
					elseif key == "announcements" or key == "notifications" then `{#value} {key}`
					elseif key == "freeAdmin" or key == "prefix" then table.concat(value, ", ")
					else value
				table.insert(changeStrings, `[{key}]: {logValue}`)

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

			if next(changes) == nil then
				return -- nothing valid changed, skip the broadcast
			end

			for _, toPlayer in _K.Service.Players:GetPlayers() do
				if toPlayer ~= player then
					_K.Remote.Settings:Fire(toPlayer, changes)
				end
			end
			-- the editor applied its own changes, but sees the filtered pinned announcement like everyone else
			if changes.announcement ~= nil then
				_K.Remote.Settings:Fire(player, { announcement = changes.announcement })
			end

			_K.Data.settings = if _K.Data.savedSettings.useSavedSettings
				then _K.Data.savedSettings
				else _K.Data.defaultSettings
			-- the prefixes and chatCommands are chat command aliases
			_K.ChatCommands.schedule()

			if #changeStrings > 0 then
				_K.log(`changed settings: {table.concat(changeStrings, " ")}`, "COMMAND", player.UserId)
			end
		end)

		-- handle ban events
		local _ = _K.Remote.Ban:Connect(function(player: Player, userId: number, reason: string?, duration: number?)
			userId = tonumber(userId) :: number
			local canBan = _K.Auth.hasCommand(player.UserId, "ban")
			if not (canBan and userId and userId > 0 and userId <= 2 ^ 53 and math.floor(userId) == userId) then
				return
			end
			if duration ~= nil then
				if type(duration) ~= "number" or duration ~= duration or math.abs(duration) == math.huge then
					return
				end
				duration = math.floor(duration)
			end

			local fromRank, fromRole = _K.Auth.getRank(player.UserId)
			local fauxArg = {
				_K = _K,
				definition = _K.Registry.commands.ban.args[1],
				command = {
					from = player.UserId,
					fromRank = fromRank,
					fromRole = fromRole or {},
					rank = canBan or 0,
				},
			}

			_K.Data.targetLimits[player.UserId] = 0
			if (reason == nil or type(reason) == "string") and _K.Auth.targetUserArgument(fauxArg, userId, userId) then
				if
					not _K.Auth.hasPermission(player.UserId, "banasync") or not _K.Auth.hasRestrictedRole(player.UserId)
				then
					duration = 0
				end
				local existingBan = _K.Data.bans[tostring(userId)]
				if existingBan and reason == existingBan[2] then
					reason = existingBan[2]
				elseif reason then
					reason = string.sub(reason, 1, 400) -- banasync limit
					-- ban reasons are user text other admins can see
					reason = _K.Chat.limitReason(player.UserId, reason)
				end
				local targetPlayer = _K.Service.Players:GetPlayerByUserId(userId)
				if targetPlayer then
					targetPlayer:Kick(reason or "No reason.")
				end
				if #_K.Auth.banUsers({ userId }, reason, duration, player.UserId) > 0 then
					local logText = `{_K.getCommandPrefix()}ban {userId} {duration}`
					_K.log(if reason then `{logText} {reason}` else logText, "COMMAND", player.UserId)
				else
					-- saved bans are kept unless the caller can use banasync
					_K.Remote.Notify:Fire(player, { Text = `Kept saved ban for <b>{userId}</b>.` })
				end
			end
		end)

		local _ = _K.Remote.Unban:Connect(function(player: Player, userId: number)
			userId = tonumber(userId) :: number
			local canUnban = _K.Auth.hasCommand(player.UserId, "unban")
			if not (canUnban and userId and userId > 0 and userId <= 2 ^ 53 and math.floor(userId) == userId) then
				return
			end
			local ban = _K.Data.bans[tostring(userId)]
			if not ban then
				return
			end
			local savedBan = ban[3] and (ban[3] < 0 or ban[3] > os.time())
			if
				savedBan
				and player.UserId ~= _K.Data.creatorId
				-- banasync includes admin, and only developers change saved bans, as in Auth.unbanUsers
				and (
					not _K.Auth.hasPermission(player.UserId, "banasync")
					or not _K.Auth.hasRestrictedRole(player.UserId)
				)
			then
				return
			end
			local fromRank, fromRole = _K.Auth.getRank(player.UserId)
			local fauxArg = {
				_K = _K,
				definition = _K.Registry.commands.unban.args[1],
				command = {
					from = player.UserId,
					fromRank = fromRank,
					fromRole = fromRole or {},
					rank = canUnban or 0,
				},
			}
			_K.Data.targetLimits[player.UserId] = 0
			if _K.Auth.targetUserArgument(fauxArg, userId, userId) then
				if #_K.Auth.unbanUsers({ userId }, player.UserId) > 0 then
					_K.log(`{_K.getCommandPrefix()}unban {userId}`, "COMMAND", player.UserId)
				end
			end
		end)

		local _ = _K.Remote.Idled:Connect(function(player: Player, idleTime: number)
			if type(idleTime) == "number" and idleTime >= 0 and idleTime < math.huge then
				player:SetAttribute("_KIdleTime", idleTime)
			end
		end)

		local function cloneInstanceUnsafe(instance, parent: Instance?)
			local clone = instance:Clone()
			clone.Parent = parent

			return clone
		end

		-- the admin system's own instances, changing them breaks it for everyone
		local function isProtectedInstance(instance: Instance, allowAncestors: boolean?): boolean
			local chatFolder = _K.ChatCommands and _K.ChatCommands.folder
			for _, root in { Package, Server, chatFolder } do
				if
					instance == root
					or instance:IsDescendantOf(root)
					or (not allowAncestors and root:IsDescendantOf(instance))
				then
					return true
				end
			end
			return false
		end

		-- the player an instance belongs to, through the Player object or their character
		local function getInstanceOwner(instance: Instance): Player?
			if instance:IsA("Player") then
				return instance
			end
			local owner = instance:FindFirstAncestorWhichIsA("Player")
			if owner then
				return owner
			end
			for _, player in _K.Service.Players:GetPlayers() do
				local character = player.Character
				if character and (instance == character or instance:IsDescendantOf(character)) then
					return player
				end
			end
			return nil
		end

		local _ = _K.Remote.Explorer:Connect(function(player: Player, action: string, data: any, selected: Instance?)
			local explorerRank = _K.Auth.hasCommand(player.UserId, "explorer")
			if not explorerRank or type(data) ~= "table" then
				return
			end

			local fromRank, fromRole = _K.Auth.getRank(player.UserId)
			local fauxArg = {
				_K = _K,
				definition = _K.Registry.commands.ban.args[1],
				command = {
					from = player.UserId,
					fromRank = fromRank,
					fromRole = fromRole or {},
					rank = explorerRank or 0,
				},
			}
			_K.Data.targetLimits[player.UserId] = 0
			local checkedOwners: { [Player]: boolean } = {}

			-- instances of other players (their character, PlayerGui, Backpack...) follow the same rank rules as
			-- targeting the player, so a lower rank can't run scripts on or remove the parts of a higher rank
			local function canModify(instance: Instance, allowAncestors: boolean?): boolean
				if isProtectedInstance(instance, allowAncestors) then
					return false
				end
				local owner = getInstanceOwner(instance)
				if owner and (owner ~= player or instance == owner) then
					if checkedOwners[owner] == nil then
						checkedOwners[owner] = _K.Auth.targetUserArgument(fauxArg, owner.UserId, owner.UserId) ~= nil
					end
					return checkedOwners[owner]
				end
				if not allowAncestors then
					if instance == _K.Service.Players or _K.Service.Players:IsDescendantOf(instance) then
						return false
					end
					for _, other in _K.Service.Players:GetPlayers() do
						if other ~= player and other.Character and instance:IsAncestorOf(other.Character) then
							if checkedOwners[other] == nil then
								checkedOwners[other] = _K.Auth.targetUserArgument(fauxArg, other.UserId, other.UserId)
									~= nil
							end
							if not checkedOwners[other] then
								return false
							end
						end
					end
				end
				return true
			end

			if action == "PASTE" then
				if typeof(selected) ~= "Instance" or not canModify(selected, true) then
					return
				end
				for _, copy in data do
					if
						typeof(copy) ~= "Instance"
						or copy:IsA("Player")
						or copy == selected
						or copy:IsAncestorOf(selected)
						or not canModify(copy)
					then
						continue
					end
					local wasArchivable = copy.Archivable
					copy.Archivable = true
					local _ = pcall(cloneInstanceUnsafe, copy, selected)
					if not wasArchivable then
						copy.Archivable = false
					end
				end
			elseif action == "DELETE" then
				for _, instance in data do
					if typeof(instance) ~= "Instance" or not canModify(instance) then
						continue
					end

					local _ = pcall(game.Destroy, instance)
				end
			end
		end)

		local _ = _K.Hook.roleAdded:Connect(function(userId: number, roleId: string)
			local player = _K.Service.Players:GetPlayerByUserId(userId)
			if player then
				if _K.Auth.hasCommand(userId, "servers") then
					if not ServersSubscribers[player] then
						_K.Remote.Servers:Fire(player, nil, Servers.Map)
					end
					ServersSubscribers[player] = true
				end
			end
		end)

		local _ = _K.Hook.roleRemoved:Connect(function(userId: number, roleId: string)
			local player = _K.Service.Players:GetPlayerByUserId(userId)
			if player then
				if not _K.Auth.hasCommand(userId, "servers") then
					ServersSubscribers[player] = nil
				end
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

			if _K.Service.Run:IsStudio() then
				_K.Auth.userRoleAdd(player.UserId, "creator")
			end

			if (_K.Data.settings.welcomeBadgeId or 0) > 0 then
				task.spawn(awardBadge, player.UserId, _K.Data.settings.welcomeBadgeId)
			end

			task.spawn(_K.log, "joined the server.", "JOIN", player.UserId)

			local cleanup = {}
			playerCleanup[player.UserId] = cleanup
			table.insert(cleanup, player.CharacterAdded:Connect(characterAdded))
			table.insert(cleanup, player.CharacterRemoving:Connect(characterRemoving))

			if _K.Auth.hasCommand(player.UserId, "servers") then
				ServersSubscribers[player] = true
			end

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

		local _ = _K.Service.Players.PlayerRemoving:Connect(function(player)
			ServersSubscribers[player] = nil

			local userId = player.UserId

			task.spawn(_K.log, "left the server.", "LEAVE", userId)

			_K.Flux.dispose(playerCleanup[userId])
			playerCleanup[userId] = nil
			_K.Data.targetLimits[userId] = nil
			_K.Process.resetLimit(userId)
			if _K.Data.playerPrefix[userId] then
				_K.Data.playerPrefix[userId] = nil
				if _K.ChatCommands then
					_K.ChatCommands.schedule()
				end
			end
		end)

		task.spawn(_K.log, `Initialized in {math.round((os.clock() - initStart) * 1000)} ms`, "DEBUG")
		_K.ready = true
		_K.Hook.init:Fire()

		return _K
	end
end
