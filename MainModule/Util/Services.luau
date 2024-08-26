local Services = setmetatable({
	Players = game:GetService("Players"),
	TextService = game:GetService("TextService"),
	ContextActionService = game:GetService("ContextActionService"),
	Lighting = game:GetService("Lighting"),
	PolicyService = game:GetService("PolicyService"),
	ReplicatedStorage = game:GetService("ReplicatedStorage"),
	ServerScriptService = game:GetService("ServerScriptService"),
	ServerStorage = game:GetService("ServerStorage"),
	SoundService = game:GetService("SoundService"),
	StarterGui = game:GetService("StarterGui"),
	UserInputService = game:GetService("UserInputService"),
}, {
	__index = function(self, key: string)
		local service = game:GetService(key)
		self[key] = service
		return service
	end,
})

return Services
