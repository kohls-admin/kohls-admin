# Contributing to Kohl's Admin: Let's Build Together!

We're thrilled you're interested in contributing to Kohl's Admin! Your time and effort are greatly appreciated.

Whether you're a seasoned developer or just starting out, there are ways for you to get involved.

## How You Can Contribute

- [Improve the Code](#improve-the-code)
- [Enhance the Documentation](#enhance-the-documentation)
- [Report Bugs & Suggest Features](#report-bugs--suggest-features)
- [Ask Questions & Join the Community](https://discord.gg/kohl)

## Improve the Code

### Setup

#### Local Development

1. Setup Your Environment

   - Install the Essentials

     - [Git](https://git-scm.com/)
     - [Rokit](https://github.com/rojo-rbx/rokit)
     - [Roblox Studio](https://create.roblox.com/docs/studio/setting-up-roblox-studio)

2. Fork and Clone the Repository

   - **[Create a fork](https://github.com/kohls-admin/kohls-admin/fork)** of the repository.
   - **Clone your fork**, and run the initial setup commands:
     ```bash
     git clone --recurse-submodules https://github.com/YOUR-USERNAME/kohls-admin.git
     ```

3. Setup Your Local Repository

   - **Navigate to the Project Directory:**
     ```bash
     cd kohls-admin
     ```
   - **Setup Git:**
     ```bash
     git config submodule.recurse true;
     git config pull.rebase true;
     ```
   - **Install Project Dependencies:**
     ```bash
     rokit install;
     rojo plugin install;
     ```

4. Test Your Changes in Roblox Studio

   - **Start the Rojo Server:**
     ```bash
     rojo serve test.project.json
     ```
   - **Connect Studio to Rojo:** Open Roblox and use the [Rojo plugin](https://rojo.space/docs/v7/getting-started/installation/#installing-the-plugin) to connect to the server you just started.


#### GitHub Codespaces

1. Open this project in GitHub Codespaces

   - Click the "Open in GitHub Codespaces" badge or the Code button, then click the Codespaces tab, and "Create codespace on main."
   ![Create codespace on main](https://github.com/user-attachments/assets/229f37b8-9650-4809-b79a-37a565f6c855)

3. Setup the Rojo plugin

   - [Install the Rojo plugin](https://rojo.space/docs/v7/getting-started/installation/#installing-the-plugin) on Roblox Studio from [GitHub](https://github.com/rojo-rbx/rojo/releases) or [Roblox.com](https://www.roblox.com/library/13916111004/Rojo).


4. Test Your Changes in Roblox Studio

   - **Start the Rojo Server:**
     ```bash
     rojo serve test.project.json
     ```
   - **Change the port visibility to Public:** Open the terminal in your codespace. Click the **PORTS** tab. Right-click the port **Rojo (34872)**, click the **Port Visibility**, then click **Public**.
      ![Screenshot of the pop-up menu for a forwarded port, with the "Port Visibility" option selected and "Private" selected in the submenu.](https://docs.github.com/assets/cb-59966/mw-1440/images/help/codespaces/make-public-option.webp)
   - **Copy the forwarded port address:** To the right of the local address for the port, click the copy icon.
      ![Screenshot of the "Ports" panel. The copy icon, which copies a forwarded port's URL, is highlighted with an orange outline.](https://docs.github.com/assets/cb-19922/mw-1440/images/help/codespaces/copy-icon-port-url.webp)
   - **Connect Studio to Rojo:** Open Roblox and in the [Rojo plugin](https://rojo.space/docs/v7/getting-started/installation/#installing-the-plugin), paste the port address you copied. Remove the `https://` at the beginning and the `/` of the forwarded address. It should look something like this: `probable-memory-w44vgv9v4vpfjwj-34872.app.github.dev`, and set the port as `80`. Finally, connect to the server you just started.

### Contributing

1. Make Your Changes

   - **Choose an Issue:** Browse our [list of issues](https://github.com/kohls-admin/kohls-admin/issues?q=is%3Aopen+is%3Aissue+no%3Aassignee) and find one that interests you, or create your own. If you're new look at our [good first issues](https://github.com/kohls-admin/kohls-admin/issues?q=is%3Aopen+is%3Aissue+no%3Aassignee+label%3A%22good+first+issue%22).
   - **Create a New Branch:** Before making any changes, create a new branch for your work. This keeps your changes separate from the main codebase.
     ```bash
     git checkout -b my-new-feature
     ```
   - **Make Your Changes:** Use your favorite code editor to modify the project files. Follow the [Roblox Lua Style Guide](https://roblox.github.io/lua-style-guide/) to maintain consistency.

2. Save Your Changes

   - **Commit Your Changes:** Once you're happy with your changes, commit them with a clear and descriptive message.
     ```bash
     git add .
     git commit -m "Add feature XYZ"
     ```
   - **Push Your Changes:** Push your branch to your forked repository on GitHub.
     ```bash
     git push origin my-new-feature
     ```

3. Create a Pull Request

   - **Open a Pull Request:** Go to [Kohl's Admin on GitHub](https://github.com/kohls-admin/kohls-admin) and click the `Compare & pull request` button.
   - **Provide Details:** Write a clear description of your changes, referencing any relevant issues.
   - **Submit Your Changes:** Click the `Create pull request` button.

4. Review and Collaboration

   - **Address Feedback:** Our team will review your pull request and provide feedback, be prepared to make additional changes or clarifications.
   - **Collaborate:** Work with us to refine your code and ensure it meets our standards.

5. Merge and Celebrate! 🎉
   - **Merge:** Once your pull request is approved, it will be merged into the [master](https://github.com/kohls-admin/kohls-admin/tree/master) branch.
   - **Celebrate:** You've made a valuable contribution to Kohl's Admin! Thank you!

## Enhance the Documentation

1. Setup Your Environment

   - Follow steps 1-2 outlined in the [Improve the Code](#improve-the-code) section above.
   - [Install Node.js v14+](https://nodejs.org/en/)
   - [Install Moonwave](https://eryn.io/moonwave/docs/intro)

2. Run the Development Server

   - **Navigate to the Project Directory:**
     ```bash
     cd kohls-admin
     ```
   - **Start the Server:**
     ```bash
     moonwave dev
     ```

3. Edit Documentation
   - **Navigate to the `docs/` folder:** This is where you'll find the markdown files for our documentation.
   - **Create or Edit Pages:** Use your favorite text editor to create new pages or modify existing ones.
   - **Preview Your Changes:** The development server will automatically update as you make changes.
   - **Submit Your Changes:** Follow steps 5-9 outlined in the [Improve the Code](#improve-the-code) section above.

## Report Bugs & Suggest Features

Check existing open and **closed** issues to make sure someone else hasn't created one! **We close duplicate issues immediately!**

_If an issue was closed after a fix, but the bug has returned or functionality was lost, please create a new issue!_

- [New Bug Report](https://github.com/kohls-admin/kohls-admin/issues/new?assignees=&labels=bug&projects=&template=bug.yml)
- [New Feature Request](https://github.com/kohls-admin/kohls-admin/issues/new?assignees=&labels=enhancement&projects=&template=feature.yml)

_Please be patient while we address your issue!_

The issue will close when a related [pull request](https://github.com/kohls-admin/kohls-admin/pulls) is merged to the [master](https://github.com/kohls-admin/kohls-admin/tree/master) branch of Kohl's Admin.

## Compensation

We deeply appreciate all contributions, big and small. While most contributions are voluntary, we recognize that exceptional, sustained efforts may warrant monetary compensation.

- **Eligibility:** We consider compensation for contributions that have a significant impact on the project or demonstrate a long-term commitment.
- **Expressing Interest:** If you believe your contributions meet these criteria, please reach out to us on [Discord](https://discord.gg/kohl).

Even if monetary compensation isn't possible, we value your contributions and will recognize them through:

- **In-game Credits:** Earn recognition within Kohl's Admin
- **Insider Access:** Access to exclusive features or early previews
- **Special Benefits:** Cosmetic benefits and free VIP commands within Kohl's Admin
- **Public Acknowledgement:** We'll highlight your contributions in our community channels and project documentation

## Let's Get Started!

We're excited to have you join our community! If you have any questions or need help getting started, don't hesitate to reach out on [Discord](https://discord.gg/kohl). Happy contributing!
