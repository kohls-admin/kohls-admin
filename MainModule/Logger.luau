local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Package = script.Parent

local Auth = require(Package.Auth)
local Data = require(Package.Data)
local Hook = require(Package.Hook)
local Remote = require(Package.Remote)
local Registry = require(Package.Registry)
local Util = require(Package.Util)

export type Log = Util.Log
export type LogType = Util.LogType
export type Logger = Util.Logger

local IsServer = RunService:IsServer()

local logger = Util.Logger.new()
local module = { logger = logger }

-- use Data log table
logger.logs = Data.logs

function module.log(text: string, level: LogType, from: number?, filtered: boolean?): Log
	-- fire this log to all clients that are authorized!
	-- TODO: make sure they pull logs on client init
	-- make sure to sort by timestamp for new datastore entries

	local log = logger:log(text, level, from)

	Hook.log:Fire(log)

	if IsServer then
		if from and not filtered then
			local filterContext = Enum.TextFilterContext[if Data.defaultRole.logs then "PublicChat" else "PrivateChat"]
			log.text = Util.String.filterForBroadcast(text, from, filterContext)
		end

		if level == "COMMAND" then
			-- TODO: should only persist commands if they are used by "staff", non VIP from?
			table.insert(Data.Cache.logs, { log.text, log.level, log.time, from })
			Data.pendingSaveLogs = true
		end

		for _, player in Players:GetPlayers() do
			if Auth.hasCommand(player.UserId, Registry.commands.logs) then
				Remote.Log:FireAllClient(player, { log.text, log.level, log.time, from })
			end
		end
	end

	return log
end

return module
