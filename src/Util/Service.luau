local Service = setmetatable({
	Asset = game:GetService("AssetService"),
	AvatarEditor = game:GetService("AvatarEditorService"),
	Badge = game:GetService("BadgeService"),
	Collection = game:GetService("CollectionService"),
	ContextAction = game:GetService("ContextActionService"),
	Group = game:GetService("GroupService"),
	Lighting = game:GetService("Lighting"),
	Log = game:GetService("LogService"),
	Http = game:GetService("HttpService"),
	Insert = game:GetService("InsertService"),
	Marketplace = game:GetService("MarketplaceService"),
	Messaging = game:GetService("MessagingService"),
	Players = game:GetService("Players"),
	Policy = game:GetService("PolicyService"),
	ReplicatedFirst = game:GetService("ReplicatedFirst"),
	ReplicatedStorage = game:GetService("ReplicatedStorage"),
	Run = game:GetService("RunService"),
	ServerScript = game:GetService("ServerScriptService"),
	ServerStorage = game:GetService("ServerStorage"),
	Social = game:GetService("SocialService"),
	Sound = game:GetService("SoundService"),
	StarterGui = game:GetService("StarterGui"),
	StarterPack = game:GetService("StarterPack"),
	StarterPlayer = game:GetService("StarterPlayer"),
	Teams = game:GetService("Teams"),
	Teleport = game:GetService("TeleportService"),
	Text = game:GetService("TextService"),
	TextChat = game:GetService("TextChatService"),
	Tween = game:GetService("TweenService"),
	UserInput = game:GetService("UserInputService"),
}, {
	__index = function(self, key: string)
		local service = game:GetService(key)
		self[key] = service
		return service
	end,
})

return Service
