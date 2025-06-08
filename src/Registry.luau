local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Hook = require(script.Parent.Hook)
local Util = require(script.Parent.Util)
local Type = require(script.Parent.Type)

--- @within Registry
--- @prop types { [string]: ArgumentType }

--- @within Registry
--- @prop commands { [string]: CommandDefinition }

--- @within Registry
--- @prop commandsList { CommandDefinition }

--- @class Registry
local Registry = {
	types = {} :: { [string]: Type.ArgumentType },
	commands = {},
	commandsList = {},
	commandNames = {},
}

--- Makes an Enum argument type definition
function Registry.makeEnumType(typeName: string, enumItems: { EnumItem | string })
	local suggestions = Util.Suggest.new(enumItems)
	return {
		displayName = typeName,
		validate = function(text)
			return Util.Suggest.query(text, suggestions)[1] ~= nil, `Invalid {typeName}`
		end,
		parse = function(text)
			return Util.Suggest.query(text, suggestions, enumItems)[1][3]
		end,
		suggestions = function(text)
			return suggestions, enumItems
		end,
	}
end

--- @within Registry
--- @type SequenceDefinition { constructor: (...any) -> any, parse: (...any) -> any, transform: (string) -> any, validate: (any) -> boolean, prefixes: { [string]: string } }
export type SequenceDefinition = {
	constructor: (...any) -> any,
	parse: (...any) -> any,
	transform: (string) -> any,
	validate: (any) -> boolean,
	prefixes: { [string]: string },
}

local function commandSort(a, b)
	if #a == #b then
		return a < b
	end
	return #a < #b
end

local debounceSort = Util.Function.debounce(0.2, table.sort)

local function cacheCommandNames(command)
	local name = string.lower(command.name)
	local oldCommand = table.find(Registry.commandNames, name)
	if oldCommand then
		oldCommand = Registry.commands[name]
		if oldCommand.aliases then
			for _, alias in oldCommand.aliases do
				table.remove(Registry.commandNames, table.find(Registry.commandNames, alias))
			end
		end
	else
		table.insert(Registry.commandNames, name)
	end

	if command.aliases then
		for _, alias in command.aliases do
			alias = string.lower(alias)
			table.insert(Registry.commandNames, alias)
		end
	end
	debounceSort(Registry.commandNames, commandSort)
end

--- Finds the command alias with the lowest Levenshtein distance to the provided alias.
function Registry.suggestCommandAlias(alias: string): string
	local suggestedAlias = ""
	local lowestDistance = math.huge
	for _, commandAlias in Registry.commandNames do
		local distance = Util.String.levenshteinDistance(alias, commandAlias)
		if distance < lowestDistance then
			lowestDistance = distance
			suggestedAlias = commandAlias
		end
		if distance == 0 then
			break
		end
	end

	return suggestedAlias
end

--- Makes an sequence argument type definition, useful for Color3, Vector3, etc
function Registry.makeSequenceType(definition: SequenceDefinition?)
	local options = definition or {}
	assert(options.parse ~= nil or options.constructor ~= nil, "Must provide one of: constructor, parse")

	options.transform = options.transform or function(...)
		return ...
	end
	options.validate = options.validate or function()
		return true
	end

	return {
		prefixes = options.prefixes,
		transform = function(text)
			return Util.Table.map(string.split(text, ","), function(text)
				return options.transform(text)
			end)
		end,
		validate = function(components)
			if options.length and #components > options.length then
				return false, `Maximum of {options.length} values allowed in sequence`
			end
			for i = 1, options.Length or #components do
				local valid, reason = options.validate(components[i], i)
				if not valid then
					return false, reason
				end
			end
			return true
		end,
		parse = options.parse or function(components)
			return options.constructor(unpack(components))
		end,
	}
end

--- Registers an argument type
function Registry.registerType(name: string, typeObject: Type.ArgumentType, override: Type.Dict?)
	assert(name and typeof(name) == "string", "Invalid type name: " .. typeof(name))
	assert(Registry.types[name] == nil, 'Type "' .. name .. '" already exists!')

	if override then
		for key, value in override do
			typeObject[key] = value
		end
	end

	typeObject.name = name
	typeObject.displayName = typeObject.displayName or name
	Registry.types[name] = typeObject
end

--- Registers a command
function Registry.registerCommand(_K: any, commandObject: Type.CommandDefinition)
	local lowerName = string.lower(commandObject.name)
	if not commandObject.name then
		return -- invalid commandObject definition
	end
	local oldCommand = Registry.commands[lowerName]
	if oldCommand and string.lower(oldCommand.name) == lowerName then
		print("Overriding Kohl's Admin command: " .. lowerName)
		local index = table.find(Registry.commandsList, oldCommand)
		if index then
			if not commandObject.group then
				commandObject.group = oldCommand.group
			end
			Registry.commandsList[index] = commandObject
		end
		if oldCommand.aliases then
			for _, alias in oldCommand.aliases do
				Registry.commands[string.lower(alias)] = nil
			end
		end
	elseif not oldCommand then
		table.insert(Registry.commandsList, commandObject)
	end

	commandObject.args = commandObject.args or {}
	for _, arg in commandObject.args :: any do
		if Registry.types[arg.type] then
			continue
		end
		if string.find(arg.type, "Enum.", 1, true) == 1 then
			local argType = arg.type
			local ok, enum = pcall(function()
				return (Enum :: any)[string.sub(argType, 6)]
			end)

			if not ok and string.find(argType, "s$") then
				argType = string.sub(argType, -2)
				ok, enum = pcall(function()
					return (Enum :: any)[string.sub(argType, 6)]
				end)
			end

			assert(ok, `Invalid Enum type: {arg.type}`)

			local enumType = Registry.makeEnumType(argType, enum:GetEnumItems())
			Registry.registerType(argType, enumType)
			Registry.registerType(argType .. "s", { listable = true }, enumType)
		elseif string.find(arg.type, "%S,%S") then
			local enumType = Registry.makeEnumType(arg.type, string.split(arg.type))
			Registry.registerType(arg.type, enumType)
			Registry.registerType(arg.type .. "s", { listable = true }, enumType)
		end
	end

	if RunService:IsServer() and type(commandObject.env) == "function" then
		commandObject.env = commandObject.env(_K)
	elseif not RunService:IsServer() and type(commandObject.envClient) == "function" then
		commandObject.env = commandObject.envClient(_K)
	end

	Registry.commands[lowerName] = commandObject
	Hook.commandRegistered:Fire(commandObject)
	task.defer(cacheCommandNames, commandObject)

	if commandObject.aliases then
		for _, alias in commandObject.aliases do
			alias = string.lower(alias)
			-- error if alias conflicts
			local conflict = Registry.commands[alias]
			assert(
				not conflict,
				`"{commandObject.name}" command alias "{alias}" conflicts with "{conflict and conflict.name}" command`
			)
			Registry.commands[alias] = commandObject
		end
	end
end

local aliases = {}
--- Registers a local command alias
function Registry.registerCommandAlias(_K: any, alias: string, command: string)
	print("command alias", alias, command)
	local oldAlias = aliases[alias]
	if not oldAlias and Registry.commands[string.lower(alias)] then
		warn("Command alias already exists")
		return
	end

	print("adding command alias", alias, command)

	Registry.registerCommand(_K, {
		name = alias,
		aliases = {},
		description = `Alias of "{command}"`,
		group = "Utility",
		args = {},
		runClient = function(context)
			context.Process.runCommands(context, Players.LocalPlayer, command)
		end,
	})
end

--- Registers a list of commands with the module name as the command group
function Registry.registerCommandModule(_K: any, commandModule: ModuleScript)
	local moduleResult = require(commandModule)
	local moduleList = #moduleResult > 0 and commandModule.Name
	local commandList = if moduleList then moduleResult else { moduleResult }

	for _, commandObject in commandList do
		if not commandObject.group then
			commandObject.group = commandModule.Name
		end
		Registry.registerCommand(_K, commandObject)
	end
end

return Registry
