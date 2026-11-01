# Contributing to Kohl's Admin

This guide covers local development setup, vendored subtrees, documentation previews, pull request conventions, and contributor perks.

## Local Setup

1. Install [Git](https://git-scm.com/), [Rokit](https://github.com/rojo-rbx/rokit), and [Roblox Studio](https://create.roblox.com/docs/studio/setting-up-roblox-studio).
2. [Fork the repository](https://github.com/kohls-admin/kohls-admin/fork) and clone your fork:
   ```bash
   git clone https://github.com/YOUR-USERNAME/kohls-admin.git
   cd kohls-admin
   ```
3. Install project tools and the Rojo Studio plugin:
   ```bash
   git config pull.rebase true
   rokit install
   rojo plugin install
   ```
4. Start the Rojo dev server and connect from the Rojo plugin in Roblox Studio:
   ```bash
   rojo serve test
   ```

### Vendored Libraries

Flux (`vendor/flux`), Z (`vendor/z`), and Building Tools (`vendor/f3x`) live in `vendor/` as [Git subtrees](https://git-scm.com/book/en/v2/Git-Tools-Advanced-Merging#_subtree_merge) of each library's `dist` branch. A plain `git clone` builds every place without initializing submodules. Make changes in each library's own repository, then pull the updated `dist` branch:

```bash
git remote add flux https://github.com/kohltastrophe/flux.git
git subtree pull --prefix=vendor/flux flux dist --squash
```

### Development Container

Open the repository in a container using VS Code's **Reopen in Container**, Zed's **Open in Container**, or another Dev Containers client. Docker or Podman is required locally, and GitHub Codespaces runs the same configuration in the cloud.

The container includes Node.js 22, Luaudocs, and the tools pinned in `rokit.toml` (Rojo, Selene, StyLua, and Luau LSP). Run `rojo serve test` to start Rojo on forwarded port **34872**, and connect from Roblox Studio on your host machine.

To preview the documentation site on port **5173**, run:

```bash
luaudocs dev -- --host 0.0.0.0 --port 5173 --strictPort
```

Rebuild the container after changing its Dockerfile or configuration. After editing `rokit.toml`, run `rokit install --no-trust-check`.

### GitHub Codespaces

1. Click **Open in GitHub Codespaces** on the repository page (or **Code > Codespaces > Create codespace on main**).
   ![Create codespace on main](https://github.com/user-attachments/assets/229f37b8-9650-4809-b79a-37a565f6c855)
2. [Install the Rojo plugin](https://rojo.space/docs/v7/getting-started/installation/#installing-the-plugin) in Roblox Studio.
3. Start the Rojo server in the codespace terminal:
   ```bash
   rojo serve test
   ```
4. Open the **PORTS** tab, right-click **Rojo (34872)**, and set **Port Visibility** to **Public**.
   ![Screenshot of the pop-up menu for a forwarded port, with the "Port Visibility" option selected and "Private" selected in the submenu.](https://docs.github.com/assets/cb-59966/mw-1440/images/help/codespaces/make-public-option.webp)
5. Copy the forwarded port URL, strip `https://` and the trailing `/`, paste the host into the Rojo plugin in Studio with port `80`, and click **Connect**.
   ![Screenshot of the "Ports" panel. The copy icon, which copies a forwarded port's URL, is highlighted with an orange outline.](https://docs.github.com/assets/cb-19922/mw-1440/images/help/codespaces/copy-icon-port-url.webp)

## Submitting a Pull Request

1. Pick an [open issue](https://github.com/kohls-admin/kohls-admin/issues?q=is%3Aopen+is%3Aissue+no%3Aassignee) (or a [good first issue](https://github.com/kohls-admin/kohls-admin/issues?q=is%3Aopen+is%3Aissue+no%3Aassignee+label%3A%22good+first+issue%22)) and create a branch:
   ```bash
   git checkout -b feat/my-change
   ```
2. Format and lint your code with StyLua, Selene, and Luau LSP, and follow the [Roblox Lua Style Guide](https://roblox.github.io/lua-style-guide/).
3. Commit your changes with a short Conventional Commit subject line (`feat: ...`, `fix: ...`, `docs: ...`) and push your branch:
   ```bash
   git commit -m "feat: add example command"
   git push origin feat/my-change
   ```
4. Open a pull request on [GitHub](https://github.com/kohls-admin/kohls-admin) explaining why the change exists and what behavior changed.

## Editing Documentation

1. Install [Node.js v22+](https://nodejs.org/en/) and start the local preview server:
   ```bash
   npx luaudocs dev
   ```
2. Edit the Markdown pages under `.luaudocs/` and preview your changes live in the browser before opening a pull request.

## Reporting Bugs and Feature Requests

Search open and closed issues before filing a new one, as duplicate issues are closed right away. If a closed bug regresses, open a new issue linking the original report.

- [New Bug Report](https://github.com/kohls-admin/kohls-admin/issues/new?assignees=&labels=bug&projects=&template=bug.yml)
- [New Feature Request](https://github.com/kohls-admin/kohls-admin/issues/new?assignees=&labels=enhancement&projects=&template=feature.yml)

## Compensation

Sustained or high-impact engineering contributions are eligible for monetary compensation. Reach out on [Discord](https://discord.gg/kohl) if you want to discuss a bounty or ongoing work.

All contributors also receive:

- **In-Game Credits:** Listed in the `credits` command and `About` tab across participating games.
- **Early Access:** Access to contributor channels and upcoming release previews.
- **In-Game Perks:** Cosmetic perks and VIP commands inside participating games running Kohl's Admin.
