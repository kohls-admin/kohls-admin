--- @within Logger
--- @type LogType "INFO" | "WARN" | "ERROR" | "DEBUG" | "CHAT" | "COMMAND" | "PURCHASE" | "DAMAGE" | "DEATH" | "KILL" | "JOIN" | "LEAVE" | string
export type LogType =
	"INFO"
	| "WARN"
	| "ERROR"
	| "DEBUG"
	| "CHAT"
	| "COMMAND"
	| "PURCHASE"
	| "DAMAGE"
	| "DEATH"
	| "KILL"
	| "JOIN"
	| "LEAVE"
	| string

--- @within Logger
--- @type Log { text: string, level: LogType, time: number, user: number? }
export type Log = {
	text: string,
	level: LogType,
	time: number,
	from: number?,
	client: boolean?,
}

--- @class Logger
local Logger = {}
Logger.__index = Logger

--- @within Logger
--- @type Logger typeof(setmetatable({} :: { logs: { Log }, debug: boolean? }, Logger))
export type Logger = typeof(setmetatable({} :: { logs: { Log }, debug: boolean? }, Logger))

-- WARN: DO NOT CHANGE THE ARRAY ORDER WITHOUT A DATASTORE MIGRATION!
local LEVELS = {
	"INFO",
	"WARN",
	"ERROR",
	"DEBUG",

	"CHAT",
	"COMMAND",
	"PURCHASE",

	"DAMAGE",
	"DEATH",
	"KILL",

	"JOIN",
	"LEAVE",
}

function Logger.new(debugEnabled: boolean?): Logger
	return setmetatable({ logs = {}, debug = debugEnabled }, Logger)
end

function Logger:encode(level: LogType): number
	return (table.find(LEVELS, level) or 1) - 1
end

function Logger:decode(index: number): LogType
	return LEVELS[index + 1]
end

function Logger:log(text: string, level: LogType, userId: number?): Log?
	if level == "DEBUG" and not self.debug then
		return
	end

	local log = {
		text = text,
		level = (table.find(LEVELS, level) or 1) - 1,
		time = workspace:GetServerTimeNow(),
		from = userId,
	}

	table.insert(self.logs, log)
	if #self.logs > 100_000 then
		table.remove(self.logs, 1)
	end

	return log
end

return Logger
