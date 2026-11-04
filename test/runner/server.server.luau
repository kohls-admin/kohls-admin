--!strict
--[[
	Studio test runner, server side (`test/test.project.json`): ensures the local Kohl's Admin package initializes
	without attempting remote asset auto-update, waits for the solo player and `_K.ready`, and runs the server's `rtest`
	specs before handing off to the client.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local load: (Instance) -> any = require
local sert = load(ReplicatedStorage:WaitForChild("sert"))
local Runner = load(ReplicatedStorage:WaitForChild("sert"):WaitForChild("roblox"):WaitForChild("Runner"))

if Runner.args() ~= nil then
	local package = ServerScriptService:FindFirstChild("Kohl's Admin")
	local config = if package then package:FindFirstChild("Config") else nil
	if config then
		config:SetAttribute("AutoUpdate", false)
	end
	sert.waitFor(function()
		return #Players:GetPlayers() > 0 and shared._K_INTERFACE and shared._K_INTERFACE.ready
	end, 20, "_K server interface ready")
	Runner.phase("server", "ready")
end

Runner.server(load(ReplicatedStorage:WaitForChild("Tests"):WaitForChild("Config")))
