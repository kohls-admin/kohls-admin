---
sidebar_position: 1
---

# Introduction

## What Is Kohl's Admin?

**Kohl's Admin (KA)** is an administration, moderation, and command suite for Roblox built on [`Flux`](/api/Flux) and [`Z`](/api/Z). It includes 200+ built-in commands, role-based access control, cross-server `DataStore` sync, an in-game dashboard, and an addon API for custom commands, types, and UI windows.

## Key Features

- **Role-Based Access Control:** Grant combinable roles by UserId, Group rank, GamePass, Asset, or Subscription, and sync bans, members, settings, and logs across servers via `DataStore`.
- **Command Bar and Chat:** Run commands from the command bar or `TextChatService` slash aliases with live autocomplete, inline validation, and command history.
- **Target Selectors:** Target players with shorthand selectors like `me`, `all` (`*`), `others`, `@role`, `%team`, `~random`, `$friends`, `$distance<100`, and `$group=ID>=RANK`.
- **In-Game Dashboard:** Manage commands, bans, members, active servers, logs, and themes from a single window across PC, mobile, console, and VR.
- **Monetization and Discovery:** Sell custom GamePass roles, earn up to **40% creator commission** on global VIP and UGC purchases, and list your game on **Kohl's Admin Charts**.
- **Addons and Hooks:** Register custom commands, argument parsers, lifecycle hooks (`_K.Hook`), and reactive windows (`_K.UI`) from shared, server, or client addon scripts.

## Documentation Overview

### Getting Started

- **[Installation](/guide/getting-started/installation):** Install Kohl's Admin via the Creator Store model, GitHub `.rbxm` releases, or Wally and Rojo.
- **[Configuration](/guide/getting-started/configuration):** Configure roles, permissions, marketplace grants, system settings, and hardcoded bans in `Config > Settings`.
- **[Using Commands](/guide/getting-started/using_commands):** Run commands from the command bar or chat, chain multiple commands, and filter targets with selectors.
- **[Using UIs](/guide/getting-started/using_uis):** Navigate the 8 dashboard tabs, topbar shortcuts, status bar metrics, and built-in tools like `;explorer` and `;btools`.
- **[Legacy Loader & Migration](/guide/getting-started/legacy_loader):** Migrate existing settings and saved data from Kohl's Admin Infinite (`Config > Legacy`).

### Developer & Customization Guides

- **[Custom Commands](/guide/custom_commands):** Register custom commands, define arguments, manage command environments (`env` / `envClient`), and handle undo aliases.
- **[Addons & Hooks](/guide/addons):** Organize shared, server, and client addons, connect to `_K.Hook` signals, and call `_K.Auth`, `_K.Process`, and `_K.Notify`.
- **[Custom Argument Types](/guide/custom_types):** Build enum types, sequence types, and custom argument parsers with validation and autocomplete suggestions.
- **[Themes & Custom UI](/guide/themes_and_ui):** Customize themes in `Config > Themes` and build reactive windows with `_K.UI` and `_K.Flux`.
- **[API Reference](/api/):** Generated reference for [`MainModule` (`_K`)](/api/MainModule), [`Registry`](/api/Registry), [`Auth`](/api/Auth), [`Process`](/api/Process), [`Hook`](/api/Hook), [`UI`](/api/UI), [`Theme`](/api/Theme), [`Flux`](/api/Flux), [`Z`](/api/Z), and [`Util`](/api/Util).

### Help & Community

- **[Troubleshooting](/guide/troubleshooting):** Fix Studio `Sandboxed` capability errors, DataStore saving in Studio, HTTP requests for Charts, and custom command registration.
- **[Support](/guide/support):** Join the community Discord server, browse the FAQ, and report bugs or feature requests.
