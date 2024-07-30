local Players = game:GetService("Players")

local Argument = require(script.Parent.Argument)

local Command = {
	Argument = Argument,
	OPTIONAL = Argument.OPTIONAL,
}
Command.__index = Command

function Command.new(_K, commandDefinition, commandArray, from, text)
	return setmetatable({
		_K = _K,
		array = commandArray,
		definition = commandDefinition,
		envClient = commandDefinition and commandDefinition.envClient,
		env = commandDefinition and commandDefinition.env,
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

	local run = self.definition[if self._K.IsServer then "run" else "runClient"]
	if not run then
		return
	end

	-- filter args for shouldRequest
	-- TODO: silently fail for userids of lowerRank/shouldRequest
	if self._K.IsServer then
		for argIndex, arg in self.args do
			if arg.definition.shouldRequest and string.find(string.lower(arg.rawType.name), "player", 1, true) then
				-- use instead of lowerRank to request the command to those who aren't higher rank
				local prepared = self.preparedArgs[argIndex]
				if prepared == Argument.OPTIONAL then
					continue
				end

				local rank = self._K.Auth.getRank(self.fromPlayer.UserId)

				if typeof(prepared) == "Instance" then
					if arg == self.fromPlayer then
						continue -- don't request self
					end
					if rank <= self._K.Auth.getRank(arg.UserId) then
						local accepted = self._K.Remote.RequestCommand:InvokeClient(arg, self.fromPlayer, self.text)
						if not accepted then
							return false, "Command request denied."
						end
					end
				else -- table?
					for i, player in prepared do
						if player == self.fromPlayer then
							continue -- don't request self
						end
						if arg ~= Argument.OPTIONAL and rank <= self._K.Auth.getRank(player.UserId) then
							prepared[i] = nil
							task.spawn(function()
								local accepted =
									self._K.Remote.RequestCommand:InvokeClient(player, self.fromPlayer, self.text)
								if accepted then
									-- these ignore hooks, clone self in the future to allow for hooks?
									local soloPrepared = table.clone(self.preparedArgs)
									soloPrepared[argIndex] = { player }
									pcall(run, self, unpack(soloPrepared))
								end
							end)
						end
					end
					if #prepared == 0 then
						return true
					end
				end
			end
		end
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

		local ok, result = arg:prepare()
		if not ok then
			return false, result or "Argument failed to prepare"
		end
		table.insert(self.preparedArgs, result)

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
