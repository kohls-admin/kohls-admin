local SoundService = game:GetService("SoundService")

local Sound = {}
Sound.__index = Sound

export type Sound = typeof(setmetatable({} :: { sound: Instance }, Sound))

function Sound.new(id: string): Sound
	local self = {
		sound = Instance.new("Sound"),
	}
	self.sound.PlayOnRemove = true
	self.sound.SoundId = "rbxassetid://" .. id
	return setmetatable(self, Sound)
end

--- Creates a copy of the sound and plays it
function Sound:Play()
	local sound = self.sound:Clone()
	sound.Parent = SoundService
	sound:Destroy()
end

return Sound
