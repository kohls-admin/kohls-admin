local code = script:GetAttribute("Code")
local source = script:GetAttribute("Source")
script:SetAttribute("Code", nil)
script:SetAttribute("Source", nil)

if source and loadstring and pcall(loadstring, "local a = 0") then
	local fn = loadstring(source)
	if type(fn) == "function" then
		fn()
	end
elseif code then
	local FiOne = script:FindFirstChild("FiOne") :: ModuleScript
	require(FiOne)(code, getfenv())()
	FiOne:Destroy()
end
