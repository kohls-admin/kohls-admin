local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Hook = require(script.Parent.Hook)
local Util = require(script.Parent.Util)

type Dict = { [any]: any }

type Environment = {} | (_K: any) -> {}

--- @within Registry
--- @type ArgumentFunction (value: any, from: Player) -> ...any
export type ArgumentFunction = (value: any, from: Player) -> ...any

--- @within Registry
--- @type ArgumentType {name: string, displayName: string?, listable: boolean?, filterLog: boolean?, transform: ArgumentFunction?, validate: ArgumentFunction, parse: ArgumentFunction, preParse: ArgumentFunction?, postParse: ArgumentFunction?, suggestions: ArgumentFunction?, prefixes: { [string]: string }? }
export type ArgumentType = {
	name: string?,
	displayName: string?,
	listable: boolean?,
	filterLog: boolean?,
	transform: ArgumentFunction?,
	validate: ArgumentFunction?,
	parse: ArgumentFunction?,
	preParse: ArgumentFunction?,
	postParse: ArgumentFunction?,
	suggestions: ArgumentFunction?,
	prefixes: { [string]: string }?,
}

--- @within Registry
--- @type ArgumentDefinition {type: string, name: string, description: string, optional: boolean?, lowerRank: boolean?, ignoreSelf: boolean?, shouldRequest: boolean? }
export type ArgumentDefinition = {
	type: string,
	name: string,
	description: string,
	optional: boolean?,
	-- player type options
	lowerRank: boolean?,
	ignoreSelf: boolean?,
	shouldRequest: boolean?,
}

--- @within Registry
--- @type CommandDefinition {name: string, aliases: { string }?, description: string, group: string, noLog: boolean?, args: { ArgumentDefinition }, envClient: {} | () -> {}?, env: {} | () -> {}?, runClient: (...any) -> ()?, run: (...any) -> ()? }
export type CommandDefinition = {
	name: string,
	aliases: { string }?,
	description: string,
	group: string,
	noLog: boolean?,
	args: { ArgumentDefinition }?,
	envClient: Environment?,
	env: Environment?,
	runClient: (...any) -> ()?,
	run: (...any) -> ()?,
}

--- @within Registry
--- @prop types { [string]: ArgumentType }

--- @within Registry
--- @prop commands { [string]: CommandDefinition }

--- @within Registry
--- @prop commandsList { CommandDefinition }

--- @class Registry
local Registry = {
	types = {} :: { [string]: ArgumentType },
	commands = {},
	commandsList = {},
}

--- Makes an Enum command type definition
function Registry.makeEnumType(typeName: string, enumItems: { EnumItem | string })
	local suggestions = Util.Suggest.new(enumItems)
	return {
		displayName = typeName,
		validate = function(text)
			return Util.Suggest.query(text, suggestions)[1] ~= nil, `Invalid {typeName}`
		end,
		parse = function(text)
			return Util.Suggest.query(text, suggestions, enumItems)[1][2]
		end,
		suggestions = function(text)
			return Util.Suggest.query(text, suggestions, enumItems)
		end,
	}
end

--- Registers a command type
function Registry.registerType(name: string, typeObject: ArgumentType, override: Dict?)
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
function Registry.registerCommand(_K: any, commandObject: CommandDefinition)
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
		if not Registry.types[arg.type] and string.find(arg.type, "Enum.", 1, true) == 1 then
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
		end
	end

	if RunService:IsServer() and type(commandObject.env) == "function" then
		commandObject.env = commandObject.env(_K)
	elseif not RunService:IsServer() and type(commandObject.envClient) == "function" then
		commandObject.env = commandObject.envClient(_K)
	end

	Registry.commands[lowerName] = commandObject
	Hook.commandRegistered:Fire(commandObject)

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
