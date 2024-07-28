local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- local Util = require(script.Parent.Util)

type Dict = { [any]: any }

--- @within Registry
--- @type ArgumentFunction (value: any, from: Player) -> ...any
export type ArgumentFunction = (value: any, from: Player) -> ...any

--- @within Registry
--- @type ArgumentType { displayName: string?, listable: boolean?, transform: ArgumentFunction?, validate: ArgumentFunction, parse: ArgumentFunction, preParse: ArgumentFunction?, postParse: ArgumentFunction?, suggestions: ArgumentFunction?, prefixes: { [string]: string }? }
export type ArgumentType = {
	displayName: string?,
	listable: boolean?,
	transform: ArgumentFunction?,
	validate: ArgumentFunction,
	parse: ArgumentFunction,
	preParse: ArgumentFunction?,
	postParse: ArgumentFunction?,
	suggestions: ArgumentFunction?,
	prefixes: { [string]: string }?,
}

--- @within Registry
--- @type ArgumentDefinition { type: string, name: string, description: string, lowerRank: boolean? }
export type ArgumentDefinition = {
	type: string,
	name: string,
	description: string,
	lowerRank: boolean?,
}

--- @within Registry
--- @type CommandDefinition { name: string, aliases: { string }?, description: string, group: string, args: { ArgumentDefinition }, runClient: (...any) -> ()?, run: (...any) -> ()? }
export type CommandDefinition = {
	name: string,
	aliases: { string }?,
	description: string,
	group: string,
	args: { ArgumentDefinition },
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

--- Registers a command type
function Registry.registerType(name: string, typeObject: ArgumentType, override: Dict?)
	assert(name and typeof(name) == "string", "Invalid type name: " .. typeof(name))
	assert(string.find(name, "^%w*$"), 'Invalid type name: "' .. name .. '", type names must be alphanumeric!')
	assert(Registry.types[name] == nil, 'Type "' .. name .. '" already exists!')

	typeObject.displayName = typeObject.displayName or name
	Registry.types[name] = typeObject

	if override then
		for key, value in override do
			typeObject[key] = value
		end
	end
end

--- Registers a command
function Registry.registerCommand(commandObject: CommandDefinition)
	if not commandObject.name then
		return -- invalid commandObject definition
	end
	local oldCommand = Registry.commands[string.lower(commandObject.name)]
	if oldCommand then
		local index = table.find(Registry.commandsList, oldCommand)
		if index then
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

	Registry.commands[string.lower(commandObject.name)] = commandObject

	if commandObject.aliases then
		for _, alias in commandObject.aliases do
			-- error if alias conflicts
			local conflict = Registry.commands[string.lower(alias)]
			assert(
				not conflict,
				`"{commandObject.name}" command alias "{alias}" conflicts with "{conflict and conflict.name}" command`
			)
			Registry.commands[string.lower(alias)] = commandObject
		end
	end
end

local aliases = {}
--- Registers a local command alias
function Registry.registerCommandAlias(alias: string, command: string)
	print("command alias", alias, command)
	local oldAlias = aliases[alias]
	if not oldAlias and Registry.commands[string.lower(alias)] then
		warn("Command alias already exists")
		return
	end

	print("adding command alias", alias, command)

	Registry.registerCommand {
		name = alias,
		aliases = {},
		description = `Alias of "{command}"`,
		group = "Utility",
		args = {},
		runClient = function(context)
			context.Process.runCommands(context, Players.LocalPlayer, command)
		end,
	}
end

--- Registers a list of commands with the module name as the command group
function Registry.registerCommandModule(commandModule: ModuleScript)
	local moduleResult = require(commandModule)
	local moduleList = #moduleResult > 0 and commandModule.Name
	local commandList = if moduleList then moduleResult else { moduleResult }

	for _, commandObject in commandList do
		commandObject.group = commandModule.Name
		Registry.registerCommand(commandObject)
	end
end

return Registry
