# Contributing (Codebase)

To get started with contributing to Kohl's Admin, follow these steps:

## Prerequisites

- [Aftman](https://github.com/LPGhatguy/aftman)
- [Roblox Studio](https://create.roblox.com/docs/studio/setting-up-roblox-studio)

The following assumes you have aftman installed, if not navigate to the [Installation](https://github.com/LPGhatguy/aftman#installation) for Aftman.

1. **Fork the repository:** Create a [fork](https://github.com/kohls-admin/main/fork) of the repository.
2. **Clone the repository:** Clone your fork locally:

```bash
git clone https://github.com/your-username/main.git --recurse-submodules
```

3. **Checkout the testing branch:** The development work is done on the testing branch, which is the most current and unstable version of the codebase. When contributing, make sure to switch to this branch to stay up-to-date:

```bash
git checkout testing
```

4. **Install Aftman tools:**

```bash
aftman install
```

5. **Install Roblox Studio [Rojo](https://rojo.space/) plugin:**

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

# Contributing (Docs)

This project utilizes [Moonwave](https://eryn.io/moonwave/) for managing our documentation.

To contribute to the Kohl's Admin documentation, follow steps 1-3 outlined in the [Contributing (Codebase)](#contributing-codebase) section before moving forward.

## Prerequisites

- [Node.js](https://nodejs.org/en/) v14+
- [Moonwave](https://eryn.io/moonwave/)

The following assumes you have Moonwave installed, if not navigate to the [Getting Started](https://eryn.io/moonwave/docs/intro) for Moonwave.

1. Open your terminal and navigate to the your local project directory.
2. Run the development server:

```bash
moonwave dev
```

3. Navigate to the `docs/` folder to start contributing directly to the documentation.

Congratulations! You are ready to start contributing to the documentation portion of the project!

# Compensation

While we deeply appreciate all contributions, we also recognize that significant, sustained efforts may warrant monetary compensation. Due to our current limited funding, we can only offer compensation on a discretionary basis.

#### Eligibility:

- **Exceptional Impact:** Contributions that significantly advance the project's core goals, introduce major features, or resolve critical issues may be eligible.
- **Sustained Dedication:** Consistent, high-quality contributions over a prolonged period demonstrate commitment and will be more favorably considered.
- **Critical Needs:** Contributions that directly address urgent or strategic project needs may also be prioritized.

#### Compensation Structure:

- **Discretionary:** The decision to offer compensation, and the specific amount, will be at the sole discretion of the project maintainers, taking into account the factors mentioned above and the project's available resources.
- **Transparent Communication:** We will maintain open communication with potential candidates, discussing expectations and possibilities as contributions progress.

#### How to Express Interest:

If you believe your contributions meet the above criteria and are interested in potential compensation, please reach out to the project maintainers via [Discord](https://discord.gg/kohl). We'll be happy to discuss your contributions and explore possibilities within our current capabilities.

**Note:** Even if monetary compensation is not feasible at this time, we deeply value all contributions and will recognize them through in-game credits, special benefits, and public acknowledgment.
