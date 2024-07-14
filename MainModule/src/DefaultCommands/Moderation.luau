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
			for _, player in players do
				if duration and canBan then
					if duration > 0 then
						duration = os.time() + duration
					end
					-- use new banasync
				end
				-- TODO: network ban and use a generic ban handler for extensions to use
				context._K.bans[player.UserId] = { player.Username, reason, duration }
				player:Kick(reason)
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

				-- TODO: network ban and use a generic ban handler for extensions to use
				context._K.bans[userId] = {
					userName,
					reason,
					duration,
				}
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
					end
				end)
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
			for _, userId in bans do
				-- TODO: network ban and use a generic ban handler for extensions to use
				context._K.bans[userId] = nil
				-- unbanasync
			end
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
