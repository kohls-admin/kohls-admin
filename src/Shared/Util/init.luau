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
	getTexture = require(script:WaitForChild("getTexture")),
	getUserInfo = require(script:WaitForChild("getUserInfo")),
	Humanoid = require(script:WaitForChild("Humanoid")),
	iterPageItems = require(script:WaitForChild("iterPageItems")),
	MemoryStore = require(script:WaitForChild("MemoryStore")),
	Queue = require(script:WaitForChild("Queue")),
	Retry = require(script:WaitForChild("Retry")),
	Rollout = require(script:WaitForChild("Rollout")),
	RunContext = require(script:WaitForChild("RunContext")),
	SafePlayerAdded = require(script:WaitForChild("SafePlayerAdded")),
	SafeTeleport = require(script:WaitForChild("SafeTeleport")),
	Service = require(script:WaitForChild("Service")),
	Signal = require(script:WaitForChild("Signal")),
	--- @within Util
	--- @prop String String
	String = require(script:WaitForChild("String")),
	Suggest = require(script:WaitForChild("Suggest")),
	Table = require(script:WaitForChild("Table")),
	Tasks = require(script:WaitForChild("Tasks")),
	Time = require(script:WaitForChild("Time")),
}

return Util
