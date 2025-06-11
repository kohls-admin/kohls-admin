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
	local rank, role = Auth.getRank(from)
	_K.Data.targetLimits[from] = nil
	return setmetatable({
		_K = _K,
		alias = alias,
		array = array,
		definition = definition,
		env = definition.env,
		from = from,
		fromPlayer = Players:GetPlayerByUserId(from),
		fromRank = rank,
		fromRole = role,
		rank = Auth.hasCommand(from, definition) or 0,
		text = text,
		undo = string.find(alias, "un", 1, true) == 1,

		args = definition.args and table.create(#definition.args) or {},
		preparedArgs = definition.args and table.create(#definition.args) or {},
		validated = false,
	}, Command)
end

function Command:shouldRequest(player: Player)
	if self._K.Data.settings.commandRequests == false then
		return false
	end
	if self._K._shouldRequestOverride then
		return self._K._shouldRequestOverride(self, player)
	end
	return self.from ~= self._K.creatorId and self.rank <= Auth.getRank(player.UserId)
end

function Command:requestCommand(targetPlayer: Player, args, run)
	if not self.validated then
		return false, self.Error or "Command must be validated before it is run!"
	end

	local userName = if targetPlayer.Name == targetPlayer.DisplayName then "" else " @" .. targetPlayer.Name

	self._K.Remote.Notify:FireClient(self.fromPlayer, {
		Text = `Requesting <b>{self.alias}</b> command on <b>{targetPlayer.DisplayName}<font transparency="0.5">{userName}</font></b>.`,
	})

	local accepted = self._K.Remote.RequestCommand:InvokeClient(
		targetPlayer,
		self.fromPlayer,
		`{self._K.getCommandPrefix()}{self.alias} {targetPlayer.Name}`
	)

	local validColor = self._K.Data.settings.themeValid:ToHex()
	local invalidColor = self._K.Data.settings.themeInvalid:ToHex()
	local status = if accepted
		then `<font color='#{validColor}'>accepted</font>`
		else `<font color='#{invalidColor}'>denied</font>`
	self._K.Remote.Notify:FireClient(
		self.fromPlayer,
		{ Text = `Command request for <b>{self.alias}</b> was <b>{status}</b>.`, From = targetPlayer.UserId }
	)

	if accepted then
		self._K.Hook.preCommand:Fire(self)
		local _ok, err = pcall(run, self, unpack(args))
		if err then
			self._K.Remote.Notify:FireClient(self.fromPlayer, {
				Text = `<b>"{self.alias}" command failed:</b> {err}`,
				From = "_K",
				TextColor3 = Color3.new(1, 0, 0),
				Sound = "Call_Leave",
			})
		end
		-- TODO: log the command request!
		self._K.Hook.postCommand:Fire(self)
	end

	return
end

function Command:run()
	if not self.validated then
		return false, self.Error or "Command must be validated before it is run!"
	end

	local run = self.definition[if self._K.IsServer then "run" else "runClient"]
	if not run then
		return
	end

	if self._K.IsServer and self._K.Data.settings.commandRequests ~= false then
		for argIndex, arg in self.args do
			if arg.definition.shouldRequest and string.find(string.lower(arg.rawType.name), "player", 1, true) then
				local prepared = self.preparedArgs[argIndex]
				if prepared == nil then
					continue
				end

				if typeof(prepared) == "Instance" then
					if prepared == self.fromPlayer then
						continue -- don't request self
					end
					if self:shouldRequest(prepared) then
						task.spawn(self.requestCommand, self, prepared, self.preparedArgs, run)
						return true -- skip running initial command
					end
				else -- list of players
					for i, player in prepared do
						if player == self.fromPlayer then
							continue -- don't request self
						end
						if self:shouldRequest(player) then
							prepared[i] = nil -- strip player
							local soloPrepared = table.clone(self.preparedArgs)
							soloPrepared[argIndex] = { player }
							task.spawn(self.requestCommand, self, player, soloPrepared, run)
						end
					end
				end
			end
		end
	end

	self._K.Hook.preCommand:Fire(self)
	local ok, err = pcall(run, self, unpack(self.preparedArgs))
	self._K.Hook.postCommand:Fire(self)

	if not ok then
		warn("Kohl's Admin Command Error:", err)
	end

	return ok, err
end

function Command:validate()
	if self.validated then
		return true
	end

	-- always try first argument for player types
	if self.definition.args[1] and string.find(self.definition.args[1].type, "player", 1, true) and #self.array < 2 then
		local start, text = unpack(self.array[1])
		self.array[2] = { start + #text, "" }
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
					local input = string.lower(rawArg)
					local text, _, _, query = unpack(suggestions[1])
					if
						string.find(string.lower(text), input, 1, true)
						or (query and string.find(string.lower(query), `[{input}`, 1, true))
					then
						shouldFillWithSelf = false
					end
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
			arg.skipped = rawArg
		elseif filledSelf and shouldFillWithSelf then
			arg.skipped = rawArg
		end

		self.args[index] = arg

		if ok then
			arrayIndex += 1
			self.preparedArgs[index] = result
		else
			if definition.optional and index < #self.definition.args then
				arg.skipped = rawArg
				continue
			end
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
