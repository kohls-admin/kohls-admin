--!strict
--[[
	Studio test runner, server side (`test/test.project.json`): ensures the local Kohl's Admin package initializes
	without attempting remote asset auto-update, waits for the solo player and `_K.ready`, and coordinates the Studio
	suite across server and client via `sert.roblox.Runner`.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local load: (Instance) -> any = require
local Runner = load(ReplicatedStorage:WaitForChild("sert"):WaitForChild("roblox"):WaitForChild("Runner"))

if Runner.args() ~= nil then
	local package = ServerScriptService:FindFirstChild("Kohl's Admin")
	local config = if package then package:FindFirstChild("Config") else nil
	if config then
		config:SetAttribute("AutoUpdate", false)
	end
end

Runner.server(load(ReplicatedStorage:WaitForChild("Tests"):WaitForChild("Config")))
