local MainModule
if shared._K_INTERFACE ~= nil or shared._K_MODERN_LOADER == true or (shared._K_LOADER_LOADED and not _G.KAU) then
	MainModule = script:WaitForChild("KA")
else
	MainModule = script:WaitForChild("KAI")
end

local tools = script:FindFirstChild("Tools")
local targetParent = MainModule:FindFirstChild("Server") or MainModule
if tools and not targetParent:FindFirstChild("Tools") then
	tools.Parent = targetParent
end

return require(MainModule)
