local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local Util = require(script.Parent.Parent.Util)

local LocalPlayer = game.Players.LocalPlayer

if RunService:IsServer() then
	return false
end

local ORIGINAL_PRODUCT_ID = 110019084552349
local SALE_PRODUCT_ID = 115444443724463
local SALE_PERIOD = 10 * 60

local vip = Instance.new("Frame")
vip.Name = "VIP"
vip.AnchorPoint = Vector2.new(0.5, 0.5)
vip.BackgroundTransparency = 1
vip.Position = UDim2.fromScale(0.5, 0.5)
vip.Size = UDim2.fromOffset(420, 440)
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
uIListLayout1.Padding = UDim.new(0, 16)
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

local previewLabel = Instance.new("TextLabel")
previewLabel.Name = "Preview"
previewLabel.AutomaticSize = Enum.AutomaticSize.XY
previewLabel.BackgroundTransparency = 1
previewLabel.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium, Enum.FontStyle.Normal)
previewLabel.LayoutOrder = 2
previewLabel.RichText = true
previewLabel.Size = UDim2.new(0.85, 0, 0, 20)
previewLabel.TextColor3 = Color3.fromRGB(220, 220, 230)
previewLabel.TextSize = 15
previewLabel.TextWrapped = true
previewLabel.TextXAlignment = Enum.TextXAlignment.Center
previewLabel.Parent = frame

local function updatePreviewPrefix(rawPrefix: string?)
	local p = Util.String.escapeRichText(rawPrefix or ";")
	previewLabel.Text =
		`<font transparency='0.25'>Includes <b>{p}headless</b>, <b>{p}korblox</b>, <b>{p}fire</b>, <b>{p}cape</b>, <b>{p}goldify</b> &amp; more!</font>`
end
updatePreviewPrefix(";")

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
title.RichText = true
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

local favorite = Instance.new("ImageButton")
favorite.Name = "Favorite"
favorite.BackgroundTransparency = 1
favorite.Image = "rbxasset://textures/ui/InspectMenu/ico_favorite@2x.png"
favorite.ImageColor3 = Color3.new(1, 0.8, 0)
favorite.LayoutOrder = 1
favorite.Size = UDim2.fromOffset(36, 36)
favorite.Parent = buyFrame

local originalPrice = Instance.new("Frame")
originalPrice.Name = "OriginalPrice"
originalPrice.AutomaticSize = Enum.AutomaticSize.X
originalPrice.BackgroundTransparency = 1
originalPrice.LayoutOrder = 2
originalPrice.Size = UDim2.fromOffset(0, 32)
originalPrice.Visible = false

local origList = Instance.new("UIListLayout")
origList.FillDirection = Enum.FillDirection.Horizontal
origList.Padding = UDim.new(0, 4)
origList.SortOrder = Enum.SortOrder.LayoutOrder
origList.VerticalAlignment = Enum.VerticalAlignment.Center
origList.Parent = originalPrice

local robuxIcon1 = Instance.new("ImageLabel")
robuxIcon1.Name = "RobuxIcon"
robuxIcon1.BackgroundTransparency = 1
robuxIcon1.Image = "rbxasset://textures/ui/common/robux@2x.png"
robuxIcon1.ImageColor3 = Color3.fromRGB(184, 184, 184)
robuxIcon1.LayoutOrder = 1
robuxIcon1.Size = UDim2.fromOffset(24, 24)
robuxIcon1.ZIndex = 2
robuxIcon1.Parent = originalPrice

local originalPriceLabel = Instance.new("TextLabel")
originalPriceLabel.Name = "Label"
originalPriceLabel.AutomaticSize = Enum.AutomaticSize.X
originalPriceLabel.BackgroundTransparency = 1
originalPriceLabel.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium, Enum.FontStyle.Normal)
originalPriceLabel.LayoutOrder = 2
originalPriceLabel.Size = UDim2.fromOffset(0, 32)
originalPriceLabel.Text = "799"
originalPriceLabel.TextColor3 = Color3.fromRGB(184, 184, 184)
originalPriceLabel.TextSize = 24

local line = Instance.new("Frame")
line.Name = "Line"
line.AnchorPoint = Vector2.new(0.5, 0.5)
line.BackgroundColor3 = Color3.fromRGB(184, 184, 184)
line.BorderColor3 = Color3.new()
line.BorderSizePixel = 0
line.Position = UDim2.fromScale(0.5, 0.5)
line.Size = UDim2.new(1, 4, 0, 2)
line.ZIndex = 2
line.Parent = originalPriceLabel

originalPriceLabel.Parent = originalPrice
originalPrice.Parent = buyFrame

local buy = Instance.new("TextButton")
buy.Name = "Buy"
buy.AutomaticSize = Enum.AutomaticSize.X
buy.BackgroundColor3 = Color3.fromRGB(51, 95, 255)
buy.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json")
buy.LayoutOrder = 3
buy.Size = UDim2.fromOffset(0, 56)
buy.Text = ""
buy.TextColor3 = Color3.new(1, 1, 1)
buy.TextSize = 12
buy.TextTransparency = 1

local uICorner2 = Instance.new("UICorner")
uICorner2.Name = "UICorner"
uICorner2.CornerRadius = UDim.new(0, 12)
uICorner2.Parent = buy

local buyList = Instance.new("UIListLayout")
buyList.FillDirection = Enum.FillDirection.Horizontal
buyList.Padding = UDim.new(0, 8)
buyList.SortOrder = Enum.SortOrder.LayoutOrder
buyList.VerticalAlignment = Enum.VerticalAlignment.Center
buyList.Parent = buy

local robuxIcon = Instance.new("ImageLabel")
robuxIcon.Name = "RobuxIcon"
robuxIcon.BackgroundTransparency = 1
robuxIcon.Image = "rbxasset://textures/ui/common/robux@2x.png"
robuxIcon.LayoutOrder = 1
robuxIcon.Size = UDim2.fromOffset(28, 28)
robuxIcon.ZIndex = 2
robuxIcon.Parent = buy

local uIPadding = Instance.new("UIPadding")
uIPadding.Name = "UIPadding"
uIPadding.PaddingBottom = UDim.new(0, 12)
uIPadding.PaddingLeft = UDim.new(0, 16)
uIPadding.PaddingRight = UDim.new(0, 16)
uIPadding.PaddingTop = UDim.new(0, 12)
uIPadding.Parent = buy

local price = Instance.new("TextLabel")
price.Name = "Price"
price.AutomaticSize = Enum.AutomaticSize.X
price.BackgroundTransparency = 1
price.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
price.LayoutOrder = 2
price.Size = UDim2.fromOffset(0, 32)
price.Text = "799"
price.TextColor3 = Color3.new(1, 1, 1)
price.TextSize = 24
price.Parent = buy

buy.Parent = buyFrame

local uIListLayout5 = Instance.new("UIListLayout")
uIListLayout5.Name = "UIListLayout"
uIListLayout5.FillDirection = Enum.FillDirection.Horizontal
uIListLayout5.HorizontalAlignment = Enum.HorizontalAlignment.Center
uIListLayout5.Padding = UDim.new(0, 14)
uIListLayout5.SortOrder = Enum.SortOrder.LayoutOrder
uIListLayout5.VerticalAlignment = Enum.VerticalAlignment.Center
uIListLayout5.Parent = buyFrame

local view = Instance.new("TextButton")
view.Name = "View"
view.AnchorPoint = Vector2.new(0, 0.5)
view.AutomaticSize = Enum.AutomaticSize.X
view.BackgroundColor3 = Color3.fromRGB(64, 64, 64)
view.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
view.LayoutOrder = 4
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
uIPadding1.PaddingBottom = UDim.new(0, 12)
uIPadding1.PaddingLeft = UDim.new(0, 16)
uIPadding1.PaddingRight = UDim.new(0, 16)
uIPadding1.PaddingTop = UDim.new(0, 12)
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

local productId: number = ORIGINAL_PRODUCT_ID

local function promptBulkPurchase(id: number | string)
	local numId = tonumber(id)
	if numId then
		Util.Remote.PromptBulkPurchase:Fire(numId)
	end
end

local function buyActiveVIP()
	promptBulkPurchase(productId)
end

local function promptPurchaseVIP(directPurchase: boolean?)
	if directPurchase or vip.Visible then
		buyActiveVIP()
	else
		vip.Visible = true
	end
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

local function updateLabelPrice(targetLabel: TextLabel, id: number)
	local ok, result = Util.Retry(function()
		return MarketplaceService:GetProductInfoAsync(id, Enum.InfoType.Asset).PriceInRobux
	end)
	if ok and result then
		targetLabel.Text = tostring(result)
	end
end

local function setSalePrice(onSale: boolean?)
	productId = if onSale then SALE_PRODUCT_ID else ORIGINAL_PRODUCT_ID
	favorite.Visible = true
	originalPrice.Visible = if onSale then true else false
	title.Visible = true
	price.Text = if onSale then "479" else "799"
	task.spawn(updateLabelPrice, price, productId)
	if shared._K_INTERFACE and shared._K_INTERFACE.VIP and shared._K_INTERFACE.VIP.saleStateChanged then
		shared._K_INTERFACE.VIP.saleStateChanged:Fire(onSale == true, productId)
	end
end

task.spawn(updateLabelPrice, originalPriceLabel, ORIGINAL_PRODUCT_ID)
task.spawn(function()
	local initialJoin = LocalPlayer:GetAttribute("_KInitialJoin")
	while not initialJoin do
		task.wait()
		initialJoin = LocalPlayer:GetAttribute("_KInitialJoin")
	end

	local elapsed = workspace:GetServerTimeNow() - initialJoin

	if elapsed < SALE_PERIOD then
		setSalePrice(false)
		while elapsed < SALE_PERIOD do
			task.wait(0.5)
			elapsed = workspace:GetServerTimeNow() - initialJoin
			local duration = math.max(0, SALE_PERIOD - elapsed)
			title.Text = `<font color="#0f0" transparency="0">40% OFF</font> in {Util.Time.clock(duration)}`
		end
	end

	title.Text = `<font color="#0f0" transparency="0">40% OFF</font>`
	setSalePrice(true)
	if shared._K_INTERFACE and shared._K_INTERFACE.client and shared._K_INTERFACE.client.VIPNotification then
		shared._K_INTERFACE.client.VIPNotification()
	end
end)

local _ = buy.Activated:Connect(buyActiveVIP)
local _ = favorite.Activated:Connect(function()
	local _ = pcall(function()
		shared._K_INTERFACE.Service.AvatarEditor:PromptSetFavorite(productId, 1, true)
	end)
end)
local _ = view.Activated:Connect(function()
	vip.Visible = false
	local client = shared._K_INTERFACE and shared._K_INTERFACE.client
	if client then
		if client.commandsWindowVisible then
			client.commandsWindowVisible(true)
		end
		local commands = client.dashboard and client.dashboard.Commands
		if commands and commands._input and commands._input._input then
			commands._input._input.Text = "role=vip"
		end
	end
	local cmds = shared._K_INTERFACE and shared._K_INTERFACE.Registry and shared._K_INTERFACE.Registry.commands.cmds
	local cmdsWindow = cmds and cmds.env and cmds.env.window
	if cmdsWindow and cmdsWindow.bringToFront then
		cmdsWindow:bringToFront()
	end
end)

local _ = close.Activated:Connect(function()
	vip.Visible = false
end)

vip:GetPropertyChangedSignal("Visible"):Connect(function()
	if vip.Visible and shared._K_INTERFACE and shared._K_INTERFACE.getCommandPrefix then
		updatePreviewPrefix(shared._K_INTERFACE.getCommandPrefix())
	end
end)

local _ = MarketplaceService.PromptBulkPurchaseFinished:Connect(function(player, status, results)
	if player ~= LocalPlayer or type(results) ~= "table" or type(results.Items) ~= "table" or not results.Items[1] then
		return
	end
	local _K = shared._K_INTERFACE
	for _, item in results.Items do
		local id = type(item) == "table" and tonumber(item.Id or item.id)
		if
			id
			and _K
			and (id == ORIGINAL_PRODUCT_ID or id == SALE_PRODUCT_ID or (_K.VIP and _K.VIP.allowedBulkPurchaseIds[id]))
		then
			_K.Remote.VIPCheck:Fire(id)
		end
	end
	local itemId = tonumber(results.Items[1].Id or results.Items[1].id)
	if itemId ~= ORIGINAL_PRODUCT_ID and itemId ~= SALE_PRODUCT_ID then
		return
	end
	if status == Enum.MarketplaceBulkPurchasePromptStatus.Completed then
		local function noop() end
		_K.client.VIPNotification = noop
		vip.Visible = false
		task.wait(4)
		local _ = pcall(function()
			_K.Service.AvatarEditor:PromptSetFavorite(17873329124, 1, true)
		end)
	end
end)

-- automatic scaling for small screens
local scale = Instance.new("UIScale")
scale.Parent = vip
vip:GetPropertyChangedSignal("Parent"):Once(function()
	local parent = vip.Parent
	local function updateScale()
		scale.Scale = math.min(1, parent.AbsoluteSize.Y / 440)
	end
	updateScale()
	parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateScale)
end)

return vip
