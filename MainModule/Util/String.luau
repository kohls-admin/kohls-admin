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

return String
