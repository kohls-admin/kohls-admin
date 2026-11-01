# Security Policy

## Reporting a Vulnerability

Do not disclose security vulnerabilities publicly until we have investigated and released a fix.

### Minor (Non-Critical) Vulnerabilities

Report low-impact issues that do not put user data, server authority, or service availability at risk through a [public GitHub Issue](https://github.com/kohls-admin/kohls-admin/issues/new/choose):

- **Cosmetic or Client-Only Bypasses:** Visual glitches or client-side validation bypasses that do not affect server-side validation or permissions.
- **Low-Impact Information Disclosure:** Exposure of non-sensitive state that does not grant unauthorized access or leak personal data, credentials, or internal configuration.

Include step-by-step reproduction instructions, the affected modules, the impact, and an optional fix if you have one.

### Critical Vulnerabilities

Report vulnerabilities that affect server authority, user data, or availability privately through a [GitHub Security Advisory](https://github.com/kohls-admin/kohls-admin/security/advisories/new):

- **Authorization Bypass or Privilege Escalation:** Gaining unauthorized roles, bypassing rank checks, or modifying another user's data.
- **Remote Code Execution (RCE):** Executing arbitrary code on the server.
- **Sensitive Data Exposure:** Leaking personal data, credentials, API keys, or financial records.
- **High-Impact Logic Exploits or Denial of Service:** Abusing command or marketplace flows to corrupt saved data or crash servers.

We will acknowledge your report promptly and keep you updated while we ship a fix.

## Bug Bounty Program

We reward security researchers for responsible disclosure based on severity and CVSS score:

### Scope

- **In Scope:** Kohl's Admin and Kohl's Admin Infinite
- **Out of Scope:** Building Tools by F3X (`vendor/f3x`)

### Rewards

| Severity | CVSS Score | Reward Range | Examples |
| :--- | :--- | :--- | :--- |
| Critical | 9.0–10.0 | R\$50,000 – R\$200,000+ | Authorization bypass, remote code execution, sensitive data exposure |
| High | 7.0–8.9 | R\$10,000 – R\$50,000 | High-impact logic exploit, server denial of service, privilege escalation |
| Medium | 4.0–6.9 | R\$2,500 – R\$10,000 | Commands that bypass rank checks, moderate information disclosure |
| Low | 0.1–3.9 | R\$50 – R\$2,500 | Cosmetic bypasses, low-impact information disclosure |

## Safe Harbor

We will not take legal action against anyone who reports security vulnerabilities in good faith under this policy. Testing that follows this policy is considered authorized conduct under the Computer Fraud and Abuse Act.
