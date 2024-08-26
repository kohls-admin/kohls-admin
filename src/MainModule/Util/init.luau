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
	--- @within Util
	--- @prop Promise Promise
	Promise = require(script:WaitForChild("Promise")),
	Queue = require(script:WaitForChild("Queue")),
	ReadableTime = require(script:WaitForChild("ReadableTime")),
	Retry = require(script:WaitForChild("Retry")),
	Rollout = require(script:WaitForChild("Rollout")),
	Services = require(script:WaitForChild("Services")),
	SignalFast = require(script:WaitForChild("SignalFast")),
	SignalGood = require(script:WaitForChild("SignalGood")),
	--- @within Util
	--- @prop String String
	String = require(script:WaitForChild("String")),
	Suggest = require(script:WaitForChild("Suggest")),
	Table = require(script:WaitForChild("Table")),
}

return Util
