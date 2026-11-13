--!nocheck
local Harness = require("./Harness")
local sert = require("../sert")

local describe = sert.describe
local test = sert.test

local _globals = Harness.globals
local CFrame = _globals.CFrame
local Color3 = _globals.Color3
local Vector3 = _globals.Vector3
local Enum = _globals.Enum

-- Rich character and service double builder for testing all DefaultCommands & VIP modules
local function decorateEnvironment(peerEnv: any)
	local origInstNew = peerEnv.Instance.new
	local customInstLib = table.freeze({
		new = function(className: string, parent: any?)
			local inst = origInstNew(className, parent)
			if className == "ViewportFrame" then
				inst._props.TouchPinch = peerEnv:signal()
			elseif className == "AudioTextToSpeech" then
				inst._props.Ended = peerEnv:signal()
				rawset(inst, "_methods", {
					LoadAsync = function(self: any)
						return self._props._loadStatus or Enum.AssetFetchStatus.Success
					end,
					Play = function(self: any)
						self._props._playing = true
					end,
					Unload = function(self: any)
						self._props._unloaded = true
					end,
				})
			end
			return inst
		end,
		fromExisting = peerEnv.Instance.fromExisting,
	})
	peerEnv.Instance = customInstLib
	rawset(peerEnv.globals, "Instance", customInstLib)

	-- Ensure Terrain has Clear
	local terrain = peerEnv.workspace.Terrain
	local terrainMethods = rawget(terrain, "_methods") or {}
	terrainMethods.Clear = function(self: any)
		self._props._cleared = true
	end
	rawset(terrain, "_methods", terrainMethods)

	-- Ensure Chat service has Chat method
	local chatService = peerEnv.game:GetService("Chat")
	local chatMethods = rawget(chatService, "_methods") or {}
	chatMethods.Chat = function(_self: any, partOrChar: any, message: string)
		chatService._props._lastChat = { target = partOrChar, message = message }
	end
	rawset(chatService, "_methods", chatMethods)

	-- Ensure GroupService has PromptJoinAsync, GetRolesInGroupAsync, and GetGroupInfoAsync
	local groupService = peerEnv.game:GetService("GroupService")
	local groupMethods = rawget(groupService, "_methods") or {}
	groupMethods.PromptJoinAsync = function(_self: any, groupId: number)
		groupService._props._lastPromptGroup = groupId
		return Enum.GroupMembershipStatus.Joined
	end
	groupMethods.GetRolesInGroupAsync = function(_self: any, userId: number, groupId: number?)
		local roles = {}
		local sourceGroups = if groupId then { [groupId] = peerEnv.groups[groupId] } else peerEnv.groups
		for gid, g in sourceGroups do
			local rank = g and g.ranks and g.ranks[userId]
			if rank then
				table.insert(roles, { Id = gid, Name = g.Name or `Group{gid}`, Rank = rank, Role = `Rank{rank}` })
			end
		end
		return { Roles = roles }
	end
	groupMethods.GetGroupInfoAsync = function(_self: any, groupId: number)
		local g = peerEnv.groups[groupId] or {}
		return {
			Id = groupId,
			Name = g.Name or `Group{groupId}`,
			EmblemUrl = "rbxassetid://0",
			Roles = g.Roles or { { Name = "Member", Rank = 1 }, { Name = "Owner", Rank = 255 } },
		}
	end
	rawset(groupService, "_methods", groupMethods)

	-- Ensure MessagingService routes PublishAsync to SubscribeAsync listeners synchronously
	local messaging = peerEnv.game:GetService("MessagingService")
	local msgSubs: { [string]: { (any) -> () } } = {}
	local msgMethods = rawget(messaging, "_methods") or {}
	local function subAsync(_self: any, topic: string, callback: (any) -> ())
		msgSubs[topic] = msgSubs[topic] or {}
		table.insert(msgSubs[topic], callback)
		return {
			Disconnect = function() end,
		}
	end
	local function pubAsync(_self: any, topic: string, data: any)
		local list = msgSubs[topic]
		if list then
			for _, cb in list do
				cb({ Data = data, Sent = 1700000000 })
			end
		end
	end
	msgMethods.SubscribeAsync = subAsync
	msgMethods.PublishAsync = pubAsync
	rawset(messaging, "_methods", msgMethods)
	rawset(messaging, "SubscribeAsync", subAsync)
	rawset(messaging, "PublishAsync", pubAsync)

	-- Ensure TeleportService has ReserveServer and GetPlayerPlaceInstanceAsync
	local teleport = peerEnv.game:GetService("TeleportService")
	local tpMethods = rawget(teleport, "_methods") or {}
	tpMethods.ReserveServer = function()
		return "reserved-access-code", "reserved-server-id"
	end
	tpMethods.GetPlayerPlaceInstanceAsync = function(_self: any, userId: number)
		if userId == 1 then
			return true, nil, 1, "job-1"
		elseif userId == 999 then
			error("Teleport lookup failed")
		end
		return false, nil, 100, "job-other"
	end
	rawset(teleport, "_methods", tpMethods)

	-- Ensure TextChatService has CanUserChatAsync, ChatInputBarConfiguration, and TextChannels (RBXGeneral, RBXSystem)
	local textChat = peerEnv.game:GetService("TextChatService")
	local tcMethods = rawget(textChat, "_methods") or {}
	tcMethods.CanUserChatAsync = function()
		if textChat._props._cannotChat then
			return false
		end
		return true
	end
	rawset(textChat, "_methods", tcMethods)
	if not textChat:FindFirstChildOfClass("ChatInputBarConfiguration") then
		local cib = peerEnv.createInstance("ChatInputBarConfiguration", textChat)
		cib.Enabled = true
	end
	if not textChat:FindFirstChild("TextChannels") then
		local channels = peerEnv.Instance.new("Folder", textChat)
		channels.Name = "TextChannels"
		local rbxGen = peerEnv.Instance.new("TextChannel", channels)
		rbxGen.Name = "RBXGeneral"
		rawset(rbxGen, "_methods", {
			SendAsync = function(self: any, msg: string, meta: string?)
				self._props._lastSent = msg
				self._props._lastMeta = meta
			end,
		})
		local rbxSys = peerEnv.Instance.new("TextChannel", channels)
		rbxSys.Name = "RBXSystem"
		rawset(rbxSys, "_methods", {
			DisplaySystemMessage = function(self: any, msg: string)
				self._props._lastSystemMsg = msg
			end,
		})
	end

	-- Ensure LocalizationService has GetCountryRegionForPlayerAsync
	local locService = peerEnv.game:GetService("LocalizationService")
	local locMethods = rawget(locService, "_methods") or {}
	locMethods.GetCountryRegionForPlayerAsync = function()
		return "US"
	end
	rawset(locService, "_methods", locMethods)

	-- Ensure MarketplaceService has PromptBulkPurchaseFinished and PromptBulkPurchase
	local market = peerEnv.game:GetService("MarketplaceService")
	market._props.PromptBulkPurchaseFinished = peerEnv:signal()
	local marketMethods = rawget(market, "_methods") or {}
	marketMethods.PromptBulkPurchase = function(_self: any, plr: any, items: any)
		market._props._lastBulkPurchase = { player = plr, items = items }
	end
	rawset(market, "_methods", marketMethods)

	-- Ensure AssetService has GetBundleDetailsAsync and rich CreateMeshPartAsync for AlphaWings/Crown
	local assetService = peerEnv.game:GetService("AssetService")
	local assetMethods = rawget(assetService, "_methods") or {}
	assetMethods.GetBundleDetailsAsync = function(_self: any, bundleId: number)
		if bundleId == 999 then
			error("Bundle error")
		end
		return {
			Id = bundleId,
			Name = `Bundle{bundleId}`,
			Items = {
				{ Id = bundleId * 10 + 1, Name = "Outfit", Type = "UserOutfit" },
			},
		}
	end
	assetMethods.CreateMeshPartAsync = function(_self: any, meshId: any)
		local mp = peerEnv.Instance.new("MeshPart")
		mp.MeshId = tostring(meshId or "")
		-- Build LeftWingRig.Wing1["Wing Beam"] for AlphaWings
		local leftRig = peerEnv.Instance.new("Bone", mp)
		leftRig.Name = "LeftWingRig"
		local wing1 = peerEnv.Instance.new("Bone", leftRig)
		wing1.Name = "Wing1"
		local beam = peerEnv.Instance.new("Beam", wing1)
		beam.Name = "Wing Beam"
		local rightRig = peerEnv.Instance.new("Bone", mp)
		rightRig.Name = "RightWingRig"
		local rwing1 = peerEnv.Instance.new("Bone", rightRig)
		rwing1.Name = "Wing1"
		mp.Size = Vector3.one
		return mp
	end
	rawset(assetService, "_methods", assetMethods)

	for _, audioId in { 123456, 999999 } do
		peerEnv.marketplace.products[audioId] = {
			AssetId = audioId,
			Name = `Audio{audioId}`,
			Description = "",
			PriceInRobux = 0,
			AssetTypeId = Enum.AssetType.Audio.Value,
			IsForSale = true,
		}
	end

	-- Ensure InsertService:LoadAsset returns tools, decals, parts, and models as needed
	local insertService = peerEnv.game:GetService("InsertService")
	local insertMethods = rawget(insertService, "_methods") or {}
	insertMethods.LoadAsset = function(_self: any, assetId: number)
		if assetId == 999998 then
			error("Asset is not authorized for this place")
		elseif assetId == 999997 then
			error("Generic insert failure")
		end
		local model = peerEnv.Instance.new("Model")
		model.Name = `Asset{assetId}`
		rawset(model, "_methods", {
			MakeJoints = function() end,
			BreakJoints = function() end,
			MoveTo = function(self: any, pos: Vector3)
				self._props.WorldPivot = CFrame.new(pos)
			end,
		})
		if assetId == 999999 then
			local pkg = peerEnv.createInstance("PackageLink", model)
			pkg.PackageId = "rbxassetid://132328169188520"
			local pkgRef = peerEnv.Instance.new("Folder", model)
			pkgRef.Name = "packageRef"
			peerEnv.Instance.new("ObjectValue", pkgRef)
			return model
		elseif assetId == 1800 then
			local decal = peerEnv.Instance.new("Decal", model)
			decal.Name = "face"
			decal.Texture = `rbxassetid://{assetId}`
			return model
		elseif assetId == 1100 then
			local shirt = peerEnv.Instance.new("Shirt", model)
			shirt.ShirtTemplate = `rbxassetid://{assetId}`
			return model
		elseif assetId == 1200 then
			local pants = peerEnv.Instance.new("Pants", model)
			pants.PantsTemplate = `rbxassetid://{assetId}`
			return model
		elseif assetId == 200 then
			local tshirt = peerEnv.Instance.new("ShirtGraphic", model)
			tshirt.Graphic = `rbxassetid://{assetId}`
			return model
		end
		local tool = peerEnv.Instance.new("Tool", model)
		tool.Name = `Tool{assetId}`
		local handle = peerEnv.Instance.new("Part", tool)
		handle.Name = "Handle"
		local acc = peerEnv.Instance.new("Accoutrement", model)
		acc.Name = `Hat{assetId}`
		local accHandle = peerEnv.Instance.new("Part", acc)
		accHandle.Name = "Handle"
		local accMesh = peerEnv.Instance.new("FileMesh", accHandle)
		accMesh.Name = "Mesh"
		accMesh.MeshType = Enum.MeshType.FileMesh
		accMesh.MeshId = "rbxassetid://123"
		accMesh.TextureId = "rbxassetid://456"
		accMesh.Scale = Vector3.one
		local s = peerEnv.Instance.new("Script", acc)
		s.Name = "HatScript"
		local decal = peerEnv.Instance.new("Decal", model)
		decal.Name = "face"
		decal.Texture = `rbxassetid://{assetId}`
		local shirt = peerEnv.Instance.new("Shirt", model)
		shirt.ShirtTemplate = `rbxassetid://{assetId}`
		local pants = peerEnv.Instance.new("Pants", model)
		pants.PantsTemplate = `rbxassetid://{assetId}`
		local tshirt = peerEnv.Instance.new("ShirtGraphic", model)
		tshirt.Graphic = `rbxassetid://{assetId}`
		return model
	end
	insertMethods.CreateMeshPartAsync = assetMethods.CreateMeshPartAsync
	rawset(insertService, "_methods", insertMethods)

	-- Ensure Players:CreateHumanoidModelFromDescriptionAsync returns a rich character model
	local players = peerEnv.Players
	local playersMethods = rawget(players, "_methods") or {}
	local function makeHumanoidModel(_self: any, _desc: any, rigType: any)
		local m = peerEnv._buildCharacter(peerEnv, {
			Name = "HumanoidModel",
			DisplayName = "HumanoidModel",
			CharacterAdded = peerEnv:signal(),
			CharacterAppearanceLoaded = peerEnv:signal(),
		}, if typeof(rigType) == "EnumItem" then rigType else Enum.HumanoidRigType.R15)
		local animScript = peerEnv.Instance.new("LocalScript", m)
		animScript.Name = "Animate"
		return m
	end
	playersMethods.CreateHumanoidModelFromDescription = makeHumanoidModel
	playersMethods.CreateHumanoidModelFromDescriptionAsync = makeHumanoidModel
	playersMethods.CreateHumanoidModelFromUserId = makeHumanoidModel
	playersMethods.CreateHumanoidModelFromUserIdAsync = makeHumanoidModel
	playersMethods.GetPlayerFromCharacter = function(self: any, character: any)
		for _, plr in self:GetPlayers() do
			if plr.Character == character then
				return plr
			end
		end
		return nil
	end
	rawset(players, "_methods", playersMethods)

	-- Ensure Workspace has GetRealPhysicsFPS and GetServerTimeNow
	local ws = peerEnv.workspace
	local wsMethods = rawget(ws, "_methods") or {}
	wsMethods.GetRealPhysicsFPS = function()
		return 60
	end
	wsMethods.GetServerTimeNow = function()
		return ws._props._serverTimeNow or 1700000000
	end
	wsMethods.Raycast = function()
		return nil
	end
	wsMethods.GetPartBoundsInRadius = function()
		return {}
	end
	rawset(ws, "_methods", wsMethods)

	-- Ensure Lighting has Atmosphere child for environment commands
	local lighting = peerEnv.game:GetService("Lighting")
	if not lighting:FindFirstChildOfClass("Atmosphere") then
		peerEnv.Instance.new("Atmosphere", lighting)
	end
end

local HEAD_ATTACHMENTS = { "HatAttachment", "HairAttachment", "FaceFrontAttachment", "FaceCenterAttachment" }
local HUMANOID_SCALES = { "BodyProportionScale", "BodyHeightScale", "BodyWidthScale", "BodyDepthScale", "HeadScale" }
local UPPER_TORSO_ATTACHMENTS = { "BodyFrontAttachment", "BodyBackAttachment", "NeckRigAttachment" }
local R15_JOINT_ALIASES: { [string]: string } = {
	RightUpperArm = "RightShoulder",
	LeftUpperArm = "LeftShoulder",
	RightUpperLeg = "RightHip",
	LeftUpperLeg = "LeftHip",
}
local LIMB_NAMES = {
	"LeftUpperArm",
	"LeftLowerArm",
	"LeftHand",
	"RightUpperArm",
	"RightLowerArm",
	"RightHand",
	"LeftUpperLeg",
	"LeftLowerLeg",
	"LeftFoot",
	"RightUpperLeg",
	"RightLowerLeg",
	"RightFoot",
	"Left Arm",
	"Right Arm",
	"Left Leg",
	"Right Leg",
}
local R6_TORSO_MOTORS = { "Neck", "Left Shoulder", "Right Shoulder", "Left Hip", "Right Hip" }
local LOG_TYPES = {
	"DEBUG",
	"INFO",
	"WARN",
	"ERROR",
	"CHAT",
	"COMMAND",
	"JOIN",
	"LEAVE",
	"DAMAGE",
	"DEATH",
	"KILL",
	"PURCHASE",
}

local function buildCharacter(peerEnv: any, player: any, rigType: Enum.HumanoidRigType?): any
	peerEnv._buildCharacter = buildCharacter
	local instNew = peerEnv.Instance.new
	local char = instNew("Model")
	char.Name = player.Name

	local function makeMotor(name: string, parent: any)
		local m = instNew("Motor6D", parent)
		m.Name = name
		m.C0 = CFrame.identity
		m.C1 = CFrame.identity
		return m
	end

	local function decoratePart(part: any, joints: { any }?)
		rawset(part, "_methods", {
			CanSetNetworkOwnership = function()
				return true
			end,
			SetNetworkOwner = function() end,
			GetNetworkOwner = function()
				return player
			end,
			ApplyImpulse = function() end,
			ApplyAngularImpulse = function() end,
			GetMass = function(self: any)
				local s = self.Size
				return s.X * s.Y * s.Z
			end,
			GetJoints = function()
				return joints or {}
			end,
			GetConnectedParts = function(self: any)
				return { self }
			end,
		})
		return part
	end

	local root = decoratePart(instNew("Part", char))
	root.Name = "HumanoidRootPart"
	root.CFrame = CFrame.new(0, 10, 0)
	root._props.AssemblyMass = 10
	char.PrimaryPart = root
	local rootAtt = instNew("Attachment", root)
	rootAtt.Name = "RootAttachment"
	rootAtt._props.WorldPosition = Vector3.new(0, 10, 0)
	local rootRigAtt = instNew("Attachment", root)
	rootRigAtt.Name = "RootRigAttachment"
	rootRigAtt._props.WorldPosition = Vector3.new(0, 10, 0)
	makeMotor("RootJoint", root)
	local rootLight = instNew("PointLight", root)
	rootLight.Enabled = true

	local head = decoratePart(instNew("MeshPart", char))
	head.Name = "Head"
	local origSize = instNew("Vector3Value", head)
	origSize.Name = "OriginalSize"
	origSize.Value = Vector3.new(2, 1, 1)
	local headMesh = instNew("SpecialMesh", head)
	headMesh.Name = "Mesh"
	headMesh.Scale = Vector3.one
	local face = instNew("Decal", head)
	face.Name = "face"
	face.Texture = "rbxasset://textures/face.png"
	for _, attName in HEAD_ATTACHMENTS do
		local att = instNew("Attachment", head)
		att.Name = attName
		att._props.WorldPosition = Vector3.new(0, 10, 0)
	end

	local hum = instNew("Humanoid", char)
	hum._props.ApplyDescriptionFinished = peerEnv:signal()
	hum._props.Touched = peerEnv:signal()
	hum._props.RootPart = root
	hum._props.AutomaticScalingEnabled = true
	hum.UseJumpPower = true
	hum.RigType = rigType or Enum.HumanoidRigType.R15
	hum.DisplayName = player.DisplayName
	instNew("HumanoidDescription", hum)
	for _, scaleName in HUMANOID_SCALES do
		local nv = instNew("NumberValue", hum)
		nv.Name = scaleName
		nv.Value = 1
	end

	local animator = instNew("Animator", hum)
	rawset(animator, "_methods", {
		GetPlayingAnimationTracks = function()
			return {}
		end,
		LoadAnimation = function(_self: any, anim: any)
			local track = peerEnv.createInstance("AnimationTrack")
			track._props.Animation = anim
			track._props.Priority = Enum.AnimationPriority.Action
			track._props.Looped = false
			track._props.IsPlaying = false
			track._props.TimePosition = 0
			track._props.Stopped = peerEnv:signal()
			rawset(track, "_methods", {
				Play = function(t: any)
					t._props.IsPlaying = true
				end,
				Stop = function(t: any)
					t._props.IsPlaying = false
					t._props.Stopped:Fire()
				end,
				AdjustSpeed = function() end,
			})
			return track
		end,
	})

	rawset(hum, "_methods", {
		TakeDamage = function(self: any, amount: number)
			self.Health = math.max(0, (self.Health or 100) - amount)
		end,
		MoveTo = function() end,
		ChangeState = function(self: any, state: any)
			self._props._state = state
		end,
		GetState = function(self: any)
			return self._props._state or Enum.HumanoidStateType.Running
		end,
		SetStateEnabled = function(self: any, state: any, enabled: boolean)
			self._props._statesEnabled = self._props._statesEnabled or {}
			self._props._statesEnabled[state] = enabled
		end,
		UnequipTools = function() end,
		RemoveAccessories = function()
			for _, child in char:GetChildren() do
				if child:IsA("Accessory") then
					child:Destroy()
				end
			end
		end,
		GetAccessories = function()
			local out = {}
			for _, child in char:GetChildren() do
				if child:IsA("Accessory") then
					table.insert(out, child)
				end
			end
			return out
		end,
		AddAccessory = function(_self: any, acc: any)
			acc.Parent = char
		end,
		BuildRigFromAttachments = function() end,
		ReplaceBodyPartR15 = function() end,
		GetBodyPartR15 = function(_self: any, part: any)
			if part.Name == "LowerTorso" then
				return Enum.BodyPartR15.LowerTorso
			end
			return Enum.BodyPartR15.RootPart
		end,
		GetAppliedDescription = function(self: any)
			return self._props._description or instNew("HumanoidDescription")
		end,
		ApplyDescription = function(self: any, desc: any)
			self._props._description = desc
		end,
		ApplyDescriptionReset = function(self: any, desc: any)
			self._props._description = desc
		end,
	})

	-- Add R15 and R6 torso/limbs so both rig paths succeed
	local upperTorso = decoratePart(instNew("Part", char))
	upperTorso.Name = "UpperTorso"
	for _, attName in UPPER_TORSO_ATTACHMENTS do
		local att = instNew("Attachment", upperTorso)
		att.Name = attName
		att._props.WorldPosition = Vector3.new(0, 10, 0)
	end
	makeMotor("Waist", upperTorso)

	local lowerTorso = decoratePart(instNew("Part", char))
	lowerTorso.Name = "LowerTorso"
	makeMotor("Root", lowerTorso)
	local waistRigAtt = instNew("Attachment", lowerTorso)
	waistRigAtt.Name = "WaistRigAttachment"
	waistRigAtt._props.WorldPosition = Vector3.new(0, 10, 0)

	local neck = makeMotor("Neck", head)
	neck.Part0 = upperTorso
	neck.Part1 = head

	for _, limbName in LIMB_NAMES do
		local motor = makeMotor(limbName .. "Motor", nil)
		local limb = decoratePart(instNew("Part", char), { motor })
		limb.Name = limbName
		motor.Parent = limb
		motor.Part0 = upperTorso
		motor.Part1 = limb
		local alias = R15_JOINT_ALIASES[limbName]
		if alias then
			local mAlias = makeMotor(alias, limb)
			mAlias.Part0 = upperTorso
			mAlias.Part1 = limb
		end
		local origLimbSize = instNew("Vector3Value", limb)
		origLimbSize.Name = "OriginalSize"
		origLimbSize.Value = Vector3.new(1, 2, 1)
	end

	local torsoR6 = decoratePart(instNew("Part", char))
	torsoR6.Name = "Torso"
	for _, mName in R6_TORSO_MOTORS do
		local m = makeMotor(mName, torsoR6)
		m.Part0 = torsoR6
		m.Part1 = head
	end

	instNew("Shirt", char)
	instNew("Pants", char)
	instNew("ShirtGraphic", char)
	instNew("BodyColors", char)

	local acc = instNew("Accessory", char)
	acc.Name = "TestHat"
	local handle = decoratePart(instNew("Part", acc))
	handle.Name = "Handle"
	local mesh = instNew("SpecialMesh", handle)
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.Scale = Vector3.one
	local hatAtt = instNew("Attachment", handle)
	hatAtt.Name = "HatAttachment"
	instNew("SurfaceAppearance", handle)

	rawset(char, "_methods", {
		MakeJoints = function() end,
		BreakJoints = function() end,
		TranslateBy = function(self: any, delta: Vector3)
			self._props.WorldPivot = self:GetPivot() + delta
		end,
		GetPivot = function(self: any)
			return self._props.WorldPivot or CFrame.new(0, 10, 0)
		end,
		PivotTo = function(self: any, cf: CFrame)
			self._props.WorldPivot = cf
			if root then
				root.CFrame = cf
			end
		end,
		MoveTo = function(self: any, pos: Vector3)
			self._props.WorldPivot = CFrame.new(pos)
		end,
		ScaleTo = function(self: any, scale: number)
			self._props._scale = scale
		end,
		GetScale = function(self: any)
			return self._props._scale or 1
		end,
		GetBoundingBox = function()
			return CFrame.new(0, 10, 0), Vector3.new(4, 5, 2)
		end,
		GetExtentsSize = function()
			return Vector3.new(4, 5, 2)
		end,
	})

	char.Parent = peerEnv.workspace
	player.Character = char

	if player.FindFirstChild and not player:FindFirstChild("PlayerScripts") then
		local ps = peerEnv.createInstance("PlayerScripts", player)
		local pm = instNew("ModuleScript", ps)
		pm.Name = "PlayerModule"
		local controlsTable = {
			moveFunction = function() end,
		}
		rawset(pm, "_factory", function()
			return {
				GetControls = function()
					return controlsTable
				end,
			}
		end)
	end

	if player.SetAttribute then
		player:SetAttribute("_KSessionStart", 1700000000)
		player:SetAttribute("_KPlatform", "PC")
	end
	if player._props then
		player._props.FollowUserId = player._props.FollowUserId or 0
		player._props.AccountAge = player._props.AccountAge or 100
	end

	local playerMethods = rawget(player, "_methods") or {}
	playerMethods.Kick = function(self: any, msg: string?)
		self._props._kicked = msg or true
	end
	playerMethods.IsVerified = function()
		return false
	end
	playerMethods.HasAppearanceLoaded = function()
		return true
	end
	playerMethods.ClearCharacterAppearance = function() end
	playerMethods.GetNetworkPing = function()
		return 0.042
	end
	playerMethods.LoadCharacter = function(self: any)
		return buildCharacter(peerEnv, self, rigType)
	end
	playerMethods.LoadCharacterAsync = playerMethods.LoadCharacter
	playerMethods.LoadCharacterWithHumanoidDescription = function(self: any, _desc: any)
		return buildCharacter(peerEnv, self, rigType)
	end
	playerMethods.LoadCharacterWithHumanoidDescriptionAsync = playerMethods.LoadCharacterWithHumanoidDescription
	rawset(player, "_methods", playerMethods)

	player.CharacterAdded:Fire(char)
	player.CharacterAppearanceLoaded:Fire(char)
	return char
end

local function setupClientState(clientK: any, ch: Harness.MountedEnv)
	local cliEnv = ch.env
	local Flux = clientK.Flux
	local UI = clientK.UI
	clientK.LocalPlayer = cliEnv.Players.LocalPlayer
	clientK.Announce = function(args: any)
		clientK._lastAnnounce = args
	end
	clientK.Notify = function(args: any)
		clientK._lastNotify = args
		if type(args) == "table" and clientK.UI and clientK.UI.Hook then
			local hook = args[clientK.UI.Hook]
			if type(hook) == "table" and type(hook.Action) == "function" then
				hook.Action(true)
			end
		end
	end

	local function makeMockWindow(name: string, withLogFilters: boolean?)
		local frame = cliEnv.Instance.new("Frame")
		frame.Name = name
		frame.Visible = false
		local logTypeFilter = {}
		local filterTypeButtons = {}
		if withLogFilters then
			for _, logType in LOG_TYPES do
				logTypeFilter[logType] = Flux.signal(true)
				filterTypeButtons[logType] = { Activated = cliEnv:signal() }
			end
		end
		return {
			_instance = frame,
			logTypeFilter = logTypeFilter,
			filterTypeButtons = filterTypeButtons,
			updateList = function() end,
		}
	end

	local aboutPage = makeMockWindow("About")
	local commandsPage = makeMockWindow("Commands")
	local bansPage = makeMockWindow("Bans")
	local membersPage = makeMockWindow("Members")
	local serversPage = makeMockWindow("Servers")
	local logsPage = makeMockWindow("Logs", true)
	local settingsPage = makeMockWindow("Settings")
	local vipPage = makeMockWindow("VIP")
	local dashboardWindow = makeMockWindow("DashboardWindow")

	clientK.client = {
		Character = cliEnv:require(clientK.script.Client:WaitForChild("Character")),
		Explorer = {
			Show = function()
				clientK._explorerShown = true
			end,
		},
		UserFrame = function()
			local uf = cliEnv.Instance.new("Frame")
			local icon = cliEnv.Instance.new("ImageLabel", uf)
			icon.Name = "Icon"
			local fromFrame = cliEnv.Instance.new("Frame", uf)
			fromFrame.Name = "From"
			local fromLabel = cliEnv.Instance.new("TextLabel", fromFrame)
			fromLabel.Name = "From"
			fromLabel._props.AbsoluteSize = Vector2.new(100, 20)
			local badge = cliEnv.Instance.new("Frame", fromFrame)
			badge.Name = "Badge"
			return uf
		end,
		TopbarPlus = {
			setTopbarEnabled = function(enabled: boolean)
				clientK._topbarEnabled = enabled
			end,
		},
		CommandBar = {
			CompletionData = function()
				return {}
			end,
			show = function()
				clientK._cmdBarShown = true
			end,
			hide = function()
				clientK._cmdBarShown = false
			end,
		},
		updateCommandInput = function() end,
		bans = Flux.signal(clientK.Data.bans),
		logs = Flux.signal(clientK.Data.logs),
		members = Flux.signal(clientK.Data.members),
		servers = Flux.signal(clientK.Data.servers),
		rank = Flux.signal(math.huge),
		ready = true,
		hotkeys = {
			dashboard = {
				key = UI.signal(Enum.KeyCode.Quote),
				mods = UI.signal({}),
				callback = function()
					dashboardWindow._instance.Visible = not dashboardWindow._instance.Visible
				end,
			},
			commandBar = {
				key = UI.signal(Enum.KeyCode.Semicolon),
				mods = UI.signal({}),
				callback = function() end,
			},
		},
		settings = {
			prefix = Flux.signal({ ";" }),
		},
		playerPrefix = Flux.signal(";"),
		dashboardButton = {
			isSelected = false,
			select = function(self: any)
				self.isSelected = true
				dashboardWindow._instance.Visible = true
			end,
			deselect = function(self: any)
				self.isSelected = false
				dashboardWindow._instance.Visible = false
			end,
		},
		dashboard = {
			[1] = true,
			Window = dashboardWindow,
			About = aboutPage,
			Commands = commandsPage,
			Bans = bansPage,
			Members = membersPage,
			Servers = serversPage,
			Logs = logsPage,
			Settings = settingsPage,
			VIP = vipPage,
			Market = vipPage,
			Tabs = {
				JumpTo = function(self: any, page: any)
					self._currentPage = page
				end,
				_pages = {
					JumpTo = function() end,
				},
				_containerCache = {},
			},
		},
		commandsWindowVisible = function(vis: boolean?)
			commandsPage._instance.Visible = if vis ~= nil then vis else not commandsPage._instance.Visible
		end,
		updateInterfaceAuth = function()
			clientK._interfaceAuthUpdated = true
		end,
	}
end

local function createSimCluster(serverGlobals: { [string]: any }?, serverOnly: boolean?)
	local world = sert.sim.new({ backing = true })
	local server = world:server()
	local client1 = server:client(1, "CreatorPlr")
	local client2 = server:client(2, "TargetPlr")

	local sh = Harness.newPeerEnv(server, { isStudio = false })
	decorateEnvironment(sh.env)

	local srvP1 = sh.env.Players:GetPlayerByUserId(1)
	local srvP2 = sh.env.Players:GetPlayerByUserId(2)
	srvP1.Name = "CreatorPlr"
	srvP1.DisplayName = "CreatorPlr"
	srvP2.Name = "TargetPlr"
	srvP2.DisplayName = "TargetPlr"
	if not srvP1:FindFirstChildOfClass("PlayerGui") then
		sh.env.createInstance("PlayerGui", srvP1)
	end

	buildCharacter(sh.env, srvP1)
	buildCharacter(sh.env, srvP2)

	local ch1: any, ch2: any
	if not serverOnly then
		ch1 = Harness.newPeerEnv(client1, { isClient = true })
		ch2 = Harness.newPeerEnv(client2, { isClient = true })
		decorateEnvironment(ch1.env)
		decorateEnvironment(ch2.env)

		ch1.env.Players.LocalPlayer.Name = "CreatorPlr"
		ch1.env.Players.LocalPlayer.DisplayName = "CreatorPlr"
		ch2.env.Players.LocalPlayer.Name = "TargetPlr"
		ch2.env.Players.LocalPlayer.DisplayName = "TargetPlr"

		buildCharacter(ch1.env, ch1.env.Players.LocalPlayer)
		buildCharacter(ch2.env, ch2.env.Players.LocalPlayer)
		local cliP2OnC1 = ch1.env.Players:GetPlayerByUserId(2)
		if cliP2OnC1 then
			cliP2OnC1.Name = "TargetPlr"
			cliP2OnC1.DisplayName = "TargetPlr"
			buildCharacter(ch1.env, cliP2OnC1)
		end
	end

	for name, value in serverGlobals or {} do
		sh.env.globals[name] = value
	end
	local _K = sh:requireK()
	_K.Data.creatorId = 1
	_K.Data.SEPARATE_DATASTORE = false
	_K.LoadScript = function(source: string, _kind: string, parent: any?)
		local s = sh.env.Instance.new("Script", parent)
		s.Name = source
		return s
	end
	local mockStores: { [string]: any } = {}
	_K.Data.Store = {
		updateAsync = function(key: string, fn: (any) -> any)
			mockStores[key] = fn(mockStores[key] or {})
			return true, mockStores[key]
		end,
		removeAsync = function(_key: string)
			return true
		end,
		setAsync = function(_key: string, _val: any)
			return true
		end,
		getAsync = function(_key: string)
			return true, nil
		end,
	}
	Harness.seedRoles(_K.Data)
	_K.Auth.userRoleAdd(1, "creator")
	_K.Auth.userRoleAdd(1, "vip")

	local clientK: any
	if not serverOnly then
		clientK = ch1:requireK()
		clientK.Data.creatorId = 1
		Harness.seedRoles(clientK.Data)
		clientK.Auth.userRoleAdd(1, "creator")
		clientK.Auth.userRoleAdd(1, "vip")
		setupClientState(clientK, ch1)
	end
	world:run(0.1)

	return {
		world = world,
		server = server,
		client1 = client1,
		client2 = client2,
		sh = sh,
		ch1 = ch1,
		ch2 = ch2,
		srvP1 = srvP1,
		srvP2 = srvP2,
		_K = _K,
		clientK = clientK,
		runSrv = function(raw: string)
			sh.env.task.spawn(function()
				_K.Process.runCommands(_K, 1, raw)
			end)
		end,
		runCli = function(raw: string)
			ch1.env.task.spawn(function()
				clientK.Process.runCommands(clientK, 1, raw)
			end)
		end,
	}
end

-- utf8 whose graphemes join a combining mark to the character before it, like Roblox
local function clusteringUtf8()
	local clustering = setmetatable({}, { __index = utf8 })
	clustering.graphemes = function(text: string)
		local spans = {}
		for first, code in utf8.codes(text) do
			local last = first + #utf8.char(code) - 1
			if code >= 0x300 and code <= 0x36F and #spans > 0 then
				spans[#spans][2] = last
			else
				table.insert(spans, { first, last })
			end
		end
		local i = 0
		return function()
			i += 1
			local span = spans[i]
			if span then
				return span[1], span[2]
			end
			return nil
		end
	end
	return clustering
end

describe("DefaultCommands", function()
	test(
		"registers all default command modules and executes Administration, Creator, Environment, and SuperAdmin commands",
		function()
			local c = createSimCluster()
			local _K, clientK, srvP1, srvP2 = c._K, c.clientK, c.srvP1, c.srvP2
			local runSrv, runCli = c.runSrv, c.runCli

			local notifications: { { plr: any, msg: any } } = {}
			local origNotifyFire = _K.Remote.Notify.Fire
			_K.Remote.Notify.Fire = function(self: any, plr: any, msg: any)
				table.insert(notifications, { plr = plr, msg = msg })
				return origNotifyFire(self, plr, msg)
			end

			-- === Administration.luau ===
			sert.eq(
				_K.Registry.commands.announce.run({ _K = _K, from = 1, fromPlayer = srvP1, global = true }, "GlobalMsg"),
				"Announcements are disabled in private servers."
			)
			_K.Data.SEPARATE_DATASTORE = true
			sert.eq(
				_K.Registry.commands.announce.run({ _K = _K, from = 1, fromPlayer = srvP1, global = false }, "PrivMsg"),
				"Announcements are disabled in private servers."
			)
			_K.Data.SEPARATE_DATASTORE = false

			local announceArg = { redactLog = true }
			local origPublishTopic = _K.Data.publishTopic
			local publishedTopics = {}
			_K.Data.publishTopic = function(topic: string, data: any)
				table.insert(publishedTopics, { topic = topic, data = data })
				return true
			end
			_K.Registry.commands.announce.run(
				{ _K = _K, from = 1, fromPlayer = srvP1, args = { announceArg } },
				"DirectAnnounce"
			)
			sert.eq(announceArg.redactLog, false)
			sert.eq(_K.Data.savedSettings.announcement[1], "DirectAnnounce")
			sert.eq(#publishedTopics, 1)
			sert.eq(publishedTopics[1].topic, "announce")
			_K.Registry.commands.unannounce.run({ _K = _K, from = 1, fromPlayer = srvP1 })
			sert.eq(_K.Data.savedSettings.announcement, false)
			sert.eq(_K.Data._skipNextAnnounceSync, _K.Data.REMOVE)
			sert.eq(#publishedTopics, 2)
			sert.eq(publishedTopics[2].topic, "announce")
			_K.Data.publishTopic = origPublishTopic
			c.world:run(61)

			runSrv(";announce Hello world")
			-- { text, from, duration, id }, the id tells a repeated announcement apart from a settings sync
			local pinned = _K.Data.savedSettings.announcement
			sert.eq({ pinned[1], pinned[2], pinned[3] }, { "Hello world", 1, 0 })
			sert.eq(type(pinned[4]), "string")
			sert.eq(_K.Data.Sync.settings.announcement, pinned)
			-- Advance past 60s broadcast cooldown so subsequent announce/chat/global calls succeed
			c.world:run(61)
			runSrv(";unannounce")
			sert.eq(_K.Data.savedSettings.announcement, false)
			sert.eq(_K.Data.Sync.settings.announcement, _K.Data.REMOVE)

			table.clear(notifications)
			runSrv(";role TargetPlr vip")
			sert.eq(_K.Auth.hasRole(2, "vip"), true)
			sert.eq(#notifications >= 1, true)
			sert.eq(notifications[1].plr, srvP2)
			sert.eq(string.find(notifications[1].msg.Text, "Gave you the", 1, true) ~= nil, true)

			-- Re-giving the same role exercises "already has role" branch (no duplicate target notification)
			table.clear(notifications)
			runSrv(";role TargetPlr vip")
			local gaveTargetAgain = false
			for _, n in notifications do
				if n.plr == srvP2 then
					gaveTargetAgain = true
				end
			end
			sert.eq(gaveTargetAgain, false)

			table.clear(notifications)
			runSrv(";temprole TargetPlr mod")
			sert.eq(_K.Auth.hasRole(2, "mod"), true)
			sert.eq(#notifications >= 1, true)
			sert.eq(notifications[1].plr, srvP2)

			table.clear(notifications)
			runSrv(";unrole TargetPlr mod")
			sert.eq(_K.Auth.hasRole(2, "mod"), false)
			sert.eq(#notifications >= 1, true)
			sert.eq(string.find(notifications[1].msg.Text, "TargetPlr", 1, true) ~= nil, true)

			table.clear(notifications)
			runSrv(";removemember TargetPlr")
			sert.eq(_K.Data.members["2"], nil)
			sert.eq(_K.Data.Sync.members["2"], _K.Data.REMOVE)
			sert.eq(#notifications, 1)
			sert.eq(string.find(notifications[1].msg.Text, "TargetPlr", 1, true) ~= nil, true)

			-- Removing a non-member exercises "not a member" guard branch (no notification sent)
			table.clear(notifications)
			_K.Registry.commands.removemember.run({ _K = _K, from = 1, fromPlayer = srvP1 }, { "2" })
			sert.eq(#notifications, 0)

			runSrv(";gear TargetPlr 12345")
			sert.ok((srvP2.Backpack:FindFirstChild("Tool12345")))
			-- Authorized error & generic error branches in gear
			runSrv(";gear TargetPlr 999998")
			runSrv(";gear TargetPlr 999997")

			runSrv(";insert 12345")
			sert.eq(#_K.cleanupCommands > 0, true)
			sert.eq(_K.cleanupCommands[1].Parent, c.sh.env.workspace)
			-- Test blocked insert asset id, packageRef path, and authorized/generic error paths
			local insertCtx = { _K = _K, from = 1, fromPlayer = srvP1, env = _K.Registry.commands.insert.env }
			sert.eq(_K.Registry.commands.insert.run(insertCtx, 59524079), "Model has been blocked.")
			sert.eq(_K.Registry.commands.insert.run(insertCtx, 999999), "Model has been blocked.")
			local errAuth = _K.Registry.commands.insert.run(insertCtx, 999998)
			sert.eq(string.find(tostring(errAuth), "Game Creator's inventory!", 1, true) ~= nil, true)
			local errGen = _K.Registry.commands.insert.run(insertCtx, 999997)
			sert.eq(string.find(tostring(errGen), "Generic insert failure", 1, true) ~= nil, true)
			sert.eq(#_K.cleanupCommands, 1)

			local prevTeleports = #c.sh.env.teleports
			runSrv(";place TargetPlr 100")
			sert.eq(#c.sh.env.teleports > prevTeleports, true)

			runSrv(";serverlock")
			sert.eq(_K._serverLock, "CreatorPlr")
			-- Calling serverlock again exercises "already locked" guard branch
			runSrv(";serverlock")
			sert.eq(_K._serverLock, "CreatorPlr")

			runSrv(";unserverlock")
			sert.eq(_K._serverLock, nil)

			-- === Creator.luau ===
			runSrv(";hidelogs")
			sert.eq(_K.Data.logsHidden[1], true)
			runSrv(";unhidelogs")
			sert.ok(not _K.Data.logsHidden[1])
			-- Verify clearlogs envClient preserves client logs (log[6] == true) and refreshes dashboard.Logs
			local clientLogKept = { "client log", 0, 1, 1, "CreatorPlr", true }
			local serverLogCleared = { "server log", 0, 2, 1, "CreatorPlr" }
			clientK.Data.logs = { clientLogKept, serverLogCleared }
			local logsDashboardRefreshed = 0
			local origUpdateList = clientK.client.dashboard.Logs.updateList
			clientK.client.dashboard.Logs.updateList = function(self: any, ...: any)
				logsDashboardRefreshed += 1
				if origUpdateList then
					return origUpdateList(self, ...)
				end
			end
			_K.Remote.ClearLogs:Fire(srvP1)
			c.world:run(0.05)
			clientK.client.dashboard.Logs.updateList = origUpdateList
			sert.eq(#clientK.Data.logs, 1)
			sert.eq(clientK.Data.logs[1], clientLogKept)
			sert.eq(logsDashboardRefreshed, 1)

			local removedLogKeys = {}
			local origRemoveAsync = _K.Data.Store.removeAsync
			_K.Data.Store.removeAsync = function(key: string)
				table.insert(removedLogKeys, key)
				return true
			end
			table.insert(_K.Data.pendingLogReveals, { log = { "pending" }, targets = {} })
			local prevLogsVersion = _K.Data.logsVersion
			_K.Registry.commands.clearlogs.run({
				_K = _K,
				from = 1,
				fromPlayer = srvP1,
				env = _K.Registry.commands.clearlogs.env,
			})
			c.world:run(0.05)
			sert.eq(#_K.Data.logs, 0)
			sert.eq(#_K.Data.pendingLogReveals, 0)
			sert.eq(_K.Data.logsVersion > prevLogsVersion, true)
			sert.eq(#removedLogKeys, 4)

			table.clear(removedLogKeys)
			_K.Data.SEPARATE_DATASTORE = true
			table.insert(_K.Data.logs, { "priv_log", 0, 1, 1, "CreatorPlr" })
			_K.Registry.commands.clearlogs.run({
				_K = _K,
				from = 1,
				fromPlayer = srvP1,
				env = _K.Registry.commands.clearlogs.env,
			})
			c.world:run(0.05)
			sert.eq(#_K.Data.logs, 0)
			sert.eq(#removedLogKeys, 0)
			_K.Data.SEPARATE_DATASTORE = false
			_K.Data.Store.removeAsync = origRemoveAsync

			-- Verify ;global unannounce does not queue a local REMOVE sync and Settings UI edit is not suppressed by _skipNextAnnounceSync
			runSrv(";announce LocalPinned")
			local pinnedBeforeGlobalUnannounce = _K.Data.savedSettings.announcement
			sert.eq(pinnedBeforeGlobalUnannounce[1], "LocalPinned")
			sert.eq(_K.Data._skipNextAnnounceSync, pinnedBeforeGlobalUnannounce)
			-- Simulate a different announcement value modified before processSync runs
			local editedAnnouncement = { "EditedViaSettings", 1, 0, "edited_id" }
			_K.Data.Sync.settings.announcement = editedAnnouncement
			sert.eq(_K.Data._skipNextAnnounceSync ~= _K.Data.Sync.settings.announcement, true)
			-- Running ;global unannounce publishes to MessagingService without queuing REMOVE in local Sync.settings
			_K.Registry.commands.unannounce.run({ _K = _K, from = 1, fromPlayer = srvP1, global = true })
			sert.eq(_K.Data.Sync.settings.announcement, editedAnnouncement)
			_K.Registry.commands.unannounce.run({ _K = _K, from = 1, fromPlayer = srvP1, global = false })
			sert.eq(_K.Data.Sync.settings.announcement, _K.Data.REMOVE)
			local prevCleanupCount = #_K.cleanupCommands
			runSrv(";script local x = 1 + 1")
			sert.eq(#_K.cleanupCommands, prevCleanupCount + 1)
			runSrv(";localscript CreatorPlr local y = 2 + 2")
			sert.ok((srvP1:FindFirstChildOfClass("PlayerGui"):FindFirstChild("local y = 2 + 2")))

			-- === Environment.luau ===
			local lighting = c.sh.env.game:GetService("Lighting")
			local terrain = c.sh.env.workspace.Terrain
			local atmosphere = lighting:FindFirstChildOfClass("Atmosphere")
			runSrv(";ambient 255,0,0")
			sert.eq(lighting.Ambient, Color3.fromRGB(255, 0, 0))
			runSrv(";outdoorambient 0,255,0")
			sert.eq(lighting.OutdoorAmbient, Color3.fromRGB(0, 255, 0))
			runSrv(";atmosphere 0.5 0.1 255,255,255 10,20,30 0.2 0.3")
			sert.eq(atmosphere.Density, 0.5)
			sert.eq(atmosphere.Offset, 0.1)
			sert.eq(atmosphere.Color, Color3.fromRGB(255, 255, 255))
			sert.eq(atmosphere.Decay, Color3.fromRGB(10, 20, 30))
			sert.eq(atmosphere.Glare, 0.2)
			sert.eq(atmosphere.Haze, 0.3)
			runSrv(";fogcolor 100,100,100")
			sert.eq(lighting.FogColor, Color3.fromRGB(100, 100, 100))
			sert.eq(atmosphere.Color, Color3.fromRGB(100, 100, 100))
			sert.eq(atmosphere.Haze >= 2 ^ -32, true)
			runSrv(";fogstart 10")
			sert.eq(lighting.FogStart, 10)
			sert.eq(math.abs(atmosphere.Density - (64 / 10) ^ 0.25) < 1e-4, true)
			sert.eq(math.abs(atmosphere.Haze - 5 / 10 ^ 0.1) < 1e-4, true)
			runSrv(";fogend 500")
			sert.eq(lighting.FogEnd, 500)
			sert.eq(math.abs(atmosphere.Density - (64 / 500) ^ 0.25) < 1e-4, true)
			sert.eq(math.abs(atmosphere.Haze - 5 / 500 ^ 0.1) < 1e-4, true)
			runSrv(";brightness 3")
			sert.eq(lighting.Brightness, 3)
			runSrv(";colorshift 255,0,0 0,0,255")
			sert.eq(lighting.ColorShift_Bottom, Color3.fromRGB(255, 0, 0))
			sert.eq(lighting.ColorShift_Top, Color3.fromRGB(0, 0, 255))
			runSrv(";diffusescale 0.5")
			sert.eq(lighting.EnvironmentDiffuseScale, 0.5)
			runSrv(";specularscale 0.5")
			sert.eq(lighting.EnvironmentSpecularScale, 0.5)
			runSrv(";exposure 1.5")
			sert.eq(lighting.ExposureCompensation, 1.5)
			runSrv(";time 6")
			sert.eq(lighting.ClockTime, 6)
			runSrv(";time 12:30:36")
			sert.eq(math.abs(lighting.ClockTime - (12 + 30 / 60 + 36 / 3600)) < 1e-4, true)
			runSrv(";time 12 0.01")
			c.sh.env:advance(0.05)
			sert.eq(lighting.ClockTime, 12)
			runSrv(";latitude 45")
			sert.eq(lighting.GeographicLatitude, 45)
			runSrv(";latitude")
			sert.eq(lighting.GeographicLatitude, _K.Registry.commands.latitude.env.defaultLatitude)
			runSrv(";shadows false")
			sert.eq(lighting.GlobalShadows, false)
			runSrv(";skybox 1 2 3 4 5 6")
			local sky = lighting:FindFirstChild("_KSky")
			sert.ok(sky)
			sert.ok(sky.SkyboxDn)
			sert.eq(sky.SkyboxBk ~= sky.SkyboxDn, true)
			sert.eq(sky.SkyboxLf ~= sky.SkyboxDn, true)
			sert.eq(sky.SkyboxUp ~= sky.SkyboxDn, true)
			sert.eq(sky.SkyboxFt ~= sky.SkyboxDn, true)
			sert.eq(sky.SkyboxRt ~= sky.SkyboxDn, true)
			runSrv(";skybox 7")
			sert.eq(sky.SkyboxBk, sky.SkyboxDn)
			sert.eq(sky.SkyboxLf, sky.SkyboxDn)
			sert.eq(sky.SkyboxUp, sky.SkyboxDn)
			sert.eq(sky.SkyboxFt, sky.SkyboxDn)
			sert.eq(sky.SkyboxRt, sky.SkyboxDn)
			runSrv(";unskybox")
			sert.eq(lighting:FindFirstChild("_KSky"), nil)
			runSrv(";airdensity 0.05")
			sert.eq(c.sh.env.workspace.AirDensity, 0.05)
			runSrv(";gravity 100")
			sert.eq(c.sh.env.workspace.Gravity, 100)
			runSrv(";gravity")
			sert.eq(c.sh.env.workspace.Gravity, _K.Registry.commands.gravity.env.gravity)
			runSrv(";windspeed 20")
			sert.eq(math.round(c.sh.env.workspace.GlobalWind.Magnitude), 20)
			local windDirThread = c.sh.env.task.spawn(function()
				runSrv(";winddir")
			end)
			c.world:run(0.05)
			_K.Remote.SpectateSubject:Fire(srvP1, CFrame.new(0, 0, -1))
			c.world:run(0.05)
			c.sh.env.task.cancel(windDirThread)
			sert.eq(math.round(c.sh.env.workspace.GlobalWind.Magnitude), 20)
			runSrv(";watercolor 0,100,200")
			sert.eq(terrain.WaterColor, Color3.fromRGB(0, 100, 200))
			runSrv(";waterreflectance 0.5")
			sert.eq(terrain.WaterReflectance, 0.5)
			runSrv(";watertransparency 0.5")
			sert.eq(terrain.WaterTransparency, 0.5)
			runSrv(";watersize 0.2")
			sert.eq(terrain.WaterWaveSize, 0.2)
			runSrv(";waterspeed 15")
			sert.eq(terrain.WaterWaveSpeed, 15)
			runSrv(";fix")
			sert.eq(c.sh.env.workspace.Gravity, 196.2)
			sert.eq(lighting.Brightness, _K.Registry.commands.fix.env[lighting].Brightness)

			-- === SuperAdmin.luau ===
			-- the sert BadgeService double predates AwardBadgeAsync
			local badgeService = _K.Service.Badge
			local function awardToEnv(_self, userId, badgeId)
				local badges = c.sh.env.badges
				badges[userId] = badges[userId] or {}
				badges[userId][badgeId] = true
				return true
			end
			badgeService.AwardBadgeAsync = awardToEnv
			local function runBadge(badgeId)
				local res = nil
				c.sh.env.task.spawn(function()
					res = _K.Registry.commands.badge.run({ _K = _K, fromPlayer = srvP1 }, { srvP2 }, badgeId)
				end)
				c.world:run(20)
				return tostring(res)
			end
			local function has(text, needle)
				return string.find(text, needle, 1, true) ~= nil
			end

			runSrv(";badge TargetPlr 555")
			sert.eq(c.sh.env.badges[2][555], true)
			-- Second award counts as already owned, not a failure
			sert.eq(runBadge(555), "nil")
			sert.eq(c.sh.env.badges[2][555], true)
			-- AwardBadgeAsync erroring every retry reports the error
			badgeService.AwardBadgeAsync = function()
				error("BadgeAPIError")
			end
			local badgeErrRes = runBadge(999)
			sert.eq(has(badgeErrRes, "failed 1"), true)
			sert.eq(has(badgeErrRes, "BadgeAPIError"), true)
			-- AwardBadgeAsync returning false (e.g. badge from another experience) is a failure, not a success
			badgeService.AwardBadgeAsync = function()
				return false
			end
			local declinedRes = runBadge(998)
			sert.eq(has(declinedRes, "Roblox declined"), true)
			sert.eq(c.sh.env.badges[2][998], nil)
			badgeService.AwardBadgeAsync = awardToEnv
			-- disabled badge fails fast without awarding
			local origGetBadgeInfo = badgeService.GetBadgeInfoAsync
			badgeService.GetBadgeInfoAsync = function(_self, badgeId)
				return { Name = `Badge{badgeId}`, IsEnabled = false }
			end
			sert.eq(has(runBadge(997), "is disabled"), true)
			sert.eq(c.sh.env.badges[2][997], nil)
			-- missing badge info reports the lookup failure
			badgeService.GetBadgeInfoAsync = function()
				error("BadgeNotFound")
			end
			local missingRes = runBadge(996)
			sert.eq(has(missingRes, "Couldn't load badge 996"), true)
			sert.eq(has(missingRes, "BadgeNotFound"), true)
			badgeService.GetBadgeInfoAsync = origGetBadgeInfo

			-- btools
			local btoolMock = c.sh.env.Instance.new("Tool")
			btoolMock.Name = "Building Tools"
			_K.Registry.commands.btools.env.tool = btoolMock
			runSrv(";btools TargetPlr")
			sert.ok((srvP2.Backpack:FindFirstChild("Building Tools")))
			-- Second btools run skips duplicating when "Building Tools" is already in Backpack
			runSrv(";btools TargetPlr")
			local btoolCount = 0
			for _, child in srvP2.Backpack:GetChildren() do
				if child.Name == "Building Tools" then
					btoolCount += 1
				end
			end
			sert.eq(btoolCount, 1)

			c.world:run(61)
			runCli(";chat")
			c.world:run(0.05)
			sert.eq(
				string.find(tostring(clientK._lastNotify and clientK._lastNotify.Text), "disabled", 1, true) ~= nil,
				true
			)

			runSrv(";clearterrain")
			sert.eq(c.sh.env.workspace.Terrain._props._cleared, true)

			runCli(";explorer")
			sert.eq(clientK._explorerShown, true)

			local incogSrvEnv = _K.Registry.commands.incognito.env
			local incogFired = {}
			local origIncogFireAll = incogSrvEnv.remote.FireAll
			incogSrvEnv.remote.FireAll = function(self, ...)
				table.insert(incogFired, { ... })
				return origIncogFireAll(self, ...)
			end
			runSrv(";incognito TargetPlr false")
			sert.eq(incogSrvEnv.hidden[srvP2], false)
			sert.eq(incogFired[#incogFired][1], srvP2.UserId)
			sert.eq(incogFired[#incogFired][3], false)
			runSrv(";incognito TargetPlr true")
			sert.eq(incogSrvEnv.hidden[srvP2], true)
			sert.eq(incogFired[#incogFired][1], srvP2.Name)
			sert.eq(incogFired[#incogFired][3], true)
			incogSrvEnv.remote.FireAll = origIncogFireAll
			c.world:run(0.05)
			runCli(";incognitolist")
			local incogEnv = clientK.Registry.commands.incognitolist.env
			sert.eq(incogEnv.window._instance.Visible, true)
			if incogEnv.scroller and incogEnv.scroller.CreateItem then
				local item = incogEnv.scroller:CreateItem()
				incogEnv.scroller:RenderItem(item, 2)
				sert.ok(item)
			end
			-- Toggle window visibility false to exercise close handler
			incogEnv.window._instance.Visible = false

			table.clear(notifications)
			local ensuredServersCount = 0
			local origEnsureServers = _K.Data.ensureServersLoaded
			_K.Data.ensureServersLoaded = function(...)
				ensuredServersCount += 1
				return origEnsureServers(...)
			end
			local publishedReserve = {}
			local origPublish = _K.Data.publishTopic
			_K.Data.publishTopic = function(topic, payload)
				if topic == "reserve" then
					table.insert(publishedReserve, payload)
				end
				return origPublish(topic, payload)
			end
			runSrv(";reserve TestServer")
			sert.eq(ensuredServersCount, 1)
			sert.ok(_K.Data.reservedServers["TestServer"])
			sert.eq(#publishedReserve, 1)
			sert.eq(type(publishedReserve[1]), "table")
			sert.eq(publishedReserve[1][1], "TestServer")
			sert.eq(#notifications >= 1, true)
			sert.eq(string.find(notifications[#notifications].msg.Text, "has been reserved", 1, true) ~= nil, true)
			-- Re-reserving same server code returns already-reserved message
			local dupRes = _K.Registry.commands.reserve.run(
				{ _K = _K, from = srvP1.UserId, fromPlayer = srvP1, args = { {} } },
				"TestServer"
			)
			sert.eq(string.find(tostring(dupRes), "already reserved", 1, true) ~= nil, true)

			local tpBefore = #c.sh.env.teleports
			runSrv(";place TargetPlr @TestServer")
			sert.eq(#c.sh.env.teleports, tpBefore + 1)
			sert.eq(
				c.sh.env.teleports[#c.sh.env.teleports].options.ReservedServerAccessCode,
				_K.Data.reservedServers["TestServer"][2]
			)

			table.clear(notifications)
			local beforeUnreserveEnsure = ensuredServersCount
			runSrv(";unreserve TestServer")
			sert.eq(ensuredServersCount > beforeUnreserveEnsure, true)
			sert.eq(_K.Data.reservedServers["TestServer"], nil)
			sert.eq(#publishedReserve, 2)
			sert.eq(publishedReserve[2], "TestServer")
			sert.eq(#notifications >= 1, true)
			sert.eq(string.find(notifications[#notifications].msg.Text, "has been removed", 1, true) ~= nil, true)
			_K.Data.ensureServersLoaded = origEnsureServers
			_K.Data.publishTopic = origPublish

			c.world:run(61)
			runSrv(";global announce GlobalTest")
			runSrv(";global gravity 80")
			c.world:run(0.1)
			sert.eq(c.sh.env.workspace.Gravity, 80)
			local sawTimeLog, sawGlobalLog = false, false
			for _, logEntry in _K.Data.logs do
				local text = tostring(logEntry[1])
				if text == ";time 12:30:36" then
					sawTimeLog = true
				elseif string.find(text, ';global ;announce "GlobalTest"', 1, true) then
					sawGlobalLog = true
				end
			end
			sert.eq(sawTimeLog, true)
			sert.eq(sawGlobalLog, true)
			-- Test Shutdown server cancellation branch and countdown > 0
			local announceCount = 0
			local origAnnounceFireAll = _K.Remote.Announce.FireAll
			_K.Remote.Announce.FireAll = function(self, ...)
				announceCount += 1
				return origAnnounceFireAll(self, ...)
			end
			local shutThread = c.sh.env.task.spawn(function()
				runSrv(";shutdown 2 Maintenance soon")
			end)
			c.world:run(0.05)
			sert.eq(announceCount, 1)
			runSrv(";shutdown") -- cancel active shutdown (no delay -> no Announce:FireAll)
			sert.eq(announceCount, 1)
			c.sh.env.task.cancel(shutThread)
			_K.Remote.Announce.FireAll = origAnnounceFireAll
			-- Trigger client Shutdown remote listener
			_K.Remote.Shutdown:Fire(srvP1, 2, "CreatorPlr", "Test reason")
			_K.Remote.Shutdown:Fire(srvP1, nil)
			c.world:run(0.05)

			runSrv(";shutdown 0 Server maintenance")
			c.world:run(0.05)
			sert.eq(string.find(tostring(srvP2._props._kicked), "has shutdown the server.", 1, true) ~= nil, true)
			sert.eq(string.find(tostring(srvP2._props._kicked), "Reason: Server maintenance", 1, true) ~= nil, true)
			-- Direct shutdown with nil fromPlayer falls back to tostring(context.from) and updates args[2].parsedArgs
			local shutArg2: any = {}
			_K.Registry.commands.shutdown.run(
				{ _K = _K, from = 77777, fromPlayer = nil, args = { {}, shutArg2 } },
				nil,
				"OfflineReason"
			)
			sert.eq(shutArg2.parsedArgs, { "OfflineReason" })
			sert.eq(shutArg2.redactLog, nil)
			sert.eq(string.find(tostring(srvP2._props._kicked), "77777 has shutdown the server.", 1, true) ~= nil, true)
		end
	)

	test("executes General and Utility commands on server and client", function()
		local c = createSimCluster()
		local _K, clientK, srvP1, srvP2 = c._K, c.clientK, c.srvP1, c.srvP2
		local runSrv, runCli = c.runSrv, c.runCli

		c.sh.env.groups[100] = {
			Name = "TestGroup",
			ranks = { [1] = 255, [2] = 50 },
		}
		c.ch1.env.groups[100] = c.sh.env.groups[100]

		-- Populate clientK.Data.emotes so emotes scroller has items to filter/render
		clientK.Data.emotes = {
			["507771019"] = "Dance1",
			["507771955"] = "Dance2",
		}
		_K.Data.emotes = clientK.Data.emotes

		-- === General.luau ===
		runSrv(";hint Server hint")
		c.world:run(61)
		runSrv(";privatehint TargetPlr Private hint")
		c.world:run(61)
		runSrv(";message Server message")
		c.world:run(61)
		runSrv(";fullmessage Full message")
		c.world:run(61)
		runSrv(";notify TargetPlr Notification text")
		c.world:run(61)
		runSrv(";privatemessage TargetPlr Secret PM")
		c.world:run(0.05)

		-- Trigger client _K.Chat.onMessage handlers via _K.Remote.ChatSystem
		for _, kind in { "announce", "hint", "privatehint", "message", "fullmessage", "notify", "privatemessage" } do
			_K.Remote.ChatSystem:Fire(srvP1, kind, "Hello " .. kind, 1, "British male", "msg_" .. kind)
		end
		c.world:run(0.1)
		sert.ok(clientK._lastAnnounce)
		sert.ok(clientK._lastNotify)

		-- Countdown start and cancel + client StartCountdown display
		runSrv(";countdown 2")
		c.world:run(0.05)
		c.ch1.env.game:GetService("RunService").Heartbeat:Fire(0.016)
		runSrv(";countdown") -- cancel countdown
		c.world:run(0.05)

		runSrv(";title TargetPlr Champion #ff0000 #00ff00 Legacy")
		sert.ok((srvP2.Character:FindFirstChild("_K_Title")))
		runSrv(";untitle TargetPlr")
		sert.eq(srvP2.Character:FindFirstChild("_K_Title"), nil)

		-- Vote & Poll: invoke the real client Vote OnInvoke handler inside ch1.env.task.spawn
		local origVoteInvoke = clientK.Remote.Vote.OnInvoke
		if type(origVoteInvoke) == "function" then
			_K.Remote.ChatSystem:Fire(srvP1, "vote", "Continue?", 1, nil, "vote_1")
			c.world:run(0.05)
			local voteInvokeThread = c.ch1.env.task.spawn(function()
				origVoteInvoke("vote_1", c.ch1.env.Players.LocalPlayer, 2, { "YES", "NO" })
			end)
			c.world:run(0.05)
			c.ch1.env.task.cancel(voteInvokeThread)
		end
		clientK.Remote.Vote.OnClientInvoke = function()
			return 1
		end
		c.world:run(61)
		local voteThread = c.sh.env.task.spawn(function()
			runSrv(";vote CreatorPlr Continue?")
		end)
		c.world:run(0.1)
		c.sh.env.task.cancel(voteThread)

		c.world:run(61)
		local pollThread = c.sh.env.task.spawn(function()
			runSrv(';poll CreatorPlr "Best map?" Crossroads,SFOTH,Doomspire')
		end)
		c.world:run(0.1)
		c.sh.env.task.cancel(pollThread)

		-- Client link / unlink / watch / spectate / unspectate
		local cliP2Root = c.ch1.env.Players:GetPlayerByUserId(2).Character.HumanoidRootPart
		runCli(";link TargetPlr true")
		sert.ok((cliP2Root:FindFirstChild("_KLink")))
		c.ch1.env.game:GetService("RunService").RenderStepped:Fire(0.016)
		runCli(";unlink TargetPlr")
		sert.eq(cliP2Root:FindFirstChild("_KLink"), nil)
		runCli(";watch TargetPlr")
		sert.eq(
			c.ch1.env.workspace.CurrentCamera.CameraSubject,
			c.ch1.env.Players:GetPlayerByUserId(2).Character.Humanoid
		)

		runSrv(";spectate TargetPlr")
		runCli(";spectate TargetPlr")
		local runServiceCli = c.ch1.env.game:GetService("RunService")
		-- Exercise spectate PreRender across R15 (scaling true/false), R6, and Dead states
		runServiceCli.PreRender:Fire(0.016)
		local localHum = c.ch1.env.Players.LocalPlayer.Character.Humanoid
		localHum._props.AutomaticScalingEnabled = false
		runServiceCli.PreRender:Fire(0.016)
		localHum.RigType = Enum.HumanoidRigType.R6
		runServiceCli.PreRender:Fire(0.016)
		localHum:ChangeState(Enum.HumanoidStateType.Dead)
		runServiceCli.PreRender:Fire(0.016)
		localHum:ChangeState(Enum.HumanoidStateType.Running)
		localHum.RigType = Enum.HumanoidRigType.R15
		localHum._props.AutomaticScalingEnabled = true

		clientK.Remote.Spectate:Fire(CFrame.identity)
		c.world:run(0.05)
		runSrv(";unspectate TargetPlr")
		runCli(";unspectate")
		sert.eq(c.ch1.env.workspace.CurrentCamera.CameraSubject, localHum)

		-- Fly / noclip / clip / notrip / xray
		runSrv(";fly TargetPlr 50")
		sert.eq(srvP2:GetAttribute("_KFly"), 50)
		runSrv(";unfly TargetPlr")
		sert.eq(srvP2:GetAttribute("_KFly"), nil)

		runSrv(";noclip TargetPlr")
		sert.eq(srvP2:GetAttribute("_KNoClip"), true)
		sert.eq(srvP2:GetAttribute("_KFly"), 128)
		runSrv(";clip TargetPlr")
		sert.eq(srvP2:GetAttribute("_KNoClip"), nil)

		runSrv(";notrip TargetPlr")
		_K.Remote.Notrip:Fire(srvP1, true)
		c.world:run(0.05)
		sert.ok((localHum:GetState()))
		runSrv(";unnotrip TargetPlr")
		_K.Remote.Notrip:Fire(srvP1, false)
		c.world:run(0.05)

		runCli(";xray")
		sert.eq(clientK.Registry.commands.xray.env.xray(), true)
		runCli(";unxray")
		sert.eq(clientK.Registry.commands.xray.env.xray(), false)

		local origShowFps = clientK.Remote.ShowFPS.OnInvoke
		if type(origShowFps) == "function" then
			local fpsVal
			local showFpsThread = c.ch1.env.task.spawn(function()
				fpsVal = origShowFps()
			end)
			runServiceCli.Heartbeat:Fire(0.016)
			c.world:run(0.05)
			c.ch1.env.task.cancel(showFpsThread)
			sert.eq(type(fpsVal), "number")
		end
		clientK.Remote.ShowFPS.OnClientInvoke = function()
			return 60
		end
		local whoisThread = c.sh.env.task.spawn(function()
			runSrv(";whois CreatorPlr")
		end)
		c.world:run(0.1)
		c.sh.env.task.cancel(whoisThread)

		runCli(";grouprank TargetPlr 100")
		sert.ok(clientK._lastNotify.Text)
		runCli(";playercount")
		sert.eq(clientK._lastNotify.Text, "<b>Player Count:</b> 2")

		c.world:run(61)
		runSrv(';tts "British male" Hello voice')
		_K.Remote.ChatSystem:Fire(srvP1, "tts", "Hello voice", 1, "British male", "tts_1")
		c.world:run(0.05)

		runSrv(";play 123456")
		sert.eq(_K.Registry.commands.play.env.playing.SoundId, "rbxassetid://123456")
		runSrv(";pause")
		runSrv(";resume")
		runSrv(";pitch 1.5")
		sert.eq(_K.Registry.commands.play.env.playing.Pitch, 1.5)
		runSrv(";volume 0.3")
		sert.eq(_K.Registry.commands.play.env.playing.Volume, 0.3)
		runSrv(";stop")
		sert.eq(_K.Registry.commands.play.env.playing.Parent, nil)
		runSrv(";clean")

		-- === Utility.luau ===
		runCli(";version")
		sert.ok(clientK._lastNotify.Text)
		runCli(";prefix")
		sert.ok(clientK._lastNotify.Text)
		runCli(";cmdbar2")
		local cmdbar2Window = clientK.Registry.commands.cmdbar2.env.window
		sert.eq(cmdbar2Window._instance.Visible, true)
		runCli(";cmdbar2")
		sert.eq(cmdbar2Window._instance.Visible, false)

		runCli(";about")
		sert.eq(clientK.client.dashboard.About._instance.Visible, true)
		clientK.client.dashboard.About._instance.Visible = false

		runCli(";commands")
		sert.eq(clientK.client.dashboard.Commands._instance.Visible, true)
		clientK.client.dashboard.Commands._instance.Visible = false

		runCli(";commandbar")
		c.world:run(0.05)
		sert.eq(clientK._cmdBarShown, true)
		runCli(";dashboard")
		sert.eq(clientK.client.dashboard.Window._instance.Visible, true)

		runCli(";donate")
		sert.eq(clientK.client.dashboard.Market._instance.Visible, true)
		clientK.client.dashboard.Market._instance.Visible = false

		runCli(";log")
		sert.eq(clientK.client.dashboard.Logs._instance.Visible, true)
		runCli(";debuglogs")
		runCli(";errorlogs")
		runCli(";chatlogs")
		sert.eq(clientK.client.dashboard.Logs.logTypeFilter.CHAT:peek(), true)
		sert.eq(clientK.client.dashboard.Logs.logTypeFilter.COMMAND:peek(), false)
		runCli(";clogs")
		sert.eq(clientK.client.dashboard.Logs.logTypeFilter.CHAT:peek(), true)
		runCli(";commandlogs")
		runCli(";joinlogs")
		runCli(";damagelogs")
		runCli(";killlogs")
		runCli(";purchaselogs")
		clientK.client.dashboard.Logs._instance.Visible = false

		runCli(";settings")
		sert.eq(clientK.client.dashboard.Settings._instance.Visible, true)
		clientK.client.dashboard.Settings._instance.Visible = false

		runSrv(";emote TargetPlr 507771019")
		_K.Remote.Emote:Fire(srvP1, 507771019)
		c.world:run(0.05)
		local emoteEnv = clientK.Registry.commands.emote.env
		sert.eq(emoteEnv.window._instance.Visible, true)
		runSrv(";stopemote TargetPlr")
		_K.Remote.Emote:Fire(srvP1, nil)
		c.world:run(0.05)
		sert.eq(emoteEnv.window._instance.Visible, false)

		-- Verify emote ownership & VIP bypass in emote.run
		do
			local emoteCmd = _K.Registry.commands.emote
			local bulkPrompts: { any } = {}
			local emoteFires: { any } = {}
			local mktMethods = rawget(_K.Service.Marketplace, "_methods")
			local origPromptBulk = mktMethods and mktMethods.PromptBulkPurchase
			local origOwnsAsset = mktMethods and mktMethods.PlayerOwnsAssetAsync
			local ownedAssets: { [number]: boolean } = {}
			if mktMethods then
				mktMethods.PromptBulkPurchase = function(_self: any, plr: any, items: any)
					table.insert(bulkPrompts, { plr = plr, items = items })
				end
				mktMethods.PlayerOwnsAssetAsync = function(_self: any, _plr: any, assetId: number)
					return ownedAssets[assetId] == true
				end
			end
			local origEmoteFire = emoteCmd.env.remote.Fire
			emoteCmd.env.remote.Fire = function(_self: any, plr: any, anim: any, loop: any, spd: any)
				table.insert(emoteFires, { plr = plr, anim = anim, loop = loop, spd = spd })
			end

			_K.Data.animationToEmoteId[9001] = 2001
			_K.VIP.allowedBulkPurchaseIds[2001] = true
			_K.Data.animationToEmoteId[9002] = 2002
			_K.VIP.allowedBulkPurchaseIds[2002] = nil

			local p2Ctx = {
				_K = _K,
				env = emoteCmd.env,
				from = srvP2.UserId,
				fromPlayer = srvP2,
			}

			-- 1. Non-VIP who does not own a sellable emote gets prompted for emoteId (2001)
			srvP2:SetAttribute("_KDonationLevel", 0)
			emoteCmd.run(p2Ctx, { srvP2 }, 9001)
			sert.eq(#emoteFires, 0)
			sert.eq(#bulkPrompts, 1)
			sert.eq(bulkPrompts[1].items[1].Id, "2001")

			-- 2. Non-VIP who does not own an offsale/non-bulk emote gets the VIP Popup via Remote.VIPNotification:Fire(plr, true)
			table.clear(bulkPrompts)
			local vipNotifications: { any } = {}
			local origVipNotifFire = _K.Remote.VIPNotification.Fire
			_K.Remote.VIPNotification.Fire = function(_self: any, plr: any, forcePopup: any)
				table.insert(vipNotifications, { plr = plr, forcePopup = forcePopup })
				return origVipNotifFire(_self, plr, forcePopup)
			end
			clientK.VIP.popup.Visible = false
			emoteCmd.run(p2Ctx, { srvP2 }, 9002)
			sert.eq(#emoteFires, 0)
			sert.eq(#bulkPrompts, 0)
			sert.eq(#vipNotifications, 1)
			sert.eq(vipNotifications[1].plr, srvP2)
			sert.eq(vipNotifications[1].forcePopup, true)

			-- 3. Non-VIP who owns the emote asset (2001) plays it without purchase prompt
			table.clear(bulkPrompts)
			ownedAssets[2001] = true
			emoteCmd.run(p2Ctx, { srvP2 }, 9001)
			sert.eq(#bulkPrompts, 0)
			sert.eq(#emoteFires, 1)
			sert.eq(emoteFires[1].anim, 9001)

			-- 4. VIP user (via _KDonationLevel >= 1, vip role, freeAdmin vip, or custom VIP group role) plays unowned emote without purchase prompt
			table.clear(emoteFires)
			ownedAssets[2001] = false
			srvP2:SetAttribute("_KDonationLevel", 1)
			emoteCmd.run(p2Ctx, { srvP2 }, 9001)
			sert.eq(#bulkPrompts, 0)
			sert.eq(#emoteFires, 1)

			table.clear(emoteFires)
			srvP2:SetAttribute("_KDonationLevel", 0)
			_K.Auth.userRoleAdd(srvP2.UserId, "vip")
			emoteCmd.run(p2Ctx, { srvP2 }, 9001)
			sert.eq(#bulkPrompts, 0)
			sert.eq(#emoteFires, 1)
			_K.Auth.userRoleRemove(srvP2.UserId, "vip")

			-- 4b. freeAdmin = { "vip" } grants free emote access even when Auth.hasRole is false for same rank
			table.clear(emoteFires)
			_K.Data.settings.freeAdmin = { "vip" }
			emoteCmd.run(p2Ctx, { srvP2 }, 9002)
			sert.eq(#bulkPrompts, 0)
			sert.eq(#emoteFires, 1)
			_K.Data.settings.freeAdmin = {}

			-- 4c. Custom role with groups = { "vip" } at rank 0 grants free emote access
			table.clear(emoteFires)
			_K.Data.roles.customVip = {
				_key = "customVip",
				_rank = 0,
				name = "CustomVIP",
				color = "#0ff",
				groups = { "vip" },
				permissions = {},
			}
			_K.Auth.userRoleAdd(srvP2.UserId, "customVip")
			emoteCmd.run(p2Ctx, { srvP2 }, 9002)
			sert.eq(#bulkPrompts, 0)
			sert.eq(#emoteFires, 1)
			_K.Auth.userRoleRemove(srvP2.UserId, "customVip")
			_K.Data.roles.customVip = nil

			-- 4d. Joining player with _KDonationLevel == nil awaits VIP.setDonationLevel before prompting
			table.clear(emoteFires)
			srvP2:SetAttribute("_KDonationLevel", nil)
			ownedAssets[115444443724463] = true
			_K.Data.settings.vip = false
			emoteCmd.run(p2Ctx, { srvP2 }, 9002)
			_K.Data.settings.vip = true
			sert.eq(srvP2:GetAttribute("_KDonationLevel"), 4)
			sert.eq(#bulkPrompts, 0)
			sert.eq(#emoteFires, 1)
			ownedAssets[115444443724463] = false
			srvP2:SetAttribute("_KDonationLevel", 0)

			-- 5. Stopping an emote (animation == nil) does not prompt purchase
			table.clear(emoteFires)
			emoteCmd.run(p2Ctx, { srvP2 }, nil :: any)
			sert.eq(#bulkPrompts, 0)
			sert.eq(#emoteFires, 1)

			-- 6. When settings.vip == false, offsale/non-bulk emotes (9002) do not prompt purchase and do not play
			table.clear(bulkPrompts)
			table.clear(emoteFires)
			table.clear(vipNotifications)
			_K.Data.settings.vip = false
			emoteCmd.run(p2Ctx, { srvP2 }, 9002)
			sert.eq(#bulkPrompts, 0)
			sert.eq(#vipNotifications, 0)
			sert.eq(#emoteFires, 0)
			_K.Data.settings.vip = true

			-- 7. Disconnected fromPlayer (Parent == nil) is a safe no-op
			local origParent = srvP2.Parent
			srvP2.Parent = nil
			emoteCmd.run(p2Ctx, { srvP2 }, 9001)
			srvP2.Parent = origParent
			sert.eq(#bulkPrompts, 0)
			sert.eq(#emoteFires, 0)

			-- 8. Client Emote preview Unlock button opens VIP popup on off-sale emotes and updates owned state on PromptBulkPurchaseFinished
			clientK.Data.emoteItemFromId[2002] = {
				emoteId = 2002,
				animationId = 9002,
				name = "OffsaleEmote",
				nameLower = "offsaleemote",
				canSell = false,
				owned = false,
			}
			clientK.Data.emoteItemFromId[2001] = {
				emoteId = 2001,
				animationId = 9001,
				name = "SellableEmote",
				nameLower = "sellableemote",
				canSell = true,
				owned = false,
			}
			if emoteEnv.updatePreview and emoteEnv.preview then
				emoteEnv.updatePreview(2002)
				emoteEnv.preview.Visible = true
				clientK.VIP.popup.Visible = false
				emoteEnv.preview.Unlock.Activated:Fire()
				sert.eq(emoteEnv.preview.Visible, false)
				sert.eq(clientK.VIP.popup.Visible, true)
				clientK.VIP.popup.Visible = false

				emoteEnv.updatePreview(2001)
				emoteEnv.preview.Visible = true
				local cliMkt = c.ch1.env.game:GetService("MarketplaceService")
				cliMkt.PromptBulkPurchaseFinished:Fire(
					c.ch1.env.Players.LocalPlayer,
					Enum.MarketplaceBulkPurchasePromptStatus.Completed,
					{ Items = { { Id = "2001", Status = Enum.MarketplaceItemPurchaseStatus.Success } } }
				)
				c.world:run(0.05)
				sert.eq(clientK.Data.emoteItemFromId[2001].owned, true)
				sert.eq(emoteEnv.preview.Visible, false)
			end

			_K.Remote.VIPNotification.Fire = origVipNotifFire
			emoteCmd.env.remote.Fire = origEmoteFire
			if mktMethods then
				mktMethods.PromptBulkPurchase = origPromptBulk
				mktMethods.PlayerOwnsAssetAsync = origOwnsAsset
			end
		end

		runCli(";emotes")
		local emotesEnv = clientK.Registry.commands.emotes.env
		sert.eq(emotesEnv.window._instance.Visible, true)
		if emotesEnv.scroller and emotesEnv.scroller.CreateItem then
			local createItemFn = if type(emotesEnv.scroller.CreateItem) == "table"
				then emotesEnv.scroller.CreateItem:peek()
				else emotesEnv.scroller.CreateItem
			local renderItemFn = if type(emotesEnv.scroller.RenderItem) == "table"
				then emotesEnv.scroller.RenderItem:peek()
				else emotesEnv.scroller.RenderItem
			local waveData = { name = "Wave", emoteId = 507771019, owned = true }
			local emoteItem = createItemFn(emotesEnv.scroller, waveData)
			renderItemFn(emotesEnv.scroller, emoteItem, waveData)
			sert.ok(emoteItem)
			local imgButton = emoteItem._instance:FindFirstChildOfClass("ImageButton")
			sert.ok(imgButton)
			sert.eq(type(imgButton.Image), "string")
			sert.eq(imgButton.Image, clientK.UI.Theme.Image.Play:peek())
		end
		emotesEnv.window._instance.Visible = false

		runCli(";age TargetPlr")
		sert.ok(clientK._lastNotify.Text)
		runCli(";serverage")
		sert.ok(clientK._lastNotify.Text)
		runCli(";gameid")
		sert.ok(clientK._lastNotify.Text)
		runCli(";jobid")
		sert.ok(clientK._lastNotify.Text)
		runCli(";placeid")
		sert.ok(clientK._lastNotify.Text)

		local fpsThread = c.sh.env.task.spawn(function()
			runSrv(";showfps CreatorPlr")
		end)
		local waitThread = c.sh.env.task.spawn(function()
			runSrv(";wait 0.01")
		end)
		c.world:run(0.1)
		c.sh.env.task.cancel(fpsThread)
		c.sh.env.task.cancel(waitThread)

		runSrv(";ping TargetPlr")
		runSrv(";rejoin")

		runCli(";viewas vip")
		sert.eq(clientK.Registry.commands.viewas.env.originalCreatorId, 1)
		runCli(";unviewas")
		sert.eq(clientK.Registry.commands.viewas.env.originalCreatorId, nil)
	end)

	test(
		"executes all Moderation commands including teams, leaderstats, tools, health, movement, and punishments",
		function()
			local c = createSimCluster()
			local _K, clientK, srvP1, srvP2 = c._K, c.clientK, c.srvP1, c.srvP2
			local runSrv, runCli = c.runSrv, c.runCli

			-- Populate StarterPack and clientK.tools with a tool for give/startergive/tools/startertools/viewtools
			local spTool = c.sh.env.Instance.new("Tool", c.sh.env.game:GetService("StarterPack"))
			spTool.Name = "Launcher"
			c.sh.env.Instance.new("Part", spTool).Name = "Handle"

			local cliSpTool = c.ch1.env.Instance.new("Tool", c.ch1.env.game:GetService("StarterPack"))
			cliSpTool.Name = "Launcher"
			cliSpTool.ToolTip = "Rocket Launcher"
			local cliSpTool2 = c.ch1.env.Instance.new("Tool", c.ch1.env.game:GetService("StarterPack"))
			cliSpTool2.Name = "Grapple"
			clientK.tools = { cliSpTool, cliSpTool2 }
			local cliP2OnC1 = c.ch1.env.Players:GetPlayerByUserId(2)
			if cliP2OnC1 then
				local p2Tool = c.ch1.env.Instance.new("Tool", cliP2OnC1.Backpack)
				p2Tool.Name = "Sword"
				p2Tool.ToolTip = "Classic Sword"
			end

			-- Populate leaderstats on srvP2
			local ls = c.sh.env.Instance.new("Folder", srvP2)
			ls.Name = "leaderstats"
			local coins = c.sh.env.Instance.new("IntValue", ls)
			coins.Name = "Coins"
			coins.Value = 10
			local statusStat = c.sh.env.Instance.new("StringValue", ls)
			statusStat.Name = "Status"
			statusStat.Value = "Idle"
			local activeStat = c.sh.env.Instance.new("BoolValue", ls)
			activeStat.Name = "Active"
			activeStat.Value = false

			-- Client dashboard/window tabs in Moderation
			runCli(";bans")
			sert.eq(clientK.client.dashboard.Bans._instance.Visible, true)
			clientK.client.dashboard.Bans._instance.Visible = false

			runCli(";members")
			sert.eq(clientK.client.dashboard.Members._instance.Visible, true)
			clientK.client.dashboard.Members._instance.Visible = false

			runCli(";servers")
			sert.eq(clientK.client.dashboard.Servers._instance.Visible, true)
			clientK.client.dashboard.Servers._instance.Visible = false

			runCli(";tools")
			local toolsEnv = clientK.Registry.commands.tools.env
			sert.eq(toolsEnv.window._instance.Visible, true)
			if toolsEnv.scroller and toolsEnv.scroller.CreateItem then
				local item = toolsEnv.scroller:CreateItem()
				toolsEnv.scroller:RenderItem(item, "Launcher")
				sert.ok(item)
			end
			toolsEnv.window._instance.Visible = false

			runCli(";startertools")
			sert.eq(toolsEnv.window._instance.Visible, true)
			toolsEnv.window._instance.Visible = false

			runCli(";viewtools TargetPlr")
			sert.eq(toolsEnv.window._instance.Visible, true)
			toolsEnv.window._instance.Visible = false

			-- Mute / unmute
			runSrv(";mute TargetPlr")
			sert.ok(_K.Registry.commands.mute.env.muted[2])
			_K.Remote.Mute:Fire(srvP1, true)
			c.world:run(0.05)
			runSrv(";unmute TargetPlr")
			sert.eq(_K.Registry.commands.mute.env.muted[2], nil)
			_K.Remote.Mute:Fire(srvP1, false)
			c.world:run(0.05)

			-- Punish / unpunish
			runSrv(";punish TargetPlr")
			sert.eq(srvP2.Character, nil)
			runSrv(";unpunish TargetPlr")
			sert.eq(srvP2.Character.Parent, c.sh.env.workspace)

			-- Name / hidename / showname / unname
			runSrv(";name TargetPlr CustomNick")
			sert.eq(srvP2.Character.Humanoid.DisplayName, "CustomNick")
			runSrv(";hidename TargetPlr")
			sert.eq(srvP2.Character.Humanoid.DisplayDistanceType, Enum.HumanoidDisplayDistanceType.None)
			runSrv(";showname TargetPlr")
			sert.eq(srvP2.Character.Humanoid.DisplayDistanceType, Enum.HumanoidDisplayDistanceType.Viewer)
			runSrv(";unname TargetPlr")
			sert.eq(srvP2.Character.Humanoid.DisplayName, "TargetPlr")

			-- CoreGui
			runSrv(";setcoregui TargetPlr Backpack false")
			_K.Remote.SetCoreGuiEnabled:Fire(srvP1, Enum.CoreGuiType.Backpack, false)
			c.world:run(0.05)
			sert.eq(c.ch1.env.game:GetService("StarterGui"):GetCoreGuiEnabled(Enum.CoreGuiType.Backpack), false)

			-- Tools: give, startergive, starterremove, copytools, removetools, sword, toolban, untoolban
			runSrv(";give TargetPlr Launcher")
			sert.ok((srvP2.Backpack:FindFirstChild("Launcher")))
			runSrv(";give TargetPlr all")
			sert.eq(#srvP2.Backpack:GetChildren() >= 1, true)
			runSrv(";startergive TargetPlr Launcher")
			sert.ok((srvP2.StarterGear:FindFirstChild("Launcher")))
			runSrv(";starterremove TargetPlr Launcher")
			sert.eq(srvP2.StarterGear:FindFirstChild("Launcher"), nil)
			runSrv(";copytools TargetPlr CreatorPlr")
			sert.ok((srvP1.Backpack:FindFirstChild("Launcher")))
			runSrv(";sword TargetPlr")
			runSrv(";removetools TargetPlr")
			sert.eq(#srvP2.Backpack:GetChildren(), 0)
			runSrv(";toolban TargetPlr")
			sert.ok(_K.Registry.commands.toolban.env.bans[srvP2])
			-- Adding a tool while toolbanned destroys it via task.defer
			local bannedTool = c.sh.env.Instance.new("Tool", srvP2.Backpack)
			c.world:run(0.05)
			sert.eq(bannedTool.Parent, nil)
			runSrv(";untoolban TargetPlr")
			sert.eq(_K.Registry.commands.toolban.env.bans[srvP2], nil)

			-- Health, damage, forcefield, immortal, kill, loopkill
			runSrv(";health TargetPlr 250")
			sert.eq(srvP2.Character.Humanoid.MaxHealth, 250)
			runSrv(";hurt TargetPlr 50")
			sert.eq(srvP2.Character.Humanoid.Health, 200)
			runSrv(";heal TargetPlr")
			sert.eq(srvP2.Character.Humanoid.Health, 250)
			runSrv(";forcefield TargetPlr")
			sert.ok((srvP2.Character:FindFirstChildOfClass("ForceField")))
			runSrv(";unforcefield TargetPlr")
			sert.eq(srvP2.Character:FindFirstChildOfClass("ForceField"), nil)
			runSrv(";immortal TargetPlr")
			sert.eq(srvP2.Character.Humanoid.MaxHealth, math.huge)
			sert.ok((srvP2.Character:FindFirstChild("_Kff")))
			runSrv(";mortal TargetPlr")
			sert.eq(srvP2.Character.Humanoid.MaxHealth, 250)
			sert.eq(srvP2.Character:FindFirstChild("_Kff"), nil)
			runSrv(";kill TargetPlr")
			sert.eq(srvP2.Character.Humanoid.Health, 0)
			buildCharacter(c.sh.env, srvP2)
			runSrv(";loopkill TargetPlr")
			sert.eq(_K.Registry.commands.loopkill.env.killing[srvP2.UserId], true)
			c.world:run(0.1)
			runSrv(";unloopkill TargetPlr")
			sert.eq(_K.Registry.commands.loopkill.env.killing[srvP2.UserId], nil)
			buildCharacter(c.sh.env, srvP2)

			-- Visibility, blind, freeze, jail, lock, stun
			runSrv(";invisible TargetPlr")
			sert.eq(srvP2.Character.Head.Transparency, 1)
			sert.eq(srvP2.Character.HumanoidRootPart:FindFirstChildOfClass("PointLight").Enabled, false)
			runSrv(";visible TargetPlr")
			sert.eq(srvP2.Character.Head.Transparency, 0)
			sert.eq(srvP2.Character.HumanoidRootPart:FindFirstChildOfClass("PointLight").Enabled, true)

			runSrv(";blind TargetPlr")
			_K.Remote.Blind:Fire(srvP1, true)
			c.world:run(0.05)
			sert.eq(clientK.Registry.commands.blind.env.frame.Visible, true)
			runSrv(";unblind TargetPlr")
			_K.Remote.Blind:Fire(srvP1, false)
			c.world:run(0.05)
			sert.eq(clientK.Registry.commands.blind.env.frame.Visible, false)

			runSrv(";freeze TargetPlr")
			sert.ok((srvP2.Character:FindFirstChild("kFreeze")))
			sert.eq(srvP2.Character.HumanoidRootPart.Anchored, true)
			runSrv(";thaw TargetPlr")
			sert.eq(srvP2.Character:FindFirstChild("kFreeze"), nil)
			sert.eq(srvP2.Character.HumanoidRootPart.Anchored, false)

			runSrv(";jail TargetPlr")
			sert.ok(_K.Registry.commands.jail.env.parts[srvP2.UserId])
			-- Re-jailing exercises existing jail guard, and respawn while jailed recaptures
			runSrv(";jail TargetPlr")
			_K.Registry.commands.jail.env.recapture(srvP2.Character)
			runSrv(";unjail TargetPlr")
			sert.eq(_K.Registry.commands.jail.env.parts[srvP2.UserId], nil)

			runSrv(";lock TargetPlr")
			sert.eq(srvP2.Character.HumanoidRootPart.Locked, true)
			runSrv(";unlock TargetPlr")
			sert.eq(srvP2.Character.HumanoidRootPart.Locked, false)
			runSrv(";stun TargetPlr")
			sert.eq(srvP2.Character.Humanoid.PlatformStand, true)
			runSrv(";unstun TargetPlr")
			sert.eq(srvP2.Character.Humanoid.PlatformStand, false)

			-- CameraOffset, antilag, fps, fov
			runSrv(";cameraoffset CreatorPlr 1,2,3")
			c.world:run(0.05)
			sert.eq(c.ch1.env.Players.LocalPlayer.Character.Humanoid.CameraOffset, Vector3.new(1, 2, 3))
			runSrv(";antilag TargetPlr")
			runSrv(";unantilag TargetPlr")
			runSrv(";fps TargetPlr 120")
			_K.Remote.FPS:Fire(srvP1, 120)
			c.world:run(0.05)
			runSrv(";unfps TargetPlr")
			_K.Remote.FPS:Fire(srvP1)
			c.world:run(0.05)
			runSrv(";fov TargetPlr 90")
			_K.Remote.FOV:Fire(srvP1, 90)
			c.world:run(0.05)
			sert.eq(c.ch1.env.workspace.CurrentCamera.FieldOfView, 90)
			runSrv(";unfov TargetPlr")
			_K.Remote.FOV:Fire(srvP1, nil)
			c.world:run(0.05)
			sert.eq(c.ch1.env.workspace.CurrentCamera.FieldOfView, 70)

			-- Teleportation & movement
			srvP2.Character:PivotTo(CFrame.new(100, 0, 100))
			runSrv(";bring TargetPlr")
			sert.eq((srvP2.Character:GetPivot().Position - srvP1.Character:GetPivot().Position).Magnitude <= 10, true)
			srvP2.Character:PivotTo(CFrame.new(200, 0, 200))
			runSrv(";to TargetPlr")
			sert.eq((srvP1.Character:GetPivot().Position - srvP2.Character:GetPivot().Position).Magnitude <= 10, true)
			srvP2.Character:PivotTo(CFrame.new(0, 0, 0))
			runSrv(";tp TargetPlr CreatorPlr")
			sert.eq((srvP2.Character:GetPivot().Position - srvP1.Character:GetPivot().Position).Magnitude <= 10, true)
			runSrv(";jump TargetPlr")
			sert.eq(srvP2.Character.Humanoid.Jump, true)
			runSrv(";jumppower TargetPlr 75")
			sert.eq(srvP2.Character.Humanoid.JumpPower, 75)
			runSrv(";starterjumppower 80")
			sert.eq(c.sh.env.game:GetService("StarterPlayer").CharacterJumpPower, 80)
			runSrv(";sit TargetPlr")
			sert.eq(srvP2.Character.Humanoid.Sit, true)
			runSrv(";unsit TargetPlr")
			sert.eq(srvP2.Character.Humanoid.Sit, false)
			runSrv(";speed TargetPlr 32")
			sert.eq(srvP2.Character.Humanoid.WalkSpeed, 32)
			runSrv(";starterspeed 24")
			sert.eq(c.sh.env.game:GetService("StarterPlayer").CharacterWalkSpeed, 24)
			runSrv(";slopeangle TargetPlr 60")
			sert.eq(srvP2.Character.Humanoid.MaxSlopeAngle, 60)
			runSrv(";starterslopeangle 60")
			sert.eq(c.sh.env.game:GetService("StarterPlayer").CharacterMaxSlopeAngle, 60)

			-- VehicleSpeed / VehicleTorque with a VehicleSeat
			local vSeat = c.sh.env.Instance.new("VehicleSeat", srvP2.Character)
			srvP2.Character.Humanoid._props.SeatPart = vSeat
			runSrv(";vehiclespeed TargetPlr 100")
			sert.eq(vSeat.MaxSpeed, 100)
			runSrv(";vehicletorque TargetPlr 50")
			sert.eq(vSeat.Torque, 50)

			-- Collide / nocollide
			srvP2.Character.HumanoidRootPart.CollisionGroup = "Default"
			runSrv(";nocollide TargetPlr")
			sert.eq(srvP2.Character.HumanoidRootPart.CollisionGroup, "_KNoCollide")
			runSrv(";collide TargetPlr")
			sert.eq(srvP2.Character.HumanoidRootPart.CollisionGroup, "Default")

			-- Limbs & rig / respawn / refresh
			runSrv(";removearms TargetPlr")
			sert.eq(srvP2.Character:FindFirstChild("LeftUpperArm"), nil)
			buildCharacter(c.sh.env, srvP2)
			runSrv(";removelegs TargetPlr")
			sert.eq(srvP2.Character:FindFirstChild("LeftUpperLeg"), nil)
			buildCharacter(c.sh.env, srvP2)
			runSrv(";removelimbs TargetPlr")
			sert.eq(srvP2.Character:FindFirstChild("RightUpperArm"), nil)
			sert.eq(srvP2.Character:FindFirstChild("RightUpperLeg"), nil)
			buildCharacter(c.sh.env, srvP2)
			runSrv(";r6 TargetPlr")
			sert.ok(srvP2.Character)
			runSrv(";r15 TargetPlr")
			sert.ok(srvP2.Character)
			runSrv(";respawn TargetPlr")
			sert.ok(srvP2.Character)
			runSrv(";refresh TargetPlr")
			sert.ok(srvP2.Character)

			-- Marketplace & Group commands: buy, has, promptgroup (arg order: players, infoType, id)
			c.sh.env.marketplace.assets[2] = { [101] = true }
			c.sh.env.marketplace.gamePasses[2] = { [102] = true }
			c.sh.env.marketplace.bundles[2] = { [103] = true }
			c.sh.env.marketplace.subscriptions[2] = { ["EXP-104"] = true }
			runSrv(";buy TargetPlr Asset 101")
			runSrv(";buy TargetPlr GamePass 102")
			runSrv(";buy TargetPlr Product 105")
			runSrv(";buy TargetPlr Bundle 103")
			runSrv(";buy TargetPlr Subscription 104")
			runSrv(";has TargetPlr Asset 101")
			runSrv(";has TargetPlr GamePass 102")
			runSrv(";has TargetPlr Bundle 103")
			runSrv(";has TargetPlr Subscription 104")
			c.world:run(0.05)
			sert.ok(_K.Registry.commands.has.env.method[Enum.InfoType.Subscription])
			runSrv(";promptgroup TargetPlr 100")

			-- Leaderstats: change & resetstats
			runSrv(";change TargetPlr Coins 999")
			sert.eq(coins.Value, 999)
			runSrv(";change TargetPlr Status Ready")
			sert.eq(statusStat.Value, "Ready")
			runSrv(";change TargetPlr Active true")
			sert.eq(activeStat.Value, true)
			runSrv(";resetstats TargetPlr")
			sert.eq(coins.Value, 0)

			-- Teams: createteam, editteam, team, substitute, randomizeteams, teamrespawn, removeteam, clearteams
			runSrv(";createteam Red 255,0,0")
			c.world:run(61)
			runSrv(";createteam Blue 0,0,255")
			local teams = c.sh.env.game:GetService("Teams")
			local redTeam = teams:FindFirstChild("Red")
			local blueTeam = teams:FindFirstChild("Blue")
			sert.ok(redTeam)
			sert.ok(blueTeam)
			c.world:run(61)
			runSrv(";editteam Red Crimson 200,0,0")
			sert.eq(redTeam.Name, "Crimson")
			runSrv(";team CreatorPlr Crimson")
			runSrv(";team TargetPlr Blue")
			sert.eq(srvP1.Team, redTeam)
			sert.eq(srvP2.Team, blueTeam)
			runSrv(";substitute CreatorPlr TargetPlr")
			sert.eq(srvP1.Team, blueTeam)
			sert.eq(srvP2.Team, redTeam)
			runSrv(";randomizeteams all Crimson Blue")
			sert.eq(srvP1.Team ~= nil or srvP2.Team ~= nil, true)
			runSrv(";teamrespawn Blue")
			runSrv(";removeteam Crimson")
			sert.eq(teams:FindFirstChild("Crimson"), nil)
			runSrv(";clearteams")
			sert.eq(#teams:GetChildren(), 0)

			-- Ban / unban / kick / crash (server run)
			runSrv(";crash TargetPlr")
			runSrv(";ban TargetPlr 10m Griefing")
			sert.ok(_K.Data.bans["2"])
			runSrv(";unban 2")
			sert.eq(_K.Data.bans["2"], nil)
			runSrv(";kick TargetPlr Bye")
			sert.eq(srvP2._props._kicked, "Bye")
		end
	)

	test("executes all VIP and Fun commands including R6/R15 rigs, effects, accessories, and undo aliases", function()
		local c = createSimCluster()
		local _K, srvP1, srvP2 = c._K, c.srvP1, c.srvP2
		local runSrv, runCli = c.runSrv, c.runCli

		-- Configure marketplace AssetTypeIds for VIP commands (hat=8, head=17, face=18, shirt=11, pants=12, tshirt=2)
		c.sh.env.marketplace.products[800] = { AssetId = 800, AssetTypeId = 8, Name = "Hat" }
		c.sh.env.marketplace.products[1700] = { AssetId = 1700, AssetTypeId = 17, Name = "Head" }
		c.sh.env.marketplace.products[1800] = { AssetId = 1800, AssetTypeId = 18, Name = "Face" }
		c.sh.env.marketplace.products[1100] = { AssetId = 1100, AssetTypeId = 11, Name = "Shirt" }
		c.sh.env.marketplace.products[1200] = { AssetId = 1200, AssetTypeId = 12, Name = "Pants" }
		c.sh.env.marketplace.products[200] = { AssetId = 200, AssetTypeId = 2, Name = "TShirt" }

		-- === VIP.luau ===
		runSrv(";fire TargetPlr 5 255,0,0 255,128,0")
		sert.ok((srvP2.Character.HumanoidRootPart:FindFirstChild("_KFire")))
		runSrv(";unfire TargetPlr")
		sert.eq(srvP2.Character.HumanoidRootPart:FindFirstChild("_KFire"), nil)

		runSrv(";smoke TargetPlr 255,255,255")
		sert.ok((srvP2.Character.HumanoidRootPart:FindFirstChild("_KSmoke")))
		runSrv(";unsmoke TargetPlr")
		sert.eq(srvP2.Character.HumanoidRootPart:FindFirstChild("_KSmoke"), nil)

		runSrv(";sparkles TargetPlr 0,255,255")
		sert.ok((srvP2.Character.HumanoidRootPart:FindFirstChild("_KSparkles")))
		runSrv(";unsparkles TargetPlr")
		sert.eq(srvP2.Character.HumanoidRootPart:FindFirstChild("_KSparkles"), nil)

		runSrv(";light TargetPlr 10 255,255,0")
		sert.ok((srvP2.Character.HumanoidRootPart:FindFirstChild("_KLight")))
		runSrv(";unlight TargetPlr")
		sert.eq(srvP2.Character.HumanoidRootPart:FindFirstChild("_KLight"), nil)

		runSrv(";highlight TargetPlr 255,0,0 255,255,255 0.5 0")
		sert.ok((srvP2.Character:FindFirstChild("_KHighlight")))
		runSrv(";unhighlight TargetPlr")
		sert.eq(srvP2.Character:FindFirstChild("_KHighlight"), nil)

		runSrv(";particle TargetPlr 12345 255,0,0")
		sert.ok((srvP2.Character.HumanoidRootPart:FindFirstChild("_KParticleEffect")))
		_K.Remote.DonorTrail:Fire(srvP1, true)
		_K.Remote.DonorTrail:Fire(srvP1, false)
		runSrv(";unparticle TargetPlr")
		sert.eq(srvP2.Character.HumanoidRootPart:FindFirstChild("_KParticleEffect"), nil)

		runSrv(";trail TargetPlr 255,0,0")
		sert.ok((srvP2.Character.Torso:FindFirstChild("_KTrailEffect")))
		runSrv(";untrail TargetPlr")
		sert.eq(srvP2.Character.Torso:FindFirstChild("_KTrailEffect"), nil)

		runSrv(";shine TargetPlr")
		sert.ok((srvP2.Character.HumanoidRootPart:FindFirstChild("_KShineEffect")))
		runSrv(";unshine TargetPlr")
		sert.eq(srvP2.Character.HumanoidRootPart:FindFirstChild("_KShineEffect"), nil)

		runSrv(";cape TargetPlr 255,0,0 0.5 Neon 12345")
		sert.ok((srvP2.Character:FindFirstChild("_KCape")))
		c.sh.env.game:GetService("RunService").Heartbeat:Fire(0.016)
		runSrv(";uncape TargetPlr")
		sert.eq(srvP2.Character:FindFirstChild("_KCape"), nil)

		runSrv(";hat TargetPlr 800 12345 255,0,0 0.5 Neon")
		sert.ok((srvP2.Character:FindFirstChild("_KHat800")))
		-- Calling hat again replaces existing _KHat800
		runSrv(";hat TargetPlr 800")
		sert.ok((srvP2.Character:FindFirstChild("_KHat800")))
		runSrv(";removehats TargetPlr")
		sert.eq(srvP2.Character:FindFirstChild("_KHat800"), nil)

		runSrv(";head TargetPlr 1700")
		sert.eq(srvP2.Character.Humanoid._props._description.Head, 1700)
		runSrv(";unhead TargetPlr")
		sert.eq(srvP2.Character.Humanoid._props._description.Head, 0)
		runSrv(";headsize TargetPlr 2")
		sert.eq(srvP2.Character.Humanoid:FindFirstChild("HeadScale").Value, 2)
		runSrv(";bighead TargetPlr")
		sert.eq(srvP2.Character.Humanoid:FindFirstChild("HeadScale").Value > 1, true)
		runSrv(";smallhead TargetPlr")
		sert.eq(srvP2.Character.Humanoid:FindFirstChild("HeadScale").Value < 1, true)
		runSrv(";normalhead TargetPlr")
		sert.eq(srvP2.Character.Humanoid:FindFirstChild("HeadScale").Value, 1)

		-- Also test R6 headsize & normalhead branch
		srvP2.Character.Humanoid.RigType = Enum.HumanoidRigType.R6
		runSrv(";headsize TargetPlr 2")
		sert.eq(srvP2.Character.Head.Mesh.Scale, Vector3.new(2, 2, 2))
		runSrv(";normalhead TargetPlr")
		sert.eq(srvP2.Character.Head.Mesh.Scale, Vector3.one)
		srvP2.Character.Humanoid.RigType = Enum.HumanoidRigType.R15

		runSrv(";face TargetPlr 1800")
		sert.eq(string.find(srvP2.Character.Head.face.Texture, "1800", 1, true) ~= nil, true)
		runSrv(";unface TargetPlr")
		sert.eq(srvP2.Character.Head.face.Texture, "rbxasset://textures/face.png")
		runSrv(";shirt TargetPlr 1100")
		sert.eq(string.find(srvP2.Character:FindFirstChildOfClass("Shirt").ShirtTemplate, "1100", 1, true) ~= nil, true)
		runSrv(";unshirt TargetPlr")
		sert.eq(srvP2.Character:FindFirstChildOfClass("Shirt").ShirtTemplate, "")
		runSrv(";pants TargetPlr 1200")
		sert.eq(string.find(srvP2.Character:FindFirstChildOfClass("Pants").PantsTemplate, "1200", 1, true) ~= nil, true)
		runSrv(";unpants TargetPlr")
		sert.eq(srvP2.Character:FindFirstChildOfClass("Pants").PantsTemplate, "")
		runSrv(";tshirt TargetPlr 200")
		sert.eq(string.find(srvP2.Character:FindFirstChildOfClass("ShirtGraphic").Graphic, "200", 1, true) ~= nil, true)
		runSrv(";untshirt TargetPlr")
		sert.eq(srvP2.Character:FindFirstChildOfClass("ShirtGraphic").Graphic, "")
		runSrv(";bodycolor TargetPlr 255,200,150")
		sert.eq(srvP2.Character.BodyColors.HeadColor3, Color3.fromRGB(255, 200, 150))
		runSrv(";unbodycolor TargetPlr")

		runSrv(";crm TargetPlr 255,0,0 0.5 Neon")
		sert.eq(srvP2.Character.Head.Material, Enum.Material.Neon)
		runSrv(";uncrm TargetPlr")
		sert.eq(srvP2.Character.Head.Reflectance, 0)
		runSrv(";goldify TargetPlr")
		sert.eq(srvP2.Character.Head.Material, Enum.Material.Metal)
		runSrv(";shiny TargetPlr")
		sert.eq(srvP2.Character.Head.Reflectance, 1)
		runSrv(";silverify TargetPlr")
		sert.eq(srvP2.Character.Head.Material, Enum.Material.Metal)
		runSrv(";ungoldify TargetPlr")
		sert.eq(srvP2.Character.Head.Reflectance, 0)
		runSrv(";swagify TargetPlr")
		sert.ok((srvP2.Character:FindFirstChild("_KCape")))
		runSrv(";unswagify TargetPlr")
		sert.eq(srvP2.Character:FindFirstChild("_KCape"), nil)

		runSrv(";bundle TargetPlr 101")
		sert.ok((srvP2:FindFirstChild("_KHumanoidDescription")))
		runSrv(";unbundle TargetPlr")
		runSrv(";headless TargetPlr")
		sert.eq(srvP2.Character.Humanoid._props._description.Head, 15093053680)
		runSrv(";korblox TargetPlr")
		runSrv(";werewolf TargetPlr")
		runSrv(";vampire TargetPlr")

		-- Wings & Crown VIP commands with _KAlphaWings and SuperCrown instances
		srvP1:SetAttribute("_KDonationLevel", 4)
		c.ch1.env.Players.LocalPlayer:SetAttribute("_KDonationLevel", 4)
		local wings = c.sh.env.Instance.new("Accessory", srvP1.Character)
		wings.Name = "_KAlphaWings"
		local wingsPart = c.sh.env.Instance.new("Part", wings)
		wingsPart.Name = "Wings"
		local crown = c.sh.env.Instance.new("Accessory", srvP1.Character)
		crown.Name = "SuperCrown"
		local crownHandle = c.sh.env.Instance.new("Part", crown)
		crownHandle.Name = "Handle"
		c.sh.env.Instance.new("Fire", crownHandle).Name = "Fire"

		runCli(";wingscolor 255,0,0")
		runSrv(";wingscolor 255,0,0")
		c.world:run(0.05)
		sert.eq(wingsPart.Color, Color3.fromRGB(255, 0, 0))
		runCli(";rainbowwings")
		runSrv(";rainbowwings")
		sert.eq(wings:HasTag("_KAlphaWingsRainbow"), true)
		runCli(";crowncolor 255,215,0 0,0,0")
		runSrv(";crowncolor 255,215,0 0,0,0")
		c.world:run(0.05)
		sert.eq(crownHandle.Color, Color3.fromRGB(255, 215, 0))
		runCli(";rainbowcrown")
		runSrv(";rainbowcrown")
		sert.eq(crown:HasTag("_KSuperCrownRainbow"), true)

		-- === Fun.luau ===
		local lighting = c.sh.env.game:GetService("Lighting")
		runSrv(";disco")
		sert.ok(_K.Registry.commands.disco.env.id)
		runSrv(";undisco")
		sert.eq(_K.Registry.commands.disco.env.id, false)
		sert.ok(lighting.Ambient)

		for _, rigType in { Enum.HumanoidRigType.R15, Enum.HumanoidRigType.R6 } do
			buildCharacter(c.sh.env, srvP2, rigType)
			runSrv(";creeper TargetPlr")
			sert.ok((srvP2.Character:GetAttribute("_KCreeper")))
			runSrv(";uncreeper TargetPlr")
			sert.eq(srvP2.Character:GetAttribute("_KCreeper"), nil)
			runSrv(";dog TargetPlr")
			sert.ok((srvP2.Character:FindFirstChild("_KDogSeat")))
			runSrv(";undog TargetPlr")
			sert.eq(srvP2.Character:FindFirstChild("_KDogSeat"), nil)
		end

		buildCharacter(c.sh.env, srvP2, Enum.HumanoidRigType.R15)
		runSrv(";char TargetPlr 1")
		sert.eq(srvP2.CharacterAppearanceId, 1)
		runSrv(";unchar TargetPlr")
		sert.eq(srvP2.CharacterAppearanceId, 2)
		runSrv(";clone TargetPlr")
		sert.eq(#_K.cleanupCommands >= 1, true)

		runSrv(";jumpscare TargetPlr")
		runSrv(";jumpscare TargetPlr 1119705746 999999")
		runSrv(";jumpscare TargetPlr 1119705746 999999")
		sert.eq(
			_K.Registry.commands.play.run(
				{ _K = _K, env = _K.Registry.commands.play.env, from = 1, fromPlayer = srvP1 },
				10764744805
			),
			"Invalid audio asset."
		)
		sert.eq(
			_K.Registry.commands.play.run(
				{ _K = _K, env = _K.Registry.commands.play.env, from = 1, fromPlayer = srvP1 },
				10764744805
			),
			"Invalid audio asset."
		)
		sert.eq(
			_K.Registry.commands.jumpscare.run(
				{ _K = _K, env = _K.Registry.commands.jumpscare.env, from = 1, fromPlayer = srvP1 },
				{ srvP2 },
				nil,
				10764744805
			),
			"Invalid audio asset."
		)
		_K.Remote.Jumpscare:Fire(srvP1)
		c.world:run(0.05)

		runSrv(";glitch CreatorPlr 2")
		c.world:run(0.05)
		c.ch1.env.game:GetService("RunService").PreRender:Fire(0.016)
		runSrv(";unglitch CreatorPlr")
		c.world:run(0.05)

		local seizeThread = c.sh.env.task.spawn(function()
			runSrv(";seizure TargetPlr")
		end)
		c.world:run(0.05)
		sert.eq(srvP2.Character:GetAttribute("_KSeizure"), true)
		runSrv(";unseizure TargetPlr")
		sert.eq(srvP2.Character:GetAttribute("_KSeizure"), nil)
		c.sh.env.task.cancel(seizeThread)

		runSrv(";infect TargetPlr")
		sert.ok(_K.Registry.commands.infect.env.infected[srvP2.Character])
		-- Touching another character's HumanoidRootPart spreads infection
		srvP2.Character.Humanoid.Touched:Fire(srvP1.Character.HumanoidRootPart)
		sert.ok(_K.Registry.commands.infect.env.infected[srvP1.Character])
		runSrv(";normal TargetPlr")
		runSrv(";normal CreatorPlr")

		buildCharacter(c.sh.env, srvP1)
		buildCharacter(c.sh.env, srvP2)
		runSrv(";confuse CreatorPlr")
		c.world:run(0.05)
		runSrv(";unconfuse CreatorPlr")
		c.world:run(0.05)

		runSrv(";fling TargetPlr")
		sert.eq(srvP2.Character.HumanoidRootPart.AssemblyLinearVelocity.Magnitude > 0, true)
		runSrv(";loopfling TargetPlr")
		sert.eq(_K.Registry.commands.loopfling.env.flinging[srvP2.UserId], 1)
		c.world:run(0.05)
		runSrv(";unloopfling TargetPlr")
		sert.eq(_K.Registry.commands.loopfling.env.flinging[srvP2.UserId], nil)

		local poisonThread = c.sh.env.task.spawn(function()
			runSrv(";poison TargetPlr 10 1")
		end)
		c.world:run(0.9)
		c.sh.env.task.cancel(poisonThread)
		sert.eq(srvP2.Character.Humanoid.Health < 100, true)

		runSrv(";spin TargetPlr 1")
		sert.ok((srvP2.Character:FindFirstChild("_KSpin")))
		runSrv(";unspin TargetPlr")
		sert.eq(srvP2.Character:FindFirstChild("_KSpin"), nil)

		runSrv(";setgravity TargetPlr 0.5")
		sert.ok((srvP2.Character:FindFirstChild("_KGravityForce")))
		runSrv(";nograv TargetPlr")
		sert.ok((srvP2.Character:FindFirstChild("_KGravityForce")))
		runSrv(";ungravity TargetPlr")
		sert.eq(srvP2.Character:FindFirstChild("_KGravityForce"), nil)

		runSrv(";skydive TargetPlr 500")
		sert.eq(srvP2.Character:GetPivot().Position.Y > 100, true)
		runSrv(";trip CreatorPlr")
		c.world:run(0.05)
		sert.eq(c.ch1.env.Players.LocalPlayer.Character.Humanoid:GetState(), Enum.HumanoidStateType.FallingDown)
		runSrv(";size TargetPlr 1.5")
		sert.eq(srvP2.Character:GetScale(), 1.5)
		runSrv(";unsize TargetPlr 1")
		sert.eq(srvP2.Character:GetScale(), 1)

		runSrv(";slim TargetPlr")
		sert.eq(srvP2.Character.Humanoid:GetAttribute("_KSlim"), true)
		runSrv(";unslim TargetPlr")
		sert.eq(srvP2.Character.Humanoid:GetAttribute("_KSlim"), false)
		runSrv(";noobify TargetPlr")
		c.world:run(0.05)
		sert.ok((srvP2:FindFirstChild("_KHumanoidDescription")))

		-- Run slippery on CreatorPlr so both server command and client Slippery remote run on ch1
		runSrv(";slippery CreatorPlr")
		c.world:run(0.05)
		sert.ok((srvP1.Character.HumanoidRootPart:FindFirstChild("_K_Slippery")))
		_K.Registry.commands.slippery.run({ _K = _K, env = _K.Registry.commands.slippery.env, undo = true }, { srvP1 })
		_K.Remote.Slippery:Fire(srvP1, nil)
		c.world:run(0.05)
		sert.eq(srvP1.Character.HumanoidRootPart:FindFirstChild("_K_Slippery"), nil)

		local smiteThread = c.sh.env.task.spawn(function()
			runSrv(";smite TargetPlr")
		end)
		c.world:run(0.3)
		c.sh.env.task.cancel(smiteThread)
		buildCharacter(c.sh.env, srvP2)

		runSrv(";explode TargetPlr")
		sert.eq(srvP2.Character.Humanoid.Health, 0)
		buildCharacter(c.sh.env, srvP2)

		local rocketThread = c.sh.env.task.spawn(function()
			runSrv(";rocket TargetPlr")
		end)
		c.world:run(0.05)
		sert.ok((srvP2.Character:FindFirstChild("_KRocket")))
		c.sh.env.task.cancel(rocketThread)

		local nukeThread = c.sh.env.task.spawn(function()
			runSrv(";nuke TargetPlr")
		end)
		c.world:run(0.05)
		c.sh.env.task.cancel(nukeThread)

		buildCharacter(c.sh.env, srvP2)
		runSrv(";control TargetPlr")
		sert.eq(srvP1.Character, srvP2.Character)
		buildCharacter(c.sh.env, srvP1)
		buildCharacter(c.sh.env, srvP2)
	end)

	test(
		"loads DefaultAddons/Legacy.luau, migrates legacy settings and custom commands, and runs legacy role aliases",
		function()
			local c = createSimCluster(nil, true)
			local _K = c._K
			_K.setupPurchasables = function() end

			-- Stage a Config/Legacy hierarchy under sh.Shared to exercise full Legacy migration
			local configFolder = c.sh.env.Instance.new("Folder", c.sh.Shared)
			configFolder.Name = "Config"
			local legacyFolder = c.sh.env.Instance.new("Folder", configFolder)
			legacyFolder.Name = "Legacy"

			local settingsMod = c.sh.env.Instance.new("ModuleScript", legacyFolder)
			settingsMod.Name = "Settings"
			rawset(settingsMod, "_factory", function()
				return {
					{
						Prefix = ":",
						AdminCredit = false,
						CommandBar = false,
						JoinMessage = false,
						PublicLogs = true,
						FreeAdmin = 1,
						Permissions = {
							fly = 2,
						},
						GroupAdmin = {
							[100] = { [255] = 4 },
						},
						VIPAdmin = {
							[101] = 1,
							[-102] = 1,
						},
					},
					{
						{ "LegacyOwner", 500 },
						{ 400 },
						{ 300 },
						{ 200 },
						{ 100 },
						{ 50 },
					},
				}
			end)

			local customCmdsMod = c.sh.env.Instance.new("ModuleScript", legacyFolder)
			customCmdsMod.Name = "Custom_Commands"
			local customRan = false
			rawset(customCmdsMod, "_factory", function()
				return {
					{
						{ "legacyhello", "lhello" },
						{ "Test legacy custom command" },
						1,
						{ "player", "string/" },
						function(_fromPlr, _args)
							customRan = true
						end,
					},
				}
			end)

			local legacyAddon = c.sh.Shared.DefaultAddons:FindFirstChild("Legacy")
			c.sh.env:require(legacyAddon)(_K)
			c.world:run(0.3)

			-- Verify legacy settings migration
			sert.eq(_K.Data.defaultSettings.prefix[1], ":")
			sert.eq(_K.Auth.hasRole(500, "creator"), true)
			sert.eq(_K.Auth.hasRole(400, "superadmin"), true)
			sert.eq(_K.Auth.hasRole(300, "admin"), true)
			sert.eq(_K.Auth.hasRole(200, "mod"), true)
			sert.eq(_K.Auth.hasRole(100, "vip"), true)
			sert.ok(_K.Data.bans["50"])

			-- Verify legacy custom command registration & execution
			sert.ok(_K.Registry.commands.legacyhello)
			c.runSrv(";legacyhello TargetPlr Greetings")
			sert.eq(customRan, true)

			-- Verify legacy role commands (creator, superadmin, admin, mod, vip + temp* + un*)
			local legacyNotifies: { any } = {}
			local origLegacyNotify = _K.Remote.Notify.Fire
			_K.Remote.Notify.Fire = function(self: any, plr: any, msg: any)
				table.insert(legacyNotifies, { plr = plr, msg = msg })
				return origLegacyNotify(self, plr, msg)
			end
			for _, roleId in { "creator", "superadmin", "admin", "mod", "vip" } do
				table.clear(legacyNotifies)
				c.runSrv(`;temp{roleId} TargetPlr`)
				sert.eq(_K.Auth.hasRole(2, roleId), true)
				sert.eq(#legacyNotifies >= 1, true)
				table.clear(legacyNotifies)
				c.runSrv(`;un{roleId} TargetPlr`)
				sert.eq(_K.Auth.hasRole(2, roleId), false)
				sert.eq(#legacyNotifies >= 1, true)
				sert.eq(string.find(legacyNotifies[1].msg.Text, "TargetPlr", 1, true) ~= nil, true)
				-- Running un<role> when member does not have that role sends no notification
				table.clear(legacyNotifies)
				_K.Registry.commands["un" .. roleId].run({ _K = _K, from = 1, fromPlayer = c.srvP1 }, { "2" })
				sert.eq(#legacyNotifies, 0)
				c.runSrv(`;{roleId} TargetPlr`)
				sert.eq(_K.Auth.hasRole(2, roleId), true)
				c.runSrv(`;un{roleId} TargetPlr`)
				sert.eq(_K.Auth.hasRole(2, roleId), false)
			end
			-- Also test giving role to an offline userId so `if not player then continue` is verified
			table.clear(legacyNotifies)
			c.runSrv(";vip 777777")
			c.world:run(0.25)
			sert.eq(_K.Auth.hasRole(777777, "vip"), true)
			sert.eq(#legacyNotifies, 1)
			sert.eq(legacyNotifies[1].plr, c.srvP1)
		end
	)

	test("legacy role commands give unrestricted, unsaved roles unless the giver is a developer", function()
		local c = createSimCluster(nil, true)
		local _K = c._K
		_K.setupPurchasables = function() end
		c.sh.env:require(c.sh.Shared.DefaultAddons:FindFirstChild("Legacy"))(_K)
		c.world:run(0.3)

		local function runAs(from: number, raw: string)
			c.sh.env.task.spawn(function()
				_K.Process.runCommands(_K, from, raw)
			end)
			c.world:run(0.3)
		end

		-- TargetPlr bought Administrator, so it has banasync but no developer powers (timed bans)
		_K.Data.roles.admin.gamepasses = { 123 }
		_K.Data.roles.superadmin.gamepasses = { 124 }
		_K.Auth.userRoleAdd(2, "admin")
		sert.eq(_K.Auth.hasRestrictedRole(2), false)

		-- giving itself a lower role doesn't make it a developer
		runAs(2, ";tempmod me")
		local member = _K.Data.members["2"]
		sert.eq(table.find(member.roles, "mod") ~= nil, true)
		sert.eq(member.unrestricted and member.unrestricted.mod, true)
		sert.eq(_K.Auth.hasRestrictedRole(2), false)

		-- a bought SuperAdmin has saveRoles, but its ;mod only lasts the session
		_K.Auth.userRoleAdd(2, "superadmin")
		runAs(2, ";mod 777001")
		local given = _K.Data.members["777001"]
		sert.eq(table.find(given.roles, "mod") ~= nil, true)
		sert.eq(table.find(given.persist, "mod"), nil)
		sert.eq(given.unrestricted and given.unrestricted.mod, true)

		-- the developer still saves restricted roles
		runAs(1, ";mod 777002")
		local saved = _K.Data.members["777002"]
		sert.eq(table.find(saved.persist, "mod") ~= nil, true)
		sert.eq(saved.unrestricted, nil)
	end)

	test("a moderator's ;ban can't turn a saved ban into a server ban", function()
		local c = createSimCluster(nil, true)
		local _K = c._K
		_K.Auth.userRoleAdd(2, "mod")
		_K.Data.bans["777003"] = { "SavedBan", "Exploiting", -1, 1 }

		local notices = {}
		local origNotifyFire = _K.Remote.Notify.Fire
		_K.Remote.Notify.Fire = function(self: any, plr: any, msg: any)
			table.insert(notices, msg.Text)
			return origNotifyFire(self, plr, msg)
		end

		c.server:client(3, "OnlinePlr")
		c.world:run(0.1)
		local online = c.sh.env.Players:GetPlayerByUserId(3)
		online:SetAttribute("_KRolesLoaded", true)

		c.sh.env.task.spawn(function()
			_K.Process.runCommands(_K, 2, ";ban 777003,777004,3")
		end)
		c.world:run(0.3)
		sert.eq(_K.Data.bans["777003"][2], "Exploiting")
		sert.eq(_K.Data.bans["777003"][3], -1)
		sert.eq(_K.Data.bans["777004"] ~= nil, true)
		sert.eq(_K.Data.bans["3"] ~= nil, true)
		local kickedOnline = false
		for _, entry in c.server.kicks do
			if entry.player == online or entry.userId == online.UserId then
				kickedOnline = true
				break
			end
		end
		sert.eq(kickedOnline, true)

		-- the kept saved ban is reported apart from the new server bans
		local saved = _K.Util.getUserInfo(777003).Username
		local fresh = _K.Util.getUserInfo(777004).Username
		sert.eq(notices, {
			`Banned <b>{fresh}, {online.Name}</b> for <b>no reason</b>.\nDuration: <b>Server</b>\nKept saved ban for <b>{saved}</b>.`,
		})

		-- only kept saved bans: no "Banned" line
		table.clear(notices)
		c.sh.env.task.spawn(function()
			_K.Process.runCommands(_K, 2, ";ban 777003")
		end)
		c.world:run(0.3)
		sert.eq(notices, { `Kept saved ban for <b>{saved}</b>.` })
		_K.Remote.Notify.Fire = origNotifyFire
	end)

	test(";unban doesn't look up offline ranks, ;ban still does", function()
		local c = createSimCluster(nil, true)
		local _K = c._K
		_K.Auth.userRoleAdd(2, "mod")
		c.srvP2:SetAttribute("_KRolesLoaded", true)

		local gMethods = rawget(c.sh.env.game:GetService("GroupService"), "_methods")
		local mMethods = rawget(c.sh.env.game:GetService("MarketplaceService"), "_methods")
		local origGetGroups, origOwnsPass = gMethods.GetGroupsAsync, mMethods.UserOwnsGamePassAsync
		local webCalls = 0
		gMethods.GetGroupsAsync = function(...)
			webCalls += 1
			return origGetGroups(...)
		end
		mMethods.UserOwnsGamePassAsync = function(...)
			webCalls += 1
			return origOwnsPass(...)
		end
		-- every offline target is a group SuperAdmin
		_K.Data.async.group[5100] = { { rank = 200, roles = { "superadmin" } } }
		c.sh.env.groups[5100] = {
			ranks = { [777010] = 250, [777011] = 250, [777012] = 250, [777013] = 250 },
			Roles = {},
		}
		_K.Data.async.gamepass[558] = { "admin" }
		for _, userId in { "777010", "777011", "777012" } do
			_K.Data.bans[userId] = { `Banned{userId}`, "Exploiting", 0, 1 }
		end

		local function run(raw)
			c.sh.env.task.spawn(function()
				_K.Process.runCommands(_K, 2, raw)
			end)
			c.world:run(0.3)
		end

		run(";unban 777010")
		sert.eq(_K.Data.bans["777010"], nil)
		run(";unban all")
		sert.eq(_K.Data.bans["777011"], nil)
		sert.eq(_K.Data.bans["777012"], nil)
		sert.eq(webCalls, 0)

		run(";ban 777013")
		sert.eq(_K.Data.bans["777013"], nil)
		sert.eq(webCalls > 0, true)

		gMethods.GetGroupsAsync, mMethods.UserOwnsGamePassAsync = origGetGroups, origOwnsPass
	end)

	describe("Process · SuperAdmin ;global", function()
		test(";global doesn't publish the raw token of a skipped optional argument", function()
			local c = createSimCluster(nil, true)
			local _K = c._K
			_K.Util.String.filterForBroadcast = function()
				return "Filtered"
			end
			local published = {}
			c._K.Data.subscribeTopic("global", function(message)
				table.insert(published, message.Data[2])
			end)

			-- "Raw" isn't a delay, so the reason takes it again and only the reason is filtered
			c.runSrv(';global shutdown "Raw" text')
			c.world:run(0.1)
			sert.eq(published[1], ';shutdown "Filtered"')
			sert.eq(string.find(tostring(c.srvP2._props._kicked), "Raw", 1, true), nil)
			sert.eq(string.find(tostring(c.srvP2._props._kicked), "Reason: Filtered", 1, true) ~= nil, true)

			-- an optional argument that took its token is still published
			c.world:run(61)
			c.runSrv(";global shutdown 0 text")
			c.world:run(0.1)
			sert.eq(published[2], ';shutdown 0 "Filtered"')
		end)

		test(";global always quotes text so receiving servers can't read commands out of it", function()
			local c = createSimCluster(nil, true)
			local _K = c._K
			local filterResult
			_K.Util.String.filterForBroadcast = function(text)
				return filterResult or text
			end
			local published = {}
			c._K.Data.subscribeTopic("global", function(message)
				table.insert(published, message.Data[2])
			end)
			local received, voted = {}, false
			_K.Registry.commands.message.run = function(_context, message)
				table.insert(received, message)
			end
			_K.Registry.commands.vote.run = function()
				voted = true
			end
			local function runGlobal(commandString: string)
				c.world:run(61) -- past the broadcast cooldown
				c.runSrv(commandString)
				c.world:run(0.5)
			end

			-- the last text argument of a single command used to be published unquoted and ran as two commands
			runGlobal(';global m "x ;vote all question"')
			sert.eq(published[1], ';m "x ;vote all question"')
			sert.eq(received, { "x ;vote all question" })
			sert.eq(voted, false)

			-- text holding a double quote takes backticks, quotes have no escapes
			runGlobal(';global `m "say ;vote all" now`')
			sert.eq(published[2], ';m `say ;vote all" now`')
			sert.eq(received[2], 'say ;vote all" now')

			-- text holding both quotes keeps the double quotes and loses the backticks
			filterResult = 'a "b" `c` ;vote all q'
			runGlobal(";global m text")
			sert.eq(published[3], ";m `a \"b\" 'c' ;vote all q`")
			sert.eq(received[3], "a \"b\" 'c' ;vote all q")
			sert.eq(voted, false)
			filterResult = nil

			-- commands without text are published as before
			runGlobal(";global gravity 80")
			sert.eq(published[4], ";gravity 80")
			sert.eq(c.sh.env.workspace.Gravity, 80)
		end)

		test(";global text arguments of every text type reach receiving servers without their quotes", function()
			local c = createSimCluster(nil, true)
			local _K = c._K
			_K.Util.String.filterForBroadcast = function(text)
				return text
			end
			local published = {}
			c._K.Data.subscribeTopic("global", function(message)
				table.insert(published, message.Data[2])
			end)
			local received = {}
			for _, argType in { "string", "strings", "chatString", "stringGreedy" } do
				_K.Registry.registerCommand(_K, {
					name = "global" .. argType,
					description = "Records its text",
					group = "superadmin",
					args = { { type = argType, name = "Text", description = "The text." } },
					run = function(_context, text)
						received[argType] = text
					end,
				})
			end
			c.world:run(0.1)

			for i, argType in { "string", "strings", "chatString", "stringGreedy" } do
				c.world:run(61)
				c.runSrv(`;global global{argType} "x ;vote all q"`)
				c.world:run(0.5)
				sert.eq(published[i], `;global{string.lower(argType)} "x ;vote all q"`)
			end
			sert.eq(received, {
				string = "x ;vote all q",
				strings = { "x ;vote all q" },
				chatString = "x ;vote all q",
				stringGreedy = "x ;vote all q",
			})

			-- a list is quoted per item so receivers get the same items, text that isn't a list keeps its commas
			c.world:run(61)
			c.runSrv(';global globalstrings a,"b, ;vote all q",c')
			c.world:run(0.5)
			sert.eq(published[5], ';globalstrings "a","b, ;vote all q","c"')
			sert.eq(received.strings, { "a", "b, ;vote all q", "c" })
			c.world:run(61)
			c.runSrv(";global globalstring a,b")
			c.world:run(0.5)
			sert.eq(published[6], ';globalstring "a,b"')
			sert.eq(received.string, "a,b")
		end)

		test(";global change publishes the leaderstat value quoted and receivers still apply it", function()
			local c = createSimCluster(nil, true)
			local _K = c._K
			_K.Util.String.filterForBroadcast = function(text)
				return text
			end
			local published = {}
			c._K.Data.subscribeTopic("global", function(message)
				table.insert(published, message.Data[2])
			end)
			local leaderstats = c.sh.env.Instance.new("Folder", c.srvP2)
			leaderstats.Name = "leaderstats"
			local coins = c.sh.env.Instance.new("IntValue", leaderstats)
			coins.Name = "Coins"

			c.runSrv(";global change TargetPlr Coins 5")
			c.world:run(0.5)
			sert.eq(published[1], ';change TargetPlr Coins "5"')
			sert.eq(coins.Value, 5)
		end)

		test(";global receivers only parse the server prefix, not the sender's own prefix inside the text", function()
			local c = createSimCluster(nil, true)
			local _K = c._K
			_K.Util.String.filterForBroadcast = function(text)
				return text
			end
			local published = {}
			c._K.Data.subscribeTopic("global", function(message)
				table.insert(published, message.Data[2])
			end)
			local received = {}
			_K.Registry.commands.message.run = function(_context, message)
				table.insert(received, message)
			end
			_K.Data.playerPrefix[1] = "!"
			local gravity = c.sh.env.workspace.Gravity

			c.runSrv('!global m "hello !gravity 33 !m z"')
			c.world:run(0.5)
			sert.eq(published[1], ';m "hello !gravity 33 !m z"')
			sert.eq(received, { "hello !gravity 33 !m z" })
			sert.eq(c.sh.env.workspace.Gravity, gravity)
		end)

		test(";global refuses command strings that receiving servers would parse differently", function()
			local c = createSimCluster(nil, true)
			local _K = c._K
			local filterResult
			_K.Util.String.filterForBroadcast = function(text)
				return filterResult or text
			end
			local published = {}
			c._K.Data.subscribeTopic("global", function(message)
				table.insert(published, message.Data[2])
			end)
			local gravity = c.sh.env.workspace.Gravity
			local notices = {}
			local origNotifyFire = _K.Remote.Notify.Fire
			_K.Remote.Notify.Fire = function(self, player, data)
				table.insert(notices, data.Text)
				return origNotifyFire(self, player, data)
			end

			-- the sender's prefix leaves ";gravity" as the time argument, receiving servers would split it off
			_K.Data.playerPrefix[1] = "!"
			c.runSrv("!global time ;gravity 33")
			c.world:run(0.5)
			sert.eq(#published, 0)
			sert.eq(c.sh.env.workspace.Gravity, gravity)
			sert.eq(
				string.find(tostring(notices[1]), "would parse this command string differently", 1, true) ~= nil,
				true
			)

			-- or opens a quote there that swallows the next command while keeping the command count
			local voted = false
			_K.Registry.commands.vote.run = function()
				voted = true
			end
			c.runSrv('!global `time ;" ;vote all q" !gravity 33`')
			c.world:run(0.5)
			sert.eq(#published, 0)
			sert.eq(voted, false)
			sert.eq(c.sh.env.workspace.Gravity, gravity)
			_K.Data.playerPrefix[1] = nil

			-- the same text parses back while graphemes keep the quote apart
			filterResult = '\u{301}x"q" ;gravity 33 ;m z'
			c.world:run(61)
			c.runSrv(";global m text")
			c.world:run(0.5)
			sert.eq(published[1], ';m `\u{301}x"q" ;gravity 33 ;m z`')
			sert.eq(c.sh.env.workspace.Gravity, gravity)
			_K.Remote.Notify.Fire = origNotifyFire

			-- in Roblox a combining mark after the opening quote joins its grapheme, so the quote isn't read as one
			c = createSimCluster({ utf8 = clusteringUtf8() }, true)
			filterResult = '\u{301}x"q" ;gravity 33 ;m z'
			c._K.Util.String.filterForBroadcast = function()
				return filterResult
			end
			table.clear(published)
			c._K.Data.subscribeTopic("global", function(message)
				table.insert(published, message.Data[2])
			end)
			c.runSrv(";global m text")
			c.world:run(0.5)
			sert.eq(c.sh.env.workspace.Gravity, gravity)
			sert.eq(#published, 0)

			-- or text that splits into the next argument without adding a command
			c._K.Registry.registerCommand(c._K, {
				name = "globalpair",
				description = "Records its text and number",
				group = "superadmin",
				args = {
					{ type = "string", name = "Text", description = "The text." },
					{ type = "number", name = "Number", description = "The number." },
				},
				run = function() end,
			})
			c.world:run(0.1)
			filterResult = '\u{301}x"q" 7'
			c.world:run(61)
			c.runSrv(';global globalpair "text" 5')
			c.world:run(0.5)
			sert.eq(#published, 0)

			-- or a list item whose opening quote joins its grapheme, so receivers split it at its comma
			c._K.Registry.registerCommand(c._K, {
				name = "globallist",
				description = "Records its items",
				group = "superadmin",
				args = { { type = "strings", name = "Items", description = "The items." } },
				run = function() end,
			})
			c.world:run(0.1)
			filterResult = "\u{301}a,b"
			c.world:run(61)
			c.runSrv(";global globallist text")
			c.world:run(0.5)
			sert.eq(#published, 0)
			-- text that isn't a list isn't split there
			c.world:run(61)
			c.runSrv(";global m text")
			c.world:run(0.5)
			sert.eq(published[1], ';m "\u{301}a,b"')
		end)

		test(";global keeps a skipped optional argument skipped when the text starts with its type", function()
			local c = createSimCluster(nil, true)
			local _K = c._K
			_K.Util.String.filterForBroadcast = function(text)
				return text
			end
			local published = {}
			c._K.Data.subscribeTopic("global", function(message)
				table.insert(published, message.Data[2])
			end)

			-- "3 strikes" isn't a duration, so receiving servers must not read its "3" as one
			c.runSrv(';global ban 777005 "3 strikes"')
			c.world:run(1)
			sert.eq(published[1], ';ban 777005 "3 strikes"')
			local ban = _K.Data.bans["777005"]
			sert.eq(ban ~= nil, true)
			sert.eq(ban[2], "3 strikes")
			sert.eq(ban[3], nil) -- a server ban, not a 3 second one

			-- nor find "5 days" in the quoted reason and ban for 5 days
			c.world:run(61) -- past the broadcast cooldown
			c.runSrv(";global ban 777006 appeal in 5 days")
			c.world:run(1)
			sert.eq(published[2], ';ban 777006 "appeal in 5 days"')
			ban = _K.Data.bans["777006"]
			sert.eq(ban ~= nil, true)
			sert.eq(ban[2], "appeal in 5 days")
			sert.eq(ban[3], nil)
		end)

		test(";global refuses strings where receivers bind arguments differently or cut them", function()
			local c = createSimCluster(nil, true)
			local _K = c._K
			local filterResult
			_K.Util.String.filterForBroadcast = function(text)
				return filterResult or text
			end
			local published = {}
			c._K.Data.subscribeTopic("global", function(message)
				table.insert(published, message.Data[2])
			end)
			local notices = {}
			local origNotifyFire = _K.Remote.Notify.Fire
			_K.Remote.Notify.Fire = function(self, player, data)
				table.insert(notices, data.Text)
				return origNotifyFire(self, player, data)
			end
			local function runGlobal(commandString: string)
				c.world:run(61) -- past the broadcast cooldown
				c.runSrv(commandString)
				c.world:run(1)
			end

			-- a quote after the sender's prefix in a raw token opens a quote on receivers and drops a token
			_K.Data.playerPrefix[1] = "!"
			runGlobal('!global change all !"coins 5')
			sert.eq(#published, 0)
			sert.eq(
				string.find(tostring(notices[#notices]), "would parse this command string differently", 1, true) ~= nil,
				true
			)
			_K.Data.playerPrefix[1] = nil

			-- receivers cut command strings past 1024 bytes from users without a restricted role
			local hasRestrictedRole = _K.Auth.hasRestrictedRole
			_K.Auth.hasRestrictedRole = function()
				return false
			end
			filterResult = string.rep("a", 1020)
			runGlobal(";global m text")
			sert.eq(#published, 0)
			sert.eq(string.find(tostring(notices[#notices]), "too long to run globally", 1, true) ~= nil, true)
			_K.Auth.hasRestrictedRole = hasRestrictedRole
			runGlobal(";global m text")
			sert.eq(#published, 1)
			_K.Remote.Notify.Fire = origNotifyFire
		end)

		test(
			";global refuses strings receivers would parse differently before they spend the announcement cooldown",
			function()
				local c = createSimCluster({ utf8 = clusteringUtf8() }, true)
				local _K = c._K
				local filterResult
				_K.Util.String.filterForBroadcast = function(text)
					return filterResult or text
				end
				local published = {}
				c._K.Data.subscribeTopic("global", function(message)
					table.insert(published, message.Data[2])
				end)
				local notices = {}
				local origNotifyFire = _K.Remote.Notify.Fire
				_K.Remote.Notify.Fire = function(self, player, data)
					table.insert(notices, data.Text)
					return origNotifyFire(self, player, data)
				end
				local function refused()
					return string.find(
						tostring(notices[#notices]),
						"would parse this command string differently",
						1,
						true
					) ~= nil
				end

				-- the text as typed already splits differently on receivers
				_K.Data.playerPrefix[1] = "!"
				c.runSrv('!global change all !"coins 5')
				c.world:run(1)
				sert.eq(refused(), true)
				_K.Data.playerPrefix[1] = nil

				-- and a string too long for receivers, once each list item is quoted
				_K.Registry.registerCommand(_K, {
					name = "globalitems",
					description = "Takes items",
					group = "superadmin",
					args = { { type = "strings", name = "Items", description = "The items." } },
					run = function() end,
				})
				c.world:run(0.1)
				local hasRestrictedRole = _K.Auth.hasRestrictedRole
				_K.Auth.hasRestrictedRole = function()
					return false
				end
				c.runSrv(";global globalitems " .. string.rep("a,", 299) .. "a")
				c.world:run(1)
				sert.eq(string.find(tostring(notices[#notices]), "too long to run globally", 1, true) ~= nil, true)
				_K.Auth.hasRestrictedRole = hasRestrictedRole
				sert.eq(#published, 0)

				-- so the next announcement doesn't wait for the cooldown
				c.runSrv(";announce Hello world")
				c.world:run(0.5)
				sert.eq(_K.Data.savedSettings.announcement[1], "Hello world")

				-- filtered text that starts with a combining mark is still refused, after the cooldown it spends
				filterResult = '\u{301}x"q" ;gravity 33 ;m z'
				local gravity = c.sh.env.workspace.Gravity
				c.world:run(61)
				c.runSrv(";global m text")
				c.world:run(0.5)
				sert.eq(refused(), true)
				sert.eq(#published, 0)
				sert.eq(c.sh.env.workspace.Gravity, gravity)
				filterResult = nil
				c.runSrv(";global m text")
				c.world:run(0.5)
				sert.eq(string.find(tostring(notices[#notices]), "before using this again", 1, true) ~= nil, true)
				sert.eq(#published, 0)
				_K.Remote.Notify.Fire = origNotifyFire
			end
		)
	end)

	test("VIPUGCMethod only takes a color name, and UGC Methods only replace the wearer's accessory", function()
		local c = createSimCluster(nil, true)
		local _K, srvP1, srvP2 = c._K, c.srvP1, c.srvP2
		local env = c.sh.env
		srvP1:SetAttribute("_KDonationLevel", 3) -- owns every UGC effect, so each call reaches Method

		local function wear(className: string, name: string, character: any)
			local item = env.Instance.new(className)
			item.Name = name
			env.Instance.new("Part", item).Name = "Handle"
			item.Parent = character
			return item
		end
		wear("Tool", "VictimTool", srvP2.Character)
		local victimHat = wear("Accessory", "VictimHat", srvP2.Character)

		-- Instances sent over the remote are refused before any Method runs
		for _, name in { "VictimTool", "VictimHat" } do
			local target = srvP2.Character:FindFirstChild(name)
			_K.VIP.Effect(srvP1, 18966788838, "rbxassetid://18966762965", true, target)
			_K.VIP.Effect(srvP1, 133292294488871, "rbxassetid://89119211625300", true, target)
			sert.eq(srvP2.Character:FindFirstChild(name), target)
		end
		-- even the caller's own accessory, which the Methods would accept
		local ownHat = wear("Accessory", "OwnHat", srvP1.Character)
		_K.VIP.Effect(srvP1, 18966788838, "rbxassetid://18966762965", true, ownHat)
		sert.eq(srvP1.Character:FindFirstChild("OwnHat"), ownHat)
		ownHat:Destroy()
		sert.eq(srvP1.Character:FindFirstChild("SuperCrown"), nil)

		-- a color name still equips the effect
		_K.VIP.Effect(srvP1, 18966788838, "rbxassetid://18966762965", true, "gold")
		sert.ok((srvP1.Character:FindFirstChild("SuperCrown")))

		-- a non-number asset id or a non-boolean equip is ignored, so it can't unequip or touch the caches
		_K.VIP.Effect(srvP1, "18966788838", "rbxassetid://18966762965", false, "gold")
		_K.VIP.Effect(srvP1, { 18966788838 }, "rbxassetid://18966762965", false, "gold")
		_K.VIP.Effect(srvP1, 18966788838, "rbxassetid://18966762965", 0, "gold")
		_K.VIP.Effect(srvP1, 18966788838, "rbxassetid://18966762965", nil, "gold")
		sert.ok((srvP1.Character:FindFirstChild("SuperCrown")))
		sert.ok(_K.VIP.effects[1]["rbxassetid://18966762965"])

		-- equip = false (what the client sends to hide it) still unequips, and it equips again afterwards
		_K.VIP.Effect(srvP1, 18966788838, "rbxassetid://18966762965", false, "gold")
		sert.eq(srvP1.Character:FindFirstChild("SuperCrown"), nil)
		sert.eq(_K.VIP.effects[1]["rbxassetid://18966762965"], nil)
		_K.VIP.Effect(srvP1, 18966788838, "rbxassetid://18966762965", true, "gold")
		sert.ok((srvP1.Character:FindFirstChild("SuperCrown")))

		-- the Methods never destroy another character's accessory or a non-Accessory, and still replace the
		-- wearer's own accessory, with or without a Handle
		local ownTool = wear("Tool", "OwnTool", srvP1.Character)
		for _, module in { c.sh.Shared.VIP.UGC.Crown, c.sh.Shared.VIP.UGC.AlphaWings } do
			local ugc = env:require(module)
			sert.eq(ugc.Method(srvP1.Character, victimHat), nil)
			sert.eq(srvP2.Character:FindFirstChild("VictimHat"), victimHat)
			sert.eq(ugc.Method(srvP1.Character, ownTool), nil)
			sert.eq(srvP1.Character:FindFirstChild("OwnTool"), ownTool)
			wear("Accessory", "OwnHat", srvP1.Character)
			sert.ok((ugc.Method(srvP1.Character, srvP1.Character:FindFirstChild("OwnHat"))))
			sert.eq(srvP1.Character:FindFirstChild("OwnHat"), nil)
			local bareHat = env.Instance.new("Accessory", srvP1.Character)
			bareHat.Name = "BareHat"
			sert.ok((ugc.Method(srvP1.Character, bareHat)))
			sert.eq(srvP1.Character:FindFirstChild("BareHat"), nil)
		end
	end)

	test(";whois shows ? for a Platform or SessionStart the server dropped", function()
		local c = createSimCluster()
		local _K, clientK, srvP1, world = c._K, c.clientK, c.srvP1, c.world
		clientK.Remote.ShowFPS.OnClientInvoke = function()
			return 60
		end
		local sent
		local origFire = _K.Remote.Notify.Fire
		_K.Remote.Notify.Fire = function(self, player, data)
			sent = data
			return origFire(self, player, data)
		end
		local function whois(): string
			sent = nil
			c.runSrv(";whois CreatorPlr")
			world:run(1)
			return sent and sent.Text
		end

		-- Remote.Init leaves these unset when a client sends bad values
		srvP1:SetAttribute("_KPlatform", nil)
		srvP1:SetAttribute("_KSessionStart", nil)
		local text = whois()
		sert.eq(string.find(text, "<b>Platform:</b> ?\n", 1, true) ~= nil, true)
		sert.eq(string.find(text, "<b>Session:</b> ?\n", 1, true) ~= nil, true)

		srvP1:SetAttribute("_KPlatform", "PC")
		srvP1:SetAttribute("_KSessionStart", c.sh.env.workspace:GetServerTimeNow() - 120)
		text = whois()
		sert.eq(string.find(text, "<b>Platform:</b> 🖥️ PC\n", 1, true) ~= nil, true)
		sert.eq(string.find(text, "<b>Session:</b> 2 minutes\n", 1, true) ~= nil, true)
		_K.Remote.Notify.Fire = origFire
	end)

	test("VIP purchase signals only grant perks the player owns, even when ownership shows up late", function()
		local c = createSimCluster(nil, true)
		local _K, srvP2, world = c._K, c.srvP2, c.world
		local env = c.sh.env
		local market = env.game:GetService("MarketplaceService")
		local Title = env:require(c.sh.Shared.VIP.Title)
		local vip, hero = Title.definition.vip, Title.definition.hero
		srvP2:SetAttribute("_KDonationLevel", 0)

		-- each check by Shared/VIP counts, and the player owns the item from check number `ownedFrom` on
		local methods = rawget(market, "_methods")
		local checks, ownedFrom = { pass = 0, asset = 0, other = 0 }, math.huge
		local function check(kind: string, owner: any, id: number, expectedId: number): boolean
			local fromVIP = string.find(debug.info(3, "s"), "src/Shared/VIP/init", 1, true)
			if not (fromVIP and (owner == srvP2 or owner == 2)) then
				return false
			elseif id ~= expectedId then
				checks.other += 1
				return false
			end
			checks[kind] += 1
			return checks[kind] >= ownedFrom
		end
		methods.UserOwnsGamePassAsync = function(_self, userId, passId)
			return check("pass", userId, passId, 5411126)
		end
		methods.PlayerOwnsAssetAsync = function(_self, player, assetId)
			return check("asset", player, assetId, 129439770798699)
		end

		local function purchase(times: number?)
			for _ = 1, times or 1 do
				-- like the engine, run each handler in its own thread so the checks overlap
				env.task.spawn(
					market.PromptGamePassPurchaseFinished.Fire,
					market.PromptGamePassPurchaseFinished,
					srvP2,
					5411126,
					true
				)
				env.task.spawn(
					market.PromptPurchaseFinished.Fire,
					market.PromptPurchaseFinished,
					srvP2,
					129439770798699,
					true
				)
			end
			world:run(10)
		end
		local function expectPerks(granted: boolean)
			sert.eq(srvP2:GetAttribute("_KDonationLevel"), if granted then 4 else 0)
			sert.eq(_K.Auth.hasRole(2, "vip"), granted)
			sert.eq(vip.ownerCache[2], if granted then true else nil)
			sert.eq(hero.ownerCache[2], if granted then true else nil)
		end

		-- fakes for ids KA grants nothing for are never checked
		market.PromptGamePassPurchaseFinished:Fire(srvP2, 123, true)
		market.PromptPurchaseFinished:Fire(srvP2, 456, true)
		world:run(10)
		sert.eq(checks.other, 0)

		-- an exploit fakes both purchases twice at once: nothing is granted, only one check per id runs at a
		-- time and gives up after three tries, and a title it was already refused is checked again on next use
		hero.ownerCache[2] = false
		purchase(2)
		expectPerks(false)
		sert.eq(checks.pass, 3)
		sert.eq(checks.asset, 3)

		-- a real purchase that the ownership checks only see on the second try still grants every perk
		checks.pass, checks.asset, ownedFrom = 0, 0, 2
		purchase()
		expectPerks(true)
		sert.eq(checks.pass, 2)
		sert.eq(checks.asset, 2)
	end)

	test("exercises Shared/VIP modules (Title, Crown, AlphaWings, Bones, Animate, Popup, Purchasables)", function()
		local c = createSimCluster()
		local _K, clientK, srvP1 = c._K, c.clientK, c.srvP1
		local srvChar = srvP1.Character
		local cliRunService = c.ch1.env.game:GetService("RunService")

		-- 1. Title module (`Shared.VIP.Title`)
		local Title = c.sh.env:require(c.sh.Shared.VIP.Title)
		Title.Method(srvChar, "Patron", Color3.new(1, 0, 0), Color3.new(1, 1, 0), Enum.Font.Code)
		local titleGui = srvChar:FindFirstChild("_K_Title")
		sert.ok(titleGui)
		for _, defName in { "epic", "hero", "legend", "mythic", "eternal" } do
			local def = Title.definition[defName]
			local seq = def.getValue(1.5)
			sert.ok(seq)
			def.update(titleGui, seq)
			local seqBoundary = def.getValue(0)
			sert.ok(seqBoundary)
			for i = 2, #seqBoundary.Keypoints do
				sert.eq(seqBoundary.Keypoints[i].Time > seqBoundary.Keypoints[i - 1].Time, true)
			end
		end
		-- Remove title when title == nil
		Title.Method(srvChar, nil)
		sert.eq(srvChar:FindFirstChild("_K_Title"), nil)

		-- Client Title heartbeat loop
		local cliTitle = c.ch1.env:require(c.ch1.Shared.VIP.Title)
		local cliChar = c.ch1.env.Players.LocalPlayer.Character
		cliTitle.Method(cliChar, "eternal")
		local cliTitleGui = cliChar:FindFirstChild("_K_Title")
		if cliTitleGui then
			cliTitleGui._props.AbsoluteSize = _globals.Vector2.new(100, 30)
		end
		cliRunService.Heartbeat:Fire(0.016)

		-- 2. Crown module (`Shared.VIP.UGC.Crown`)
		local Crown = c.sh.env:require(c.sh.Shared.VIP.UGC.Crown)
		sert.eq(Crown.Name, "SuperCrown")
		local crownAcc = Crown.Method(srvChar, "gold")
		sert.ok(crownAcc)
		sert.eq(crownAcc.Name, "SuperCrown")
		local crownDark = Crown.Method(srvChar, "dark")
		sert.ok(crownDark)
		crownDark:Destroy()

		-- Client Crown heartbeat loop
		local cliCrown = c.ch1.env:require(c.ch1.Shared.VIP.UGC.Crown)
		local cliCrownAcc = cliCrown.Method(cliChar, "gold")
		cliCrownAcc:AddTag("_KSuperCrownRainbow")
		cliRunService.Heartbeat:Fire(0.016)
		cliCrownAcc:Destroy()

		-- 3. AlphaWings, Bones, and Animate (`Shared.VIP.UGC.AlphaWings`)
		local AlphaWings = c.sh.env:require(c.sh.Shared.VIP.UGC.AlphaWings)
		local Bones = c.sh.env:require(c.sh.Shared.VIP.UGC.AlphaWings.Bones)
		sert.ok(Bones)
		sert.eq(AlphaWings.Name, "_KAlphaWings")
		local wingsAcc = AlphaWings.Method(srvChar, "gold")
		sert.ok(wingsAcc)
		sert.eq(wingsAcc.Name, "_KAlphaWings")

		-- Client AlphaWings heartbeat loop
		local cliWings = c.ch1.env:require(c.ch1.Shared.VIP.UGC.AlphaWings)
		local cliWingsAcc = cliWings.Method(cliChar, "dark")
		cliWingsAcc:AddTag("_KAlphaWingsRainbow")
		cliRunService.Heartbeat:Fire(0.016)

		-- Exercise Animate module (`Shared.VIP.UGC.AlphaWings.Animate.Animate`)
		local Animate = c.sh.env:require(c.sh.Shared.VIP.UGC.AlphaWings.Animate.Animate)
		local idleSeq = c.sh.env.Instance.new("KeyframeSequence")
		local kf1 = c.sh.env.Instance.new("Keyframe", idleSeq)
		kf1.Time = 0
		local parentPose = c.sh.env.Instance.new("Pose", kf1)
		parentPose.Name = "LeftWingRig"
		local childPose = c.sh.env.Instance.new("Pose", parentPose)
		childPose.Name = "Wing1"
		childPose.CFrame = CFrame.Angles(0.1, 0, 0)
		childPose.EasingStyle = Enum.PoseEasingStyle.Linear
		childPose.EasingDirection = Enum.PoseEasingDirection.In
		local kf2 = c.sh.env.Instance.new("Keyframe", idleSeq)
		kf2.Time = 0.02
		rawset(idleSeq, "_methods", {
			GetKeyframes = function()
				return { kf1, kf2 }
			end,
		})
		if wingsAcc:FindFirstChild("Wings") then
			sert.ok((Animate.getBoneFromPose(wingsAcc.Wings, childPose)))
			local playThread = c.sh.env.task.spawn(function()
				Animate.play(wingsAcc.Wings, idleSeq, false)
			end)
			c.world:run(0.6)
			c.sh.env.task.cancel(playThread)
		end
		wingsAcc:Destroy()
		cliWingsAcc:Destroy()

		-- 4. Purchasables (`Shared.VIP.Purchasables`)
		local Purchasables = c.sh.env:require(c.sh.Shared.VIP.Purchasables)
		sert.eq(#Purchasables.donations, 11)
		sert.eq(#Purchasables.scriptedUGC, 6)
		sert.eq(#Purchasables.chatCommands, 8)

		-- 5. Popup (`Shared.VIP.Popup`)
		local srvPopup = c.sh.env:require(c.sh.Shared.VIP.Popup)
		sert.eq(srvPopup, false)
		sert.ok(clientK.VIP.popup)
		sert.eq(clientK.VIP.popup.Name, "VIP")
		sert.ok((clientK.VIP.popup.Frame:FindFirstChild("Preview")))
		sert.eq(clientK.VIP.popup.Frame.BuyFrame.Favorite:IsA("ImageButton"), true)
		sert.eq(clientK.VIP.popup.Frame.BuyFrame.Favorite.Visible, true)

		-- PromptPurchaseVIP opens the popup first when hidden, and View hides the popup while opening Commands
		clientK.VIP.popup.Visible = false
		clientK.PromptPurchaseVIP()
		sert.eq(clientK.VIP.popup.Visible, true)
		clientK.VIP.popup.Frame.BuyFrame.View.Activated:Fire()
		sert.eq(clientK.VIP.popup.Visible, false)
		sert.eq(clientK.client.dashboard.Commands._instance.Visible, true)
		sert.eq(clientK.VIP.popup.ZIndex, 9e8)

		-- Completing a bulk purchase for the 40% OFF asset (capital .Id) hides the popup and disables VIPNotification
		local cliMarket = c.ch1.env.game:GetService("MarketplaceService")
		clientK.VIP.popup.Visible = true
		cliMarket.PromptBulkPurchaseFinished:Fire(
			c.ch1.env.Players.LocalPlayer,
			Enum.MarketplaceBulkPurchasePromptStatus.Completed,
			{ Items = { { Id = "115444443724463", Status = Enum.MarketplaceItemPurchaseStatus.Success } } }
		)
		c.world:run(0.1)
		sert.eq(clientK.VIP.popup.Visible, false)

		-- 6. VIP purchase & receipt signals (`Shared.VIP.init`)
		local market = c.sh.env.game:GetService("MarketplaceService")
		market.PromptGamePassPurchaseFinished:Fire(srvP1, 5411126, true)
		market.PromptPurchaseFinished:Fire(srvP1, 129439770798699, true)
		clientK.Remote.VIPCheck:Fire(115444443724463)
		clientK.Remote.VIPCheck:Fire(129439770798699)
		_K.VIP.Effect(srvP1, 18966788838, "rbxassetid://18966762965", true, "Light Crown")
		_K.VIP.EffectHandler(srvChar)
		_K.VIP.Effect(srvP1, 18966788838, "rbxassetid://18966762965", false, "Light Crown")
		_K.VIP.Title(srvP1, "Hero")
		clientK.Remote.VIPCheck:Fire(110019084552349)
		clientK.Remote.PromptBulkPurchase:Fire(110019084552349)
		clientK.Remote.Title:Fire("Hero")
		c.world:run(0.1)

		-- Verify ;localscript parents script to each target player's PlayerGui (even when fromPlayer is nil)
		local p1Gui = srvP1:FindFirstChildOfClass("PlayerGui")
		local loadedParents: { Instance } = {}
		local origLoadScript = _K.LoadScript
		_K.LoadScript = function(src: string, mode: string, parent: Instance)
			table.insert(loadedParents, parent)
			return origLoadScript(src, mode, parent)
		end
		_K.Registry.commands.localscript.run({ _K = _K, fromPlayer = nil }, { srvP1 }, "local x = 1")
		_K.LoadScript = origLoadScript
		sert.eq(loadedParents, { p1Gui })

		-- Verify ;prefix / ;hotkeys reads Shift+ and Alt+ from mods:peek()
		clientK.client.hotkeys.commandBar.mods({ Shift = true, Alt = true })
		clientK.client.hotkeys.dashboard.mods({ Shift = true, Alt = false })
		_K.Registry.commands.prefix.runClient({ _K = clientK })
		sert.eq(string.find(clientK._lastNotify.Text, "Shift+Alt+", 1, true) ~= nil, true)
	end)

	test("disco tweens each client's Lighting at <= 1 Hz and honors KAH_NoFx and ReducedMotionEnabled", function()
		local c = createSimCluster()
		local _K, clientK, runSrv = c._K, c.clientK, c.runSrv
		local srvLighting = c.sh.env.game:GetService("Lighting")
		local cliLighting = c.ch1.env.game:GetService("Lighting")
		local cliGui = c.ch1.env.game:GetService("GuiService")
		local cliPlayer = c.ch1.env.Players.LocalPlayer
		local cliEnv = clientK.Registry.commands.disco.env
		local original = Color3.new(0.1, 0.2, 0.3)
		cliLighting.Ambient, cliLighting.FogColor = original, original

		-- the server only marks disco active, it never changes Lighting itself
		local srvAmbient = srvLighting.Ambient
		runSrv(";disco")
		c.world:run(0.05)
		sert.ok(_K.Registry.commands.disco.env.id)
		sert.eq(srvLighting:GetAttribute("_KDisco"), _K.Registry.commands.disco.env.id)
		c.world:run(2)
		sert.eq(srvLighting.Ambient, srvAmbient)

		-- the attribute replicates in Roblox, in the sim each peer has its own Lighting
		local tweens = {}
		local tween = c.ch1.env.game:GetService("TweenService")
		local tweenMethods = rawget(tween, "_methods")
		local origCreate = tweenMethods.Create
		tweenMethods.Create = function(self: any, target: any, info: any, goals: any)
			table.insert(tweens, { target = target, info = info, goals = goals })
			return origCreate(self, target, info, goals)
		end
		cliLighting:SetAttribute("_KDisco", 1)
		c.world:run(0.05)
		sert.eq(cliEnv.restore, { original, original })
		sert.eq(#tweens, 1)
		sert.eq(tweens[1].target, cliLighting)
		-- one color per tween of at least a second: luminance changes at <= 1 Hz, eased, never a hard jump
		sert.eq(tweens[1].info.Time >= 1, true)
		sert.eq(tweens[1].info.EasingStyle, Enum.EasingStyle.Sine)
		sert.eq(tweens[1].goals.Ambient, cliEnv.COLORS[1])
		sert.eq(tweens[1].goals.FogColor, cliEnv.COLORS[1])
		sert.ne(cliLighting.Ambient, cliEnv.COLORS[1])
		c.world:run(cliEnv.STEP)
		sert.eq(#tweens, 2)
		sert.eq(tweens[2].goals.Ambient, cliEnv.COLORS[2])
		-- the colors wrap around
		c.world:run(cliEnv.STEP * (#cliEnv.COLORS - 1))
		sert.eq(tweens[#tweens].goals.Ambient, cliEnv.COLORS[1])
		sert.eq(#tweens, #cliEnv.COLORS + 1)
		-- re-marking an active disco doesn't start a second loop
		cliLighting:SetAttribute("_KDisco", 2)
		c.world:run(0.05)
		sert.eq(#tweens, #cliEnv.COLORS + 1)

		-- opting out mid-effect stops the tweens and restores the player's lighting
		cliPlayer:SetAttribute("KAH_NoFx", true)
		c.world:run(0.05)
		sert.eq(cliEnv.running, false)
		sert.eq(cliEnv.tween, false)
		sert.eq(cliLighting.Ambient, original)
		sert.eq(cliLighting.FogColor, original)
		local count = #tweens
		c.world:run(cliEnv.STEP * 2)
		sert.eq(#tweens, count)
		-- a false attribute isn't an opt-out
		cliPlayer:SetAttribute("KAH_NoFx", false)
		c.world:run(0.05)
		sert.ok(cliEnv.running)
		sert.eq(#tweens, count + 1)

		cliGui.ReducedMotionEnabled = true
		c.world:run(0.05)
		sert.eq(cliEnv.running, false)
		sert.eq(cliLighting.Ambient, original)
		c.world:run(cliEnv.STEP * 2)
		sert.eq(#tweens, count + 1)
		cliGui.ReducedMotionEnabled = false
		c.world:run(0.05)
		sert.ok(cliEnv.running)

		-- undisco clears the mark, every client restores its lighting
		runSrv(";undisco")
		c.world:run(0.05)
		sert.eq(srvLighting:GetAttribute("_KDisco"), nil)
		sert.eq(_K.Registry.commands.disco.env.id, false)
		cliLighting:SetAttribute("_KDisco", nil)
		c.world:run(0.05)
		sert.eq(cliEnv.running, false)
		sert.eq(cliEnv.restore, false)
		sert.eq(cliLighting.Ambient, original)
		sert.eq(cliLighting.FogColor, original)
		count = #tweens
		c.world:run(cliEnv.STEP * 2)
		sert.eq(#tweens, count)

		-- a player who opted out before disco started never gets it
		cliPlayer:SetAttribute("KAH_NoFx", "yes")
		cliLighting:SetAttribute("_KDisco", 3)
		c.world:run(cliEnv.STEP * 2)
		sert.eq(#tweens, count)
		sert.eq(cliEnv.restore, false)
		sert.eq(cliLighting.Ambient, original)
	end)

	test(
		";poll, ;vote, and SuperAdmin ;global validate options, deduplicate targets, tally choices, and render results below question",
		function()
			local c = createSimCluster()
			local _K, clientK, srvP1, srvP2 = c._K, c.clientK, c.srvP1, c.srvP2
			local pollDef = _K.Registry.commands.poll
			local voteDef = _K.Registry.commands.vote

			local function makeCtx(args: any?)
				return {
					_K = _K,
					from = srvP1.UserId,
					fromPlayer = srvP1,
					env = pollDef.env,
					args = args or {},
				}
			end

			-- Validation errors: 0 targets, blank question, <2 options, blank/pipe-only options, duplicates, >8 options, >200 chars
			sert.eq(pollDef.run(makeCtx(), {}, "Map?"), "No players to poll.")
			sert.eq(pollDef.run(makeCtx(), { srvP1 }, "   "), "A poll needs a question.")
			sert.eq(
				pollDef.run(makeCtx(), { srvP1 }, string.rep("q", 201)),
				"The question can be at most 200 characters."
			)
			sert.eq(pollDef.run(makeCtx(), { srvP1 }, "Map?", { "OnlyOne" }), "A poll needs at least 2 options.")
			sert.eq(
				pollDef.run(
					makeCtx({ [2] = { rawArg = '"Map?"' }, [3] = { rawArg = '"OnlyOne" ""' } }),
					{ srvP1 },
					"Map?",
					{ 'OnlyOne" "' }
				),
				"A poll needs at least 2 options."
			)
			sert.eq(pollDef.run(makeCtx(), { srvP1 }, "Map?", { "   ", "" }), "A poll needs at least 2 options.")
			sert.eq(
				pollDef.run(makeCtx(), { srvP1 }, "Map?", { "Desert", "desert" }),
				"Poll options must be different from each other."
			)
			sert.eq(
				pollDef.run(makeCtx(), { srvP1 }, "Map?", { "A", string.rep("b", 201) }),
				"Each option can be at most 200 characters."
			)
			sert.eq(
				pollDef.run(makeCtx(), { srvP1 }, "Map?", { "1", "2", "3", "4", "5", "6", "7", "8", "9" }),
				"A poll can have at most 8 options."
			)

			-- Global command block for both vote and poll
			local globalDef = _K.Registry.commands.global
			sert.eq(
				globalDef.run({ _K = _K, from = srvP1.UserId, fromPlayer = srvP1 }, ";vote all Question?"),
				'"vote" can\'t run globally.'
			)
			sert.eq(
				globalDef.run({ _K = _K, from = srvP1.UserId, fromPlayer = srvP1 }, ';poll all "Question?" A,B'),
				'"poll" can\'t run globally.'
			)

			-- Mount Dialog on client for VoteResults & OnInvoke
			local lastDialog
			clientK.Notify = function(override: any)
				lastDialog = clientK.UI.new("Dialog")(override)
				return lastDialog
			end

			-- End-to-end poll with duplicate player entry, RichText question/options, and client choice = 2
			local origInvoke = pollDef.env.remote.Invoke
			pollDef.env.remote.Invoke = function(
				_self: any,
				player: any,
				_id: string,
				_from: any,
				count: number,
				labels: { string }
			)
				sert.eq(count, 3)
				sert.eq(labels, { "<b>Red</b>", "Blue", "Green" })
				if player == srvP1 then
					return 2
				end
				return 99 -- invalid out-of-range choice from srvP2 is ignored (counts as missing)
			end

			local lastResults
			local resultsCon = clientK.Remote.VoteResults:Connect(function(q, labels, tally, missing, yesNo)
				lastResults = { q = q, labels = labels, tally = tally, missing = missing, yesNo = yesNo }
			end)

			local qArg = { rawType = { freeText = true }, rawArg = '"<b>Color?</b>"', parsedArgs = { "<b>Color?</b>" } }
			local oArg = {
				rawType = { freeText = true },
				rawArg = '"<b>Red</b>" Blue "Green"',
				parsedArgs = { '<b>Red</b>" Blue "Green' },
			}
			local err = "unset"
			c.sh.env.task.spawn(function()
				err = pollDef.run(
					makeCtx({ [2] = qArg, [3] = oArg }),
					{ srvP1, srvP1, srvP2 }, -- duplicate srvP1 should be deduplicated
					"<b>Color?</b>",
					{ '<b>Red</b>" Blue "Green' }
				)
			end)
			c.world:run(0.1)
			sert.eq(err, nil)
			sert.eq(qArg.redactLog, false)
			sert.eq(oArg.redactLog, false)

			sert.eq(lastResults ~= nil, true)
			sert.eq(lastResults.q, "<b>Color?</b>")
			sert.eq(lastResults.labels, { "<b>Red</b>", "Blue", "Green" })
			sert.eq(lastResults.tally, { 0, 1, 0 })
			sert.eq(lastResults.missing, 1) -- 2 unique players - 1 valid vote = 1 missing
			sert.eq(lastResults.yesNo, false)

			-- Verify Results Frame LayoutOrder is 3 (below Dialog's Title -2 and Text -1)
			sert.eq(lastDialog ~= nil, true)
			local resultsFrame = lastDialog._content:FindFirstChild("Results")
			sert.eq(resultsFrame ~= nil, true)
			sert.eq(lastDialog._content.Title.LayoutOrder, -2)
			sert.eq(lastDialog._content.Text.LayoutOrder, -1)
			sert.eq(resultsFrame.LayoutOrder, 3)
			sert.eq(resultsFrame.LayoutOrder > lastDialog._content.Text.LayoutOrder, true)

			-- Unquoted multi-word question in ;poll falls back to a yes/no vote
			c.world:run(61)
			pollDef.env.remote.Invoke = function()
				return true
			end
			local errYesNo = "unset"
			local unquotedCtx = makeCtx({ [2] = { rawArg = "Are" }, [3] = { rawArg = "you ready?" } })
			c.sh.env.task.spawn(function()
				errYesNo = pollDef.run(unquotedCtx, { srvP1 }, "Are", { "you ready?" })
			end)
			c.world:run(0.1)
			sert.eq(errYesNo, nil)
			sert.eq(unquotedCtx.args[3], nil)
			sert.eq(lastResults.q, "Are you ready?")
			sert.eq(lastResults.yesNo, true)
			sert.eq(lastResults.tally, { 1, 0 })

			-- Client OnInvoke resolves nil if dialog is destroyed externally (e.g. overflow eviction)
			local origVoteOnInvoke = clientK.Remote.Vote.OnInvoke
			_K.Remote.ChatSystem:Fire(srvP1, "vote", "Evict test?", 1, { "A", "B" }, "vote_evict")
			c.world:run(0.05)
			local invokeResolved = false
			local invokeResult = "unset"
			c.ch1.env.task.spawn(function()
				invokeResult = origVoteOnInvoke("vote_evict", 1, 2, { "A", "B" })
				invokeResolved = true
			end)
			c.world:run(0.05)
			sert.eq(lastDialog ~= nil, true)
			c.ch1.env.task.spawn(function()
				lastDialog._instance:Destroy()
			end)
			c.world:run(0.05)
			sert.eq(invokeResolved, true)
			sert.eq(invokeResult, nil)

			resultsCon:Disconnect()
			pollDef.env.remote.Invoke = origInvoke
			voteDef.env.remote.Invoke = origInvoke
		end
	)

	test("registers and runs ExampleAddon, ExampleAddonClient, and ExampleAddonServer", function()
		local c = createSimCluster()
		local _K, clientK = c._K, c.clientK
		local ExampleAddon = require("../../model/Config/addons/src/ExampleAddon")
		local ExampleAddonClient = require("../../model/Config/addons/src/ExampleAddonClient")
		local ExampleAddonServer = require("../../model/Config/addons/src/ExampleAddonServer")

		ExampleAddon(_K)
		ExampleAddon(clientK)
		ExampleAddonClient(clientK)
		ExampleAddonServer(_K)

		local customcommand = _K.Registry.commands.customcommand
		sert.ok(customcommand)
		setfenv(customcommand.run, c.sh.env.globals)
		local srvEnv = customcommand.env
		local cliEnv = clientK.Registry.commands.customcommand.env
		sert.eq(srvEnv.countServer, 0)
		sert.eq(cliEnv.countClient, 0)

		customcommand.run({ _K = _K, env = srvEnv, from = 1 }, nil)
		sert.eq(srvEnv.countServer, 1)
		customcommand.runClient({ _K = clientK, env = cliEnv, from = 1 }, "hello")
		sert.eq(cliEnv.countClient, 1)
	end)

	test(
		"SuperAdmin and Administration PIC compliance skips restricted recipients on cooldown, allows predefined titles, and preserves moderation actions when sender cannot chat",
		function()
			local c = createSimCluster(nil, true)
			local _K, srvP1, srvP2 = c._K, c.srvP1, c.srvP2
			local srvP3 = c.sh.env:addPlayer(3, "RestrictedPlr")
			buildCharacter(c.sh.env, srvP3)

			local tcs = c.sh.env.game:GetService("TextChatService")
			local tcMethods = rawget(tcs, "_methods")
			local origCanUserChat = tcMethods.CanUserChatAsync
			local origCanUsersChat = tcMethods.CanUsersChatAsync

			-- 1. ;time marks its Time argument redactLog = false
			local timeArg = { rawArg = "14:30", parsedArgs = { "14:30" }, rawType = { freeText = true } }
			_K.Registry.commands.time.run({ _K = _K, from = 1, args = { timeArg } }, "14:30", nil)
			sert.eq(timeArg.redactLog, false)

			-- 2. When all peers can chat with sender, world-text commands (name, custom title, createteam, editteam, change) do not spend cooldowns
			tcMethods.CanUsersChatAsync = function()
				return true
			end
			c.runSrv(";name TargetPlr FirstNick")
			c.runSrv(";name TargetPlr SecondNick")
			sert.eq(srvP2:GetAttribute("_KDisplayName"), "SecondNick")

			c.runSrv(";createteam TeamAlpha #ff0000")
			c.runSrv(";createteam TeamBeta #00ff00")
			local teamBeta = c.sh.env.game:GetService("Teams"):FindFirstChild("TeamBeta")
			sert.eq(teamBeta ~= nil, true)
			c.runSrv(";editteam TeamBeta TeamGamma")
			c.runSrv(";editteam TeamGamma TeamDelta")
			sert.eq(teamBeta.Name, "TeamDelta")

			local ls = c.sh.env.Instance.new("Folder", srvP2)
			ls.Name = "leaderstats"
			local rankStat = c.sh.env.Instance.new("StringValue", ls)
			rankStat.Name = "Rank"
			c.runSrv(";change TargetPlr Rank Bronze")
			c.runSrv(";change TargetPlr Rank Silver")
			sert.eq(rankStat.Value, "Silver")

			-- 3. Predefined VIP titles work even when sender cannot chat or is on custom title cooldown
			-- First restrict srvP3 so custom title spends cooldown
			tcMethods.CanUsersChatAsync = function(_self, _from, to)
				return to ~= 3
			end
			c.runSrv(";title TargetPlr CustomOne")
			c.world:run(0.05)
			sert.eq(srvP2.Character:FindFirstChild("_K_Title").Title.Text, "CustomOne")
			-- Second custom title within 60s is blocked by cooldown because RestrictedPlr (3) is in server
			local titleErr = _K.Registry.commands.title.run(
				{ _K = _K, from = 1, fromPlayer = srvP1, args = {} },
				{ srvP2 },
				"CustomTwo"
			)
			sert.eq(string.find(tostring(titleErr), "Wait", 1, true) ~= nil, true)
			-- Predefined VIP title ("vip") succeeds even while on cooldown and even when CanUserChatAsync is false
			_K.VIP.titleDefinition.vip.ownerCache[srvP2.UserId] = true
			tcMethods.CanUserChatAsync = function()
				return false
			end
			c.runSrv(";title TargetPlr vip")
			c.world:run(0.05)
			sert.eq(string.lower(srvP2.Character:FindFirstChild("_K_Title").Title.Text), "vip")

			-- 4. ban, kick, and shutdown still execute with reason stripped when CanUserChatAsync is false
			srvP2._props._kicked = nil
			c.runSrv(";ban TargetPlr 0 ShouldStripReason")
			sert.eq(_K.Data.bans["2"] ~= nil, true)
			sert.eq(_K.Data.bans["2"][2], nil)
			sert.eq(srvP2._props._kicked, "No reason.")
			_K.Data.bans["2"] = nil

			srvP2._props._kicked = nil
			c.runSrv(";kick TargetPlr ShouldAlsoStrip")
			sert.eq(srvP2._props._kicked, true) -- nil reason passed to Kick

			srvP2._props._kicked = nil
			srvP3._props._kicked = nil
			_K.Registry.commands.shutdown.run({ _K = _K, from = 1, fromPlayer = srvP1, args = {} }, nil, "MutedReason")
			sert.eq(string.find(tostring(srvP2._props._kicked), "Reason:", 1, true), nil)

			-- 5. On reason cooldown, kick/shutdown still show the reason to chat-allowed players while stripping for restricted players
			tcMethods.CanUserChatAsync = origCanUserChat
			-- Spend the reason cooldown on restricted srvP3
			_K.Registry.commands.kick.run(
				{ _K = _K, from = 1, fromPlayer = srvP1, args = {} },
				{ srvP3 },
				"FirstKickReason"
			)
			sert.eq(srvP3._props._kicked, "FirstKickReason")
			-- Now on cooldown: kicking both srvP2 (allowed) and srvP3 (restricted) gives srvP2 the reason and srvP3 nil
			srvP2._props._kicked = nil
			srvP3._props._kicked = nil
			_K.Registry.commands.kick.run(
				{ _K = _K, from = 1, fromPlayer = srvP1, args = {} },
				{ srvP2, srvP3 },
				"SecondKickReason"
			)
			sert.eq(srvP2._props._kicked, "SecondKickReason")
			sert.eq(srvP3._props._kicked, true)

			-- 6. startVote on "vote" cooldown skips restricted srvP3 and only polls delivered srvP2
			local voteDef = _K.Registry.commands.vote
			local origVoteInvoke = voteDef.env.remote.Invoke
			local polledIds = {}
			voteDef.env.remote.Invoke = function(_self, plr)
				table.insert(polledIds, plr.UserId)
				return 1
			end
			-- First vote with srvP3 spends the "vote" cooldown
			c.sh.env.task.spawn(function()
				voteDef.run(
					{ _K = _K, from = 1, fromPlayer = srvP1, env = voteDef.env, args = {} },
					{ srvP2, srvP3 },
					"First vote?"
				)
			end)
			c.world:run(0.1)
			table.sort(polledIds)
			sert.eq(polledIds, { 2, 3 })

			-- Second vote within 60s skips srvP3 and only invokes Remote.Vote on srvP2
			table.clear(polledIds)
			c.sh.env.task.spawn(function()
				voteDef.run(
					{ _K = _K, from = 1, fromPlayer = srvP1, env = voteDef.env, args = {} },
					{ srvP2, srvP3 },
					"Second vote?"
				)
			end)
			c.world:run(0.1)
			sert.eq(polledIds, { 2 })

			voteDef.env.remote.Invoke = origVoteInvoke
			tcMethods.CanUserChatAsync = origCanUserChat
			tcMethods.CanUsersChatAsync = origCanUsersChat
		end
	)

	test(
		"Batch 2 regressions: track persistence & stream-in, R15 AnimationConstraint dog, R6/dynamic head face & bundle, BindToClose pcall, jail streaming, createteam duplicates, and respawn/punish tool unequip",
		function()
			local c = createSimCluster()
			local _K, clientK, srvP1, srvP2 = c._K, c.clientK, c.srvP1, c.srvP2

			-- #519: BindToClose wrapped in pcall in Data/init.luau
			sert.eq(_K.Data.gameClosing, false)

			-- #481: ;createteam rejects duplicate team names (case-insensitive) and duplicate explicit TeamColors, and picks an unused BrickColor when omitted
			local teams = c.sh.env.game:GetService("Teams")
			for _, t in teams:GetChildren() do
				t:Destroy()
			end
			local createTeamRun = _K.Registry.commands.createteam.run
			local ctx = { _K = _K, from = 1, fromPlayer = srvP1, args = {} }
			local err1 = createTeamRun(ctx, "RedGuard", Color3.fromRGB(255, 0, 0))
			sert.eq(err1, nil)
			local redTeam = teams:FindFirstChild("RedGuard")
			sert.eq(redTeam ~= nil, true)

			-- Case-insensitive duplicate name rejected
			local errDupName = createTeamRun(ctx, "redguard", Color3.fromRGB(0, 255, 0))
			sert.eq(string.find(tostring(errDupName), "already exists", 1, true) ~= nil, true)

			-- Duplicate explicit TeamColor rejected
			local errDupColor = createTeamRun(ctx, "CrimsonCopy", redTeam.TeamColor.Color)
			sert.eq(string.find(tostring(errDupColor), "already in use", 1, true) ~= nil, true)

			-- Omitted color picks an unused BrickColor
			local errAutoColor = createTeamRun(ctx, "AutoTeam", nil)
			sert.eq(errAutoColor, nil)
			local autoTeam = teams:FindFirstChild("AutoTeam")
			sert.eq(autoTeam ~= nil, true)
			sert.eq(autoTeam.TeamColor ~= redTeam.TeamColor, true)

			-- #517: ;jail sets root CanCollide = false and attaches ChildAdded watcher on client so streamed-in wall BaseParts get CanCollide = true
			c.runSrv(";jail TargetPlr")
			local jailPart = _K.Registry.commands.jail.env.parts[srvP2.UserId]
			sert.eq(jailPart ~= nil, true)
			sert.eq(jailPart.CanCollide, false)
			local srvJail = c.sh.env.Instance.new("Part", c.sh.env.workspace)
			srvJail.Name = "JailCollideTestPart"
			srvJail.CanCollide = true
			c.world:run(0.05)
			local cliJail = c.ch1.env.workspace:FindFirstChild("JailCollideTestPart")
			sert.eq(cliJail ~= nil, true)
			_K.Remote.JailCollide:Fire(srvP1, srvJail)
			c.world:run(0.05)
			sert.eq(cliJail.CanCollide, false)
			local streamedWall = c.ch1.env.Instance.new("Part")
			streamedWall.CanCollide = false
			streamedWall.Parent = cliJail
			sert.eq(streamedWall.CanCollide, true)
			srvJail:Destroy()
			c.runSrv(";unjail TargetPlr")

			-- #398: ;punish and ;respawn call Humanoid:UnequipTools() before removing/reloading character
			local unequippedCount = 0
			local humMethods = rawget(srvP2.Character:FindFirstChildOfClass("Humanoid"), "_methods")
			local origUnequip = humMethods.UnequipTools
			humMethods.UnequipTools = function(self)
				unequippedCount += 1
				if origUnequip then
					origUnequip(self)
				end
			end
			c.runSrv(";punish TargetPlr")
			sert.eq(unequippedCount, 1)
			c.runSrv(";unpunish TargetPlr")
			c.runSrv(";respawn TargetPlr")
			sert.eq(unequippedCount, 2)

			-- #534: ;dog on R15 rig with AnimationConstraint joints modifies Attachment0.CFrame instead of throwing read-only C0 error
			local r15Char = buildCharacter(c.sh.env, srvP2, Enum.HumanoidRigType.R15)
			local upperTorso = r15Char:FindFirstChild("UpperTorso")
			local existingWaist = upperTorso:FindFirstChild("Waist")
			if existingWaist then
				existingWaist:Destroy()
			end
			local att0 = c.sh.env.Instance.new("Attachment", upperTorso)
			local origAttCFrame = CFrame.new(1, 2, 3)
			att0.CFrame = origAttCFrame
			local waistConstraint = c.sh.env.Instance.new("AnimationConstraint", upperTorso)
			waistConstraint.Name = "Waist"
			waistConstraint.Attachment0 = att0
			c.runSrv(";dog TargetPlr")
			sert.eq(att0.CFrame, origAttCFrame * CFrame.Angles(-math.rad(30), 0, 0))
			c.runSrv(";undog TargetPlr")
			sert.eq(att0.CFrame.Position, origAttCFrame.Position)

			-- #532: ;face clears Head SpecialMesh.TextureId and MeshPart.TextureID and restores them on ;unface
			local head = srvP2.Character:FindFirstChild("Head")
			local headMesh = head:FindFirstChildOfClass("SpecialMesh") or c.sh.env.Instance.new("SpecialMesh", head)
			headMesh.TextureId = "rbxassetid://999888"
			c.runSrv(";face TargetPlr 1800")
			sert.eq(headMesh.TextureId, "")
			c.runSrv(";unface TargetPlr")
			sert.eq(headMesh.TextureId, "rbxassetid://999888")

			-- #255: ;bundle with BundleType == "DynamicHead" merges only Head and MoodAnimation onto existing HumanoidDescription
			local assetSvc = c.sh.env.game:GetService("AssetService")
			local playersSvc = c.sh.env.game:GetService("Players")
			local assetMethods = rawget(assetSvc, "_methods")
			local playersMethods = rawget(playersSvc, "_methods")
			local origGetBundleDetails = assetMethods.GetBundleDetailsAsync
			local origGetDescFromOutfit = playersMethods.GetHumanoidDescriptionFromOutfitIdAsync
			assetMethods.GetBundleDetailsAsync = function(_self, bundleId)
				if bundleId == 777 then
					return {
						BundleType = "DynamicHead",
						Items = { { Type = "UserOutfit", Id = 888 } },
					}
				end
				return origGetBundleDetails and origGetBundleDetails(_self, bundleId)
			end
			playersMethods.GetHumanoidDescriptionFromOutfitIdAsync = function(_self, outfitId)
				if outfitId == 888 then
					local d = c.sh.env.Instance.new("HumanoidDescription")
					d.Head = 555444
					d.MoodAnimation = 666333
					d.Torso = 111222 -- should NOT overwrite player's existing Torso on DynamicHead bundle
					return d
				end
				return origGetDescFromOutfit and origGetDescFromOutfit(_self, outfitId)
			end
			local hum = srvP2.Character:FindFirstChildOfClass("Humanoid")
			local baseDesc = hum:FindFirstChildOfClass("HumanoidDescription")
				or c.sh.env.Instance.new("HumanoidDescription", hum)
			baseDesc.Torso = 424242
			c.runSrv(";bundle TargetPlr 777")
			local appliedDesc = hum:GetAppliedDescription()
			sert.eq(appliedDesc.Head, 555444)
			sert.eq(appliedDesc.MoodAnimation, 666333)
			sert.eq(appliedDesc.Torso, 424242)
			c.runSrv(";unbundle TargetPlr")
			assetMethods.GetBundleDetailsAsync = origGetBundleDetails
			playersMethods.GetHumanoidDescriptionFromOutfitIdAsync = origGetDescFromOutfit

			-- #536: ;track defaults to persistent = true and auto-attaches when HumanoidRootPart streams in later
			local cliLinkDef = clientK.Registry.commands.link
			local cliP1 = c.ch1.env.Players.LocalPlayer
			local cliP2 = c.ch1.env:addPlayer(2, "TargetPlr")
			buildCharacter(c.ch1.env, cliP1)
			-- Start with a character whose HumanoidRootPart hasn't streamed in yet
			local partialChar = c.ch1.env.Instance.new("Model")
			partialChar.Name = "TargetPlr"
			cliP2.Character = partialChar
			partialChar.Parent = c.ch1.env.workspace
			cliLinkDef.runClient({ _K = clientK, env = cliLinkDef.env, from = 1 }, { cliP2 }, nil)
			sert.eq(cliLinkDef.env.persist[cliP2] ~= nil, true)
			sert.eq(cliLinkDef.env.watchCleanup[cliP2] ~= nil, true)
			-- Now stream in HumanoidRootPart + Attachment
			local streamedHrp = c.ch1.env.Instance.new("Part")
			streamedHrp.Name = "HumanoidRootPart"
			c.ch1.env.Instance.new("Attachment", streamedHrp)
			streamedHrp.Parent = partialChar
			c.world:run(0.05)
			sert.eq(streamedHrp:FindFirstChild("_KLink") ~= nil, true)
			-- Unlink cleans up both persist and watchCleanup
			clientK.Registry.commands.unlink.runClient({ _K = clientK, env = cliLinkDef.env, from = 1 }, { cliP2 })
			sert.eq(cliLinkDef.env.persist[cliP2], nil)
			sert.eq(cliLinkDef.env.watchCleanup[cliP2], nil)
		end
	)

	test(
		"Slice 2 regressions: dog/undog exact Root.C0 identity, shirt nil AssetId, bodycolor/crm undo & ForceField textures, VIP single-asset purchases, antilag MeshPart/destroyed safety, team edits & RichText escaping, pre-load emotes preview, link/unlink race, and play/jumpscare/tts hardening",
		function()
			local c = createSimCluster()
			local _K, clientK, srvP1, srvP2 = c._K, c.clientK, c.srvP1, c.srvP2

			-- 1. dog / undog restores R15 Root.C0 (both Motor6D and AnimationConstraint) to exact original CFrame without drift
			local dogChar = buildCharacter(c.sh.env, srvP2, Enum.HumanoidRigType.R15)
			local rootMotor = dogChar.LowerTorso:FindFirstChild("Root")
			local origRootC0 = CFrame.new(0.25, -1, 0.5) * CFrame.Angles(0.1, 0.2, -0.1)
			rootMotor.C0 = origRootC0
			for _ = 1, 3 do
				c.runSrv(";dog TargetPlr")
				sert.eq(rootMotor.C0:FuzzyEq(origRootC0), false)
				c.runSrv(";undog TargetPlr")
				sert.eq(rootMotor.C0:FuzzyEq(origRootC0), true)
			end

			-- 2. jumpscare and play reject <= 0, non-audio, and failed/nil GetProductInfoAsync
			local playDef = _K.Registry.commands.play
			local jumpDef = _K.Registry.commands.jumpscare
			local playCtx = { _K = _K, env = playDef.env, from = 1, fromPlayer = srvP1 }
			local jumpCtx = { _K = _K, env = jumpDef.env, from = 1, fromPlayer = srvP1 }
			sert.eq(playDef.run(playCtx, 0), "Invalid audio asset.")
			sert.eq(playDef.run(playCtx, -42), "Invalid audio asset.")
			sert.eq(jumpDef.run(jumpCtx, { srvP2 }, nil, 0), "Invalid audio asset.")
			sert.eq(jumpDef.run(jumpCtx, { srvP2 }, nil, -42), "Invalid audio asset.")

			local marketMethods = rawget(_K.Service.Marketplace, "_methods")
			local origGetProductInfo = marketMethods.GetProductInfoAsync
			marketMethods.GetProductInfoAsync = function()
				error("Marketplace HTTP timeout")
			end
			sert.eq(playDef.run(playCtx, 888777), "Invalid audio asset.")
			sert.eq(jumpDef.run(jumpCtx, { srvP2 }, nil, 888777), "Invalid audio asset.")
			-- Transient HTTP failure must not poison audioCache
			sert.eq(playDef.env.audioCache[888777], nil)
			sert.eq(jumpDef.env.audioCache[888777], nil)
			marketMethods.GetProductInfoAsync = origGetProductInfo

			-- 3. ;shirt / ;pants / ;tshirt with nil AssetId resets/destroys applied clothing cleanly without crashing Property.override
			local shirtInst = srvP2.Character:FindFirstChildOfClass("Shirt")
			shirtInst.ShirtTemplate = "rbxassetid://555"
			c.runSrv(";shirt TargetPlr 1100")
			sert.eq(string.find(shirtInst.ShirtTemplate, "1100", 1, true) ~= nil, true)
			c.runSrv(";shirt TargetPlr") -- omitted AssetId == nil
			sert.eq(shirtInst.ShirtTemplate, "rbxassetid://555")

			-- Character originally without Shirt: created Shirt is destroyed on omitted AssetId, and bare ;shirt on shirtless character is a safe no-op
			shirtInst:Destroy()
			sert.eq(srvP2.Character:FindFirstChildOfClass("Shirt"), nil)
			c.runSrv(";shirt TargetPlr")
			sert.eq(srvP2.Character:FindFirstChildOfClass("Shirt"), nil)
			c.runSrv(";shirt TargetPlr 1100")
			sert.eq(srvP2.Character:FindFirstChildOfClass("Shirt") ~= nil, true)
			c.runSrv(";shirt TargetPlr")
			sert.eq(srvP2.Character:FindFirstChildOfClass("Shirt"), nil)

			-- 4. bodycolor / unbodycolor and crm / uncrm undo aliases + ForceField texture restoration
			buildCharacter(c.sh.env, srvP2, Enum.HumanoidRigType.R15)
			local bc = srvP2.Character:FindFirstChildOfClass("BodyColors")
			local origHeadColor = Color3.fromRGB(245, 205, 48)
			bc.HeadColor3 = origHeadColor
			c.runSrv(";bodycolor TargetPlr 255,0,0")
			sert.eq(bc.HeadColor3, Color3.fromRGB(255, 0, 0))
			-- ;unbodycolor with extra color arg still honors context.undo and restores original color
			c.runSrv(";unbodycolor TargetPlr 0,255,0")
			sert.eq(bc.HeadColor3, origHeadColor)

			local headPart = srvP2.Character:FindFirstChild("Head")
			headPart.TextureID = "rbxassetid://7001"
			local headSpecialMesh = headPart:FindFirstChildOfClass("SpecialMesh")
			headSpecialMesh.TextureId = "rbxassetid://7002"
			local charShirt = srvP2.Character:FindFirstChildOfClass("Shirt")
			charShirt.ShirtTemplate = "rbxassetid://7003"
			local charPants = srvP2.Character:FindFirstChildOfClass("Pants")
			charPants.PantsTemplate = "rbxassetid://7004"

			-- Opaque crm clears textures
			c.runSrv(";crm TargetPlr 255,0,0 0.25 SmoothPlastic")
			sert.eq(headPart.TextureID, "")
			sert.eq(headSpecialMesh.TextureId, "")
			sert.eq(charShirt.ShirtTemplate, "")
			sert.eq(charPants.PantsTemplate, "")

			-- Switching to ForceField restores original textures while applying ForceField
			c.runSrv(";crm TargetPlr 0,128,255 0 ForceField")
			sert.eq(headPart.Material, Enum.Material.ForceField)
			sert.eq(headPart.TextureID, "rbxassetid://7001")
			sert.eq(headSpecialMesh.TextureId, "rbxassetid://7002")
			sert.eq(charShirt.ShirtTemplate, "rbxassetid://7003")
			sert.eq(charPants.PantsTemplate, "rbxassetid://7004")

			-- ;uncrm with extra args honors context.undo and resets Material/Color/Reflectance
			c.runSrv(";uncrm TargetPlr 255,0,0 0.5 Neon")
			sert.eq(headPart.Reflectance, 0)

			-- 5. VIP single-asset PromptPurchaseFinished credits chatCommandsLower and assetDonations when verified
			local plrDonor = c.sh.env:addPlayer(55, "SingleAssetDonor")
			plrDonor:SetAttribute("_KDonationLevel", 0)
			local origOwnsAsset = marketMethods.PlayerOwnsAssetAsync
			local ownedByDonor: { [number]: boolean } = {
				[441133423] = true, -- assetDonations[1] -> level 1
				[115403290087767] = true, -- chatCommandsLower[2] (Patron) -> level 2
				[110019084552349] = true, -- chatCommands -> level 4
			}
			marketMethods.PlayerOwnsAssetAsync = function(_self, plr, id)
				if plr == plrDonor then
					return ownedByDonor[id] == true
				end
				return origOwnsAsset and origOwnsAsset(_self, plr, id) or false
			end
			_K.Service.Marketplace.PromptPurchaseFinished:Fire(plrDonor, 441133423, true)
			c.world:run(0.5)
			sert.eq(plrDonor:GetAttribute("_KDonationLevel"), 1)

			_K.Service.Marketplace.PromptPurchaseFinished:Fire(plrDonor, 115403290087767, true)
			c.world:run(0.5)
			sert.eq(plrDonor:GetAttribute("_KDonationLevel"), 2)

			_K.Service.Marketplace.PromptPurchaseFinished:Fire(plrDonor, 110019084552349, true)
			c.world:run(0.5)
			sert.eq(plrDonor:GetAttribute("_KDonationLevel"), 4)
			marketMethods.PlayerOwnsAssetAsync = origOwnsAsset

			-- 6. antilag resets MeshPart.TextureID and survives destroyed hidden instances on unantilag
			local origDeferWait = clientK.Util.Defer.wait
			clientK.Util.Defer.wait = function() end
			local worldMesh = c.ch1.env.Instance.new("MeshPart", c.ch1.env.workspace)
			worldMesh.Material = Enum.Material.Brick
			worldMesh.TextureID = "rbxassetid://424242"
			local worldDecalHolder = c.ch1.env.Instance.new("Part", c.ch1.env.workspace)
			local worldDecal = c.ch1.env.Instance.new("Decal", worldDecalHolder)
			local destroyedDecal = c.ch1.env.Instance.new("Decal", worldDecalHolder)
			sert.eq(worldDecal.Parent, worldDecalHolder)

			_K.Remote.AntiLag:Fire(srvP1, false)
			c.world:run(0.1)
			sert.eq(worldMesh.Material, Enum.Material.SmoothPlastic)
			sert.eq(worldMesh.TextureID, "")
			sert.eq(worldDecal.Parent, nil)
			sert.eq(destroyedDecal.Parent, nil)

			-- Destroy one hidden decal so its Parent is locked (throws on reparent), then verify unantilag still restores worldDecal
			destroyedDecal:Destroy()
			local okLocked = pcall(function()
				destroyedDecal.Parent = worldDecalHolder
			end)
			sert.eq(okLocked, false)
			_K.Remote.AntiLag:Fire(srvP1, true)
			c.world:run(0.1)
			clientK.Util.Defer.wait = origDeferWait
			sert.eq(worldMesh.Material, Enum.Material.Brick)
			sert.eq(worldMesh.TextureID, "rbxassetid://424242")
			sert.eq(worldDecal.Parent, worldDecalHolder)
			worldMesh:Destroy()
			worldDecalHolder:Destroy()

			-- 7. createteam / editteam / removeteam: optional preservation, duplicate checks, nil safety, BrickColor.palette, RichText escaping, and nil fromPlayer safety
			local teams = c.sh.env.game:GetService("Teams")
			for _, t in teams:GetChildren() do
				t:Destroy()
			end
			local teamCtx = { _K = _K, from = 1, fromPlayer = srvP1, global = true, args = {} }
			local createTeamRun = _K.Registry.commands.createteam.run
			local editTeamRun = _K.Registry.commands.editteam.run
			local removeTeamRun = _K.Registry.commands.removeteam.run

			local lastNotifyText = ""
			local origNotifyFire = _K.Remote.Notify.Fire
			_K.Remote.Notify.Fire = function(selfRemote, plr, payload)
				if type(payload) == "table" and type(payload.Text) == "string" then
					lastNotifyText = payload.Text
				end
				return origNotifyFire(selfRemote, plr, payload)
			end

			sert.eq(createTeamRun(teamCtx, "<b>Alpha&One</b>", Color3.fromRGB(255, 0, 0), false), nil)
			sert.eq(string.find(lastNotifyText, "&lt;b&gt;Alpha&amp;One&lt;/b&gt;", 1, true) ~= nil, true)
			local alphaTeam = teams:FindFirstChild("<b>Alpha&One</b>")
			sert.eq(alphaTeam ~= nil, true)
			local origAlphaBrickColor = alphaTeam.TeamColor
			sert.eq(alphaTeam.AutoAssignable, false)

			sert.eq(createTeamRun(teamCtx, "BravoTeam", Color3.fromRGB(0, 0, 255), true), nil)
			local bravoTeam = teams:FindFirstChild("BravoTeam")

			-- editteam preserves TeamColor and AutoAssignable when omitted
			sert.eq(editTeamRun(teamCtx, alphaTeam, "AlphaRenamed", nil, nil), nil)
			sert.eq(alphaTeam.Name, "AlphaRenamed")
			sert.eq(alphaTeam.TeamColor, origAlphaBrickColor)
			sert.eq(alphaTeam.AutoAssignable, false)

			-- editteam rejects name and color collisions with BravoTeam
			sert.eq(
				string.find(tostring(editTeamRun(teamCtx, alphaTeam, "bravoteam", nil, nil)), "already exists", 1, true)
					~= nil,
				true
			)
			sert.eq(
				string.find(
					tostring(editTeamRun(teamCtx, alphaTeam, "AlphaRenamed", bravoTeam.TeamColor.Color, nil)),
					"already in use",
					1,
					true
				) ~= nil,
				true
			)

			-- editteam and removeteam safely handle nil team without crashing
			sert.eq(editTeamRun(teamCtx, nil, "Missing", nil, nil), nil)
			removeTeamRun(teamCtx, nil)

			-- Ban notification escapes RichText in ban reason
			_K.Registry.commands.ban.run(
				{ _K = _K, from = 1, fromPlayer = srvP1, global = true, args = {} },
				{ 2 },
				0,
				"<font color='bad'>Exploit & Spam"
			)
			sert.eq(string.find(lastNotifyText, "&lt;font", 1, true) ~= nil, true)
			sert.eq(string.find(lastNotifyText, "Exploit &amp; Spam", 1, true) ~= nil, true)
			_K.Data.bans["2"] = nil
			_K.Remote.Notify.Fire = origNotifyFire

			-- Nil fromPlayer under global context does not crash serverlock / bring / to / join / rejoin / spectate
			local globalNilCtx = { _K = _K, from = 0, fromPlayer = nil, global = true, args = {} }
			_K.Registry.commands.serverlock.run(globalNilCtx)
			sert.eq(_K._serverLock ~= nil, true)
			_K._serverLock = nil
			_K.Registry.commands.bring.run(globalNilCtx, { srvP2 })
			_K.Registry.commands.to.run(globalNilCtx, srvP2)
			_K.Registry.commands.join.run(globalNilCtx, 2)
			_K.Registry.commands.rejoin.run(globalNilCtx)
			_K.Registry.commands.spectate.run(
				{ _K = _K, env = _K.Registry.commands.spectate.env, from = 0, fromPlayer = nil, global = true },
				srvP2
			)

			-- 8. ;emotes preview click before CreateHumanoidModelFromUserId resolves queues preview without crashing
			local cliPlayersMethods = rawget(c.ch1.env.Players, "_methods")
			local origCreateModel = cliPlayersMethods.CreateHumanoidModelFromUserId
			local previewRigReady = false
			cliPlayersMethods.CreateHumanoidModelFromUserId = function(selfPlr, uid)
				while not previewRigReady do
					c.ch1.env.task.wait(0.05)
				end
				return origCreateModel(selfPlr, uid)
			end
			clientK.Data.emoteItemFromId[7777] = {
				emoteId = 7777,
				animationId = 8888,
				name = "QueuedDance",
				nameLower = "queueddance",
				owned = false,
			}
			-- Re-run setup via fresh emote envClient in ch1
			local utilityDefs = c.ch1.env:require(c.ch1.Shared.DefaultCommands.Utility)
			local emoteDefCli
			for _, d in utilityDefs do
				if d.name == "emote" then
					emoteDefCli = d
					break
				end
			end
			local freshEmoteEnv = emoteDefCli.envClient(clientK)
			-- Calling updatePreview even before task.defer runs and while CreateHumanoidModelFromUserId yields must not throw
			freshEmoteEnv.updatePreview(7777)
			c.world:run(0.05)
			sert.eq(freshEmoteEnv.preview ~= nil, true)
			sert.eq(freshEmoteEnv.preview.Visible, true)
			sert.eq(freshEmoteEnv.preview.Title.Text, "QueuedDance")
			previewRigReady = true
			c.world:run(0.2)
			cliPlayersMethods.CreateHumanoidModelFromUserId = origCreateModel

			-- 9. link / unlink deferred race, cleanup[player], and localPlayer.Character == nil stream-in
			local cliLinkDef = clientK.Registry.commands.link
			local cliUnlinkDef = clientK.Registry.commands.unlink
			local cliP1 = c.ch1.env.Players.LocalPlayer
			local cliP3 = c.ch1.env:addPlayer(33, "RaceTarget")
			local charP1 = buildCharacter(c.ch1.env, cliP1)
			cliP1.Character = charP1
			charP1.Parent = c.ch1.env.workspace
			local charP3 = buildCharacter(c.ch1.env, cliP3)
			cliP3.Character = charP3
			charP3.Parent = c.ch1.env.workspace

			cliLinkDef.runClient({ _K = clientK, env = cliLinkDef.env, from = 1 }, { cliP3 }, true)
			sert.eq(charP3.HumanoidRootPart:FindFirstChild("_KLink") ~= nil, true)
			sert.eq(cliLinkDef.env.cleanup[cliP3] ~= nil, true)

			-- Queue deferred re-link via CharacterAdded, then immediately unlink before deferred runs
			local respawnCharP3 = buildCharacter(c.ch1.env, cliP3)
			cliP3.Character = respawnCharP3
			respawnCharP3.Parent = c.ch1.env.workspace
			cliP3.CharacterAdded:Fire(respawnCharP3)
			cliUnlinkDef.runClient({ _K = clientK, env = cliLinkDef.env, from = 1 }, { cliP3 })
			c.world:run(0.1)
			sert.eq(respawnCharP3.HumanoidRootPart:FindFirstChild("_KLink"), nil)
			sert.eq(cliLinkDef.env.active[cliP3], nil)
			sert.eq(cliLinkDef.env.cleanup[cliP3], nil)

			-- Link while localPlayer.Character == nil watches localPlayer.CharacterAdded and links on spawn
			cliP1.Character = nil
			cliLinkDef.runClient({ _K = clientK, env = cliLinkDef.env, from = 1 }, { cliP3 }, false)
			sert.eq(respawnCharP3.HumanoidRootPart:FindFirstChild("_KLink"), nil)
			local spawnedLocalChar = buildCharacter(c.ch1.env, cliP1)
			cliP1.Character = spawnedLocalChar
			spawnedLocalChar.Parent = c.ch1.env.workspace
			cliP1.CharacterAdded:Fire(spawnedLocalChar)
			c.world:run(0.1)
			sert.eq(respawnCharP3.HumanoidRootPart:FindFirstChild("_KLink") ~= nil, true)
			cliUnlinkDef.runClient({ _K = clientK, env = cliLinkDef.env, from = 1 }, { cliP3 })

			-- 10. tts ignores RichText-only empty strings and cleans up instances when LoadAsync errors
			local beforeChildren = #c.ch1.env.workspace:GetChildren()
			c.runSrv(';tts "British male" "<b>   </b>"')
			c.world:run(0.1)
			sert.eq(#c.ch1.env.workspace:GetChildren(), beforeChildren)

			-- Force AudioTextToSpeech:LoadAsync to throw and verify no Wire / AudioTextToSpeech leaks in workspace
			local ttsConn = c.ch1.env.workspace.DescendantAdded:Connect(function(inst)
				if inst.ClassName == "AudioTextToSpeech" then
					local m = rawget(inst, "_methods") or {}
					m.LoadAsync = function()
						error("TTS LoadAsync failure")
					end
					rawset(inst, "_methods", m)
				end
			end)
			c.world:run(61)
			c.runSrv(';tts "British male" "Hello world"')
			c.world:run(0.1)
			ttsConn:Disconnect()
			for _, child in c.ch1.env.workspace:GetChildren() do
				sert.eq(child.ClassName ~= "AudioTextToSpeech", true)
				sert.eq(child.ClassName ~= "AudioDeviceOutput", true)
				sert.eq(child.ClassName ~= "Wire", true)
			end
		end
	)
end)

do
	return {}
end
