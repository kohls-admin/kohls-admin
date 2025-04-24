local _K
local tools = {}

local typeTool = {
	validate = function(input: string, from: number): (boolean, string?)
		local query = string.lower(input)
		for _, tool in tools do
			if string.find(string.lower(tool.Name), query, 1, true) == 1 then
				return true
			end
		end
		return false, "Invalid tool."
	end,
	parse = function(input: string, from: number): Tool
		local query = string.lower(input)
		for _, tool in tools do
			if string.lower(tool.Name) == query then
				return tool
			end
		end
		for _, tool in tools do
			if string.find(string.lower(tool.Name), query, 1, true) == 1 then
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
	prefixes = { all = "allTools" },
}

local function allParse()
	return #tools > 1 and tools, "No valid tool found"
end

local typeAllTools = {
	listable = true,
	transform = string.lower,
	validate = allParse,
	parse = allParse,
}

return function(context)
	_K = context

	if _K.IsServer then
		local function sortName(a, b)
			return a.Name > b.Name
		end
		local debounceSort = _K.Util.Function.debounce(0.2, function()
			table.sort(tools, sortName)
		end)

		local function addTool(tool)
			if
				not (tool:IsA("Tool") or tool:IsA("HopperBin"))
				or tool:HasTag("_K_Ignore")
				or tool.Parent:HasTag("_K_Ignore")
			then
				return
			end
			table.insert(tools, tool)
			debounceSort()
		end

		local function registerSource(source)
			for _, tool in source:GetDescendants() do
				addTool(tool)
			end
			source.DescendantAdded:Connect(addTool)
		end

		registerSource(_K.Util.Services.Lighting)
		registerSource(_K.Util.Services.ReplicatedStorage)
		registerSource(_K.Util.Services.ServerStorage)
		registerSource(_K.Util.Services.StarterPack)

		_K.Remote.Tools.OnServerEvent:Connect(function(player)
			local toolData = table.create(#tools)
			for i, tool in tools do
				toolData[i] = { Name = tool.Name }
			end
			_K.Remote.Tools:FireClient(player, toolData)
		end)
	else -- Client
		_K.Remote.Tools.OnClientEvent:Connect(function(toolData)
			tools = toolData
			_K.tools = tools
			table.insert(tools, 1, { Name = "all" })
		end)
		_K.Remote.Tools:FireServer()
	end

	_K.Registry.registerType("tool", typeTool)
	_K.Registry.registerType("tools", { listable = true }, typeTool)
	_K.Registry.registerType("allTools", typeAllTools)
end
