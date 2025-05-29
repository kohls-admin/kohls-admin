local code = script:GetAttribute("Code")
script:SetAttribute("Code", nil)

if code then
	local FiOne = script:FindFirstChild("FiOne") :: ModuleScript
	require(FiOne)(code, getfenv())()
	FiOne:Destroy()
end
