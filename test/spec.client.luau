--!strict
--[[
	Kohl's Admin unified test entry: one suite, two runtimes.

	* Headless: `python3 tools/sert.py run` (`luau test/spec.client.luau` after staging `default.project.json` into
	  `.sert/stage`). `rtest()` tests are skipped; all pure, sandbox (`sert.env`), and multi-server simulator (`sert.sim`)
	  specs run in milliseconds.
	* Studio: `python3 tools/sert.py studio` builds and plays `test/test.project.json`, where `test/runner/` loads
	  the same specs through `sert.roblox.Runner` on both server and client.
]]

local IS_ROBLOX = game ~= nil

local load: (Instance) -> any = require
local ReplicatedStorage = if IS_ROBLOX then game:GetService("ReplicatedStorage") else nil
local tests = if ReplicatedStorage then ReplicatedStorage:WaitForChild("Tests") else nil
local sert: typeof(require("@sert")) = if ReplicatedStorage
	then load(ReplicatedStorage:WaitForChild("sert"))
	else require("@sert")
if tests then
	load(tests:WaitForChild("kohls-admin"):WaitForChild("test"):WaitForChild("unit"))
else
	require("./unit")
end

assert(type(sert.run) == "function", "sert.run must be a function")
return sert.run(if IS_ROBLOX then {} else sert.parseCliArgs(...))
