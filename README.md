# Nexium Connect Wrapper

A lightweight desktop shell for Nexium Connect.

This repo is only the wrapper. It does not contain the Nexium Connect backend, database, API keys, Discord webhook, Groq keys, WhatsApp credentials, Supabase keys, Render secrets, or private business logic.

The wrapper opens the hosted Nexium Connect app inside a native desktop window so the system can be used like a normal installed application instead of only as a browser tab.

---

## What this is

Nexium Connect already runs as a web app. This project packages that web app into a desktop application using Tauri.

In simple terms:

```text
Nexium Connect web app
        ↓
Tauri desktop wrapper
        ↓
Nexium Connect.exe
```

The wrapper gives the app a cleaner desktop experience while keeping the real product hosted online.

---

## Why this wrapper exists

The goal is not to rebuild Nexium Connect from scratch.

The goal is to give the existing system a proper desktop entry point for daily work:

- open Nexium Connect from the desktop
- keep it separate from normal browser tabs
- prepare the app for a more professional internal rollout
- support future native features like tray mode, notifications, file handling, and auto updates
- keep secrets out of the public repo

---

## Stack

- Tauri
- TypeScript
- HTML
- CSS
- Rust for the Tauri shell
- GitHub Actions
- Discord webhook notifications

---

## Repo structure

```text
.
├── .github
│   └── workflows
│       ├── build-check.yml
│       └── discord-push.yml
├── scripts
│   ├── build.ps1
│   ├── dev.ps1
│   └── publish.ps1
├── src
│   ├── config.ts
│   ├── main.ts
│   └── styles.css
├── src-tauri
│   ├── src
│   │   ├── lib.rs
│   │   └── main.rs
│   ├── build.rs
│   ├── Cargo.toml
│   └── tauri.conf.json
├── index.html
├── package.json
└── README.md
```

---

## What is not stored here

Do not commit secrets to this repo.

This repo should never contain:

- Discord webhook URLs
- API keys
- database passwords
- Supabase service role keys
- Render secrets
- Vercel tokens
- WhatsApp tokens
- Groq keys
- customer data
- private lead data
- onboarding documents

The only safe public information here is the wrapper code and the public URL it loads.

---

## Requirements

Install these before running the scripts:

- Git
- GitHub CLI
- Node.js LTS
- Rust
- Tauri prerequisites for Windows

On Windows, GitHub CLI can be installed with:

```powershell
winget install --id GitHub.cli
```

Then log in:

```powershell
gh auth login
```

---

## Set the Nexium Connect URL

The wrapper URL is stored in:

```text
src/config.ts
```

Example:

```ts
export const NEXIUM_CONNECT_URL = "https://your-nexium-connect-url.vercel.app";
```

The publish script can update this for you from the terminal.

---

## Run locally

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\dev.ps1
```

Or manually:

```powershell
npm install
npm run tauri:dev
```

---

## Build the desktop app

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\build.ps1
```

Or manually:

```powershell
npm install
npm run tauri:build
```

The built app will be inside the Tauri target folder.

---

## GitHub Actions Discord alerts

This repo includes:

```text
.github/workflows/discord-push.yml
```

The alert is built to match the existing Nexium Connect Discord style:

- app name: `Nexium Connect`
- title: `Nexium Connect code pushed`
- blue Discord embed strip
- commit message under the push line
- fields for Event, Status, Branch, Actor, Commit, and Repository
- footer showing repo and branch

The workflow runs on:

- push to `main`
- pull request against `main`
- manual workflow trigger

The workflow uses one GitHub Actions secret:

```text
DISCORD_WEBHOOK_URL
```

The webhook URL must be stored in GitHub Actions secrets. It must not be pasted into the repo.

---

## How to get a Discord webhook URL

In Discord:

1. Open the server
2. Open the channel where alerts must be posted
3. Click channel settings
4. Open **Integrations**
5. Open **Webhooks**
6. Create a new webhook
7. Copy the webhook URL
8. Paste it into the terminal when the publish script asks for it

---

## Push everything through the CLI

This repo includes a PowerShell publisher:

```text
scripts/publish.ps1
```

It will ask for:

- GitHub owner or org
- repo name
- Nexium Connect app URL
- Discord webhook URL

Then it will:

- initialize git if needed
- set the main branch
- connect the repo remote
- create the GitHub repo if it does not exist
- store `DISCORD_WEBHOOK_URL` as a GitHub Actions secret
- push the code to GitHub
- trigger the Discord workflow on push

Run it from the project folder:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\publish.ps1
```

For the current repo, use:

```text
GitHub owner/org: buildsbybuchanan
Repo name: nexium-wrapper
Repo URL: https://github.com/buildsbybuchanan/nexium-wrapper.git
```

---

## Add the Discord secret manually

If you do not use the script, add the secret manually:

```powershell
gh secret set DISCORD_WEBHOOK_URL --repo buildsbybuchanan/nexium-wrapper
```

Paste the Discord webhook URL when asked.

Then push a test commit:

```powershell
git commit --allow-empty -m "Test Discord workflow"
git push
```

---

## Normal Git workflow

```powershell
git add .
git commit -m "Update wrapper"
git push
```

Every push to `main` should send a message to the Discord channel.

---

## Notes for public repo safety

This repo is safe to keep public as long as secrets stay out of the files.

Before pushing, check:

```powershell
git status
git diff --cached
```

If a secret is ever pasted into a file, remove it before committing. If it was already pushed, rotate the secret immediately.

---

## License

MIT
