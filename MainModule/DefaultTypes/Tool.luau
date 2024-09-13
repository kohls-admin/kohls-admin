local _K
local tools = {}

local function addTool(tool)
	if not (tool:IsA("Tool") or tool:IsA("HopperBin")) then
		return
	end
	table.insert(tools, tool)
end

local typeTool = {
	validate = function(input: string, from: number): (boolean, string?)
		local query = string.lower(input)
		for _, tool in tools do
			if string.find(string.lower(tool.Name), query) == 1 then
				return true
			end
		end
		return false, "Invalid tool."
	end,
	parse = function(input: string, from: number): string
		local query = string.lower(input)
		for _, tool in tools do
			if string.find(string.lower(tool.Name), query) == 1 then
				return tool
			end
		end
		error("Invalid tool value")
	end,
	suggestions = function(text: string, from: number)
		return _K.Util.Suggest.query(text, _K.Util.Suggest.new(tools))
	end,
	log = function(arg)
		return _K.Util.Table.concat(arg.parsedArgs, ",")
	end,
}

return function(context)
	_K = context

	if _K.IsServer then
		for _, tool in _K.Util.Services.Lighting:GetDescendants() do
			addTool(tool)
		end
		for _, tool in _K.Util.Services.ServerStorage:GetDescendants() do
			addTool(tool)
		end
		table.sort(tools, function(a, b)
			return a.Name > b.Name
		end)
		_K.Remote.Tools.OnServerEvent:Connect(function(player)
			local toolData = table.create(#tools)
			for i, tool in tools do
				toolData[i] = { Name = tool.Name }
			end
			_K.Remote.Tools:FireClient(player, toolData)
		end)
	else
		_K.Remote.Tools.OnClientEvent:Connect(function(toolData)
			tools = toolData
		end)
		_K.Remote.Tools:FireServer()
	end

	_K.Registry.registerType("tool", typeTool)
	_K.Registry.registerType("tools", { listable = true }, typeTool)
end
