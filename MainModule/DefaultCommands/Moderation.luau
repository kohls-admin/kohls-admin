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
			local canBan = context._K.Auth.hasPermission(context.from.UserId, "ban")
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
					context.from.UserId,
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
			local canBan = context._K.Auth.hasPermission(context.from.UserId, "ban")
			local rank = context._K.Auth.getRank(context.from.UserId)
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

				context._K.banHandler(userId, userName, reason, duration, context.from.UserId, context.from.Name)
				if userName ~= "" then
					continue
				end
				-- populate the username if not found
				task.spawn(function()
					local ok, result = pcall(
						context._K.Services.Players.GetNameFromUserIdAsync,
						context._K.Services.Players,
						tonumber(userId)
					)
					if ok then
						context._K.bans[userId][1] = result
						-- TODO: network ban name
					end
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
				context._K.Remote "Ban":FireAllClients(userId)
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
				lowerRank = true, -- TODO: respect lowerRank???!?!?
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
			},
		},
		run = function(context, players)
			for _, player in players do
				if context._K.Auth.shouldRequest(context, player) then
					continue
				end
				if player.Character then
					player.Character:BreakJoints()
				end
			end
		end,
	},
}
