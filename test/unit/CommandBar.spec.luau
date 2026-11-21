local ClientHarness = require("./ClientHarness")
local Harness = require("./Harness")
local sert = require("../sert")

local describe, test = sert.describe, sert.test

local setupClientEnv = ClientHarness.setupClientEnv
local makeInput = ClientHarness.makeInput

local Enum = Harness.globals.Enum

describe("Client and UI", function()
	describe("Part 3 · CompletionData & CommandBar", function()
		test(
			"CompletionData handles history, invalid strings, command suggestions, chaining, and argument completion",
			function()
				local world = sert.sim.new({ backing = true })
				local server = world:server()
				local client = server:client(1, "Player1")
				local cliMounted = setupClientEnv(client, { mockRemote = true })

				local _K = cliMounted:requireK()
				Harness.seedRoles(_K.Data)
				_K.Data.settings.prefix = { ";" }
				_K.Data.settings.splitKey = " "
				_K.client = {
					playerPrefix = _K.Flux.signal(";"),
					settings = {
						prefix = _K.Flux.signal({ ";" }),
						onlyShowUsableCommands = _K.Flux.signal(false),
					},
					hotkeys = {},
				}

				-- Authorize everyone commands, restrict ban initially
				for _, cmd in _K.Registry.commands do
					cmd.LocalPlayerAuthorized = _K.Auth.roleCanUseCommand("everyone", cmd)
					cmd.RestrictedToRole = _K.Data.roles.admin
				end
				if _K.Registry.commands.version then
					_K.Registry.commands.version.LocalPlayerAuthorized = true
				end
				if _K.Registry.commands.ban then
					_K.Registry.commands.ban.LocalPlayerAuthorized = false
					_K.Registry.commands.ban.RestrictedToRole = _K.Data.roles.admin
				end

				local CompletionData = cliMounted.env:require(cliMounted.Client.CommandBar.CompletionData)

				-- 1. Empty prefix -> History
				local dHist = CompletionData(_K, ";", 2)
				sert.eq(dHist.suggestionType, "History")
				sert.eq(dHist.argPos, 2)
				sert.eq(dHist.argIndex, 0)
				sert.eq(dHist.rawArg, "")
				sert.eq(dHist.query, "")

				-- 2. Invalid command string (`; `)
				local dInvalidStr = CompletionData(_K, "; ", 3)
				sert.eq(#dInvalidStr.invalid > 0, true)
				sert.eq(dInvalidStr.invalid[1][1], "Invalid command string")

				-- 3. Cursor within command name (`;ver` at pos 5) and mid-word (`;version` at pos 5) and exact command (`;version` at pos 9)
				local dCmd = CompletionData(_K, ";ver", 5)
				sert.eq(dCmd.argIndex, 1)
				sert.eq(dCmd.argPos, 2)
				sert.eq(dCmd.rawArg, "ver")
				sert.eq(dCmd.query, "ver")
				sert.eq(dCmd.suggestionType, _K.Registry.types.command)
				sert.eq(#dCmd.suggestions > 0, true)
				sert.eq(dCmd.validSuggestion, true)
				sert.eq(dCmd.commandDefinition, _K.Registry.commands.version)

				local dMidCmd = CompletionData(_K, ";version", 5)
				sert.eq(dMidCmd.rawArg, "version")
				sert.eq(dMidCmd.query, "ver")

				local dExactCmd = CompletionData(_K, ";version", 9)
				sert.eq(dExactCmd.commandDefinition, _K.Registry.commands.version)
				sert.eq(#dExactCmd.commands, 1)
				sert.eq(dExactCmd.commands[1].validated, true)

				-- 4. Restricted command when cursor is on command (with onlyShowUsableCommands false and true) or after command
				local dRestrIn = CompletionData(_K, ";ban", 5)
				sert.eq(dRestrIn.argIndex, 1)
				sert.eq(dRestrIn.commandDefinition, _K.Registry.commands.ban)
				local foundInvalidSug = false
				for _, sug in dRestrIn.suggestions do
					if sug[4] == true then
						foundInvalidSug = true
					end
				end
				sert.eq(foundInvalidSug, true)
				_K.client.settings.onlyShowUsableCommands(true)
				local dRestrHidden = CompletionData(_K, ";ban", 5)
				sert.eq(#dRestrHidden.invalid > 0, true)
				_K.client.settings.onlyShowUsableCommands(false)

				local dRestrAfter = CompletionData(_K, ";ban ", 6)
				sert.eq(#dRestrAfter.invalid > 0, true)
				sert.eq(string.find(dRestrAfter.invalid[1][1], "restricted") ~= nil, true)

				-- Chained command where first command is restricted (`;ban ;ver`)
				local dChainRestr = CompletionData(_K, ";ban ;ver", 10)
				sert.eq(#dChainRestr.invalid > 0, true)
				sert.eq(#dChainRestr.commands, 1)

				-- 5. Invalid command name outside (`;notacommand `) and inside args (`;notacommand arg1`)
				local dBadCmd = CompletionData(_K, ";notacommand ", 14)
				sert.eq(#dBadCmd.invalid > 0, true)
				sert.eq(string.find(dBadCmd.invalid[1][1], "did you mean") ~= nil, true)

				local dBadCmdInArgs = CompletionData(_K, ";notacommand arg1", 18)
				sert.eq(#dBadCmdInArgs.invalid > 0, true)
				sert.eq(string.find(dBadCmdInArgs.invalid[1][1], "did you mean") ~= nil, true)

				-- 6. Chained command where cursor is in second command (`;version ;ver`)
				local dChain = CompletionData(_K, ";version ;ver", 14)
				sert.eq(#dChain.commands, 1)
				sert.eq(dChain.commands[1].validated, true)
				sert.eq(dChain.argIndex, 1)

				-- Chained command where first command is invalid (`;notacommand ;help`) continues to complete second command
				local dChainBad = CompletionData(_K, ";notacommand ;help", 19)
				sert.eq(dChainBad.argIndex, 1)
				sert.eq(dChainBad.argPos, 15)
				sert.eq(dChainBad.rawArg, "help")
				sert.eq(dChainBad.query, "help")
				sert.eq(dChainBad.hasInvalidCommand, true)
				sert.eq(dChainBad.cursorInvalid, false)
				sert.eq(#dChainBad.invalid > 0, true)

				-- Leading or middle empty chained commands flag hasInvalidCommand while still completing trailing command
				local dLeadingEmpty = CompletionData(_K, "; ;help", 8)
				sert.eq(dLeadingEmpty.hasInvalidCommand, true)
				sert.eq(#dLeadingEmpty.invalid > 0, true)
				sert.eq(dLeadingEmpty.argIndex, 1)
				sert.eq(dLeadingEmpty.rawArg, "help")
				sert.eq(dLeadingEmpty.query, "help")

				local dMidEmpty = CompletionData(_K, ";help ; ;version", 17)
				sert.eq(dMidEmpty.hasInvalidCommand, true)
				sert.eq(#dMidEmpty.invalid > 0, true)
				sert.eq(dMidEmpty.rawArg, "version")

				-- Unknown command with zero suggestions does not crash on suggestions[1][3]
				local origCmdSuggestions = _K.Registry.types.command.suggestions
				_K.Registry.types.command.suggestions = function()
					return {}
				end
				local dNoSugg = CompletionData(_K, ";zzzzzzzzzzzz", 14)
				_K.Registry.types.command.suggestions = origCmdSuggestions
				sert.eq(dNoSugg.hasInvalidCommand, true)
				sert.eq(#(dNoSugg.suggestions or {}), 0)
				sert.eq(dNoSugg.commandDefinition, nil)
				local dNoSuggPast = CompletionData(_K, ";zzzzzzzzzzzz ", 15)
				sert.eq(dNoSuggPast.hasInvalidCommand, true)
				sert.eq(dNoSuggPast.cursorInvalid, true)

				-- 7. Grant creator role and authorize all commands to test argument completion
				_K.Auth.userRoleAdd(1, "creator")
				for _, cmd in _K.Registry.commands do
					cmd.LocalPlayerAuthorized = true
				end

				-- Chained command where first command is authorized but has an invalid arg (`;ban Player1 ;ver`)
				local dChainBadArg = CompletionData(_K, ";ban Player1 ;ver", 18)
				sert.eq(#dChainBadArg.invalid > 0, true)

				-- Cursor on 1st arg, 2nd arg, 3rd (greedy string) arg of `;ban`
				local dArg1 = CompletionData(_K, ';ban "2"', 8)
				sert.eq(dArg1.commandDefinition, _K.Registry.commands.ban)
				sert.eq(#dArg1.commands, 1)
				sert.eq(dArg1.arg ~= nil, true)
				sert.eq(dArg1.argIndex, 2)
				sert.eq(dArg1.argPos, 6)
				sert.eq(dArg1.rawArg, '"2"')
				sert.eq(dArg1.rawQuery, '"2')
				sert.eq(dArg1.query, "2")
				sert.eq(dArg1.argDefinition, _K.Registry.commands.ban.args[1])
				sert.eq(dArg1.transformedArg, "2")
				sert.eq(dArg1.suggestionType, _K.Registry.types.userIds)
				sert.eq(dArg1.suggestions ~= nil, true)

				-- Prefix arg (`@admin`) transforms to rolePlayers suggestionType
				local dPrefixArg = CompletionData(_K, ";ban @admin", 12)
				sert.eq(dPrefixArg.argPos, 6)
				sert.eq(dPrefixArg.rawArg, "@admin")
				sert.eq(dPrefixArg.suggestionType, _K.Registry.types.rolePlayers)

				-- Listable arg with `,` delimiter
				local dArgList = CompletionData(_K, ';ban 2,"34"', 10)
				sert.eq(dArgList.argIndex, 2)
				sert.eq(dArgList.argPos, 8)
				sert.eq(dArgList.rawArg, '"34"')
				sert.eq(dArgList.rawQuery, '"3')
				sert.eq(dArgList.query, "3")
				sert.eq(CompletionData(_K, ';ban 2,"34"', 7).rawArg, "2")

				local dArg2 = CompletionData(_K, ";ban 2 10", 10)
				sert.eq(dArg2.argIndex, 3)
				sert.eq(dArg2.argPos, 8)
				sert.eq(dArg2.rawArg, "10")
				sert.eq(CompletionData(_K, ';ban 2 "seconds"', 17).skipped, nil)
				sert.eq(#CompletionData(_K, ";ban ", 5).invalid, 0)

				-- Skipped optional argument with suggestions (`;ban 2 "seconds"` with cursor inside skipped arg)
				local dSkipped = CompletionData(_K, ';ban 2 "seconds"', 10)
				sert.eq(dSkipped.skipped, true)
				sert.eq(dSkipped.rawQuery, '"s')
				sert.eq(dSkipped.query, "s")
				sert.eq(dSkipped.suggestions ~= nil and #dSkipped.suggestions > 0, true)
				sert.eq(dSkipped.suggestions[1][1] ~= "0", true)

				local dArg3 = CompletionData(_K, ";ban 2 10m some reason here   ", 31)
				sert.eq(dArg3.argIndex, 4)
				sert.eq(dArg3.rawArg, "some reason here   ")

				-- Greedy chatString / stringGreedy commands (`;m h` and `;m he`) with legacy splitKey = "%s"
				_K.Data.settings.splitKey = "%s"
				local dMsgH = CompletionData(_K, ";m h", 5)
				sert.eq(dMsgH.commandDefinition, _K.Registry.commands.message)
				sert.eq(dMsgH.argIndex, 2)
				sert.eq(dMsgH.rawArg, "h")
				sert.eq(#dMsgH.invalid, 0)
				local dMsgHe = CompletionData(_K, ";m he   ", 9)
				sert.eq(dMsgHe.commandDefinition, _K.Registry.commands.message)
				sert.eq(dMsgHe.argIndex, 2)
				sert.eq(dMsgHe.rawArg, "he   ")
				sert.eq(dMsgHe.suggestionType, _K.Registry.types.chatString)
				sert.eq(#dMsgHe.invalid, 0)
				_K.Data.settings.splitKey = " "

				-- Invalid argument value (targeting self when ignoreSelf = true)
				local dBadArg = CompletionData(_K, ";ban Player1 10m", 17)
				sert.eq(#dBadArg.invalid > 0, true)
				sert.eq(dBadArg.commands[1].Error ~= nil, true)

				-- Mid-token cursor slicing and empty rawArgs / nil suggestions / non-invalidArg command failure
				local dMidArg = CompletionData(_K, ';ban "2345" 10m', 8)
				sert.eq(dMidArg.rawArg, '"2345"')
				sert.eq(dMidArg.rawQuery, '"2')
				sert.eq(dMidArg.query, "2")

				local dMidSkip = CompletionData(_K, ';ban 2 "seconds"', 11)
				sert.eq(dMidSkip.skipped, true)
				sert.eq(dMidSkip.rawQuery, '"se')
				sert.eq(dMidSkip.query, "se")

				_K.Registry.registerType("testnosuggest", {
					listable = false,
					validate = function()
						return true
					end,
					parse = function(v)
						return v
					end,
				})
				_K.Registry.registerCommand(_K, {
					name = "testcompedge",
					aliases = {},
					description = "Completion edge cases",
					group = "Utility",
					LocalPlayerAuthorized = true,
					args = {
						{ type = "testnosuggest", name = "NoSug", description = "NoSug", optional = true },
						{ type = "players", name = "Plr", description = "Plr" },
						{ type = "integer", name = "Num", description = "Num" },
					},
					runClient = function() end,
				})
				-- When shouldFillWithSelf fills "me" for arg 2 (players), arg.rawArg is "me" while arg.skipped is '"xyz"'
				local dSelfSkip = CompletionData(_K, ';testcompedge 1 "xyz" 5', 18)
				sert.eq(dSelfSkip.skipped, true)
				sert.eq(dSelfSkip.rawQuery, '"')
				sert.eq(dSelfSkip.query, "")
				local origSplit = _K.Util.String.splitOutsideQuotes
				_K.Registry.types.testnosuggest.listable = true
				_K.Util.String.splitOutsideQuotes = function()
					return {}
				end
				local dNoRawArgs = CompletionData(_K, ';testcompedge "abc" 5', 18)
				sert.eq(dNoRawArgs.argPos, 15)
				sert.eq(dNoRawArgs.rawArg, '"abc"')
				sert.eq(dNoRawArgs.rawQuery, '"ab')
				sert.eq(dNoRawArgs.query, "ab")
				sert.eq(dNoRawArgs.suggestionType, _K.Registry.types.testnosuggest)
				_K.Util.String.splitOutsideQuotes = origSplit
				_K.Registry.types.testnosuggest.listable = false

				-- Skipped arg when rawType.suggestions returns {} or is nil falls through to next arg without breaking
				_K.Registry.types.testnosuggest.validate = function()
					return false
				end
				_K.Registry.types.testnosuggest.suggestions = function()
					return {}
				end
				sert.eq(CompletionData(_K, ';testcompedge "xyz" 42', 16).argIndex, 3)
				_K.Registry.types.testnosuggest.suggestions = nil
				local dSkipNilSug = CompletionData(_K, ";testcompedge 42", 16)
				sert.eq(dSkipNilSug.suggestions == nil or type(dSkipNilSug.suggestions) == "table", true)
				_K.Registry.types.testnosuggest.validate = function()
					return true
				end

				-- #363: Chained commands validate subsequent commands even when cursor is at the end of the first command name
				local dChainInvalid = CompletionData(_K, ";fly ;notacommand", 5)
				sert.eq(#dChainInvalid.invalid > 0, true)
				sert.eq(dChainInvalid.argPos, 2)
				sert.eq(dChainInvalid.rawArg, "fly")

				local dChainMissingArg = CompletionData(_K, ";fly ;ban", 5)
				sert.eq(#dChainMissingArg.invalid > 0, true)

				-- #364: Complete valid short commands (under 3 chars, e.g. ;ff or ;tp) populate data.commands and have no invalid entries
				local dShortValid = CompletionData(_K, ";ff", 4)
				sert.eq(#dShortValid.commands, 1)
				sert.eq(dShortValid.commands[1].validated, true)
				sert.eq(#dShortValid.invalid, 0)
			end
		)

		do
			local cbSut: any = nil
			local liveHistory: { string } = {}

			local function getOrCreateCommandBarSut()
				if cbSut and #cbSut.world.scheduler.errors == 0 then
					return cbSut
				end
				local world = sert.sim.new({ backing = true })
				local server = world:server()
				local client = server:client(1, "Player1")
				local cliMounted = setupClientEnv(client, { mockRemote = true })

				local _K = cliMounted:requireK()
				Harness.seedRoles(_K.Data)
				_K.Data.settings.prefix = { ";" }
				_K.Data.settings.splitKey = " "
				_K.Auth.userRoleAdd(1, "admin")

				local UI = cliMounted.env:require(cliMounted.Client.UI)
				if UI.registerClasses then
					UI.registerClasses()
				end
				_K.UI = UI
				_K.IsClient = true
				_K.LocalPlayer = cliMounted.env.Players.LocalPlayer
				_K.Notify = function() end
				_K.client = {
					rank = _K.Flux.signal(3),
					commandBarEnabled = true,
					dashboardButtonEnabled = true,
					dashboardButton = { Visible = true },
					playerPrefix = _K.Flux.signal(";"),
					settings = {
						prefix = _K.Flux.signal({ ";" }),
						onlyShowUsableCommands = _K.Flux.signal(false),
					},
					hotkeys = {},
				}

				for _, extraName in { "testalpha", "testbeta" } do
					_K.Registry.registerCommand(_K, {
						name = extraName,
						aliases = {},
						description = `Test command {extraName}`,
						group = "Utility",
						args = {},
						runClient = function() end,
					})
				end

				for _, cmd in _K.Registry.commands do
					cmd.LocalPlayerAuthorized = _K.Auth.roleCanUseCommand("admin", cmd)
						or _K.Auth.roleCanUseCommand("mod", cmd)
						or _K.Auth.roleCanUseCommand("everyone", cmd)
					cmd.RestrictedToRole = _K.Data.roles.superadmin
				end
				for _, name in { "version", "help", "cmds", "fly", "ban", "testalpha", "testbeta" } do
					if _K.Registry.commands[name] then
						_K.Registry.commands[name].LocalPlayerAuthorized = true
					end
				end
				if _K.Registry.commands.shutdown then
					_K.Registry.commands.shutdown.LocalPlayerAuthorized = false
					_K.Registry.commands.shutdown.RestrictedToRole = _K.Data.roles.superadmin
				end

				local CompletionData = cliMounted.env:require(cliMounted.Client.CommandBar.CompletionData)
				local CommandBar = cliMounted.env:require(cliMounted.Client.CommandBar)
				CommandBar:init(_K)
				world:run(0.1)

				table.clear(liveHistory)
				cbSut = {
					world = world,
					env = cliMounted.env,
					_K = _K,
					UI = UI,
					CompletionData = CompletionData,
					CommandBar = CommandBar,
				}
				return cbSut
			end

			local TOKEN_INPUTS = {
				";",
				";ver",
				";version",
				";help",
				";testalpha",
				";testbeta",
				";fly",
				";fly me",
				";ban 2 10m reason",
				";version ;help",
				";shutdown",
				";notacommand ",
			}
			local EXECUTABLE_INPUTS = {
				";version",
				";help",
				";testalpha",
				";testbeta",
				";notacommand ",
				";",
			}

			sert.model("CommandBar & CompletionData Autocomplete and History State Machine", {
				setup = function()
					local sut = getOrCreateCommandBarSut()
					local input = sut.CommandBar.Input
					input._input.SelectionStart = -1
					input:SetValue(";")
					input._input.CursorPosition = 2
					sut.CommandBar.updateCompletionData()
					sut.world:step()
					return sut
				end,
				init = function()
					return {
						prefix = ";",
						text = ";",
						cursor = 2,
						suggestionIndex = 1,
						history = table.clone(liveHistory),
					}
				end,
				commands = {
					TypeToken = {
						gen = function(_state, g)
							return g:pick(TOKEN_INPUTS)
						end,
						run = function(sut, text)
							local input = sut.CommandBar.Input
							input._input.SelectionStart = -1
							input:SetValue(text)
							input._input.CursorPosition = #text + 1
							sut.CommandBar.updateCompletionData()
							sut.world:step()
						end,
						next = function(state, text)
							state.text = text
							state.cursor = #text + 1
							state.suggestionIndex = 1
							return state
						end,
					},
					MoveCursor = {
						gen = function(state, g)
							return g:int(1, #state.text + 1)
						end,
						run = function(sut, pos)
							local input = sut.CommandBar.Input
							input._input.SelectionStart = -1
							input._input.CursorPosition = pos
							sut.CommandBar.updateCompletionData()
							sut.world:step()
						end,
						next = function(state, pos)
							state.cursor = math.max(#state.prefix + 1, pos)
							state.suggestionIndex = 1
							return state
						end,
					},
					CycleSuggestion = {
						gen = function(_state, g)
							return {
								dir = g:pick({ "Up", "Down" }),
								steps = g:int(1, 3),
							}
						end,
						run = function(sut, arg)
							local input = sut.CommandBar.Input
							input._input:CaptureFocus()
							local keyCode = if arg.dir == "Up" then Enum.KeyCode.Up else Enum.KeyCode.Down
							for _ = 1, arg.steps do
								sut.UI.UserInputService.InputBegan:Fire(
									makeInput(
										sut.env,
										{ UserInputType = Enum.UserInputType.Keyboard, KeyCode = keyCode }
									),
									false
								)
							end
							sut.world:step()
						end,
						next = function(state, arg)
							local sut = getOrCreateCommandBarSut()
							local isHistory = (state.text == state.prefix)
							local count = 1
							if isHistory then
								count = math.max(1, #state.history)
							else
								local d = sut.CompletionData(sut._K, state.text, state.cursor)
								count = math.max(1, if d.suggestions then #d.suggestions else 1)
							end
							for _ = 1, arg.steps do
								if isHistory then
									if arg.dir == "Up" then
										state.suggestionIndex = math.min(count, state.suggestionIndex + 1)
									else
										state.suggestionIndex = math.max(1, state.suggestionIndex - 1)
									end
								else
									if arg.dir == "Up" then
										state.suggestionIndex = math.max(1, state.suggestionIndex - 1)
									else
										state.suggestionIndex = math.min(count, state.suggestionIndex + 1)
									end
								end
							end
							return state
						end,
					},
					NavigateHistory = {
						gen = function(_state, g)
							return g:int(0, 3)
						end,
						run = function(sut, upSteps)
							local input = sut.CommandBar.Input
							input._input.SelectionStart = -1
							input:SetValue(";")
							input._input.CursorPosition = 2
							input._input:CaptureFocus()
							sut.world:step()
							sut.CommandBar.updateCompletionData()
							for _ = 1, upSteps do
								sut.UI.UserInputService.InputBegan:Fire(
									makeInput(
										sut.env,
										{ UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Up }
									),
									false
								)
							end
							sut.world:step()
						end,
						next = function(state, upSteps)
							state.text = state.prefix
							state.cursor = 2
							state.suggestionIndex = 1
							local count = math.max(1, #state.history)
							for _ = 1, upSteps do
								state.suggestionIndex = math.min(count, state.suggestionIndex + 1)
							end
							return state
						end,
					},
					ExecuteCommand = {
						gen = function(_state, g)
							return g:pick(EXECUTABLE_INPUTS)
						end,
						run = function(sut, cmdText)
							local input = sut.CommandBar.Input
							input._input.SelectionStart = -1
							input._input:ReleaseFocus()
							input:SetValue(cmdText)
							input._input.CursorPosition = #cmdText + 1
							sut.CommandBar.updateCompletionData()
							input._input.FocusLost:Fire(true)
							sut.world:step()
							input._input.SelectionStart = -1
							input._input.CursorPosition = #input._input.Text + 1
							sut.CommandBar.updateCompletionData()
							sut.world:step()
						end,
						next = function(state, cmdText)
							local sut = getOrCreateCommandBarSut()
							local d = sut.CompletionData(sut._K, cmdText, #cmdText + 1)
							local hasInvalidArg = false
							for _, cmd in d.commands do
								if cmd.invalidArg then
									hasInvalidArg = true
									break
								end
							end
							if
								d.hasInvalidCommand
								or #d.invalid > 0
								or (cmdText ~= state.prefix and (#d.commands < 1 or #d.commands < (d.rawCommandsCount or 1)))
								or hasInvalidArg
							then
								local trimmedInvalid = sut._K.Util.String.trimEnd(cmdText)
								state.text = trimmedInvalid
								state.cursor = #trimmedInvalid + 1
								state.suggestionIndex = 1
								return state
							end
							if cmdText ~= state.prefix then
								local trimmed = sut._K.Util.String.trimEnd(cmdText)
								local entry = string.sub(trimmed, 2)
								for _, hist in { state.history, liveHistory } do
									local idx = table.find(hist, entry)
									if idx ~= 1 then
										if idx then
											table.remove(hist, idx)
										end
										table.insert(hist, 1, entry)
										if #hist > 32 then
											table.remove(hist)
										end
									end
								end
							end
							state.text = state.prefix
							state.cursor = 2
							state.suggestionIndex = 1
							return state
						end,
					},
				},
				invariants = {
					commandBarMatchesModel = function(state, sut)
						sert.eq(sut.world.scheduler.errors, {})
						local input = sut.CommandBar.Input
						sert.eq(input._input.Text, state.text)
						sert.eq(input._input.CursorPosition, state.cursor)
						sert.eq(input._input.CursorPosition >= #state.prefix + 1, true)

						local d = sut.CompletionData(sut._K, state.text, state.cursor)
						if state.text == state.prefix then
							sert.eq(d.suggestionType, "History")
							sert.eq(d.argIndex, 0)
							sert.eq(d.argPos, 2)
							if #state.history > 0 then
								local expectedCmd = state.history[state.suggestionIndex]
								local display = input.DisplayText:peek()
								sert.eq(string.find(display, expectedCmd, 1, true) ~= nil, true)
							end
						else
							local validSignal = sut._K.client.CommandBarState[1]:peek()
							if d.hasInvalidCommand or #d.invalid > 0 then
								sert.eq(validSignal, false)
							end
						end
					end,
				},
			}, { runs = 12, length = 12 })
		end
	end)
end)

do
	return {}
end
