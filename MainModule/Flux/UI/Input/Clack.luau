local ContentProvider = game:GetService("ContentProvider")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")

local ChatInputBarConfiguration = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")

local module = {
	enabled = true,
	everyTextBox = true,
	soundList = {
		"18215153828",
		"18215155563",
		"18215157567",
		"18215159165",
		"18215160827",
		"18215161601",
		"18215163477",
		"18215169084",
	},
}

for i, v in module.soundList do
	module.soundList[i] = "rbxassetid://" .. v
end
ContentProvider:PreloadAsync(module.soundList)

local lastHash, lastKey
local clackRandom = Random.new()

function module.sound(keycode)
	local keyHash = keycode.Value % #module.soundList
	local sound = Instance.new("Sound")
	sound.Volume = clackRandom:NextNumber(1.5, 2)
	if keyHash == lastHash and keycode ~= lastKey then
		sound.Pitch = clackRandom:NextNumber(0.9, 1.1)
	end
	sound.SoundId = module.soundList[keyHash + 1]
	sound.Parent = workspace
	sound:Play()
	task.delay(2, sound.Destroy, sound)
	lastHash, lastKey = keyHash, keycode
end

function module.registerAll()
	module.registerAll = nil :: any
	local focused, textBoxFocused = {}, false
	UserInputService.TextBoxFocused:Connect(function(textbox)
		if not textbox then
			return
		end
		focused[textbox] = true
		textBoxFocused = textbox
	end)

	UserInputService.TextBoxFocusReleased:Connect(function(textbox)
		if not textbox then
			return
		end
		focused[textbox] = nil
		if next(focused) then
			return
		end
		textBoxFocused = nil
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
		if
			not module.enabled
			or not (textBoxFocused or ChatInputBarConfiguration.IsFocused)
			or input.KeyCode == Enum.KeyCode.Unknown
		then
			return
		end
		if module.everyTextBox or (textBoxFocused and textBoxFocused:HasTag("KeyClackSound")) then
			task.spawn(module.sound, input.KeyCode)
		end
	end)
	return module
end

return module
