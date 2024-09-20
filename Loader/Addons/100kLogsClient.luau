local loremIpsum = {
	"Lorem",
	"ipsum",
	"dolor",
	"sit",
	"amet",
	"consectetur",
	"adipiscing",
	"elit",
	"sed",
	"do",
	"eiusmod",
	"tempor",
	"incididunt",
	"ut",
	"labore",
	"et",
	"dolore",
	"magna",
	"aliqua",
	"Ut",
	"enim",
	"ad",
	"minim",
	"veniam",
	"quis",
	"nostrud",
	"exercitation",
	"ullamco",
	"laboris",
	"nisi",
	"ut",
	"aliquip",
	"ex",
	"ea",
	"commodo",
	"consequat",
	"Duis",
	"aute",
	"irure",
	"dolor",
	"in",
	"reprehenderit",
	"in",
	"voluptate",
	"velit",
	"esse",
	"cillum",
	"dolore",
	"eu",
	"fugiat",
	"nulla",
	"pariatur",
	"Excepteur",
	"sint",
	"occaecat",
	"cupidatat",
	"non",
	"proident",
	"sunt",
	"in",
	"culpa",
	"qui",
	"officia",
	"deserunt",
	"mollit",
	"anim",
	"id",
	"est",
	"laborum",
}

local function generateLoremIpsum(wordCount: number): string
	local result = {}
	for i = 1, wordCount do
		local randomIndex = math.random(1, #loremIpsum)
		table.insert(result, loremIpsum[randomIndex])
	end
	return table.concat(result, " ")
end

local lines = {}
for i = 1, 100 do
	table.insert(lines, generateLoremIpsum(math.random(16, 32)))
end

local levels = {
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

return function(_K)
	-- _K.Util.Defer.reset()
	-- for i = 1, 100_000 do
	-- 	_K.logger:log("log #" .. i .. ": " .. lines[math.random(1, 100)], levels[math.random(1, #levels)])
	-- 	_K.Util.Defer.wait()
	-- 	if i % 10000 == 0 then
	-- 		_K.UI.Scope.dashboard.Logs:updateList()
	-- 	end
	-- end
	--
	-- _K.UI.Scope.dashboard.Logs:updateList()
end
