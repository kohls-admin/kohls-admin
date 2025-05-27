local BaseClass = require(script.Parent.BaseClass)
local UI = require(script.Parent.Parent)
local UIS = game:GetService("UserInputService")

local Menu = {}
Menu.__index = Menu
setmetatable(Menu, BaseClass)

local LayerTopSize = UI.state(UI.LayerTop, "AbsoluteSize")

function Menu.new(definition)
	local new = UI.makeStatefulDefaults({
		Adornee = false,
		RightAlign = false,
		Visible = false,
	}, definition)

	new._list = UI.new "UIListLayout" {
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = Enum.FillDirection.Vertical,
		VerticalAlignment = Enum.VerticalAlignment.Top,
	}

	local listContentSize = UI.state(new._list, "AbsoluteContentSize")

	new._menu = UI.new "ScrollingFrame" {
		Name = "Menu",
		ZIndex = 100,
		BackgroundTransparency = 1,
		ClipsDescendants = false,
		Size = UDim2.new(1, 0, 1, 0),
		CanvasSize = UI.compute(function(use)
			return UDim2.new(0, 0, 0, use(listContentSize).Y)
		end),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 0,

		new._list,

		[UI.Event.Property] = {
			CanvasPosition = function()
				UI.clearState("hover")
			end,
		},
	}

	new._instance = UI.new "TextButton" {
		Name = "Menu",
		ZIndex = 100,
		Visible = new.Visible,
		Parent = UI.LayerTop,
		AnchorPoint = UI.compute(function(use)
			return if use(new.RightAlign) then Vector2.new(1, 0) else Vector2.zero
		end),
		BackgroundColor3 = UI.Theme.Primary,
		ClipsDescendants = true,

		AutoButtonColor = false,
		Text = "",

		new._menu,
		UI.new "UICorner" {
			CornerRadius = UI.Theme.CornerRadius,
		},
		UI.new "UIStroke" {
			Enabled = UI.Theme.StrokeEnabled,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Transparency = UI.Theme.TransparencyClamped,
			Color = UI.Theme.Border,
		},
	}

	local menuSize = UI.state(new._instance, "AbsoluteSize")

	local function onAdornee(adornee)
		if not adornee then
			return
		end

		local absolutePosition = UI.state(adornee, "AbsolutePosition")
		local absoluteSize = UI.state(adornee, "AbsoluteSize")

		UI.edit(new._instance, {
			Position = UI.compute(function(use)
				local size = use(menuSize)
				local layerSize = use(LayerTopSize)
				local absolutePos = use(absolutePosition)
				local absoluteSize = use(absoluteSize)
				local rightAlign = use(new.RightAlign)
				local padding = use(UI.Theme.Padding).Offset
				local height = use(UI.TopbarInset).Height

				local xPos = absolutePos.X + if rightAlign then absoluteSize.X else 0
				local yPos = absolutePos.Y + absoluteSize.Y + padding + height

				return UDim2.fromOffset(
					if rightAlign
						then math.clamp(xPos, size.X, math.max(size.X, layerSize.X))
						else math.clamp(xPos, 0, math.max(0, layerSize.X - size.X)),
					math.clamp(yPos, 0, math.max(0, layerSize.Y - size.Y))
				)
			end),
		})
	end

	local connection = nil
	local function makeConnection()
		connection = UIS.InputBegan:Connect(function(Input: InputObject, GPE: boolean)
			if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
				return
			end

			local mouse = UIS:GetMouseLocation() :: Vector2
			local boundsTL, boundsBR =
				(UI.peek(new._instance.AbsolutePosition) + Vector2.new(0, UI.peek(UI.TopbarInset).Height)), --calculate bounds, inlcuding top bar inset because roblox is hell
				(UI.peek(new._instance.AbsolutePosition) + UI.peek(new._instance.AbsoluteSize) + Vector2.new(
					0,
					UI.peek(UI.TopbarInset).Height
				))

			if
				(mouse.X < boundsTL.X and mouse.Y < boundsTL.Y) --box bounds check, ty random dev forum post
				and (mouse.X > boundsBR.X and mouse.Y > boundsBR.Y)
			then
				UI.deactivateState(new.Visible, "floating")
			end
		end)
	end

	new._compute = UI.compute(function(use)
		if use(new.Visible) then
			makeConnection()
		else
			if connection :: RBXScriptSignal then
				connection:Disconnect()
			end
		end
	end)

	new.Adornee:hook(onAdornee)
	onAdornee(UI.peek(new.Adornee))

	return setmetatable(new, Menu)
end

return Menu
