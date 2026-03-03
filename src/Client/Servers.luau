local UI = require(script.Parent:WaitForChild("UI"))

local Servers = {}
Servers.__index = Servers

function Servers.new(_K)
	local servers = _K.Data.servers

	local placeNames = {}
	local function getPlaceName(placeId: number)
		if placeNames[placeId] then
			return placeNames[placeId]
		end

		local success, info = pcall(function()
			return _K.Service.Marketplace:GetProductInfo(placeId)
		end)

		local name = if success then info.Name else "Unknown"
		placeNames[placeId] = name

		return name
	end

	_K.Remote.Servers:Connect(function(jobId: string?, data: any?)
		if not jobId then -- bulk update
			if type(data) ~= "table" then
				return
			end
			table.clear(servers)
			for k, v in data do
				servers[k] = v
			end
		else -- single update
			servers[jobId] = data
		end
		_K.client.servers(servers)
	end)

	local merge = _K.Util.Table.merge

	local buttonSize = UI.compute(function()
		return UDim2.new(0.2, 0, 1, -UI.Theme.Padding().Offset)
	end)

	local function icon(properties)
		return UI.new "ImageLabel"(merge({
			BackgroundTransparency = 1,
			Size = UDim2.new(0.5, 0, 0.5, 0),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			ImageColor3 = UI.Theme.PrimaryText,
			ScaleType = Enum.ScaleType.Fit,
		}, properties))
	end

	local function label(properties)
		return UI.new "TextLabel"(merge({
			AutoLocalize = false,
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Size = UDim2.new(0, 0, 1, 0),
			RichText = true,
			FontFace = UI.Theme.FontMono,
			TextColor3 = UI.Theme.PrimaryText,
			TextSize = UI.Theme.FontSize,
			TextStrokeColor3 = UI.Theme.Primary,
			TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
			TextTruncate = Enum.TextTruncate.SplitWord,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
		}, properties))
	end

	local function createItem(self, server)
		local lineItem = {} :: any

		lineItem._instance = UI.new "Frame" {
			BackgroundTransparency = 1,
			Size = self.ItemSize,

			UI.new "UIListLayout" {
				Padding = UI.Theme.Padding,
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			},

			icon { Image = UI.Theme.Image.Host },
			label { Name = "Id" },

			icon { Image = UI.Theme.Image.Graph1 },
			label {
				Name = "Place",
				FontFace = UI.Theme.Font,
				UI.new "UIFlexItem" {
					FlexMode = Enum.UIFlexMode.Shrink,
				},
			},

			UI.new "Spacer" {},

			icon { Image = UI.Theme.Image.Hourglass_Bottom },
			label { Name = "Age" },

			icon { Image = UI.Theme.Image.Play },
			label { Name = "Count" },

			UI.new "Button" {
				Label = "Join",
				Size = buttonSize,

				UI.new "UIFlexItem" {
					FlexMode = Enum.UIFlexMode.Shrink,
				},

				Activated = function()
					if lineItem.placeId and lineItem.jobId then
						_K.Util.SafeTeleport(lineItem.placeId, lineItem.jobId)
					end
				end,
			},
		}

		return lineItem
	end

	local playerCountFormat = `%-{#tostring(_K.Service.Players.MaxPlayers)}d`

	local function renderItem(self, lineItem, jobId)
		local now = tick()
		lineItem.lastRender = now
		lineItem.jobId = jobId

		local data = servers[jobId]
		if data then
			local placeId, playerCount, startTime, _lastUpdate = unpack(data)

			lineItem.placeId = placeId

			lineItem._instance.Id.Text = string.sub(jobId, -6, -1)
			lineItem._instance.Count.Text = string.format(playerCountFormat, playerCount)

			task.spawn(function()
				local name = getPlaceName(placeId)
				if lineItem.lastRender == now then
					lineItem._instance.Place.Text = name
				end
			end)

			task.spawn(function()
				while lineItem.lastRender == now do
					lineItem._instance.Age.Text = _K.Util.Time.clock(DateTime.now().UnixTimestamp - startTime)
					task.wait(1)
				end
			end)
		end
	end

	local scroller = UI.new "ScrollerFast" {
		Name = "Servers",
		List = _K.client.servers,
		DictList = true,
		Enabled = false,
		Visible = false,
		ItemSize = function()
			return UDim2.new(1, 0, 0, UI.Theme.FontSize * 2 + UI.Theme.Padding().Offset)
		end,
		CreateItem = createItem,
		RenderItem = renderItem,
	}

	task.defer(scroller.filter, scroller, function(self, list)
		return list
	end)

	task.defer(scroller.sort, scroller, function(a, b)
		local A, B = servers[a], servers[b]
		if A and B then
			if A[1] == B[1] then
				return A[2] > B[2]
			else
				return A[1] < B[1]
			end
		end
		return a < b
	end)

	return scroller
end

return Servers
