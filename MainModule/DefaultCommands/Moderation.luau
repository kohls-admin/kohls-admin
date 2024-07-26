-- dangerous moderation commands, but not the most dangerous of commands

return {
	{
		name = "ban",
		description = "Bans one or more players.",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to ban.",
				ignoreSelf = true,
				lowerRank = true,
			},
			{
				type = "timeSimple",
				name = "Duration",
				description = "The duration for the ban.",
				optional = true,
			},
			{
				type = "string",
				name = "Reason",
				description = "The reason for the ban.",
				optional = true,
			},
		},
		permissions = {
			kick = true,
		},

		run = function(context, players, duration: number?, reason: string?)
			-- if lacking administrator command group only allow session banning?
			-- need to somehow display only session bans in suggestions...
			-- TODO: only show lower rank players in the suggestions if defined in argDef
			local canBan = context._K.Auth.hasPermission(context.from, "ban")
			local timestamp
			if duration and canBan then
				if duration > 0 then
					timestamp = os.time() + duration
				end
				-- use new banasync
			end

			local ids = table.create(#players)
			for _, player in players do
				context._K.banHandler(
					player.UserId,
					player.Username,
					reason,
					timestamp,
					context.from,
					context.from.Name
				)
				player:Kick(reason)
			end
			if canBan and duration and duration ~= 0 then
				local ok = pcall(
					context._K.Services.Players.BanAsync,
					context._K.Services.Players,
					{ UserIds = ids, PrivateReason = reason, Duration = duration }
				)
				if not ok then
					-- TODO: retry banasync
				end
			end
		end,
	},
	{
		name = "banid",
		description = "Bans one or more players by userId.",
		args = {
			{
				type = "integers",
				name = "UserId(s)",
				description = "The userid(s) of the player(s) to ban.",
			},
			{
				type = "timeSimple",
				name = "Duration",
				description = "The duration for the ban.",
				optional = true,
			},
			{
				type = "string",
				name = "Reason",
				description = "The reason for the ban.",
				optional = true,
			},
		},
		permissions = {
			kick = true,
		},

		run = function(context, userIds, duration: number?, reason: string?)
			-- if lacking administrator command group only allow session banning?
			-- need to somehow display only session bans in suggestions...
			-- TODO: only show lower rank players in the suggestions if defined in argDef
			if type(reason) == "string" then
				reason = string.sub(reason, 1, 400) -- banasync limit
			end
			local canBan = context._K.Auth.hasPermission(context.from, "ban")
			local rank = context._K.Auth.getRank(context.from)
			for _, userId in userIds do
				-- only ban if rank is lower haha
				if rank <= context._K.Auth.getRank(userId) then
					continue
				end
				if duration and canBan then
					if duration > 0 then
						duration = os.time() + duration
					end
					-- use new banasync
				end

				local userName = ""
				for _, player in context._K.Services.Players:GetPlayers() do
					if player.UserId == tonumber(userId) then
						userName = player.Name
						player:Kick(reason)
					end
				end

				context._K.banHandler(
					userId,
					userName,
					reason,
					duration,
					context.from,
					context._K.Util.getUserInfo(context.from).Username
				)
				if userName ~= "" then
					continue
				end
				-- populate the username if not found
				task.spawn(function()
					context._K.bans[userId][1] = context._K.Util.getUserInfo(userId).Username
					-- TODO: network ban name and update for clients
				end)
			end
			if canBan and duration and duration ~= 0 then
				local ok = pcall(
					context._K.Services.Players.BanAsync,
					context._K.Services.Players,
					{ UserIds = userIds, PrivateReason = reason, Duration = duration }
				)
				if not ok then
					-- TODO: retry banasync
				end
			end
		end,
	},
	{
		name = "unban",
		description = "Unbans one or more players.",
		args = {
			{
				type = "bans",
				name = "Player(s)",
				description = "The player(s) to unban.",
			},
		},
		permissions = {
			kick = true,
		},
		run = function(context, bans)
			local ids = table.create(#bans)
			for i, userId in bans do
				context._K.bans[userId] = nil
				context._K.Remote.Ban:FireAllClients(userId)
				-- trigger ban save
				-- unbanasync
				table.insert(ids, tonumber(userId))
			end
			context._K.Services.Players:UnbanAsync({ UserIds = ids })
		end,
	},
	{
		name = "kick",
		description = "Kicks one or more players.",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to kick.",
				ignoreSelf = true,
				lowerRank = true,
			},
			{
				type = "string",
				name = "Reason",
				description = "The reason for the kick.",
				optional = true,
			},
		},
		permissions = {
			kick = true,
		},
		run = function(context, players, duration: number?, reason: string?)
			for _, player in players do
				player:Kick(reason)
			end
		end,
	},
	{
		name = "kill",
		aliases = { "unalive" },
		description = "Kills one or more players.",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to kill.",
				shouldRequest = true,
			},
		},
		run = function(context, players)
			for _, player in players do
				-- if context._K.Auth.shouldRequest(context, player) then
				-- 	print("kill shouldRequest", context, player)
				-- 	continue
				-- end
				if player.Character then
					player.Character:BreakJoints()
				end
			end
		end,
	},
	{
		name = "hurt",
		aliases = { "damage" },
		description = "Damages one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to hurt.",
			},
			{
				type = "number",
				name = "Damage",
				description = "The damage to deal to their health.",
			},
		},

		run = function(context, players, health)
			for _, player in players do
				local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid:TakeDamage(health)
				end
			end
		end,
	},
	{
		name = "health",
		aliases = { "maxhealth" },
		description = "Changes the maximum health one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) whose health to change.",
			},
			{
				type = "number",
				name = "Max Health",
				description = "The new maximum health.",
			},
		},

		run = function(context, players, health)
			for _, player in players do
				local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid.MaxHealth = health
				end
			end
		end,
	},
	{
		name = "heal",
		description = "Heals one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to heal.",
			},
		},

		run = function(context, players)
			for _, player in players do
				local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid.Health = humanoid.MaxHealth
				end
			end
		end,
	},
	{
		name = "god",
		description = "Makes one or more player(s) invincible.",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to make invincible.",
			},
		},

		run = function(context, players)
			for _, player in players do
				if player.Character and not player.Character:FindFirstChildOfClass("ForceField") then
					Instance.new("ForceField", player.Character).Visible = false
				end
			end
		end,
	},
	{
		name = "ff",
		description = "Gives a ForceField to one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to protect.",
			},
		},

		run = function(context, players)
			for _, player in players do
				if player.Character and not player.Character:FindFirstChildOfClass("ForceField") then
					Instance.new("ForceField", player.Character)
				end
			end
		end,
	},
	{
		name = "unff",
		aliases = { "ungod" },
		description = "Removes a ForceField from one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to remove a ForceField from.",
			},
		},

		run = function(context, players)
			for _, player in players do
				if player.Character then
					local ff = player.Character:FindFirstChildOfClass("ForceField")
					if ff then
						ff:Destroy()
					end
				end
			end
		end,
	},
	{
		name = "invisible",
		aliases = { "inv" },
		description = "Makes one or more player(s) invisible.",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to make invisible.",
			},
		},

		run = function(context, players)
			for _, player in players do
				if not player.Character then
					continue
				end
				for _, child in player.Character:GetDescendants() do
					if
						(child:IsA("BasePart") or child:IsA("Decal") or child:IsA("Texture"))
						and not child:GetAttribute("kTransparency")
					then
						child:SetAttribute("kTransparency", child.Transparency)
						child.Transparency = 1
					elseif
						(
							child:IsA("Light")
							or child:IsA("Beam")
							or child:IsA("Trail")
							or child:IsA("ParticleEmitter")
							or child:IsA("Fire")
							or child:IsA("Smoke")
							or child:IsA("Sparkles")
							or child:IsA("SurfaceGui")
						) and not child:GetAttribute("kEnabled")
					then
						child:SetAttribute("kEnabled", child.Enabled)
						child.Enabled = false
					end
				end
			end
		end,
	},
	{
		name = "visible",
		aliases = { "vis" },
		description = "Makes one or more player(s) visible.",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to make visible.",
			},
		},

		run = function(context, players)
			for _, player in players do
				if not player.Character then
					continue
				end
				for _, child in player.Character:GetDescendants() do
					local kTransparency = child:GetAttribute("kTransparency")
					local kEnabled = child:GetAttribute("kEnabled")
					if kTransparency then
						child:SetAttribute("kTransparency", nil)
						child.Transparency = kTransparency
					elseif kEnabled then
						child:SetAttribute("kEnabled", nil)
						child.Enabled = kEnabled
					end
				end
			end
		end,
	},
	{
		name = "respawn",
		description = "Respawns the character of one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to respawn.",
			},
		},

		run = function(context, players)
			for _, player in players do
				player:LoadCharacter()
			end
		end,
	},
	{
		name = "refresh",
		aliases = { "re" },
		description = "Refreshes the character of one or more player(s).",
		args = {
			{
				type = "players",
				name = "Player(s)",
				description = "The player(s) to refresh.",
			},
		},

		run = function(context, players)
			for _, player in players do
				if player and player.Character then
					local old = player.Character:GetPivot()
					player:LoadCharacter()
					player.Character:PivotTo(old)
					context._K.Remote.Refresh:FireClient(player)
				end
			end
		end,
	},
}
