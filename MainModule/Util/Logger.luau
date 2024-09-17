--- @within Logger
--- @type LogType "DEBUG" | "INFO" | "WARN" | "ERROR" | "CHAT" | "COMMAND" | "JOIN" | "LEAVE" | "KILL" | "DEATH" | "DAMAGE" | "PURCHASE" | string
export type LogType =
	"DEBUG"
	| "INFO"
	| "WARN"
	| "ERROR"
	| "CHAT"
	| "COMMAND"
	| "JOIN"
	| "LEAVE"
	| "KILL"
	| "DEATH"
	| "DAMAGE"
	| "PURCHASE"
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
local decode, encode = {}, {}
for i, level in
	{
		"DEBUG",
		"INFO",
		"WARN",
		"ERROR",
		"CHAT",
		"COMMAND",
		"JOIN",
		"LEAVE",
		"KILL",
		"DEATH",
		"DAMAGE",
		"PURCHASE",
	}
do
	local key = string.char(31 + i)
	decode[key] = level
	encode[level] = key
end

function Logger.new(debugEnabled: boolean?): Logger
	return setmetatable({ logs = {}, debug = debugEnabled }, Logger)
end

function Logger:encode(level: LogType): string
	return encode[level] or level
end

function Logger:decode(key: string): LogType
	return decode[key] or key
end

function Logger:log(text: string, level: LogType, userId: number?): Log?
	if level == "DEBUG" and not self.debug then
		return
	end

	local log = {
		text = text,
		level = encode[level],
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
