--|  |Core Setup|  |--
task.wait()
local function new(a, b)
	return function(props)
		local c = Instance.new(a)
		for i, v in props do
			if type(i) == "number" then
				v.Parent = c
			else
				c[i] = v
			end
		end
		c.Parent = c.Parent or b
		return c
	end
end
local FindChild
FindChild = function(a, b, c, d, e)
	d, e = pcall(function()
		return a[b]
	end)
	if d then
		return e
	end
	if c then
		for _, d in a:GetChildren() do
			c = FindChild(d, b, true)
			if c then
				return c
			end
		end
	end
	return nil
end
local function WaitForChild(a, b, c)
	repeat
		c = FindChild(a, b)
		task.wait()
	until c
	return c
end
local function wrap(f, ...)
	local success, result = coroutine.resume(coroutine.create(f), ...)
	if not success then
		warn(`Kohl's Admin Infinite Error: {result} \n {debug.traceback()}`)
	end
	return success, result
end
local function S(a)
	return game:GetService(a)
end
local s = {
	Teams = S("Teams"),
	Debris = S("Debris"),
	Content = S("ContentProvider"),
	Gui = S("GuiService"),
	Market = S("MarketplaceService"),
	UIS = S("UserInputService"),
	TP = S("TeleportService"),
	Collection = S("CollectionService"),
	Players = S("Players"),
	Lighting = S("Lighting"),
	Badge = S("BadgeService"),
	Run = S("RunService"),
	RStorage = S("ReplicatedStorage"),
	Insert = S("InsertService"),
	SS = S("SoundService"),
	HTTP = S("HttpService"),
	StarterGui = S("StarterGui"),
	StarterPack = S("StarterPack"),
	StarterPlayer = S("StarterPlayer"),
	User = S("UserService"),
}

local TS, BT, IT, TT, TST, AP, AS, UIT = "Transparency", nil
BT, IT, TT, TST, AP, AS, UIT =
	"Background" .. TS,
	"Image" .. TS,
	"Text" .. TS,
	"TextStroke" .. TS,
	"AbsolutePosition",
	"AbsoluteSize",
	"UserInputType"

local plr, NameCache, Admins, Bans, Logs, CLogs, Cmds, Set =
	game.Players.LocalPlayer, {}, {}, {}, {}, {}, {}, {
		Color = Color3.new(),
		ColorTransparency = 0.8,
		AdminCredit = true,
		AutoCleanDelay = 30,
		CommandBar = true,
		FunCommands = true,
		Prefix = ":",
		GroupAdmin = {},
		VIPAdmin = {},
		ForcedColor = false,
	}

for i, v in { 313101943, 305266753, 305291549, 305807605, 305807572, 305807549, 313321271, 306774746 } do
	s.Content:Preload("rbxassetid://" .. v)
end
repeat
	task.wait()
until plr:GetMouse() and workspace.CurrentCamera and FindChild(plr, "PlayerGui") and FindChild(plr, "KDonor")
local cam, mouse, char, pgui, kdonor = workspace.CurrentCamera, plr:GetMouse(), plr.Character, plr.PlayerGui, plr.KDonor
local server, SN, f, admstr, banstr, logb, clogb =
	WaitForChild(s.RStorage, "b\a\n\a\n\a"),
	"Kohl's Admin Infinite",
	{ s = script, template = require(script:WaitForChild("Templates")), uID = "" },
	nil
admstr, banstr, logb, clogb =
	FindChild(server, "\admi\n"), FindChild(server, "\b\a\n"), FindChild(server, "log"), FindChild(server, "clog")

local CoreUI = new("ScreenGui")({ Name = "KCoreUI", IgnoreGuiInset = true, ResetOnSpawn = false, Parent = pgui })

function f.unMapTab(a, b)
	b = {}
	for i, v in a do
		if type(v) == "table" then
			b[tostring(i)] = f.unMapTab(v)
		else
			b[tonumber(i)] = v
		end
	end
	return b
end
function f.AssetInfo(a)
	return s.Market:GetProductInfo(a)
end
function f.RImage(a, b, c)
	b = f.AssetInfo(a)
	if b.AssetTypeId == 1 then
		return a
	end
	b, c = b.Creator.Id, a
	repeat
		c = c - 1
	until f.AssetInfo(a).Creator.Id == b or a - c > 10
	return c
end
function f.unCache(a, b, c, d)
	b = {}
	for i in a:gmatch("%S+") do
		c, d = i:match("(.+):(.+)")
		b[tonumber(c)] = tonumber(d)
	end
	return b
end
function f.Merge(a, b)
	for i, v in b do
		a[i] = v
	end
	return a
end
function f.UpdateAdmins()
	Admins = f.unCache(admstr.Value)
end
function f.Stroke(a)
	return math.max(a.r, a.g) > 0.5 and Color3.new() or Color3.new(1, 1, 1)
end
function f.Hide(o, r, d, c)
	d = d or 0.2
	if not c then
		local a
		c = {}
		a = function(b, i)
			i = {}
			for _, p in { IT, TT, TST, BT } do
				if FindChild(b, p) and b[p] ~= 1 then
					i[p] = { b[p], 1 - b[p] }
				end
			end
			i = { b, i }
			c[#c + 1] = i
			for i, v in b:GetChildren() do
				a(v)
			end
		end
		a(o)
		o.Visible = true
	end
	if d ~= 0 then
		local s, id, k = tick(), 1 / d, nil
		repeat
			k = (tick() - s) * id
			for _, v in c do
				for i, p in v[2] do
					v[1][i] = p[1] + p[2] * k
				end
			end
			task.wait()
		until k >= 1
	end
	o.Visible = false
	if r then
		o:Destroy()
	else
		for _, v in c do
			for i, p in v[2] do
				v[1][i] = p[1]
			end
		end
	end
end
function f.Show(o, d, c)
	d = d or 0.2
	if not c then
		local a
		c = {}
		a = function(b, i)
			i = {}
			for _, p in { IT, TT, TST, BT } do
				if FindChild(b, p) and b[p] ~= 1 then
					i[p] = { b[p], 1 - b[p] }
					b[p] = 1
				end
			end
			i = { b, i }
			c[#c + 1] = i
			for i, v in b:GetChildren() do
				a(v)
			end
		end
		a(o)
		o.Visible = true
	end
	if d ~= 0 then
		local s, id, k = tick(), 1 / d, nil
		repeat
			k = 1 - (tick() - s) * id
			for _, v in c do
				for i, p in v[2] do
					v[1][i] = p[1] + p[2] * k
				end
			end
			task.wait()
		until k <= 0
	end
	for _, v in c do
		for i, p in v[2] do
			v[1][i] = p[1]
		end
	end
end
function f.Drag(o, x, y, d, p, b, c)
	p = o.Parent
	o.InputBegan:connect(function(io)
		if io[UIT] == Enum[UIT].MouseButton1 or io[UIT] == Enum[UIT].Touch then
			local _d = Vector2.new(o[AP].X - mouse.X, o[AP].Y - (mouse.Y - s.Gui.TopbarInset.Height))
			d = _d
			c = s.UIS.InputEnded:connect(function(io)
				if io[UIT] == Enum[UIT].MouseButton1 or io[UIT] == Enum[UIT].Touch then
					d = nil
				end
			end)
			while d == _d and o and o.Parent == p do
				b = (x and y) and Vector2.new(x, y) or Vector2.new(o[AS].X, o[AS].Y)
				o.Position = UDim2.new(
					0,
					math.clamp(mouse.X + d.x, 0, CoreUI.AbsoluteSize.X - b.x),
					0,
					math.clamp(mouse.Y + d.y, 0, CoreUI.AbsoluteSize.Y - b.y)
				)
				task.wait()
			end
			c:disconnect()
		end
	end)
end
function f.Resize(o, x, y, p, r, c, d)
	p = o.Parent
	r = f.template.Resize:Clone()
	r.Parent = o
	r.InputBegan:connect(function(io)
		if io[UIT] == Enum[UIT].MouseButton1 or io[UIT] == Enum[UIT].Touch then
			local _d = {
				x = mouse.X,
				y = mouse.Y,
				s = o.AbsoluteSize,
				m = Vector2.new(mouse.ViewSizeX - o.AbsolutePosition.X, mouse.ViewSizeY - o.AbsolutePosition.Y),
			}
			d = _d
			c = s.UIS.InputEnded:connect(function(io)
				if io[UIT] == Enum[UIT].MouseButton1 or io[UIT] == Enum[UIT].Touch then
					d = nil
				end
			end)
			while d == _d and o and o.Parent == p do
				o.Size = UDim2.new(
					0,
					math.min(d.m.X, math.max(x or 20, d.s.X + (mouse.X - d.x))),
					0,
					math.min(d.m.Y, math.max(y or 20, d.s.Y + (mouse.Y - d.y)))
				)
				task.wait()
			end
			c:disconnect()
		end
	end)
end
function f.UpdateVar()
	cam = cam or workspace.CurrentCamera
	plr = plr or game.Players.LocalPlayer
	char = plr.Character
	pgui = WaitForChild(plr, "PlayerGui")
	mouse = mouse or plr:GetMouse()
end
function f.MatchPlr(a, b, c)
	a = a or ""
	a, b = "^" .. a:lower(), ""
	for i, v in s.Players:GetPlayers() do
		i = v.Name:lower():match(a)
		if i and #i > #b then
			b, c = i, v
		end
	end
	return c
end
function f.MatchClr(a, b)
	b = BrickColor.new(a:sub(1, 1):upper() .. a:sub(2))
	b = b ~= BrickColor.new(0) and b or nil
	if not b then
		for i, v in { "New Yeller", "Pastel Blue", "Dusty Rose", "CGA brown" } do
			if a:lower():find("^" .. v) then
				b = BrickColor.new(v)
			end
		end
	end
	if not b and a:find("^random") then
		b = BrickColor.Random()
	end
	b = b and b.Color
	return b
end
function f.Has(a, b)
	return s.Market:PlayerOwnsAsset(a, b)
end
function f.onCam(a)
	return (cam.CFrame:inverse() * a).z < 0
end
function f.PredictCmds(a, b)
	a, b = a:lower():gsub(Set.Prefix, ""), {}
	for i, v in Cmds do
		for i, c in v[1] do
			if c:lower():find("^" .. a) and math.abs(Admins[plr.userId] or 0) >= (v[3] or 0) then
				table.insert(
					b,
					(v[2][2] and c .. " " .. (v[2][2] or "") .. "\t" or "")
						.. "["
						.. c
						.. (#v[4] > 0 and " " .. table.concat(v[4], " ") or "")
						.. "]\t"
						.. v[2][1]
				)
			end
		end
	end
	return b
end
function f.getTime(t, s)
	t = t % 86400
	s = { t % 60, t % 3600 / 60, t / 3600 }
	for i, v in s do
		v = math.floor(v)
		s[i] = (10 > v and "0" .. v or v)
	end
	return s[3] .. ":" .. s[2] .. ":" .. s[1]
end
function f.getTitle(a)
	return a == 8 and "Admin Creator"
		or a >= 6 and "Game Creator"
		or a == 5 and "Owner"
		or a == 4 and "Super Admin"
		or a == 3 and "Administrator"
		or a == 2 and "Moderator"
		or a == 1 and "VIP"
		or "Player"
end
function f.getNameFromId(a, b)
	a, b = pcall(function()
		return NameCache[a] or s.Players:GetNameFromUserIdAsync(a)
	end)
	b = a and b or "???"
	if b ~= "???" then
		NameCache[a] = b
	end
	return b
end
function f.getNamesFromIds(a)
	local b = {}
	local c = {}
	local function flush()
		local success, infos = pcall(s.User.GetUserInfosByUserIdsAsync, s.User, c)
		if success then
			for i, v in infos do
				NameCache[v.Id] = v.Username
				table.insert(b, v)
			end
		end
		table.clear(c)
	end
	for i, v in a do
		local result = NameCache[v]
		if result then
			table.insert(b, { Id = v, Username = result })
		else
			table.insert(c, v)
			if #c >= 200 then
				flush()
			end
		end
	end
	if #c > 0 then
		flush()
	end
	return b
end
function f.getWords(a, b)
	b = {}
	for c in a:gmatch("%S+") do
		b[#b + 1] = c
	end
	return b
end
function f.getCmds(a, b, c)
	a, b, c = a:lower(), {}, 0
	for i, v in f.getWords(a) do
		if v:find(Set.Prefix, 1, true) == 1 then
			v = v:sub(#Set.Prefix + 1)
			for i2, v2 in Cmds do
				for _, nm in v2[1] do
					if v == nm:lower() then
						c = c + a:sub(c + 1, #a):find(Set.Prefix .. nm:lower())
						if #b > 0 then
							b[#b][3] = c - 1
						end
						b[#b + 1] = { v2, c }
					end
				end
			end
		end
	end
	return b
end

local baseText = new("TextBox")({
	AutoLocalize = false,
	Font = "SourceSans",
	FontSize = "Size14",
	TextColor3 = Color3.new(1, 1, 1),
	BackgroundColor3 = Color3.new(),
	[TST] = 0.75,
	[BT] = 1,
	BorderSizePixel = 0,
	TextXAlignment = "Left",
	Size = UDim2.new(1, -10, 0, 20),
	ClipsDescendants = true,
	Selectable = true,
	TextEditable = false,
	ClearTextOnFocus = false,
	ZIndex = 7,
})
local Curr = { LastSpace = 0, Fly = nil, Noclip = nil, Note = nil }
local isTyping
s.UIS.TextBoxFocused:connect(function()
	isTyping = true
end)
s.UIS.TextBoxFocusReleased:connect(function()
	isTyping = false
end)
admstr.Changed:connect(f.UpdateAdmins)
banstr.Changed:connect(function()
	Bans = f.unCache(banstr.Value)
end)
f.UpdateAdmins()
Bans = f.unCache(banstr.Value)
char = plr.Character or plr.CharacterAdded:Wait()

local cmdHistory = {}
local cmdHistoryOffset = -1

local cmdb, CmdFading, CmdBar = f.template.CommandBar:Clone(), false, nil
CmdBar = cmdb.CmdBar
cmdb.Parent = CoreUI
CmdBar.FocusLost:connect(function(a, b)
	b = CmdBar.Text
	if a and b:gsub("%s", "") ~= "" then
		-- remove existing history
		local index = table.find(cmdHistory, b)
		if index then
			table.remove(cmdHistory, index)
		end
		-- remove old history
		if #cmdHistory > 32 then
			table.remove(cmdHistory, 1)
		end
		-- append to end of history and reset offset
		cmdHistoryOffset = -1
		table.insert(cmdHistory, b)
		server:FireServer(f.uID .. "KCmdBar", (b:find(Set.Prefix, 1, true) == 1 and "" or Set.Prefix) .. b)
	end
	if not CmdFading and cmdb.Visible then
		CmdFading = true
		f.Hide(cmdb)
		CmdFading = false
	end
	CmdBar.Text = ""
end)
CmdBar.Changed:connect(function(a)
	local list = cmdb:FindFirstChild("List")
	if not list then
		return
	end
	a = CmdBar.Text:match("%w+") or ""
	a = #a > 0 and f.PredictCmds(a) or {}
	for i, v in list:GetChildren() do
		v.Visible = a[i] and true or false
		v.Text = a[i] or ""
	end
end)
s.UIS.InputBegan:connect(function(io, processed)
	if not isTyping and not processed and io.KeyCode == Enum.KeyCode.Space then
		local b = Curr.Noclip or Curr.Fly
		if b and tick() - Curr.LastSpace < 0.3 then
			b.Value = not b.Value
		end
		Curr.LastSpace = tick()
		return
	end
	if not Set.CommandBar then
		return
	end
	if
		(Set.CommandBar or FindChild(plr, "KCmdBar"))
		and not isTyping
		and not processed
		and io.KeyCode == Enum.KeyCode.Semicolon
		and not CmdFading
	then
		task.wait()
		CmdBar:CaptureFocus()
		if not cmdb.Visible then
			CmdFading = true
			f.Show(cmdb)
			CmdFading = false
		end
	elseif io.KeyCode == Enum.KeyCode.Up and CmdBar:IsFocused() and (Set.CommandBar or FindChild(plr, "KCmdBar")) then
		cmdHistoryOffset = math.clamp(cmdHistoryOffset + 1, -1, #cmdHistory - 1)
		CmdBar.Text = cmdHistory[#cmdHistory - cmdHistoryOffset] or CmdBar.Text
		CmdBar.CursorPosition = #CmdBar.Text + 1
	elseif io.KeyCode == Enum.KeyCode.Down and CmdBar:IsFocused() and (Set.CommandBar or FindChild(plr, "KCmdBar")) then
		cmdHistoryOffset = math.clamp(cmdHistoryOffset - 1, -1, #cmdHistory - 1)
		CmdBar.Text = cmdHistory[#cmdHistory - cmdHistoryOffset] or ""
		CmdBar.CursorPosition = #CmdBar.Text + 1
	end
end)

--|  Credit Setup  |--
local lastAttemptedPurchase
local Credit, CredF, cm = f.template.Credit:Clone(), false, nil
cm = Credit.Main
Credit.Parent = CoreUI
f.Drag(cm, 250, 250)
function ToggleCredit()
	if not CredF then
		CredF = true
		f[cm.Visible and "Hide" or "Show"](cm)
		CredF = false
	end
end
Credit.Toggle.MouseButton1Click:connect(ToggleCredit)
cm.Close.MouseButton1Click:connect(ToggleCredit)
cm.Trail.Visible, cm.Hat.Visible, cm.Shine.Visible = kdonor.Value > 0, kdonor.Value > 2, kdonor.Value > 3
kdonor.Changed:Connect(function()
	cm.Trail.Visible, cm.Hat.Visible, cm.Shine.Visible = kdonor.Value > 0, kdonor.Value > 2, kdonor.Value > 3
end)
cm.Get.MouseButton1Click:connect(function()
	s.Market:PromptPurchase(plr, 172732271)
end)
for i, v in { { 5391355, 10 }, { 5391356, 100 }, { 5391359, 250 }, { 5391361, 500 }, { 5411126, 1000 } } do
	local obj = cm["D" .. i]
	local success, info = pcall(s.Market.GetProductInfo, s.Market, v[1], Enum.InfoType.GamePass)
	obj.Text = (success and info.PriceInRobux or v[2]) .. " R$"
	obj.MouseButton1Click:Connect(function()
		lastAttemptedPurchase = v[1]
		s.Market:PromptGamePassPurchase(plr, v[1])
	end)
end
cm.Hat.MouseButton1Click:connect(function()
	server:FireServer(f.uID .. "KHat")
end)
cm.Trail.MouseButton1Click:connect(function()
	server:FireServer(f.uID .. "KTrail")
end)
cm.Shine.MouseButton1Click:connect(function()
	server:FireServer(f.uID .. "KShine")
end)
wrap(function()
	local a, b, t = false, 1, nil
	repeat
		task.wait(1)
		t = tick()
		repeat
			task.wait()
			b = tick() - t
			local c = a and b or math.max(0, 1 - b)
			Credit.Toggle.ImageColor3 = Color3.new(c, c, c)
		until b > 1
		a = not a
	until nil
end)

-- thirdpartysales stuff?
local LogService = game:GetService("LogService")
local Direct = f.template.Direct:Clone()
Direct.Parent = CoreUI

Direct.Close.MouseButton1Click:Connect(function()
	Direct.Visible = false
end)

LogService.MessageOut:Connect(function(message, messageType)
	if
		messageType == Enum.MessageType.MessageWarning
		and string.find(message, "AllowThirdPartySales")
		and string.find(message, "3403354")
		and lastAttemptedPurchase
	then
		Direct.Link.Text = "roblox.com/game-pass/" .. lastAttemptedPurchase
		Direct.Visible = true
	end
end)

-- socials
local PolicyService = game:GetService("PolicyService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local success, result = pcall(function()
	return PolicyService:GetPolicyInfoForPlayerAsync(player)
end)

if success and result.AllowedExternalLinkReferences and table.find(result.AllowedExternalLinkReferences, "Discord") then
	cm.Position = UDim2.new(0.5, -125, 0.5, -144)
	cm.Trail.Position = UDim2.new(0, 0, 1, 268)
	cm.Hat.Position = UDim2.new(0, 83, 1, 268)
	cm.Shine.Position = UDim2.new(1, -82, 1, 268)
	cm.Social.Visible = true
	cm.Social.Text = "discord.gg/bwCC7gV"
	f.template.Help.BG.Social.Visible = true
	f.template.Help.BG.Social.Text = "discord.gg/bwCC7gV"
end

-- TextChatService compatibility
local TextChatService = game:GetService("TextChatService")
TextChatService.SendingMessage:Connect(function(message)
	if string.find(message.Text, Set.Prefix, 1, true) == 1 then
		server:FireServer(f.uID .. "KCmdBar", message.Text)
	end
end)

--|  Cape Setup  |--
local function Cape(c, clr, d, t, h)
	clr, t, h = clr or Color3.new(), FindChild(c, "HumanoidRootPart"), FindChild(c, "Humanoid")
	if not (c and t and h) then
		return
	end
	local c0, ca, cv, tv = CFrame.new(0, 0.925, 0.5), -3, 0, 0
	local p, w = new("Part")({
		Name = "KCape",
		Parent = c,
		CanCollide = false,
		[TS] = 1,
		FormFactor = 3,
		Size = Vector3.new(1.9, 3.8, 0.2),
		TopSurface = 0,
		BottomSurface = 0,
	})
	w = new("Weld")({
		Parent = t,
		Part0 = t,
		Part1 = p,
		C0 = c0 * CFrame.Angles(math.rad(ca), 0, 0),
		C1 = CFrame.new(0, 1.9, 0),
	})
	new("SelectionBox")({
		Parent = p,
		Adornee = p,
		SurfaceColor3 = clr,
		["Surface" .. TS] = 0,
		[TS] = 1,
		LineThickness = 0,
	})
	if d then
		new("SurfaceGui")({
			Parent = p,
			Face = "Back",
			new("ImageLabel")({
				Size = UDim2.new(1, 0, 1, 0),
				[BT] = 1,
				Image = d and "rbxassetid://" .. f.RImage(d) or "",
			}),
		})
	end
	local function Animate(a)
		wrap(function()
			while not a do
				cv = (t.CFrame:inverse() * (t.CFrame + h.MoveDirection)).z * t.Velocity.magnitude
				task.wait()
			end
		end)
		wrap(function()
			while p and f.onCam(p.Position) do
				task.wait()
				tv = t.Velocity.y
				ca = math.min(-3, math.max(ca * 0.9 + (tv + cv) * 0.25, tv < 0 and -170 or -100))
				w.C0 = c0 * CFrame.Angles(math.rad(ca), 0, 0)
			end
			a = true
			if p then
				while p and not f.onCam(p.Position) do
					task.wait()
				end
				Animate()
			end
		end)
	end
	Animate()
end

--|  Crown Setup  |--

local crowns, rainbowcrowns = s.Collection:GetTagged("KAICrown"), s.Collection:GetTagged("KAIRCrown")
s.Run.Heartbeat:connect(function()
	if #crowns > 0 or #rainbowcrowns > 0 then
		local t = time()
		local tpi = t % (math.pi * 2)
		local AP = CFrame.new(0, math.sin(tpi) / 8, 0) * CFrame.Angles(0, tpi, 0)
		local color = Color3.fromHSV((t / 10) % 1, 1, 1)
		for i, v in crowns do
			if v and v.Parent then
				if v.Handle:FindFirstChild("AccessoryWeld") then
					v.Handle.AccessoryWeld.C1 = AP
				end
			else
				table.remove(crowns, i)
			end
		end
		for i, v in rainbowcrowns do
			if v and v.Parent then
				if v.Handle:FindFirstChild("AccessoryWeld") then
					v.Handle.AccessoryWeld.C1 = AP
				end
				v.Handle.Color, v.Handle.Fire.SecondaryColor = color, color
			else
				table.remove(rainbowcrowns, i)
			end
		end
	end
end)
s.Collection:GetInstanceAddedSignal("KAICrown"):Connect(function(obj)
	table.insert(crowns, obj)
end)
s.Collection:GetInstanceAddedSignal("KAIRCrown"):Connect(function(obj)
	table.insert(rainbowcrowns, obj)
end)
s.Collection:GetInstanceRemovedSignal("KAICrown"):Connect(function(obj)
	table.remove(crowns, table.find(crowns, obj))
end)
s.Collection:GetInstanceRemovedSignal("KAIRCrown"):Connect(function(obj)
	table.remove(rainbowcrowns, table.find(rainbowcrowns, obj))
end)

--|  Event Setup  |--
function f.HookList(a, b, c, d)
	d = FindChild(a, "List") or FindChild(a, "BG")
	local FadeB = false
	b = a.Hide.MouseButton1Click:connect(function()
		if not FadeB then
			FadeB = true
			if d.Parent.Name ~= "BG" then
				wrap(f[a.BG.Visible and "Hide" or "Show"], d)
			end
			f[a.BG.Visible and "Hide" or "Show"](a.BG)
			a.Hide.Text = a.BG.Visible and "-" or "+"
			FadeB = false
		end
	end)
	c = a.Close.MouseButton1Click:connect(function()
		b:disconnect()
		c:disconnect()
		f.Hide(a, true)
	end)
end
f.CreateList = function(a, b, c, d)
	b = f.template.List:Clone()
	b.Parent = CoreUI
	b.Title.Text, b.Name = a, a
	f.HookList(b)
	return b
end
f.FixUI = function(a)
	if a.Name == "BG" or a.Name == "Bar" then
		a[BT] = Set["Color" .. TS]
		a.BackgroundColor3 = Set.Color
	end
	for i, v in a:GetChildren() do
		f.FixUI(v)
	end
end
f.UpdateUI = function()
	if not Set.ForcedColor then
		if FindChild(plr, "KColor") then
			Set.Color = plr.KColor.Value
		end
		if FindChild(plr, "KColor" .. TS) then
			Set["Color" .. TS] = plr["KColor" .. TS].Value
		end
	end
	f.FixUI(CoreUI)
	for _, v in f.template do
		f.FixUI(v)
	end
end
f.UpdateSet = function()
	f.UpdateAdmins()
	Credit.Toggle.Visible = Set.AdminCredit
	f.UpdateUI()
end
f.BumpList = function(a)
	for i, v in a.List:GetChildren() do
		v.Position = UDim2.new(0, 5, 0, (i - 1) * 20)
	end
end
f.NoteCheck = function(a, b)
	return a[1] <= b.X and a[2] >= b.X and a[3] <= b.Y and a[4] >= b.Y
end
f.Note = function(a, b, c, d)
	a.MouseEnter:connect(function()
		c = Curr.Note
		if c then
			c:Destroy()
		end
		c = f.template.Note:Clone()
		Curr.Note = c
		c.Text, c.Parent = b or "", CoreUI
		c.Size = UDim2.new(0, c.TextBounds.X + 10, 0, 24)
		c.Visible = true
		wrap(function()
			d = { a[AP].X, a[AP].X + a[AS].X, a[AP].Y, a[AP].Y + a[AS].Y }
			repeat
				c.Position = UDim2.new(0, mouse.X, 0, mouse.Y + s.Gui.TopbarInset.Height - 8)
				task.wait()
			until not (c and mouse and f.NoteCheck(d, mouse))
			if c then
				c:Destroy()
			end
		end)
	end)
end
f.Search = function(a, b, c, d)
	c, d = c or function(a, b)
		return a == b
	end, {}
	for i, v in a do
		if c(v, b) then
			if type(i) == "string" then
				d[i] = v
			else
				d[#d + 1] = v
			end
		end
	end
	return d
end
f.GetSearch = function(a, b)
	b = f.template.Search:Clone()
	b.Parent = a
	return b
end
f.KeyDown = function(a)
	return s.UIS:IsKeyDown(a)
end
f.HookToggle = function(a, b)
	a.MouseButton1Click:connect(function(c)
		c = a.BackgroundColor3 == Color3.new()
		a.BackgroundColor3 = c and Color3.new(1, 1, 1) or Color3.new()
		if b then
			b(a, c)
			server:FireServer(f.uID .. "KUpdate", Set)
		end
	end)
end
f.HookInput = function(a, b)
	a.Changed:connect(function(c)
		if c == "Text" and a.Text ~= "" then
			b(a)
			server:FireServer(f.uID .. "KUpdate", Set)
		end
	end)
end
local SDesc = {
	Flat = "Gives the UI a flat appearance",
	ForcedColor = "Forces everyone to have set color & transparency",
	Color = "Changes the Color of the user interface",
	ColorTransparency = "Changes the Transparency of the user interface",
	AdminCredit = "Enables the credit GUI for that appears in the bottom right",
	AutoClean = "Enables automatic cleaning of hats & tools in the Workspace",
	AutoCleanDelay = "The delay between each AutoClean routine",
	CommandBar = "Enables the Command Bar | GLOBAL KEYBIND: ;",
	FunCommands = "Enables fun yet unnecessary commands",
	FreeAdmin = "Set to 1-5.	1-VIP 2-Mod 3-Admin 4-SuperAdmin 5-Owner",
	PublicLogs = "Allows all users to see the command & chat logs",
	Prefix = "Character to begin a command",
}
local musicMuted = false

function ClientEvent(a, b)
	if a == "KuID" then
		f.uID, Admins, Set, Cmds, Logs, CLogs = b[1], b[2], b[3], b[4], b[5], b[6]
		f.UpdateSet()
		return
	end
	if not (cam and plr and char and mouse and pgui) then
		f.UpdateVar()
	end
	if a == "KCrash" then
		repeat
		until nil
	elseif a == "KPing" then
		server:FireServer(f.uID .. "KPing")
	elseif a == "KUpdate" and b then
		Set = b
		f.UpdateSet()
	elseif a == "KUpdateLog" and b then
		if #Logs > 300 then
			table.remove(Logs, #Logs)
		end
		table.insert(Logs, 1, b)
		logb.Value = not logb.Value
	elseif a == "KUpdateCLog" and b then
		if #CLogs > 300 then
			table.remove(CLogs, #CLogs)
		end
		table.insert(CLogs, 1, b)
		clogb.Value = not clogb.Value
	elseif a == "KUpdateLogs" and b then
		Logs = b
		table.sort(Logs, function(a, b)
			return a[1] > b[1]
		end)
		logb.Value = not logb.Value
	elseif a == "KUpdateCLogs" and b then
		CLogs = b
		table.sort(CLogs, function(a, b)
			return a[1] > b[1]
		end)
		clogb.Value = not clogb.Value
	elseif a == "KFakeChat" then
		server:FireServer(f.uID .. "KChat", { plr.Name, b })
	elseif a == "KBuy" then
		s.Market:PromptPurchase(plr, b)
	elseif a == "KBuyBundle" then
		s.Market:PromptBundlePurchase(plr, b)
	elseif a == "KBuyGamePass" then
		s.Market:PromptGamePassPurchase(plr, b)
	elseif a == "KBuyProduct" then
		s.Market:PromptProductPurchase(plr, b)
	elseif a == "KHelp" then
		local existing = FindChild(CoreUI, "Help")
		if existing then
			wrap(f.Hide, existing, true)
		end
		local new = f.template.Help:Clone()
		new.List.Prefix.Text = 'The prefix is "' .. Set.Prefix .. '"'
		new.Parent = CoreUI
		f.HookList(new)
		f.Drag(new, 300, 300)
		f.Show(new)
	elseif a == "KTools" then
		if FindChild(CoreUI, "Tools") then
			wrap(f.Hide, CoreUI.Tools, true)
		end
		local Tools = f.CreateList("Tools")
		table.sort(b)
		for i, v in b do
			local t = baseText:Clone()
			t.Parent, t.Text, t.Position = Tools.List, v, UDim2.new(0, 5, 0, (i - 1) * 20)
		end
		Tools.List.CanvasSize = UDim2.new(1, 0, 0, #Tools.List:GetChildren() * 20)
		f.Drag(Tools, 200, 220)
		f.Show(Tools)
	elseif a == "KSettings" then
		a = FindChild(CoreUI, "Settings")
		if a then
			wrap(f.Hide, a, true)
		end
		if not b then
			return
		end
		Set = b
		local SL = f.template.Settings:Clone()
		SL.Parent = CoreUI
		f.HookList(SL)
		if Set.IGS then
			SL.Toggle.BackgroundColor3 = Color3.new(1, 1, 1)
			SL.List.Visible = true
		end
		f.HookToggle(SL.Toggle, function(a, b)
			Set.IGS, a.Parent.List.Visible = b, b
			if not b then
				wrap(f.Hide, SL, true)
			end
		end)
		for i, v in SL.List:GetChildren() do
			if not v:IsA("GuiObject") then
				continue
			end
			i = v.Text
			if Set[i] ~= nil then
				f.Note(v, SDesc[i])
				if i == "Color" then
					v.Input1.Text, v.Input2.Text, v.Input3.Text = Set[i].r * 255, Set[i].g * 255, Set[i].b * 255
					f.HookInput(v.Input1, function(a, b)
						b = tonumber(a.Text)
						if b and b <= 255 and b >= 0 then
							Set[i] = Color3.new(b / 255, Set[i].g, Set[i].b)
						else
							a.Text = Set[i]
						end
					end)
					f.HookInput(v.Input2, function(a, b)
						b = tonumber(a.Text)
						if b and b <= 255 and b >= 0 then
							Set[i] = Color3.new(Set[i].r, b / 255, Set[i].b)
						else
							a.Text = Set[i]
						end
					end)
					f.HookInput(v.Input3, function(a, b)
						b = tonumber(a.Text)
						if b and b <= 255 and b >= 0 then
							Set[i] = Color3.new(Set[i].r, Set[i].g, b / 255)
						else
							a.Text = Set[i]
						end
					end)
				elseif i == "ColorTransparency" then
					v.Input.Text = Set[i]
					f.HookInput(v.Input, function(a, b)
						b = tonumber(a.Text)
						if b and b <= 1 and b >= 0 then
							Set[i] = b
						elseif a.Text ~= "." then
							a.Text = Set[i]
						end
					end)
				elseif i == "AutoCleanDelay" then
					v.Input.Text = Set[i]
					f.HookInput(v.Input, function(a, b)
						b = tonumber(a.Text)
						if b and b >= 0 then
							Set[i] = b
						else
							a.Text = Set[i]
						end
					end)
				elseif i == "Prefix" then
					v.Input.Text = Set[i]
					f.HookInput(v.Input, function(a, b)
						b = a.Text:gsub("%s", "")
						if #b == 1 then
							Set[i] = b
						else
							a.Text = Set[i]
						end
					end)
				elseif i == "FreeAdmin" then
					v.Input.Visible, v.Input.Text, v.Toggle.BackgroundColor3 =
						Set[i], Set[i] or "", Set[i] and Color3.new(1, 1, 1) or Color3.new()
					f.HookInput(v.Input, function(a, b)
						b = tonumber(a.Text)
						if b and b < 6 and b > 0 then
							Set[i] = b
						else
							a.Text = Set[i]
						end
					end)
					f.HookToggle(v.Toggle, function(a, b)
						v.Input.Visible = b
						if not b then
							Set[i] = b
						end
					end)
				elseif FindChild(v, "Toggle") then
					v.Toggle.BackgroundColor3 = Set[i] and Color3.new(1, 1, 1) or Color3.new()
					f.HookToggle(v.Toggle, function(a, b)
						Set[i] = b
					end)
				end
			end
		end
		f.Drag(SL, 200, 220)
		f.Show(SL)
	elseif a == "KCmds" then
		local existing = FindChild(CoreUI, "Commands")
		if existing then
			wrap(f.Hide, existing, true)
		end
		local list = {}
		local CL, nl, ol = f.CreateList("Commands"), f.template.Blank:Clone()
		ol = CL.List
		nl.Parent, nl.Name, ol.Parent = CL, "List", nl
		CL.Size = UDim2.new(0, 300, 0, 20)
		ol.Size = UDim2.new(1, 0, 0, 260)
		CL.BG.Size = UDim2.new(1, 0, 0, 260)
		for i, v in b[1] do
			if v[3] <= b[2] or b[3][v[1][1]] then
				table.insert(list, v)
			end
		end
		table.sort(list, function(a, b)
			return a[1][1] < b[1][1]
		end)
		local SetList = function(a)
			for i, v in ol:GetChildren() do
				v:Destroy()
			end
			for i, v in a do
				local t = baseText:Clone()
				t.FontSize, t.Parent, t.Text, t.Position =
					"Size18",
					ol,
					i .. "\t" .. v[1][1] .. " " .. table.concat(v[4], " "),
					UDim2.new(0, 5, 0, (i - 1) * 20)
				f.Note(
					t,
					f.getTitle(v[3]) .. "+\t" .. Set.Prefix .. "[" .. table.concat(v[1], "/") .. "] " .. (v[2][2] or "")
				)
			end
			ol.CanvasSize = UDim2.new(1, 0, 0, #ol:GetChildren() * 20)
		end
		local S = f.GetSearch(nl).BG
		S.Parent.Position = UDim2.new(0, 0, 0, 282)
		S.Changed:connect(function(p)
			if p == "Text" then
				SetList(f.Search(a, S.Text, function(a, b, c)
					for i, v in a[1] do
						if v:lower():find(b:lower()) then
							c = true
						end
					end
					return c
				end))
			end
		end)
		SetList(a)
		f.Drag(CL, 300, 300)
		f.Show(CL)
	elseif a == "KAdmins" then
		local existing = FindChild(CoreUI, "Admins")
		if existing then
			wrap(f.Hide, existing, true)
		end
		local AL = f.CreateList("Admins")
		local function List()
			local list = {}
			for i, v in AL.List:GetChildren() do
				v:Destroy()
			end
			for i, v in Admins do
				if math.abs(v) ~= 1 or s.Players:GetPlayerByUserId(i) then
					table.insert(list, i)
				end
			end
			local names = f.getNamesFromIds(list)
			table.sort(names, function(a, b)
				local pa = math.abs(Admins[a.Id])
				local pb = math.abs(Admins[b.Id])
				if pa > pb then
					return true
				elseif pa < pb then
					return false
				else
					return a.Username < b.Username
				end
			end)
			for i, v in names do
				local p = Admins[v.Id]
				local t, t2 = baseText:Clone(), baseText:Clone()
				t2.Text, t2.TextXAlignment, t2.Parent, t2.Size, t2.Position =
					(p < 0 and "P. " or "") .. f.getTitle(math.abs(p)),
					"Right",
					t,
					UDim2.new(0.5, 0, 0, 20),
					UDim2.new(0.5, 0, 0, 0)
				t.Parent, t.Text, t.Position = AL.List, v.Username, UDim2.new(0, 5, 0, (i - 1) * 20)
				AL.List.CanvasSize = UDim2.new(1, 0, 0, #AL.List:GetChildren() * 20)
			end
		end
		List()
		local con
		con = admstr.Changed:connect(function()
			if not (AL and AL.Parent == CoreUI) then
				con:disconnect()
				return
			end
			task.wait()
			List()
		end)
		f.Drag(AL, 200, 220)
		f.Show(AL)
	elseif a == "KBans" then
		a = FindChild(CoreUI, "Bans")
		if a then
			wrap(f.Hide, a, true)
		end
		local BL = f.CreateList("Bans")
		local function List()
			local list = {}
			for i, v in BL.List:GetChildren() do
				v:Destroy()
			end
			for i, v in Bans do
				table.insert(list, tonumber(i))
			end
			local names = f.getNamesFromIds(list)
			table.sort(names, function(a, b)
				local ba = string.lower(Bans[a.Id])
				local bb = string.lower(Bans[b.Id])
				if ba > bb then
					return true
				elseif ba < bb then
					return false
				else
					return string.lower(a.Username) < string.lower(b.Username)
				end
			end)
			for i, v in names do
				local t, t2 = baseText:Clone(), baseText:Clone()
				wrap(function()
					t2.TextXAlignment = "Right"
					t2.Size = UDim2.new(0.5, 0, 0, 20)
					t2.Position = UDim2.new(0.5, 0, 0, 0)
					t2.Text = Bans[v.Id] < 2 and "Permanently" or "From Server"
					t2.Parent = t
					t.Text = v.Username
					t.Position = UDim2.new(0, 5, 0, (i - 1) * 20)
					t.Parent = BL.List
					BL.List.CanvasSize = UDim2.new(1, 0, 0, #BL.List:GetChildren() * 20)
					if Bans[v.Id] < -1 then
						local tb, tm = -Bans[v.Id], nil
						repeat
							tm = math.floor(tb - os.time())
							t2.Text = tm .. " seconds"
							task.wait(1)
						until not t or tm <= 0
						if t then
							t:Destroy()
							f.BumpList(BL)
						end
					end
				end)
			end
		end
		List()
		local con
		con = banstr.Changed:connect(function()
			if not (BL and BL.Parent == CoreUI) then
				con:disconnect()
				return
			end
			task.wait()
			List()
		end)
		f.Drag(BL, 200, 220)
		f.Show(BL)
	elseif a == "KLogs" then
		a = FindChild(CoreUI, b)
		if a then
			wrap(f.Hide, a, true)
		end
		local LL, nl, ol = f.CreateList(b)
		LL.Size = UDim2.new(0, 300, 0, 20)
		LL.BG.Size = UDim2.new(1, 0, 0, 260)
		nl, ol = LL.BG, LL.List
		ol.Position, ol.Size = UDim2.new(), UDim2.new(1, 0, 1, 0)
		ol.Parent = nl
		local List = function(a)
			local b = 0
			for i, v in ol:GetChildren() do
				v:Destroy()
			end
			for i, v in a do
				if v[1] and v[2] then
					b = b + 1
					local t = baseText:Clone()
					t.FontSize, t.Parent, t.Text, t.Position =
						"Size18", ol, f.getTime(v[1]) .. "\t" .. v[2], UDim2.new(0, 5, 0, (b - 1) * 20)
					f.Note(t, v[2]:match(":%s(.+)"))
				end
			end
			ol.CanvasSize = UDim2.new(1, 0, 0, #ol:GetChildren() * 20)
		end
		local S = f.GetSearch(nl).BG
		S.Parent.Position = UDim2.new(0, 0, 1, 2)
		S.Changed:connect(function(p)
			if p == "Text" then
				List(f.Search(Logs, S.Text, function(a, b)
					return a[2]:lower():find(b:lower())
				end))
			end
		end)
		List(Logs)
		local con
		con = logb.Changed:connect(function()
			if not (LL and LL.Parent == CoreUI) then
				con:disconnect()
				return
			end
			if S.Text:gsub("%s", "") == "" or S.Text == "Type here to search" then
				List(Logs)
			end
		end)
		f.Drag(LL, 300, 300)
		f.Resize(nl, 300, 260)
		f.Show(LL)
	elseif a == "KCLogs" then
		a = FindChild(CoreUI, b)
		if a then
			wrap(f.Hide, a, true)
		end
		local LL, nl, ol = f.CreateList(b)
		nl, ol = LL.BG, LL.List
		ol.Parent = nl
		LL.Size = UDim2.new(0, 300, 0, 20)
		ol.Position, ol.Size = UDim2.new(), UDim2.new(1, 0, 1, 0)
		LL.BG.Size = UDim2.new(1, 0, 0, 260)
		local List = function(a)
			local b = 0
			for i, v in ol:GetChildren() do
				v:Destroy()
			end
			for i, v in a do
				if v[1] and v[2] then
					b = b + 1
					local t = baseText:Clone()
					t.FontSize, t.Parent, t.Text, t.Position =
						"Size18", ol, f.getTime(v[1]) .. "\t" .. v[2], UDim2.new(0, 5, 0, (b - 1) * 20)
					f.Note(t, v[2]:match(":%s(.+)"))
				end
			end
			ol.CanvasSize = UDim2.new(1, 0, 0, #ol:GetChildren() * 20)
		end
		local S = f.GetSearch(nl).BG
		S.Parent.Position = UDim2.new(0, 0, 1, 2)
		S.Changed:connect(function(p)
			if p == "Text" then
				List(f.Search(CLogs, S.Text, function(a, b)
					return a[2]:lower():find(b:lower())
				end))
			end
		end)
		List(CLogs)
		local con
		con = clogb.Changed:connect(function()
			if not (LL and LL.Parent == CoreUI) then
				con:disconnect()
				return
			end
			if S.Text:gsub("%s", "") == "" or S.Text == "Type here to search" then
				List(CLogs)
			end
		end)
		f.Drag(LL, 300, 300)
		f.Resize(nl, 300, 260)
		f.Show(LL)
	elseif a == "KCountDown" then
		local instance, duration = unpack(b)
		if instance and tonumber(duration) then
			local old = FindChild(CoreUI, "Timer")
			if old then
				wrap(f.Hide, old, true)
				task.delay(2, s.Run.UnbindFromRenderStep, s.Run, "kCircleProgress")
			end
			local frame = f.template.Timer:Clone()
			frame.Time.Text = duration
			frame.Parent = CoreUI

			local circles = { frame.Circle1, frame.Circle2, frame.Circle3, frame.Circle4 }
			local start = tick()

			local function circleProgress()
				local alpha = math.clamp((tick() - start) / duration, 0, 1)
				for i, circle in circles do
					local circleAlpha = math.clamp((alpha - (i - 1) / 4) * 4, 0, 1)
					if circleAlpha > 0 then
						local index = math.floor(circleAlpha * ((16 * 16) - 1))
						local column = index % 16
						local row = math.floor(index / 16)
						circle.ImageRectOffset = Vector2.new(column * 64, row * 64)
						circle.Visible = true
					else
						circle.Visible = false
					end
				end
			end

			task.spawn(function()
				s.Run:BindToRenderStep("kCircleProgress", 1, circleProgress)
				f.Show(frame)
				while tick() - start < duration and instance and instance.Parent do
					task.wait()
					frame.Time.Text = math.clamp(math.floor(duration - (tick() - start)) + 1, 0, duration)
				end
				f.Hide(frame, true)
				task.delay(2, s.Run.UnbindFromRenderStep, s.Run, "kCircleProgress")
			end)
		end
	elseif a == "KMsg" then
		a = FindChild(CoreUI, "Msg")
		if a then
			wrap(f.Hide, a, true)
		end
		local new = f.template.Msg:Clone()
		local content = b[4]
			and Players:GetUserThumbnailAsync(b[4], Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		new.Parent, new.Owner.Text, new.Title.Text, new.Msg.Text = CoreUI, b[1], b[2], b[3]
		local c1 = b[1] == SN
		if c1 or content then
			new.User.Image = c1 and "rbxassetid://314925538" or content
			new.User.Position =
				UDim2.new(0.5, -80 - new.Owner.TextBounds.X / 2, new.User.Position.Y.Scale, new.User.Position.Y.Offset)
			new.User.Visible = true
		end
		f.Show(new)
		task.wait(math.sqrt(#tostring(b[3])) + 0.5)
		f.Hide(new, true)
	elseif a == "KHint" then
		local existing = FindChild(CoreUI, "Hint")
		if existing then
			wrap(f.Hide, existing, true)
		end
		local new = f.template.Hint:Clone()
		new.Parent, new.BG.Text = CoreUI, b
		f.Show(new)
		task.wait(math.sqrt(#b) + 0.5)
		f.Hide(new, true)
	elseif a == "KNotify" then
		local existing = FindChild(CoreUI, "Notify")
		if existing then
			wrap(f.Hide, existing, true)
		end
		if b then
			local new = f.template.Hint:Clone()
			new.Name, new.Parent, new.BG.Text = "Notify", CoreUI, b
			f.Show(new)
		end
	elseif a == "KError" then
		local existing = FindChild(CoreUI, "Error")
		if existing then
			wrap(f.Hide, existing, true)
		end
		if b then
			local new = f.template.Error:Clone()
			new.Msg.Text, new.Parent = b, CoreUI
			f.Show(new)
			task.wait(math.max(2, math.sqrt(#b) / 2 + 1))
			f.Hide(new, true)
		end
	elseif a == "KWatch" then
		cam.CameraSubject = b or plr.Character
	elseif a == "KBlind" then
		local existing = FindChild(CoreUI, "Blind")
		if existing then
			wrap(f.Hide, existing, true)
		end
		if b then
			local new = f.template.Blind:Clone()
			new.Parent = CoreUI
			f.Show(new)
		end
	elseif a == "KLag" then
		while FindChild(plr, "KLag") do
			for i = 1, 999 do
				print((Vector3.new() - Vector3.new()).Magnitude)
			end
			task.wait()
		end
	elseif a == "KMute" then
		a = "You have been " .. (b and "" or "un") .. "muted."
		Curr.Muted = b
		s.StarterGui:SetCore("ChatBarDisabled", b)
		s.StarterGui:SetCore("ChatMakeSystemMessage", { Text = a, Color = Color3.new(1, 0, 0) })
	elseif a == "KRefresh" then
		local list = { cam.CFrame, cam.Focus, char.HumanoidRootPart.CFrame }
		wrap(function()
			local c
			c = plr.CharacterAdded:connect(function(chr)
				chr = WaitForChild(chr, "HumanoidRootPart")
				repeat
					chr.CFrame = list[3]
					task.wait()
				until (chr.Position - list[3].p).magnitude < 1
				cam.CoordinateFrame, cam.Focus = list[1], list[2]
				c:disconnect()
			end)
		end)
		server:FireServer(f.uID .. "KRefresh")
	elseif a == "KPhase" then
		char.Parent = char.Parent == cam and workspace or cam
		char:MakeJoints()
	elseif a == "KFly" then
		local fly = Curr.Fly
		if fly then
			fly.Value = nil
			fly.Parent.BodyVelocity:Destroy()
			fly.Parent.BodyGyro:Destroy()
			fly:Destroy()
			Curr.Fly = nil
		end
		local hum, root = FindChild(char, "Humanoid"), FindChild(char, "HumanoidRootPart")
		if not (hum and root) then
			return
		end
		if b then
			local maxspd, m, acc, dir, CF = 100, 5, Vector3.new()
			local bg = new("BodyGyro")({ Parent = root, D = 200, P = 5000, cframe = root.CFrame })
			local bv = new("BodyVelocity")({ Parent = root })
			b = new("BoolValue")({ Parent = root, Name = "KFly" })
			Curr.Fly = b
			b.Changed:connect(function(a)
				if b == Curr.Fly then
					a = b.Value
					local f = a and Vector3.new(9e9, 9e9, 9e9) or Vector3.new()
					hum.PlatformStand, bg.MaxTorque, bv.MaxForce = a, f, f
				end
			end)
			b.Value = true
			wrap(function()
				repeat
					if b.Value then
						task.wait()
						dir, CF = hum.MoveDirection, cam.CFrame
						dir = (CF:inverse() * CFrame.new(CF.p + dir)).p
						acc = acc * 0.95
						acc = Vector3.new(
							math.max(-maxspd, math.min(maxspd, acc.x + dir.x * m)),
							math.max(
								-maxspd,
								math.min(
									maxspd,
									not isTyping
											and (f.KeyDown(Enum.KeyCode.Space) and acc.y + m or f.KeyDown(
												Enum.KeyCode.LeftControl
											) and acc.y - m)
										or acc.y
								)
							),
							math.max(-maxspd, math.min(maxspd, acc.z + dir.z * m))
						)
						bg.cframe, bv.velocity = CF, (CF * CFrame.new(acc)).p - CF.p
					else
						task.wait()
					end
				until not b or b ~= Curr.Fly or not hum or not root
			end)
		else
			hum.PlatformStand = false
		end
	elseif a == "KNoclip" then
		local noclip = Curr.Noclip
		if noclip then
			noclip.Value = nil
			noclip:Destroy()
			Curr.Noclip = nil
		end
		local hum, humroot = FindChild(char, "Humanoid"), FindChild(char, "HumanoidRootPart")
		if not (hum and humroot) then
			return
		end
		if b then
			local maxspd, m, acc, zm, CF, dir, zmc, zmc2 =
				5, 0.06, Vector3.new(), (cam.CFrame.p - humroot.Position).magnitude, nil
			zmc = mouse.WheelBackward:connect(function()
				zm = math.min(zm + 2.5, 100)
			end)
			zmc2 = mouse.WheelForward:connect(function()
				zm = math.max(zm - 2.5, 2.5)
			end)
			b = new("BoolValue")({ Parent = char, Name = "KNoclip" })
			Curr.Noclip = b
			b.Changed:connect(function(a)
				if b == Curr.Noclip then
					a = b.Value
					if humroot and a then
						zm = (cam.CFrame.p - humroot.Position).magnitude
					end
					cam.CameraType, hum.WalkSpeed, hum.PlatformStand, humroot.Anchored, humroot.Anchored =
						a and "Fixed" or "Custom", a and 0 or 16, a, a, a
				end
			end)
			b.Value = true
			wrap(function()
				repeat
					if b.Value then
						task.wait()
						CF, dir = cam.CFrame, hum.MoveDirection
						dir = (CF:inverse() * CFrame.new(CF.p + dir)).p
						acc = acc * 0.9
						local m = (m + acc.magnitude * 0.1)
						acc = Vector3.new(
							math.min(maxspd, math.max(-maxspd, acc.x + dir.x * m)),
							not isTyping
									and (f.KeyDown(Enum.KeyCode.Space) and acc.y + m or f.KeyDown(
										Enum.KeyCode.LeftControl
									) and acc.y - m)
								or acc.y,
							math.min(maxspd, math.max(-maxspd, acc.z + dir.z * m))
						)
						if acc.magnitude > 0.1 then
							cam.CFrame = CF * CFrame.new(acc)
							CF = cam.CFrame
							cam.Focus = CF * CFrame.new(0, 0, -zm)
							dir = cam.Focus * CFrame.new(0, 0, -1)
							dir = CFrame.new(cam.Focus.p, Vector3.new(dir.x, cam.Focus.y, dir.z))
								- Vector3.new(0, 1.5, 0)
							humroot.CFrame = dir
						end
					else
						task.wait()
					end
				until not b or b ~= Curr.Noclip or not hum or not humroot
				zmc:disconnect()
				zmc2:disconnect()
			end)
			hum.Died:connect(function()
				plr.CharacterAdded:Wait()
				cam.CameraSubject = WaitForChild(plr.Character, "Humanoid")
			end)
		else
			cam.CameraType, hum.WalkSpeed, hum.PlatformStand, humroot.Anchored, humroot.Anchored =
				"Custom", 16, false, false, false
		end
	elseif a == "KCape" and b then
		if FindChild(b[1], "KCape") then
			b[1].KCape:Destroy()
		end
		if b[4] then
			Cape(b[1], b[2], b[3])
		end
	elseif a == "KGlitch" then
		local existing = FindChild(char, "KGlitch")
		if existing then
			existing:Destroy()
		end
		if b then
			local v, t, c =
				new("IntValue")({ Name = "KGlitch", Parent = char }), FindChild(char, "HumanoidRootPart"), true
			while v and v.Parent == char and t do
				t.CFrame = t.CFrame + Vector3.new(0, 0, (c and 1 or -1) * b)
				c = not c
				task.wait()
			end
		end
	elseif a == "KGlitch2" then
		local existing = FindChild(char, "KGlitch")
		if existing then
			existing:Destroy()
		end
		if b then
			local v, t, c =
				new("IntValue")({ Name = "KGlitch", Parent = char }), FindChild(char, "HumanoidRootPart"), true
			while v and v.Parent == char and t do
				t.CFrame = t.CFrame * CFrame.new(0, 0, (c and 1 or -1) * b)
				c = not c
				task.wait()
			end
		end
	elseif a == "KVibrate" then
		local existing = FindChild(char, "KGlitch")
		if existing then
			existing:Destroy()
		end
		if b then
			local v, t, c, ncf =
				new("IntValue")({ Name = "KGlitch", Parent = char }),
				FindChild(char, "HumanoidRootPart"),
				0,
				CFrame.new()
			while v and v.Parent == char and t do
				if c == 0 then
					ncf = CFrame.new(b, 0, 0)
				elseif c == 1 then
					ncf = CFrame.new(-b, 0, 0)
				elseif c == 2 then
					ncf = CFrame.new(0, 0, b)
				else
					ncf = CFrame.new(0, 0, -b)
				end
				t.CFrame = t.CFrame * ncf
				c = (c + 1) % 4
				task.wait()
			end
		end
	elseif a == "KFOV" then
		cam.FieldOfView = math.min(120, math.max(1, b))
	elseif a == "KVote" then
		a = FindChild(CoreUI, "Vote")
		if a then
			wrap(f.Hide, a, true)
		end
		local v = f.template.Vote:Clone()
		v.Visible = true
		v.Msg.Text = b
		v.Parent = CoreUI
		local c1, c2
		local cleanup = function(c)
			c1:disconnect()
			c2:disconnect()
			c1, c2 = nil, nil
			wrap(f.Hide, v, true)
			server:FireServer(f.uID .. "KVote", c)
		end
		c1 = v.Y.MouseButton1Click:connect(function()
			cleanup(true)
		end)
		c2 = v.N.MouseButton1Click:connect(function()
			cleanup(false)
		end)
		delay(9, function()
			if v.Parent == CoreUI and c1 then
				wrap(f.Hide, v, true)
			end
		end)
		f.Show(v)
	elseif a == "KCredit" then
		ToggleCredit()
	elseif a == "KCam" then
		server:FireServer(f.uID .. "KCam", cam.CFrame)
	elseif a == "KPlaySound" then
		if b then
			b.Volume = if musicMuted then 0 else 1
			b:Play()
		end
	elseif a == "KMuteMusic" then
		musicMuted = not musicMuted
		for _, v in workspace:GetChildren() do
			if v.Name == "KMusic" then
				v.Volume = if musicMuted then 0 else 1
			end
		end
	end
end
server.OnClientEvent:connect(ClientEvent)
server:FireServer("KuID")
if FindChild(server, "KNotify") then
	ClientEvent("KNotify", server.KNotify.Value)
end
plr.CharacterAdded:connect(function(a)
	char, cam = a, workspace.CurrentCamera
	cam.CameraSubject = WaitForChild(char, "Humanoid")
end)
