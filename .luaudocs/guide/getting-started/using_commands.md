---
sidebar_position: 3
---

# Using Commands

Kohl's Admin supports running commands through the **Command Bar** (on PC, Mobile, Console, and VR) as well as through **Roblox Chat** (including native `/` slash commands).

## Using the Command Bar

The Command Bar features real-time autocomplete, argument type validation, inline error feedback, and command history.

### Opening the Command Bar

- **Keyboard (PC)**: Press `;` (semicolon) on your keyboard. You can customize this keybind at any time in **Dashboard > Settings**.
- **Topbar Shortcut (PC & Mobile)**:
  - **PC**: Right-click either the **Kohl's Admin Dashboard** button or the **Commands** button in the top-left Roblox topbar.
  - **Mobile / Touch**: Long-press (press and hold) either the **Kohl's Admin Dashboard** button or the **Commands** button in the topbar.
- **From the Dashboard**: Click or tap the **Terminal (`>_`)** icon in the top-right corner of the Dashboard title bar (next to the close `X` button).

### Autocomplete, Validation & History

1. Start typing a command name or alias (the prefix is automatically inserted for you).
2. **Cycle Suggestions**: Press the `Up` / `Down` arrow keys or scroll the mouse wheel over the suggestion list.
3. **Accept a Suggestion**: Press `Tab` (or click/tap a suggestion) to autocomplete the highlighted command or argument.
4. **Validation Indicator**: The circle on the right side of the Command Bar displays a **green checkmark** when all arguments are valid, or a **red `X`** with an inline error explanation if an argument is missing or invalid.
5. **Command History**: When the Command Bar only contains your prefix (`;`), it displays your recently executed commands so you can quickly re-run them.
6. Press `Enter` (or click/tap the green checkmark) to execute the command.

---

## Using Roblox Chat

When `chatCommands = true` in `Settings`, you can run commands directly from the Roblox chat box:

1. Press `/` (or tap the chat icon) to focus the chat input bar.
2. Type your command starting with a valid prefix (`;` or `:` by default, or your personal prefix configured in Settings), followed by any arguments:
   ```text
   ;fly me
   ```
3. **Silent Commands**: Prefix your message with `/e ` to run a command without displaying your chat message publicly to other players:
   ```text
   /e ;invisible me
   ```
4. **Native `/` Slash Commands**: Kohl's Admin automatically registers `TextChatCommand` slash aliases for Utility commands (such as `/cmds`, `/info`, `/help`, `/version`) and VIP commands (such as `/headless`, `/korblox`, `/cape`, `/fire`, `/light`, `/particle`, `/trail`, `/shine`, `/vampire`, `/werewolf`).

---

## Command Syntax & Power Tricks

### Self-Targeting Shorthand

For commands whose first argument is a player, you can omit `me` when targeting yourself:

```text
;fly          -- Equivalent to ;fly me
;size 2       -- Automatically fills "me" for the player argument: ;size me 2
```

### Batching Multiple Commands

Run multiple commands in a single message by separating each command with a space and a prefix:

```text
;size me 2 ;sparkles me ;fly me 50
```

### Multi-Target Lists (Comma-Separated)

For arguments that accept multiple values (such as `players`, `roles`, or `tools`), separate targets with commas (no spaces around the comma):

```text
;bring Builderman,Roblox,Shedletsky
;give me Sword,Slingshot
```

### Quoting Arguments with Spaces

Wrap arguments that contain spaces—or match players whose DisplayName contains spaces—inside double quotes (`"..."`) or backticks (`` `...` ``):

```text
;team me "Red Team"
;pm "Cool Player" Hello there!
```

---

## Player Target Selectors

Whenever a command expects a `player`, `players`, `userId`, or `userIds` argument, you can use special target selectors instead of typing individual usernames:

### Basic Selectors

| Selector | Target | Example |
| :--- | :--- | :--- |
| `me` *(or omitted)* | Yourself (the command caller) | `;respawn me` |
| `all` or `*` | Every player in the server | `;sparkles *` |
| `others` | Every player in the server except yourself | `;bring others` |
| `~` or `~N` | `1` random player (`~`) or `N` random players (`~N`) | `;give ~3 Sword` |

### Role & Team Selectors (`@` and `%`)

| Selector | Target | Example |
| :--- | :--- | :--- |
| `@<role>` | All players in the server who have `<role>` (supports partial matching) | `;teleport @vip me` |
| `%<team>` | All players on `<team>` (supports partial matching) | `;heal %Red` |

### Special Conditional Selectors (`$`)

Prefix a conditional selector with `$` to filter players dynamically:

| Selector | Target | Example |
| :--- | :--- | :--- |
| `$all` | Every player in the server | `;refresh $all` |
| `$others` | Every player except yourself | `;freeze $others` |
| `$admins` | Players with any assigned member role | `;pm $admins Meeting at spawn!` |
| `$nonadmins` | Players without any assigned member role | `;teleport $nonadmins me` |
| `$friends` | Players in the server who are friends with you | `;bring $friends` |
| `$close` | Players within `100` studs of your character | `;heal $close` |
| `$far` | Players more than `100` studs away from your character | `;bring $far` |
| `$distance<N` | Players within `N` studs of your character | `;explode $distance<50` |
| `$distance>N` | Players more than `N` studs away from your character | `;bring $distance>250` |
| `$group=ID` | Players who are members of Roblox Group `ID` | `;give $group=3403354 Sword` |
| `$group=ID<op>RANK` | Players in Group `ID` matching rank comparison (`=`, `>`, `>=`, `<`, `<=`) | `;role $group=3403354>=200 mod` |

:::tip Combining Selectors
Because comma-separated lists work with any player selector, you can combine multiple selectors in one command:
```text
;heal me,$friends,%Blue
```
:::

---

## Command Requests

To prevent abuse between admins of equal authority, commands marked with `shouldRequest = true` (such as teleporting or modifying another player) cannot be forced onto someone of the **same or higher rank**.

When `commandRequests = true` in `Settings` and you target a player with an equal or higher rank:
1. Kohl's Admin sends a **Command Request** dialog to the target player showing the exact command you want to run on them.
2. You receive a notification that the request was sent.
3. If the target player clicks **Accept**, the command executes immediately; if they click **Deny**, you are notified that the request was declined.
