$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $ProjectRoot

Write-Host ""
Write-Host "Nexium Wrapper - GitHub + Discord Setup" -ForegroundColor Green
Write-Host "Repo: buildsbybuchanan/nexium-wrapper" -ForegroundColor DarkGray
Write-Host ""

function Require-Command {
    param([string]$Name, [string]$InstallHint)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Missing command '$Name'. $InstallHint"
    }
}

function Run-Native {
    param([scriptblock]$Command, [string]$FailureMessage)
    & $Command
    if ($LASTEXITCODE -ne 0) { throw $FailureMessage }
}

Require-Command "git" "Install Git for Windows first."
Require-Command "gh" "Run: winget install --id GitHub.cli"
Require-Command "node" "Install Node.js LTS first."
Require-Command "npm.cmd" "npm is installed with Node.js."

$DefaultOwner = "buildsbybuchanan"
$DefaultRepo = "nexium-wrapper"

$RepoOwner = Read-Host "GitHub owner [$DefaultOwner]"
if ([string]::IsNullOrWhiteSpace($RepoOwner)) { $RepoOwner = $DefaultOwner }

$RepoName = Read-Host "Repository name [$DefaultRepo]"
if ([string]::IsNullOrWhiteSpace($RepoName)) { $RepoName = $DefaultRepo }

$FullRepo = "$RepoOwner/$RepoName"
$RepoUrl = "https://github.com/$FullRepo.git"

Write-Host ""
$AppUrl = Read-Host "Nexium Connect live URL [keep current]"
if (-not [string]::IsNullOrWhiteSpace($AppUrl)) {
    if ($AppUrl -notmatch '^https://') { throw "Use a full HTTPS URL." }
    $SafeUrl = $AppUrl.Replace('"', '')
    Set-Content -Path (Join-Path $ProjectRoot "src/config.ts") -Value "export const NEXIUM_CONNECT_URL = `"$SafeUrl`";" -Encoding utf8
    Write-Host "Updated wrapper URL." -ForegroundColor Green
}

Write-Host ""
Write-Host "Paste the webhook for the Discord channel that receives GitHub alerts." -ForegroundColor Cyan
Write-Host "Discord: Channel Settings > Integrations > Webhooks > Copy Webhook URL" -ForegroundColor DarkGray
$SecureWebhook = Read-Host "Discord webhook URL (hidden)" -AsSecureString
$Ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureWebhook)
try {
    $DiscordWebhookUrl = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($Ptr)
}
finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($Ptr)
}

if ([string]::IsNullOrWhiteSpace($DiscordWebhookUrl) -or $DiscordWebhookUrl -notmatch '^https://(discord.com|discordapp.com)/api/webhooks/') {
    throw "That does not look like a valid Discord webhook URL."
}

Write-Host ""
Write-Host "Checking GitHub CLI login..." -ForegroundColor Cyan
Run-Native { gh auth status } "GitHub CLI is not logged in. Run: gh auth login"

Write-Host "Installing dependencies and generating the lock file..." -ForegroundColor Cyan
Run-Native { & npm.cmd install } "npm install failed."
Run-Native { & npm.cmd run build } "The local Vite build failed. Nothing was pushed."

if (-not (Test-Path ".git")) {
    Run-Native { git init } "git init failed."
}

Run-Native { git branch -M main } "Could not set the main branch."

$OriginExists = (git remote 2>$null) -contains "origin"
if ($OriginExists) {
    Run-Native { git remote set-url origin $RepoUrl } "Could not update the origin remote."
} else {
    Run-Native { git remote add origin $RepoUrl } "Could not add the origin remote."
}

Write-Host "Saving DISCORD_WEBHOOK_URL in GitHub Actions secrets..." -ForegroundColor Cyan
$DiscordWebhookUrl | gh secret set DISCORD_WEBHOOK_URL --repo $FullRepo
if ($LASTEXITCODE -ne 0) { throw "Could not save the Discord webhook secret." }
$DiscordWebhookUrl = $null

Write-Host "Committing files..." -ForegroundColor Cyan
Run-Native { git add --all } "git add failed."

git diff --cached --quiet
if ($LASTEXITCODE -eq 0) {
    Run-Native { git commit --allow-empty -m "Test Nexium wrapper build and Discord alert" } "Could not create the test commit."
} else {
    Run-Native { git commit -m "Fix Nexium wrapper build and Discord alerts" } "git commit failed."
}

Write-Host "Pushing to $FullRepo..." -ForegroundColor Cyan
Run-Native { git push -u origin main } "Git push failed."

Write-Host "Waiting for the GitHub Actions run..." -ForegroundColor Cyan
Start-Sleep -Seconds 4
$RunId = gh run list --repo $FullRepo --workflow "Build Check" --branch main --limit 1 --json databaseId --jq '.[0].databaseId'
if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($RunId)) {
    gh run watch $RunId --repo $FullRepo --exit-status
    if ($LASTEXITCODE -ne 0) {
        Write-Host "The workflow finished with a failure. Open the run shown above for the exact step." -ForegroundColor Red
        exit 1
    }
}
else {
    Write-Host "Push completed. Check the Actions tab and Discord channel." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "DONE" -ForegroundColor Green
Write-Host "GitHub: https://github.com/$FullRepo" -ForegroundColor Green
Write-Host "Discord notification is sent even when the build fails." -ForegroundColor Green
