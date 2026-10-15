export type Dict = { [any]: any }

--- @within Registry
export type Environment = {} | (_K: any) -> {}

--- @within Registry
export type ArgumentFunction = (value: any, from: Player) -> ...any

--- @within Registry
export type ArgumentType = {
	name: string?,
	displayName: string?,
	listable: boolean?,
	filterLog: boolean?,
	freeText: boolean?,
	transform: ArgumentFunction?,
	validate: ArgumentFunction?,
	parse: ArgumentFunction?,
	postParse: ArgumentFunction?,
	suggestions: ArgumentFunction?,
	prefixes: { [string]: string }?,
}

--- @within Registry
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
