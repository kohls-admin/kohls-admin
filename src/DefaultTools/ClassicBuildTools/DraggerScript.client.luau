---------------------------------------------------------------------------------------------------------------------------
-- @CloneTrooper1019, 2017 <3
-- DraggerScript.lua
-- This script emulates the behavior of Roblox's classic build tools.
---------------------------------------------------------------------------------------------------------------------------
-- Initial declarations
---------------------------------------------------------------------------------------------------------------------------

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")
local Dragger = Instance.new("Dragger")

local player = Players.LocalPlayer
local tool = script.Parent

local selection = Instance.new("SelectionBox")
selection.Parent = tool
selection.Transparency = 1

local mode = tool.Name
local draggerService = ReplicatedStorage:WaitForChild("DraggerService")
local gateway = draggerService:WaitForChild("DraggerGateway")
local submitUpdate = draggerService:WaitForChild("SubmitUpdate")

----------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Keys
----------------------------------------------------------------------------------------------------------------------------------------------------------------

local keyLocks = {}

local function onInputEnded(input)
	if keyLocks[input.KeyCode.Name] then
		keyLocks[input.KeyCode.Name] = nil
	end
end

local function isKeyDown(key)
	if UserInputService:IsKeyDown(key) and not keyLocks[key] then
		keyLocks[key] = true
		return true
	end
	return false
end

UserInputService.InputEnded:Connect(onInputEnded)

----------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Tool Style
----------------------------------------------------------------------------------------------------------------------------------------------------------------

local style =
{
	_KGameTool =
	{
		Icon = "rbxassetid://1048129653";
		HoverColor = Color3.fromRGB(25,153,255);
		Cursors =
		{
			Idle = "rbxassetid://1000000";
			Hover = "rbxasset://textures/DragCursor.png";
			Grab = "rbxasset://textures/GrabRotateCursor.png";
		};
	};
	_KClone =
	{
		Icon = "rbxasset://textures/Clone.png";
		HoverColor = Color3.fromRGB(25,153,255);
		Cursors =
		{
			Idle = "rbxasset://textures/CloneCursor.png";
			Hover = "rbxassetid://1048136830";
			Grab = "rbxasset://textures/GrabRotateCursor.png";
		}
	};
	_KHammer =
	{
		Icon = "rbxasset://textures/Hammer.png";
		HoverColor = Color3.new(1,0.5,0);
		CanShowWithHover = true;
		Cursors =
		{
			Idle = "rbxasset://textures/HammerCursor.png";
			Hover = "rbxasset://textures/HammerOverCursor.png";
		}
	}
}

if not style[mode] then
	error("Bad mode specification: " .. mode)
end

local function getIcon(iconType)
	return style[mode].Cursors[iconType]
end

tool.TextureId = style[mode].Icon
selection.Color3 = style[mode].HoverColor
if style[mode].CanShowWithHover then
	selection.Transparency = 0
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Dragger
----------------------------------------------------------------------------------------------------------------------------------------------------------------

local mouse
local currentKey
local down = false
local debounce = false

local function onIdle()
	if (not down) and mouse then
		local mousePart = mouse.Target
		if mousePart and not mousePart.Locked then
			selection.Adornee = mousePart
			mouse.Icon = getIcon("Hover")
			return
		end
		selection.Adornee = nil
		mouse.Icon = getIcon("Idle")
	end
end

local function startDraggerAction(mPart)
	if mode == "_KHammer" then
		gateway:InvokeServer("RequestDelete",mPart)
		return
	end

	local pointOnMousePart = mPart.CFrame:toObjectSpace(mouse.Hit).p
	local canDrag,dragKey,mousePart = gateway:InvokeServer("GetKey",mPart,mode == "_KClone")

	if canDrag and mousePart then
		selection.Adornee = mousePart
		selection.Transparency = 0
		currentKey = dragKey
		mouse.Icon = getIcon("Grab")
		Dragger:MouseDown(mousePart,pointOnMousePart,{mousePart})
		down = true

		local lastSubmit = 0
		while down do
			local now = tick()
			Dragger:MouseMove(mouse.UnitRay)

			local mousePart = selection.Adornee
			if mousePart and currentKey then
				if isKeyDown('R') then
					Dragger:AxisRotate('Z')
				elseif isKeyDown('T') then
					Dragger:AxisRotate('X')
				end
				if now - lastSubmit > 0.03 then
					submitUpdate:FireServer(currentKey,mousePart.CFrame)
					lastSubmit = now
				end
			end

			RunService.RenderStepped:Wait()
		end

		selection.Transparency = 1
		gateway:InvokeServer("ClearKey",dragKey)
		currentKey = nil
	end
end

local function onButton1Down()
	if not debounce then
		debounce = true
		local mousePart = selection.Adornee
		if mousePart and not down then
			startDraggerAction(mousePart)
		end
		debounce = false
	end
end

local function onButton1Up()
	if down then
		down = false
		Dragger:MouseUp()
	end
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Connections
----------------------------------------------------------------------------------------------------------------------------------------------------------------

local connections = {}

local function pushConnections(connectionData)
	for event,func in pairs(connectionData) do
		local connection = event:Connect(func)
		table.insert(connections,connection)
	end
end

local function popConnections()
	while #connections > 0 do
		local connection = table.remove(connections)
		connection:Disconnect()
	end
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Tool
----------------------------------------------------------------------------------------------------------------------------------------------------------------

local function onEquipped(newMouse)
	mouse = newMouse
	pushConnections
	{
		[mouse.Button1Down] = onButton1Down;
		[mouse.Button1Up]   = onButton1Up;
		[mouse.Idle]        = onIdle;
	}
end

local function onUnequipped()
	onButton1Up()
	popConnections()
	selection.Adornee = nil
	if mouse then
		mouse.Icon = ""
		mouse = nil
	end
end

tool.Equipped:Connect(onEquipped)
tool.Unequipped:Connect(onUnequipped)

----------------------------------------------------------------------------------------------------------------------------------------------------------------
