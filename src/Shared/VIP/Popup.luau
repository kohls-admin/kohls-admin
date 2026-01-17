local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local LocalPlayer = game.Players.LocalPlayer

if RunService:IsServer() then
	return false
end

local promptBulkPurchaseEvent = script.Parent:WaitForChild("PromptBulkPurchaseEvent")

local vip = Instance.new("Frame")
vip.Name = "VIP"
vip.AnchorPoint = Vector2.new(0.5, 0.5)
vip.BackgroundTransparency = 1
vip.Position = UDim2.fromScale(0.5, 0.5)
vip.Size = UDim2.fromOffset(420, 420)
vip.Visible = false
vip.ZIndex = 9e8

local imageLabel = Instance.new("ImageLabel")
imageLabel.Name = "ImageLabel"
imageLabel.BackgroundColor3 = Color3.fromRGB(18, 18, 21)
imageLabel.BackgroundTransparency = 0
imageLabel.Image = "rbxassetid://104331312960285"
imageLabel.Size = UDim2.fromScale(1, 1)

local uICorner = Instance.new("UICorner")
uICorner.Name = "UICorner"
uICorner.CornerRadius = UDim.new(0, 12)
uICorner.Parent = imageLabel

imageLabel.Parent = vip

local frame = Instance.new("Frame")
frame.Name = "Frame"
frame.BackgroundTransparency = 1
frame.Size = UDim2.fromScale(1, 1)

local uIListLayout1 = Instance.new("UIListLayout")
uIListLayout1.Name = "UIListLayout"
uIListLayout1.HorizontalAlignment = Enum.HorizontalAlignment.Center
uIListLayout1.Padding = UDim.new(0, 24)
uIListLayout1.SortOrder = Enum.SortOrder.LayoutOrder
uIListLayout1.Parent = frame

local unlock = Instance.new("Frame")
unlock.Name = "Unlock"
unlock.AutomaticSize = Enum.AutomaticSize.XY
unlock.BackgroundTransparency = 1
unlock.LayoutOrder = 1

local label = Instance.new("TextLabel")
label.Name = "Label"
label.AnchorPoint = Vector2.new(0.5, 0)
label.AutomaticSize = Enum.AutomaticSize.XY
label.BackgroundTransparency = 1
label.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
label.LayoutOrder = 1
label.Position = UDim2.new(0.5, 8, 0, 64)
label.RichText = true
label.Size = UDim2.new(0.5, 0, 0, 48)
label.Text = "Unlock exclusive commands <i>forever</i>"
label.TextColor3 = Color3.new(1, 1, 1)
label.TextSize = 24
label.TextWrapped = true
label.TextXAlignment = Enum.TextXAlignment.Left
label.Parent = unlock

local emoji = Instance.new("TextLabel")
emoji.Name = "Emoji"
emoji.AnchorPoint = Vector2.new(1, 0)
emoji.AutomaticSize = Enum.AutomaticSize.XY
emoji.BackgroundTransparency = 1
emoji.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
emoji.Position = UDim2.new(0.25, 0, 0, 64)
emoji.Text = "✨"
emoji.TextColor3 = Color3.new(1, 1, 1)
emoji.TextSize = 48
emoji.TextWrapped = true
emoji.Parent = unlock

local uIListLayout = Instance.new("UIListLayout")
uIListLayout.Name = "UIListLayout"
uIListLayout.FillDirection = Enum.FillDirection.Horizontal
uIListLayout.Padding = UDim.new(0, 8)
uIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uIListLayout.Parent = unlock

unlock.Parent = frame

local games = Instance.new("Frame")
games.Name = "Games"
games.AutomaticSize = Enum.AutomaticSize.XY
games.BackgroundTransparency = 1
games.LayoutOrder = 2

local label1 = Instance.new("TextLabel")
label1.Name = "Label"
label1.AnchorPoint = Vector2.new(0.5, 0)
label1.AutomaticSize = Enum.AutomaticSize.XY
label1.BackgroundTransparency = 1
label1.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
label1.LayoutOrder = 1
label1.Position = UDim2.new(0.5, 8, 0, 64)
label1.RichText = true
label1.Size = UDim2.new(0.5, 0, 0, 48)
label1.Text = "Use in over <b>10,000</b>\nRoblox experiences"
label1.TextColor3 = Color3.new(1, 1, 1)
label1.TextSize = 24
label1.TextWrapped = true
label1.TextXAlignment = Enum.TextXAlignment.Left
label1.Parent = games

local uIListLayout2 = Instance.new("UIListLayout")
uIListLayout2.Name = "UIListLayout"
uIListLayout2.FillDirection = Enum.FillDirection.Horizontal
uIListLayout2.Padding = UDim.new(0, 8)
uIListLayout2.SortOrder = Enum.SortOrder.LayoutOrder
uIListLayout2.Parent = games

local imageLabel1 = Instance.new("ImageLabel")
imageLabel1.Name = "ImageLabel"
imageLabel1.BackgroundTransparency = 1
imageLabel1.Image = "rbxasset://textures/loading/robloxTilt.png"
imageLabel1.Size = UDim2.fromOffset(48, 48)
imageLabel1.Parent = games

games.Parent = frame

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AutomaticSize = Enum.AutomaticSize.XY
panel.BackgroundTransparency = 1
panel.LayoutOrder = 5

local label2 = Instance.new("TextLabel")
label2.Name = "Label"
label2.AnchorPoint = Vector2.new(0.5, 0)
label2.AutomaticSize = Enum.AutomaticSize.XY
label2.BackgroundTransparency = 1
label2.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
label2.LayoutOrder = 1
label2.Position = UDim2.new(0.5, 8, 0, 64)
label2.RichText = true
label2.Size = UDim2.new(0.5, 0, 0, 32)
label2.Text = "30% goes to supporting free and open-source projects"
label2.TextColor3 = Color3.fromRGB(184, 184, 184)
label2.TextSize = 16
label2.TextWrapped = true
label2.TextXAlignment = Enum.TextXAlignment.Left
label2.Parent = panel

local emoji1 = Instance.new("TextLabel")
emoji1.Name = "Emoji"
emoji1.AnchorPoint = Vector2.new(1, 0)
emoji1.AutomaticSize = Enum.AutomaticSize.XY
emoji1.BackgroundTransparency = 1
emoji1.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
emoji1.Position = UDim2.new(0.25, 0, 0, 64)
emoji1.Text = "🌎"
emoji1.TextColor3 = Color3.new(1, 1, 1)
emoji1.TextSize = 24
emoji1.TextWrapped = true
emoji1.Parent = panel

local uIListLayout3 = Instance.new("UIListLayout")
uIListLayout3.Name = "UIListLayout"
uIListLayout3.FillDirection = Enum.FillDirection.Horizontal
uIListLayout3.Padding = UDim.new(0, 8)
uIListLayout3.SortOrder = Enum.SortOrder.LayoutOrder
uIListLayout3.VerticalAlignment = Enum.VerticalAlignment.Center
uIListLayout3.Parent = panel

panel.Parent = frame

local creator = Instance.new("Frame")
creator.Name = "Creator"
creator.AutomaticSize = Enum.AutomaticSize.XY
creator.BackgroundTransparency = 1
creator.LayoutOrder = 4

local label3 = Instance.new("TextLabel")
label3.Name = "Label"
label3.AnchorPoint = Vector2.new(0.5, 0)
label3.AutomaticSize = Enum.AutomaticSize.XY
label3.BackgroundTransparency = 1
label3.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
label3.LayoutOrder = 1
label3.Position = UDim2.new(0.5, 8, 0, 64)
label3.RichText = true
label3.Size = UDim2.new(0.5, 0, 0, 32)
label3.Text = "40% of your purchase goes to the creator of this experience"
label3.TextColor3 = Color3.fromRGB(184, 184, 184)
label3.TextSize = 16
label3.TextWrapped = true
label3.TextXAlignment = Enum.TextXAlignment.Left
label3.Parent = creator

local emoji2 = Instance.new("TextLabel")
emoji2.Name = "Emoji"
emoji2.AnchorPoint = Vector2.new(1, 0)
emoji2.AutomaticSize = Enum.AutomaticSize.XY
emoji2.BackgroundTransparency = 1
emoji2.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
emoji2.Position = UDim2.new(0.25, 0, 0, 64)
emoji2.Text = "❤️"
emoji2.TextColor3 = Color3.new(1, 1, 1)
emoji2.TextSize = 24
emoji2.TextWrapped = true
emoji2.Parent = creator

local uIListLayout4 = Instance.new("UIListLayout")
uIListLayout4.Name = "UIListLayout"
uIListLayout4.FillDirection = Enum.FillDirection.Horizontal
uIListLayout4.Padding = UDim.new(0, 8)
uIListLayout4.SortOrder = Enum.SortOrder.LayoutOrder
uIListLayout4.VerticalAlignment = Enum.VerticalAlignment.Center
uIListLayout4.Parent = creator

creator.Parent = frame

local titleFrame = Instance.new("Frame")
titleFrame.Name = "Title"
titleFrame.BackgroundTransparency = 1
titleFrame.Size = UDim2.new(1, 0, 0, 40)

local title = Instance.new("TextLabel")
title.Name = "Header"
title.BackgroundTransparency = 1
title.FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
title.Size = UDim2.fromScale(1, 1)
title.Text = ""
title.TextColor3 = Color3.new(1, 1, 1)
title.TextSize = 24
title.TextTransparency = 0.25
title.TextWrapped = true
title.Visible = true
title.Parent = titleFrame

local titleBG = Instance.new("Frame")
titleBG.Name = "BG"
titleBG.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
titleBG.BackgroundTransparency = 0.5
titleBG.Size = UDim2.fromScale(1, 2)
titleBG.ZIndex = 0

local uICorner1 = Instance.new("UICorner")
uICorner1.Name = "UICorner"
uICorner1.CornerRadius = UDim.new(0, 12)
uICorner1.Parent = titleBG

local uIGradient = Instance.new("UIGradient")
uIGradient.Name = "UIGradient"
uIGradient.Rotation = 90
uIGradient.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(1, 1),
})
uIGradient.Parent = titleBG

titleBG.Parent = titleFrame

titleFrame.Parent = frame

local buyFrame = Instance.new("Frame")
buyFrame.Name = "BuyFrame"
buyFrame.BackgroundTransparency = 1
buyFrame.LayoutOrder = 3
buyFrame.Size = UDim2.new(1, 0, 0, 64)

local favorite = Instance.new("TextButton", buyFrame)
favorite.Name = "Favorite"
favorite.BackgroundTransparency = 1
favorite.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json")
favorite.Size = UDim2.fromOffset(84, 48)
favorite.Text = "⭐"
favorite.TextColor3 = Color3.new()
favorite.TextSize = 48
favorite.TextXAlignment = Enum.TextXAlignment.Right

local buy = Instance.new("TextButton")
buy.Name = "Buy"
buy.BackgroundColor3 = Color3.fromRGB(51, 95, 255)
buy.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json")
buy.LayoutOrder = 3
buy.Size = UDim2.fromOffset(114, 64)
buy.Text = "399"
buy.TextColor3 = Color3.new(1, 1, 1)
buy.TextSize = 12
buy.TextTransparency = 1

local uICorner2 = Instance.new("UICorner")
uICorner2.Name = "UICorner"
uICorner2.CornerRadius = UDim.new(0, 12)
uICorner2.Parent = buy

local robuxIcon = Instance.new("ImageLabel")
robuxIcon.Name = "RobuxIcon"
robuxIcon.BackgroundTransparency = 1
robuxIcon.Image = "rbxasset://textures/ui/common/robux@2x.png"
robuxIcon.Size = UDim2.fromScale(1, 1)
robuxIcon.SizeConstraint = Enum.SizeConstraint.RelativeYY
robuxIcon.ZIndex = 2
robuxIcon.Parent = buy

local uIPadding = Instance.new("UIPadding")
uIPadding.Name = "UIPadding"
uIPadding.PaddingBottom = UDim.new(0, 16)
uIPadding.PaddingLeft = UDim.new(0, 16)
uIPadding.PaddingRight = UDim.new(0, 16)
uIPadding.PaddingTop = UDim.new(0, 16)
uIPadding.Parent = buy

local price = Instance.new("TextLabel")
price.Name = "Price"
price.BackgroundTransparency = 1
price.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
price.Position = UDim2.fromOffset(40, 0)
price.Size = UDim2.fromOffset(42, 32)
price.Text = "399"
price.TextColor3 = Color3.new(1, 1, 1)
price.TextSize = 24
price.Parent = buy

buy.Parent = buyFrame

local originalPrice = Instance.new("Frame")
originalPrice.Name = "OriginalPrice"
originalPrice.BackgroundTransparency = 1
originalPrice.Size = UDim2.fromOffset(84, 32)
originalPrice.Visible = false

local originalPriceLabel = Instance.new("TextLabel")
originalPriceLabel.Name = "Label"
originalPriceLabel.BackgroundTransparency = 1
originalPriceLabel.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium, Enum.FontStyle.Normal)
originalPriceLabel.Position = UDim2.fromOffset(40, 0)
originalPriceLabel.Size = UDim2.fromOffset(42, 32)
originalPriceLabel.Text = "499"
originalPriceLabel.TextColor3 = Color3.fromRGB(184, 184, 184)
originalPriceLabel.TextSize = 24

local line = Instance.new("Frame")
line.Name = "Line"
line.AnchorPoint = Vector2.new(0.5, 0.5)
line.BackgroundColor3 = Color3.fromRGB(184, 184, 184)
line.BorderColor3 = Color3.new()
line.BorderSizePixel = 0
line.Position = UDim2.fromScale(0.5, 0.5)
line.Size = UDim2.fromOffset(48, 2)
line.ZIndex = 2
line.Parent = originalPriceLabel

originalPriceLabel.Parent = originalPrice

local robuxIcon1 = Instance.new("ImageLabel")
robuxIcon1.Name = "RobuxIcon"
robuxIcon1.BackgroundTransparency = 1
robuxIcon1.Image = "rbxasset://textures/ui/common/robux@2x.png"
robuxIcon1.ImageColor3 = Color3.fromRGB(184, 184, 184)
robuxIcon1.Size = UDim2.fromScale(1, 1)
robuxIcon1.SizeConstraint = Enum.SizeConstraint.RelativeYY
robuxIcon1.ZIndex = 2
robuxIcon1.Parent = originalPrice

originalPrice.Parent = buyFrame

local uIListLayout5 = Instance.new("UIListLayout")
uIListLayout5.Name = "UIListLayout"
uIListLayout5.FillDirection = Enum.FillDirection.Horizontal
uIListLayout5.HorizontalAlignment = Enum.HorizontalAlignment.Center
uIListLayout5.Padding = UDim.new(0, 16)
uIListLayout5.SortOrder = Enum.SortOrder.LayoutOrder
uIListLayout5.VerticalAlignment = Enum.VerticalAlignment.Center
uIListLayout5.Parent = buyFrame

local view = Instance.new("TextButton")
view.Name = "View"
view.AnchorPoint = Vector2.new(0, 0.5)
view.AutomaticSize = Enum.AutomaticSize.X
view.BackgroundColor3 = Color3.fromRGB(64, 64, 64)
view.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
view.LayoutOrder = 3
view.Position = UDim2.new(1, 32, 0.5, 0)
view.Size = UDim2.fromOffset(0, 48)
view.Text = "View"
view.TextColor3 = Color3.new(1, 1, 1)
view.TextSize = 24

local uiCorner3 = Instance.new("UICorner")
uiCorner3.Name = "UICorner"
uiCorner3.CornerRadius = UDim.new(0, 12)
uiCorner3.Parent = view

local uIPadding1 = Instance.new("UIPadding")
uIPadding1.Name = "UIPadding"
uIPadding1.PaddingBottom = UDim.new(0, 16)
uIPadding1.PaddingLeft = UDim.new(0, 16)
uIPadding1.PaddingRight = UDim.new(0, 16)
uIPadding1.PaddingTop = UDim.new(0, 16)
uIPadding1.Parent = view

view.Parent = buyFrame

buyFrame.Parent = frame

frame.Parent = vip

local close = Instance.new("ImageButton")
close.Name = "Close"
close.AnchorPoint = Vector2.new(1, 0)
close.BackgroundTransparency = 1
close.Image = "rbxasset://textures/ui/ScreenshotHud/Close.png"
close.Position = UDim2.new(1, -4, 0, 4)
close.Size = UDim2.fromOffset(32, 32)
close.Parent = vip

local originalProductId = "110019084552349"
local saleProductId = "115444443724463"

local productId = originalProductId

local function promptBulkPurchase(id: number | string)
	promptBulkPurchaseEvent:FireServer(tonumber(id))
end

local function promptPurchaseVIP()
	promptBulkPurchase(productId)
end

task.spawn(function()
	while not shared._K_INTERFACE do
		task.wait()
	end
	shared._K_INTERFACE.PromptBulkPurchase = promptBulkPurchase
	shared._K_INTERFACE.PromptPurchaseVIP = promptPurchaseVIP

	shared._K_INTERFACE.UI.new "Tooltip" {
		Parent = favorite,
		Text = "Add to Favorites",
	}
end)

local function updatePrice(label: TextLabel, id: number)
	local ok, result = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, Enum.InfoType.Asset)
	if ok then
		label.Text = result.PriceInRobux
	end
end

task.spawn(updatePrice, originalPriceLabel, productId)
task.spawn(function()
	local initialJoin = LocalPlayer:GetAttribute("_KInitialJoin")
	while not initialJoin do
		task.wait()
		initialJoin = LocalPlayer:GetAttribute("_KInitialJoin")
	end

	local duration = workspace:GetServerTimeNow() - initialJoin
	if duration > 15 * 60 then
		task.spawn(updatePrice, buy.Price, productId)
		return
	end

	productId = saleProductId
	favorite.Visible = false
	originalPrice.Visible = true
	title.Visible = true
	buy.Price.Text = "479"
	task.spawn(updatePrice, buy.Price, productId)

	repeat
		task.wait(0.5)
		duration = (15 * 60) - (workspace:GetServerTimeNow() - initialJoin)
		title.Text = `40% OFF for {string.format("%02d:%02d", duration // 60, duration % 60)}`
	until duration < 0

	productId = originalProductId
	favorite.Visible = true
	originalPrice.Visible = false
	title.Visible = false
	buy.Price.Text = "799"
	task.spawn(updatePrice, buy.Price, productId)
end)

buy.Activated:Connect(promptPurchaseVIP)
favorite.Activated:Connect(function()
	pcall(function()
		shared._K_INTERFACE.Service.AvatarEditor:PromptSetFavorite(productId, 1, true)
	end)
end)
view.Activated:Connect(function()
	shared._K_INTERFACE.client.commandsWindowVisible(true)
	shared._K_INTERFACE.client.dashboard.Commands._input._input.Text = "role=vip"
	vip.ZIndex = shared._K_INTERFACE.Registry.commands.cmds.env.window._instance.ZIndex - 1
end)

local count = 0
local thread

close.Activated:Connect(function()
	count += 1
	vip.Visible = false
	if thread and coroutine.status(thread) == "suspended" then
		task.cancel(thread)
	end
	thread = task.delay(300, shared._K_INTERFACE.client.VIPNotification)
end)

MarketplaceService.PromptBulkPurchaseFinished:Connect(function(player, status, results)
	if player ~= LocalPlayer or (results.Items[1].id ~= productId and results.Items[1].id ~= saleProductId) then
		return
	end
	shared._K_INTERFACE.Remote.VIPCheck:FireServer(tonumber(results.Items[1].id))
	if status == Enum.MarketplaceBulkPurchasePromptStatus.Completed then
		shared._K_INTERFACE.client.VIPNotification = function() end
		vip.Visible = false
		task.wait(4)
		pcall(function()
			game:GetService("AvatarEditorService"):PromptSetFavorite(17873329124, 1, true)
		end)
	end
end)

-- automatic scaling for small screens
local scale = Instance.new("UIScale", vip)
vip:GetPropertyChangedSignal("Parent"):Once(function()
	local parent = vip.Parent
	local function updateScale()
		scale.Scale = math.min(1, parent.AbsoluteSize.Y / 420)
	end
	updateScale()
	parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateScale)
end)

return vip
