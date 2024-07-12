-- local RunService = game:GetService("RunService")

-- local Util = require(script.Parent.Util)

type Dict = { [any]: any }

local module = {
	_K = nil,
	hooks = {},
	types = {},
	commands = {},
	commandsList = {},
}

function module.registerHook(key: string, mutable: boolean?)
	if module.hooks[key] then
		warn('Hook "' .. key .. '" already exists')
		return
	end
	local signalType = if mutable and module._K.settings.mutableHooks:get() then "SignalFast" else "SignalGood"
	module.hooks[key] = module._K.Util[signalType].new()
end

function module.registerType(name: string, typeObject: Dict, override: Dict?)
	assert(name and typeof(name) == "string", "Invalid type name: " .. typeof(name))
	assert(string.find(name, "^%w*$"), 'Invalid type name: "' .. name .. '", type names must be alphanumeric!')
	assert(module.types[name] == nil, 'Type "' .. name .. '" already exists!')

	typeObject.displayName = typeObject.displayName or name
	module.types[name] = typeObject

	if override then
		for key, value in override do
			typeObject[key] = value
		end
	end
end

function module.registerCommand(commandObject)
	local oldCommand = module.commands[string.lower(commandObject.name)]
	if oldCommand then
		local index = table.find(module.commandsList, oldCommand)
		if index then
			module.commandsList[index] = commandObject
		end
		if oldCommand.aliases then
			for _, alias in oldCommand.aliases do
				module.commands[string.lower(alias)] = nil
			end
		end
	elseif not oldCommand then
		table.insert(module.commandsList, commandObject)
	end

	module.commands[string.lower(commandObject.name)] = commandObject

	if commandObject.aliases then
		for _, alias in commandObject.aliases do
			-- error if alias conflicts
			local conflict = module.commands[string.lower(alias)]
			assert(
				not conflict,
				`"{commandObject.name}" command alias "{alias}" conflicts with "{conflict and conflict.name}" command`
			)
			module.commands[string.lower(alias)] = commandObject
		end
	end
end

local aliases = {}
function module.registerCommandAlias(alias, command)
	local oldAlias = aliases[alias]
	if not oldAlias and module.commands[string.lower(alias)] then
		warn("Command alias already exists")
		return
	end

	module.registerCommand {
		name = alias,
		aliases = {},
		description = `Alias of "{command}"`,
		group = "Local",
		args = {},
		clientRun = function(context)
			context.Process.runCommands(game.Players.LocalPlayer, command)
		end,
	}
end

-- TODO: handle replication of the entire module and stuff?
function module.registerCommandModule(commandModule)
	local moduleResult = require(commandModule)
	local moduleList = #moduleResult > 0 and commandModule.Name
	local commandList = if moduleList then moduleResult else { moduleResult }

	for _, commandObject in commandList do
		-- TODO: check for server method definition & overwrite run method?
		module.registerCommand(commandObject)
	end

	--commandModule.Parent = module.Replicated.commands
end

return module
