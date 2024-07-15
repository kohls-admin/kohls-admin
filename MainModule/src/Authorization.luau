-- allow for lookup of a player's "profile" ingame
-- store roles with "admin-like" permissions in a global datastore
-- necessary to prevent abuse against other users with "admin-like" roles
-- also allows for the "staff" command
-- should just be pure data that the command system references to give access to various parts

local Players = game:GetService("Players")

local module = {
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
		-- allows the user to manage roles of other users with a lesser role
		roles = false,
		-- can configure the global admin settings
		settings = false,
		-- can view audit logs
		logs = false,

		-- COSMETIC PERMISSIONS
		-- can use commands that require VIP permission
		vip = false,

		-- allowed command groups?
		groups = {
			-- "administration",
			-- "moderation",
			-- "general",
			"utility",
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
			groups = { "moderation", "general" },
		},
		admin = {
			_rank = 3,
			name = "Administrator",
			ban = true,
			kick = true,
			roles = true,
			logs = true,
			groups = { "administration", "moderation", "general" },
		},
		superadmin = {
			_rank = 4,
			name = "SuperAdmin",
			ban = true,
			kick = true,
			roles = true,
			logs = true,
			settings = true,
			groups = { "administration", "moderation", "general" },
		},
		-- FIXME should this be defined and configurable? (or should it just be forced...)
		creator = {
			_rank = math.huge,
			name = "Game Creator",
			admin = true,
		},
	},

	members = {
		-- example role data structure
		-- [userid] = {data}
		["1"] = {
			-- last known username? (update over time on init?)
			name = "Roblox",
			roles = { "admin", "vip" },
		},
		["44391621"] = {
			name = "Kohl",
			roles = { "mod", "vip" },
		},
	},
}

if game.CreatorId > 0 then
	module.members[tostring(game.CreatorId)] = {
		name = game:GetService("Players"):GetNameFromUserIdAsync(game.CreatorId),
		roles = { "creator" },
	}
end

-- for adding/removing roles only save staff roles
-- TODO: should probably not save roles to a player datastore otherwise those would need to be updated too ;(
-- TODO: instead let the game developer handle their own player save state and just give roles on join?

local function roleSort(a: string, b: string): boolean
	return module.roles[a]._rank > module.roles[b]._rank
end

function module.userRoleAdd(userId, role)
	local member = module.members[tostring(userId)]
	if not member then
		local player = Players:GetPlayerByUserId(userId)
		module.members[tostring(userId)] = {
			name = if player then player.name else Players:GetNameFromUserIdAsync(userId),
			roles = { role },
		}
	else
		if not table.find(member.roles, role) then
			table.insert(member.roles, role)
			table.sort(member.roles, roleSort)
		end
	end
end

function module.userRoleRemove(userId, role)
	local member = module.members[tostring(userId)]
	if member then
		local index = table.find(member.roles, role)
		if index then
			table.remove(member, index)
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
	local member = module.members[tostring(userId)]
	if member then
		for _, roleId in member.roles do
			local role = module.roles[roleId]
			if role and role[permission] then
				rank = math.max(rank, role._rank)
			end
		end
	end
	return rank
end

function module.hasCommandGroup(userId: number, group: string): boolean
	group = string.lower(group)
	if module.defaultRole.admin or (module.defaultRole.groups and table.find(module.defaultRole.groups, group)) then
		return true
	end
	local member = module.members[tostring(userId)]
	if member then
		if member.permissions and member.permissions.admin then
			return true
		end
		for _, roleId in member.roles do
			local role = module.roles[roleId]
			if not role then
				warn("undefined role?", role)
				continue
			end
			if role.admin or (role.groups and table.find(role.groups, group)) then
				return true
			end
		end
	end
	return false
end

function module.hasPermission(userId, permission)
	-- does everyone have the permission?
	if module.defaultRole[permission] or module.defaultRole.admin then
		return true
	end
	local member = module.members[tostring(userId)]
	if member then
		if member.permissions and (member.permissions.admin or member.permissions[permission]) then
			return true
		end
		for _, roleId in member.roles do
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
			local args = table.clone(context.args)
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
