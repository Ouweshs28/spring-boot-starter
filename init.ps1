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

# Sync the .NET process working directory with PowerShell's current location.
# [System.IO.File] methods resolve relative paths against the .NET CWD, which
# does NOT follow Set-Location — this one line fixes that.
[System.IO.Directory]::SetCurrentDirectory((Get-Location).Path)

Write-Host ""
Write-Info "+-----------------------------------------+"
Write-Info "|  Initializing Spring Boot template       |"
Write-Info "+-----------------------------------------+"
Write-Host ""
Write-Host "  Project name : $ProjectName"
Write-Host "  Package      : $PackageName"
Write-Host "  Pascal case  : $ProjectPascal"
Write-Host ""

# ---- [1/5] Replace text in source files ---------------------------------------
Write-Info "  [1/5] Replacing text in source files..."

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

# ---- [2/5] Rename Java package directories ------------------------------------
Write-Info "  [2/5] Renaming Java package directories..."

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

# ---- [3/5] Rename module and app directories ----------------------------------
Write-Info "  [3/5] Renaming module directories..."

foreach ($module in @("template-persistence","template-service","template-rest","template-image")) {
    $oldDir  = "template-app\$module"
    $newName = $module -replace '^template-', "$ProjectName-"
    if (Test-Path $oldDir) { Rename-Item -Path $oldDir -NewName $newName }
}
if (Test-Path "template-app") { Rename-Item -Path "template-app" -NewName "$ProjectName-app" }

# ---- [4/5] Create additional service modules ----------------------------------
Write-Host ""
Write-Info "  [4/5] Additional service modules"
Write-Host ""
$moduleCountInput = Read-Host "  How many extra service modules do you want to create? (0 to skip)"
$moduleCount = 0
if ($moduleCountInput -match '^\d+$') {
    $moduleCount = [int]$moduleCountInput
    if ($moduleCount -gt 10) {
        Write-Warn "  Clamping to 10 modules maximum."
        $moduleCount = 10
    }
}
if ($moduleCount -gt 0) {
    $AppPomPath   = "$ProjectName-app\pom.xml"
    $ReservedMods = @('app','parent','rest','persistence','service','image','core','common','web','api')
    $CreatedMods  = @()
    # --- Optionally rename the existing service module for consistency --------
    $ExistingServiceDir = "$ProjectName-app\$ProjectName-service"
    if (Test-Path $ExistingServiceDir) {
        Write-Host ""
        Write-Info "  Rename existing module '$ProjectName-service'?"
        Write-Host "  Since you are adding extra modules, consider giving it a specific"
        Write-Host "  name (e.g. 'user', 'user-mgmt', 'account')."
        Write-Host ""
        $newSvcName = Read-Host "  New name for '$ProjectName-service' [Enter to keep as 'service']"
        $newSvcName = $newSvcName.Trim().ToLower()
        if (-not [string]::IsNullOrWhiteSpace($newSvcName) -and $newSvcName -ne 'service') {
            $svcValid = $true
            if ($newSvcName -notmatch '^[a-z][a-z0-9-]*$') {
                Write-Warn "  Invalid name - keeping '$ProjectName-service' as-is."; $svcValid = $false
            }
            if ($svcValid -and ($newSvcName.Length -lt 2 -or $newSvcName.Length -gt 50)) {
                Write-Warn "  Name must be 2-50 chars - keeping '$ProjectName-service' as-is."; $svcValid = $false
            }
            if ($svcValid -and ($newSvcName -match '-$' -or $newSvcName -match '--')) {
                Write-Warn "  No trailing hyphen or consecutive hyphens - keeping '$ProjectName-service' as-is."; $svcValid = $false
            }
            if ($svcValid -and ($newSvcName -in $ReservedMods)) {
                Write-Warn "  Reserved name - keeping '$ProjectName-service' as-is."; $svcValid = $false
            }
            if ($svcValid -and (Test-Path "$ProjectName-app\$ProjectName-$newSvcName")) {
                Write-Warn "  Directory already exists - keeping '$ProjectName-service' as-is."; $svcValid = $false
            }
            if ($svcValid) {
                $NewSvcFull = "$ProjectName-$newSvcName"
                foreach ($f in @("$ProjectName-app\pom.xml", "$ProjectName-app\$ProjectName-rest\pom.xml", "$ExistingServiceDir\pom.xml")) {
                    if (Test-Path $f) {
                        $c = [System.IO.File]::ReadAllText($f, [System.Text.Encoding]::UTF8)
                        $c = $c -replace [regex]::Escape("$ProjectName-service"), $NewSvcFull
                        [System.IO.File]::WriteAllText($f, $c, $Utf8NoBom)
                    }
                }
                Rename-Item -Path $ExistingServiceDir -NewName $NewSvcFull
                Write-Success "  Renamed '$ProjectName-service' -> '$NewSvcFull'"
                $ReservedMods += $newSvcName
                $CreatedMods  += $newSvcName
            }
        } else {
            Write-Info "  Keeping '$ProjectName-service' as-is."
        }
    }
    # --- Create new modules ---------------------------------------------------
    for ($i = 1; $i -le $moduleCount; $i++) {
        Write-Host ""
        $modName = Read-Host "  Module $i of ${moduleCount} - name (e.g. payment, notification)"
        $modName = $modName.Trim().ToLower()
        if ([string]::IsNullOrWhiteSpace($modName))            { Write-Warn "  Skipping - name cannot be empty."; continue }
        if ($modName -notmatch '^[a-z][a-z0-9-]*$')           { Write-Warn "  Skipping '$modName' - lowercase letters, digits, hyphens only."; continue }
        if ($modName.Length -lt 2 -or $modName.Length -gt 50) { Write-Warn "  Skipping '$modName' - must be 2-50 characters."; continue }
        if ($modName -match '-$' -or $modName -match '--')     { Write-Warn "  Skipping '$modName' - no trailing/consecutive hyphens."; continue }
        if ($modName -in $ReservedMods)                        { Write-Warn "  Skipping '$modName' - reserved name."; continue }
        if ($modName -in $CreatedMods)                         { Write-Warn "  Skipping '$modName' - already created in this session."; continue }
        $FullMod = "$ProjectName-$modName"
        $ModDir  = "$ProjectName-app\$FullMod"
        if (Test-Path $ModDir) { Write-Warn "  Skipping '$modName' - directory already exists."; continue }
        $AppPomText = [System.IO.File]::ReadAllText($AppPomPath, [System.Text.Encoding]::UTF8)
        if ($AppPomText -match [regex]::Escape("<module>$FullMod</module>")) {
            Write-Warn "  Skipping '$modName' - already registered in app pom.xml."; continue
        }
        # Create dirs
        New-Item -ItemType Directory -Path "$ModDir\src\main\java\$NewPath" -Force | Out-Null
        New-Item -ItemType Directory -Path "$ModDir\src\test\java\$NewPath"  -Force | Out-Null
        # Generate pom.xml
        $nl2 = "`r`n"
        $pom = ('<?xml version="1.0" encoding="UTF-8"?>'                                                                      + $nl2 +
                '<project xmlns="http://maven.apache.org/POM/4.0.0"'                                                          + $nl2 +
                '         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"'                                              + $nl2 +
                '         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">'+ $nl2 +
                '    <modelVersion>4.0.0</modelVersion>'                                                                       + $nl2 +
                '    <parent>'                                                                                                  + $nl2 +
                "        <artifactId>$ProjectName-app</artifactId>"                                                            + $nl2 +
                "        <groupId>$PackageName</groupId>"                                                                      + $nl2 +
                '        <version>1.0-SNAPSHOT</version>'                                                                      + $nl2 +
                '    </parent>'                                                                                                 + $nl2 +
                $nl2 +
                "    <artifactId>$FullMod</artifactId>"                                                                        + $nl2 +
                $nl2 +
                '    <dependencies>'                                                                                            + $nl2 +
                '        <dependency>'                                                                                          + $nl2 +
                "            <groupId>$PackageName</groupId>"                                                                  + $nl2 +
                "            <artifactId>$ProjectName-persistence</artifactId>"                                                + $nl2 +
                '        </dependency>'                                                                                         + $nl2 +
                '        <dependency>'                                                                                          + $nl2 +
                '            <groupId>org.mapstruct</groupId>'                                                                 + $nl2 +
                '            <artifactId>mapstruct</artifactId>'                                                               + $nl2 +
                '        </dependency>'                                                                                         + $nl2 +
                '        <dependency>'                                                                                          + $nl2 +
                '            <groupId>org.mapstruct</groupId>'                                                                 + $nl2 +
                '            <artifactId>mapstruct-processor</artifactId>'                                                     + $nl2 +
                '        </dependency>'                                                                                         + $nl2 +
                '        <dependency>'                                                                                          + $nl2 +
                '            <groupId>org.springframework.boot</groupId>'                                                      + $nl2 +
                '            <artifactId>spring-boot-starter-json</artifactId>'                                                + $nl2 +
                '        </dependency>'                                                                                         + $nl2 +
                '        <dependency>'                                                                                          + $nl2 +
                '            <groupId>jakarta.validation</groupId>'                                                            + $nl2 +
                '            <artifactId>jakarta.validation-api</artifactId>'                                                  + $nl2 +
                '        </dependency>'                                                                                         + $nl2 +
                '        <dependency>'                                                                                          + $nl2 +
                '            <groupId>io.swagger.core.v3</groupId>'                                                            + $nl2 +
                '            <artifactId>swagger-annotations</artifactId>'                                                     + $nl2 +
                '        </dependency>'                                                                                         + $nl2 +
                '        <dependency>'                                                                                          + $nl2 +
                '            <groupId>org.springframework.boot</groupId>'                                                      + $nl2 +
                '            <artifactId>spring-boot-starter-test</artifactId>'                                                + $nl2 +
                '            <scope>test</scope>'                                                                               + $nl2 +
                '        </dependency>'                                                                                         + $nl2 +
                '    </dependencies>'                                                                                           + $nl2 +
                '</project>')
        [System.IO.File]::WriteAllText("$ModDir\pom.xml", $pom, $Utf8NoBom)
        # Register in app pom.xml
        $AppPomText = $AppPomText -replace '(?m)([ \t]*</modules>)', "`t`t<module>$FullMod</module>`r`n`$1"
        $dep  = "`t`t<dependency>`r`n"
        $dep += "`t`t`t<groupId>$PackageName</groupId>`r`n"
        $dep += "`t`t`t<artifactId>$FullMod</artifactId>`r`n"
        $dep += "`t`t`t<version>`${project.version}</version>`r`n"
        $dep += "`t`t</dependency>`r`n"
        if ($AppPomText -match '<!-- Lombok -->') {
            $AppPomText = $AppPomText -replace '(?m)([ \t]*<!-- Lombok -->)', "$dep`t`t`$1"
        }
        [System.IO.File]::WriteAllText($AppPomPath, $AppPomText, $Utf8NoBom)
        Write-Success "  Created: $FullMod"
        $CreatedMods += $modName
    }
    if ($CreatedMods.Count -gt 0) {
        Write-Host ""
        Write-Info "  Modules created: $($CreatedMods -join ', ')"
    }
}

# ---- [5/5] Reset git history and remove remote --------------------------------
Write-Host ""
Write-Info "  [5/5] Resetting git history..."

if (Test-Path ".git") { Remove-Item -Recurse -Force ".git" }
git init -q
git add -A | Out-Null
git commit -q -m "chore: initial project from spring-boot-starter" | Out-Null
Write-Success "  Git repository initialized with a clean history (no remote)."

# ---- Remove bootstrap / init scripts ------------------------------------------
Write-Info "  Cleaning up setup scripts..."
foreach ($s in @("bootstrap.ps1","bootstrap.sh","init.ps1","init.sh")) {
    if (Test-Path $s) { Remove-Item -Force $s }
}
Write-Success "  Setup scripts removed."

# ---- Done ---------------------------------------------------------------------
Write-Host ""
Write-Success "  Done!  Project '$ProjectName' is ready."
Write-Host ""
Write-Host "  Next steps:"
Write-Host "    mvn clean install"
Write-Host "    cd $ProjectName-app\$ProjectName-rest ; mvn spring-boot:run"
Write-Host ""
Write-Host "    Swagger UI  ->  http://localhost:8080/swagger-ui/index.html"
Write-Host "    H2 Console  ->  http://localhost:8080/h2-console"
Write-Host ""
