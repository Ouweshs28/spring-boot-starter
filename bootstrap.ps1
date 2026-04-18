# Spring Boot Starter - Bootstrap
# Run with: irm https://raw.githubusercontent.com/Ouweshs28/spring-boot-starter/main/bootstrap.ps1 | iex

$ErrorActionPreference = "Stop"

function Write-Info    { param($m) Write-Host $m -ForegroundColor Cyan   }
function Write-Success { param($m) Write-Host $m -ForegroundColor Green  }
function Write-Warn    { param($m) Write-Host $m -ForegroundColor Yellow }

Write-Host ""
Write-Info "+------------------------------------------+"
Write-Info "|   Spring Boot Starter - Project Setup    |"
Write-Info "+------------------------------------------+"
Write-Host ""

# ---- Prompt ------------------------------------------------------------------
$ProjectName = Read-Host "Project name (e.g. my-app)"
$PackageName  = Read-Host "Base package  (e.g. com.example.myapp)"

# ---- Validate ----------------------------------------------------------------
if ($ProjectName -notmatch '^[a-z][a-z0-9-]*$') {
    Write-Host "ERROR: Project name must be lowercase letters, digits, and hyphens." -ForegroundColor Red
    exit 1
}
if ($PackageName -notmatch '^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*)*$') {
    Write-Host "ERROR: Package must be a valid Java package (e.g. com.example.myapp)." -ForegroundColor Red
    exit 1
}

# ---- Clone -------------------------------------------------------------------
$RepoUrl = "git@github.com:Ouweshs28/spring-boot-starter.git"

if (Test-Path $ProjectName) {
    Write-Host "ERROR: Directory '$ProjectName' already exists." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Info "Cloning template into '$ProjectName'..."
git clone $RepoUrl $ProjectName

Set-Location $ProjectName

# ---- Init --------------------------------------------------------------------
Write-Host ""
Write-Info "Running init script..."
& .\init.ps1 -ProjectName $ProjectName -PackageName $PackageName

Write-Host ""
Write-Success "Your project '$ProjectName' is ready in ./$ProjectName"
