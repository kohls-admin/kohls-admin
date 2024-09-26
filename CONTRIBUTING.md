# Contributing

We immensely appreciate all contributions and suggestions from the community!

**How would you like to contribute?**

- [Codebase](#contributing-codebase)
- [Documentation](#contributing-docs)
- [Issues & Suggestions](#contributing-issues)
- [Questions? (Discord)](https://discord.gg/kohl)

# Contributing (Issues)

Check existing open and **closed** issues to make sure someone else hasn't created one! **We close duplicate issues immediately!**

_If an issue was closed after a fix, but the bug has returned or functionality was lost, please create a new issue!_

- [**Create** Bug Report](https://github.com/kohls-admin/kohls-admin/issues/new?assignees=&labels=bug&projects=&template=bug.yml)
- [**Create** Feature Request](https://github.com/kohls-admin/kohls-admin/issues/new?assignees=&labels=enhancement&projects=&template=feature.yml)

_Please be patient while we address your issue!_

We will close the issue when it is verified to work and merged to the [master](https://github.com/kohls-admin/kohls-admin/tree/master) branch of Kohl's Admin.

# Contributing (Codebase)

To get started with contributing to Kohl's Admin, follow these steps:

## Prerequisites

- [Git](https://git-scm.com/)
- [Aftman](https://github.com/LPGhatguy/aftman)
- [Roblox Studio](https://create.roblox.com/docs/studio/setting-up-roblox-studio)

The following assumes you have aftman installed, if not navigate to the [Installation](https://github.com/LPGhatguy/aftman#installation) for Aftman.

1. **Fork the repository:** Create a [fork](https://github.com/kohls-admin/kohls-admin/fork) of the repository.
2. **Clone the repository:** Clone your fork locally and change the git config:

```bash
git clone https://github.com/YOUR-USERNAME/main.git --recurse-submodules;
git config submodule.recurse true;
git config pull.rebase true;
```

3. **Install Aftman tools:**

```bash
aftman install
```

4. **Install Roblox Studio [Rojo](https://rojo.space/) plugin:**

```bash
rojo plugin install
```

## Studio Testing

1. **Start the Rojo test server:**

```bash
rojo serve test.project.json
```

2. **Connect to Rojo server:** in Roblox Studio using the [Rojo plugin](https://rojo.space/docs/v7/getting-started/installation/#installing-the-plugin).

Congratulations! You are ready to start contributing to the codebase portion of the project!

We use the [GitLab Flow](https://about.gitlab.com/topics/version-control/what-is-gitlab-flow/) style of git development.

We use the [Roblox Lua Style Guide](https://roblox.github.io/lua-style-guide/) to avoid style arguments.

Here's a [list of issues](https://github.com/kohls-admin/kohls-admin/issues?q=is%3Aopen+is%3Aissue+no%3Aassignee+label%3A%22good+first+issue%22) to get started with!

### Bug fixes

Please create a corresponding [bug report](https://github.com/kohls-admin/kohls-admin/issues/new?assignees=&labels=bug&projects=&template=bug.yml) if one doesn't already exist. This ensures we have all the necessary information to track and understand the issue.

### New Features

Please create a [feature request](https://github.com/kohls-admin/kohls-admin/issues/new?assignees=&labels=enhancement&projects=&template=feature.yml) before implementing any new features. Pull requests are primarily intended for code review, not for introducing brand-new concepts.

### Draft Pull Request Early

Create a pull request as soon as possible. Mark it as a "draft" to signal that it's a work in progress. This enables us to provide real-time feedback and guidance, streamlining the review process.

# Contributing (Docs)

This project utilizes [Moonwave](https://eryn.io/moonwave/) for managing our documentation.

To contribute to the Kohl's Admin documentation, follow steps 1-2 outlined in the [Contributing (Codebase)](#contributing-codebase) section before moving forward.

## Prerequisites

- [Node.js](https://nodejs.org/en/) v14+
- [Moonwave](https://eryn.io/moonwave/)

The following assumes you have Moonwave installed, if not navigate to the [Getting Started](https://eryn.io/moonwave/docs/intro) for Moonwave.

1. Open your terminal and navigate to the your local project directory.
2. Run the development server:

```bash
moonwave dev --code MainModule/
```

3. Navigate to the `docs/` folder to create and edit markdown pages.

Congratulations! You are ready to start contributing to the documentation portion of the project!

# Compensation

While we deeply appreciate all contributions, we also recognize that significant, sustained efforts may warrant monetary compensation. Due to our current limited funding, we can only offer compensation on a discretionary basis.

#### Eligibility:

- **Exceptional Impact:** Contributions that significantly advance the project's core goals, introduce major features, or resolve critical issues may be eligible.
- **Sustained Dedication:** Consistent, high-quality contributions over a prolonged period demonstrate commitment and will be more favorably considered.

#### How to Express Interest:

If you believe your contributions meet the above criteria and are interested in potential compensation, please reach out to the project maintainers via [Discord](https://discord.gg/kohl). We'll be happy to discuss your contributions and explore possibilities within our current capabilities.

**Note:** Even if monetary compensation is not feasible at this time, we deeply value all contributions and will recognize them through in-game credits, special benefits, and public acknowledgment.
