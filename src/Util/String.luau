local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
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

--- Strip quotes from a string
function String.stripQuotes(s: string): string
	return string.gsub(s, '["`]', "")
end

--- Strip whitespace from the start of a string
function String.trimStart(s: string): string
	return if string.find(s, "^%s*$") then "" else (string.match(s, "^%s*(.*)") or "")
end

--- Strip whitespace from the end of a string
function String.trimEnd(s: string): string
	return if string.find(s, "^%s*$") then "" else (string.match(s, "(.-)%s*$") or "")
end

--- Strip whitespace from both ends of a string
function String.trim(s: string): string
	return if string.find(s, "^%s*$") then "" else (string.match(s, "^%s*(.*%S)") or "")
end

--- Returns a [TextFilterResult] with [TextService.FilterStringAsync] to be used with [String.filterResultForBroadcast] or [String.filterResultForUser]
function String.filterResult(
	message: string,
	fromUserId: number,
	filterContext: Enum.TextFilterContext?
): (boolean, TextFilterResult | string)
	return pcall(function()
		return TextService:FilterStringAsync(message, fromUserId, filterContext or Enum.TextFilterContext.PublicChat)
	end)
end

--- Filters a [TextFilterResult] for broadcast messages with [TextService.FilterStringAsync]
function String.filterResultForBroadcast(filterResult: TextFilterResult | string, fromUserId: number)
	if type(filterResult) == "string" then
		return filterResult
	end
	local _, result = pcall(function()
		if TextChatService:CanUserChatAsync(fromUserId) then
			return filterResult:GetNonChatStringForBroadcastAsync()
		else
			return "User cannot chat"
		end
	end)
	return result
end

--- Filters a [TextFilterResult] for chat messages chat with [TextService.FilterStringAsync]
function String.filterResultForUser(filterResult: TextFilterResult | string, fromUserId: number, toUserId: number)
	if type(filterResult) == "string" then
		return filterResult
	end
	local _, result = pcall(function()
		if Players:GetPlayerByUserId(fromUserId) then
			if TextChatService:CanUsersChatAsync(fromUserId, toUserId) then
				return filterResult:GetChatForUserAsync(toUserId)
			else
				return "User cannot chat"
			end
		else
			if TextChatService:CanUserChatAsync(fromUserId) then
				return filterResult:GetNonChatStringForBroadcastAsync()
			else
				return "User cannot chat"
			end
		end
	end)
	return result
end

--- Filters a broadcast message with [TextService.FilterStringAsync]
function String.filterForBroadcast(message: string, fromUserId: number, filterContext: Enum.TextFilterContext?): string
	local _, result = String.filterResult(message, fromUserId)
	return String.filterResultForBroadcast(result, fromUserId)
end

--- Filters a chat message with [TextService.FilterStringAsync]
function String.filterForUser(
	message: string,
	fromUserId: number,
	toUserId: number,
	filterContext: Enum.TextFilterContext?
): string
	if fromUserId == toUserId then
		return message
	end
	local _, result = String.filterResult(message, fromUserId)
	return String.filterResultForUser(result, fromUserId, toUserId)
end

return String
