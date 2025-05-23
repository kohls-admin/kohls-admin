export type Dict = { [any]: any }

export type Environment = {} | (_K: any) -> {}

--- @within Registry
--- @type ArgumentFunction (value: any, from: Player) -> ...any
export type ArgumentFunction = (value: any, from: Player) -> ...any

--- @within Registry
--- @type ArgumentType {name: string, displayName: string?, listable: boolean?, filterLog: boolean?, transform: ArgumentFunction?, validate: ArgumentFunction, parse: ArgumentFunction, preParse: ArgumentFunction?, postParse: ArgumentFunction?, suggestions: ArgumentFunction?, prefixes: { [string]: string }? }
export type ArgumentType = {
	name: string?,
	displayName: string?,
	listable: boolean?,
	filterLog: boolean?,
	transform: ArgumentFunction?,
	validate: ArgumentFunction?,
	parse: ArgumentFunction?,
	postParse: ArgumentFunction?,
	suggestions: ArgumentFunction?,
	prefixes: { [string]: string }?,
}

--- @within Registry
--- @type ArgumentDefinition {type: string, name: string, description: string, optional: boolean?, permissions: { [string]: boolean }?, lowerRank: boolean?, ignoreSelf: boolean?, shouldRequest: boolean? }
export type ArgumentDefinition = {
	type: string,
	name: string,
	description: string,
	optional: boolean?,
	permissions: { [string]: boolean }?,
	-- player type options
	lowerRank: boolean?,
	ignoreSelf: boolean?,
	shouldRequest: boolean?,
}

--- @within Registry
--- @type CommandDefinition {name: string, aliases: { string }?, description: string, group: string, noLog: boolean?, args: { ArgumentDefinition }, permissions: { [string]: boolean }?, envClient: {} | () -> {}?, env: {} | () -> {}?, runClient: (...any) -> ()?, run: (...any) -> ()? }
export type CommandDefinition = {
	name: string,
	aliases: { string }?,
	description: string,
	group: string,
	noLog: boolean?,
	args: { ArgumentDefinition }?,
	permissions: { [string]: boolean }?,
	envClient: Environment?,
	env: Environment?,
	runClient: (...any) -> ()?,
	run: (...any) -> ()?,
	_listIndex: number?,
}

return {}
