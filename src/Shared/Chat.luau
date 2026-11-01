--[[
	Delivers admin messages (hints, messages, notifications, private messages, votes, text to speech and announcements)
	to the admin UI of each recipient, as text the server filtered for broadcast.
	https://create.roblox.com/docs/chat/guidelines

	The sender must be allowed to chat, TextService filters the text for broadcast, and messages that reach other
	players are limited to one a minute per sender. Nothing goes through TextChannels: with platform-integrated chat,
	scripts can't send or read chat text.
	https://create.roblox.com/docs/chat/platform-integrated-chat
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Auth = require(script.Parent:WaitForChild("Auth"))
local Util = require(script.Parent:WaitForChild("Util"))
local Remote = Util.Remote

local COOLDOWN = 60

--- @class Chat
local Chat = {
	COOLDOWN = COOLDOWN,
}

local cooldowns = {}

--- Rate limits user-editable text shown to other users, returns a message while cooling down
function Chat.cooldown(userId: number, key: string, seconds: number?): string?
	local id = `{key}:{userId}`
	local duration = seconds or COOLDOWN
	local now = os.clock()
	local last = cooldowns[id]
	if last and now - last < duration then
		return `Wait {math.ceil(duration - (now - last))}s before using this again.`
	end
	cooldowns[id] = now
	task.delay(duration, function()
		if cooldowns[id] == now then
			cooldowns[id] = nil
		end
	end)
	return nil
end

--- Lists the prefixes that can start a chat command alias: single characters that aren't letters, digits or spaces
function Chat.commandPrefixes(prefixes: { string }?): { string }
	local list, candidates: { string } = {}, prefixes or {}
	for _, prefix in candidates do
		if
			type(prefix) == "string"
			and utf8.len(prefix) == 1
			and not string.find(prefix, "[%w%s]")
			and not table.find(list, prefix)
		then
			table.insert(list, prefix)
		end
	end
	return list
end

local function canUserChat(userId: number): boolean
	if RunService:IsStudio() and Auth.hasRestrictedRole(userId) then
		return true
	end
	local ok, canChat = pcall(TextChatService.CanUserChatAsync, TextChatService, userId)
	return ok and canChat == true
end

Chat.canUserChat = canUserChat

local function canUsersChat(fromUserId: number, toUserId: number): boolean
	if fromUserId == toUserId or (RunService:IsStudio() and Auth.hasRestrictedRole(fromUserId)) then
		return true
	end
	local ok, canChat = pcall(TextChatService.CanUsersChatAsync, TextChatService, fromUserId, toUserId)
	return ok and canChat == true
end

Chat.canUsersChat = canUsersChat

--- Returns true when any player in `players` (or the server) cannot chat with `fromUserId`
function Chat.hasRestrictedPeer(fromUserId: number, players: { Player }?): boolean
	if RunService:IsStudio() and Auth.hasRestrictedRole(fromUserId) then
		return false
	end
	for _, player in players or Players:GetPlayers() do
		if player.UserId ~= fromUserId and not canUsersChat(fromUserId, player.UserId) then
			return true
		end
	end
	return false
end

--- Gates user text shown to everyone behind a chat check and the shared announcement cooldown
function Chat.limitBroadcast(userId: number, _roleError: string?): string?
	if not canUserChat(userId) then
		return "User cannot chat"
	end
	return Chat.cooldown(userId, "announce")
end

-- rich text tags that may be restored in filtered text
local SIMPLE_TAGS = { b = true, i = true, u = true, s = true, sc = true, uc = true }
local FONT_SIZE_MIN, FONT_SIZE_MAX = 8, 40

local function validFontAttribute(name: string, value: string, compact: boolean?): string?
	if name == "color" then
		if string.find(value, "^#%x%x%x%x%x%x$") or string.find(value, "^#%x%x%x$") then
			return value
		end
		local r, g, b = string.match(value, "^rgb%(%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*%)$")
		if r and tonumber(r) <= 255 and tonumber(g) <= 255 and tonumber(b) <= 255 then
			return `rgb({r},{g},{b})`
		end
	elseif name == "transparency" then
		local n = tonumber(value)
		if n and n >= 0 and n <= 1 then
			return tostring(n)
		end
	elseif name == "size" then
		local n = tonumber(value)
		if n then
			-- dropped in the chat window, where it would stretch the line
			return if compact then "" else tostring(math.clamp(math.floor(n), FONT_SIZE_MIN, FONT_SIZE_MAX))
		end
	end
	return nil
end

-- returns the restored tag, its name and whether it opens (true), closes (false) or stands alone (nil)
local function restoreTag(inner: string, compact: boolean?): (string?, string?, boolean?)
	inner = string.gsub(string.gsub(inner, "&quot;", '"'), "&apos;", "'")
	local closing, name = string.match(inner, "^%s*(/?)%s*(%a+)%s*$")
	name = name and string.lower(name)
	if name and SIMPLE_TAGS[name] then
		return `<{closing}{name}>`, name, closing == ""
	elseif name == "font" and closing == "/" then
		return "</font>", name, false
	elseif (name == "br" and closing == "") or string.match(inner, "^%s*[bB][rR]%s*/%s*$") then
		return if compact then " " else "<br />", nil, nil
	end

	local attributes = string.match(inner, "^%s*[fF][oO][nN][tT]%s+(.-)%s*$")
	if not attributes then
		return nil
	end
	local parts = {}
	local rest = string.gsub(attributes, "(%a+)%s*=%s*([\"']?)([^\"'%s]*)%2", function(key, _, value)
		key = string.lower(key)
		local valid = validFontAttribute(key, value, compact)
		if valid then
			if valid ~= "" then
				table.insert(parts, `{key}="{valid}"`)
			end
			return ""
		end
		return nil -- left in place, invalidates the tag
	end)
	if not string.find(rest, "^%s*$") then
		return nil
	end
	if #parts == 0 then
		table.insert(parts, 'transparency="0"') -- every attribute was dropped, keep the pair balanced
	end
	return `<font {table.concat(parts, " ")}>`, "font", true
end

--[=[
	Restores a safe subset of rich text in text that TextChatService filtered and escaped: b, i, u, s, sc, uc, br,
	and font with color, transparency and a clamped size. Anything else stays escaped and shows literally.
	`compact` is for the chat window and bubbles: font size is dropped and line breaks become spaces.
	Unbalanced tags would break rich text parsing, so the text is returned unchanged when they don't pair up.
]=]
function Chat.restoreRichText(text: string, compact: boolean?): string
	local stack, balanced = {}, true
	local restored = string.gsub(text, "(&lt;(.-)&gt;)", function(...: string): string
		local escaped, inner = ...
		-- a stray "<" earlier pairs with this ">", only the last "<" can open a tag
		local before, after = string.match(inner, "^(.*)&lt;(.*)$")
		local prefix = if before then "&lt;" .. before else ""
		inner = after or inner

		local tag, name, opens = restoreTag(inner, compact)
		if not tag then
			return escaped
		elseif opens == true then
			table.insert(stack, name)
		elseif opens == false then
			if stack[#stack] ~= name then
				balanced = false
			end
			table.remove(stack)
		end
		return prefix .. tag
	end)
	if not balanced or #stack > 0 then
		return text
	end
	return restored
end

if RunService:IsServer() then
	-- create the lazy remote now, clients connect to it on start
	_ = Remote.ChatSystem

	--[=[
		Sends a message of `kind` to everyone in the server, or only to `targets`, through Remote.ChatSystem to the
		admin UI. Returns the message id and, after a nil error, the players it reached; or nil and an error message.

		The sender must be allowed to chat and the text is filtered for broadcast. Messages that reach other players
		are rate limited to one a minute per sender, shared by every kind except `vote`.

		Global messages were rate limited and filtered in their origin server, so here they are delivered directly.
	]=]
	function Chat.send(
		context: any,
		kind: string,
		text: string,
		targets: { Player }?,
		data: any?
	): (string?, string?, { Player }?)
		local recipients = targets or Players:GetPlayers()
		local from, escaped
		if context.global then
			from = context.from
			escaped = Util.String.escapeRichText(text)
		else
			local sender = context.fromPlayer or (context.from and Players:GetPlayerByUserId(context.from))
			if not (sender and sender.Parent) then
				return nil, "Message commands must be run by a player in this server."
			end
			from = sender.UserId
			if not canUserChat(from) then
				return nil, "User cannot chat"
			end
			local ok, filterResult = Util.String.filterResult(text, from, Enum.TextFilterContext.PublicChat)
			if not ok then
				return nil, "Message could not be filtered"
			end
			local filterResultTyped = filterResult :: TextFilterResult
			local okBroadcast, filtered = pcall(filterResultTyped.GetNonChatStringForBroadcastAsync, filterResultTyped)
			if not okBroadcast or type(filtered) ~= "string" then
				return nil, "Message could not be filtered"
			end

			local allowed, hasOtherAllowed, hasRestricted = {}, false, false
			for _, player in recipients do
				if player == sender then
					table.insert(allowed, player)
				elseif canUsersChat(from, player.UserId) then
					hasOtherAllowed = true
					table.insert(allowed, player)
				else
					hasRestricted = true
				end
			end

			-- messages to players the sender can chat with are never limited
			if hasRestricted then
				local err = Chat.cooldown(from, if kind == "vote" then "vote" else "direct")
				if err then
					if not hasOtherAllowed then
						return nil, err
					end
					recipients = allowed
					Remote.Notify:Fire(sender, { Text = `{err} Players you can't chat with were skipped.` })
				end
			end

			escaped = Util.String.escapeRichText(filtered)
			for _, arg in context.args or {} do
				if
					arg.rawType
					and arg.rawType.freeText
					and (arg.rawArg == text or Util.String.stripQuotes(arg.rawArg) == text)
				then
					arg.parsedArgs = { filtered }
					arg.redactLog = false
				end
			end
		end

		local id = HttpService:GenerateGUID(false)
		for _, player in recipients do
			Remote.ChatSystem:Fire(player, kind, escaped, from, data, id)
		end
		return id, nil, recipients
	end

	--[=[
		Filters and rate limits a free-text reason (ban, kick, shutdown) that other users see.
		Returns `(allowedReason, restrictedReason)`: chat-allowed targets always see `allowedReason`, while targets
		the sender cannot chat with receive `restrictedReason` (which is `nil` while cooling down).
	]=]
	function Chat.limitReason(userId: number, reason: string?, players: { Player }?): (string?, string?)
		if not reason or not canUserChat(userId) then
			return nil, nil
		end
		reason = Util.String.filterForBroadcast(reason, userId)
		if players and not Chat.hasRestrictedPeer(userId, players) then
			return reason, reason
		end
		local err = Chat.cooldown(userId, "reason")
		if not err then
			return reason, reason
		end
		local player = Players:GetPlayerByUserId(userId)
		if player then
			Remote.Notify:Fire(player, { Text = `<b>Reason removed:</b> {err}` })
		end
		if players then
			return reason, nil
		end
		return nil, nil
	end
else
	local handlers = {}
	local received = {}
	local waiting: { [string]: { thread } } = {}

	--- Registers the client handler for a message kind, called with the filtered text, sender UserId, data and id
	function Chat.onMessage(kind: string, callback: (text: string, from: number, data: any, id: string) -> ())
		handlers[kind] = callback
	end

	local pinned: string? = nil
	local shownPins: { [string]: true } = {}

	--[=[
		Tracks the pinned announcement ({ text, from, duration, id }) shown on this client. It arrives through
		settings and "announce" messages, so returns true only when it changed and should show. Each pin gets
		a new id and shows once, so pinning the same text again still shows while a late settings sync of a
		cleared or replaced pin doesn't. Pins saved without an id show when they differ from the last one.
		Anything else clears it.
	]=]
	function Chat.pinAnnouncement(announcement: any): boolean
		if type(announcement) ~= "table" or type(announcement[1]) ~= "string" then
			pinned = nil
			return false
		end
		local id = announcement[4]
		if type(id) == "string" then
			if shownPins[id] then
				return false
			end
			shownPins[id] = true
			pinned = id
			return true
		end
		local key = `{announcement[2]}\0{announcement[1]}`
		if key == pinned then
			return false
		end
		pinned = key
		return true
	end

	--- Waits for the filtered text of a message by id, or nil when it doesn't arrive in time
	function Chat.waitForMessage(id: string, timeout: number?): string?
		if received[id] then
			return received[id]
		end
		local thread = coroutine.running()
		local threads = waiting[id] or {}
		waiting[id] = threads
		table.insert(threads, thread)
		local timedOut = false
		local timer = task.delay(timeout or 10, function()
			timedOut = true
			local index = table.find(threads, thread)
			if index then
				table.remove(threads, index)
				task.spawn(thread, nil)
			end
		end)
		local text = coroutine.yield()
		if not timedOut then
			task.cancel(timer)
		end
		return text
	end

	local function dispatch(kind: string, text: string, from: number, data: any, id: string)
		if received[id] then
			return
		end
		received[id] = text
		task.delay(30, function()
			received[id] = nil
		end)
		local threads = waiting[id]
		if threads then
			waiting[id] = nil
			for _, thread in threads do
				task.spawn(thread, text)
			end
		end

		local handler = handlers[kind]
		if handler then
			task.spawn(handler, text, from, data, id)
		end
	end

	local _ = Remote.ChatSystem:Connect(function(kind: string, text: string, from: number, data: any, id: string)
		dispatch(kind, Chat.restoreRichText(text), from, data, id)
	end)
end

return Chat
