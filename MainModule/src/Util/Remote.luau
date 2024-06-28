local IsServer = game:GetService("RunService"):IsServer()

return setmetatable({}, {
	__index = function(self, key)
		local event
		if IsServer then
			event = Instance.new("RemoteEvent")
			event.Name = key
			event.Parent = script
		else
			event = script:WaitForChild(key)
		end
		self[key] = event

		return event
	end,
})
