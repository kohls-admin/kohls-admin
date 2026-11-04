local _K = require(script.Parent.Parent)
local UI = require(script.Parent:WaitForChild("UI"))

--stylua: ignore
local ExplorerOrder = {Accessory=30,AccessoryDescription=22,Accoutrement=20,Actor=10,AdGui=200,AdPlacement=200,AdPortal=200,AirController=20,AlignOrientation=30,AlignPosition=30,AngularVelocity=30,Animation=220,AnimationConstraint=30,AnimationController=220,AnimationTrack=220,Animator=220,ArcHandles=200,Atmosphere=5,AtmosphereSensor=20,Attachment=30,AudioAnalyzer=10,AudioChannelMixer=10,AudioChannelSplitter=10,AudioChorus=10,AudioCompressor=10,AudioDeviceInput=10,AudioDeviceOutput=10,AudioDistortion=10,AudioEcho=10,AudioEmitter=10,AudioEqualizer=10,AudioFDNReverb=10,AudioFader=10,AudioFilter=10,AudioFlanger=10,AudioGate=10,AudioLimiter=10,AudioListener=10,AudioPitchShifter=10,AudioPlayer=10,AudioRecorder=10,AudioReverb=10,AudioSpeechToText=10,AudioStreamReader=10,AudioStreamWriter=10,AudioTextToSpeech=10,AudioTremolo=10,AudioWindSynthesizer=10,AuroraScript=50,AvatarAccessoryRules=20,AvatarAnimationRules=20,AvatarBodyRules=20,AvatarClothingRules=20,AvatarCollisionRules=20,AvatarRules=20,Backpack=30,BackpackItem=20,BallSocketConstraint=30,BasePart=3,Beam=30,BillboardGui=140,BindableEvent=50,BindableFunction=40,BlockMesh=30,BloomEffect=20,BlurEffect=20,BodyAngularVelocity=140,BodyColors=20,BodyForce=140,BodyGyro=140,BodyPartDescription=22,BodyPosition=140,BodyThrust=140,BodyVelocity=140,Bone=30,BoolValue=30,BoxHandleAdornment=205,BrickColorValue=30,BubbleChatConfiguration=13,BuoyancySensor=20,CFrameValue=30,Camera=5,CanvasGroup=200,ChannelTabsConfiguration=12,CharacterMesh=220,Chat=510,ChatInputBarConfiguration=11,ChatService=510,ChatWindowConfiguration=10,ChorusSoundEffect=20,ClickDetector=30,ClimbController=20,Clothing=20,Clouds=5,Color3Value=30,ColorCorrectionEffect=20,ColorGradingEffect=20,CompressorSoundEffect=20,ConeHandleAdornment=205,Configuration=220,Constraint=30,ControlState=31,ControllerManager=20,ControllerPartSensor=20,CoreGui=30,CorePackages=30,CornerWedgePart=120,CustomEvent=30,CustomEventReceiver=30,CylinderHandleAdornment=205,CylinderMesh=30,CylindricalConstraint=30,DebugSettings=20,Decal=40,DepthOfFieldEffect=20,Dialog=220,DialogChoice=220,DistortionSoundEffect=20,DoubleConstrainedValue=30,DragDetector=30,EchoSoundEffect=20,EqualizerSoundEffect=20,Explosion=30,FaceControls=105,Feature=20,Fire=30,Flag=30,FlagStand=30,FlangeSoundEffect=20,FloorWire=30,FluidForceSensor=20,Folder=10,ForceField=30,Frame=150,FunctionalTest=10,GameSettings=20,GeneratedFolder=10,GlobalDataStore=-1,GlobalSettings=20,GroundController=20,GuiButton=160,GuiMain=140,HandRigDescription=222,Handles=190,HapticEffect=100,Hat=30,Highlight=20,HingeConstraint=30,Hint=110,Hole=20,Hopper=20,HopperBin=240,Humanoid=30,HumanoidDescription=22,HumanoidRigDescription=220,IKControl=220,ImageButton=160,ImageHandleAdornment=205,ImageLabel=180,InputAction=31,InputActionLabel=185,InputContext=31,InputBinding=31,IntConstrainedValue=30,IntValue=30,Item=20,JointInstance=200,Keyframe=220,KeyframeMarker=220,Light=30,Lighting=30,LineForce=30,LineHandleAdornment=205,LinearVelocity=30,LocalScript=40,LocalizationService=530,LocalizationTable=30,MakeupDescription=22,MaterialService=30,MaterialVariant=41,MeshPart=105,Message=110,Model=100,ModuleScript=50,Motor=20,Motor6D=200,NegateOperation=104,NetworkClient=30,NetworkReplicator=30,NetworkServer=30,NetworkSettings=20,NoCollisionConstraint=30,NumberPose=220,NumberValue=30,ObjectValue=30,OrderedDataStore=-1,PackageLink=1,Pants=20,ParallelRampPart=120,Part=110,PartPairLasso=220,ParticleEmitter=30,ParticleEmitter2D=30,Path2D=31,PathfindingLink=210,PathfindingModifier=210,PhysicsActivitySensor=20,PitchShiftSoundEffect=20,Plane=30,PlaneConstraint=30,Platform=30,PlatformLibraries=30,Player=10,PlayerGui=130,PlayerScripts=130,Players=20,Plugin=30,PluginCapabilities=30,PluginDebugService=30,PluginGuiService=30,PointLight=30,Pose=220,PoseBase=220,Preloaded=30,PrismPart=120,PrismaticConstraint=30,ProceduralModel=100,ProximityPrompt=30,PyramidHandleAdornment=205,PyramidPart=120,RayValue=30,RemoteEvent=50,RemoteFunction=40,RenderSettings=20,RenderingTest=40,ReplicatedFirst=30,ReplicatedStorage=30,ReverbSoundEffect=20,RightAngleRampPart=120,RigidConstraint=30,RobloxPluginGuiService=30,RocketPropulsion=140,RodConstraint=30,RopeConstraint=30,ScreenGui=140,Script=30,ScrollingFrame=150,Seat=30,SelectionBox=210,SelectionPartLasso=220,SelectionPointLasso=220,SelectionSphere=210,Shirt=20,ShirtGraphic=20,SkateboardPlatform=30,Skin=20,Sky=5,SlidingBallConstraint=30,Smoke=30,Snap=200,Sound=10,SoundGroup=20,SoundService=500,Sparkles=30,SpawnLocation=30,SpecialMesh=30,SphereHandleAdornment=205,SpotLight=30,SpringConstraint=30,StandalonePluginScripts=130,StarterCharacterScripts=130,StarterGear=30,StarterGui=30,StarterPack=30,StarterPlayer=30,StarterPlayerScripts=130,Status=100,StockSound=-1,StringValue=30,StyleBase=200,StyleDerive=200,StyleLink=200,StyleQuery=200,StyleRule=200,StyleSheet=200,SunRaysEffect=20,SurfaceAppearance=40,SurfaceGui=140,SurfaceGuiBase=140,SurfaceLight=30,SurfaceSelection=210,SwimController=20,Team=10,Teams=140,Terrain=5,TerrainDetail=42,TerrainRegion=20,TestService=1000,TextBox=170,TextButton=170,TextChannel=14,TextChannelWindow=16,TextChatCommand=15,TextChatService=511,TextDocument=55,TextLabel=190,TextSource=10,Texture=40,Tool=30,Torque=30,TorsionSpringConstraint=30,TouchTransmitter=30,Trail=30,TremoloSoundEffect=20,TrussPart=120,UIAspectRatioConstraint=30,UICorner=30,UIDragDetector=30,UIFlexItem=130,UIGradient=30,UIGridLayout=30,UIListLayout=30,UIPadding=30,UIPageLayout=30,UIScale=30,UIShadow=30,UISizeConstraint=30,UIStroke=30,UITableLayout=30,UITextSizeConstraint=30,UnionOperation=105,UniversalConstraint=30,UnreliableRemoteEvent=51,VRService=1000,ValueBase=30,Vector3Value=30,VectorForce=30,VehicleSeat=30,VideoDisplay=10,VideoFrame=18,VideoPlayer=10,ViewportCamera=5,ViewportFrame=30,VoiceChatService=520,WedgePart=120,Weld=200,WeldConstraint=30,Wire=10,WireframeHandleAdornment=205,Workspace=5,WorldModel=22,WrapDeformer=32,WrapLayer=32,WrapTarget=32,WrapTextureTransfer=33}

local ContentProvider = game:GetService("ContentProvider")
local Reflection = game:GetService("ReflectionService")

local DragScope = {
	Active = false,
	StartPos = Vector3.zero,
	Ghost = nil :: Instance?,
	TargetNode = nil,
}

local CLIPBOARD = {}
local SELECTION = {}
local SHOW_HIDDEN = false
local NODES = setmetatable({ [game] = { AncestorExpanded = true, Expanded = true, Instance = game } }, { __mode = "k" })

local scroller, updateListThrottled

local function isService(instance: Instance)
	local class = Reflection:GetClass(instance.ClassName)
	return class and class.Permits and class.Permits.GetService
end

local function setAncestorExpanded(node, value)
	local v = if node.Expanded then value else false
	for _, child in node.Instance:GetChildren() do
		local childNode = NODES[child]
		if childNode then
			childNode.AncestorExpanded = v
			setAncestorExpanded(childNode, v)
		end
	end
end

local function getFallbackIcon(instance: Instance)
	local path = if isService(instance)
		then "InsertableObjects/Dark/Standard/Service"
		else "Placeholder/Dark/Standard/Placeholder"

	return `rbxasset://studio_svg_textures/Shared/{path}.png`
end

local classIcons = {}
local function getClassIcon(instance: Instance)
	local existing = classIcons[instance.ClassName]
	if existing ~= nil then
		return existing or getFallbackIcon(instance)
	end

	return `rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/{instance.ClassName}.png`
end

local function setClassIcon(item, instance: Instance)
	local existing = classIcons[instance.ClassName]
	if existing ~= nil then
		item._instance.IconFrame.ImageLabel.Image = existing or getFallbackIcon(instance)
		return
	end

	item._instance.IconFrame.ImageLabel.Image =
		"rbxasset://studio_svg_textures/Shared/Placeholder/Dark/Standard/Placeholder.png"

	local texture = `rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/{instance.ClassName}.png`
	local decal = Instance.new("Decal")
	decal.Texture = texture

	task.spawn(
		ContentProvider.PreloadAsync,
		ContentProvider,
		{ decal },
		function(path: string, Status: Enum.AssetFetchStatus)
			if Status == Enum.AssetFetchStatus.Success then
				classIcons[instance.ClassName] = path
				if item.node.Instance == instance then
					item._instance.IconFrame.ImageLabel.Image = path
				end
			elseif Status == Enum.AssetFetchStatus.Failure or Status == Enum.AssetFetchStatus.TimedOut then
				classIcons[instance.ClassName] = false
				if item.node.Instance == instance then
					item._instance.IconFrame.ImageLabel.Image = getFallbackIcon(instance)
				end
			end
		end
	)
end

local function sortChildren(a, b)
	local orderA = ExplorerOrder[a.ClassName]
	local orderB = ExplorerOrder[b.ClassName]
	if orderA and orderB and orderA ~= orderB then
		return orderA < orderB
	end
	if a.ClassName == b.ClassName then
		return a.Name < b.Name
	end
	return a.ClassName < b.ClassName
end

local function sortNodes(A: Instance, B: Instance)
	local a, b = NODES[A], NODES[B]
	if not a or not b then
		return false
	end
	return a.Index < b.Index
end

local function traverse(instance: Instance, index: number, traverseAll: boolean?)
	local node = NODES[instance]
	if not node or not (node.AncestorExpanded or traverseAll) then
		return index
	end

	node.Index = index

	local children = instance:GetChildren()
	table.sort(children, sortChildren)

	for _, child in children do
		index = traverse(child, index + 1, traverseAll)
	end

	return index
end

local function instanceRemoving(instance: Instance)
	local parentNode = instance.Parent and NODES[instance.Parent]
	if parentNode and parentNode.Expanded then
		updateListThrottled(scroller)
	end
end

local function check(instance: Instance)
	return instance.AncestryChanged
end

local function isAncestorExpanded(instance: Instance)
	if instance == game then
		return true
	end

	local parent = instance.Parent
	while parent do
		if parent == game then
			return true
		end
		local node = NODES[parent]
		if node and not node.Expanded then
			return false
		end
		parent = parent.Parent
	end

	return false
end

local function removeNode(instance)
	local node = NODES[instance]
	if node then
		if _K and _K.Flux and _K.Flux.dispose then
			_K.Flux.dispose(node)
		end
		NODES[instance] = nil
	end

	for _, descendant in instance:GetDescendants() do
		local descNode = NODES[descendant]
		if descNode then
			if _K and _K.Flux and _K.Flux.dispose then
				_K.Flux.dispose(descNode)
			end
			NODES[descendant] = nil
		end
	end
end

local function instanceAdded(instance: Instance, parent: Instance?)
	if not pcall(check, instance) then
		return
	end

	if not parent then
		parent = instance.Parent
	end

	if not parent then
		local node = NODES[instance]
		if node then
			removeNode(instance)
			if isAncestorExpanded(instance) then
				updateListThrottled(scroller)
			end
		end
		return
	end

	local tree, currParent = { instance }, parent
	while currParent do
		table.insert(tree, currParent)
		currParent = currParent.Parent
	end

	for i = #tree - 1, 1, -1 do
		local obj = tree[i]
		local objNode = NODES[obj]
		if not objNode then
			objNode = {
				AncestorExpanded = isAncestorExpanded(obj),
				Expanded = false,
				Selected = false,
				Instance = obj,
				Index = 0,
			}
			NODES[obj] = objNode
		end
		objNode.Depth = (#tree - i) - 1
	end

	local node = NODES[instance]
	if node then
		node.AncestorExpanded = isAncestorExpanded(instance)
		if not node.Connection then
			node.Connection = true

			local _ = instance.AncestryChanged:Connect(instanceAdded)
			local _ = instance.Destroying:Connect(function()
				local parentNode = instance.Parent and NODES[instance.Parent]
				if parentNode and parentNode.Expanded then
					updateListThrottled(scroller)
				end
				removeNode(instance)
			end)
		end
	end

	local parentNode = NODES[parent]
	if parentNode and parentNode.Expanded then
		updateListThrottled(scroller)
	end
end

local function parentInstanceUnsafe(instance: Instance, parent: Instance?)
	instance.Parent = parent
end

local function cloneInstanceUnsafe(instance, parent: Instance?)
	local clone = instance:Clone()
	clone.Parent = parent

	return clone
end

local function COPY()
	table.clear(CLIPBOARD)
	for _, node in SELECTION do
		if pcall(cloneInstanceUnsafe, node.Instance) then
			table.insert(CLIPBOARD, node.Instance)
		end
	end
end

local function DELETE()
	local instances = table.create(#SELECTION)
	for _, node in SELECTION do
		table.insert(instances, node.Instance)
	end
	_K.Remote.Explorer:Fire("DELETE", instances)

	for _, node in SELECTION do
		if node.Instance:IsA("Player") then
			continue
		end
		local _ = pcall(game.Destroy, node.Instance)
	end
	table.clear(SELECTION)
end

local function PASTE()
	local selected = SELECTION[1]
	if not selected or not selected.Instance or not next(CLIPBOARD) then
		return
	end
	_K.Remote.Explorer:Fire("PASTE", CLIPBOARD, selected.Instance)

	if not selected.Expanded then
		selected.Expanded = true
		setAncestorExpanded(selected, true)
	end

	updateListThrottled(scroller)
end

local titleBarHeight = UI.computed(function()
	return UI.Theme.FontSize() + UI.Theme.Padding().Offset * 2
end)

local titleBarButtonSize = function()
	return UDim2.fromOffset(titleBarHeight(), titleBarHeight())
end

local function Initialize()
	local Explorer = UI.new "Window" {
		Parent = UI.LayerTopInset,
		Icon = "rbxassetid://71961243872230",
		Name = "Explorer",
		Title = "Explorer",

		UI.list {
			gap = UI.Theme.Padding,
		},
	}

	local titleBar = Explorer._instance.Frame.TitleBar

	local deleteButton = UI.new "Button" {
		Parent = titleBar,
		LayoutOrder = 4,
		Icon = UI.Theme.Image.Delete,
		IconProperties = {
			ImageColor3 = UI.Theme.PrimaryText,
			Size = UDim2.fromScale(0.625, 0.625),
		},
		Size = titleBarButtonSize,

		Activated = DELETE,
	}
	UI.new "Tooltip" { Parent = deleteButton, Hovering = deleteButton._hovering, Text = "Delete" }

	local copyButton = UI.new "Button" {
		Parent = titleBar,
		LayoutOrder = 6,
		Icon = UI.Theme.Image.Copy,
		IconProperties = {
			ImageColor3 = UI.Theme.PrimaryText,
			Size = UDim2.fromScale(0.625, 0.625),
		},
		Size = titleBarButtonSize,

		Activated = COPY,
	}
	UI.new "Tooltip" { Parent = copyButton, Hovering = copyButton._hovering, Text = "Copy" }

	local pasteButton = UI.new "Button" {
		Parent = titleBar,
		LayoutOrder = 7,
		Icon = UI.Theme.Image.Paste,
		IconProperties = {
			ImageColor3 = UI.Theme.PrimaryText,
			Size = UDim2.fromScale(0.625, 0.625),
		},
		Size = titleBarButtonSize,

		Activated = PASTE,
	}
	UI.new "Tooltip" { Parent = pasteButton, Hovering = pasteButton._hovering, Text = "Paste" }

	local itemSize = UDim2.new(1, 0, 0, 20)

	local function createGhost()
		if DragScope.Ghost then
			DragScope.Ghost:Destroy()
		end

		local ghost = UI.new "Frame" {
			Parent = UI.LayerTop,
			BackgroundTransparency = 1,
			Active = false,
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.new(),

			UI.list(),
		}

		for i, node in SELECTION do
			if node.Depth > 0 then
				UI.new "Frame" {
					LayoutOrder = i,
					Parent = ghost,
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					Size = UDim2.new(0, 0, 0, 20),

					UI.list {
						direction = "x",
						verticalAlign = "center",
					},

					UI.new "Frame" {
						Name = "IconFrame",
						BackgroundTransparency = 1,
						Size = UDim2.fromOffset(20, 20),

						UI.new "ImageLabel" {
							BackgroundTransparency = 1,
							AnchorPoint = Vector2.new(0, 0.5),
							Position = UDim2.fromScale(0, 0.5),
							Size = UDim2.fromOffset(16, 16),
							Image = getClassIcon(node.Instance),
							ImageTransparency = 0.25,
						},
					},

					UI.new "TextLabel" {
						AutomaticSize = Enum.AutomaticSize.X,
						BackgroundTransparency = 1,
						Font = Enum.Font.SourceSans,
						Text = node.Instance.Name,
						TextSize = 16,
						TextColor3 = UI.Theme.PrimaryText,
						TextStrokeColor3 = UI.Theme.Primary,
						TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
						TextTransparency = 0.25,
						TextTruncate = Enum.TextTruncate.SplitWord,
						Size = UDim2.new(0, 0, 1, 0),
						TextXAlignment = Enum.TextXAlignment.Left,
					},
				}
			end
		end

		DragScope.Ghost = ghost
	end

	local function updateGhost(position: Vector3)
		if DragScope.Ghost then
			DragScope.Ghost.Position = UDim2.fromOffset(position.X + 6, position.Y - 10 + UI.TopbarInset:peek().Height)
		end
	end

	local function executeReparent()
		if not DragScope.TargetNode or not DragScope.TargetNode.Instance then
			return
		end

		local target = DragScope.TargetNode.Instance
		local changed = false

		for _, node in SELECTION do
			local inst = node.Instance
			if inst ~= target and not isService(inst) and not target:IsDescendantOf(inst) and inst.Parent ~= target then
				local ok = pcall(parentInstanceUnsafe, inst, target)
				if ok then
					changed = true
				end
			end
		end

		if changed and DragScope.TargetNode then
			DragScope.TargetNode.Expanded = true
			setAncestorExpanded(DragScope.TargetNode, DragScope.TargetNode.Expanded)
			updateListThrottled(scroller)
		end
	end

	local _ = UI.UserInputService.InputChanged:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			if DragScope.Active then
				updateGhost(input.Position)
			end
		end
	end)

	local _ = UI.UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if DragScope.Active then
				executeReparent()
				DragScope.Active = false
				DragScope.TargetNode = nil
				if DragScope.Ghost then
					DragScope.Ghost:Destroy()
					DragScope.Ghost = nil
				end
			end
		end
	end)

	local _ = UI.UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed or not Explorer._instance.Visible then
			return
		end
		if input.UserInputType == Enum.UserInputType.Keyboard then
			local ctrl = UI.UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
			if input.KeyCode == Enum.KeyCode.C and ctrl then
				COPY()
			elseif input.KeyCode == Enum.KeyCode.V and ctrl then
				PASTE()
			elseif input.KeyCode == Enum.KeyCode.Delete then
				DELETE()
			end
		end
	end)

	scroller = UI.new "ScrollerFast" {
		Parent = Explorer,
		List = NODES,
		DictList = true,
		Enabled = true,
		FilterInput = true,
		Visible = true,
		ItemSize = itemSize,
		CreateItem = function(self)
			local item: { [string]: any } = {}
			local lastActivate = 0
			item._instance = UI.new "TextButton" {
				Parent = Explorer._content,
				AutoButtonColor = false,
				BackgroundColor3 = UI.Theme.Secondary,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				TextTransparency = 1,
				Size = itemSize,

				UI.padding(0),

				UI.list {
					direction = "x",
					verticalAlign = "center",
				},

				UI.new "TextButton" {
					Name = "Expand",
					BackgroundTransparency = 1,
					TextTransparency = 1,
					Size = UDim2.fromOffset(20, 20),

					UI.new "ImageLabel" {
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						BackgroundTransparency = 1,
						Size = UDim2.fromOffset(8, 8),
						Image = UI.Theme.Image.Down,
						Rotation = -90,
					},

					Activated = function()
						if item._instance.Expand.ImageLabel.Visible then
							item.node.Expanded = not item.node.Expanded
							setAncestorExpanded(item.node, item.node.Expanded)

							scroller:refreshList()
						end
					end,
				},

				UI.new "Frame" {
					Name = "IconFrame",
					BackgroundTransparency = 1,
					Size = UDim2.fromOffset(20, 20),

					UI.new "ImageLabel" {
						BackgroundTransparency = 1,
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.fromScale(0, 0.5),
						Size = UDim2.fromOffset(16, 16),
						Image = UI.Theme.Image.Add,
					},
				},

				UI.new "TextLabel" {
					BackgroundTransparency = 1,
					Font = Enum.Font.SourceSans,
					TextSize = 16,
					TextColor3 = UI.Theme.PrimaryText,
					TextStrokeColor3 = UI.Theme.Primary,
					TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
					TextTruncate = Enum.TextTruncate.SplitWord,
					Size = UDim2.new(1, -40, 1, 0),
					TextXAlignment = Enum.TextXAlignment.Left,
				},

				-- LOGIC START --
				Activated = function()
					if item._instance.Expand.ImageLabel.Visible then
						local last = lastActivate
						lastActivate = os.clock()
						if lastActivate - last < 0.3 then
							item.node.Expanded = not item.node.Expanded
							setAncestorExpanded(item.node, item.node.Expanded)
							scroller:refreshList()
							return
						end
					end

					local ctrl = UI.UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
					local shift = UI.UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)

					if ctrl or shift then -- Toggle selection
						item.node.Selected = not item.node.Selected
						if item.node.Selected then
							table.insert(SELECTION, item.node)
							item.selected(true)
						else
							local idx = table.find(SELECTION, item.node)
							if idx then
								table.remove(SELECTION, idx)
								item.selected(false)
							end
						end
					else -- Single select
						for _, v in scroller._lineItemCache do
							v.selected(false)
						end
						for _, v in scroller._lineItemFree do
							v.selected(false)
						end
						for _, v in SELECTION do
							v.Selected = false
						end
						table.clear(SELECTION)

						item.node.Selected = true
						table.insert(SELECTION, item.node)
						item.selected(true)
					end
					UI.flush()
				end,

				TouchLongPress = function(input, processed)
					DragScope.StartPos = input.Position
				end,

				InputBegan = function(input, processed)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						DragScope.StartPos = input.Position
					end
				end,

				InputChanged = function(input, processed)
					if input.UserInputType == Enum.UserInputType.MouseMovement then
						if
							not DragScope.Active
							and UI.UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
							and item.node
							and item.node.Depth > 0
						then
							local delta = (input.Position - DragScope.StartPos).Magnitude
							if delta > 5 then
								DragScope.Active = true

								if item.node and not item.node.Selected then
									for _, v in SELECTION do
										v.Selected = false
									end
									table.clear(SELECTION)
									item.node.Selected = true
									table.insert(SELECTION, item.node)
									scroller:refreshList()
								end

								createGhost()
								updateGhost(input.Position)
							end
						end
					end
				end,
			}

			item.selected = UI.signal(false)
			item.hovering = UI.Interact.hover(item._instance, { within = true })
			local dragHoverEffect = UI.effect(UI.on(item.hovering, function(hover)
				if hover and DragScope.Active then
					DragScope.TargetNode = item.node
				end
			end, true))
			dragHoverEffect:get()
			local bgTransparency = UI.computed(function()
				local hover = item.hovering()
				if item.selected() then
					return 0.75
				end
				return if hover then 0.875 else 1
			end)
			UI.edit(item._instance)({
				BackgroundTransparency = bgTransparency,
				__CLEAN = { item.selected, item.hovering, dragHoverEffect, bgTransparency },
			})

			return item
		end,
		RenderItem = function(self, item, instance)
			local node = NODES[instance]
			if node then
				item.node = node
				item._instance.TextLabel.Text = instance.Name
				item.selected(node.Selected == true)
				UI.flush()

				setClassIcon(item, instance)
				item._instance.Expand.ImageLabel.Visible = #instance:GetChildren() > 0
				item._instance.Expand.ImageLabel.Rotation = if node.Expanded then 0 else -90
				item._instance.UIPadding.PaddingLeft = UDim.new(0, node.Depth * 10)
			end
		end,
	}

	UI.new "Tooltip" {
		Parent = scroller._input._instance.ImageLabel,
		Text = "Search uses game:QueryDescendants()",
	}

	updateListThrottled = _K.Util.Function.throttle(1, scroller.updateList)

	scroller:filter(function(self, list)
		local new = {}
		local rawFilter = scroller._input._input.Text
		local filter = rawFilter
		self._filter = filter

		local noFilter = string.find(self._filter, "^%s*$")
		local query

		if noFilter then
			for _, instance in list do
				if not ExplorerOrder[instance.ClassName] and not SHOW_HIDDEN then
					continue
				end
				local node = NODES[instance]
				if node and node.AncestorExpanded and node.Depth then
					table.insert(new, instance)
				end
			end
		else
			-- prefix names with "#"
			if string.find(filter, "^%w$") and not Reflection:GetClass(filter) then
				filter = "#" .. filter
			end

			local cache, count, ok = {}, 0, nil
			ok, query = pcall(game.QueryDescendants, game, filter)
			if not ok then
				query = {}
			end

			if #query > 0 then
				for _, instance in query do
					if not ExplorerOrder[instance.ClassName] and not SHOW_HIDDEN then
						continue
					end
					local node = NODES[instance]
					if node and node.Depth then
						count += 1
						cache[instance] = true
						local parent = instance.Parent
						while parent and parent ~= game and not cache[parent] do
							cache[parent] = true
							parent = parent.Parent
						end
					end
				end
			else
				filter = string.lower(rawFilter)
				for _, instance in list do
					if not ExplorerOrder[instance.ClassName] and not SHOW_HIDDEN then
						continue
					end
					local node = NODES[instance]
					if node and node.Depth and string.find(string.lower(instance.Name), filter, 1, true) then
						count += 1
						cache[instance] = true
						local parent = instance.Parent
						while parent and parent ~= game and not cache[parent] do
							cache[parent] = true
							parent = parent.Parent
						end
					end
				end
			end
			if count > 32 then
				new = table.create(count)
			end
			for instance in cache do
				table.insert(new, instance)
			end
		end

		traverse(game, 0, not noFilter)
		table.sort(new, sortNodes)

		return new
	end)

	UI.edit(Explorer)({ Visible = true })

	local _ = game.DescendantAdded:Connect(instanceAdded)
	local _ = game.DescendantRemoving:Connect(instanceRemoving)
	for _, instance in game:GetDescendants() do
		task.spawn(instanceAdded, instance)
	end

	return Explorer
end

local initialized = false

return {
	Show = function()
		if not initialized then
			initialized = Initialize()
		else
			UI.edit(initialized)({ Visible = true })
		end
	end,
}
