local RunService = game:GetService("RunService")

local IsServer = RunService:IsServer()

local _REMOTE = Instance.new("RemoteEvent")
local _REMOTECALL = Instance.new("RemoteFunction")

--- @class Remote
local Remote = {
	script = script,
	Announce = _REMOTE,
	Ban = _REMOTE,
	Bans = _REMOTE,
	Command = _REMOTE,
	Idled = _REMOTE,
	Init = _REMOTE,
	Log = _REMOTE,
	Logs = _REMOTE,
	Member = _REMOTE,
	Members = _REMOTE,
	Notify = _REMOTE,
	Prefix = _REMOTE,
	ReservedServers = _REMOTE,
	Refresh = _REMOTE,
	Role = _REMOTE,
	Roles = _REMOTE,
	SetCore = _REMOTE,
	Setting = _REMOTE,
	Settings = _REMOTE,
	Teleport = _REMOTE,
	Unban = _REMOTE,

	ShowFPS = _REMOTECALL,
	RequestCommand = _REMOTECALL,
	Vote = _REMOTECALL,
}

for name, base in Remote do
	if IsServer then
		local remote = Instance.new(base.ClassName, script)
		remote.Name = name
		Remote[name] = remote
	else
		Remote[name] = script:WaitForChild(name)
	end
end

-- Dynamic remote creation for command enviroments
return setmetatable(Remote, {
	__index = function(self, key)
		local remote
		if IsServer then
			remote = Instance.new("RemoteEvent")
			remote.Name = key
			remote.Parent = script
			self[key] = remote
			return remote
		else
			remote = script:FindFirstChild(key)
			self[key] = remote
		end

		return remote
	end,
})
