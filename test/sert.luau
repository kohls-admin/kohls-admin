--!strict
--[[
	sert, the test framework, for the specs: they require it by path (`../sert` from test/unit), which works in both
	runtimes because the test place lays out `test` as the checkout has it. Headless Luau loads the fetched toolkit
	through the `sert` alias in `.luaurc` (`.sert/sert/src`, from `python3 tools/sert.py fetch`); in Roblox it is the
	package mapped at `ReplicatedStorage.sert`, whose runner (`sert.roblox.Runner`) runs the suite in Studio.
]]

if game ~= nil then
	local load: (Instance) -> any = require
	return load(game:GetService("ReplicatedStorage"):WaitForChild("sert")) :: Sert
end

local sert = require("@sert")
type Sert = typeof(sert)
assert(type(sert) == "table", "sert module must return a table")

return sert
