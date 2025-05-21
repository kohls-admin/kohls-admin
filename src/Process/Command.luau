local Players = game:GetService("Players")

local Auth = require(script.Parent.Parent.Auth)
local Argument = require(script.Parent.Argument)
local Util = require(script.Parent.Parent.Util)
local Type = require(script.Parent.Parent.Type)

local Command = {
	Argument = Argument,
}
Command.__index = Command

function Command.new(_K, alias, definition: Type.CommandDefinition, array, from, text)
	return setmetatable({
		_K = _K,
		alias = alias,
		array = array,
		definition = definition,
		env = definition.env,
		from = from,
		fromPlayer = Players:GetPlayerByUserId(from),
		fromRank = Auth.getRank(from),
		text = text,
		undo = string.find(alias, "un", 1, true) == 1,

		args = definition.args and table.create(#definition.args) or {},
		preparedArgs = definition.args and table.create(#definition.args) or {},
		validated = false,
	}, Command)
end

function Command:shouldRequest(player: Player)
	if self._K._shouldRequestOverride then
		local value = self._K._shouldRequestOverride(self, player)
		if value ~= nil then
			return value
		end
	end
	return self.fromRank <= Auth.getRank(player.UserId)
end

function Command:requestCommand(player: Player)
	if not self.validated then
		return false
	end

	local userName = if player.Name == player.DisplayName then "" else " @" .. player.Name

	if not self.requested then
		self.requested = {}
	end
	local requested = self.requested[player]
	self.requested[player] = true
	if not requested then
		self._K.Remote.Notify:FireClient(self.fromPlayer, {
			Text = `Requesting <b>{self.alias}</b> command on <b>{player.DisplayName}<font transparency="0.5">{userName}</font></b>.`,
		})
	end

	local accepted = self._K.Remote.RequestCommand:InvokeClient(
		player,
		self.fromPlayer,
		`{self._K.Data.settings.prefix}{self.alias} {player.Name}`
	)

	local status = if accepted
		then "<font color='#0f0'>accepted</font>"
		elseif accepted == false then "<font color='#f00'>denied</font>"
		else "<font transparency='0.5'>already in progress</font>"

	if not requested then
		self._K.Remote.Notify:FireClient(
			self.fromPlayer,
			{ Text = `Command request for <b>{self.alias}</b> was <b>{status}</b>.`, From = player.UserId }
		)
	end

	return accepted
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
				if prepared == nil then
					continue
				end

				if typeof(prepared) == "Instance" then
					if arg == self.fromPlayer then
						continue -- don't request self
					end
					if self:shouldRequest(arg) then
						local accepted = self:requestCommand(arg)
						if not accepted then
							return false, "Command request denied."
						end
					end
				else -- table?
					for i, player in prepared do
						if player == self.fromPlayer then
							continue -- don't request self
						end
						if self:shouldRequest(player) then
							prepared[i] = nil
							task.spawn(function()
								local accepted = self:requestCommand(player)
								if accepted then
									-- these ignore hooks, clone self in the future to allow for hooks?
									local soloPrepared = table.clone(self.preparedArgs)
									soloPrepared[argIndex] = { player }
									pcall(run, self, unpack(soloPrepared))
								end
							end)
						end
					end
				end
			end
		end
	end

	self._K.Hook.preCommand:Fire(self)
	if not self.validated then
		return false, self.Error
	end

	local ok, err = pcall(run, self, unpack(self.preparedArgs))
	self.Ran = ok
	self.Error = err
	self._K.Hook.postCommand:Fire(self)

	return ok, err
end

function Command:validate()
	if self.validated then
		return true
	end

	-- always try first argument
	if #self.definition.args > 0 and #self.array < 2 then
		self.text ..= " "
		self.array[2] = { #self.text, "" }
	end

	local filledSelf
	local arrayIndex = 2
	for index, definition in self.definition.args do
		local data = self.array[arrayIndex]
		local hasArgument = self._K.Auth.hasArgument(self.from, definition)

		if not data then
			if definition.optional or not hasArgument then
				continue
			end
			local start = self.array[1][1]
			self.invalidPos = start
			self.invalidArg = string.sub(self.text, start, start + #self.text)
			self.argMissing = `Argument {index} missing: {definition.name}`
			return false, self.argMissing
		end

		if not hasArgument then
			continue
		end

		local argPos, rawArg = unpack(data)

		if index == #self.definition.args then
			local buffer = table.create(#self.array - arrayIndex)
			for i = arrayIndex, #self.array do
				table.insert(buffer, self.array[i][2])
			end
			rawArg = table.concat(buffer, " ")
		end

		local shouldFillWithSelf = not filledSelf
			and index ~= #self.definition.args
			and string.find(string.lower(definition.type), "player", 1, true)

		if shouldFillWithSelf and self._K.IsClient then
			local argType = self._K.Registry.types[definition.type]
			if argType and argType.suggestions then
				local suggestions = Util.Suggest.query(rawArg, argType.suggestions(rawArg, self.from, definition))
				if #suggestions > 0 then
					shouldFillWithSelf = false
				end
			end
		end

		if shouldFillWithSelf and arrayIndex == #self.array then
			local arg = self.definition.args[index + 1]
			if arg and string.find(string.lower(arg.type), "player", 1, true) then
				rawArg = "me"
				arrayIndex -= 1
				filledSelf = true
			end
		end

		local arg = Argument.new(self, definition, argPos, rawArg)
		local ok, result = arg:prepare()

		if not (ok or filledSelf) and shouldFillWithSelf then
			arg = Argument.new(self, definition, argPos, "me")
			ok, result = arg:prepare()
			arrayIndex -= 1
			filledSelf = true
		end

		self.args[index] = arg

		if ok then
			arrayIndex += 1
			self.preparedArgs[index] = result
		elseif not definition.optional or index == #self.definition.args then
			if result then
				self.invalidArg = result.arg
				self.invalidPos = result.pos
				self.invalidMessage = result.message
			end
			return false, result.message or "Argument failed to prepare"
		end
	end

	self.validated = true
	return true
end

return Command
