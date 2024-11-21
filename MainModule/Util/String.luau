local Players = game:GetService("Players")
local TextService = game:GetService("TextService")

local Retry = require(script.Parent:WaitForChild("Retry"))

--- @class String
local String = {}

--- Escape magic string pattern characters: % . ( ) [ ] + - * ? ^ $
function String.escapePattern(s: string): string
	return string.gsub(s, "([%%%.%(%)%[%]%+%-%*%?%^%$])", "%%%1")
end

--- Escape RichText tags
function String.escapeRichText(s: string): string
	s = string.gsub(s, "&", "&amp;") -- first because substitutes contain it
	s = string.gsub(s, "<", "&lt;")
	s = string.gsub(s, ">", "&gt;")
	s = string.gsub(s, '"', "&quot;")
	s = string.gsub(s, "'", "&apos;")
	return s
end

--- Unescape RichText tags
function String.unescapeRichText(s: string): string
	s = string.gsub(s, "&apos;", "'")
	s = string.gsub(s, "&quot;", '"')
	s = string.gsub(s, "&gt;", ">")
	s = string.gsub(s, "&lt;", "<")
	s = string.gsub(s, "&amp;", "&")
	return s
end

function String.stripQuotes(s: string): string
	return string.gsub(s, '["`]', "")
end

function String.trimStart(s: string): string
	return if string.find(s, "^%s*$") then "" else (string.match(s, "^%s*(.*)") or "")
end

function String.trimEnd(s: string): string
	return if string.find(s, "^%s*$") then "" else (string.match(s, "(.-)%s*$") or "")
end

function String.trim(s: string): string
	return if string.find(s, "^%s*$") then "" else (string.match(s, "^%s*(.*%S)") or "")
end

function String.filterForBroadcast(message: string, fromUserId: number, filterContext: Enum.TextFilterContext?): string
	local ok, result = Retry(function()
		return TextService:FilterStringAsync(message, fromUserId, filterContext or Enum.TextFilterContext.PublicChat)
	end, 5, 1)
	if ok then
		ok, result = Retry(function()
			return result:GetNonChatStringForBroadcastAsync()
		end, 5, 1)
		if ok then
			return result
		end
	end
	return `TextService filtering failed: {result}`
end

--- Filters a message with [TextService.FilterStringAsync]
function String.filterForUser(
	message: string,
	fromUserId: number,
	toUserId: number,
	filterContext: Enum.TextFilterContext?
): string
	if fromUserId == toUserId then
		return message
	end
	local ok, result = Retry(function()
		return TextService:FilterStringAsync(message, fromUserId, filterContext or Enum.TextFilterContext.PublicChat)
	end, 5, 1)
	if ok then
		ok, result = Retry(function()
			if Players:GetPlayerByUserId(fromUserId) then
				return result:GetChatForUserAsync(toUserId)
			else
				return result:GetNonChatStringForBroadcastAsync()
			end
		end, 5, 1)
		if ok then
			return result
		end
	end
	return `TextService filtering failed: {result}`
end

return String
