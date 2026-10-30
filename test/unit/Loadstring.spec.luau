local Harness = require("./Harness")
local sert = require("../sert")

local describe, test, expect = sert.describe, sert.test, sert.expect
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
		expect(errProto).toBeNil()
		expect(type(fnProto)).toBe("function")
		expect(fnProto()).toBe(2230)

		-- Also test the "LuaC" bytecode dump + bc_to_state path
		local fnBc, bytecode = Loadstring(source, "LuaC")
		expect(type(bytecode)).toBe("string")
		expect(string.find(bytecode, "\27Lua", 1, true) ~= nil).toBe(true)
		expect(fnBc()).toBe(2230)

		-- Also test LoadScript creating a Server / Client Script instance with Code attribute
		local createdServer = LoadScript("return 1 + 1", "Server")
		expect(createdServer ~= nil).toBe(true)
		expect(string.find(createdServer:GetAttribute("Code"), "\27Lua", 1, true) ~= nil).toBe(true)
		expect(createdServer.Enabled).toBe(true)

		-- Syntax errors return nil, errorMessage
		local badFn, badErr = Loadstring("local x = == invalid syntax", envTable)
		expect(badFn).toBeNil()
		expect(type(badErr)).toBe("string")
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
		expect(kaErr).toBeNil()
		local nativeFn = assert((loadstring :: any)(program))

		expect(kaFn()).toBe(nativeFn())
	end, { runs = 60 })
end)

return {}
