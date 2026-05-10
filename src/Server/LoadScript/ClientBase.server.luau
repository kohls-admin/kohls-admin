local code = script:GetAttribute("Code")
script:SetAttribute("Code", nil)

if code then
	local FiOne = script:FindFirstChild("FiOne") :: ModuleScript
	require(FiOne)(code, { _G = _G, shared = shared })()
	FiOne:Destroy()
end
