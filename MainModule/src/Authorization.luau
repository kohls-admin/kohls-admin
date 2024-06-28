-- allow for lookup of a player's "profile" ingame
-- store roles with "admin-like" permissions in a global datastore
-- necessary to prevent abuse against other users with "admin-like" roles
-- also allows for the "staff" command
-- should just be pure data that the command system references to give access to various parts

local Players = game:GetService("Players")

local module = {
	_K = nil,

	defaultRole = {
		-- role "_rank" determines hierarchy
		-- 0 is reserved for the default role
		name = "everyone",

		-- STAFF PERMISSIONS (anyone with one of these permissions will be saved to the list of staff)

		-- this permission bypasses all restrictions (danger!)
		admin = false,
		-- can PERMANENTLY ban users from the game
		ban = false,
		-- can kick or ban users from the current server session
		kick = false,
		-- allows the user to manage roles of other users with a lower role
		roles = false,
		-- can view dev tools
		dev = false,
		-- can view audit logs
		logs = false,

		-- COSMETIC PERMISSIONS
		-- can use commands that require a staff OR vip permission
		vip = false,

		-- allowed command groups?
		groups = {
			utility = false,
			moderation = false,
		},

		-- command name/alias filter
		filter = {
			-- allows the help command unless it's disabled
			help = true,
			-- prevents the use of the kill command
			kill = false,
		},
	},
	-- role definition
	roles = {
		-- the default role given to everyone
		-- unique key should NEVER be changed or you may lose save data
		vip = {
			_rank = 1,
			name = "VIP",
			vip = true,
		},
		mod = {
			_rank = 2,
			name = "Moderator",
			kick = true,
			logs = true,
		},
		admin = {
			_rank = 3,
			name = "Administrator",
			ban = true,
			kick = true,
			roles = true,
			logs = true,
		},
		dev = {
			_rank = 4,
			name = "Developer",
			dev = true,
			logs = true,
		},
		-- FIXME should this be defined and configurable? (or should it just be forced...)
		creator = {
			_rank = math.huge,
			name = "Game Creator",
			admin = true,
		},
	},

	permissions = {
		-- example role data structure
		-- [userid] = {data}
		[1] = {
			-- last known username
			name = "Roblox",
			roles = { "creator" },
		},
	},
}

-- for adding/removing roles only save staff roles
-- TODO: should probably not save roles to a player datastore otherwise those would need to be updated too ;(
-- TODO: instead let the game developer handle their own player save state and just give roles on join?

function module.userRoleAdd(userId, role)
	local userPermissions = module.permissions[userId]
	if not userPermissions then
		local player = Players:GetPlayerByUserId(userId)
		userPermissions = {
			name = if player then player.name else Players:GetNameFromUserIdAsync(userId),
			roles = { role },
		}
		module.permissions[userId] = userPermissions
	else
		if not table.find(userPermissions.roles, role) then
			table.insert(userPermissions.roles, role)
		end
	end
end

function module.userRoleRemove(userId, role)
	local userPermissions = module.permissions[userId]
	if userPermissions then
		local index = table.find(userPermissions.roles, role)
		if index then
			table.remove(userPermissions, index)
		end
	end
end

function module.getRoleId(roleString)
	roleString = string.lower(roleString)
	for _, role in module.roles do
		local nameLower = string.lower(role.name)
		if nameLower == roleString then
			return role._id
		-- TODO: allow a partial match? or should this be a part of autocomplete validation?
		elseif string.find(nameLower, roleString) == 1 then
			return role._id
		end
	end
	return
end

function module.getRank(userId, permission)
	permission = permission or "_rank"
	local rank = 0
	local userPermissions = module.permissions[userId]
	if userPermissions then
		for _, roleId in userPermissions.roles do
			local role = module.roles[roleId]
			if role and role[permission] then
				rank = math.max(rank, role._rank)
			end
		end
	end
	return rank
end

function module.hasPermission(userId, permission)
	-- does everyone have the permission?
	if module.defaultRole[permission] or module.defaultRole.admin then
		return true
	end
	local userPermissions = module.permissions[userId]
	if userPermissions then
		for _, roleId in userPermissions.roles do
			local role = module.roles[roleId]
			if role and (role.admin or role[permission]) then
				return true
			end
		end
	end
	return false
end

function module.rankDiff(userIdFrom, userIdTo, permission)
	return module.getRank(userIdFrom, permission) - module.getRank(userIdTo, permission)
end

function module.requestCommand(context, to, ...)
	print(string.format('%s requested to run command "%s" on %s.', context.from.Name, context.definition.name, to.Name))
	-- TODO: have some pretty "command requested" feedback sent
	-- for now just going to ignore the requests automatically
	if false then
		if not context.Requested then
			context.Requested = { [to] = true }
		else
			context.Requested[to] = true
		end

		if #{ ... } > 0 then
			pcall(context.definition.run, context, ...)
		else
			-- replace first player argument with to
			local args = module._K.Util.shallowCopy(context.args)
			for index, arg in args do
				local valueType = typeof(arg)
				if valueType == "table" then
					local value = next(arg)
					if typeof(value) == "Instance" and value:IsA("Player") then
						table.clear(arg)
						table.insert(to)
					end
				elseif valueType == "Instance" and arg:IsA("Player") then
					args[index] = to
				end
			end
			pcall(context.definition.run, context, unpack(args))
		end
	end
end

function module.shouldRequest(context, to, ...)
	if context.Requested and context.Requested[to] then
		return false
	end
	if context.from ~= to and module.rankDiff(context.from.UserId, to.UserId) <= 0 then
		pcall(module.requestCommand, context, to, ...)
		return true
	end
	return false
end

return module
