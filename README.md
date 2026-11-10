# EvilClaude CLI

[![Version](https://img.shields.io/badge/version-1.0.28-crimson.svg?style=flat-square)](https://github.com/swampmine/evilclaude-cli/releases)
[![Gateway](https://img.shields.io/badge/gateway-evilclaude.swampmine.in-blue.svg?style=flat-square)](https://evilclaude.swampmine.in)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20Windows%20%7C%20Termux-darkgreen.svg?style=flat-square)](#installation)
[![License](https://img.shields.io/badge/license-MIT-purple.svg?style=flat-square)](LICENSE)

**EvilClaude** is an AI coding agent and terminal assistant designed for unrestricted software engineering, automated refactoring, and full shell execution — routed through the SwampMine intelligence network.

---

## ⚡ Quick Installation

### Linux / macOS / WSL / Android (Termux)
Run the universal installer:
```bash
curl -fsSL https://evilclaude.swampmine.in/install.sh | bash
```
*Or via GitHub mirror:*
```bash
curl -fsSL https://raw.githubusercontent.com/swampmine/evilclaude-cli/main/install.sh | bash
```

### Windows (PowerShell)
Open PowerShell as Administrator or regular user and run:
```powershell
irm https://evilclaude.swampmine.in/install.ps1 | iex
```
*Or via GitHub mirror:*
```powershell
irm https://raw.githubusercontent.com/swampmine/evilclaude-cli/main/install.ps1 | iex
```

### Direct Download
- Standalone Node/Bun Bundle: [`cli.js`](https://raw.githubusercontent.com/swampmine/evilclaude-cli/main/cli.js)
- Linux x64 Release: [evilclaude-linux-x64.tar.gz](https://evilclaude.swampmine.in/downloads/evilclaude-linux-x64.tar.gz)
- Linux ARM64 Release: [evilclaude-linux-arm64.tar.gz](https://evilclaude.swampmine.in/downloads/evilclaude-linux-arm64.tar.gz)

---

## 🚀 Getting Started

### 1. Authenticate your terminal
Launch device login to link your terminal to your EvilClaude account:
```bash
evilclaude login
```
The CLI will print an authorization code and open the approval page:
```
┌────────────────────────────────────────────────────────┐
│  EvilClaude Terminal Authorization                     │
│                                                        │
│  To connect this terminal to your account, open:       │
│  https://evilclaude.swampmine.in/device                │
│                                                        │
│  Verification code: XXXX-XXXX                          │
└────────────────────────────────────────────────────────┘
```
Once approved in your browser, your terminal automatically activates and saves your credentials to `~/.evilclaude/api_key`.

*Alternatively, you can manually export your API key:*
```bash
export SWAMPMINE_API_KEY="ec_your_api_key_here"
```

### 2. Start an interactive session
In your project directory, launch EvilClaude:
```bash
cd /path/to/your/project
evilclaude
```

### 3. Non-interactive / Scripting mode (`-p`)
Ask a question or perform a quick command:
```bash
evilclaude -p "Review this repository and identify security vulnerabilities"
```

---

## 🎯 Key Capabilities

- **Autonomous Tool Use:** Reads, edits, creates files, runs builds, and executes test suites autonomously.
- **Deep Codebase Awareness:** Scans Git worktrees, detects language setups, and analyzes AST structures.
- **Model Routing:** Powered by **WormGPT-5** and **WormGPT-5.1** through the high-throughput gateway.
- **MCP Extensibility:** Full support for Model Context Protocol servers (`evilclaude mcp`).
- **Remote Teleport & Web Mirroring:** Mirror live CLI sessions to the web workspace at [`evilclaude.swampmine.in`](https://evilclaude.swampmine.in).

---

## 🛠️ Command Reference

| Command | Description |
| :--- | :--- |
| `evilclaude` | Starts the interactive coding session |
| `evilclaude -p "<prompt>"` | Executes prompt non-interactively and prints result |
| `evilclaude login` | Connects terminal to your EvilClaude account via browser |
| `evilclaude logout` | Signs out and clears stored session credentials |
| `evilclaude update` | Checks for real-time updates and upgrades to the latest version |
| `evilclaude doctor` | Runs self-diagnostics on connectivity and configuration |
| `evilclaude mcp` | Lists and manages MCP plugins and external tool servers |
| `evilclaude --version` | Displays installed version (current: `1.0.25`) |

---

## 🔄 Real-Time Updates

EvilClaude CLI features real-time version checking. To update your CLI at any time, run:
```bash
evilclaude update
```
Or re-run the universal installer:
```bash
curl -fsSL https://evilclaude.swampmine.in/install.sh | bash
```

---

## 🌐 Community & Links

- **Web Gateway & Dashboard:** [https://evilclaude.swampmine.in](https://evilclaude.swampmine.in)
- **Status & Model Health:** [https://evilclaude.swampmine.in/status](https://evilclaude.swampmine.in/status)
- **API Documentation:** [https://evilclaude.swampmine.in/docs](https://evilclaude.swampmine.in/docs)
- **Source Code (Private Monorepo):** `swampmine/evilclaude`
- **Public CLI Distribution:** [swampmine/evilclaude-cli](https://github.com/swampmine/evilclaude-cli)
