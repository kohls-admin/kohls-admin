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
local Logger = { limit = 100_000 }
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

function Logger.sortTime(a, b)
	return a.time < b.time
end

function Logger:encode(level: LogType): string
	return string.char((table.find(LEVELS, level) or 1))
end

function Logger:decode(level: string): LogType
	return LEVELS[string.byte(level)] or "UNKNOWN"
end

function Logger:log(text: string, level: LogType, userId: number?, noAppend: boolean?): Log?
	if level == "DEBUG" and not self.debug then
		return
	end

	local log = {
		text = text,
		level = Logger:encode(level),
		time = workspace:GetServerTimeNow(),
		from = if userId then math.abs(userId) else nil,
	}

	if not noAppend then
		table.insert(self.logs, log)
	end

	return log
end

return Logger
