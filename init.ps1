# -------------------------------------------------------------------------------
# init.ps1  -  Bootstrap this Spring Boot template into your own project
#
# Usage:
#   .\init.ps1 -ProjectName <name> -PackageName <package>
#
# Examples:
#   .\init.ps1 -ProjectName my-app -PackageName com.example.myapp
#   .\init.ps1          # interactive - will prompt for both values
# -------------------------------------------------------------------------------
param(
    [Alias("p")][string]$ProjectName,
    [Alias("n")][string]$PackageName
)

$ErrorActionPreference = "Stop"

function Write-Info    { param($m) Write-Host $m -ForegroundColor Cyan   }
function Write-Success { param($m) Write-Host $m -ForegroundColor Green  }
function Write-Warn    { param($m) Write-Host $m -ForegroundColor Yellow }
function Fail          { param($m) Write-Host "ERROR: $m" -ForegroundColor Red; exit 1 }

# ---- Prompt for missing values ------------------------------------------------
if (-not $ProjectName) { $ProjectName = Read-Host "Project name (e.g. my-app)" }
if (-not $PackageName)  { $PackageName  = Read-Host "Base package  (e.g. com.example.myapp)" }

# ---- Validate -----------------------------------------------------------------
if ($ProjectName -notmatch '^[a-z][a-z0-9-]*$') {
    Fail "Project name must be lowercase and contain only letters, digits, and hyphens."
}
if ($PackageName -notmatch '^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*)*$') {
    Fail "Package name must be a valid Java package (e.g. com.example.myapp)."
}

# ---- Derive values ------------------------------------------------------------
$OldGroup = "com.project.template"
$OldPath  = "com/project/template"
$NewPath  = $PackageName -replace '\.', '/'

# PascalCase: my-project -> MyProject
$ProjectPascal = ($ProjectName -split '-' |
    ForEach-Object { $_.Substring(0,1).ToUpper() + $_.Substring(1) }) -join ''

$Utf8NoBom = New-Object System.Text.UTF8Encoding $false

Write-Host ""
Write-Info "+-----------------------------------------+"
Write-Info "|  Initializing Spring Boot template       |"
Write-Info "+-----------------------------------------+"
Write-Host ""
Write-Host "  Project name : $ProjectName"
Write-Host "  Package      : $PackageName"
Write-Host "  Pascal case  : $ProjectPascal"
Write-Host ""

# ---- [1/4] Replace text in source files ---------------------------------------
Write-Info "  [1/4] Replacing text in source files..."

$SourceExts    = @(".xml",".java",".yaml",".yml",".md",".properties",".imports")
$ExcludeParts  = @("\.git\\","\\target\\","\.idea\\")

$Files = Get-ChildItem -Path . -Recurse -File | Where-Object {
    $path  = $_.FullName
    $extOk = ($SourceExts -contains $_.Extension) -or ($_.Name -eq "Dockerfile")
    if (-not $extOk) { return $false }
    foreach ($ex in $ExcludeParts) { if ($path -match $ex) { return $false } }
    return $true
}

foreach ($file in $Files) {
    $content = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
    if ([string]::IsNullOrEmpty($content)) { continue }

    $content = $content -replace [regex]::Escape($OldGroup),  $PackageName
    $content = $content -replace [regex]::Escape($OldPath),   $NewPath
    $content = $content -replace 'template-parent',      "$ProjectName-parent"
    $content = $content -replace 'template-app',         "$ProjectName-app"
    $content = $content -replace 'template-persistence', "$ProjectName-persistence"
    $content = $content -replace 'template-service',     "$ProjectName-service"
    $content = $content -replace 'template-rest',        "$ProjectName-rest"
    $content = $content -replace 'template-image',       "$ProjectName-image"
    $content = $content -replace 'jdbc:h2:mem:template', "jdbc:h2:mem:$ProjectName"
    $content = $content -replace 'image: Template:',     "image: ${ProjectPascal}:"
    $content = $content -replace '>Template<',           ">${ProjectPascal}<"
    $content = $content -replace '# Spring Boot Template', "# $ProjectPascal"

    [System.IO.File]::WriteAllText($file.FullName, $content, $Utf8NoBom)
}

# ---- [2/4] Rename Java package directories ------------------------------------
Write-Info "  [2/4] Renaming Java package directories..."

function Rename-PackageDir {
    param([string]$Base)
    $oldWin    = $OldPath -replace '/', '\'
    $newWin    = $NewPath -replace '/', '\'
    $oldPkgDir = Join-Path $Base $oldWin
    $newPkgDir = Join-Path $Base $newWin
    if (-not (Test-Path $oldPkgDir)) { return }
    $newParent = Split-Path $newPkgDir -Parent
    if (-not (Test-Path $newParent)) { New-Item -ItemType Directory -Path $newParent -Force | Out-Null }
    Move-Item -Path $oldPkgDir -Destination $newPkgDir
    # Clean up empty old intermediate dirs
    $oldMid  = Join-Path $Base "com\project"
    $oldRoot = Join-Path $Base "com"
    if ((Test-Path $oldMid) -and (@(Get-ChildItem $oldMid).Count -eq 0)) {
        Remove-Item $oldMid -Force
        if ((Test-Path $oldRoot) -and (@(Get-ChildItem $oldRoot).Count -eq 0)) {
            Remove-Item $oldRoot -Force
        }
    }
}

foreach ($module in @("template-persistence","template-service","template-rest")) {
    foreach ($srcType in @("src/main/java","src/test/java")) {
        Rename-PackageDir -Base "template-app\$module\$srcType"
    }
}

# ---- [3/4] Rename module and app directories ----------------------------------
Write-Info "  [3/4] Renaming module directories..."

foreach ($module in @("template-persistence","template-service","template-rest","template-image")) {
    $oldDir  = "template-app\$module"
    $newName = $module -replace '^template-', "$ProjectName-"
    if (Test-Path $oldDir) { Rename-Item -Path $oldDir -NewName $newName }
}
if (Test-Path "template-app") { Rename-Item -Path "template-app" -NewName "$ProjectName-app" }

# ---- [4/4] Reset git history --------------------------------------------------
Write-Host ""
Write-Warn "  [4/4] Reset git history?"
Write-Warn "        This removes the template's commit history and starts fresh."
$resetGit = Read-Host "        Reset? [y/N]"
if ($resetGit -match '^[Yy]$') {
    Remove-Item -Recurse -Force ".git"
    git init -q
    git add -A
    git commit -q -m "chore: initial project from spring-boot-starter"
    Write-Success "  Git repository re-initialized with a clean initial commit."
}

# ---- [5/5] Remove bootstrap / init scripts ------------------------------------
Write-Info "  [5/5] Cleaning up setup scripts..."
$setupScripts = @("bootstrap.ps1", "bootstrap.sh", "init.ps1", "init.sh")
foreach ($s in $setupScripts) {
    if (Test-Path $s) { Remove-Item $s -Force }
}
Write-Success "  Setup scripts removed."

# ---- Done ---------------------------------------------------------------------
Write-Host ""
Write-Success "  Done!  Project '$ProjectName' is ready."
Write-Host ""
Write-Host "  Next steps:"
Write-Host "    mvn clean install"
Write-Host "    cd $ProjectName-app\$ProjectName-rest"
Write-Host "    mvn spring-boot:run"
Write-Host ""
Write-Host "    Swagger UI  ->  http://localhost:8080/swagger-ui/index.html"
Write-Host "    H2 Console  ->  http://localhost:8080/h2-console"
Write-Host ""

