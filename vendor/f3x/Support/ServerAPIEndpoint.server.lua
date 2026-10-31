local ServerEndpoint = script.Parent
local SyncAPI = ServerEndpoint.Parent
local Tool = SyncAPI.Parent

local Players = game:GetService("Players")

local function SETUP()
	-- Start the server-side sync module
	SyncModule = require(SyncAPI:WaitForChild "SyncModule")

	-- Provide functionality to the server API endpoint instance
	ServerEndpoint.OnServerInvoke = function(Client, ...)
		return SyncModule.PerformAction(Client, ...)
	end
end

local function isPlayerDescendant()
	return Tool:IsDescendantOf(Players) or Players:GetPlayerFromCharacter(Tool.Parent)
end

ServerEndpoint.OnServerInvoke = function() end

if isPlayerDescendant() then
	SETUP()
else
	local conn
	conn = Tool.AncestryChanged:Connect(function()
		if isPlayerDescendant() then
			conn:Disconnect()
			SETUP()
		end
	end)
end
