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
		return false, "Invalid tool"
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
		return _K.Util.Suggest.new(tools)
	end,
	prefixes = { ["^all$"] = "allTools" },
}

local function allParse()
	return #tools > 0 and tools, "No valid tool found"
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

		local function shouldIgnore(object)
			if object == nil then
				return
			end
			if object:HasTag("_K_Ignore") then
				return true
			end
			return shouldIgnore(object.Parent)
		end

		local function addTool(tool)
			if not (tool:IsA("Tool") or tool:IsA("HopperBin")) or shouldIgnore(tool) then
				return
			end
			for _, existingTool in tools do
				if existingTool.Name == tool.Name then
					return
				end
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

		registerSource(_K.Service.Lighting)
		registerSource(_K.Service.ReplicatedStorage)
		registerSource(_K.Service.ServerStorage)
		registerSource(_K.Service.StarterPack)

		_K.Remote.Tools.OnServerEvent:Connect(function(player)
			if _K.Auth.hasCommand(player.UserId, "tools") then
				local toolData = table.create(#tools)
				for i, tool in tools do
					toolData[i] = { Name = tool.Name }
				end
				_K.Remote.Tools:FireClient(player, toolData)
			end
		end)

		local toolData = table.create(#tools)
		for i, tool in tools do
			toolData[i] = { Name = tool.Name }
		end

		task.spawn(function()
			if not _K.ready then
				_K.Hook.init:Wait()
			end
			for _, player in _K.Service.Players:GetPlayers() do
				if _K.Auth.hasCommand(player.UserId, "tools") then
					_K.Remote.Tools:FireClient(player, toolData)
				end
			end
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
