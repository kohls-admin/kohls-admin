--!optimize 2
--!native

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local TextService = game:GetService("TextService")

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

--- Calculates the Levenshtein distance between two strings.
function String.levenshteinDistance(s1: string, s2: string): number
	local len1, len2 = #s1, #s2
	if len1 < len2 then
		s1, s2, len1, len2 = s2, s1, len2, len1
	end

	if len2 == 0 then
		return len1
	end

	local row = table.create(len2 + 1)
	for j = 0, len2 do
		row[j] = j
	end

	for i = 1, len1 do
		local previous = row[0]
		row[0] = i
		for j = 1, len2 do
			local column = row[j]
			row[j] = math.min(
				column + 1, -- Deletion
				row[j - 1] + 1, -- Insertion
				previous + if string.sub(s1, i, i) == string.sub(s2, j, j) then 0 else 1 -- Substitution
			)
			previous = column
		end
	end

	return row[len2]
end

--- Splits a string by a specified delimiter, but does not split within quoted sequences.
function String.splitOutsideQuotes(text: string, delimiter: string?): { string }?
	if not text then
		return {}
	end

	local segment = { "" } :: { string }
	local segments = { segment }
	local quote

	if delimiter == nil or delimiter == "" then
		delimiter = ","
	end

	for first, last in utf8.graphemes(text) do
		local char: string = string.sub(text, first, last)
		if quote then
			table.insert(segment, char)
			if char == quote then
				quote = nil
			end
		elseif char == "`" or char == '"' then
			table.insert(segment, char)
			quote = char
		elseif char == delimiter then
			segment = { "" }
			table.insert(segments, segment)
		else
			table.insert(segment, char)
		end
	end

	for index, chars in segments do
		segments[index] = table.concat(chars)
	end

	return segments
end

--- Strip enclosing quotes from a string
function String.stripQuotes(s: string): string
	if string.find(s, '[`"]') == 1 then
		return string.sub(s, 2, if string.find(s, '[`"]', #s) == #s then #s - 1 else #s)
	else
		return s
	end
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
				return filterResult:GetNonChatStringForUserAsync(toUserId)
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

-- Converts a locale string (e.g., "en-US") to a flag emoji representation, or an empty string if the locale is invalid.
function String.toFlag(locale: string): string
	if not locale or #locale < 2 then
		return ""
	end
	local first = string.byte(string.upper(string.sub(locale, 1, 1))) - 0x41 + 0x1F1E6
	local second = string.byte(string.upper(string.sub(locale, 2, 2))) - 0x41 + 0x1F1E6
	return utf8.char(first) .. utf8.char(second)
end

return String
