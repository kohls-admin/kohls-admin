local Services = setmetatable({
	Players = game:GetService("Players"),
	ContextActionService = game:GetService("ContextActionService"),
	Lighting = game:GetService("Lighting"),
	MarketplaceService = game:GetService("MarketplaceService"),
	PolicyService = game:GetService("PolicyService"),
	ReplicatedStorage = game:GetService("ReplicatedStorage"),
	RunService = game:GetService("RunService"),
	ServerScriptService = game:GetService("ServerScriptService"),
	ServerStorage = game:GetService("ServerStorage"),
	SocialService = game:GetService("SocialService"),
	SoundService = game:GetService("SoundService"),
	StarterGui = game:GetService("StarterGui"),
	StarterPack = game:GetService("StarterPack"),
	StarterPlayer = game:GetService("StarterPlayer"),
	TextService = game:GetService("TextService"),
	UserInputService = game:GetService("UserInputService"),
}, {
	__index = function(self, key: string)
		local service = game:GetService(key)
		self[key] = service
		return service
	end,
})

return Services
