--[[
	Credit to einsteinK.
	Credit to Stravant for LBI.
	
	Credit to the creators of all the other modules used in this.
	
	Sceleratis was here and decided modify some things.
	
	einsteinK was here again to fix a bug in LBI for if-statements
--]]

local waitDeps = {
	"Rerubi",
	"LuaK",
	"LuaP",
	"LuaU",
	"LuaX",
	"LuaY",
	"LuaZ",
}

for i, v in pairs(waitDeps) do
	script:WaitForChild(v)
end

local luaX = require(script.LuaX)
local luaY = require(script.LuaY)
local luaZ = require(script.LuaZ)
local luaU = require(script.LuaU)
local Rerubi = require(script.Rerubi)

luaX:init()
local LuaState = {}

return function(str, env)
	local f, writer, buff
	local ran, error = pcall(function()
		local zio = luaZ:init(luaZ:make_getS(str), nil)
		if not zio then
			return error()
		end
		local func = luaY:parser(LuaState, zio, nil, "@input")
		writer, buff = luaU:make_setS()
		luaU:dump(LuaState, func, writer, buff)
		f = Rerubi(buff.data, env)
	end)
	if ran then
		return f, buff.data
	else
		return nil, error
	end
end
