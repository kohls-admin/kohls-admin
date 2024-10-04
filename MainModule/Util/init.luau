local Logger = require(script:WaitForChild("Logger"))

export type Log = Logger.Log
export type LogType = Logger.LogType
export type Logger = Logger.Logger

--- @class Util
local Util = {
	--- @within Util
	--- @prop Logger Logger
	Logger = Logger,

	Defer = require(script:WaitForChild("Defer")),
	Function = require(script:WaitForChild("Function")),
	getUserInfo = require(script:WaitForChild("getUserInfo")),
	Humanoid = require(script:WaitForChild("Humanoid")),
	--- @within Util
	--- @prop Promise Promise
	Promise = require(script:WaitForChild("Promise")),
	Queue = require(script:WaitForChild("Queue")),
	ReadableTime = require(script:WaitForChild("ReadableTime")),
	Retry = require(script:WaitForChild("Retry")),
	Rollout = require(script:WaitForChild("Rollout")),
	SafePlayerAdded = require(script:WaitForChild("SafePlayerAdded")),
	SafeTeleport = require(script:WaitForChild("SafeTeleport")),
	Services = require(script:WaitForChild("Services")),
	Signal = require(script:WaitForChild("Signal")),
	--- @within Util
	--- @prop String String
	String = require(script:WaitForChild("String")),
	Suggest = require(script:WaitForChild("Suggest")),
	Table = require(script:WaitForChild("Table")),
}

return Util
