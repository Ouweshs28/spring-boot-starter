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

function Write-Info    { param($m) Write-Host $m -ForegroundColor Cyan }
function Write-Success { param($m) Write-Host $m -ForegroundColor Green }
function Write-Warn    { param($m) Write-Host $m -ForegroundColor Yellow }
function Fail          { param($m) Write-Host "ERROR: $m" -ForegroundColor Red; exit 1 }

function Show-Usage {
    @"
Usage: .\init.ps1 [options]
  -ProjectName/-p          Lowercase, hyphenated name (e.g. my-app)
  -PackageName/-n          Java base package (e.g. com.example.myapp)
  -MigrationTool/-m        flyway | liquibase | none
  -SpringDataJpa/-j        true | false
  -BlazePersistence/-b     true | false
  -ExtraServiceModules/-s  Number of extra service modules to scaffold
  -Help                    Show this help message

Defaults:
  Spring Data JPA   enabled
  Blaze-Persistence enabled
  Migration tool    flyway

Compatibility:
  When Spring Data JPA is disabled, Blaze-Persistence is forced off and
  migration tooling is forced to 'none'. Explicitly requesting Blaze or
  Flyway/Liquibase while JPA is disabled is rejected.
"@ | Write-Host
}

function Normalize-Bool {
    param([string]$Value)
    switch ($Value.Trim().ToLowerInvariant()) {
        { $_ -in @('y', 'yes', 'true', '1', 'on', 'enable', 'enabled') } { return 'true' }
        { $_ -in @('n', 'no', 'false', '0', 'off', 'disable', 'disabled') } { return 'false' }
        default { throw "Invalid boolean value '$Value'." }
    }
}

function Normalize-MigrationTool {
    param([string]$Value)
    $normalized = $Value.Trim().ToLowerInvariant()
    if ($normalized -notin @('flyway', 'liquibase', 'none')) {
        throw "Invalid migration tool '$Value'."
    }
    return $normalized
}

function Read-YesNoDefaultYes {
    param([string]$Prompt)
    while ($true) {
        $response = Read-Host "$Prompt [Y/n]"
        if ([string]::IsNullOrWhiteSpace($response)) {
            return 'true'
        }
        try {
            return Normalize-Bool $response
        } catch {
            Write-Warn 'Please answer yes or no.'
        }
    }
}

function Read-MigrationTool {
    while ($true) {
        $response = Read-Host 'Migration tool [flyway/liquibase/none] (default: flyway)'
        if ([string]::IsNullOrWhiteSpace($response)) {
            return 'flyway'
        }
        try {
            return Normalize-MigrationTool $response
        } catch {
            Write-Warn 'Please choose flyway, liquibase, or none.'
        }
    }
}

function Expand-Template {
    param(
        [string]$Template,
        [hashtable]$Values
    )
    $expanded = $Template
    foreach ($entry in $Values.GetEnumerator()) {
        $expanded = $expanded.Replace("__$($entry.Key)__", [string]$entry.Value)
    }
    return $expanded.TrimStart("`r", "`n")
}

if ($Help) {
    Show-Usage
    exit 0
}

$Utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.Directory]::SetCurrentDirectory((Get-Location).Path)

if (-not $ProjectName) { $ProjectName = Read-Host 'Project name (e.g. my-app)' }
if (-not $PackageName) { $PackageName = Read-Host 'Base package  (e.g. com.example.myapp)' }

if ($ProjectName -notmatch '^[a-z][a-z0-9-]*$') {
    Fail 'Project name must be lowercase and contain only letters, digits, and hyphens.'
}
if ($PackageName -notmatch '^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*)*$') {
    Fail 'Package name must be a valid Java package (e.g. com.example.myapp).'
}

$jpaExplicit = $PSBoundParameters.ContainsKey('SpringDataJpa')
$blazeExplicit = $PSBoundParameters.ContainsKey('BlazePersistence')
$migrationExplicit = $PSBoundParameters.ContainsKey('MigrationTool')
$moduleCountExplicit = $PSBoundParameters.ContainsKey('ExtraServiceModules')

try {
    if ($jpaExplicit) {
        $SpringDataJpa = Normalize-Bool $SpringDataJpa
    } else {
        $SpringDataJpa = Read-YesNoDefaultYes 'Enable Spring Data JPA?'
    }

    if ($SpringDataJpa -eq 'true') {
        if ($migrationExplicit) {
            $MigrationTool = Normalize-MigrationTool $MigrationTool
        } else {
            $MigrationTool = Read-MigrationTool
        }

        if ($blazeExplicit) {
            $BlazePersistence = Normalize-Bool $BlazePersistence
        } else {
            $BlazePersistence = Read-YesNoDefaultYes 'Enable Blaze-Persistence?'
        }
    } else {
        if ($blazeExplicit) {
            $BlazePersistence = Normalize-Bool $BlazePersistence
            if ($BlazePersistence -ne 'false') {
                Fail 'Blaze-Persistence cannot be enabled when Spring Data JPA is disabled.'
            }
        } else {
            $BlazePersistence = 'false'
            Write-Info 'Spring Data JPA disabled -> Blaze-Persistence will also be disabled.'
        }

        if ($migrationExplicit) {
            $MigrationTool = Normalize-MigrationTool $MigrationTool
            if ($MigrationTool -ne 'none') {
                Fail 'Migration tooling cannot be enabled when Spring Data JPA is disabled.'
            }
        } else {
            $MigrationTool = 'none'
            Write-Info 'Spring Data JPA disabled -> migration tooling will also be disabled.'
        }
    }
} catch {
    Fail $_.Exception.Message
}

$OldGroup = 'com.project.template'
$OldPath = 'com/project/template'
$NewPath = $PackageName -replace '\.', '/'
$ProjectPascal = ($ProjectName -split '-' | ForEach-Object { $_.Substring(0, 1).ToUpper() + $_.Substring(1) }) -join ''
$AppDir = "${ProjectName}-app"
$PersistenceDir = "$AppDir\${ProjectName}-persistence"
$ServiceDir = "$AppDir\${ProjectName}-service"
$RestDir = "$AppDir\${ProjectName}-rest"
$NewPathWindows = $NewPath -replace '/', '\'

function Write-Utf8File {
    param(
        [string]$Path,
        [string]$Content
    )
    $parent = Split-Path $Path -Parent
    if ($parent -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($Path, $Content, $Utf8NoBom)
}

function Write-TemplateFile {
    param(
        [string]$Path,
        [string]$Template,
        [hashtable]$Values
    )
    Write-Utf8File $Path (Expand-Template -Template $Template -Values $Values)
}

function Remove-PathIfExists {
    param([string]$Path)
    if (Test-Path $Path) {
        Remove-Item -Recurse -Force $Path
    }
}

function Get-TemplateValues {
    param([hashtable]$Extra = @{})
    $values = @{
        PROJECT_NAME = $ProjectName
        PACKAGE_NAME = $PackageName
        PROJECT_PASCAL = $ProjectPascal
    }
    foreach ($entry in $Extra.GetEnumerator()) {
        $values[$entry.Key] = $entry.Value
    }
    return $values
}

function Configure-AppPom {
    $blazeDependencyManagement = ''
    $blazeAnnotationProcessor = ''
    if ($BlazePersistence -eq 'true') {
        $blazeDependencyManagement = @'
            <!-- Blaze-Persistence BOM (covers core + entity-view artifacts) -->
            <dependency>
                <groupId>com.blazebit</groupId>
                <artifactId>blaze-persistence-bom</artifactId>
                <version>${blaze-persistence.version}</version>
                <type>pom</type>
                <scope>import</scope>
            </dependency>
            <!-- Blaze integration artifacts (not in BOM) -->
            <dependency>
                <groupId>com.blazebit</groupId>
                <artifactId>blaze-persistence-integration-hibernate-7.2</artifactId>
                <version>${blaze-persistence.version}</version>
            </dependency>
            <dependency>
                <groupId>com.blazebit</groupId>
                <artifactId>blaze-persistence-integration-entity-view-spring-6.0</artifactId>
                <version>${blaze-persistence.version}</version>
            </dependency>
            <dependency>
                <groupId>com.blazebit</groupId>
                <artifactId>blaze-persistence-entity-view-processor-jakarta</artifactId>
                <version>${blaze-persistence.version}</version>
            </dependency>
'@
        $blazeAnnotationProcessor = @'
                        <path>
                            <groupId>com.blazebit</groupId>
                            <artifactId>blaze-persistence-entity-view-processor-jakarta</artifactId>
                            <version>${blaze-persistence.version}</version>
                        </path>
'@
    }

    $template = @'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <parent>
        <artifactId>__PROJECT_NAME__-parent</artifactId>
        <groupId>__PACKAGE_NAME__</groupId>
        <version>1.0-SNAPSHOT</version>
    </parent>

    <artifactId>__PROJECT_NAME__-app</artifactId>
    <packaging>pom</packaging>

    <properties>
        <build.final-name>__PROJECT_PASCAL__</build.final-name>
        <maven.compiler.release>21</maven.compiler.release>
        <java.version>21</java.version>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
        <project.reporting.outputEncoding>UTF-8</project.reporting.outputEncoding>
        <org.openapi-generator-maven-plugin.version>7.21.0</org.openapi-generator-maven-plugin.version>
        <org.projectlombok.version>1.18.46</org.projectlombok.version>
        <org.mapstruct.version>1.6.3</org.mapstruct.version>
        <blaze-persistence.version>1.6.18</blaze-persistence.version>
        <swagger-annotations.version>2.2.45</swagger-annotations.version>
        <springdoc-openapi-starter-webmvc-ui.version>3.0.3</springdoc-openapi-starter-webmvc-ui.version>
        <lombok-mapstruct-binding.version>0.2.0</lombok-mapstruct-binding.version>
        <maven-compiler-plugin.version>3.15.0</maven-compiler-plugin.version>
        <exec-maven-plugin.version>3.6.3</exec-maven-plugin.version>
    </properties>

    <modules>
        <module>__PROJECT_NAME__-persistence</module>
        <module>__PROJECT_NAME__-service</module>
        <module>__PROJECT_NAME__-rest</module>
        <module>__PROJECT_NAME__-image</module>
    </modules>

    <dependencyManagement>
        <dependencies>
            <dependency>
                <groupId>__PACKAGE_NAME__</groupId>
                <artifactId>__PROJECT_NAME__-persistence</artifactId>
                <version>${project.version}</version>
            </dependency>
            <dependency>
                <groupId>__PACKAGE_NAME__</groupId>
                <artifactId>__PROJECT_NAME__-service</artifactId>
                <version>${project.version}</version>
            </dependency>
__BLAZE_DEPENDENCY_MANAGEMENT__            <dependency>
                <groupId>org.mapstruct</groupId>
                <artifactId>mapstruct</artifactId>
                <version>${org.mapstruct.version}</version>
            </dependency>
            <dependency>
                <groupId>org.mapstruct</groupId>
                <artifactId>mapstruct-processor</artifactId>
                <version>${org.mapstruct.version}</version>
            </dependency>
            <dependency>
                <groupId>io.swagger.core.v3</groupId>
                <artifactId>swagger-annotations-jakarta</artifactId>
                <version>${swagger-annotations.version}</version>
            </dependency>
            <dependency>
                <groupId>org.springdoc</groupId>
                <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>
                <version>${springdoc-openapi-starter-webmvc-ui.version}</version>
            </dependency>
        </dependencies>
    </dependencyManagement>

    <dependencies>
        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
            <scope>provided</scope>
        </dependency>
    </dependencies>

    <build>
        <resources>
            <resource>
                <directory>src/main/resources</directory>
            </resource>
        </resources>

        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-compiler-plugin</artifactId>
                <configuration>
                    <annotationProcessorPaths>
                        <path>
                            <groupId>org.projectlombok</groupId>
                            <artifactId>lombok</artifactId>
                            <version>${org.projectlombok.version}</version>
                        </path>
                        <path>
                            <groupId>org.mapstruct</groupId>
                            <artifactId>mapstruct-processor</artifactId>
                            <version>${org.mapstruct.version}</version>
                        </path>
                        <path>
                            <groupId>org.projectlombok</groupId>
                            <artifactId>lombok-mapstruct-binding</artifactId>
                            <version>${lombok-mapstruct-binding.version}</version>
                        </path>
__BLAZE_ANNOTATION_PROCESSOR__                    </annotationProcessorPaths>
                </configuration>
            </plugin>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-resources-plugin</artifactId>
                <configuration>
                    <delimiters>
                        <delimiter>@</delimiter>
                    </delimiters>
                    <useDefaultDelimiters>false</useDefaultDelimiters>
                </configuration>
            </plugin>
        </plugins>

        <pluginManagement>
            <plugins>
                <plugin>
                    <groupId>org.apache.maven.plugins</groupId>
                    <artifactId>maven-compiler-plugin</artifactId>
                    <version>${maven-compiler-plugin.version}</version>
                    <configuration>
                        <annotationProcessorPaths>
                            <path>
                                <groupId>org.projectlombok</groupId>
                                <artifactId>lombok</artifactId>
                            </path>
                        </annotationProcessorPaths>
                    </configuration>
                </plugin>
                <plugin>
                    <groupId>org.codehaus.mojo</groupId>
                    <artifactId>exec-maven-plugin</artifactId>
                    <version>${exec-maven-plugin.version}</version>
                </plugin>
                <plugin>
                    <groupId>org.openapitools</groupId>
                    <artifactId>openapi-generator-maven-plugin</artifactId>
                    <version>${org.openapi-generator-maven-plugin.version}</version>
                    <executions>
                        <execution>
                            <goals>
                                <goal>generate</goal>
                            </goals>
                            <configuration>
                                <apiPackage>__PACKAGE_NAME__.api</apiPackage>
                                <generateApis>false</generateApis>
                                <generateApiTests>false</generateApiTests>
                                <generateApiDocumentation>false</generateApiDocumentation>
                                <generatorName>spring</generatorName>
                                <inputSpec>
                                    ${project.basedir}/../__PROJECT_NAME__-rest/src/main/resources/static/openapi.yaml
                                </inputSpec>
                                <modelPackage>__PACKAGE_NAME__.model</modelPackage>
                                <generateModels>false</generateModels>
                                <generateModelTests>false</generateModelTests>
                                <generateModelDocumentation>false</generateModelDocumentation>
                                <generateSupportingFiles>false</generateSupportingFiles>
                                <verbose>false</verbose>
                                <configOptions>
                                    <dateLibrary>java8</dateLibrary>
                                    <interfaceOnly>true</interfaceOnly>
                                    <openApiNullable>false</openApiNullable>
                                    <useBeanValidation>true</useBeanValidation>
                                    <useJakartaEe>true</useJakartaEe>
                                    <useSpringBoot4>true</useSpringBoot4>
                                    <useJackson3>true</useJackson3>
                                </configOptions>
                            </configuration>
                        </execution>
                    </executions>
                </plugin>
            </plugins>
        </pluginManagement>
    </build>
</project>
'@

    Write-TemplateFile -Path "$AppDir\pom.xml" -Template $template -Values (Get-TemplateValues @{
            BLAZE_DEPENDENCY_MANAGEMENT = $blazeDependencyManagement
            BLAZE_ANNOTATION_PROCESSOR = $blazeAnnotationProcessor
        })
}

function Configure-PersistencePom {
    $dependencies = ''
    if ($SpringDataJpa -eq 'true') {
        $dependencies = @'
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-jpa</artifactId>
        </dependency>
        <dependency>
            <groupId>com.h2database</groupId>
            <artifactId>h2</artifactId>
            <scope>runtime</scope>
        </dependency>
'@
        if ($BlazePersistence -eq 'true') {
            $dependencies += @'
        <dependency>
            <groupId>com.blazebit</groupId>
            <artifactId>blaze-persistence-core-api-jakarta</artifactId>
        </dependency>
        <dependency>
            <groupId>com.blazebit</groupId>
            <artifactId>blaze-persistence-core-impl-jakarta</artifactId>
            <scope>runtime</scope>
        </dependency>
        <dependency>
            <groupId>com.blazebit</groupId>
            <artifactId>blaze-persistence-entity-view-api-jakarta</artifactId>
        </dependency>
        <dependency>
            <groupId>com.blazebit</groupId>
            <artifactId>blaze-persistence-entity-view-impl-jakarta</artifactId>
            <scope>runtime</scope>
        </dependency>
        <dependency>
            <groupId>com.blazebit</groupId>
            <artifactId>blaze-persistence-integration-hibernate-7.2</artifactId>
            <scope>runtime</scope>
        </dependency>
        <dependency>
            <groupId>com.blazebit</groupId>
            <artifactId>blaze-persistence-integration-entity-view-spring-6.0</artifactId>
        </dependency>
        <dependency>
            <groupId>com.blazebit</groupId>
            <artifactId>blaze-persistence-entity-view-processor-jakarta</artifactId>
            <scope>provided</scope>
        </dependency>
'@
        }
        switch ($MigrationTool) {
            'flyway' {
                $dependencies += @'
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-flyway</artifactId>
        </dependency>
'@
            }
            'liquibase' {
                $dependencies += @'
        <dependency>
            <groupId>org.liquibase</groupId>
            <artifactId>liquibase-core</artifactId>
        </dependency>
'@
            }
        }
    }

    $dependenciesBlock = if ([string]::IsNullOrWhiteSpace($dependencies)) { '' } else { "`r`n    <dependencies>`r`n$dependencies    </dependencies>`r`n" }
    $template = @'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <parent>
        <artifactId>__PROJECT_NAME__-app</artifactId>
        <groupId>__PACKAGE_NAME__</groupId>
        <version>1.0-SNAPSHOT</version>
    </parent>

    <artifactId>__PROJECT_NAME__-persistence</artifactId>__DEPENDENCIES_BLOCK__</project>
'@
    Write-TemplateFile -Path "$PersistenceDir\pom.xml" -Template $template -Values (Get-TemplateValues @{
            DEPENDENCIES_BLOCK = $dependenciesBlock
        })
}

function Configure-ServicePom {
    $template = @'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <parent>
        <artifactId>__PROJECT_NAME__-app</artifactId>
        <groupId>__PACKAGE_NAME__</groupId>
        <version>1.0-SNAPSHOT</version>
    </parent>

    <artifactId>__PROJECT_NAME__-service</artifactId>

    <dependencies>
        <dependency>
            <groupId>__PACKAGE_NAME__</groupId>
            <artifactId>__PROJECT_NAME__-persistence</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework</groupId>
            <artifactId>spring-context</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.data</groupId>
            <artifactId>spring-data-commons</artifactId>
        </dependency>
        <dependency>
            <groupId>org.mapstruct</groupId>
            <artifactId>mapstruct</artifactId>
        </dependency>
        <dependency>
            <groupId>org.mapstruct</groupId>
            <artifactId>mapstruct-processor</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-json</artifactId>
        </dependency>
        <dependency>
            <groupId>jakarta.validation</groupId>
            <artifactId>jakarta.validation-api</artifactId>
        </dependency>
        <dependency>
            <groupId>io.swagger.core.v3</groupId>
            <artifactId>swagger-annotations-jakarta</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.openapitools</groupId>
                <artifactId>openapi-generator-maven-plugin</artifactId>
                <executions>
                    <execution>
                        <configuration>
                            <generateApis>false</generateApis>
                            <generateModels>true</generateModels>
                        </configuration>
                    </execution>
                </executions>
            </plugin>
        </plugins>
    </build>
</project>
'@
    Write-TemplateFile -Path "$ServiceDir\pom.xml" -Template $template -Values (Get-TemplateValues)
}

function Configure-ApplicationYaml {
    if ($SpringDataJpa -eq 'true') {
        $ddlAuto = if ($MigrationTool -eq 'none') { 'create-drop' } else { 'validate' }
        $migrationBlock = switch ($MigrationTool) {
            'flyway' {
@'
  flyway:
    enabled: true
    locations: classpath:db/migration
'@
            }
            'liquibase' {
@'
  liquibase:
    change-log: classpath:db/changelog/db.changelog-master.yaml
'@
            }
            default { '' }
        }
        $template = @'
spring:
  datasource:
    url: jdbc:h2:mem:__PROJECT_NAME__;DB_CLOSE_DELAY=-1;DB_CLOSE_ON_EXIT=FALSE
    driver-class-name: org.h2.Driver
    username: sa
    password:
  h2:
    console:
      enabled: true
      path: /h2-console
  jpa:
    hibernate:
      ddl-auto: __DDL_AUTO__
    show-sql: true
    database-platform: org.hibernate.dialect.H2Dialect
__MIGRATION_BLOCK__  profiles:
    active: dev
'@
        Write-TemplateFile -Path "$RestDir\src\main\resources\application.yaml" -Template $template -Values (Get-TemplateValues @{
                DDL_AUTO = $ddlAuto
                MIGRATION_BLOCK = $migrationBlock
            })
    } else {
        Write-Utf8File "$RestDir\src\main\resources\application.yaml" @'
spring:
  profiles:
    active: dev
'@
    }
}

function Configure-ApplicationDevYaml {
    $migrationLogger = if ($SpringDataJpa -eq 'true') {
        switch ($MigrationTool) {
            'flyway' { '    org.flywaydb: DEBUG' }
            'liquibase' { '    liquibase: INFO' }
            default { '' }
        }
    } else { '' }
    $template = @'
springdoc:
  api-docs:
    enabled: false
  swagger-ui:
    url: openapi.yaml
logging:
  level:
    org.springframework.web: DEBUG
__MIGRATION_LOGGER__
'@
    Write-TemplateFile -Path "$RestDir\src\main\resources\application-dev.yaml" -Template $template -Values @{
        MIGRATION_LOGGER = if ([string]::IsNullOrWhiteSpace($migrationLogger)) { '' } else { "$migrationLogger`r`n" }
    }
}

function Configure-MigrationFiles {
    $dbDir = "$RestDir\src\main\resources\db"
    switch ($MigrationTool) {
        'flyway' {
            Remove-PathIfExists "$dbDir\changelog"
            Write-Utf8File "$dbDir\migration\V1__init.sql" @'
-- ============================================================
-- V1 - Initial schema
-- ============================================================

CREATE TABLE next_stock_user
(
    id         BIGINT AUTO_INCREMENT NOT NULL,
    username   VARCHAR(255),
    email      VARCHAR(255),
    first_name VARCHAR(255),
    last_name  VARCHAR(255),
    gender     VARCHAR(50),
    created_on TIMESTAMP,
    updated_on TIMESTAMP,
    CONSTRAINT pk_next_stock_user PRIMARY KEY (id)
);
'@
        }
        'liquibase' {
            Remove-PathIfExists "$dbDir\migration"
            Write-Utf8File "$dbDir\changelog\db.changelog-master.yaml" @'
databaseChangeLog:
  - changeSet:
      id: 1
      author: spring-boot-starter
      changes:
        - createTable:
            tableName: next_stock_user
            columns:
              - column:
                  name: id
                  type: BIGINT
                  autoIncrement: true
                  constraints:
                    nullable: false
                    primaryKey: true
              - column:
                  name: username
                  type: VARCHAR(255)
              - column:
                  name: email
                  type: VARCHAR(255)
              - column:
                  name: first_name
                  type: VARCHAR(255)
              - column:
                  name: last_name
                  type: VARCHAR(255)
              - column:
                  name: gender
                  type: VARCHAR(50)
              - column:
                  name: created_on
                  type: TIMESTAMP
              - column:
                  name: updated_on
                  type: TIMESTAMP
'@
        }
        'none' {
            Remove-PathIfExists $dbDir
        }
    }
}

function Write-JpaCommonSources {
    $serviceJavaDir = "$ServiceDir\src\main\java\$NewPathWindows"
    $persistenceJavaDir = "$PersistenceDir\src\main\java\$NewPathWindows\persistence"
    $inheritance = if ($BlazePersistence -eq 'true') { ', UserRepositoryCustom' } else { '' }

    Write-TemplateFile -Path "$serviceJavaDir\service\UserService.java" -Template @'
package __PACKAGE_NAME__.service;

import __PACKAGE_NAME__.model.Gender;
import __PACKAGE_NAME__.model.PageResponse;
import __PACKAGE_NAME__.model.UserCreateUpdateRequest;
import __PACKAGE_NAME__.model.UserResponse;
import org.springframework.data.domain.PageRequest;

public interface UserService {

    Long createUser(UserCreateUpdateRequest createUserRequest);

    void updateUser(UserCreateUpdateRequest userUpdateRequest);

    void deleteUser(Long userId);

    UserResponse findUserById(Long userId);

    PageResponse findAllUsers(String criteria, Gender gender, PageRequest pageRequest);
}
'@ -Values (Get-TemplateValues)

    Write-TemplateFile -Path "$serviceJavaDir\service\impl\UserServiceImpl.java" -Template @'
package __PACKAGE_NAME__.service.impl;

import __PACKAGE_NAME__.exception.ResourceNotFoundException;
import __PACKAGE_NAME__.mapper.PageMapper;
import __PACKAGE_NAME__.mapper.UserMapper;
import __PACKAGE_NAME__.model.Gender;
import __PACKAGE_NAME__.model.PageResponse;
import __PACKAGE_NAME__.model.UserCreateUpdateRequest;
import __PACKAGE_NAME__.model.UserResponse;
import __PACKAGE_NAME__.persistence.entity.UserEntity;
import __PACKAGE_NAME__.persistence.repository.UserRepository;
import __PACKAGE_NAME__.persistence.repository.UserSpecifications;
import __PACKAGE_NAME__.service.UserService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional
@RequiredArgsConstructor
public class UserServiceImpl implements UserService {

    private static final String USER_ID_NOT_FOUND = "UserId :%d not found";

    private final UserRepository userRepository;
    private final UserMapper userMapper;
    private final PageMapper pageMapper;

    @Override
    public Long createUser(UserCreateUpdateRequest createUserRequest) {
        return userRepository.save(userMapper.mapToUserEntity(createUserRequest)).getId();
    }

    @Override
    public void updateUser(UserCreateUpdateRequest userUpdateRequest) {
        UserEntity user = userRepository.findById(userUpdateRequest.getId())
                .orElseThrow(() -> new ResourceNotFoundException(USER_ID_NOT_FOUND.formatted(userUpdateRequest.getId())));
        userMapper.mapToUpdateUserEntity(user, userUpdateRequest);
        userRepository.save(user);
    }

    @Override
    public void deleteUser(Long userId) {
        userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException(USER_ID_NOT_FOUND.formatted(userId)));
        userRepository.deleteById(userId);
    }

    @Override
    public UserResponse findUserById(Long userId) {
        return userRepository.findById(userId)
                .map(userMapper::mapToUserResponse)
                .orElseThrow(() -> new ResourceNotFoundException(USER_ID_NOT_FOUND.formatted(userId)));
    }

    @Override
    public PageResponse findAllUsers(String criteria, Gender gender, PageRequest pageRequest) {
        return pageMapper.toPageResponse(
                userRepository.findAll(UserSpecifications.filter(criteria, userMapper.toGenderEnum(gender)), pageRequest)
        );
    }
}
'@ -Values (Get-TemplateValues)

    Write-TemplateFile -Path "$serviceJavaDir\mapper\UserMapper.java" -Template @'
package __PACKAGE_NAME__.mapper;

import __PACKAGE_NAME__.model.Gender;
import __PACKAGE_NAME__.model.UserCreateUpdateRequest;
import __PACKAGE_NAME__.model.UserResponse;
import __PACKAGE_NAME__.persistence.entity.UserEntity;
import __PACKAGE_NAME__.persistence.enumeration.GenderEnum;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.MappingTarget;
import org.mapstruct.ValueMapping;

@Mapper(componentModel = "spring")
public interface UserMapper {

    @Mapping(target = "id", ignore = true)
    UserEntity mapToUserEntity(UserCreateUpdateRequest createUserRequest);

    UserCreateUpdateRequest mapToUserCreateOrUpdateRequest(UserEntity user);

    UserResponse mapToUserResponse(UserEntity user);

    void mapToUpdateUserEntity(@MappingTarget UserEntity user, UserCreateUpdateRequest userUpdateRequest);

    @ValueMapping(source = "MALE", target = "MALE")
    @ValueMapping(source = "FEMALE", target = "FEMALE")
    GenderEnum toGenderEnum(Gender gender);
}
'@ -Values (Get-TemplateValues)

    Write-TemplateFile -Path "$serviceJavaDir\mapper\PageMapper.java" -Template @'
package __PACKAGE_NAME__.mapper;

import __PACKAGE_NAME__.model.PageResponse;
import __PACKAGE_NAME__.model.UserResponse;
import __PACKAGE_NAME__.persistence.entity.UserEntity;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.springframework.data.domain.Page;

import java.util.List;

@Mapper(componentModel = "spring", uses = UserMapper.class)
public interface PageMapper {

    @Mapping(target = "content", expression = "java(toContent(result))")
    PageResponse toPageResponse(Page<UserEntity> result);

    default List<UserResponse> toContent(Page<UserEntity> result) {
        return result.getContent().stream().map(this::toUserResponse).toList();
    }

    UserResponse toUserResponse(UserEntity user);
}
'@ -Values (Get-TemplateValues)

    Write-TemplateFile -Path "$persistenceJavaDir\repository\UserRepository.java" -Template @'
package __PACKAGE_NAME__.persistence.repository;

import __PACKAGE_NAME__.persistence.entity.UserEntity;
import org.springframework.stereotype.Repository;

@Repository
public interface UserRepository extends AbstractRepository<UserEntity>__REPOSITORY_INHERITANCE__ {

}
'@ -Values (Get-TemplateValues @{ REPOSITORY_INHERITANCE = $inheritance })

    Write-TemplateFile -Path "$persistenceJavaDir\repository\UserSpecifications.java" -Template @'
package __PACKAGE_NAME__.persistence.repository;

import __PACKAGE_NAME__.persistence.entity.UserEntity;
import __PACKAGE_NAME__.persistence.enumeration.GenderEnum;
import jakarta.persistence.criteria.Predicate;
import org.springframework.data.jpa.domain.Specification;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

public final class UserSpecifications {

    private UserSpecifications() {
    }

    public static Specification<UserEntity> filter(String criteria, GenderEnum gender) {
        return (root, query, builder) -> {
            List<Predicate> predicates = new ArrayList<>();

            if (criteria != null && !criteria.isBlank()) {
                String pattern = "%" + criteria.toLowerCase(Locale.ROOT) + "%";
                predicates.add(builder.or(
                        builder.like(builder.lower(root.get("firstName")), pattern),
                        builder.like(builder.lower(root.get("lastName")), pattern),
                        builder.like(builder.lower(root.get("username")), pattern),
                        builder.like(builder.lower(root.get("email")), pattern)
                ));
            }

            if (gender != null) {
                predicates.add(builder.equal(root.get("gender"), gender));
            }

            return predicates.isEmpty()
                    ? builder.conjunction()
                    : builder.and(predicates.toArray(Predicate[]::new));
        };
    }
}
'@ -Values (Get-TemplateValues)
}

function Configure-JpaEnabledScaffolding {
    $restJavaDir = "$RestDir\src\main\java\$NewPathWindows"
    $persistenceJavaDir = "$PersistenceDir\src\main\java\$NewPathWindows\persistence"

    Write-JpaCommonSources

    Write-TemplateFile -Path "$restJavaDir\config\TemplateConfig.java" -Template @'
package __PACKAGE_NAME__.config;

import org.springframework.boot.persistence.autoconfigure.EntityScan;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.jpa.repository.config.EnableJpaAuditing;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;

@Configuration
@EnableJpaRepositories("__PACKAGE_NAME__.persistence.repository")
@EntityScan("__PACKAGE_NAME__.persistence.entity")
@EnableJpaAuditing
public class TemplateConfig {

}
'@ -Values (Get-TemplateValues)

    if ($BlazePersistence -eq 'true') {
        Write-TemplateFile -Path "$restJavaDir\config\BlazePersistenceConfig.java" -Template @'
package __PACKAGE_NAME__.config;

import com.blazebit.persistence.Criteria;
import com.blazebit.persistence.CriteriaBuilderFactory;
import com.blazebit.persistence.integration.view.spring.EnableEntityViews;
import com.blazebit.persistence.spi.CriteriaBuilderConfiguration;
import com.blazebit.persistence.view.EntityViewManager;
import com.blazebit.persistence.view.spi.EntityViewConfiguration;
import jakarta.persistence.EntityManagerFactory;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
@EnableEntityViews("__PACKAGE_NAME__.persistence.view")
public class BlazePersistenceConfig {

    @Bean
    public CriteriaBuilderFactory criteriaBuilderFactory(EntityManagerFactory emf) {
        CriteriaBuilderConfiguration config = Criteria.getDefault();
        return config.createCriteriaBuilderFactory(emf);
    }

    @Bean
    public EntityViewManager entityViewManager(CriteriaBuilderFactory cbf,
                                               EntityViewConfiguration evc) {
        return evc.createEntityViewManager(cbf);
    }
}
'@ -Values (Get-TemplateValues)
    } else {
        Remove-PathIfExists "$restJavaDir\config\BlazePersistenceConfig.java"
        Remove-PathIfExists "$persistenceJavaDir\view"
        Remove-PathIfExists "$persistenceJavaDir\repository\UserRepositoryCustom.java"
        Remove-PathIfExists "$persistenceJavaDir\repository\UserRepositoryCustomImpl.java"
    }
}

function Configure-JpaDisabledScaffolding {
    $serviceJavaDir = "$ServiceDir\src\main\java\$NewPathWindows"
    $persistenceJavaDir = "$PersistenceDir\src\main\java\$NewPathWindows"
    $restJavaDir = "$RestDir\src\main\java\$NewPathWindows"

    Remove-PathIfExists "$persistenceJavaDir\persistence"
    Remove-PathIfExists "$serviceJavaDir\mapper"
    Remove-PathIfExists "$restJavaDir\config\TemplateConfig.java"
    Remove-PathIfExists "$restJavaDir\config\BlazePersistenceConfig.java"
    Remove-PathIfExists "$restJavaDir\DataLoader.java"
    Remove-PathIfExists "$RestDir\src\main\resources\db"

    Write-TemplateFile -Path "$serviceJavaDir\service\UserService.java" -Template @'
package __PACKAGE_NAME__.service;

import __PACKAGE_NAME__.model.Gender;
import __PACKAGE_NAME__.model.PageResponse;
import __PACKAGE_NAME__.model.UserCreateUpdateRequest;
import __PACKAGE_NAME__.model.UserResponse;
import org.springframework.data.domain.PageRequest;

public interface UserService {

    Long createUser(UserCreateUpdateRequest createUserRequest);

    void updateUser(UserCreateUpdateRequest userUpdateRequest);

    void deleteUser(Long userId);

    UserResponse findUserById(Long userId);

    PageResponse findAllUsers(String criteria, Gender gender, PageRequest pageRequest);
}
'@ -Values (Get-TemplateValues)

    Write-TemplateFile -Path "$serviceJavaDir\service\impl\UserServiceImpl.java" -Template @'
package __PACKAGE_NAME__.service.impl;

import __PACKAGE_NAME__.exception.ResourceNotFoundException;
import __PACKAGE_NAME__.model.Gender;
import __PACKAGE_NAME__.model.PageResponse;
import __PACKAGE_NAME__.model.UserCreateUpdateRequest;
import __PACKAGE_NAME__.model.UserResponse;
import __PACKAGE_NAME__.service.UserService;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;

@Service
public class UserServiceImpl implements UserService {

    private static final String USER_ID_NOT_FOUND = "UserId :%d not found";

    private final Map<Long, UserResponse> users = new ConcurrentHashMap<>();
    private final AtomicLong idGenerator = new AtomicLong();

    @Override
    public Long createUser(UserCreateUpdateRequest createUserRequest) {
        long userId = idGenerator.incrementAndGet();
        UserResponse user = toUserResponse(userId, createUserRequest);
        users.put(userId, user);
        return userId;
    }

    @Override
    public void updateUser(UserCreateUpdateRequest userUpdateRequest) {
        Long userId = userUpdateRequest.getId();
        if (userId == null || !users.containsKey(userId)) {
            throw new ResourceNotFoundException(USER_ID_NOT_FOUND.formatted(userId));
        }
        users.put(userId, toUserResponse(userId, userUpdateRequest));
    }

    @Override
    public void deleteUser(Long userId) {
        if (users.remove(userId) == null) {
            throw new ResourceNotFoundException(USER_ID_NOT_FOUND.formatted(userId));
        }
    }

    @Override
    public UserResponse findUserById(Long userId) {
        UserResponse user = users.get(userId);
        if (user == null) {
            throw new ResourceNotFoundException(USER_ID_NOT_FOUND.formatted(userId));
        }
        return user;
    }

    @Override
    public PageResponse findAllUsers(String criteria, Gender gender, PageRequest pageRequest) {
        List<UserResponse> filteredUsers = users.values().stream()
                .filter(user -> matchesCriteria(user, criteria))
                .filter(user -> gender == null || gender == user.getGender())
                .sorted(resolveComparator(pageRequest.getSort()))
                .toList();

        int totalElements = filteredUsers.size();
        int fromIndex = Math.min((int) pageRequest.getOffset(), totalElements);
        int toIndex = Math.min(fromIndex + pageRequest.getPageSize(), totalElements);
        List<UserResponse> content = new ArrayList<>(filteredUsers.subList(fromIndex, toIndex));
        int totalPages = totalElements == 0 ? 0 : (int) Math.ceil((double) totalElements / pageRequest.getPageSize());

        PageResponse response = new PageResponse();
        response.setNumber(pageRequest.getPageNumber());
        response.setSize(pageRequest.getPageSize());
        response.setNumberOfElements(content.size());
        response.setTotalPages(totalPages);
        response.setTotalElements(totalElements);
        response.setContent(content);
        return response;
    }

    private boolean matchesCriteria(UserResponse user, String criteria) {
        if (criteria == null || criteria.isBlank()) {
            return true;
        }
        String normalizedCriteria = criteria.toLowerCase(Locale.ROOT);
        return contains(user.getUsername(), normalizedCriteria)
                || contains(user.getEmail(), normalizedCriteria)
                || contains(user.getFirstName(), normalizedCriteria)
                || contains(user.getLastName(), normalizedCriteria);
    }

    private boolean contains(String value, String criteria) {
        return value != null && value.toLowerCase(Locale.ROOT).contains(criteria);
    }

    private Comparator<UserResponse> resolveComparator(Sort sort) {
        Sort.Order order = sort.stream().findFirst().orElseGet(() -> Sort.Order.asc("firstName"));
        Comparator<UserResponse> comparator = switch (order.getProperty()) {
            case "id" -> Comparator.comparing(UserResponse::getId, Comparator.nullsLast(Long::compareTo));
            case "username" -> Comparator.comparing(UserResponse::getUsername, Comparator.nullsLast(String.CASE_INSENSITIVE_ORDER));
            case "email" -> Comparator.comparing(UserResponse::getEmail, Comparator.nullsLast(String.CASE_INSENSITIVE_ORDER));
            case "lastName" -> Comparator.comparing(UserResponse::getLastName, Comparator.nullsLast(String.CASE_INSENSITIVE_ORDER));
            case "gender" -> Comparator.comparing(user -> user.getGender() == null ? null : user.getGender().name(), Comparator.nullsLast(String.CASE_INSENSITIVE_ORDER));
            default -> Comparator.comparing(UserResponse::getFirstName, Comparator.nullsLast(String.CASE_INSENSITIVE_ORDER));
        };
        return order.isDescending() ? comparator.reversed() : comparator;
    }

    private UserResponse toUserResponse(Long userId, UserCreateUpdateRequest request) {
        UserResponse response = new UserResponse();
        response.setId(userId);
        response.setUsername(request.getUsername());
        response.setEmail(request.getEmail());
        response.setFirstName(request.getFirstName());
        response.setLastName(request.getLastName());
        response.setGender(request.getGender());
        return response;
    }
}
'@ -Values (Get-TemplateValues)
}

function Configure-Stack {
    Configure-AppPom
    Configure-PersistencePom
    Configure-ServicePom
    Configure-ApplicationYaml
    Configure-ApplicationDevYaml

    if ($SpringDataJpa -eq 'true') {
        Configure-MigrationFiles
        Configure-JpaEnabledScaffolding
    } else {
        Configure-JpaDisabledScaffolding
    }
}

Write-Host ''
Write-Info '+-----------------------------------------+'
Write-Info '|  Initializing Spring Boot template      |'
Write-Info '+-----------------------------------------+'
Write-Host ''
Write-Host ("  {0,-18}: {1}" -f 'Project name', $ProjectName)
Write-Host ("  {0,-18}: {1}" -f 'Package', $PackageName)
Write-Host ("  {0,-18}: {1}" -f 'Pascal case', $ProjectPascal)
Write-Host ("  {0,-18}: {1}" -f 'Spring Data JPA', $SpringDataJpa)
Write-Host ("  {0,-18}: {1}" -f 'Blaze-Persistence', $BlazePersistence)
Write-Host ("  {0,-18}: {1}" -f 'Migration tool', $MigrationTool)
Write-Host ''

Write-Info '  [1/6] Replacing text in source files...'
$sourceExts = @('.xml', '.java', '.yaml', '.yml', '.md', '.properties', '.imports', '.ps1', '.sh')
$excludeParts = @('\.git\\', '\\target\\', '\.idea\\')

$files = Get-ChildItem -Path . -Recurse -File | Where-Object {
    $path = $_.FullName
    $extensionAllowed = ($sourceExts -contains $_.Extension) -or ($_.Name -eq 'Dockerfile')
    if (-not $extensionAllowed) { return $false }
    foreach ($ex in $excludeParts) {
        if ($path -match $ex) { return $false }
    }
    return $true
}

foreach ($file in $files) {
    $content = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
    if ([string]::IsNullOrEmpty($content)) { continue }

    $content = $content -replace [regex]::Escape($OldGroup), $PackageName
    $content = $content -replace [regex]::Escape($OldPath), $NewPath
    $content = $content -replace 'template-parent', "${ProjectName}-parent"
    $content = $content -replace 'template-app', "${ProjectName}-app"
    $content = $content -replace 'template-persistence', "${ProjectName}-persistence"
    $content = $content -replace 'template-service', "${ProjectName}-service"
    $content = $content -replace 'template-rest', "${ProjectName}-rest"
    $content = $content -replace 'template-image', "${ProjectName}-image"
    $content = $content -replace 'jdbc:h2:mem:template', "jdbc:h2:mem:$ProjectName"
    $content = $content -replace 'image: Template:', "image: ${ProjectPascal}:"
    $content = $content -replace '>Template<', ">${ProjectPascal}<"
    $content = $content -replace '# Spring Boot Template', "# $ProjectPascal"

    [System.IO.File]::WriteAllText($file.FullName, $content, $Utf8NoBom)
}

Write-Info '  [2/6] Renaming Java package directories...'
function Rename-PackageDir {
    param([string]$Base)
    $oldPkgDir = Join-Path $Base ($OldPath -replace '/', '\')
    $newPkgDir = Join-Path $Base ($NewPath -replace '/', '\')
    if (-not (Test-Path $oldPkgDir)) { return }
    if ($oldPkgDir -eq $newPkgDir) { return }
    if ($newPkgDir.StartsWith("$oldPkgDir\", [System.StringComparison]::OrdinalIgnoreCase)) {
        $stagingDir = Join-Path $Base ('.package-rename-{0}' -f [System.Guid]::NewGuid().ToString('N'))
        Move-Item -Path $oldPkgDir -Destination $stagingDir
        $newParent = Split-Path $newPkgDir -Parent
        if (-not (Test-Path $newParent)) { New-Item -ItemType Directory -Path $newParent -Force | Out-Null }
        Move-Item -Path $stagingDir -Destination $newPkgDir
    } else {
        $newParent = Split-Path $newPkgDir -Parent
        if (-not (Test-Path $newParent)) { New-Item -ItemType Directory -Path $newParent -Force | Out-Null }
        Move-Item -Path $oldPkgDir -Destination $newPkgDir
    }
    $oldMid = Join-Path $Base 'com\project'
    $oldRoot = Join-Path $Base 'com'
    if ((Test-Path $oldMid) -and (@(Get-ChildItem $oldMid).Count -eq 0)) {
        Remove-Item $oldMid -Force
        if ((Test-Path $oldRoot) -and (@(Get-ChildItem $oldRoot).Count -eq 0)) {
            Remove-Item $oldRoot -Force
        }
    }
}

foreach ($module in @('template-persistence', 'template-service', 'template-rest')) {
    foreach ($srcType in @('src/main/java', 'src/test/java')) {
        Rename-PackageDir -Base "template-app\$module\$srcType"
    }
}

Write-Info '  [3/6] Renaming module directories...'
foreach ($module in @('template-persistence', 'template-service', 'template-rest', 'template-image')) {
    $oldDir = "template-app\$module"
    $newName = $module -replace '^template-', "${ProjectName}-"
    if ((Test-Path $oldDir) -and $oldDir -ne "template-app\$newName") { Rename-Item -Path $oldDir -NewName $newName }
}
if ((Test-Path 'template-app') -and 'template-app' -ne "${ProjectName}-app") { Rename-Item -Path 'template-app' -NewName "${ProjectName}-app" }

Write-Info '  [4/6] Configuring selected starter stack...'
Configure-Stack

Write-Host ''
Write-Info '  [5/6] Additional service modules'
Write-Host ''

$moduleCount = 0
if ($moduleCountExplicit) {
    $moduleCount = $ExtraServiceModules
} else {
    $moduleCountInput = Read-Host '  How many extra service modules do you want to create? (0 to skip)'
    if ($moduleCountInput -match '^\d+$') {
        $moduleCount = [int]$moduleCountInput
    }
}

if ($moduleCount -gt 10) {
    Write-Warn '  Clamping to 10 modules maximum.'
    $moduleCount = 10
}

if ($moduleCount -gt 0) {
    $appPomPath = '{0}-app\pom.xml' -f $ProjectName
    $reservedMods = @('app', 'parent', 'rest', 'persistence', 'service', 'image', 'core', 'common', 'web', 'api')
    $createdMods = @()
    $existingServiceDir = '{0}-app\{0}-service' -f $ProjectName

    if (Test-Path $existingServiceDir) {
        Write-Host ''
        Write-Info ('  Rename existing ''{0}-service'' module?' -f $ProjectName)
        Write-Host "  Since you are adding extra modules, consider giving the existing"
        Write-Host "  service module a specific name (e.g. 'user', 'user-mgmt')."
        Write-Host ''
        $newSvcName = (Read-Host ('  New name for ''{0}-service'' [Enter to keep as ''service'']' -f $ProjectName)).Trim().ToLower()

        if (-not [string]::IsNullOrWhiteSpace($newSvcName) -and $newSvcName -ne 'service') {
            $svcValid = $true
            if ($newSvcName -notmatch '^[a-z][a-z0-9-]*$') {
                Write-Warn ('  Invalid name ''{0}'' - keeping ''{1}-service'' as-is.' -f $newSvcName, $ProjectName)
                $svcValid = $false
            } elseif ($newSvcName.Length -lt 2 -or $newSvcName.Length -gt 50) {
                Write-Warn ('  Name must be 2-50 characters - keeping ''{0}-service'' as-is.' -f $ProjectName)
                $svcValid = $false
            } elseif ($newSvcName -match '-$' -or $newSvcName -match '--') {
                Write-Warn ('  Name must not end with a hyphen or contain ''--'' - keeping ''{0}-service'' as-is.' -f $ProjectName)
                $svcValid = $false
            } elseif ($reservedMods -contains $newSvcName) {
                Write-Warn ('  ''{0}'' is a reserved name - keeping ''{1}-service'' as-is.' -f $newSvcName, $ProjectName)
                $svcValid = $false
            } elseif (Test-Path ('{0}-app\{0}-{1}' -f $ProjectName, $newSvcName)) {
                Write-Warn ('  Directory ''{0}-app\{0}-{1}'' already exists - keeping as-is.' -f $ProjectName, $newSvcName)
                $svcValid = $false
            }

            if ($svcValid) {
                $newSvcFull = '{0}-{1}' -f $ProjectName, $newSvcName
                foreach ($filePath in @(
                        ('{0}-app\pom.xml' -f $ProjectName),
                        ('{0}-app\{0}-rest\pom.xml' -f $ProjectName),
                        ('{0}\pom.xml' -f $existingServiceDir)
                    )) {
                    if (Test-Path $filePath) {
                        $content = [System.IO.File]::ReadAllText($filePath, [System.Text.Encoding]::UTF8)
                        $content = $content -replace [regex]::Escape(('{0}-service' -f $ProjectName)), $newSvcFull
                        [System.IO.File]::WriteAllText($filePath, $content, $Utf8NoBom)
                    }
                }
                Rename-Item -Path $existingServiceDir -NewName $newSvcFull
                Write-Success ('  Renamed ''{0}-service'' -> ''{1}''' -f $ProjectName, $newSvcFull)
                $reservedMods += $newSvcName
                $createdMods += $newSvcName
            }
        } else {
            Write-Info ('  Keeping ''{0}-service'' as-is.' -f $ProjectName)
        }
    }

    for ($i = 1; $i -le $moduleCount; $i++) {
        Write-Host ''
        $modName = (Read-Host ("  Module {0} of {1} - name (e.g. payment, notification)" -f $i, $moduleCount)).Trim().ToLower()
        if ([string]::IsNullOrWhiteSpace($modName)) { Write-Warn ("  Skipping module {0} - name cannot be empty." -f $i); continue }
        if ($modName -notmatch '^[a-z][a-z0-9-]*$') { Write-Warn ("  Skipping '{0}' - only lowercase letters, digits, and hyphens allowed." -f $modName); continue }
        if ($modName.Length -lt 2 -or $modName.Length -gt 50) { Write-Warn ("  Skipping '{0}' - name must be 2-50 characters." -f $modName); continue }
        if ($modName -match '-$' -or $modName -match '--') { Write-Warn ("  Skipping '{0}' - must not end with a hyphen or contain consecutive hyphens." -f $modName); continue }
        if ($reservedMods -contains $modName) { Write-Warn ("  Skipping '{0}' - reserved name." -f $modName); continue }
        if ($createdMods -contains $modName) { Write-Warn ("  Skipping '{0}' - already created in this session." -f $modName); continue }

        $fullMod = '{0}-{1}' -f $ProjectName, $modName
        $modDir = '{0}-app\{1}' -f $ProjectName, $fullMod
        if (Test-Path $modDir) { Write-Warn ("  Skipping '{0}' - directory '{1}' already exists." -f $modName, $modDir); continue }

        $appPomText = [System.IO.File]::ReadAllText($appPomPath, [System.Text.Encoding]::UTF8)
        if ($appPomText -match [regex]::Escape("<module>$fullMod</module>")) {
            Write-Warn ("  Skipping '{0}' - already registered in app pom.xml." -f $modName)
            continue
        }

        New-Item -ItemType Directory -Path "$modDir\src\main\java\$NewPathWindows" -Force | Out-Null
        New-Item -ItemType Directory -Path "$modDir\src\test\java\$NewPathWindows" -Force | Out-Null

        $modulePomTemplate = @'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <parent>
        <artifactId>__PROJECT_NAME__-app</artifactId>
        <groupId>__PACKAGE_NAME__</groupId>
        <version>1.0-SNAPSHOT</version>
    </parent>

    <artifactId>__FULL_MOD__</artifactId>

    <dependencies>
        <dependency>
            <groupId>__PACKAGE_NAME__</groupId>
            <artifactId>__PROJECT_NAME__-persistence</artifactId>
        </dependency>
        <dependency>
            <groupId>org.mapstruct</groupId>
            <artifactId>mapstruct</artifactId>
        </dependency>
        <dependency>
            <groupId>org.mapstruct</groupId>
            <artifactId>mapstruct-processor</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-json</artifactId>
        </dependency>
        <dependency>
            <groupId>jakarta.validation</groupId>
            <artifactId>jakarta.validation-api</artifactId>
        </dependency>
        <dependency>
            <groupId>io.swagger.core.v3</groupId>
            <artifactId>swagger-annotations-jakarta</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>
</project>
'@
        Write-TemplateFile -Path "$modDir\pom.xml" -Template $modulePomTemplate -Values (Get-TemplateValues @{ FULL_MOD = $fullMod })

        $appPomText = $appPomText -replace '(?m)([ \t]*</modules>)', "`t`t<module>$fullMod</module>`r`n`$1"
        [System.IO.File]::WriteAllText($appPomPath, $appPomText, $Utf8NoBom)
        Write-Success "  Created: $fullMod"
        $createdMods += $modName
    }

    if ($createdMods.Count -gt 0) {
        Write-Host ''
        Write-Info "  Modules created: $($createdMods -join ', ')"
    }
}

Write-Host ''
Write-Info '  [6/6] Cleaning generated output and initializing git...'
Get-ChildItem -Path . -Recurse -Directory -Filter target -ErrorAction SilentlyContinue |
    Sort-Object FullName -Descending |
    ForEach-Object { [System.IO.Directory]::Delete("\\?\$($_.FullName)", $true) }

foreach ($scriptPath in @('bootstrap.ps1', 'bootstrap.sh', 'init.ps1', 'init.sh')) {
    if (Test-Path $scriptPath) {
        Remove-Item -Force $scriptPath
    }
}

if (Test-Path '.git') { Remove-Item -Recurse -Force '.git' }
function Invoke-Git {
    param([string[]]$Arguments)
    & git @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed with exit code $LASTEXITCODE."
    }
}

Invoke-Git -Arguments @('init', '-q')
Invoke-Git -Arguments @('add', '-A')
Invoke-Git -Arguments @('-c', 'user.name=Spring Boot Starter', '-c', 'user.email=spring-boot-starter@localhost', 'commit', '-q', '-m', 'chore: initial project from spring-boot-starter')
Write-Success '  Git repository initialized with a clean history (no remote).'

Write-Host ''
Write-Success "  Done!  Project '$ProjectName' is ready."
Write-Host ''
Write-Host '  Next steps:'
Write-Host '    .\mvnw.cmd clean install'
Write-Host ("    cd {0}-app\{0}-rest ; ..\..\mvnw.cmd spring-boot:run" -f $ProjectName)
Write-Host ''
Write-Host '    Swagger UI  ->  http://localhost:8080/swagger-ui/index.html'
if ($SpringDataJpa -eq 'true') {
    Write-Host '    H2 Console  ->  http://localhost:8080/h2-console'
}
Write-Host ''
