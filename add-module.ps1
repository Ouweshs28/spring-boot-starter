# -------------------------------------------------------------------------------
# add-module.ps1  —  Add a new service module to this Spring Boot project
#
# Usage:
#   .\add-module.ps1 -ModuleName <name>
#
# Examples:
#   .\add-module.ps1 -ModuleName payment
#   .\add-module.ps1             # interactive — will prompt for module name
# -------------------------------------------------------------------------------
param(
    [Alias("m")][string]$ModuleName
)

$ErrorActionPreference = "Stop"

function Write-Info    { param($m) Write-Host $m -ForegroundColor Cyan   }
function Write-Success { param($m) Write-Host $m -ForegroundColor Green  }
function Write-Warn    { param($m) Write-Host $m -ForegroundColor Yellow }
function Fail          { param($m) Write-Host "ERROR: $m" -ForegroundColor Red; exit 1 }

$Utf8NoBom = New-Object System.Text.UTF8Encoding $false

Write-Host ""
Write-Info "+------------------------------------------+"
Write-Info "|        Add New Service Module            |"
Write-Info "+------------------------------------------+"
Write-Host ""

# ---- Validate project root ---------------------------------------------------
if (-not (Test-Path "pom.xml")) {
    Fail "pom.xml not found. Run this script from the project root directory."
}

# ---- Read project context from root pom.xml ----------------------------------
[xml]$rootPom = Get-Content "pom.xml"
$GroupId        = $rootPom.project.groupId
$RootArtifactId = $rootPom.project.artifactId   # e.g. template-parent

if ([string]::IsNullOrWhiteSpace($GroupId) -or [string]::IsNullOrWhiteSpace($RootArtifactId)) {
    Fail "Could not read groupId or artifactId from pom.xml."
}
if ($RootArtifactId -notmatch '-parent$') {
    Fail "Root artifactId '$RootArtifactId' does not end with '-parent'. Are you in the project root?"
}

$ProjectName = $RootArtifactId -replace '-parent$', ''   # e.g. template
$AppDir      = "$ProjectName-app"
$AppPomPath  = "$AppDir\pom.xml"
$GroupPath   = $GroupId -replace '\.', '\'   # e.g. com\project\template

if (-not (Test-Path $AppDir)) {
    Fail "App directory '$AppDir' not found. Are you in the project root?"
}
if (-not (Test-Path $AppPomPath)) {
    Fail "'$AppPomPath' not found."
}

Write-Host "  Detected project  :  $ProjectName"
Write-Host "  Detected group ID :  $GroupId"
Write-Host ""

# ---- Prompt if missing -------------------------------------------------------
if (-not $ModuleName) {
    $ModuleName = Read-Host "Module name (e.g. payment, notification, reporting)"
}

# ---- Validate module name ----------------------------------------------------
$ModuleName = $ModuleName.Trim().ToLower()

if ([string]::IsNullOrWhiteSpace($ModuleName)) {
    Fail "Module name cannot be empty."
}
if ($ModuleName -notmatch '^[a-z][a-z0-9-]*$') {
    Fail "Module name must start with a letter and contain only lowercase letters, digits, and hyphens."
}
if ($ModuleName.Length -lt 2) {
    Fail "Module name must be at least 2 characters long."
}
if ($ModuleName.Length -gt 50) {
    Fail "Module name must not exceed 50 characters."
}
if ($ModuleName -match '-$') {
    Fail "Module name must not end with a hyphen."
}
if ($ModuleName -match '--') {
    Fail "Module name must not contain consecutive hyphens."
}

$ReservedNames = @('app', 'parent', 'rest', 'persistence', 'service', 'image', 'core', 'common', 'web', 'api')
if ($ModuleName -in $ReservedNames) {
    Fail "Module name '$ModuleName' is reserved. Reserved names: $($ReservedNames -join ', ')."
}

$FullModuleName = "$ProjectName-$ModuleName"
$ModuleDir      = "$AppDir\$FullModuleName"

if (Test-Path $ModuleDir) {
    Fail "Directory '$ModuleDir' already exists. Choose a different module name or remove the directory first."
}

# ---- Check not already registered in app pom.xml ----------------------------
$AppPomText = [System.IO.File]::ReadAllText($AppPomPath, [System.Text.Encoding]::UTF8)
if ($AppPomText -match [regex]::Escape("<module>$FullModuleName</module>")) {
    Fail "Module '$FullModuleName' is already registered in $AppPomPath."
}

# ---- Confirm -----------------------------------------------------------------
Write-Host ""
Write-Host "  New module   :  $FullModuleName"
Write-Host "  Location     :  $ModuleDir"
Write-Host "  Package      :  $GroupId.$($ModuleName -replace '-','')"
Write-Host ""
$confirm = Read-Host "  Proceed? [Y/n]"
if ($confirm -ne '' -and $confirm -notmatch '^[Yy]$') {
    Write-Warn "  Aborted."
    exit 0
}

# ---- [1/3] Create directory structure ----------------------------------------
Write-Host ""
Write-Info "  [1/3] Creating directory structure..."

$JavaMainPath = "$ModuleDir\src\main\java\$GroupPath"
$JavaTestPath = "$ModuleDir\src\test\java\$GroupPath"
New-Item -ItemType Directory -Path $JavaMainPath -Force | Out-Null
New-Item -ItemType Directory -Path $JavaTestPath -Force | Out-Null

Write-Success "         + $ModuleDir\src\main\java\$GroupPath"
Write-Success "         + $ModuleDir\src\test\java\$GroupPath"

# ---- [2/3] Generate pom.xml --------------------------------------------------
Write-Info "  [2/3] Generating pom.xml..."

$PomContent = @"
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <parent>
        <artifactId>$AppDir</artifactId>
        <groupId>$GroupId</groupId>
        <version>1.0-SNAPSHOT</version>
    </parent>

    <artifactId>$FullModuleName</artifactId>

    <dependencies>
        <!-- Depend on persistence for entities / repositories -->
        <dependency>
            <groupId>$GroupId</groupId>
            <artifactId>$ProjectName-persistence</artifactId>
        </dependency>

        <!-- Mapping -->
        <dependency>
            <groupId>org.mapstruct</groupId>
            <artifactId>mapstruct</artifactId>
        </dependency>
        <dependency>
            <groupId>org.mapstruct</groupId>
            <artifactId>mapstruct-processor</artifactId>
        </dependency>

        <!-- JSON -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-json</artifactId>
        </dependency>

        <!-- Validation -->
        <dependency>
            <groupId>jakarta.validation</groupId>
            <artifactId>jakarta.validation-api</artifactId>
        </dependency>

        <!-- OpenAPI / Swagger annotations -->
        <dependency>
            <groupId>io.swagger.core.v3</groupId>
            <artifactId>swagger-annotations</artifactId>
        </dependency>

        <!-- Test -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>
</project>
"@

[System.IO.File]::WriteAllText("$ModuleDir\pom.xml", $PomContent, $Utf8NoBom)
Write-Success "         + $ModuleDir\pom.xml"

# ---- [3/3] Register in app pom.xml -------------------------------------------
Write-Info "  [3/3] Registering module in $AppPomPath..."

# Insert <module> before </modules>
$AppPomText = $AppPomText -replace '(?m)([ \t]*</modules>)', "`t`t<module>$FullModuleName</module>`r`n`$1"

# Insert <dependency> in dependencyManagement before <!-- Lombok -->
$NewDep  = "`t`t<dependency>`r`n"
$NewDep += "`t`t`t<groupId>$GroupId</groupId>`r`n"
$NewDep += "`t`t`t<artifactId>$FullModuleName</artifactId>`r`n"
$NewDep += "`t`t`t<version>`${project.version}</version>`r`n"
$NewDep += "`t`t</dependency>`r`n"

if ($AppPomText -match '<!-- Lombok -->') {
    $AppPomText = $AppPomText -replace '(?m)([ \t]*<!-- Lombok -->)', "$NewDep`t`t`$1"
} else {
    Write-Warn ""
    Write-Warn "  WARNING: Could not locate '<!-- Lombok -->' anchor in $AppPomPath."
    Write-Warn "  Please manually add the following inside <dependencyManagement><dependencies>:"
    Write-Warn ""
    Write-Warn "    <dependency>"
    Write-Warn "        <groupId>$GroupId</groupId>"
    Write-Warn "        <artifactId>$FullModuleName</artifactId>"
    Write-Warn "        <version>`${project.version}</version>"
    Write-Warn "    </dependency>"
    Write-Warn ""
}

[System.IO.File]::WriteAllText($AppPomPath, $AppPomText, $Utf8NoBom)
Write-Success "         + $AppPomPath  (modules + dependencyManagement updated)"

# ---- Done -------------------------------------------------------------------
Write-Host ""
Write-Success "  Module '$FullModuleName' created successfully!"
Write-Host ""
Write-Host "  Next steps:"
Write-Host ""
Write-Host "  1. Add your service interfaces and implementations under:"
Write-Host "       $ModuleDir\src\main\java\$GroupPath"
Write-Host ""
Write-Host "  2. To consume this module from $ProjectName-rest, add to"
Write-Host "     $AppDir\$ProjectName-rest\pom.xml:"
Write-Host ""
Write-Host "       <dependency>"
Write-Host "           <groupId>$GroupId</groupId>"
Write-Host "           <artifactId>$FullModuleName</artifactId>"
Write-Host "       </dependency>"
Write-Host ""
Write-Host "  3. To consume this module from another service module, add the"
Write-Host "     same block to that module's pom.xml."
Write-Host ""
Write-Host "  4. Rebuild the project:"
Write-Host "       mvn clean install"
Write-Host ""

