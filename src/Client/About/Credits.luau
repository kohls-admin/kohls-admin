--!strict
-- Credited contributors and special thanks for the About page.
-- `active` sets the commit threshold and day window read by About/Order.luau and .github/scripts/credits.py.
export type Person = { Id: number, GitHub: string?, Tooltip: string? }
export type Credits = {
	active: { commits: number, days: number },
	people: { Person },
	specialThanks: Person,
}

local credits: Credits = {
	active = { commits = 2, days = 365 },
	people = {
		{ Id = 44391621, GitHub = "kohltastrophe", Tooltip = "Creator of Kohl's Admin." }, -- kohl

		-- contributors
		{ Id = 41336494, GitHub = "calculatous" }, -- Calculatous
		{ Id = 352492, GitHub = "DylWithlt" }, -- DylWithlt
		{ Id = 131233603, GitHub = "GiddG" }, -- Geed
		{ Id = 35818691, GitHub = "lightofthestars" }, -- greeny
		{ Id = 201989656, GitHub = "iirealisticdev" }, -- iiRealistic_Dev
		{ Id = 2536605621, GitHub = "ItzMrRatsP" }, -- ItzMrRatsP
		{ Id = 7034077053, GitHub = "wingstosky256" }, -- johnny_klebitz1 (Wingstosky)
		{ Id = 448137594, GitHub = "Lucatacos" }, -- Lucatacos
		{ Id = 130170862, GitHub = "TheHackerLxr" }, -- matsagor1
		{ Id = 1025103658, GitHub = "meisox" }, -- Mei
		{ Id = 958742555, GitHub = "neopolitans" }, -- neopolitans
		{ Id = 3727541395, GitHub = "luv2trilogy" }, -- p3taliie
		{ Id = 345072461, GitHub = "ryanlua" }, -- raenlua
		{ Id = 14658110, GitHub = "rietria" }, -- Rietria
		{ Id = 483215789, GitHub = "crazyrb" }, -- seil
		{ Id = 2014793803, GitHub = "LayzieBones" }, -- SkellyLua
		{ Id = 83478451, GitHub = "StevenDahFish" }, -- stevendahfish
		{ Id = 444317184, GitHub = "vonials" }, -- vonials
		{ Id = 558808710, GitHub = "XoifaiI" }, -- XoifaiI
		{ Id = 15554260, GitHub = "zeejayym" }, -- zeejaym
		{ Id = 1279022258 }, -- arcane
		{ Id = 107192912 }, -- britishtrainspotting
		{ Id = 208790398 }, -- chan
		{ Id = 1224156917 }, -- dalien
		{ Id = 46236725 }, -- Doroku
		{ Id = 1219753275 }, -- DZIDZIO999
		{ Id = 200565345 }, -- easternbloxxer
		{ Id = 190022817 }, -- emblazes
		{ Id = 2258246 }, -- emp
		{ Id = 75214485 }, -- ericance
		{ Id = 195261420 }, -- exobyte
		{ Id = 15303771 }, -- Fragility
		{ Id = 1142396048 }, -- Franklin_Surten (H)
		{ Id = 105503420 }, -- general_legendary
		{ Id = 129134882 }, -- horracecat
		{ Id = 127757866 }, -- iam_danny
		{ Id = 77608258 }, -- icarus
		{ Id = 1022854840 }, -- JJJ
		{ Id = 516417505 }, -- landon
		{ Id = 3286467 }, -- lejam7890
		{ Id = 3357116228 }, -- lemon
		{ Id = 3470429081 }, -- Mercury
		{ Id = 146573772 }, -- metallochrome
		{ Id = 4847574 }, -- mets
		{ Id = 2297254 }, -- min
		{ Id = 1560379748 }, -- mosha
		{ Id = 3230955923 }, -- napiw
		{ Id = 496062049 }, -- pachiswack
		{ Id = 521855368 }, -- rfov
		{ Id = 1686847974 }, -- stone
		{ Id = 197640401 }, -- swibes
		{ Id = 2773879457 }, -- therealfaylix
		{ Id = 9345226 }, -- tomspell
		{ Id = 672360774 }, -- xaz

		-- inspiration & ecosystem
		{ Id = 1670764, Tooltip = "Creator of Fusion." }, -- Elttob
		{ Id = 92658764, Tooltip = "Creator of Moonwave and Cmdr." }, -- evaera
		{ Id = 82347291, Tooltip = "Creator of TopbarPlus and HD Admin." }, -- ForeverHD
		{ Id = 484140, Tooltip = "Creator of Building Tools by F3X." }, -- GigsD4x
		{ Id = 576473, Tooltip = "Creator of Rojo." }, -- lpg
		{ Id = 214258, Tooltip = "Creator of Person299's Admin Commands." }, -- Person299
		{ Id = 70540486, Tooltip = "Luau optimization and bytecode research." }, -- reru
		{ Id = 1237666, Tooltip = "Creator of Adonis and EISS." }, -- Sceleratis
		{ Id = 4812582, Tooltip = "Designer of the Classic Sword." }, -- Sharksie
		{ Id = 2722909519, Tooltip = "Creator of Squash." }, -- sona
		{ Id = 648020, Tooltip = "Pioneered Roblox group development." }, -- trick555
	},
	specialThanks = {
		Id = 16, -- erik.cassel
		Tooltip = "For imagining the world we build in.",
	},
}

return credits
