local ContentProvider = game:GetService("ContentProvider")

local module = {
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

return module
