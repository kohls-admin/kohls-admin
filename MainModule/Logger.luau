local RunService = game:GetService("RunService")

local Package = script.Parent

local Auth = require(Package.Auth)
local Data = require(Package.Data)
local Hook = require(Package.Hook)
local Util = require(Package.Util)

export type Log = Util.Log
export type LogType = Util.LogType
export type Logger = Util.Logger

local IsServer = RunService:IsServer()

local logger = Util.Logger.new(true)
local module = { logger = logger }

-- use Data log table
logger.logs = Data.logs

function module.log(text: string, level: LogType, from: number?, filtered: boolean?): Log?
	if Data.logsHidden[from] then
		return
	end
	local log = logger:log(text, level, from)

	Hook.log:Fire(log)

	if IsServer then
		if from and not filtered then
			local filterContext =
				Enum.TextFilterContext[if Data.roles.default.permissions.logs then "PublicChat" else "PrivateChat"]
			log.text = Util.String.filterForBroadcast(text, from, filterContext)
		end

		if level == "COMMAND" and (not from or Auth.getRank(from) > 1) then
			-- save logs for roles above VIP (rank 1)
			table.insert(Data.Cache.logs, { log.text, log.level, log.time, from })
			Data.pendingSaveLogs = true
		end

		Hook.logFiltered:Fire(log)
	else
		log.client = true
	end

	return log
end

return module
