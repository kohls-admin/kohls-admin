# 🛡️ Security Policy

## 🚨 Reporting a Vulnerability

Kohl's Admin takes the security of our systems and data very seriously. We appreciate the responsible disclosure of security vulnerabilities. We have different reporting mechanisms depending on the severity of the issue you discover.

**Please DO NOT disclose vulnerabilities publicly until we have had an opportunity to investigate and address them.**

### 🟡 Reporting Minor (Non-Critical) Vulnerabilities

For vulnerabilities that **do not pose an immediate or significant risk** to user data, system integrity, or availability, please report them through a **[public GitHub Issue](https://github.com/kohls-admin/kohls-admin/issues/new/choose)**. Examples of minor vulnerabilities include:

* **Cosmetic Issues/Bypass:** Issues that affect the visual appearance of the application without impacting functionality or data security. For instance, a bypass of *visual* restrictions (e.g., a way to make an element larger than intended, but without any data access implications), or a way to circumvent client-side validation *without* impacting the server-side validation.
* **Information Disclosure (Low Impact):** Exposure of non-sensitive information that does not directly lead to unauthorized access or modification of data. This *excludes* PII (Personally Identifiable Information), credentials, API keys, or internal network details.

#### Clearly describe the vulnerability, including:
* **Steps to reproduce:** Provide detailed, step-by-step instructions on how to reproduce the vulnerability. Include any necessary code snippets, errors, or warnings.
* **Impact:** Explain the potential impact of the vulnerability, even if minor.
* **Affected component(s):** Specify which part of the application is affected.
* **Suggested fix (optional):** If you have a suggestion for how to fix the vulnerability, you may include it.

### 🔴 Reporting Critical Vulnerabilities

For vulnerabilities that **pose a significant risk** to user data, system integrity, or availability, please report them through a **[GitHub Security Advisory](https://github.com/kohls-admin/kohls-admin/security/advisories/new)**. Examples of critical vulnerabilities include:

* **Authorization Bypass/Permission Elevation:** A vulnerability that allows a user to gain privileges they should not have, enabling them to access or modify data they are not authorized to. This includes vertical (gaining admin privileges) and horizontal (accessing another user's data) privilege escalation.
* **Remote Code Execution (RCE):** The ability for an attacker to execute arbitrary code on the server.
* **Sensitive Data Exposure:** Exposure of Personally Identifiable Information (PII), credentials (passwords, API keys, etc.), financial data, internal network configurations, or other confidential information.
* **Business Logic Vulnerabilities (High Impact):** Vulnerabilities that exploit flaws in the application's business logic to cause significant harm, such as financial fraud or unauthorized access to sensitive functionality.
* **Denial of Service (DoS/DDoS) (High Impact)**: A successful Denial of service attack that prevents legitimate users from accessing the application.

We will acknowledge receipt of your report as soon as possible and work with you to understand the issue and develop a fix. We will keep you informed of our progress.

## 🪲 Kohl's Bug Bounty Program

We value the contributions of the security research community and encourage responsible disclosure of vulnerabilities. This bug bounty program outlines the rules, scope, and rewards for reporting vulnerabilities to Kohl's Admin.

### 🔭 Scope

* **In Scope:**
    * Kohl's Admin
    * Kohl's Admin Infinite

* **Out of Scope:**
    * F3X
    * TopbarPlus

### 🎁 Rewards

We offer rewards based on the severity and impact of the vulnerability, determined using the CVSS scoring system.

| Severity     | CVSS Score | Reward Range      | Examples                                                                       |
|--------------|------------|-------------------|--------------------------------------------------------------------------------|
| Critical     | 9.0-10.0   | R$50,000 - R$200,000+ | Authentication Bypass, Remote Code Execution, Sensitive Data Exposure      |
| High         | 7.0-8.9    | R$10,000 - R$50,000   | Business Logic Exploit, Denial of Service, Significant Authorization Flaws |
| Medium       | 4.0-6.9    | R$2,500 - R$10,000    | Commands that abuse Higher Ranks, Some Information Disclosure              |
| Low          | 0.1-3.9    | R$50 - R$2,500        | Cosmetic Issues, Low-Impact Information Disclosure                         |

## ⚖️ Safe Harbor

We will not take legal action against individuals who report security vulnerabilities in good faith and in accordance with this policy. We consider activities conducted consistent with this policy to constitute "authorized" conduct under the Computer Fraud and Abuse Act.
