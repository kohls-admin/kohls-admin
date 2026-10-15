---
sidebar_position: 6
---

# Themes & Custom UI

Kohl's Admin features a reactive UI framework powered by [`Flux`](/api/Flux) and [`_K.UI`](/api/UI). You can customize the look and feel of every window using **Themes**, or build your own reactive windows and components inside client addons.

## Customizing Themes (`Config > Themes`)

Kohl's Admin ships with built-in themes (`Default`, `Light`, and `Legacy`) and allows you to define custom studio themes or let players customize their own theme in-game.

### Theme Settings in `Config > Settings`

In `Kohl's Admin > Config > Settings`, two settings control how themes behave:

```luau
theme = "Default", -- Initial theme name (matches a ModuleScript in Config > Themes or built-in Themes)
changeThemeAuthority = "Client", -- "Client", "Server", or "Studio"
```

- **`"Client"` (Default)**: Every player can customize their own UI theme and colors in **Dashboard > Settings** locally. Admins with the `settings` permission can also update the default server-wide theme.
- **`"Server"`**: Only users with the `settings = true` role permission can change the theme, which syncs across all servers.
- **`"Studio"`**: Locks the theme strictly to what you configure in Roblox Studio (`Config > Settings` and `Config > Themes`), preventing any in-game theme changes.

### Creating a Custom Studio Theme

1. Inside `Kohl's Admin > Config`, create a `Folder` named **`Themes`** (if it doesn't already exist).
2. Inside `Config > Themes`, create a `ModuleScript` named after your theme (for example, `Cyberpunk`, or `Default` to override the built-in default theme).
3. Return a table overriding any properties from [`UI.Theme`](/api/Theme) (any omitted properties automatically inherit from `Default`):

```luau
-- Kohl's Admin > Config > Themes > Cyberpunk
return {
	Transparency = 0.05,
	TextStrokeTransparency = 0.85,

	Primary = Color3.fromRGB(15, 10, 30),
	PrimaryText = Color3.fromRGB(240, 240, 255),

	Secondary = Color3.fromRGB(0, 255, 200),
	SecondaryText = Color3.fromRGB(15, 10, 30),

	Border = Color3.fromRGB(0, 200, 255),
	BorderStop = Color3.fromRGB(255, 0, 128),
	BorderAngle = 45,
	StrokeEnabled = true,

	Valid = Color3.fromRGB(0, 255, 140),
	Invalid = Color3.fromRGB(255, 50, 90),

	FontSize = 16,
	Font = Enum.Font.BuilderSans,
	FontMono = Enum.Font.RobotoMono,

	CornerRadius = UDim.new(0, 8),
	Padding = UDim.new(0, 6),
}
```

4. Set `theme = "Cyberpunk"` in `Kohl's Admin > Config > Settings`.

### Theme Properties Reference

| Property | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `Primary` | `Color3` | `RGB(18, 18, 21)` | Main window and container background color. |
| `PrimaryText` | `Color3` | `RGB(255, 255, 255)` | Primary text and icon color on `Primary` surfaces. |
| `Secondary` | `Color3` | `RGB(255, 255, 255)` | Accent and secondary surface color. |
| `SecondaryText` | `Color3` | `RGB(0, 0, 0)` | Text color on `Secondary` surfaces. |
| `Border` | `Color3` | `RGB(100, 100, 100)` | UIStroke border color. |
| `BorderStop` | `Color3` | `RGB(100, 100, 100)` | Secondary gradient color for borders. |
| `BorderAngle` | `number` | `90` | Gradient rotation angle in degrees for borders. |
| `StrokeEnabled` | `boolean` | `false` | Enables or disables 1px `UIStroke` borders across UI components. |
| `Valid` | `Color3` | `RGB(0, 255, 0)` | Positive / valid indicator color. |
| `Invalid` | `Color3` | `RGB(255, 0, 0)` | Error / invalid indicator color. |
| `Transparency` | `number` | `0.08` | Base background transparency (`0` = opaque, `1` = invisible). Automatically computes `TransparencyLight`, `TransparencyMedium`, `TransparencyStrong`, etc. |
| `TextStrokeTransparency` | `number` | `0.875` | Text outline transparency. |
| `Font` | `Font \| Enum.Font` | `Inter` (`12187365364`) | Primary UI font family. |
| `FontMono` | `Font \| Enum.Font` | `Enum.Font.RobotoMono` | Monospace font used in the Command Bar, Logs, and code inputs. |
| `FontSize` | `number` | `16` | Base font size in pixels (automatically scales `FontSizeSmall`, `FontSizeLarge`, etc.). |
| `CornerRadius` | `UDim` | `UDim.new(0, 12)` | Base corner radius for windows and controls. |
| `Padding` | `UDim` | `UDim.new(0, 6)` | Base layout spacing and padding. |
| `BackgroundImage` | `string` | `"rbxassetid://..."` | Optional texture overlaid on window backgrounds. |
| `BackgroundImageTransparency` | `number` | `1` | Transparency of the background image (`1` = hidden by default). |
| `BackgroundGradientEnabled` | `boolean` | `false` | Enables a color gradient across window backgrounds. |
| `BackgroundGradient` / `Stop` / `Angle` | `Color3` / `number` | — | Start color, stop color, and angle for the window background gradient. |
| `SoundEnabled` | `boolean` | `true` | Enables UI hover, click, and notification sound effects. |
| `TypingSounds` | `boolean` | `true` | Enables mechanical clack typing sounds in inputs. |
| `Volume` | `number` | `1` | Master volume for Kohl's Admin UI sounds. |

---

## Building Custom UI with `_K.UI` & `_K.Flux`

On the client (`_K.IsClient`), `_K.UI` inherits from [`_K.Flux`](/api/Flux) and provides a library of themed, reactive UI component classes (`src/Client/UI/Classes`).

### Reactive State (`_K.UI.state` & `_K.UI.compute`)

- **`local count = UI.state(0)`**: Creates a reactive state object. Call `count()` with no arguments to read its current value, or `count(newValue)` to update it and automatically update any bound UI properties!
- **`local doubled = UI.compute(function() return count() * 2 end)`**: Creates a derived state that recalculates whenever any state called inside it changes.

### Built-In UI Component Classes

Pass any of the following class names (or any standard Roblox `Instance` class name like `"Frame"`, `"TextLabel"`, `"UIListLayout"`) to `_K.UI.new "<ClassName>" { ... }`:

| Component Class | Description |
| :--- | :--- |
| `"Window"` | Draggable, resizable window with title bar, icon, minimize/maximize/close buttons, and content container. |
| `"Tabs"` | Tabbed page container (supports horizontal or vertical tab bars). |
| `"List"` & `"ListItem"` | Structured settings/property list and labeled row container. |
| `"Scroller"` & `"ScrollerFast"` | Themed scrolling frame and virtualized high-performance list scroller for thousands of rows. |
| `"Button"` | Interactive button with icon, label, hover/press states, and sound effects. |
| `"Input"` | Text / number input field with placeholder, validation, clear button, and typing sounds. |
| `"Switch"` & `"Checkbox"` | Boolean toggle switch and checkbox controls. |
| `"Slider"` | Numeric range slider. |
| `"Select"` & `"Menu"` | Dropdown selection control and contextual popup menu. |
| `"Color"` & `"ColorPicker"` | Color swatch button and full HSV/Oklab/Hex color picker popup. |
| `"Dialog"` | Confirmation or prompt dialog box. |
| `"Tooltip"` | Hover/touch tooltip attached to any UI element. |
| `"Spacer"` & `"Stroke"` | Flexible layout spacer and themed `UIStroke` border. |

### Example: Creating a Custom Window Command

Here is a shared addon that registers a `;counter` command which opens a custom reactive `Window` on the client:

```luau
return function(_K)
	local window

	if _K.IsClient then
		local UI = _K.UI
		local clicks = UI.state(0)

		window = UI.new "Window" {
			Parent = UI.LayerTopInset,
			Title = "Click Counter",
			Visible = false,
			Size = UDim2.fromOffset(280, 160),
			Position = UDim2.new(0.5, -140, 0.5, -80),

			UI.new "UIListLayout" {
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UI.Theme.Padding,
				SortOrder = Enum.SortOrder.LayoutOrder,
			},

			UI.new "ListItem" {
				Text = "Total Clicks",
				UI.new "TextLabel" {
					AutomaticSize = Enum.AutomaticSize.XY,
					BackgroundTransparency = 1,
					FontFace = UI.Theme.FontMono,
					TextColor3 = UI.Theme.PrimaryText,
					TextSize = UI.Theme.FontSizeLarge,
					Text = UI.compute(function()
						return tostring(clicks())
					end),
				},
			},

			UI.new "Button" {
				LayoutOrder = 2,
				Label = "Increment (+1)",
				Activated = function()
					clicks(clicks() + 1)
				end,
			},
		}
	end

	_K.Registry.registerCommand(_K, {
		name = "counter",
		description = "Opens the custom Click Counter window.",
		group = "Utility",
		runClient = function(_context)
			if window then
				window._instance.Visible = not window._instance.Visible
			end
		end,
	})
end
```
