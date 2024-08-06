local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local Data = require(script.Parent.Data)
local Hook = require(script.Parent.Hook)
local Remote = require(script.Parent.Remote)
local Util = require(script.Parent.Util)

export type Log = Util.Log
export type LogType = Util.LogType
export type Logger = Util.Logger

local IsServer = RunService:IsStudio()

local logger = Util.Logger.new()
local module = { logger = logger }

-- use Data log table
logger.logs = Data.logs

function module.log(text: string, level: LogType, from: number?): Log
	-- fire this log to all clients that are authorized!
	-- TODO: make sure they pull logs on client init
	-- make sure to sort by timestamp for new datastore entries

	local log = logger:log(text, level, from)

	Hook.log:Fire(log)

	if IsServer then
		if from then
			local ok, result = pcall(
				TextService.FilterStringAsync,
				TextService,
				text,
				from,
				Enum.TextFilterContext[if Data.defaultRole.logs then "PublicChat" else "PrivateChat"]
			)
			if ok then
				for _, player in Players:GetPlayers() do
					local success, filtered = pcall(result.GetChatForUserAsync, result, player.UserId)
					if success then
						Remote.Log:FireClient(player, { filtered, level, log.time, from })
					else -- retry
					end
				end
			else
				-- TODO: if not ok, retry
			end
		else
			Remote.Log:FireAllClients({ log.text, log.level, log.time, log.from })
		end
	end

	return log
end

return module
