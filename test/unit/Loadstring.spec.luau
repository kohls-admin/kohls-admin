local Harness = require("./Harness")
local sert = require("../sert")

local describe, test = sert.describe, sert.test
local prop = sert.prop

describe("Server · LoadScript & Loadstring (Yueliang + FiOne Differential Oracle)", function()
	local OPS = { "+", "-", "*" }

	local function getLoadModules()
		local h = Harness.shared()
		local LoadScriptMod = h.Server:WaitForChild("LoadScript")
		local Loadstring = h.env:require(LoadScriptMod:WaitForChild("Loadstring"))
		local LoadScript = h.env:require(LoadScriptMod)
		return Loadstring, LoadScript
	end

	test("compiles and executes closures, upvalues, loops, tables, varargs, and LuaC bytecode dump", function()
		local Loadstring, LoadScript = getLoadModules()
		local source = [[
			local function makeCounter(start, step)
				local acc = start
				return function(...)
					for i = 1, select("#", ...) do
						acc = acc + select(i, ...) * step
					end
					return acc
				end
			end
			local c = makeCounter(10, 2)
			local t = { a = c(1, 2, 3), b = c(4) }
			return t.a * 100 + t.b
		]]

		local envTable = setmetatable({}, { __index = _G })
		local fnProto, errProto = Loadstring(source, envTable)
		sert.eq(errProto, nil)
		sert.eq(type(fnProto), "function")
		sert.eq(fnProto(), 2230)

		-- Also test the "LuaC" bytecode dump + bc_to_state path
		local fnBc, bytecode = Loadstring(source, "LuaC")
		sert.eq(type(bytecode), "string")
		sert.eq(string.find(bytecode, "\27Lua", 1, true) ~= nil, true)
		sert.eq(fnBc(), 2230)

		-- Also test LoadScript creating a Server / Client Script instance with Code attribute
		local createdServer = LoadScript("return 1 + 1", "Server")
		sert.eq(createdServer ~= nil, true)
		sert.eq(string.find(createdServer:GetAttribute("Code"), "\27Lua", 1, true) ~= nil, true)
		sert.eq(createdServer.Enabled, true)

		-- Syntax errors return nil, errorMessage
		local badFn, badErr = Loadstring("local x = == invalid syntax", envTable)
		sert.eq(badFn, nil)
		sert.eq(type(badErr), "string")
	end)

	prop("differential oracle: Yueliang + FiOne matches native Luau loadstring on generated programs", function(g)
		local Loadstring = getLoadModules()
		local a = g:int(-50, 50)
		local b = g:int(-50, 50)
		local c = g:int(1, 15)
		local loopN = g:int(1, 8)
		local op = g:pick(OPS)

		local program = string.format(
			[[
			local x = %d
			local y = %d
			local z = %d
			local sum = 0
			for i = 1, %d do
				if (i %% 2) == 0 then
					sum = sum + (x %s i)
				else
					sum = sum - (y + z)
				end
			end
			local tbl = { sum, x + y, z * 2 }
			return tbl[1] + tbl[2] - tbl[3]
		]],
			a,
			b,
			c,
			loopN,
			op
		)

		local envTable = setmetatable({}, { __index = _G })
		local kaFn, kaErr = Loadstring(program, envTable)
		sert.eq(kaErr, nil)
		local nativeFn = assert((loadstring :: any)(program))

		sert.eq(kaFn(), nativeFn())
	end, { runs = 60 })

	test("LoadScript caches up to 64 compiled scripts before clearing cache", function()
		local h = Harness.newEnv()
		local LoadScriptMod = h.Server:WaitForChild("LoadScript")
		local luaU = h.env:require(LoadScriptMod:WaitForChild("Loadstring"):WaitForChild("LuaU"))
		local dumpSpy = sert.spy(luaU, "dump")
		local LoadScript = h.env:require(LoadScriptMod)

		for i = 1, 64 do
			local created = LoadScript(`return {i}`, "Server")
			sert.eq(created ~= nil, true)
		end
		sert.eq(dumpSpy.callCount, 64)

		-- 64th cached entry must still hit without clearing or recompiling
		LoadScript("return 1", "Server")
		sert.eq(dumpSpy.callCount, 64)

		-- Adding a 65th unique source evicts the cache, so a previously cached source recompiles
		LoadScript("return 65", "Server")
		sert.eq(dumpSpy.callCount, 65)
		LoadScript("return 65", "Server")
		sert.eq(dumpSpy.callCount, 65)
		LoadScript("return 1", "Server")
		sert.eq(dumpSpy.callCount, 66)

		dumpSpy:restore()
	end)
end)

return {}
