local IsServer = game:GetService("RunService"):IsServer()

local _remotes = {}

return function(key)
	local event = _remotes[key]
	if event then
		return event
	end
	if IsServer then
		event = Instance.new("RemoteEvent")
		event.Name = key
		event.Parent = script
	else
		event = script:WaitForChild(key)
	end
	_remotes[key] = event

	return event
end
