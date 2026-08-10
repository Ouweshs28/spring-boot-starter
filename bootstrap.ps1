# Spring Boot Starter - Bootstrap
# Run with: & ([scriptblock]::Create((irm https://raw.githubusercontent.com/Ouweshs28/spring-boot-starter/main/bootstrap.ps1)))

param(
    [Alias("p")][string]$ProjectName,
    [Alias("n")][string]$PackageName,
    [Alias("m")][string]$MigrationTool,
    [Alias("j")][string]$SpringDataJpa,
    [Alias("b")][string]$BlazePersistence,
    [Alias("s")][int]$ExtraServiceModules,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

function Write-Info    { param($m) Write-Host $m -ForegroundColor Cyan   }
function Write-Success { param($m) Write-Host $m -ForegroundColor Green  }
function Fail          { param($m) Write-Host "ERROR: $m" -ForegroundColor Red; exit 1 }

if ($Help) {
    @"
Usage: .\bootstrap.ps1 [options]
  -ProjectName/-p          Lowercase, hyphenated name (e.g. my-app)
  -PackageName/-n          Java base package (e.g. com.example.myapp)
  -MigrationTool/-m        flyway | liquibase | none
  -SpringDataJpa/-j        true | false
  -BlazePersistence/-b     true | false
  -ExtraServiceModules/-s  Number of extra service modules to scaffold
  -Help                    Show this help message
"@ | Write-Host
    exit 0
}

Write-Host ""
Write-Info "+------------------------------------------+"
Write-Info "|   Spring Boot Starter - Project Setup    |"
Write-Info "+------------------------------------------+"
Write-Host ""

if (-not $ProjectName) { $ProjectName = Read-Host "Project name (e.g. my-app)" }
if (-not $PackageName)  { $PackageName  = Read-Host "Base package  (e.g. com.example.myapp)" }

# ---- Validate ----------------------------------------------------------------
if ($ProjectName -notmatch '^[a-z][a-z0-9-]*$') {
    Fail "Project name must be lowercase letters, digits, and hyphens."
}
if ($PackageName -notmatch '^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*)*$') {
    Fail "Package must be a valid Java package (e.g. com.example.myapp)."
}

# ---- Clone -------------------------------------------------------------------
$RepoUrl = "https://github.com/Ouweshs28/spring-boot-starter.git"

if (Test-Path $ProjectName) {
    Fail "Directory '$ProjectName' already exists."
}

Write-Host ""
Write-Info "Cloning template into '$ProjectName'..."
git clone $RepoUrl $ProjectName

Set-Location $ProjectName

# ---- Init --------------------------------------------------------------------
Write-Host ""
Write-Info "Running init script..."
$initArgs = @("-ProjectName", $ProjectName, "-PackageName", $PackageName)
if ($PSBoundParameters.ContainsKey("MigrationTool")) {
    $initArgs += @("-MigrationTool", $MigrationTool)
}
if ($PSBoundParameters.ContainsKey("SpringDataJpa")) {
    $initArgs += @("-SpringDataJpa", $SpringDataJpa)
}
if ($PSBoundParameters.ContainsKey("BlazePersistence")) {
    $initArgs += @("-BlazePersistence", $BlazePersistence)
}
if ($PSBoundParameters.ContainsKey("ExtraServiceModules")) {
    $initArgs += @("-ExtraServiceModules", $ExtraServiceModules)
}
& .\init.ps1 @initArgs

Write-Host ""
Write-Success "Your project '$ProjectName' is ready in ./$ProjectName"
