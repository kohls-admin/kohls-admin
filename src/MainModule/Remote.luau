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
	Init = _REMOTE,
	Log = _REMOTE,
	Logs = _REMOTE,
	Members = _REMOTE,
	Noclip = _REMOTE,
	Notify = _REMOTE,
	Prefix = _REMOTE,
	Refresh = _REMOTE,
	SetCore = _REMOTE,
	Setting = _REMOTE,
	Settings = _REMOTE,
	Spectate = _REMOTE,
	SpectateSubject = _REMOTE,

	RequestCommand = _REMOTECALL,
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
		if IsServer then
			local remote = Instance.new("RemoteEvent")
			remote.Name = key
			remote.Parent = script
			self[key] = remote
		else
			self[key] = script:WaitForChild(key)
		end

		return self[key]
	end,
})
