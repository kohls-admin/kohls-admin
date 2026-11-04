--!strict
--[[
	Studio suite configuration for `sert.roblox.Runner`.
	`test/test.project.json` maps this module at `ReplicatedStorage.Tests.Config`; `server.server.luau` and
	`client.client.luau` hand it to the runner on each side of the play session started by `python3 tools/sert.py studio`.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local load: (Instance) -> any = require
local sert = load(ReplicatedStorage:WaitForChild("sert"))
local Runner = load(ReplicatedStorage:WaitForChild("sert"):WaitForChild("roblox"):WaitForChild("Runner"))
local unit =
	ReplicatedStorage:WaitForChild("Tests"):WaitForChild("kohls-admin"):WaitForChild("test"):WaitForChild("unit")

local function clientReady()
	sert.waitFor(function()
		return shared._K_INTERFACE and shared._K_INTERFACE.ready
	end, 15, "_K client interface ready")
	Runner.phase("client", "ready")
end

return {
	name = "Kohl's Admin",
	hideChat = false,
	rtestOnly = true,
	sides = {
		server = { entry = unit, filter = "Studio · Server > " },
		client = { entry = unit, filter = "Studio · Client > ", before = clientReady },
	},
}
