--[[
	Routes user-to-user text through TextChatService TextChannels, as the Roblox chat guidelines require.
	https://create.roblox.com/docs/chat/guidelines

	The server authorizes a message command and grants its sender one message. The sender's client sends the
	raw text with TextChannel:SendAsync, so TextChatService applies filtering, privacy settings and reporting.
	ShouldDeliverCallback only delivers granted messages to the granted targets, and receiving clients render
	the filtered TextChatMessage.Text in the admin UI.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Auth = require(script.Parent:WaitForChild("Auth"))
local Util = require(script.Parent:WaitForChild("Util"))
local Remote = Util.Remote

local PREFIX = "KA_"
local TAG = '<font transparency="0.4">[%s]</font> '
-- user text arrives rich text escaped, so only our own tag can match this
local TAG_PATTERN = '^<font transparency="0%.4">%[[^%]]*%]</font> '
local BROADCAST = "KA_Broadcast"
local GRANT_LIFETIME = 15
local COOLDOWN = 60

--- @class Chat
local Chat = {
	COOLDOWN = COOLDOWN,
	-- tags shown before KA messages in the chat window and bubbles
	LABELS = {
		announce = "Announce",
		message = "Message",
		hint = "Hint",
		fullmessage = "Full Message",
		notify = "Notify",
		privatemessage = "PM",
		privatehint = "Private Hint",
		vote = "Vote",
		tts = "TTS",
	},
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

--- Gates user text shown to everyone behind a developer role and the shared announcement cooldown
function Chat.limitBroadcast(userId: number, roleError: string): string?
	if not Auth.hasRestrictedRole(userId) then
		return roleError
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

local function decode(metadata: string?)
	if type(metadata) ~= "string" or metadata == "" then
		return
	end
	local ok, data = pcall(HttpService.JSONDecode, HttpService, metadata)
	if ok and type(data) == "table" and type(data.k) == "string" and type(data.id) == "string" then
		return data
	end
	return
end

if RunService:IsServer() then
	local grants = {}
	local delivering = {} -- MessageId -> grant it was delivered under
	local directChannels: { [Player]: TextChannel } = {}
	local directMembers: { [TextChannel]: { [number]: boolean } } = {}

	local function shouldDeliver(message: TextChatMessage, textSource: TextSource)
		-- called once per recipient, the grant is checked on the first call
		local grant = delivering[message.MessageId]
		if not grant then
			local sender = message.TextSource
			local data = decode(message.Metadata)
			grant = data and grants[data.id]
			if
				not (sender and grant)
				or grant.from ~= sender.UserId
				or grant.metadata ~= message.Metadata
				or os.clock() > grant.expires
				or grant.messageId ~= nil -- one message per grant
			then
				return false
			end
			grant.messageId = message.MessageId
			delivering[message.MessageId] = grant
		end
		return grant.targets == nil or grant.targets[textSource.UserId] == true
	end

	local function newChannel(name: string): TextChannel
		local channel = Instance.new("TextChannel")
		channel.Name = name
		channel.ShouldDeliverCallback = shouldDeliver
		channel.Parent = TextChatService
		return channel
	end

	-- create the lazy remotes now, clients connect to them on start
	_ = Remote.ChatSend
	_ = Remote.ChatSystem

	local broadcast = newChannel(BROADCAST)
	Util.SafePlayerAdded(function(player)
		Util.Retry(function()
			if player.Parent then
				broadcast:AddUserAsync(player.UserId)
			end
		end)
	end)

	local function getDirectChannel(sender: Player): TextChannel
		local channel = directChannels[sender]
		if not channel then
			channel = newChannel(`KA_Direct_{sender.UserId}`)
			channel:SetDirectChatRequester(sender)
			directChannels[sender] = channel
			directMembers[channel] = { [sender.UserId] = true }
		end
		return channel
	end

	Players.PlayerRemoving:Connect(function(player)
		local channel = directChannels[player]
		if channel then
			directChannels[player] = nil
			directMembers[channel] = nil
			channel:Destroy()
		end
		for _, members in directMembers do
			members[player.UserId] = nil
		end
	end)

	--[=[
		Grants the command's sender one TextChatService message of `kind` and asks their client to send it.
		Delivers to everyone in the server, or only to `targets` through a direct chat channel.

		Global commands from another server can't use TextChatService, they are gated and rate limited like
		announcements by the global command, and their text was filtered in the origin server.

		Returns the grant id, or nil and an error message.
	]=]
	function Chat.send(context: any, kind: string, text: string, targets: { Player }?, data: any?): (string?, string?)
		local id = HttpService:GenerateGUID(false)
		local sender = context.fromPlayer or (context.from and Players:GetPlayerByUserId(context.from))
		if context.global and not (sender and sender.Parent) then
			local escaped = Util.String.escapeRichText(text)
			for _, player in targets or Players:GetPlayers() do
				if player.UserId == context.from or not Auth.hasRestrictedRole(player.UserId) then
					Remote.ChatSystem:Fire(player, kind, escaped, context.from, data, id)
				end
			end
			return id
		end

		if not (sender and sender.Parent) then
			return nil, "Message commands must be run by a player in this server."
		end

		local channel, targetSet, flag = broadcast, nil, nil
		if targets then
			channel = getDirectChannel(sender)
			local members = directMembers[channel]
			local tasks = Util.Tasks.new()
			targetSet = {}
			flag = 1
			for _, player in targets do
				targetSet[player.UserId] = true
				if player == sender then
					flag = 2 -- sender is also a target
				elseif not members[player.UserId] then
					tasks:add(function()
						local ok, source = pcall(channel.AddUserAsync, channel, player.UserId)
						if ok and source then
							source.CanSend = false
							members[player.UserId] = true
						end
					end)
				end
			end
			tasks:wait()
		end

		local metadata = HttpService:JSONEncode({ k = kind, id = id, d = data, t = flag })
		grants[id] = {
			from = sender.UserId,
			metadata = metadata,
			targets = targetSet,
			expires = os.clock() + GRANT_LIFETIME,
		}
		task.delay(GRANT_LIFETIME, function()
			local grant = grants[id]
			grants[id] = nil
			if grant and grant.messageId then
				delivering[grant.messageId] = nil
			end
		end)

		Remote.ChatSend:Fire(sender, channel.Name, text, metadata)
		return id
	end

	--[=[
		Rate limits a free-text reason (ban, kick, shutdown) that other users see. Returns the reason, or nil and
		notifies the player while it is cooling down.
	]=]
	function Chat.limitReason(userId: number, reason: string?): string?
		if not reason then
			return nil
		end
		local err = Chat.cooldown(userId, "reason")
		if not err then
			return reason
		end
		local player = Players:GetPlayerByUserId(userId)
		if player then
			Remote.Notify:Fire(player, { Text = `<b>Reason removed:</b> {err}` })
		end
		return nil
	end
else
	local LocalPlayer = Players.LocalPlayer
	local handlers = {}
	local received = {}
	local waiting: { [string]: { thread } } = {}
	local originals = {}

	--- Registers the client handler for a message kind, called with the filtered text, sender UserId, data and id
	function Chat.onMessage(kind: string, callback: (text: string, from: number, data: any, id: string) -> ())
		handlers[kind] = callback
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
		local timer = task.delay(timeout or 10, function()
			local index = table.find(threads, thread)
			if index then
				table.remove(threads, index)
				task.spawn(thread, nil)
			end
		end)
		local text = coroutine.yield()
		task.cancel(timer)
		return text
	end

	local function dispatch(kind: string, text: string, from: number, data: any, id: string)
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

	local function onMessage(message: TextChatMessage)
		if message.Status ~= Enum.TextChatMessageStatus.Success then
			return
		end
		local source = message.TextSource
		local data = decode(message.Metadata)
		if not (source and data) then
			return
		end
		-- the sender always receives their own message, skip it unless they targeted themselves
		if data.t == 1 and source.UserId == LocalPlayer.UserId then
			return
		end

		-- OnIncomingMessage tags the message text in place, the admin UI uses the untagged original
		local text = originals[message.MessageId] or string.gsub(message.Text, TAG_PATTERN, "")
		originals[message.MessageId] = nil
		dispatch(data.k, Chat.restoreRichText(text), source.UserId, data.d, data.id)
	end

	-- tag KA messages so they stand out from normal chat, only on our own channels
	local function onIncomingMessage(message: TextChatMessage)
		local data = decode(message.Metadata)
		if not data or string.find(message.Text, TAG_PATTERN) then
			return
		end
		if message.Status == Enum.TextChatMessageStatus.Success then
			local id = message.MessageId
			originals[id] = message.Text
			task.delay(30, function()
				originals[id] = nil
			end)
		end
		local properties = Instance.new("TextChatMessageProperties")
		properties.Text = string.format(TAG, Chat.LABELS[data.k] or data.k) .. Chat.restoreRichText(message.Text, true)
		return properties
	end

	local function watchChannel(child: Instance)
		if child:IsA("TextChannel") and string.find(child.Name, PREFIX, 1, true) == 1 then
			child.OnIncomingMessage = onIncomingMessage
			child.MessageReceived:Connect(onMessage)
		end
	end
	TextChatService.ChildAdded:Connect(watchChannel)
	for _, child in TextChatService:GetChildren() do
		watchChannel(child)
	end

	Remote.ChatSystem:Connect(function(kind: string, text: string, from: number, data: any, id: string)
		dispatch(kind, Chat.restoreRichText(text), from, data, id)
	end)

	Remote.ChatSend:Connect(function(channelName: string, text: string, metadata: string)
		local channel = TextChatService:WaitForChild(channelName, 10)
		if channel and channel:IsA("TextChannel") then
			if not channel:FindFirstChildOfClass("TextSource") then
				channel.ChildAdded:Wait()
			end
			local ok, err = pcall(channel.SendAsync, channel, text, metadata)
			if not ok then
				warn(`Kohl's Admin failed to send message: {err}`)
			end
		end
	end)
end

return Chat
