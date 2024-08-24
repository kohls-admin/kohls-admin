local Logger = require(script:WaitForChild("Logger"))

export type Log = Logger.Log
export type LogType = Logger.LogType
export type Logger = Logger.Logger

--- @class Util
local Util = {
	Logger = Logger,

	Defer = require(script:WaitForChild("Defer")),
	Function = require(script:WaitForChild("Function")),
	getUserInfo = require(script:WaitForChild("getUserInfo")),
	Promise = require(script:WaitForChild("Promise")),
	Queue = require(script:WaitForChild("Queue")),
	ReadableTime = require(script:WaitForChild("ReadableTime")),
	Retry = require(script:WaitForChild("Retry")),
	Rollout = require(script:WaitForChild("Rollout")),
	Services = require(script:WaitForChild("Services")),
	SignalFast = require(script:WaitForChild("SignalFast")),
	SignalGood = require(script:WaitForChild("SignalGood")),
	String = require(script:WaitForChild("String")),
	Suggest = require(script:WaitForChild("Suggest")),
	Table = require(script:WaitForChild("Table")),
}

return Util
