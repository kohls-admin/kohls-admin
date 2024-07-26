local Players = game:GetService("Players")

local Argument = require(script.Parent.Argument)

local Command = {
	_K = nil,
	Argument = Argument,
}
Command.__index = Command

function Command.new(_K, commandDefinition, commandArray, from, text)
	return setmetatable({
		_K = _K,
		array = commandArray,
		definition = commandDefinition,
		from = from,
		fromPlayer = Players:GetPlayerByUserId(from),
		text = text,

		argIndex = 1,
		argLength = #commandDefinition.args,
		args = {},
		preparedArgs = {},
		-- flags = {};
		validated = false,
	}, Command)
end

function Command:run()
	if not self.validated then
		return false, "Command must be validated before it is run!"
	end

	local run = self.definition[if self._K.IsServer then "run" else "clientRun"]
	if not run then
		return
	end

	self._K.hook.preCommand:Fire(self)
	local ok, err = pcall(run, self, unpack(self.preparedArgs))
	self._K.hook.postCommand:Fire(self)

	return ok, err
end

function Command:validate()
	if self.validated then
		return true
	end
	-- start from 2 to skip the command name
	local commandArray = self.array
	for i = 2, #commandArray do
		local argPos, rawArg = unpack(commandArray[i])

		-- if last defined argument, concat the rest of the command's arguments
		if self.argIndex == self.argLength then
			local lastArg = commandArray[#commandArray]
			rawArg = string.sub(self.text, argPos, lastArg[1] + #lastArg[2])
		end

		local argDefinition = self.definition.args[self.argIndex]
		if not argDefinition then
			-- end of defined positional arguments
			break
		end

		if argDefinition.type == "stringGreedy" then
			rawArg = string.sub(self.text, argPos)
			self.greedy = true
		end

		local arg = Argument.new(self, argDefinition, argPos, rawArg)
		table.insert(self.args, arg)

		local prepared, feedback = arg:prepare()
		if not prepared then
			return false, feedback
		end
		table.insert(self.preparedArgs, prepared)

		if arg.exit == true or self.greedy then
			-- exit with immediate execution
			self.validated = true
			return true
		else
			-- TODO: need to step only if the argument is successful or optional
			-- how to handle optional arguments?!
			self.argIndex += 1
		end
	end
	-- TODO: verify that every defined non-optional argument is valid before full validation
	self.validated = true
	return true
end

return Command
