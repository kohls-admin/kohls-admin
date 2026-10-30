local Color = {}

local function fromLinear(channel: number): number
	channel = math.clamp(channel, 0, 1)
	if channel < 0.0031308 then
		return channel * 12.92
	end
	return channel ^ (1 / 2.4) * 1.055 - 0.055
end

--- Converts an Oklab HCL Vector3 (X = hue in turns, Y = chroma, Z = lightness) to an sRGB Color3, clamping each
--- linear channel to [0, 1] so out-of-gamut values saturate instead of wrapping.
function Color.hclToRGB(hcl: Vector3): Color3
	local h = hcl.X * 2 * math.pi
	local a, b = hcl.Y * math.cos(h), hcl.Y * math.sin(h)

	local l_ = hcl.Z + 0.3963377774 * a + 0.2158037573 * b
	local m_ = hcl.Z - 0.1055613458 * a - 0.0638541728 * b
	local s_ = hcl.Z - 0.0894841775 * a - 1.2914855480 * b
	local l, m, s = l_ * l_ * l_, m_ * m_ * m_, s_ * s_ * s_

	return Color3.new(
		fromLinear(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s),
		fromLinear(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s),
		fromLinear(-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s)
	)
end

return Color
