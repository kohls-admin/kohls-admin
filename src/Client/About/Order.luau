--!strict
--[[
	The credits' two lists, from Credits.luau's people and the generated Contributions.luau:

	- `Order.active(people, data?)`: the **active contributors**, people whose `GitHub` login has at least
	  `Credits.active.commits` commits in the window (`recent`, the last `Credits.active.days` days), most first; ties
	  by display name, then username, then id.
	- `Order.plain(people, data?)`: everyone else, by Roblox username (case-insensitive), then id; a credit the data
	  has no name for goes last, by id, until the script runs again.

	Names come from the generated data, not from the page's live lookups, so both lists are known before the first
	entry is built and never move when live names arrive. .github/scripts/credits.py computes the 12-month window and
	repeats these orders to decide when Contributions.luau needs rewriting; both check themselves against
	test/unit/CreditsOrder.json, so change them together. `data` defaults to the generated module (specs pass
	their own).
]]
local Contributions = require(script.Parent:WaitForChild("Contributions"))
local Credits = require(script.Parent:WaitForChild("Credits"))

export type Person = Credits.Person
export type Data = Contributions.Contributions

local Order = {}

-- The commits in the window that make someone an active contributor (Credits.luau's `active`, shared with the script).
local ACTIVE = Credits.active.commits

type Rank = { person: Person, commits: number, displayName: string?, name: string? }

local function ranks(people: { Person }, source: Data): { Rank }
	-- GitHub logins are case-insensitive.
	local recent: { [string]: number } = {}
	for login, count in source.recent do
		local key = string.lower(login)
		recent[key] = (recent[key] or 0) + count
	end
	local out: { Rank } = {}
	for _, person in people do
		local names = source.names[person.Id]
		table.insert(out, {
			person = person,
			commits = if person.GitHub then recent[string.lower(person.GitHub)] or 0 else 0,
			displayName = names and string.lower(names.displayName),
			name = names and string.lower(names.name),
		})
	end
	return out
end

local function people(sorted: { Rank }): { Person }
	local out: { Person } = {}
	for index, rank in sorted do
		out[index] = rank.person
	end
	return out
end

function Order.active(list: { Person }, data: Data?): { Person }
	local chosen: { Rank } = {}
	for _, rank in ranks(list, data or Contributions) do
		if rank.commits >= ACTIVE then
			table.insert(chosen, rank)
		end
	end
	table.sort(chosen, function(a: Rank, b: Rank): boolean
		if a.commits ~= b.commits then
			return a.commits > b.commits
		end
		if (a.displayName == nil) ~= (b.displayName == nil) then
			return a.displayName ~= nil
		end
		if a.displayName and b.displayName and a.displayName ~= b.displayName then
			return a.displayName < b.displayName
		end
		if a.name and b.name and a.name ~= b.name then
			return a.name < b.name
		end
		return a.person.Id < b.person.Id
	end)
	return people(chosen)
end

function Order.plain(list: { Person }, data: Data?): { Person }
	local chosen: { Rank } = {}
	for _, rank in ranks(list, data or Contributions) do
		if rank.commits < ACTIVE then
			table.insert(chosen, rank)
		end
	end
	table.sort(chosen, function(a: Rank, b: Rank): boolean
		if (a.name == nil) ~= (b.name == nil) then
			return a.name ~= nil
		end
		if a.name and b.name and a.name ~= b.name then
			return a.name < b.name
		end
		return a.person.Id < b.person.Id
	end)
	return people(chosen)
end

return table.freeze(Order)
