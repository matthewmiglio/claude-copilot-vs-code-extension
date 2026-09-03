# Claude Copilot - Routes Claude Code to GitHub Copilot models (gpt-5.6-sol) via
# a local @jeffreycao/copilot-api proxy (serves Anthropic /v1/messages, routes
# per-model to Copilot's /responses vs /chat/completions).
# Usage: .\claude-copilot.ps1 [args to pass to claude]
param(
  [string]$Model = "gpt-5.6-sol",
  [int]$Port = 4142,
  [string]$Token = "$HOME\.local\share\copilot-api\github_token"
)
$ErrorActionPreference = "Stop"

if (-not (Test-Path $Token)) {
    Write-Host "No Copilot token at $Token" -ForegroundColor Red
    Write-Host "Set it up once with:  npx copilot-api@latest auth" -ForegroundColor Yellow
    exit 1
}
$gh = (Get-Content $Token -Raw).Trim()

# Snapshot env we change so we can restore it afterward
$old = @{
    Base  = $env:ANTHROPIC_BASE_URL
    Tok   = $env:ANTHROPIC_AUTH_TOKEN
    Key   = $env:ANTHROPIC_API_KEY
    Model = $env:ANTHROPIC_MODEL
    Ctx   = $env:CLAUDE_CODE_MAX_CONTEXT_TOKENS
}

# ponytail: reuse a proxy already on the port instead of double-starting one
$up = $false
try { Invoke-WebRequest "http://localhost:$Port/models" -TimeoutSec 2 -UseBasicParsing | Out-Null; $up = $true } catch {}

$proxy = $null
if (-not $up) {
    Write-Host "Starting copilot-api proxy on :$Port ..." -ForegroundColor Cyan
    # npx.cmd, not npx: Start-Process can't launch the npx.ps1 shim (silent no-op)
    $proxy = Start-Process -PassThru -WindowStyle Minimized "npx.cmd" `
        -ArgumentList @("-y","@jeffreycao/copilot-api@latest","start","--port","$Port","-g",$gh)
    for ($i = 0; $i -lt 45; $i++) {
        Start-Sleep 1
        if ((Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0) { $up = $true; break }
    }
    if (-not $up) {
        Write-Host "Proxy never came up on :$Port" -ForegroundColor Red
        if ($proxy) { Stop-Process -Id $proxy.Id -Force -ErrorAction SilentlyContinue }
        exit 1
    }
}
Write-Host "Proxy live. Launching Claude Code on model '$Model'." -ForegroundColor Green

# Point Claude Code at the local proxy (auth-token/dummy mode). sol needs its
# real 400k window declared, else Claude Code assumes 200k for the unknown model.
$env:ANTHROPIC_BASE_URL = "http://localhost:$Port"
$env:ANTHROPIC_AUTH_TOKEN = "dummy"
$env:CLAUDE_CODE_MAX_CONTEXT_TOKENS = "400000"
Remove-Item Env:\ANTHROPIC_API_KEY -ErrorAction SilentlyContinue

$claudeArgs = @($args)
if ($claudeArgs -notcontains '--model') {
    $claudeArgs = @('--model', $Model) + $claudeArgs
}

try {
    claude @claudeArgs
} finally {
    if ($proxy) { Stop-Process -Id $proxy.Id -Force -ErrorAction SilentlyContinue }
    if ($old.Base)  { $env:ANTHROPIC_BASE_URL = $old.Base }          else { Remove-Item Env:\ANTHROPIC_BASE_URL -ErrorAction SilentlyContinue }
    if ($old.Tok)   { $env:ANTHROPIC_AUTH_TOKEN = $old.Tok }         else { Remove-Item Env:\ANTHROPIC_AUTH_TOKEN -ErrorAction SilentlyContinue }
    if ($old.Key)   { $env:ANTHROPIC_API_KEY = $old.Key }            else { Remove-Item Env:\ANTHROPIC_API_KEY -ErrorAction SilentlyContinue }
    if ($old.Model) { $env:ANTHROPIC_MODEL = $old.Model }            else { Remove-Item Env:\ANTHROPIC_MODEL -ErrorAction SilentlyContinue }
    if ($old.Ctx)   { $env:CLAUDE_CODE_MAX_CONTEXT_TOKENS = $old.Ctx } else { Remove-Item Env:\CLAUDE_CODE_MAX_CONTEXT_TOKENS -ErrorAction SilentlyContinue }
}
