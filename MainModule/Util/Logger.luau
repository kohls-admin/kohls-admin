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

export type Log = {
	text: string,
	level: LogType,
	time: number,
	user: number?,
}

local Class = {}
Class.__index = Class

export type Logger = typeof(setmetatable({} :: { logs: { Log }, debug: boolean? }, Class))

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

function Class.new(debugEnabled: boolean?): Logger
	return setmetatable({ logs = {}, debug = debugEnabled }, Class)
end

function Class:encode(level: LogType): string
	return encode[level] or level
end

function Class:decode(key: string): LogType
	return decode[key] or key
end

function Class:log(text: string, level: LogType, userId: number?): Log?
	if level == "DEBUG" and not self.debug then
		return
	end

	local log = {
		text = text,
		level = encode[level],
		time = os.time(),
		user = userId,
	}

	table.insert(self.logs, log)
	if #self.logs > 100_000 then
		table.remove(self.logs, 1)
	end

	return log
end

return Class
