--[[
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::::::::'##:::'##::'#######::'##::::'##:'##:::::::'####::'######:::::::::
:::::::: ##::'##::'##.... ##: ##:::: ##: ##::::::: ####:'##... ##::::::::
:::::::: ##:'##::: ##:::: ##: ##:::: ##: ##:::::::. ##:: ##:::..:::::::::
:::::::: #####:::: ##:::: ##: #########: ##:::::::'##:::. ######:::::::::
:::::::: ##. ##::: ##:::: ##: ##.... ##: ##:::::::..:::::..... ##::::::::
:::::::: ##:. ##:: ##:::: ##: ##:::: ##: ##:::::::::::::'##::: ##::::::::
:::::::: ##::. ##:. #######:: ##:::: ##: ########:::::::. ######:::::::::
::::::::..::::..:::.......:::..:::::..::........:::::::::......::::::::::
:::::::::::::::'###::::'########::'##::::'##:'####:'##::: ##:::::::::::::
::::::::::::::'## ##::: ##.... ##: ###::'###:. ##:: ###:: ##:::::::::::::
:::::::::::::'##:. ##:: ##:::: ##: ####'####:: ##:: ####: ##:::::::::::::
::::::::::::'##:::. ##: ##:::: ##: ## ### ##:: ##:: ## ## ##:::::::::::::
:::::::::::: #########: ##:::: ##: ##. #: ##:: ##:: ##. ####:::::::::::::
:::::::::::: ##.... ##: ##:::: ##: ##:.:: ##:: ##:: ##:. ###:::::::::::::
:::::::::::: ##:::: ##: ########:: ##:::: ##:'####: ##::. ##:::::::::::::
::::::::::::..:::::..::........:::..:::::..::....::..::::..::::::::::::::
:::'####:'##::: ##:'########:'####:'##::: ##:'####:'########:'########:::
:::. ##:: ###:: ##: ##.....::. ##:: ###:: ##:. ##::... ##..:: ##.....::::
:::: ##:: ####: ##: ##:::::::: ##:: ####: ##:: ##::::: ##:::: ##:::::::::
:::: ##:: ## ## ##: ######:::: ##:: ## ## ##:: ##::::: ##:::: ######:::::
:::: ##:: ##. ####: ##...::::: ##:: ##. ####:: ##::::: ##:::: ##...::::::
:::: ##:: ##:. ###: ##:::::::: ##:: ##:. ###:: ##::::: ##:::: ##:::::::::
:::'####: ##::. ##: ##:::::::'####: ##::. ##:'####:::: ##:::: ########:::
:::....::..::::..::..::::::::....::..::::..::....:::::..:::::........::::
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:::::::::::: Thanks for using Kohl's Admin Infinite Edition! ::::::::::::
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:::::::::::::::::::: This script is developed by Kohl :::::::::::::::::::
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
: To configure the admin open the Settings module inside of this script	:
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
]]

if _G.KAU then
	script:Destroy()
else
	_G.KAU = true
	script.Name = "Kohl's Admin Infinite"
	script.Parent = game:GetService("ServerScriptService")

	local function loadModuleAsset(moduleId: number)
		local asset = game:GetService("InsertService"):LoadAsset(moduleId)

		if asset.Name == "MainModule" then
			return assert(require(asset), ":LoadAsset() module returned invalid values!")
		elseif asset:FindFirstChild("MainModule") then
			return assert(require(asset.MainModule), ":LoadAsset() module returned invalid values!")
		elseif asset:IsA("ModuleScript") then
			return assert(require(asset), ":LoadAsset() module returned invalid values!")
		end

		for _, v in asset:GetChildren() do
			if v:IsA("ModuleScript") then
				return assert(require(v), ":LoadAsset() module returned invalid values!")
			end
		end

		error(`Failed to find any matching ModuleScripts for {moduleId}.`)
	end

	local moduleId = 1868400649
	local ok, result = pcall(require, moduleId)
	if not ok then
		warn("Kohl's Admin failed to auto-update from MainModule, attempting to load from asset\nReason:\t" .. result)
		ok, result = pcall(loadModuleAsset, moduleId)
		if not ok then
			warn("Kohl's Admin failed to auto-update from asset\nReason:\t" .. result)
		end
	end
end
