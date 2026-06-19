$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "Nexium Connect Wrapper - GitHub + Discord Publisher" -ForegroundColor Green
Write-Host "This pushes the public wrapper repo and stores the Discord webhook safely as a GitHub Actions secret." -ForegroundColor DarkGray
Write-Host ""

function Require-Command($Name, $InstallHint) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        Write-Host "Missing command: $Name" -ForegroundColor Red
        Write-Host $InstallHint -ForegroundColor Yellow
        exit 1
    }
}

function Set-OriginRemote($RepoUrl) {
    $origin = git remote 2>$null | Select-String -Pattern "^origin$"
    if ($origin) {
        git remote set-url origin $RepoUrl
    }
    else {
        git remote add origin $RepoUrl
    }
}

Require-Command "git" "Install Git: https://git-scm.com/download/win"
Require-Command "gh" "Install GitHub CLI: winget install --id GitHub.cli"
Require-Command "node" "Install Node.js LTS: https://nodejs.org/"

$DefaultOwner = "buildsbybuchanan"
$DefaultRepo = "nexium-wrapper"

$RepoOwner = Read-Host "GitHub owner/org [$DefaultOwner]"
if ([string]::IsNullOrWhiteSpace($RepoOwner)) { $RepoOwner = $DefaultOwner }

$RepoName = Read-Host "Repo name [$DefaultRepo]"
if ([string]::IsNullOrWhiteSpace($RepoName)) { $RepoName = $DefaultRepo }

$FullRepo = "$RepoOwner/$RepoName"
$RepoUrl = "https://github.com/$FullRepo.git"

Write-Host ""
Write-Host "Wrapper app URL" -ForegroundColor Cyan
Write-Host "Paste the live Nexium Connect URL that the desktop wrapper must open." -ForegroundColor DarkGray
$AppUrl = Read-Host "Nexium Connect URL"
if (-not [string]::IsNullOrWhiteSpace($AppUrl)) {
    $ConfigPath = Join-Path $PSScriptRoot "..\src\config.ts"
    $SafeUrl = $AppUrl.Replace('"', '')
    Set-Content -Path $ConfigPath -Value "export const NEXIUM_CONNECT_URL = `"$SafeUrl`";" -Encoding UTF8
    Write-Host "Updated src/config.ts -> $SafeUrl" -ForegroundColor Green
}
else {
    Write-Host "No URL entered. Keeping the current wrapper URL." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Discord webhook setup" -ForegroundColor Cyan
Write-Host "Discord path: Channel Settings > Integrations > Webhooks > New Webhook > Copy Webhook URL" -ForegroundColor DarkGray
$DiscordWebhookSecure = Read-Host "Paste Discord webhook URL (hidden)" -AsSecureString
$Bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($DiscordWebhookSecure)
try {
    $DiscordWebhookUrl = [Runtime.InteropServices.Marshal]::PtrToStringAuto($Bstr)
}
finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($Bstr)
}

if ([string]::IsNullOrWhiteSpace($DiscordWebhookUrl)) {
    throw "Discord webhook URL is required. It will be stored as DISCORD_WEBHOOK_URL in GitHub secrets, not in the repo."
}

Write-Host ""
Write-Host "Checking GitHub login..." -ForegroundColor Cyan
gh auth status

Write-Host ""
Write-Host "Preparing local git repo..." -ForegroundColor Cyan
if (-not (Test-Path ".git")) {
    git init
}

git branch -M main
Set-OriginRemote $RepoUrl

Write-Host ""
Write-Host "Checking GitHub repo: $FullRepo" -ForegroundColor Cyan
gh repo view $FullRepo *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Repo not found. Creating public repo: $FullRepo" -ForegroundColor Yellow
    gh repo create $FullRepo --public --source . --remote origin
}
else {
    Write-Host "Repo exists. Using existing repo." -ForegroundColor Green
}

Write-Host ""
Write-Host "Saving Discord webhook as GitHub Actions secret: DISCORD_WEBHOOK_URL" -ForegroundColor Cyan
$DiscordWebhookUrl | gh secret set DISCORD_WEBHOOK_URL --repo $FullRepo

Write-Host ""
Write-Host "Committing wrapper files..." -ForegroundColor Cyan
git add .
git commit -m "Update Nexium Connect desktop wrapper with Discord alerts" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "No file changes detected. Creating an empty test commit so Discord can fire." -ForegroundColor Yellow
    git commit --allow-empty -m "Test Nexium wrapper Discord alert"
}

Write-Host ""
Write-Host "Pushing to GitHub..." -ForegroundColor Cyan
git push -u origin main

Write-Host ""
Write-Host "DONE" -ForegroundColor Green
Write-Host "Repo: https://github.com/$FullRepo" -ForegroundColor Green
Write-Host "Discord alert style: Nexium Connect app name, blue embed, event/status/branch/actor/commit/repo fields." -ForegroundColor Green
Write-Host "Secret stored only in GitHub Actions: DISCORD_WEBHOOK_URL" -ForegroundColor DarkGray
