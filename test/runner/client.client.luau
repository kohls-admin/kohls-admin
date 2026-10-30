--!strict
--[[
	Studio test runner, client side (`test/test.project.json`): waits for the server to hand off the run, executes
	the client-side `Studio · Client · ` specs against the live `_K` client instance, and reports back.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- this runs from ReplicatedFirst, before the rest of the place replicates, and the runner's string requires
-- ("../core/runner") don't wait for their modules
if not game:IsLoaded() then
	game.Loaded:Wait()
end

local load: (Instance) -> any = require
local Runner = load(ReplicatedStorage:WaitForChild("sert"):WaitForChild("roblox"):WaitForChild("Runner"))
Runner.client(load(ReplicatedStorage:WaitForChild("Tests"):WaitForChild("Config")))
