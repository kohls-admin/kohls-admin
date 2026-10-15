---
sidebar_position: 1
---

# Introduction

## What Is Kohl's Admin?

**Kohl's Admin (KA)** is a fast, modern, and extensible administration framework for Roblox experiences. Whether you are moderating players across live servers, testing gameplay mechanics in Studio, selling VIP perks and roles, or building custom administrative tools for your team, Kohl's Admin provides a complete, zero-lag solution out of the box.

## Key Features

- **Role-Based Access Control (RBAC)**: Configure an unlimited hierarchy of custom roles with granular command groups, permission flags, cooldowns, and target limits. Automatically grant roles by UserId, Username, Group Rank, GamePass, Asset, Subscription, Friend status, or Private Server ownership.
- **Smart Command Bar & Chat Execution**: Run commands with real-time autocomplete, inline argument validation, error highlighting, command history, multi-command batching, and native Roblox `/` slash commands (`TextChatCommand`).
- **Powerful Target Selectors**: Target players effortlessly using shorthand selectors like `me`, `all` (`*`), `others`, `@role`, `%team`, `~random`, `$friends`, `$admins`, `$distance<100`, and `$group=ID>=RANK`.
- **Live Dashboard & Server Management**: Manage Commands, Bans, Members, Active & Reserved Servers, Cross-Server Synced Logs, and Settings through a responsive, reactive interface on PC, Mobile, Console, and VR.
- **Built-in Monetization & Discovery**: Sell custom GamePass/Asset/Subscription roles, earn **40% creator commission** on global VIP and UGC purchases in your experience, and gain free player discovery through **Kohl's Admin Charts**.
- **Limitless Customization**: Extend Kohl's Admin with shared, server-only, or client-only **Addons**, register **Custom Commands** and **Custom Argument Types**, listen to lifecycle **Hooks** (`_K.Hook`), and customize **UI Themes** or build custom windows with [`_K.UI`](/api/UI) and [`_K.Flux`](/api/Flux).

## Documentation Overview

### Getting Started

- **[Installation](/guide/getting-started/installation)**: Install Kohl's Admin via the Creator Store model, GitHub `.rbxm` releases, or Wally & Rojo, and configure recommended Studio security settings.
- **[Configuration](/guide/getting-started/configuration)**: Set up roles, permissions, automatic role assignments (Groups, GamePasses, Assets, Subscriptions), system settings, and pre-configured bans in `Config > Settings`.
- **[Using Commands](/guide/getting-started/using_commands)**: Learn how to run commands from the Command Bar or Chat, batch multiple commands, and use advanced player target selectors.
- **[Using UIs](/guide/getting-started/using_uis)**: Explore the 8 Dashboard tabs (Commands, Bans, Members, Servers, Logs, Settings, About, Market), topbar shortcuts, status bar metrics, and built-in tools like `;explorer` and `;btools`.
- **[Legacy Loader & Migration](/guide/getting-started/legacy_loader)**: Migrate automatically from Kohl's Admin Infinite (`Config > Legacy`) or switch between the New and Legacy loaders.

### Developer & Customization Guides

- **[Custom Commands](/guide/custom_commands)**: Register custom commands, configure argument definitions, use built-in argument types, manage command environments (`env` / `envClient`), and handle execution contexts.
- **[Addons & Hooks](/guide/addons)**: Organize shared, server-only, and client-only addons, tag external addons with `CollectionService`, connect to `_K.Hook` events, and call core `_K` APIs (`_K.Auth`, `_K.Process`, `_K.Notify`, `_K.log`).
- **[Custom Argument Types](/guide/custom_types)**: Create enum types, sequence types, and full custom argument parsers with validation and autocomplete suggestions.
- **[Themes & Custom UI](/guide/themes_and_ui)**: Customize UI themes in `Config > Themes` and build reactive windows and components using `_K.UI` and `_K.Flux`.
- **[API Reference](/api/)**: Full technical reference for [`MainModule` (`_K`)](/api/MainModule), [`Registry`](/api/Registry), [`Auth`](/api/Auth), [`Process`](/api/Process), [`Hook`](/api/Hook), [`UI`](/api/UI), [`Theme`](/api/Theme), [`Flux`](/api/Flux), [`Z`](/api/Z), and [`Util`](/api/Util).

### Help & Community

- **[Troubleshooting](/guide/troubleshooting)**: Fix common issues such as Studio `Sandboxed` capability errors, DataStore saving in Studio, HTTP Requests for Charts, and custom command registration.
- **[Support](/guide/support)**: Join the community Discord server, browse FAQ resources, and report bugs or feature requests.
