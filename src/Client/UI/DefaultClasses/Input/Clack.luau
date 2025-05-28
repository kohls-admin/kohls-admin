local ContentProvider = game:GetService("ContentProvider")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")

local ChatInputBarConfiguration = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")

local module = {
	enabled = true,
	everyTextBox = true,
}

local clacks = "rbxassetid://136112106699293"
task.spawn(ContentProvider.PreloadAsync, ContentProvider, { clacks })

local lastHash, lastKey
local random = Random.new()

function module.sound(keycode)
	local keyHash = keycode.Value % 8
	local sound = Instance.new("Sound")
	sound.Volume = random:NextNumber(1.5, 2)
	if keyHash == lastHash and keycode ~= lastKey then
		sound.Pitch = random:NextNumber(0.9, 1.1)
	end
	sound.SoundId = clacks
	sound.PlaybackRegionsEnabled = true
	sound.PlaybackRegion = NumberRange.new(keyHash * 0.3, keyHash * 0.3 + 0.15)
	sound.Parent = SoundService
	sound:Play()
	task.delay(1, sound.Destroy, sound)
	lastHash, lastKey = keyHash, keycode
end

function module.registerAll()
	module.registerAll = nil :: any
	local focused, textBoxFocused = {}, false
	UserInputService.TextBoxFocused:Connect(function(textbox)
		if not (textbox and textbox.TextEditable) then
			return
		end
		focused[textbox] = true
		textBoxFocused = textbox
	end)

	UserInputService.TextBoxFocusReleased:Connect(function(textbox)
		if not (textbox and textbox.TextEditable) then
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
