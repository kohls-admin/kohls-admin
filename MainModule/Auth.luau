local Players = game:GetService("Players")

export type Role = "vip" | "mod" | "admin" | "superadmin" | "creator"

--- @class Auth
local Auth = {
	defaultRole = {
		-- role "_rank" determines hierarchy
		-- 0 is reserved for the default role
		_rank = 0,
		name = "Player",
		color = "#0ff",

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
		-- unique key should NEVER be changed or you may lose save data
		vip = {
			_rank = 1,
			name = "VIP",
			vip = true,
			color = "#0f8",
		},
		mod = {
			_rank = 2,
			name = "Moderator",
			kick = true,
			logs = true,
			groups = { "moderation", "general" },
			color = "#0f0",
		},
		admin = {
			_rank = 3,
			name = "Administrator",
			ban = true,
			kick = true,
			roles = true,
			logs = true,
			groups = { "administration", "moderation", "general" },
			color = "#ff0",
		},
		superadmin = {
			_rank = 4,
			name = "SuperAdmin",
			ban = true,
			kick = true,
			roles = true,
			logs = true,
			settings = true,
			groups = { "creator", "administration", "moderation", "general" },
			color = "#f80",
		},
		-- FIXME should this be defined and configurable? (or should it just be forced...)
		creator = {
			_rank = math.huge,
			name = "Game Creator",
			admin = true,
			color = "#f00",
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
	},
}

if game.CreatorId > 0 then
	Auth.members[tostring(game.CreatorId)] = {
		name = game:GetService("Players"):GetNameFromUserIdAsync(game.CreatorId),
		roles = { "creator" },
	}
end

Auth.roles.defaultRole = Auth.defaultRole

-- for adding/removing roles only save staff roles
-- TODO: should probably not save roles to a player datastore otherwise those would need to be updated too ;(
-- TODO: instead let the game developer handle their own player save state and just give roles on join?

local function roleSort(a: Role, b: Role): boolean
	return Auth.roles[a]._rank > Auth.roles[b]._rank
end

--- Adds a role to a user if they don't already have it
function Auth.userRoleAdd(userId: number, role: Role)
	local member = Auth.members[tostring(userId)]
	if not member then
		local player = Players:GetPlayerByUserId(userId)
		Auth.members[tostring(userId)] = {
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

--- Removes a role from a user if it exists
function Auth.userRoleRemove(userId: number, role: Role)
	local member = Auth.members[tostring(userId)]
	if member then
		local index = table.find(member.roles, role)
		if index then
			table.remove(member, index)
		end
	end
end

--- Gets the role entry from a rank number
function Auth.getRoleFromRank(rank: number): Role?
	for _, roleData in Auth.roles do
		if roleData._rank == rank then
			return roleData
		end
	end
	return
end

--- Checks the maximum role rank of the user, if permission is given it will fetch the highest rank of the roles with that permission
function Auth.getRank(userId: number, permission: string?): number
	permission = permission or "_rank"
	local rank = 0
	local member = Auth.members[tostring(userId)]
	if member then
		for _, roleId in member.roles do
			local role = Auth.roles[roleId]
			if role and role[permission] then
				rank = math.max(rank, role._rank)
			end
		end
	end
	return rank
end

--- Checks if a user has access to a command group
function Auth.hasCommandGroup(userId: number, group: string): boolean
	group = string.lower(group)
	if Auth.defaultRole.admin or (Auth.defaultRole.groups and table.find(Auth.defaultRole.groups, group)) then
		return true
	end
	local member = Auth.members[tostring(userId)]
	if member then
		if member.permissions and member.permissions.admin then
			return true
		end
		for _, roleId in member.roles do
			local role = Auth.roles[roleId]
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

--- Checks if a user has access to a permission
function Auth.hasPermission(userId: number, permission: string): boolean
	-- does everyone have the permission?
	if Auth.defaultRole[permission] or Auth.defaultRole.admin then
		return true
	end
	local member = Auth.members[tostring(userId)]
	if member then
		if member.permissions and (member.permissions.admin or member.permissions[permission]) then
			return true
		end
		for _, roleId in member.roles do
			local role = Auth.roles[roleId]
			if role and (role.admin or role[permission]) then
				return true
			end
		end
	end
	return false
end

--- Gets the difference of two users' ranks, with an optional permission parameter
function Auth.rankDiff(userIdFrom: number, userIdTo: number, permission: string?)
	return Auth.getRank(userIdFrom, permission) - Auth.getRank(userIdTo, permission)
end

--- Requests a command execution with a dialog interface
function Auth.requestCommand(context: { [any]: any }, to: Player, ...: any)
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
						table.insert(arg, to)
					end
				elseif valueType == "Instance" and arg:IsA("Player") then
					args[index] = to
				end
			end
			pcall(context.definition.run, context, unpack(args))
		end
	end
end

--- Shorthand utility for potentially abusive commands to check if they should show a request dialog
function Auth.shouldRequest(context: { [any]: any }, to: Player, ...: any): boolean
	if context.Requested and context.Requested[to] then
		return false
	end
	if context.from ~= to.UserId and Auth.rankDiff(context.from, to.UserId) <= 0 then
		pcall(Auth.requestCommand, context, to, ...)
		return true
	end
	return false
end

return Auth
