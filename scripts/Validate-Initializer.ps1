$ErrorActionPreference = 'Stop'

function Write-Step { param([string]$Message) Write-Host "==> $Message" -ForegroundColor Cyan }
function Fail-Test { param([string]$Message) throw $Message }

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )
    if (-not $Condition) { Fail-Test $Message }
}

function Assert-FileContains {
    param(
        [string]$Path,
        [string]$Expected
    )
    $content = [System.IO.File]::ReadAllText($Path)
    Assert-True ($content.Contains($Expected)) "Expected '$Expected' in $Path"
}

function Assert-FileNotContains {
    param(
        [string]$Path,
        [string]$Unexpected
    )
    $content = [System.IO.File]::ReadAllText($Path)
    Assert-True (-not $content.Contains($Unexpected)) "Did not expect '$Unexpected' in $Path"
}

function Assert-PathExists {
    param([string]$Path)
    Assert-True (Test-Path $Path) "Expected path to exist: $Path"
}

function Assert-PathMissing {
    param([string]$Path)
    Assert-True (-not (Test-Path $Path)) "Expected path to be absent: $Path"
}

function Copy-TreeFiltered {
    param(
        [string]$Source,
        [string]$Destination
    )
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    foreach ($item in Get-ChildItem -LiteralPath $Source -Force) {
        if ($item.Name -in @('.git', '.idea', '.build-tools', '.test-work')) { continue }
        $targetPath = Join-Path $Destination $item.Name
        if ($item.PSIsContainer) {
            if ($item.Name -eq 'target') { continue }
            Copy-TreeFiltered -Source $item.FullName -Destination $targetPath
        } else {
            Copy-Item -LiteralPath $item.FullName -Destination $targetPath -Force
        }
    }
}

function Resolve-Java {
    if (-not [string]::IsNullOrWhiteSpace($env:JAVA_HOME)) {
        $javaExe = Join-Path $env:JAVA_HOME 'bin\java.exe'
        if (-not (Test-Path $javaExe)) {
            Fail-Test "JAVA_HOME is set to '$env:JAVA_HOME', but '$javaExe' was not found. Set JAVA_HOME to a valid JDK or add Java to PATH."
        }
        return $javaExe
    }

    $javaCommand = Get-Command java.exe -ErrorAction SilentlyContinue
    if ($null -eq $javaCommand) {
        $javaCommand = Get-Command java -ErrorAction SilentlyContinue
    }
    if ($null -eq $javaCommand) {
        Fail-Test 'Java was not found. Set JAVA_HOME to a JDK or add java.exe to PATH before running validation.'
    }
    return $javaCommand.Source
}

function Invoke-MavenVerify {
    param([string]$WorkingDirectory)
    $wrapperPath = Join-Path $WorkingDirectory 'mvnw.cmd'
    Assert-PathExists $wrapperPath
    Push-Location $WorkingDirectory
    try {
        & $wrapperPath clean verify --no-transfer-progress
        if ($LASTEXITCODE -ne 0) {
            Fail-Test "Maven verify failed in $WorkingDirectory"
        }
    } finally {
        Pop-Location
    }
}

function Assert-GitClean {
    param([string]$WorkingDirectory)
    Push-Location $WorkingDirectory
    try {
        $status = git --no-pager status --short
        Assert-True ([string]::IsNullOrWhiteSpace($status)) "Expected clean git status in $WorkingDirectory. Found:`n$status"
    } finally {
        Pop-Location
    }
}

function New-WorkingCopy {
    param(
        [string]$Root,
        [string]$Name
    )
    $copyDir = Join-Path $Root $Name
    if (Test-Path $copyDir) { Remove-Item -Recurse -Force $copyDir }
    Copy-TreeFiltered -Source $repositoryRoot -Destination $copyDir
    return $copyDir
}

function Invoke-PowerShellInit {
    param(
        [string]$WorkingDirectory,
        [string[]]$Arguments,
        [string]$InputText = ''
    )
    Push-Location $WorkingDirectory
    try {
        if ([string]::IsNullOrEmpty($InputText)) {
            & powershell -NoProfile -ExecutionPolicy Bypass -File .\init.ps1 @Arguments
        } else {
            $InputText | & powershell -NoProfile -ExecutionPolicy Bypass -File .\init.ps1 @Arguments
        }
        if ($LASTEXITCODE -ne 0) {
            Fail-Test "PowerShell init failed in $WorkingDirectory"
        }
    } finally {
        Pop-Location
    }
}

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$testWorkRoot = Join-Path $repositoryRoot '.test-work'
$validationRoot = Join-Path $testWorkRoot 'validation'
if (Test-Path $validationRoot) { Remove-Item -Recurse -Force $validationRoot }
if ((Test-Path $testWorkRoot) -and @(Get-ChildItem -Force $testWorkRoot).Count -eq 0) {
    Remove-Item -Force $testWorkRoot
}
$javaExe = Resolve-Java
Write-Step "Using Java: $javaExe"
& $javaExe -version
if ($LASTEXITCODE -ne 0) {
    Fail-Test "Unable to run Java at '$javaExe'."
}

New-Item -ItemType Directory -Path $validationRoot -Force | Out-Null

try {
    Write-Step 'Scenario 1: PowerShell initializer interactive defaults'
    $psDefaultProject = New-WorkingCopy -Root $validationRoot -Name 'ps-default'
    Invoke-PowerShellInit -WorkingDirectory $psDefaultProject -Arguments @('-ProjectName', 'ps-default-app', '-PackageName', 'com.example.psdefault', '-ExtraServiceModules', '0') -InputText "yes`nflyway`nyes`n"
    Assert-FileContains (Join-Path $psDefaultProject 'ps-default-app-app\ps-default-app-persistence\pom.xml') 'spring-boot-starter-flyway'
    Assert-FileContains (Join-Path $psDefaultProject 'ps-default-app-app\ps-default-app-persistence\pom.xml') 'blaze-persistence-core-api-jakarta'
    Assert-PathExists (Join-Path $psDefaultProject 'ps-default-app-app\ps-default-app-rest\src\main\resources\db\migration\V1__init.sql')
    Assert-PathMissing (Join-Path $psDefaultProject 'init.ps1')
    Assert-PathMissing (Join-Path $psDefaultProject 'init.sh')
    Assert-GitClean $psDefaultProject
    Invoke-MavenVerify $psDefaultProject

    Write-Step 'Scenario 2: PowerShell initializer with Liquibase and Blaze disabled'
    $psLiquibaseProject = New-WorkingCopy -Root $validationRoot -Name 'ps-liquibase'
    Invoke-PowerShellInit -WorkingDirectory $psLiquibaseProject -Arguments @('-ProjectName', 'ps-liq-app', '-PackageName', 'com.example.psliq', '-MigrationTool', 'liquibase', '-SpringDataJpa', 'true', '-BlazePersistence', 'false', '-ExtraServiceModules', '0')
    Assert-FileContains (Join-Path $psLiquibaseProject 'ps-liq-app-app\ps-liq-app-persistence\pom.xml') 'liquibase-core'
    Assert-FileNotContains (Join-Path $psLiquibaseProject 'ps-liq-app-app\ps-liq-app-persistence\pom.xml') 'spring-boot-starter-flyway'
    Assert-FileNotContains (Join-Path $psLiquibaseProject 'ps-liq-app-app\ps-liq-app-persistence\pom.xml') 'blaze-persistence-core-api-jakarta'
    Assert-PathExists (Join-Path $psLiquibaseProject 'ps-liq-app-app\ps-liq-app-rest\src\main\resources\db\changelog\db.changelog-master.yaml')
    Assert-PathMissing (Join-Path $psLiquibaseProject 'ps-liq-app-app\ps-liq-app-rest\src\main\java\com\example\psliq\config\BlazePersistenceConfig.java')
    Assert-GitClean $psLiquibaseProject
    Invoke-MavenVerify $psLiquibaseProject

    Write-Step 'Scenario 3: PowerShell initializer with JPA disabled'
    $psNoJpaProject = New-WorkingCopy -Root $validationRoot -Name 'ps-no-jpa'
    Invoke-PowerShellInit -WorkingDirectory $psNoJpaProject -Arguments @('-ProjectName', 'ps-no-jpa', '-PackageName', 'com.example.psnojpa', '-SpringDataJpa', 'false', '-ExtraServiceModules', '0')
    Assert-FileNotContains (Join-Path $psNoJpaProject 'ps-no-jpa-app\ps-no-jpa-persistence\pom.xml') 'spring-boot-starter-data-jpa'
    Assert-PathMissing (Join-Path $psNoJpaProject 'ps-no-jpa-app\ps-no-jpa-rest\src\main\resources\db')
    Assert-PathMissing (Join-Path $psNoJpaProject 'ps-no-jpa-app\ps-no-jpa-rest\src\main\java\com\example\psnojpa\config\TemplateConfig.java')
    Assert-FileNotContains (Join-Path $psNoJpaProject 'ps-no-jpa-app\ps-no-jpa-rest\src\main\resources\application.yaml') 'datasource:'
    Assert-GitClean $psNoJpaProject
    Invoke-MavenVerify $psNoJpaProject

    Write-Step 'Scenario 4: Invalid explicit JPA-disabled combination is rejected'
    $invalidCopy = New-WorkingCopy -Root $validationRoot -Name 'invalid-jpa-off'
    Push-Location $invalidCopy
    try {
        & powershell -NoProfile -ExecutionPolicy Bypass -File .\init.ps1 -ProjectName invalid-app -PackageName com.example.invalid -SpringDataJpa false -MigrationTool flyway -ExtraServiceModules 0
        if ($LASTEXITCODE -eq 0) {
            Fail-Test 'Expected init.ps1 to reject JPA disabled + Flyway'
        }
    } finally {
        Pop-Location
    }

    Write-Step 'Scenario 5: PowerShell add-module script on initialized project'
    $psAddModuleProject = New-WorkingCopy -Root $validationRoot -Name 'ps-addmod'
    Invoke-PowerShellInit -WorkingDirectory $psAddModuleProject -Arguments @('-ProjectName', 'ps-mod-app', '-PackageName', 'com.example.psmod', '-ExtraServiceModules', '0') -InputText "yes`nflyway`nyes`n"
    Push-Location $psAddModuleProject
    try {
        & powershell -NoProfile -ExecutionPolicy Bypass -File .\add-module.ps1 -ModuleName 'billing' -Yes
        if ($LASTEXITCODE -ne 0) {
            Fail-Test "PowerShell add-module failed in $psAddModuleProject"
        }
    } finally {
        Pop-Location
    }
    Assert-PathExists (Join-Path $psAddModuleProject 'ps-mod-app-app\ps-mod-app-billing\pom.xml')
    Assert-PathExists (Join-Path $psAddModuleProject 'ps-mod-app-app\ps-mod-app-billing\src\main\java\com\example\psmod')
    Assert-PathExists (Join-Path $psAddModuleProject 'ps-mod-app-app\ps-mod-app-billing\src\test\java\com\example\psmod')
    Assert-FileContains (Join-Path $psAddModuleProject 'ps-mod-app-app\pom.xml') '<module>ps-mod-app-billing</module>'
    Assert-FileContains (Join-Path $psAddModuleProject 'ps-mod-app-app\pom.xml') '<artifactId>ps-mod-app-billing</artifactId>'
    Assert-FileContains (Join-Path $psAddModuleProject 'ps-mod-app-app\ps-mod-app-image\src\main\resources\docker\app\Dockerfile') 'COPY ps-mod-app-app/ps-mod-app-billing/pom.xml'
    Push-Location $psAddModuleProject
    try {
        git add -A
        git commit -m "Add billing module"
    } finally {
        Pop-Location
    }
    Assert-GitClean $psAddModuleProject
    Invoke-MavenVerify $psAddModuleProject

    Write-Step 'Scenario 6: PowerShell bootstrap script'
    $tempOrigin = Join-Path $validationRoot 'temp-git-origin'
    Copy-TreeFiltered -Source $repositoryRoot -Destination $tempOrigin
    Push-Location $tempOrigin
    try {
        git init -q
        git config user.email "test@example.com"
        git config user.name "Test"
        git add -A
        git commit -q -m "test initial commit"
    } finally {
        Pop-Location
    }

    $psBootstrapRoot = Join-Path $validationRoot 'ps-bootstrap-root'
    New-Item -ItemType Directory -Path $psBootstrapRoot -Force | Out-Null
    Push-Location $psBootstrapRoot
    try {
        $env:REPO_URL = $tempOrigin
        & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repositoryRoot 'bootstrap.ps1') -ProjectName 'ps-boot-app' -PackageName 'com.example.psboot' -MigrationTool 'flyway' -SpringDataJpa 'true' -BlazePersistence 'true' -ExtraServiceModules 0
        if ($LASTEXITCODE -ne 0) {
            Fail-Test 'PowerShell bootstrap failed'
        }
    } finally {
        $env:REPO_URL = $null
        Pop-Location
    }
    $psBootProject = Join-Path $psBootstrapRoot 'ps-boot-app'
    Assert-PathExists (Join-Path $psBootProject 'ps-boot-app-app\ps-boot-app-rest\pom.xml')
    Assert-PathMissing (Join-Path $psBootProject 'init.ps1')
    Assert-PathMissing (Join-Path $psBootProject 'init.sh')
    Assert-PathMissing (Join-Path $psBootProject 'bootstrap.ps1')
    Assert-PathMissing (Join-Path $psBootProject 'bootstrap.sh')
    Assert-GitClean $psBootProject

    Write-Step 'All PowerShell initializer validation scenarios passed.'
} finally {
    if (Test-Path $validationRoot) {
        Remove-Item -Recurse -Force $validationRoot
    }
    if ((Test-Path $testWorkRoot) -and @(Get-ChildItem -Force $testWorkRoot).Count -eq 0) {
        Remove-Item -Force $testWorkRoot
    }
}
