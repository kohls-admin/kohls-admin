local ClientHarness = require("./ClientHarness")
local Harness = require("./Harness")
local sert = require("../sert")

local describe, test = sert.describe, sert.test

local setupClientEnv = ClientHarness.setupClientEnv
local makeInput = ClientHarness.makeInput
local newClientEnvUI = ClientHarness.newClientUI
local observers = ClientHarness.observers

local baseGlobals = Harness.globals
local Enum = baseGlobals.Enum
local Font = baseGlobals.Font
local Color3 = baseGlobals.Color3
local UDim = baseGlobals.UDim
local UDim2 = baseGlobals.UDim2
local Vector2 = baseGlobals.Vector2
local Vector3 = baseGlobals.Vector3
local NumberRange = baseGlobals.NumberRange
local Rect = baseGlobals.Rect

describe("Client and UI", function()
	describe("Part 1 · UI Engine, Theme, Fonts & Stateful Primitives", function()
		test("registers classes, resolves fonts, manages active states, luminance, and edits instances", function()
			local world = sert.sim.new({ backing = true })
			local server = world:server()
			local client = server:client(1, "Player1")
			local cliMounted = setupClientEnv(client)

			local UI = cliMounted.env:require(cliMounted.Client.UI)
			if UI.registerClasses then
				sert.eq(UI.registerClasses(), UI)
			end
			sert.eq(rawequal(UI.new("Frame"), UI.new("Frame")), true)

			-- Double registration throws
			local okDup = pcall(function()
				UI.register("Button", UI.Class.Button)
			end)
			sert.eq(okDup, false)

			-- Fonts (Enum, family json path, known assetId, unknown assetId)
			sert.eq(UI.getFontName(Enum.Font.Gotham), "Gotham")
			sert.eq(UI.getFontName(Font.fromEnum(Enum.Font.Gotham)), "Gotham")
			sert.eq(UI.getFontName(Font.new("rbxasset://fonts/families/GothamSSm.json")), "GothamSSm")
			sert.eq(UI.getFontName(Font.fromId(12187368317)), "Akronim")
			sert.eq(UI.getFontName(Font.fromId(999999999)), nil)

			-- TopbarInset reactivity
			UI.GuiService.TopbarInset = Rect.new(0, 0, 1280, 48)
			world:step()
			sert.eq(UI.TopbarPadding().Offset, 2)
			sert.eq(UI.TopbarFrame.Visible, true)
			UI.GuiService.TopbarInset = Rect.new(0, 0, 1280, 0)
			world:step()
			sert.eq(UI.TopbarFrame.Visible, false)
			UI.GuiService.TopbarInset = Rect.new(0, 0, 1280, 36)
			world:step()
			sert.eq(UI.TopbarFrame.Visible, true)

			-- Active state management (hover, floating, dialog)
			local s1 = UI.signal(false)
			local s2 = UI.signal(false)
			local s1Changes = 0
			local s1Effect = UI.effect(function()
				s1()
				s2()
				s1Changes += 1
			end)
			s1Effect:get()
			sert.eq(s1Changes, 1)
			UI.activateState(s1, "hover")
			sert.eq(s1(), true)
			sert.eq(s1Changes, 2)
			UI.activateState(s2, "hover")
			sert.eq(s1(), false)
			sert.eq(s2(), true)

			-- Deactivating a non-matching state does not clear activeState
			UI.deactivateState(s1, "hover")
			sert.eq(rawequal(UI._activeState.hover, s2), true)

			UI.toggleState(s2, "hover")
			sert.eq(s2(), false)
			UI.toggleState(s2, "hover")
			sert.eq(s2(), true)

			local beforeDeactivate = s1Changes
			UI.deactivateState(s2, "hover")
			sert.eq(s2(), false)
			sert.eq(s1Changes, beforeDeactivate + 1)
			sert.eq(UI._activeState.hover, nil)

			UI.activateState(s1, "floating")
			UI.activateState(s2, "dialog")
			sert.eq(s1(), true)
			sert.eq(s2(), true)
			local prevS1Changes = s1Changes
			UI.clearState("floating")
			sert.eq(s1(), false)
			sert.eq(s1Changes, prevS1Changes + 1)
			sert.eq(UI._activeState.floating, nil)
			UI.clearActiveStates()
			sert.eq(s2(), false)
			sert.eq(UI._activeState.dialog, nil)
			s1Effect:Destroy()

			-- Invalid state throws
			sert.eq(pcall(UI.activateState, "not_a_state", "hover"), false)
			sert.eq(pcall(UI.deactivateState, "not_a_state", "hover"), false)
			sert.eq(pcall(UI.toggleState, "not_a_state", "hover"), false)

			-- Luminance & invertLuminance
			local blackLum = UI.getLuminance(Color3.new(0, 0, 0))
			local whiteLum = UI.getLuminance(Color3.new(1, 1, 1))
			sert.near(blackLum, 0, 5e-4)
			sert.near(whiteLum, 1, 5e-4)

			local invertedDark = UI.invertLuminance(Color3.new(0.1, 0.1, 0.1), 0.2)
			sert.eq(UI.getLuminance(invertedDark) > UI.getLuminance(Color3.new(0.1, 0.1, 0.1)), true)
			local invertedLight = UI.invertLuminance(Color3.new(0.9, 0.9, 0.9), 0.2)
			sert.eq(UI.getLuminance(invertedLight) < UI.getLuminance(Color3.new(0.9, 0.9, 0.9)), true)

			-- pointInGuiObject & sinkInput
			local frame = UI.new "Frame" {
				Parent = UI.LayerDefault,
				Position = UDim2.fromOffset(10, 20),
				Size = UDim2.fromOffset(100, 50),
			}
			local pos = frame.AbsolutePosition
			local sz = frame.AbsoluteSize
			sert.eq(UI.pointInGuiObject(pos.X, pos.Y, frame), true)
			sert.eq(UI.pointInGuiObject(pos.X + sz.X + 50, pos.Y + sz.Y + 50, frame), false)
			sert.eq(type(UI.sinkInput(0, 0, frame)), "boolean")

			-- retryGetTextBoundsAsync with retry on transient failure
			local origTextMethods = rawget(UI.TextService, "_methods")
			local attempts = 0
			rawset(UI.TextService, "_methods", {
				GetTextSize = origTextMethods.GetTextSize,
				FilterStringAsync = origTextMethods.FilterStringAsync,
				GetTextBoundsAsync = function(self, params)
					attempts += 1
					if attempts == 1 then
						error("transient TextService failure")
					end
					return origTextMethods.GetTextBoundsAsync(self, params)
				end,
			})
			local retryBounds = nil
			client:spawn(function()
				retryBounds = UI.retryGetTextBoundsAsync({ Text = "Hello", Size = 14, Width = 200 })
			end)
			world:run(3)
			sert.eq(attempts, 2)
			sert.eq(retryBounds ~= nil, true)

			-- retryGetTextBoundsAsync falls back to Vector2.zero after 5 failed attempts
			local failAttempts = 0
			rawset(UI.TextService, "_methods", {
				GetTextSize = origTextMethods.GetTextSize,
				FilterStringAsync = origTextMethods.FilterStringAsync,
				GetTextBoundsAsync = function()
					failAttempts += 1
					error("permanent TextService failure")
				end,
			})
			local fallbackBounds = nil
			client:spawn(function()
				fallbackBounds = UI.retryGetTextBoundsAsync({ Text = "Hello", Size = 14, Width = 200 })
			end)
			for _ = 1, 6 do
				world:run(1)
			end
			sert.eq(failAttempts, 5)
			sert.eq(fallbackBounds, Vector2.zero)
			rawset(UI.TextService, "_methods", origTextMethods)

			-- makeStatefulDefaults with Nil, Function, compute, and values
			local fn = function()
				return 42
			end
			local defs = UI.makeStatefulDefaults({
				a = 10,
				b = UI.Nil,
				c = UI.Function,
				d = function()
					return 99
				end,
			}, {
				a = 20,
				c = fn,
			})
			sert.eq(UI.isNode(defs.a), true)
			sert.eq(defs.a(), 20)
			sert.eq(defs.b, nil)
			sert.eq(UI.isNode(defs.c), true)
			sert.eq(defs.c(), fn)
			sert.eq(UI.isNode(defs.d), true)
			sert.eq(defs.d(), 99)
			sert.eq(#defs._createdNodes, 3)

			-- UI.textWidth
			local twSig, twMeasure = UI.textWidth(function()
				return {
					{
						Text = "<b>Hello</b>",
						Font = Font.fromEnum(Enum.Font.Gotham),
						Size = 16,
						RichText = true,
					},
				}
			end)
			sert.eq(twSig:peek() > 0, true)
			world:run(2)
			sert.eq(twSig:peek() > 0, true)
			twMeasure:Destroy()
			twSig:Destroy()

			-- newSinkHoverState (processed vs unprocessed)
			local hoverFrame = UI.new "Frame" { Parent = UI.LayerDefault }
			local hoverState = UI.newSinkHoverState(hoverFrame)
			sert.eq(UI.isNode(hoverState), true)
			sert.eq(hoverState(), false)
			UI.GuiService.MenuIsOpen = true
			hoverFrame.InputChanged:Fire(
				makeInput(
					cliMounted.env,
					{ UserInputType = Enum.UserInputType.MouseMovement, Position = Vector3.new(5, 5, 0) }
				),
				true
			)
			sert.eq(hoverState(), false)
			UI.GuiService.MenuIsOpen = false
			hoverFrame.InputChanged:Fire(
				makeInput(
					cliMounted.env,
					{ UserInputType = Enum.UserInputType.MouseMovement, Position = Vector3.new(5, 5, 0) }
				),
				false
			)
			sert.eq(hoverState(), true)
			hoverFrame.InputEnded:Fire(
				makeInput(
					cliMounted.env,
					{ UserInputType = Enum.UserInputType.MouseMovement, Position = Vector3.new(5, 5, 0) }
				)
			)
			sert.eq(hoverState(), false)
			local externalHover = UI.signal(true)
			local hoverFrame2 = UI.new "Frame" { Parent = UI.LayerDefault }
			UI.newSinkHoverState(hoverFrame2, externalHover)
			sert.eq(externalHover(), false)
			hoverFrame2:Destroy()

			-- UI.edit with numeric children (including wrapped class child & preset LayoutOrder), UI.Hook, and DefaultProperties
			local child1 = UI.new "Frame" { Name = "Child1" }
			local child2 = UI.new "TextButton" { Name = "Child2", LayoutOrder = 7 }
			local child3 = { _instance = UI.new "Frame" { Name = "Child3" } }
			local imgBtn = UI.new "ImageButton" { Name = "ImgBtn" }
			sert.eq(child2.HoverHapticEffect, UI.Haptic.Hover)
			sert.eq(imgBtn.PressHapticEffect, UI.Haptic.Click)

			local hookedVal = nil
			local customComp = {
				_instance = UI.new "Frame" {},
				_content = UI.new "Frame" {},
				MyState = UI.signal("init"),
			}
			UI.edit(customComp) {
				Name = "EditedRoot",
				[1] = child1,
				[2] = child2,
				[3] = child3,
				[UI.Hook] = {
					MyState = function(v)
						hookedVal = v
					end,
				},
			}
			sert.eq(customComp._instance.Name, "EditedRoot")
			sert.eq(child1.Parent, customComp._content)
			sert.eq(child1.LayoutOrder, 1)
			sert.eq(child2.LayoutOrder, 7)
			sert.eq(child3._instance.Parent, customComp._content)
			sert.eq(child3._instance.LayoutOrder, 2)
			customComp.MyState("updated")
			UI.flush()
			sert.eq(hookedVal, "updated")

			-- Invalid UI.Hook throws
			sert.eq(
				pcall(function()
					UI.edit(customComp) {
						[UI.Hook] = { NonExistent = function() end },
					}
				end),
				false
			)

			-- Theme states and computed properties
			local soundGroup = cliMounted.env.game:GetService("SoundService"):FindFirstChild("_KASounds")
			UI.Theme.SoundEnabled(false)
			UI.flush()
			if soundGroup then
				sert.eq(soundGroup.Volume, 0)
			end
			UI.Theme.SoundEnabled(true)
			UI.flush()
			if soundGroup then
				sert.eq(soundGroup.Volume, UI.Theme.Volume())
			end
			UI.Theme.TypingSounds(false)
			sert.eq(UI.Theme.TypingSounds(), false)
			UI.Theme.TypingSounds(true)
			sert.eq(UI.Theme.TypingSounds(), true)
			UI.Theme.TypingSoundsOnEveryTextBox(false)
			sert.eq(UI.Theme.TypingSoundsOnEveryTextBox(), false)
			UI.Theme.TypingSoundsOnEveryTextBox(true)
			sert.eq(UI.Theme.TypingSoundsOnEveryTextBox(), true)
			UI.Theme.FontSize(18)
			sert.eq(UI.Theme.FontSizeDouble(), 36)
			sert.eq(UI.Theme.FontSizeLargest(), math.round(18 * 1.75))
			sert.eq(UI.Theme.FontSizeLarger(), 27)
			sert.eq(UI.Theme.FontSizeLarge(), math.round(18 * 1.25))
			sert.eq(UI.Theme.FontSizeSmall(), math.round(18 * 0.75))
			sert.eq(UI.Theme.FontSizeSmaller(), 9)
			sert.eq(UI.Theme.FontSizeSmallest(), math.round(18 * 0.25))
			UI.Theme.FontSize(16)

			UI.Theme.CornerRadius(UDim.new(0, 0))
			sert.eq(UI.Theme.ScrollTopImage(), "rbxassetid://18370268668")
			sert.eq(UI.Theme.ScrollBottomImage(), "rbxassetid://18370268668")
			UI.Theme.CornerRadius(UDim.new(0, 8))
			sert.eq(UI.Theme.CornerHalf().Offset, 4)
			sert.eq(UI.Theme.CornerDiameter().Offset, 16)

			-- UI.new custom class constructor, unwrapChild in UI.new, direct GuiObject LayoutOrder, and parent._content unwrapping
			local customChild1 = { _instance = UI.new "Frame" { Name = "WrappedChild1" } }
			local customChild2 = { _instance = UI.new "Frame" { Name = "WrappedChild2" } }
			local customChild3 = { { _instance = UI.new "Frame" { Name = "NestedWrappedChild3" } } }
			local directChild1 = UI.new "Frame" { Name = "DirectChild1" }
			local directChild2 = UI.new "Frame" { Name = "DirectChild2", LayoutOrder = 9 }
			local hostFrame = UI.new "Frame" {
				Parent = customComp,
				customChild1,
				customChild2,
				customChild3,
				directChild1,
				directChild2,
			}
			sert.eq(hostFrame.Parent, customComp._content)
			sert.eq(customChild1._instance.Parent, hostFrame)
			sert.eq(customChild1._instance.LayoutOrder, 1)
			sert.eq(customChild2._instance.Parent, hostFrame)
			sert.eq(customChild2._instance.LayoutOrder, 2)
			sert.eq(customChild3[1].Parent, hostFrame)
			sert.eq(directChild1.LayoutOrder, 4)
			sert.eq(directChild2.LayoutOrder, 9)

			local customBtn = UI.new "Button" {
				Parent = customComp,
				Label = "Part1Btn",
			}
			sert.eq(customBtn._instance.Parent, customComp._content)
			sert.eq(#customBtn._createdNodes > 0, true)
			local btnNodeDestroyed = 0
			customBtn.ActiveSound:onDestroy(function()
				btnNodeDestroyed += 1
			end)
			customBtn._instance:Destroy()
			sert.eq(btnNodeDestroyed, 1)

			-- Hover state cleanup on destroy
			local hoverDestroyFrame = UI.new "Frame" { Parent = UI.LayerDefault }
			local hoverDestroyState = UI.newSinkHoverState(hoverDestroyFrame)
			local hoverDestroyed = 0
			hoverDestroyState:onDestroy(function()
				hoverDestroyed += 1
			end)
			hoverDestroyFrame:Destroy()
			sert.eq(hoverDestroyed, 1)

			-- Invalid UTF-8 text width estimation falls back to #text
			local badUtf8Sig, badUtf8Eff = UI.textWidth(function()
				return {
					{
						Text = "\255\255\255\255",
						Font = Font.fromEnum(Enum.Font.Gotham),
						Size = 20,
					},
				}
			end)
			sert.eq(badUtf8Sig:peek(), math.ceil(4 * 20 * 0.55))
			badUtf8Eff:Destroy()
			badUtf8Sig:Destroy()

			-- Non-integer numeric key in UI.new is not overwritten by unwrapChild
			local fracFrame = UI.new "Frame" {
				[1.5] = "custom_frac" :: any,
			}
			sert.eq(fracFrame ~= nil, true)

			local reactiveTxt = UI.signal("InitialTxt")
			local reactiveLbl = UI.new "TextLabel" {
				Text = function()
					return reactiveTxt()
				end,
			}
			sert.eq(reactiveLbl.Text, "InitialTxt")
		end)
	end)

	describe("Part 1b · Console Top Bar", function()
		test(
			"console screens follow TopbarInset height for 44px inner row while clamping horizontal padding to 12px",
			function()
				local world = sert.sim.new({ backing = true })
				local server = world:server()
				local client = server:client(1, "Player1")
				local cliMounted = setupClientEnv(client)

				-- UI reads IsTenFootInterface once at load, so fake a console before the first require
				local guiService: any = cliMounted.env.game:GetService("GuiService")
				local methods: any = rawget(guiService, "_methods")
				methods.IsTenFootInterface = function()
					return true
				end
				local UI = cliMounted.env:require(cliMounted.Client.UI)
				sert.eq(UI.IsConsoleScreen, true)
				sert.eq(UI.Platform, "Console")

				UI.GuiService.TopbarInset = Rect.new(0, 0, 1920, 0)
				world:step()
				UI.flush()

				sert.eq(UI.TopbarPadding().Offset, 0)
				sert.eq(UI.TopbarFrame.Visible, false)
				sert.eq(UI.TopbarFrame.Size.Y.Offset, 0)
				sert.eq(UI.LayerTopInset.Size.Y.Offset, 0)

				local padding = UI.TopbarFrame:FindFirstChildOfClass("UIPadding")
				sert.eq(padding ~= nil, true)
				sert.eq(padding.PaddingLeft.Offset, 0)
				sert.eq(padding.PaddingTop.Offset, 0)
				sert.eq(padding.PaddingBottom.Offset, 2)
				sert.eq(padding.PaddingRight.Offset, 0)

				-- Xbox ten-foot TopbarInset (87px tall, Min.X = 0): 41px top + 2px bottom = 44px inner height, 12px symmetric horizontal padding
				UI.GuiService.TopbarInset = Rect.new(0, 0, 1920, 87)
				world:step()
				UI.flush()
				sert.eq(UI.TopbarPadding().Offset, 12)
				sert.eq(UI.TopbarFrame.Visible, true)
				sert.eq(UI.TopbarFrame.Size.Y.Offset, 87)
				sert.eq(UI.LayerTopInset.Size.Y.Offset, -87)
				sert.eq(padding.PaddingLeft.Offset, 12)
				sert.eq(padding.PaddingRight.Offset, 12)
				sert.eq(padding.PaddingTop.Offset, 41)
				sert.eq(padding.PaddingBottom.Offset, 2)

				-- When left CoreGui Unibar controls occupy Min.X > 0 (e.g. Desktop 58px), left padding halves + 2px (8px)
				UI.GuiService.TopbarInset = Rect.new(160, 0, 1920, 58)
				world:step()
				UI.flush()
				sert.eq(UI.TopbarPadding().Offset, 12)
				sert.eq(padding.PaddingLeft.Offset, 8)
				sert.eq(padding.PaddingRight.Offset, 12)
				sert.eq(padding.PaddingTop.Offset, 12)
				sert.eq(padding.PaddingBottom.Offset, 2)
			end
		)
	end)

	describe("Part 2 · UI.Class Component Suite", function()
		test("instantiates and exercises all 21 UI.Class components and Clack", function()
			local world = sert.sim.new({ backing = true })
			local server = world:server()
			local client = server:client(1, "Player1")
			local cliMounted = setupClientEnv(client)
			local env = cliMounted.env

			local UI = env:require(cliMounted.Client.UI)
			if UI.registerClasses then
				UI.registerClasses()
			end
			local Clack = env:require(cliMounted.Client.UI.Classes.Input.Clack)

			-- 1. Button
			local btnClicked = 0
			local hoverSoundPlays = 0
			local origHover01 = UI.Sound.Hover01
			UI.Sound.Hover01 = {
				Play = function()
					hoverSoundPlays += 1
				end,
			} :: any
			local btn = UI.new "Button" {
				Parent = UI.LayerDefault,
				Position = UDim2.fromOffset(30, 0),
				Label = "Click Me",
				Icon = "rbxassetid://12345",
				IconRightAlign = true,
				AutomaticSize = Enum.AutomaticSize.XY,
				Activated = function()
					btnClicked += 1
				end,
			}
			sert.eq(btn._content.Label.Visible, true)
			sert.eq(btn._content.Label.Text, "Click Me")
			sert.eq(btn._content.IconFrame.Visible, true)
			sert.eq(btn._instance.Size.X.Scale, 0)
			btn.AutomaticSize(Enum.AutomaticSize.X)
			btn.AutomaticSize(Enum.AutomaticSize.Y)
			btn.AutomaticSize(Enum.AutomaticSize.None)
			UI.flush()
			sert.eq(btn._instance.Size.X.Scale, 1)
			env:input():click(btn._instance)
			sert.eq(btnClicked, 1)
			sert.eq(hoverSoundPlays, 1)
			btn.ActiveSound(false)
			env:input():click(btn._instance)
			sert.eq(hoverSoundPlays, 1)
			btn.ActiveSound(true)
			UI.Sound.Hover01 = origHover01
			btn._instance.InputBegan:Fire(
				makeInput(env, { UserInputType = Enum.UserInputType.MouseButton1, Position = Vector3.new(50, 10, 0) }),
				false
			)
			sert.eq(btn._instance.Ripple.Position.X.Offset, 50 - btn._instance.AbsolutePosition.X)
			btn._instance.InputChanged:Fire(
				makeInput(env, { UserInputType = Enum.UserInputType.MouseMovement, Position = Vector3.new(10, 10, 0) }),
				false
			)
			sert.eq(btn._hovering(), true)

			-- Button + child Tooltip hover never flickers across repeated MouseMovement events
			local btnTip = UI.new "Tooltip" {
				Parent = btn,
				Text = "Button Tip",
			}
			for px = 11, 20 do
				btn._instance.InputChanged:Fire(
					makeInput(
						env,
						{ UserInputType = Enum.UserInputType.MouseMovement, Position = Vector3.new(px, 10, 0) }
					),
					false
				)
				UI.flush()
				sert.eq(btn._hovering(), true)
				sert.eq(btnTip.Hovering(), true)
			end

			btn._instance.InputEnded:Fire(
				makeInput(env, { UserInputType = Enum.UserInputType.MouseMovement, Position = Vector3.new(10, 10, 0) })
			)
			UI.flush()
			sert.eq(btn._hovering(), false)
			sert.eq(btnTip.Hovering(), false)
			btn:Destroy()
			sert.eq(UI.Theme.Font:peek() ~= nil, true)

			-- 2. Checkbox
			local cb = UI.new "Checkbox" {
				Parent = UI.LayerDefault,
				Value = false,
			}
			sert.eq(cb.Value(), false)
			cb._instance.Activated:Fire()
			sert.eq(cb.Value(), true)
			cb._instance.Activated:Fire()
			sert.eq(cb.Value(), false)
			cb:Destroy()

			-- 3. Switch
			local sw = UI.new "Switch" {
				Parent = UI.LayerDefault,
				Value = false,
			}
			sert.eq(sw.Value(), false)
			sw._instance.Activated:Fire()
			sert.eq(sw.Value(), true)
			sw._instance.Activated:Fire()
			sert.eq(sw.Value(), false)
			sw:Destroy()

			-- 4. CircleProgress
			local cp = UI.new "CircleProgress" {
				Parent = UI.LayerDefault,
				Alpha = 0,
			}
			sert.eq(cp._instance.Left.Visible, false)
			sert.eq(cp._instance.Right.Visible, false)
			cp.Alpha(0.25)
			UI.flush()
			sert.eq(cp._instance.Left.Visible, false)
			sert.eq(cp._instance.Right.Visible, true)
			cp.Alpha(0.75)
			UI.flush()
			sert.eq(cp._instance.Left.Visible, true)
			sert.eq(cp._instance.Right.Visible, true)
			cp.Alpha(1)
			UI.flush()
			sert.eq(cp._instance.Left.ImageLabel.UIGradient.Rotation, 0)
			sert.eq(cp._instance.Right.ImageLabel.UIGradient.Rotation, 180)
			cp:Destroy()

			-- 5 & 6. Color & ColorPicker
			local colorComp = UI.new "Color" {
				Parent = UI.LayerDefault,
				Value = Color3.fromRGB(255, 0, 0),
			}
			sert.eq(colorComp._dialog.Visible(), false)
			colorComp._instance.Activated:Fire()
			sert.eq(colorComp._dialog.Visible(), true)
			colorComp._instance.Activated:Fire()
			sert.eq(colorComp._dialog.Visible(), false)

			local picker = colorComp._dialog
			picker.hueSlider.Value(0.5)
			UI.flush()
			picker.hexInput._input.Text = "#00ff00"
			picker.hexInput._input.FocusLost:Fire(true)
			UI.flush()
			sert.eq(colorComp.Value():ToHex(), "00ff00")

			-- ColorPicker hueSlider on 0-saturation color (pure white)
			colorComp.Value(Color3.new(1, 1, 1), true)
			UI.flush()
			picker.hueSlider.Value(0.5, true)
			UI.flush()
			local hWhite, sWhite, vWhite = picker.sv.BackgroundColor3:ToHSV()
			sert.near(hWhite, 0.5, 5e-3)
			sert.near(sWhite, 1, 5e-3)
			sert.near(vWhite, 1, 5e-3)

			-- Dragging SV box in ColorPicker
			local svDragInput = makeInput(env, {
				UserInputType = Enum.UserInputType.MouseButton1,
				UserInputState = Enum.UserInputState.Begin,
				Position = Vector3.new(20, 20, 0),
			})
			picker.sv.InputBegan:Fire(svDragInput)
			UI.UserInputService.InputChanged:Fire(
				makeInput(env, { UserInputType = Enum.UserInputType.MouseMovement, Position = Vector3.new(30, 30, 0) })
			)
			svDragInput.UserInputState = Enum.UserInputState.End
			colorComp:Destroy()

			-- 7. Dialog (confirm/cancel, drag, duration)
			local dialogActionResult = nil
			local dialogClosed = false
			local dlg = UI.new "Dialog" {
				Parent = UI.LayerDefault,
				Title = "Confirm Dialog",
				Text = "Are you sure?",
				ActionText = "Confirm?",
				Action = true,
				LeftAction = true,
				RightAction = true,
				ExitButton = true,
				Draggable = true,
				Duration = 0.05,
				Close = function()
					dialogClosed = true
				end,
				[UI.Hook] = {
					Action = function(val)
						dialogActionResult = val
					end,
				},
			}
			-- Drag dialog via title
			local dlgDragInput = makeInput(env, {
				UserInputType = Enum.UserInputType.MouseButton1,
				UserInputState = Enum.UserInputState.Begin,
				Position = Vector3.new(50, 50, 0),
			})
			dlg._content.Title.InputBegan:Fire(dlgDragInput, false)
			UI.UserInputService.InputChanged:Fire(
				makeInput(env, { UserInputType = Enum.UserInputType.MouseMovement, Position = Vector3.new(70, 80, 0) })
			)
			dlgDragInput.UserInputState = Enum.UserInputState.End

			-- Trigger RightAction (true)
			local actionsFrame = dlg._instance.Frame:FindFirstChild("Actions")
			sert.eq(actionsFrame ~= nil, true)
			actionsFrame.RightAction.Activated:Fire()
			UI.flush()
			sert.eq(dialogActionResult, true)
			sert.eq(dialogClosed, true)
			dlg:Destroy()

			-- Timed dialog auto-closes on PreRender
			local timedDlg = UI.new "Dialog" {
				Parent = UI.LayerDefault,
				Text = "Timed",
				Duration = 0.05,
				LeftAction = true,
			}
			world:run(0.2)
			sert.eq(timedDlg._instance.Parent, nil)

			-- Dialog with Options and OptionColors fires Action with selected option index
			local optionActionIndex = nil
			local optDlg = UI.new "Dialog" {
				Parent = UI.LayerDefault,
				Text = "Pick one",
				ActionText = "<b>CAST YOUR VOTE</b>",
				Action = true,
				Options = { "Alpha", "Beta", "Gamma" },
				OptionColors = { UI.Theme.Valid, UI.Theme.Invalid, UI.Theme.Secondary },
				[UI.Hook] = {
					Action = function(idx)
						optionActionIndex = idx
					end,
				},
			}
			local optionsFrame = optDlg._instance.Frame:FindFirstChild("Options")
			sert.eq(optionsFrame ~= nil, true)
			sert.eq(optionsFrame.Text.LayoutOrder, -1)
			optionsFrame.Option2.Activated:Fire()
			UI.flush()
			sert.eq(optionActionIndex, 2)
			optDlg:Destroy()

			-- 8, 9, 10, 11, 12. Gradient, Stroke, Spacer, Link, Tooltip
			local grad = UI.new "Gradient" { Parent = UI.LayerDefault }
			sert.eq(grad._instance.ClassName, "UIGradient")
			grad:Destroy()

			local stroke = UI.new "Stroke" { Parent = UI.LayerDefault }
			sert.eq(stroke._instance.ClassName, "UIStroke")
			stroke:Destroy()

			local spacer = UI.new "Spacer" { Parent = UI.LayerDefault }
			sert.eq(spacer._instance.ClassName, "Frame")
			spacer:Destroy()

			local link = UI.new "Link" {
				Parent = UI.LayerDefault,
				Text = "https://example.com",
				Tooltip = "Click to copy",
			}
			link:Select()
			link._instance.Focused:Fire()
			sert.eq(link._instance.SelectionStart, 1)
			sert.eq(link._instance.CursorPosition, #link._instance.Text + 1)
			link._instance.CursorPosition = 1
			sert.eq(link._instance.SelectionStart, 1)
			sert.eq(link._instance.CursorPosition, #link._instance.Text + 1)
			link._instance.InputEnded:Fire(
				makeInput(env, { UserInputType = Enum.UserInputType.MouseButton1, Position = Vector3.new(10, 10, 0) })
			)
			sert.eq(link._instance.SelectionStart, 1)
			sert.eq(link._instance.CursorPosition, #link._instance.Text + 1)
			link._instance:ReleaseFocus()
			link._instance.FocusLost:Fire()
			sert.eq(link._instance.SelectionStart, -1)
			sert.eq(link._instance.Text, "https://example.com")
			link:Destroy()
			-- Firing Focused / FocusLost after Link:Destroy() is a safe no-op
			link._instance.Focused:Fire()
			link._instance.FocusLost:Fire()
			world:run(0.05)

			-- Theme.load keeps Theme.Themes entries as plain value tables (no nested Flux signals)
			local lightThemeModule = cliMounted.Client.UI.Theme.Themes.Light
			UI.Theme.Themes.Light = nil
			UI.Theme.load(lightThemeModule)
			sert.eq(env.globals.typeof(UI.Theme.Themes.Light.Primary), "Color3")
			sert.eq(UI.isNode(UI.Theme.Themes.Light.Primary), false)

			local tipTarget = UI.new "Frame" {
				Parent = UI.LayerDefault,
				Position = UDim2.fromOffset(1250, 710),
				Size = UDim2.fromOffset(100, 750),
			}
			local tip = UI.new "Tooltip" {
				Parent = tipTarget,
				Text = "Helpful tip",
			}
			-- gamepad/keyboard selection drives tooltips through GuiService.SelectedObject (UI.Interact.selected)
			local guiService = UI.GuiService
			guiService.SelectedObject = tipTarget
			UI.flush()
			sert.eq(tip.Hovering(), true)
			world:run(0.5)
			sert.eq(tip.Visible(), true)
			tipTarget.Position = UDim2.fromOffset(1260, 5)
			tipTarget.Size = UDim2.fromOffset(100, 750)
			guiService.SelectedObject = nil
			UI.flush()
			sert.eq(tip.Visible(), false)
			tip:Destroy()

			-- 13 & 14. Input & Clack
			Clack.sound(Enum.KeyCode.A)
			Clack.sound(Enum.KeyCode.B)

			local textInput = UI.new "Input" {
				Parent = UI.LayerDefault,
				Placeholder = "Enter text",
				ClearTextButton = true,
				MaxChars = 5,
				Icon = "rbxassetid://123",
				IconProperties = { ImageTransparency = 0.1 },
				Validate = function(v)
					return v ~= "bad"
				end,
			}
			UI.UserInputService.TextBoxFocused:Fire(textInput._input)
			UI.UserInputService.InputBegan:Fire(
				makeInput(env, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.A }),
				false
			)
			UI.UserInputService.TextBoxFocusReleased:Fire(textInput._input)

			textInput._input.Text = "hello_world"
			sert.eq(textInput._input.Text, "hello") -- MaxChars = 5
			textInput._input.SelectionStart = 1
			textInput._input.CursorPosition = 3
			world:run(0.1)
			textInput._input.SelectionStart = -1
			textInput._input.CursorPosition = -1
			textInput._input.FocusLost:Fire(true)
			sert.eq(textInput.Value(), "hello")

			-- Reject invalid via Validate
			textInput._input.Text = "bad"
			textInput._input.FocusLost:Fire(true)
			sert.eq(textInput.Value(), "hello")

			-- SetValue reaches the TextBox before the next flush, so FocusLost keeps it instead of the stale text
			textInput:SetValue("abc")
			sert.eq(textInput._input.Text, "abc")
			textInput._input.FocusLost:Fire(true)
			sert.eq(textInput.Value(), "abc")

			-- ClearTextButton
			textInput._instance.ImageButton.Activated:Fire()
			sert.eq(textInput.Value(), "")
			textInput:Destroy()

			-- NumberOnly / IntegerOnly Input
			local numInput = UI.new "Input" {
				Parent = UI.LayerDefault,
				NumberOnly = true,
				IntegerOnly = true,
				NumberRange = NumberRange.new(10, 50),
				Value = 20,
			}
			numInput._input.Text = ""
			numInput._input.FocusLost:Fire(true)
			sert.eq(numInput.Value(), 10)
			sert.eq(numInput._input.Text, "10")
			-- Clearing again while Value is already at NumberRange.Min still restores _input.Text to Min
			numInput._input.Text = ""
			numInput._input.FocusLost:Fire(true)
			sert.eq(numInput.Value(), 10)
			sert.eq(numInput._input.Text, "10")
			numInput._input.Text = "999"
			numInput._input.FocusLost:Fire(true)
			sert.eq(tonumber(numInput.Value()), 50)
			numInput._input.Text = "abc"
			numInput._input.FocusLost:Fire(true)
			numInput:Destroy()

			-- HotkeyInput mode
			local hkInput = UI.new "Input" {
				Parent = UI.LayerDefault,
				HotkeyInput = true,
				Hotkey = Enum.KeyCode.Semicolon,
				Modifiers = {},
			}
			hkInput._input:CaptureFocus()
			UI.UserInputService.InputBegan:Fire(
				makeInput(env, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.LeftShift }),
				false
			)
			UI.UserInputService.InputBegan:Fire(
				makeInput(env, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.K }),
				false
			)
			sert.eq(hkInput.Hotkey(), Enum.KeyCode.K)
			hkInput:Destroy()

			-- 15 & 16. List & ListItem
			local listComp = UI.new "List" {
				Parent = UI.LayerDefault,
				Label = "Section",
				Collapsible = true,
				Collapsed = false,
				UI.new "ListItem" {
					Text = "Row 1",
					Tooltip = "Row 1 tip",
					ContentAutomaticSize = false,
					ContentListLayout = false,
				},
			}
			sert.eq(listComp.Collapsed(), false)
			listComp._instance.Header.Activated:Fire()
			sert.eq(listComp.Collapsed(), true)
			listComp._instance.Header.Activated:Fire()
			sert.eq(listComp.Collapsed(), false)
			listComp:Destroy()

			-- 17. Menu
			local adorneeBtn = UI.new "Frame" {
				Parent = UI.LayerDefault,
				Position = UDim2.fromOffset(100, 100),
				Size = UDim2.fromOffset(40, 20),
			}
			local menuComp = UI.new "Menu" {
				Adornee = adorneeBtn,
				RightAlign = true,
				Visible = false,
			}
			UI.activateState(menuComp.Visible, "floating")
			sert.eq(menuComp.Visible(), true)
			menuComp._content.CanvasPosition = Vector2.new(0, 10)
			-- Clicking outside closes menu
			UI.UserInputService.InputBegan:Fire(
				makeInput(env, { UserInputType = Enum.UserInputType.MouseButton1, Position = Vector3.new(500, 500, 0) }),
				false
			)
			sert.eq(menuComp.Visible(), false)
			menuComp:Destroy()

			-- 18 & 19. Scroller & ScrollerFast
			local scroller = UI.new "Scroller" { Parent = UI.LayerDefault }
			sert.eq(scroller._instance.ClassName, "ScrollingFrame")
			scroller:Destroy()

			sert.eq(UI.Class.ScrollerFast.escapeRichText(`<a&"b'>`), "&lt;a&amp;&quot;b&apos;&gt;")
			local arrayState = UI.signal({ "Alpha", "Beta", "Gamma" })
			local fastArray = UI.new "ScrollerFast" {
				Parent = UI.LayerDefault,
				List = arrayState,
				FilterInput = true,
				FilterInputDebounce = 0.02,
				Visible = true,
			}
			world:run(0.2)
			fastArray:forceRender()
			sert.eq(next(fastArray._lineItemCache) ~= nil, true)
			-- Scroll canvas (> sizeY and < sizeY) and trigger pause-canvas adjustment on refresh
			fastArray._scroller.CanvasPosition = Vector2.new(0, 200)
			fastArray._scroller.CanvasPosition = Vector2.new(0, 210)
			fastArray:refreshList()
			world:run(0.2)
			arrayState({ "Alpha", "Beta", "Gamma", "Delta" })
			world:run(0.2)
			fastArray._scroller.CanvasPosition = Vector2.zero
			fastArray._input._input.Text = "be"
			fastArray._input._input.Text = "beta"
			world:run(0.2)
			fastArray:forceRender()
			sert.eq(#fastArray._filteredList, 1)
			fastArray._input._input.Text = ""
			world:run(0.2)
			fastArray:sort(function(a, b)
				return a > b
			end)
			world:run(0.2)
			sert.eq(fastArray._filteredList[1], "Gamma")
			fastArray:sort(nil :: any)
			world:run(0.2)
			fastArray._scroller._props.AbsoluteCanvasSize = Vector2.new(100, 50)
			fastArray._scroller:GetPropertyChangedSignal("AbsoluteCanvasSize"):Fire()
			-- Calling render(true) or mutating List while hidden defers work until Visible = true
			fastArray._instance.Visible = false
			sert.eq(next(fastArray._lineItemCache) ~= nil, true)
			fastArray:render(true)
			sert.eq(fastArray._bustCache, true)
			sert.eq(fastArray._pendingRender, true)
			sert.eq(next(fastArray._lineItemCache) ~= nil, true)
			fastArray.List({ "Alpha", "Beta", "Gamma", "Delta", "Epsilon" })
			UI.flush()
			sert.eq(fastArray._pendingUpdate, true)
			sert.eq(#fastArray._filteredList, 4)
			fastArray._instance.Visible = true
			world:run(0.2)
			sert.eq(fastArray._bustCache, nil)
			sert.eq(fastArray._pendingRender, nil)
			sert.eq(fastArray._pendingUpdate, nil)
			sert.eq(#fastArray._filteredList, 5)
			sert.eq(next(fastArray._lineItemCache) ~= nil, true)
			fastArray:Destroy()

			local fastDict = UI.new "ScrollerFast" {
				Parent = UI.LayerDefault,
				List = { k1 = "Val1", k2 = "Val2" },
				DictList = true,
				ReverseOrder = true,
				Visible = true,
				CreateItem = function(self)
					return UI.new "TextLabel" { Size = self.ItemSize }
				end,
				RenderItem = function(_self, item, val)
					item.Text = tostring(val)
				end,
			}
			world:run(0.2)
			fastDict:forceRender()
			sert.eq(next(fastDict._lineItemCache) ~= nil, true)
			fastDict:filter(function(_self, list)
				local out = {}
				for _, k in list do
					if k == "k1" then
						table.insert(out, k)
					end
				end
				return out
			end)
			world:run(0.2)
			sert.eq(#fastDict._filteredList, 1)
			sert.eq(fastDict._filteredList[1], "k1")
			fastDict:freeCache()
			fastDict:Destroy()

			-- 20. Select
			local sel = UI.new "Select" {
				Parent = UI.LayerDefault,
				Value = "Choice A",
				Choices = {
					"Default",
					"Choice A",
					"Choice B",
					Enum.Font.Code,
					Font.fromEnum(Enum.Font.Gotham),
					{ Name = "TableChoice" },
				},
			}
			sel._instance.Header.Activated:Fire()
			sert.eq(sel.menu.Visible(), true)
			local choiceBBtn = sel.menu._content:FindFirstChild("Choice B") :: TextButton
			sert.eq(choiceBBtn ~= nil, true)
			choiceBBtn.Activated:Fire()
			sert.eq(sel.Value(), "Choice B")
			sel.Choices({ "New 1", "New 2" })
			sert.eq(#sel.Choices(), 2)
			sel:Destroy()

			-- 21. Slider
			local slider = UI.new "Slider" {
				Parent = UI.LayerDefault,
				Snap = 5,
				Value = 1,
				Vertical = false,
			}
			local sldInput = makeInput(env, {
				UserInputType = Enum.UserInputType.MouseButton1,
				UserInputState = Enum.UserInputState.Begin,
				Position = Vector3.new(50, 10, 0),
			})
			slider._instance.InputBegan:Fire(sldInput)
			UI.UserInputService.InputChanged:Fire(
				makeInput(env, { UserInputType = Enum.UserInputType.MouseMovement, Position = Vector3.new(100, 10, 0) })
			)
			sldInput.UserInputState = Enum.UserInputState.End
			slider.Vertical(true)
			sert.eq(slider.Vertical(), true)
			slider:Destroy()

			-- 22. Tabs (including tab dragging and mousewheel scrolling)
			local page1 = UI.new "Frame" { Name = "Page1" }
			local page2 = UI.new "Frame" { Name = "Page2" }
			local tabsComp = UI.new "Tabs" {
				Parent = UI.LayerDefault,
				CurrentPage = page1,
				Tabs = {
					{ page1, "rbxassetid://111" },
					{ page2, "rbxassetid://222" },
				},
				Vertical = false,
			}
			local barTabs = tabsComp._instance.Bar.Tabs
			barTabs._props.AbsoluteCanvasSize = Vector2.new(500, 30)
			barTabs._props.AbsoluteSize = Vector2.new(100, 30)
			local page1Btn = barTabs:FindFirstChild("Page1") :: TextButton
			local page2Btn = barTabs:FindFirstChild("Page2") :: TextButton
			sert.eq(page2Btn ~= nil, true)
			page2Btn.Activated:Fire()
			sert.eq(tabsComp.CurrentPage(), page2)

			if page1Btn and page2Btn then
				page1Btn._props.AbsolutePosition = Vector2.new(0, 0)
				page1Btn._props.AbsoluteSize = Vector2.new(40, 24)
				page2Btn._props.AbsolutePosition = Vector2.new(45, 0)
				page2Btn._props.AbsoluteSize = Vector2.new(40, 24)
				local tabDragInput = makeInput(env, {
					UserInputType = Enum.UserInputType.MouseButton1,
					UserInputState = Enum.UserInputState.Begin,
					Position = Vector3.new(10, 10, 0),
				})
				page1Btn.InputBegan:Fire(tabDragInput, false)
				UI.UserInputService.InputChanged:Fire(
					makeInput(
						env,
						{ UserInputType = Enum.UserInputType.MouseMovement, Position = Vector3.new(60, 10, 0) }
					)
				)
				world:run(0.1)
				tabDragInput.UserInputState = Enum.UserInputState.End
				world:run(0.1)
			end

			tabsComp._pages:Previous()
			tabsComp._pages:Next()
			barTabs.MouseWheelBackward:Fire()
			world:run(0.1)
			barTabs.MouseWheelForward:Fire()
			world:run(0.1)
			tabsComp.Vertical(true)
			sert.eq(tabsComp.Vertical(), true)
			tabsComp:Destroy()

			-- 23. Window
			local winClosed = false
			local paddedParent = UI.new "Frame" {
				Parent = UI.LayerDefault,
				Size = UDim2.fromOffset(800, 600),
				UI.new "UIPadding" {
					PaddingLeft = UDim.new(0, 10),
					PaddingRight = UDim.new(0, 10),
					PaddingTop = UDim.new(0, 10),
					PaddingBottom = UDim.new(0, 10),
				},
			}
			local win1 = UI.new "Window" {
				Parent = UI.LayerDefault,
				Title = "Win1",
				Icon = "rbxassetid://123",
				Position = UDim2.fromOffset(100, 100),
				Size = UDim2.fromOffset(300, 300),
				Close = function()
					winClosed = true
				end,
			}
			win1._instance.Visible = true
			win1._instance.Parent = paddedParent
			paddedParent.Size = UDim2.fromOffset(700, 500)
			sert.eq(win1._instance.UISizeConstraint.MaxSize, Vector2.new(680, 480))
			paddedParent.Size = UDim2.fromOffset(200, 180)
			sert.eq(win1._instance.UISizeConstraint.MaxSize, Vector2.new(180, 160))
			sert.eq(win1.Size(), UDim2.fromOffset(300, 300))
			win1._instance.Parent = UI.LayerDefault
			win1.Position(UDim2.fromOffset(100, 100))
			UI.flush()

			local win2 = UI.new "Window" {
				Parent = UI.LayerDefault,
				Title = "Win2",
				Position = UDim2.fromOffset(100, 100),
				Size = UDim2.fromOffset(300, 300),
				RemoveOnClose = true,
			}
			win2._instance.Visible = true
			-- Setting Visible = true nudges win2 and preserves the nudged Position on the instance synchronously
			sert.ne(win2._instance.Position, UDim2.fromOffset(100, 100))
			UI.Class.Window.bringToFront(win1)
			sert.ne(win2.Position(), UDim2.fromOffset(100, 100))

			local win3 = UI.new "Window" {
				Parent = UI.LayerDefault,
				Title = "Win3",
				Position = UDim2.fromOffset(100, 100),
				Size = UDim2.fromOffset(300, 300),
				Visible = true,
			}
			sert.ne(win3._instance.Position, UDim2.fromOffset(100, 100))
			win3:Destroy()

			-- Drag window via TitleBar (updates _instance.Position synchronously on InputChanged)
			local preDragPos = win1._instance.Position
			local winDrag = makeInput(env, {
				UserInputType = Enum.UserInputType.MouseButton1,
				UserInputState = Enum.UserInputState.Begin,
				Position = Vector3.new(150, 110, 0),
			})
			win1._instance.Frame.TitleBar.InputBegan:Fire(winDrag, false)
			UI.UserInputService.InputChanged:Fire(
				makeInput(
					env,
					{ UserInputType = Enum.UserInputType.MouseMovement, Position = Vector3.new(180, 140, 0) }
				)
			)
			sert.ne(win1._instance.Position, preDragPos)
			winDrag.UserInputState = Enum.UserInputState.End

			-- Hover & resize window at top-left corner of win1 (with MouseIconEnabled true)
			UI.UserInputService.MouseIconEnabled = true
			local wPos = win1._instance.AbsolutePosition
			UI.UserInputService.InputChanged:Fire(
				makeInput(
					env,
					{ UserInputType = Enum.UserInputType.MouseMovement, Position = Vector3.new(wPos.X, wPos.Y, 0) }
				)
			)
			sert.eq(UI.UserInputService.MouseIconEnabled, false)
			sert.eq(win1._instance.ResizeIcon.Visible, true)
			local winResize = makeInput(env, {
				UserInputType = Enum.UserInputType.MouseButton1,
				UserInputState = Enum.UserInputState.Begin,
				Position = Vector3.new(wPos.X, wPos.Y, 0),
			})
			UI.UserInputService.InputBegan:Fire(winResize, false)
			UI.UserInputService.InputChanged:Fire(makeInput(env, {
				UserInputType = Enum.UserInputType.MouseMovement,
				Position = Vector3.new(wPos.X - 10, wPos.Y - 10, 0),
			}))
			winResize.UserInputState = Enum.UserInputState.End
			UI.UserInputService.InputChanged:Fire(makeInput(env, {
				UserInputType = Enum.UserInputType.MouseMovement,
				Position = Vector3.new(wPos.X + 100, wPos.Y + 100, 0),
			}))
			sert.eq(UI.UserInputService.MouseIconEnabled, true)

			-- AutomaticSize.Y window preserves auto-sized Y scale/offset and disables vertical resize
			local autoWin = UI.new "Window" {
				Parent = UI.LayerDefault,
				Title = "AutoWin",
				AutomaticSize = Enum.AutomaticSize.Y,
				Position = UDim2.fromOffset(50, 50),
				Size = UDim2.fromOffset(420, 0),
			}
			sert.eq(autoWin._content.Size, UDim2.fromScale(1, 0))
			sert.eq(autoWin._instance.Frame.Size, UDim2.fromScale(1, 0))
			sert.eq(autoWin._content.UIFlexItem.FlexMode, Enum.UIFlexMode.None)
			autoWin._instance.Visible = true
			sert.eq(autoWin._instance.Size, UDim2.fromOffset(420, 0))
			-- Top edge hover does not trigger vertical resize on AutomaticSize.Y
			local awPos = autoWin._instance.AbsolutePosition
			UI.UserInputService.InputChanged:Fire(makeInput(env, {
				UserInputType = Enum.UserInputType.MouseMovement,
				Position = Vector3.new(awPos.X + 100, awPos.Y, 0),
			}))
			sert.eq(autoWin._instance.ResizeIcon.Visible, false)
			-- Left edge hover still allows horizontal resize
			UI.UserInputService.InputChanged:Fire(makeInput(env, {
				UserInputType = Enum.UserInputType.MouseMovement,
				Position = Vector3.new(awPos.X, awPos.Y, 0),
			}))
			sert.eq(autoWin._instance.ResizeIcon.Visible, true)
			sert.eq(autoWin._instance.ResizeIcon.ImageRectOffset, Vector2.new(48, 0))
			-- When AutomaticSize grows the window's AbsoluteSize past the bottom edge, Position re-clamps on-screen
			local parentHeight = UI.LayerDefault.AbsoluteSize.Y
			autoWin.Position(UDim2.fromOffset(50, parentHeight - 20))
			UI.flush()
			autoWin.Size(UDim2.fromOffset(420, 120))
			UI.flush()
			sert.eq(autoWin._instance.Position.Y.Offset, math.max(0, parentHeight - 120))
			autoWin:Destroy()

			-- Exit buttons
			win1._exitButton._instance.Activated:Fire()
			sert.eq(winClosed, true)
			win2._exitButton._instance.Activated:Fire()
			sert.eq(win2._instance.Parent, nil)
		end)
	end)
end)

describe("Client and UI · Tabs & UI.edit regressions", function()
	test("Tabs snaps CanvasPosition when a resize clamps it, but still animates scrolling", function()
		local world, env, UI = newClientEnvUI()
		local page1 = UI.new "Frame" { Name = "Page1" }
		local page2 = UI.new "Frame" { Name = "Page2" }
		local tabsComp = UI.new "Tabs" {
			Parent = UI.LayerDefault,
			CurrentPage = page1,
			Tabs = { { page1 }, { page2 } },
		}
		local barTabs = tabsComp._instance.Bar.Tabs
		world:run(0.5)
		env:setAbsolute(tabsComp._instance, Vector2.new(100, 30), Vector2.new(0, 0))
		env:setAbsolute(barTabs, Vector2.new(100, 30), Vector2.new(0, 0))
		env:setAbsolute(barTabs:FindFirstChild("Page1"), Vector2.new(40, 24), Vector2.new(0, 0))
		env:setAbsolute(barTabs:FindFirstChild("Page2"), Vector2.new(40, 24), Vector2.new(150, 0))
		world:run(0.5)
		sert.eq(barTabs.CanvasPosition.X, 0)

		-- a mousewheel scroll eases toward the next tab over several frames (the first frame only retargets)
		barTabs.MouseWheelBackward:Fire()
		world:step()
		world:step()
		local scrolling = barTabs.CanvasPosition.X
		sert(scrolling > 0 and scrolling < 150, `scroll animates, CanvasPosition.X = {scrolling}`)

		-- shrinking the bar mid-scroll clamps the offset and lands there on the next frame instead of easing behind
		env:setAbsolute(barTabs, Vector2.new(90, 30))
		world:step()
		world:step()
		local snapped = barTabs.CanvasPosition.X
		world:run(1)
		sert.eq(barTabs.CanvasPosition.X, snapped)

		-- the next scroll animates again
		env:setAbsolute(barTabs:FindFirstChild("Page2"), Vector2.new(40, 24), Vector2.new(snapped + 60, 0))
		barTabs.MouseWheelBackward:Fire()
		world:step()
		world:step()
		local resumed = barTabs.CanvasPosition.X
		sert(resumed ~= snapped, "scrolling after a resize moves the canvas")
		world:run(1)
		sert(barTabs.CanvasPosition.X ~= resumed, `scrolling after a resize animates, stuck at {resumed}`)
		tabsComp:Destroy()
	end)

	test("UI.edit leaves a Find selection passed as a child untouched", function()
		local world, _, UI = newClientEnvUI()
		local host = UI.new "Frame" {
			Parent = UI.LayerDefault,
			UI.new "Frame" { Name = "Inner" },
		}
		local selection = UI.Find.Child("Inner")({ Name = "Renamed" })
		UI.edit(host)({ selection })
		UI.flush()
		world:step()
		sert.eq(host:FindFirstChild("Renamed") ~= nil, true)

		-- the selection's own children are not unwrapped in place (Flux may reject them; only the rewrite matters)
		local marker = { _instance = UI.new "Frame" { Name = "Marker" } }
		local props = { marker }
		local nested = UI.Find.Child("Renamed")(props)
		pcall(UI.edit(host), { nested })
		sert.eq(nested[1], selection[1])
		sert.eq(nested[3], props)
		sert.eq(props[1], marker)
		host:Destroy()
	end)
end)

describe("Client and UI · motion nodes die with their component", function()
	-- A tween/spring passed straight to a property is only bound, not owned (Flux owns getter functions, not motion
	-- nodes), and a class constructor runs with no owner. A leaked motion keeps its driving effect subscribed to the
	-- theme forever, so the observer count of a theme signal it reads must return to its baseline after Destroy. A nil
	-- guard inside the getter would hide the error but leave the effect subscribed, and still fails this.
	local function newClientUI()
		local world, _env, UI = ClientHarness.newClientUI()
		return world, UI
	end

	local cases: { { name: string, build: (UI: any) -> any, poke: ((comp: any, UI: any) -> ())? } } = {
		{
			name = "List",
			build = function(UI)
				return UI.new "List" {
					Parent = UI.LayerDefault,
					Label = "Section",
					Collapsible = true,
					UI.new "ListItem" { Text = "Row" },
				}
			end,
			poke = function(comp)
				comp._instance.Header.Activated:Fire()
			end,
		},
		{
			name = "Switch",
			build = function(UI)
				return UI.new "Switch" { Parent = UI.LayerDefault }
			end,
			poke = function(comp)
				comp._instance.Activated:Fire()
			end,
		},
		{
			name = "Checkbox",
			build = function(UI)
				return UI.new "Checkbox" { Parent = UI.LayerDefault }
			end,
			poke = function(comp)
				comp._instance.Activated:Fire()
			end,
		},
		{
			name = "Slider",
			build = function(UI)
				return UI.new "Slider" { Parent = UI.LayerDefault, Snap = 5, Value = 2 }
			end,
		},
		{
			name = "ColorPicker",
			build = function(UI)
				return UI.new "ColorPicker" { Parent = UI.LayerDefault, Value = Color3.new(0, 1, 0) }
			end,
		},
		{
			name = "Tabs",
			build = function(UI)
				local page1 = UI.new "Frame" { Name = "Page1" }
				local page2 = UI.new "Frame" { Name = "Page2" }
				return UI.new "Tabs" {
					Parent = UI.LayerDefault,
					CurrentPage = page1,
					Tabs = { { page1 }, { page2 } },
				}
			end,
			poke = function(comp)
				comp._instance.Bar.Tabs:FindFirstChild("Page2").Activated:Fire()
			end,
		},
	}

	for _, case in cases do
		test(`{case.name} releases its tweens on Destroy`, function()
			local world, UI = newClientUI()
			world:run(0.5)
			UI.flush()
			local baseline = observers(UI.Theme.TweenOut)

			local comp = case.build(UI)
			UI.flush()
			world:run(0.1)
			if case.poke then
				case.poke(comp, UI)
				UI.flush()
				world:run(0.5)
			end
			local alive = observers(UI.Theme.TweenOut)
			sert(alive > baseline, `{case.name} tweens read Theme.TweenOut while alive ({alive} vs {baseline})`)

			comp:Destroy()
			UI.flush()
			world:step()
			-- a theme change after Destroy would re-run any leaked effect against the destroyed instance
			UI.Theme.TweenOut(UI.Theme.TweenOut:peek(), true)
			UI.Theme.FontSize(UI.Theme.FontSize:peek() + 1)
			UI.flush()
			world:run(0.5)
			sert.eq(observers(UI.Theme.TweenOut), baseline)
		end)
	end

	test("a notification keeps its spring through the hide animation and releases it with the card", function()
		local world = sert.sim.new({ backing = true })
		local server = world:server()
		local client = server:client(1, "Player1")
		local cliMounted = setupClientEnv(client, { mockRemote = true })
		local cK = cliMounted:requireK()
		Harness.seedRoles(cK.Data)
		local UI = cliMounted.env:require(cliMounted.Client.UI)
		if UI.registerClasses then
			UI.registerClasses()
		end
		cK.UI = UI
		cK.IsClient = true
		cK.LocalPlayer = cliMounted.env.Players.LocalPlayer
		cK.client = {
			rank = cK.Flux.signal(0),
			UserFrame = cliMounted.env:require(cliMounted.Client.UserFrame),
		}
		cK.Notify = cliMounted.env:require(cliMounted.Client.Notify)

		world:run(0.2)
		UI.flush()
		local baseline = observers(UI.Theme.Padding)

		local dialog = cK.Notify({ Text = "leak check" })
		local card = dialog._instance
		world:run(0.5)
		UI.flush()
		local alive = observers(UI.Theme.Padding)
		sert(alive > baseline, `the notification reads Theme.Padding while shown ({alive} vs {baseline})`)

		-- Duration is 4 + 0.0625 * #Text (4.625 s); just after it the card is hidden but still animating out
		world:run(4.35)
		UI.flush()
		sert(card.Parent ~= nil, "the card is still mounted during its hide animation")
		local beforeDestroy = card.Position
		world:step()
		world:step()
		sert(card.Position ~= beforeDestroy, "the hide animation is still moving the card")
		sert(observers(UI.Theme.Padding) > baseline, "the spring is not released before the hide animation ends")

		world:run(2)
		UI.flush()
		sert.eq(card.Parent, nil)
		UI.Theme.Padding(UDim.new(0, UI.Theme.Padding:peek().Offset + 1))
		UI.flush()
		world:run(0.5)
		sert.eq(observers(UI.Theme.Padding), baseline)

		-- Verify UserFrame system notification (from = nil) does not leak Theme observers after Destroy
		local fontBaseline = observers(UI.Theme.Font)
		local sysHeader = cK.client.UserFrame(nil, "System")
		UI.flush()
		sysHeader:Destroy()
		UI.flush()
		sert.eq(observers(UI.Theme.Font), fontBaseline)

		-- Verify Tooltip.Cache clears adornee on adornee change and tooltip destroy
		local adornee1 = cliMounted.env.Instance.new("TextButton")
		local adornee2 = cliMounted.env.Instance.new("TextButton")
		local tip = UI.new "Tooltip" { Parent = adornee1, Text = "Tip" }
		UI.flush()
		sert.eq(UI.Class.Tooltip.Cache[adornee1], tip)
		tip._instance.Parent = adornee2
		UI.flush()
		sert.eq(UI.Class.Tooltip.Cache[adornee1], nil)
		sert.eq(UI.Class.Tooltip.Cache[adornee2], tip)
		tip:Destroy()
		UI.flush()
		sert.eq(UI.Class.Tooltip.Cache[adornee2], nil)
		adornee1:Destroy()
		adornee2:Destroy()
	end)

	do
		local ExplorerOrder: any
		local explorerClasses: { string }
		local function getExplorerOrder()
			if not ExplorerOrder then
				local h = Harness.shared()
				ExplorerOrder = h.env:require(h.Client:WaitForChild("Explorer"):WaitForChild("ExplorerOrder"))
				explorerClasses = {}
				for className in ExplorerOrder do
					table.insert(explorerClasses, className)
				end
				table.sort(explorerClasses)
			end
			return ExplorerOrder, explorerClasses
		end

		sert.laws.order("ExplorerOrder · sortChildren", {
			gen = function(g)
				local _, classes = getExplorerOrder()
				return {
					ClassName = g:pick(classes),
					Name = sert.gen.string("abcd", 1, 4)(g),
				}
			end,
			lt = function(a, b)
				local orderMap = getExplorerOrder()
				local orderA = orderMap[a.ClassName]
				local orderB = orderMap[b.ClassName]
				if orderA and orderB and orderA ~= orderB then
					return orderA < orderB
				end
				if a.ClassName == b.ClassName then
					return a.Name < b.Name
				end
				return a.ClassName < b.ClassName
			end,
		})
	end

	do
		sert.roblox.Layout.matrix(
			"UI Components · Multi-Viewport Responsive Layout Audit",
			function(_container, preset)
				local viewport = preset.size
				local world, UI = newClientUI()
				local screenGui = UI.LayerDefault.Parent
				if screenGui then
					screenGui.Size = UDim2.fromOffset(viewport.X, viewport.Y)
				end

				local panelW = math.min(viewport.X - 24, 560)
				local panelH = math.min(viewport.Y - 48, 380)

				local btnExecute = UI.new "Button" {
					Name = "ExecuteButton",
					Label = "Execute",
					Size = UDim2.fromOffset(100, 32),
				}
				btnExecute._instance.Ripple.Size = UDim2.fromOffset(0, 0)
				local btnClear = UI.new "Button" {
					Name = "ClearButton",
					Label = "Clear",
					Size = UDim2.fromOffset(88, 32),
				}
				btnClear._instance.Ripple.Size = UDim2.fromOffset(0, 0)
				local swToggle = UI.new "Switch" {
					Name = "ModeSwitch",
					AnchorPoint = Vector2.new(0, 0),
					Position = UDim2.fromOffset(0, 0),
					Value = true,
				}
				local cbCheck = UI.new "Checkbox" {
					Name = "ConfirmCheck",
					AnchorPoint = Vector2.new(0, 0),
					Position = UDim2.fromOffset(0, 0),
					Value = true,
				}

				local panel = UI.new "Frame" {
					Name = "AuditPanel",
					Parent = UI.LayerDefault,
					Position = UDim2.fromOffset(12, 24),
					Size = UDim2.fromOffset(panelW, panelH),
					BackgroundColor3 = UI.Theme.Primary,

					UI.padding(UDim.new(0, 8)),
					UI.list {
						gap = UDim.new(0, 8),
						horizontalAlign = "start",
						verticalAlign = "start",
					},

					UI.new "TextLabel" {
						Name = "HeaderTitle",
						LayoutOrder = 1,
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 0, 28),
						FontFace = UI.Theme.FontBold,
						TextSize = 18,
						TextXAlignment = Enum.TextXAlignment.Left,
						Text = "Kohl's Admin Controls",
					},

					UI.new "Frame" {
						Name = "Toolbar",
						LayoutOrder = 2,
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 0, 36),

						UI.list {
							direction = "x",
							gap = UDim.new(0, 8),
							verticalAlign = "center",
						},

						btnExecute._instance,
						btnClear._instance,
						swToggle._instance,
						cbCheck._instance,
					},

					UI.new "Frame" {
						Name = "RowsSection",
						LayoutOrder = 3,
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 0, 120),

						UI.list {
							gap = UDim.new(0, 6),
						},

						UI.new "TextLabel" {
							Name = "Row1",
							LayoutOrder = 1,
							BackgroundTransparency = 0.5,
							Size = UDim2.new(1, 0, 0, 28),
							FontFace = UI.Theme.Font,
							TextSize = 14,
							TextXAlignment = Enum.TextXAlignment.Left,
							Text = "Prefix: ;",
						},
						UI.new "TextLabel" {
							Name = "Row2",
							LayoutOrder = 2,
							BackgroundTransparency = 0.5,
							Size = UDim2.new(1, 0, 0, 28),
							FontFace = UI.Theme.Font,
							TextSize = 14,
							TextXAlignment = Enum.TextXAlignment.Left,
							Text = "Role: SuperAdmin",
						},
					},
				}

				UI.flush()
				world:run(0.1)
				return { root = panel }
			end,
			{
				presets = {
					{ name = "Phone", size = Vector2.new(390, 844) },
					{ name = "Tablet", size = Vector2.new(820, 1180) },
					{ name = "Desktop", size = Vector2.new(1920, 1080) },
					{ name = "Console", size = Vector2.new(1920, 1080) },
				},
				settle = false,
				check = function(root, vp)
					sert.eq(root.AbsoluteSize.X > 0 and root.AbsoluteSize.X <= vp.size.X, true)
					sert.eq(root.AbsoluteSize.Y > 0 and root.AbsoluteSize.Y <= vp.size.Y, true)
					local toolbar = root:FindFirstChild("Toolbar")
					sert.eq(toolbar ~= nil, true)
					local execBtn = toolbar:FindFirstChild("ExecuteButton")
					local modeSw = toolbar:FindFirstChild("ModeSwitch")
					local confirmCb = toolbar:FindFirstChild("ConfirmCheck")
					sert.eq(execBtn ~= nil and execBtn.AbsoluteSize.X > 0, true)
					sert.eq(modeSw ~= nil and modeSw.AbsoluteSize.X > 0, true)
					sert.eq(confirmCb ~= nil and confirmCb.AbsoluteSize.X > 0, true)
				end,
			}
		)
	end
end)

describe("Client and UI · Slider & Window Regressions", function()
	test("Slider avoids 0/0 NaN when zero-sized and uses dynamic _padding", function()
		local world = sert.sim.new({ backing = true })
		local server = world:server()
		local client = server:client(1, "Player1")
		local cliMounted = setupClientEnv(client)
		local env = cliMounted.env
		local UI = env:require(cliMounted.Client.UI)
		if UI.registerClasses then
			UI.registerClasses()
		end

		local slider = UI.new "Slider" {
			Parent = UI.LayerDefault,
			Snap = 0,
			Value = 0.5,
		}
		UI.flush()
		world:run(0.1)

		-- Unmounted / zero-size slider drag produces 0 instead of NaN
		env:setAbsolute(slider._instance, Vector2.zero, Vector2.zero)
		local down = makeInput(env, {
			UserInputType = Enum.UserInputType.MouseButton1,
			UserInputState = Enum.UserInputState.Begin,
			Position = Vector3.new(0, 0, 0),
		})
		slider._instance.InputBegan:Fire(down, false)
		UI.flush()
		local valZero = slider.Value:peek()
		sert.eq(valZero == valZero, true)
		sert.eq(valZero, 0)
		down.UserInputState = Enum.UserInputState.End

		-- Dynamic padding: FontSizeSmaller (12) + PaddingHalf (16) -> pad = 28; width = 156 -> span = 100
		local origPadding = UI.Theme.Padding:peek()
		UI.Theme.Padding(UDim.new(0, 32))
		UI.flush()
		local pad = slider._padding:peek().Offset
		env:setAbsolute(slider._instance, Vector2.new(100 + pad * 2, 32), Vector2.new(10, 10))
		local down2 = makeInput(env, {
			UserInputType = Enum.UserInputType.MouseButton1,
			UserInputState = Enum.UserInputState.Begin,
			Position = Vector3.new(10 + pad + 50, 20, 0),
		})
		slider._instance.InputBegan:Fire(down2, false)
		UI.flush()
		sert.eq(math.abs(slider.Value:peek() - 0.5) < 1e-4, true)
		down2.UserInputState = Enum.UserInputState.End

		UI.Theme.Padding(origPadding)
		slider:Destroy()
		UI.flush()
	end)

	test("Window restores MouseIconEnabled on hide/Destroy and positions ResizeIcon in offset containers", function()
		local world = sert.sim.new({ backing = true })
		local server = world:server()
		local client = server:client(1, "Player1")
		local cliMounted = setupClientEnv(client)
		local env = cliMounted.env
		local UI = env:require(cliMounted.Client.UI)
		if UI.registerClasses then
			UI.registerClasses()
		end
		UI.UserInputService.MouseIconEnabled = true

		local offsetContainer = UI.new "Frame" {
			Parent = UI.LayerDefault,
			Position = UDim2.fromOffset(50, 80),
			Size = UDim2.fromOffset(800, 600),
		}
		env:setAbsolute(offsetContainer, Vector2.new(800, 600), Vector2.new(50, 80))

		world:run(0.2)
		UI.flush()
		local baseline = observers(UI.Theme.TweenOut)

		local win = UI.new "Window" {
			Parent = offsetContainer,
			Position = UDim2.fromOffset(100, 100),
			Size = UDim2.fromOffset(300, 200),
		}
		win._instance.Visible = true
		env:setAbsolute(win._instance, Vector2.new(300, 200), Vector2.new(150, 180))
		UI.flush()

		-- Hover right resize edge at screen (450, 250) -> local (300 - 12, 70 - 12) = (288, 58)
		UI.UserInputService.InputChanged:Fire(
			makeInput(env, {
				UserInputType = Enum.UserInputType.MouseMovement,
				Position = Vector3.new(450, 250, 0),
			}),
			false
		)
		UI.flush()
		sert.eq(UI.UserInputService.MouseIconEnabled, false)
		local resizeIcon = win._instance:FindFirstChild("ResizeIcon")
		sert.eq(resizeIcon ~= nil, true)
		sert.eq(resizeIcon.Visible, true)
		sert.eq(resizeIcon.Position, UDim2.fromOffset(288, 58))

		-- Hiding window while hovering resize edge restores MouseIconEnabled
		win._instance.Visible = false
		UI.flush()
		sert.eq(UI.UserInputService.MouseIconEnabled, true)
		sert.eq(resizeIcon.Visible, false)

		-- Showing again, hovering resize edge, and destroying restores MouseIconEnabled and cleans observers
		win._instance.Visible = true
		env:setAbsolute(win._instance, Vector2.new(300, 200), Vector2.new(150, 180))
		UI.UserInputService.InputChanged:Fire(
			makeInput(env, {
				UserInputType = Enum.UserInputType.MouseMovement,
				Position = Vector3.new(450, 250, 0),
			}),
			false
		)
		UI.flush()
		sert.eq(UI.UserInputService.MouseIconEnabled, false)

		win:Destroy()
		UI.flush()
		world:step()
		sert.eq(UI.UserInputService.MouseIconEnabled, true)
		sert.eq(observers(UI.Theme.TweenOut), baseline)
		offsetContainer:Destroy()
	end)
end)

do
	return {}
end
