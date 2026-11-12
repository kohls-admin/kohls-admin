--!strict
--[[
	Studio suite configuration for `sert.roblox.Runner`.
	`test/test.project.json` maps this module at `ReplicatedStorage.Tests.Config`; `server.server.luau` and
	`client.client.luau` hand it to the runner on each side of the play session started by `python3 tools/sert.py studio`.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local load: (Instance) -> any = require
local sert = load(ReplicatedStorage:WaitForChild("sert"))
local unit =
	ReplicatedStorage:WaitForChild("Tests"):WaitForChild("kohls-admin"):WaitForChild("test"):WaitForChild("unit")

local function serverReady()
	ReplicatedStorage:SetAttribute("_K_StudioServerActive", true)
	ReplicatedStorage:SetAttribute("_K_StudioServerDone", false)
	sert.waitFor(function()
		return #Players:GetPlayers() > 0 and shared._K_INTERFACE and shared._K_INTERFACE.ready
	end, 20, nil, "_K server interface ready")
	return function()
		ReplicatedStorage:SetAttribute("_K_StudioServerDone", true)
	end
end

local function clientReady()
	sert.waitFor(function()
		return shared._K_INTERFACE and shared._K_INTERFACE.ready
	end, 15, nil, "_K client interface ready")
	if ReplicatedStorage:GetAttribute("_K_StudioServerActive") then
		sert.waitFor(function()
			return ReplicatedStorage:GetAttribute("_K_StudioServerDone") == true
		end, 60, nil, "_K server specs completed")
	end
end

return {
	name = "Kohl's Admin",
	sweep = false,
	specs = unit,
	sides = {
		server = { setup = serverReady },
		client = { setup = clientReady },
	},
}
