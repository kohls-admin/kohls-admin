local Logger = require(script.Logger)

export type Log = Logger.Log
export type LogType = Logger.LogType
export type Logger = Logger.Logger

--- @class Util
local Util = {
	Logger = Logger,

	Defer = require(script.Defer),
	Function = require(script.Function),
	getUserInfo = require(script.getUserInfo),
	Queue = require(script.Queue),
	ReadableTime = require(script.ReadableTime),
	Retry = require(script.Retry),
	Rollout = require(script.Rollout),
	Services = require(script.Services),
	SignalFast = require(script.SignalFast),
	SignalGood = require(script.SignalGood),
	String = require(script.String),
	Suggest = require(script.Suggest),
	Table = require(script.Table),
}

return Util
