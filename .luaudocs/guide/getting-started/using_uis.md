---
sidebar_position: 4
---

# Using UIs

Kohl's Admin includes a modern, reactive user interface built with [`Flux`](/api/Flux) that adapts automatically to PC, Mobile, Tablet, Console, and VR screens.

:::info Using the Legacy Loader?
Looking for the classic *Kohl's Admin Infinite* windows (`;help`, `;admins`, `;bans`, `;tools`)? See the [Legacy Loader & Migration](/guide/getting-started/legacy_loader#legacy-loaders-uis) guide.
:::

## Topbar Buttons & Shortcuts

Depending on your role rank and the experience's `Settings` (`dashboardButtonRank` and `commandsButtonRank`), up to two buttons appear in the top-left Roblox topbar (compatible with **TopbarPlus** if present in `ReplicatedStorage`):

1. **Dashboard Button (Kohl's Admin Crown Icon)**:
   - **Left-Click / Tap**: Opens or closes the main **Dashboard** window.
   - **Right-Click (PC) / Long-Press (Mobile)**: Toggles the **Command Bar**.
   - **Keyboard Shortcut**: Press `'` (`Quote` key) on PC to toggle the Dashboard (customizable in **Settings**).
2. **Commands Button (Terminal `>_` Icon)**:
   - **Left-Click / Tap**: Opens or closes a standalone **Commands** window.
   - **Right-Click (PC) / Long-Press (Mobile)**: Toggles the **Command Bar**.

---

## The Dashboard

The Dashboard is the central control panel for Kohl's Admin. You can resize, drag, or maximize the window, and its navigation bar automatically switches between vertical and horizontal layouts based on window dimensions.

### 1. Commands

- Browse every registered command in the experience, grouped and badged by authority role and command group.
- Displays each command's primary name, aliases, argument signatures (`<required>` and `<optional?>`), and description.
- Use the search bar in the title bar to filter commands by name, alias, group, or description.
- Hover over (or press and hold on mobile) any command to inspect detailed argument tooltips.

### 2. Bans

- View all active server bans, temporary bans, and permanent cross-server bans (`DataStore`).
- Displays each banned user's avatar, display name, username, `UserId`, ban reason, banner, and remaining duration.
- **Ban Users via UI**: Click the **Add (`+`)** button to ban a user by Username or `UserId` with a custom duration and reason.
- **Unban Users via UI**: Click the **`X`** button on a ban entry and confirm the prompt (`✔`) to unban them immediately.

### 3. Members

- View all online and offline (saved) users who hold roles in your experience.
- Displays each member's avatar, username, `UserId`, and assigned role badges.
- Add or remove roles directly from the UI (subject to your rank and `saveRoles` permission) or filter members using the search bar.

### 4. Servers

- **Active Servers**: View live servers running across your experience, including player counts, server ping/FPS metrics, and server age, with one-click teleportation.
- **Reserved Servers**: Create, view, copy join codes for, teleport players into, or delete reserved private server codes (`;reserve` / `;place` / `;unreserve`).

### 5. Logs

- View real-time and cross-server synced logs with millisecond precision.
- **Log Categories**:
  - **Admin & Chat**: `COMMAND`, `CHAT`
  - **Player Activity**: `JOIN`, `LEAVE`, `KILL`, `DEATH`, `DAMAGE`, `PURCHASE`
  - **System & Developer**: `DEBUG`, `INFO`, `WARN`, `ERROR`
- **Filtering & Search**: Click the **Filter** button to toggle specific log categories on or off, or use the search bar to filter by player name, command, or message content.
- **Cross-Server Persistence**: When `saveLogs = true` in `Settings` (enabled by default), command logs from restricted roles are automatically saved and synced across all servers via DataStores.

### 6. Settings

- **Local Client Settings**: Every player can customize their personal command prefix (`playerPrefix`), Dashboard/Command Bar hotkeys, UI sounds, and typing sounds. When `changeThemeAuthority = "Client"`, players can also pick their preferred UI theme and colors locally.
- **Global Server Settings**: Admins with the `settings = true` permission (such as `SuperAdmin` and `Game Creator`) can modify game-wide settings—such as prefixes, rank thresholds, `freeAdmin`, and server-wide themes—which automatically save to DataStores and sync to all servers.

### 7. About

- Displays the current Kohl's Admin version, credits and contributors, Kohl's Admin Charts status, and quick links to get the model or join the community.

### 8. Market

- Browse and purchase global **VIP** perks (unlocking dozens of cosmetic commands and `/headless`, `/korblox`, `/cape`, `/fire`, etc. across participating experiences), experience-specific GamePass roles, and supporter UGC items.

### Dashboard Status Bar

Along the bottom edge of the Dashboard window, the live Status Bar displays:
- **Ping**: Average and maximum network ping in milliseconds (`ms`), color-coded from green to red.
- **FPS**: Average frames per second, `1% Low` FPS, and maximum FPS.
- **Uptime**: Current server uptime (and client session time on hover).
- **Version**: The running Kohl's Admin version string.

---

## Built-in Admin Tool Windows

Beyond the main Dashboard, Kohl's Admin includes specialized tool interfaces accessible via commands:

- **Instance Explorer (`;explorer`)**: A full in-game Studio-style Explorer and Properties inspector (`src/Client/Explorer`) for browsing and editing the DataModel hierarchy in real time.
- **Building Tools (`;btools`)**: Equips the full **Building Tools by F3X** suite for in-game part creation, transformation, material/color editing, and exporting.
- **Environment & Tools Windows (`;tools`, `;emotes`, `;env`)**: Dedicated interactive windows for spawning tools, previewing/playing avatar emotes, and adjusting lighting/atmosphere properties.
