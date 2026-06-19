param(
    [string]$Repo = "buildsbybuchanan/nexium-wrapper"
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "Nexium Wrapper - GitHub Actions Discord setup" -ForegroundColor Cyan
Write-Host ""

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw "GitHub CLI is not installed. Install it from https://cli.github.com/"
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "Git is not installed."
}

gh auth status | Out-Host

$webhook = Read-Host "Paste Discord webhook URL"

if ([string]::IsNullOrWhiteSpace($webhook)) {
    throw "Discord webhook URL is required."
}

Write-Host "Saving DISCORD_WEBHOOK_URL in $Repo..." -ForegroundColor Yellow
$webhook | gh secret set DISCORD_WEBHOOK_URL --repo $Repo

$workflowDir = Join-Path (Get-Location) ".github\workflows"
New-Item -ItemType Directory -Force -Path $workflowDir | Out-Null

Get-ChildItem $workflowDir -Filter "*.yml" -ErrorAction SilentlyContinue | Remove-Item -Force
Get-ChildItem $workflowDir -Filter "*.yaml" -ErrorAction SilentlyContinue | Remove-Item -Force

$workflow = @'
name: Discord Repository Alerts

on:
  push:
    branches:
      - main
  pull_request:
    branches:
      - main
    types:
      - opened
      - reopened
      - synchronize
      - closed
  workflow_dispatch:

permissions:
  contents: read

jobs:
  discord:
    runs-on: ubuntu-latest

    steps:
      - name: Send Discord notification
        env:
          DISCORD_WEBHOOK_URL: ${{ secrets.DISCORD_WEBHOOK_URL }}
          EVENT_NAME: ${{ github.event_name }}
          REPOSITORY: ${{ github.repository }}
          ACTOR: ${{ github.actor }}
          REF_NAME: ${{ github.ref_name }}
          SHA: ${{ github.sha }}
          SERVER_URL: ${{ github.server_url }}
          RUN_ID: ${{ github.run_id }}
          PR_ACTION: ${{ github.event.action }}
          PR_NUMBER: ${{ github.event.pull_request.number }}
          PR_TITLE: ${{ github.event.pull_request.title }}
          COMMIT_MESSAGE: ${{ github.event.head_commit.message }}
        shell: bash
        run: |
          set -euo pipefail

          if [ -z "${DISCORD_WEBHOOK_URL:-}" ]; then
            echo "DISCORD_WEBHOOK_URL secret is missing."
            exit 1
          fi

          SHORT_SHA="${SHA:0:7}"
          RUN_URL="${SERVER_URL}/${REPOSITORY}/actions/runs/${RUN_ID}"

          if [ "$EVENT_NAME" = "push" ]; then
            TITLE="Nexium Connect code pushed"
            DESCRIPTION="${COMMIT_MESSAGE:-A new commit was pushed to main.}"
            DETAILS="**Event:** Push\n**Branch:** ${REF_NAME}\n**Actor:** ${ACTOR}\n**Commit:** \`${SHORT_SHA}\`\n**Repository:** ${REPOSITORY}"
            COLOR=3447003
          elif [ "$EVENT_NAME" = "pull_request" ]; then
            TITLE="Nexium Connect pull request ${PR_ACTION}"
            DESCRIPTION="${PR_TITLE:-Pull request update}"
            DETAILS="**Event:** Pull request\n**Action:** ${PR_ACTION}\n**PR:** #${PR_NUMBER}\n**Branch:** ${REF_NAME}\n**Actor:** ${ACTOR}\n**Repository:** ${REPOSITORY}"
            COLOR=10181046
          else
            TITLE="Nexium Connect workflow triggered"
            DESCRIPTION="The repository alert workflow was run manually."
            DETAILS="**Event:** Manual run\n**Branch:** ${REF_NAME}\n**Actor:** ${ACTOR}\n**Repository:** ${REPOSITORY}"
            COLOR=5763719
          fi

          PAYLOAD=$(jq -n \
            --arg title "$TITLE" \
            --arg description "$DESCRIPTION" \
            --arg details "$DETAILS" \
            --arg url "$RUN_URL" \
            --argjson color "$COLOR" \
            '{
              username: "Nexium Connect",
              embeds: [
                {
                  title: $title,
                  description: $description,
                  color: $color,
                  fields: [
                    {
                      name: "Details",
                      value: $details,
                      inline: false
                    }
                  ],
                  url: $url,
                  footer: {
                    text: "Nexium Connect · GitHub Actions"
                  }
                }
              ]
            }')

          curl --fail-with-body \
            -H "Content-Type: application/json" \
            -d "$PAYLOAD" \
            "$DISCORD_WEBHOOK_URL"
'@

$workflowPath = Join-Path $workflowDir "discord-alerts.yml"
Set-Content -Path $workflowPath -Value $workflow -Encoding utf8

Write-Host "Created $workflowPath" -ForegroundColor Green

git add .github/workflows/discord-alerts.yml

$changes = git status --porcelain
if ($changes) {
    git commit -m "Add Discord alerts for pushes and pull requests"
    git push origin main
}
else {
    Write-Host "No workflow changes to commit." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Testing the workflow..." -ForegroundColor Cyan
gh workflow run "Discord Repository Alerts" --repo $Repo

Start-Sleep -Seconds 3
gh run list --repo $Repo --workflow "Discord Repository Alerts" --limit 3

Write-Host ""
Write-Host "Done. Discord alerts are active for pushes, pull requests, and manual runs." -ForegroundColor Green
