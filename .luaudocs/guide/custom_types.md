---
sidebar_position: 5
---

# Custom Argument Types

When the [built-in argument types](/guide/custom_commands#built-in-argument-types) and inline enums aren't enough, you can register custom argument types with [`_K.Registry.registerType`](/api/Registry#registertype). Custom types integrate directly with the Command Bar's autocomplete, validation indicator, and argument parser.

:::warning Register Types in Shared Addons
Just like [Custom Commands](/guide/custom_commands), always register custom argument types inside a **Shared** addon (no `"Server"` or `"Client"` in the `ModuleScript` name) so both the client Command Bar and the server command processor can validate and parse the type.
:::

## Quick Helpers

Before writing a full parser from scratch, check if one of the two built-in type factories fits your needs:

### 1. Enum Types (`_K.Registry.makeEnumType`)

[`_K.Registry.makeEnumType(typeName, enumItems)`](/api/Registry#makeenumtype) builds a complete `ArgumentType` with fuzzy autocomplete and validation from a list of strings or `EnumItem`s:

```luau
return function(_K)
	local classes = { "Warrior", "Mage", "Rogue", "Paladin", "Ranger" }
	local classType = _K.Registry.makeEnumType("class", classes)

	-- Register singular ("class") and comma-separated listable ("classes") variants:
	_K.Registry.registerType("class", classType)
	_K.Registry.registerType("classes", { listable = true }, classType)
end
```

### 2. Sequence Types (`_K.Registry.makeSequenceType`)

[`_K.Registry.makeSequenceType(definition)`](/api/Registry#makesequencetype) builds a comma-delimited sequence type (like `vector3` or `vector2`):

```luau
return function(_K)
	local udim2Type = _K.Registry.makeSequenceType({
		length = 4,
		transform = tonumber,
		validate = function(value, index)
			if value == nil then
				return false, `Invalid number at component {index} in UDim2`
			end
			return true
		end,
		constructor = UDim2.new,
	})

	_K.Registry.registerType("udim2", udim2Type)
end
```

---

## Full Custom Type Registration (`_K.Registry.registerType`)

For dynamic game objects (such as vehicles, zones, quests, or inventory items), pass an [`ArgumentType`](/api/Registry#argumenttype) table to [`_K.Registry.registerType(name, typeObject, override?)`](/api/Registry#registertype).

### How the Argument Pipeline Works

When a user types an argument, `src/Shared/Process/Argument.luau` processes each token through 4 stages (`transform` → `validate` → `parse` → `postParse`):

1. **`transform(rawText: string) -> (any, string?)`** *(Optional)*:
   Pre-processes the raw token (e.g., `string.lower` or `tonumber`). Returning `nil` (for a non-optional argument) immediately invalidates the argument with the optional second return string as the error message.
2. **`validate(value: any, self: Argument) -> (boolean, string?)`** *(Required)*:
   Returns `true` if `value` is valid, or `false, "Error reason"` to mark the argument invalid in the Command Bar and block execution.
3. **`parse(value: any, self: Argument) -> (any, string?)`** *(Required)*:
   Converts the validated value into the final Luau value passed to `command.run(context, ...)`. Returning `nil, "Error reason"` (or throwing an error) aborts parsing.
4. **`postParse(parsedArgs: { any }, self: Argument) -> { any }`** *(Optional)*:
   Transforms the array of parsed values for listable or prefix-expanded types before unpacking into `run`.

### `ArgumentType` Schema Reference

```luau
type ArgumentType = {
	displayName: string?,                           -- Type name shown in Command Bar tooltips (defaults to registered name)
	listable: boolean?,                             -- When true, splits comma-separated inputs ("a,b") and returns an array
	filterLog: boolean?,                            -- When true, filters the argument in server command logs
	freeText: boolean?,                             -- Marks open-ended user text so live logs mask it as "…" for other players
	prefixes: { [string]: string }?,                -- Maps Lua pattern prefixes (e.g. ["^all$"] = "allItems") to sub-types
	transform: ((text: string) -> (any, string?))?, -- Pre-processes raw string input
	validate: (value: any, self: any) -> (boolean, string?), -- Validates transformed input
	parse: (value: any, self: any) -> (any, string?),        -- Produces the final value passed to command.run
	postParse: ((parsedArgs: { any }, self: any) -> any)?,   -- Post-processes parsed array
	suggestions: ((text: string, from: number, definition: ArgumentDefinition) -> ({ any }, any?))?,
	log: ((self: any) -> string)?,                  -- Optional custom serializer for command logs
}
```

### Autocomplete `suggestions` Format

The `suggestions(text, from, definition)` function returns a list of suggestions for the Command Bar. Each entry in the returned table can be:
- A plain `string` (e.g. `"SportsCar"`).
- An `Instance` (uses `instance.Name`).
- A tuple table `{ matchOrAliases, displayLabel?, value? }`:
  - `matchOrAliases`: A `string` (or `{ string }` array of aliases) inserted when the user presses `Tab`.
  - `displayLabel`: Optional formatted label shown in the suggestion dropdown (defaults to `matchOrAliases`).

---

## Complete Example: Dynamic `"vehicle"` and `"vehicles"` Type

Below is a complete shared addon that registers `"vehicle"` and `"vehicles"` argument types backed by a folder of vehicle models in `ReplicatedStorage.Vehicles`, along with a `;spawnvehicle` command:

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

return function(_K)
	local vehiclesFolder = ReplicatedStorage:WaitForChild("Vehicles")

	local function findVehicle(query: string): Model?
		-- 1. Check exact match first
		for _, vehicle in vehiclesFolder:GetChildren() do
			if string.lower(vehicle.Name) == query then
				return vehicle :: Model
			end
		end
		-- 2. Fall back to prefix match
		for _, vehicle in vehiclesFolder:GetChildren() do
			if string.find(string.lower(vehicle.Name), query, 1, true) == 1 then
				return vehicle :: Model
			end
		end
		return nil
	end

	local vehicleType = {
		displayName = "vehicle",
		transform = string.lower,

		validate = function(query: string): (boolean, string?)
			if findVehicle(query) ~= nil then
				return true
			end
			return false, `Invalid vehicle "{query}"`
		end,

		parse = function(query: string): (Model?, string?)
			local vehicle = findVehicle(query)
			if not vehicle then
				return nil, "Vehicle not found"
			end
			return vehicle
		end,

		suggestions = function(_text: string, _from: number)
			return _K.Util.Suggest.new(vehiclesFolder:GetChildren())
		end,
	}

	-- Register singular ("vehicle" -> Model) and plural ("vehicles" -> { Model }) types
	_K.Registry.registerType("vehicle", vehicleType)
	_K.Registry.registerType("vehicles", { listable = true }, vehicleType)

	-- Use the new type in a custom command!
	_K.Registry.registerCommand(_K, {
		name = "spawnvehicle",
		aliases = { "car", "sv" },
		description = "Spawns a vehicle next to one or more players.",
		group = "General",
		args = {
			{
				type = "players",
				name = "Players",
				description = "The player(s) to spawn the vehicle for.",
			},
			{
				type = "vehicle",
				name = "Vehicle",
				description = "The vehicle model to spawn.",
			},
		},
		run = function(_context, players: { Player }, vehicleTemplate: Model)
			for _, player in players do
				local character = player.Character
				if character and character.PrimaryPart then
					local clone = vehicleTemplate:Clone()
					clone:PivotTo(character:GetPivot() * CFrame.new(0, 0, -10))
					clone.Parent = workspace
				end
			end
		end,
	})
end
```
