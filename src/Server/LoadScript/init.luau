local ServerScriptService = game:GetService("ServerScriptService")

local Loadstring = require(script.Loadstring)
local FiOne = script.Loadstring.FiOne

local BASE = {
	Client = script.ClientBase,
	Server = script.ServerBase,
}

local bytecodeCache = {}
local function Bytecode(source: string)
	if bytecodeCache[source] then
		return bytecodeCache[source]
	end
	local _f, code = Loadstring(source, "LuaC")
	bytecodeCache[source] = code
	return code
end

return function(source: string, base: "Client" | "Server", clientParent: Instance?)
	local scriptBase = BASE[base]
	if not scriptBase then
		return
	end

	local bytecode = Bytecode(source)
	assert(
		string.find(bytecode, "\27Lua"),
		`{base} Script unable to be created: {string.gsub(bytecode, "Loadstring%.LuaX:%d+:", "")}`
	)

	local new = scriptBase:Clone()
	new:SetAttribute("Code", bytecode)
	if not clientParent then
		new:SetAttribute("Source", source)
	end

	FiOne:Clone().Parent = new
	new.Parent = clientParent or ServerScriptService
	new.Enabled = true

	return new
end
