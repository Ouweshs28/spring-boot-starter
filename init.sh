#!/usr/bin/env bash
# -------------------------------------------------------------------------------
# init.sh  -  Bootstrap this Spring Boot template into your own project
# -------------------------------------------------------------------------------
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}$*${NC}"; }
success() { echo -e "${GREEN}$*${NC}"; }
warn()    { echo -e "${YELLOW}$*${NC}"; }
error()   { echo -e "${RED}ERROR: $*${NC}" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage: ./init.sh [options]
  -p, --project-name          Lowercase, hyphenated name (e.g. my-app)
  -n, --package-name          Java base package (e.g. com.example.myapp)
  -m, --migration-tool        flyway | liquibase | none
  -j, --spring-data-jpa       true | false
  -b, --blaze-persistence     true | false
  -s, --extra-service-modules Number of extra service modules to scaffold
  -h, --help                  Show this help message

Defaults:
  Spring Data JPA   enabled
  Blaze-Persistence enabled
  Migration tool    flyway

Compatibility:
  When Spring Data JPA is disabled, Blaze-Persistence is forced off and
  migration tooling is forced to 'none'. Explicitly requesting Blaze or
  Flyway/Liquibase while JPA is disabled is rejected.
EOF
}

normalize_bool() {
  local value="${1,,}"
  case "$value" in
    y|yes|true|1|on|enable|enabled) echo "true" ;;
    n|no|false|0|off|disable|disabled) echo "false" ;;
    *) return 1 ;;
  esac
}

normalize_migration() {
  local value="${1,,}"
  case "$value" in
    flyway|liquibase|none) echo "$value" ;;
    *) return 1 ;;
  esac
}

prompt_yes_no_default_yes() {
  local prompt="$1"
  local response
  while true; do
    read -rp "$prompt [Y/n]: " response
    if [[ -z "$response" ]]; then
      echo "true"
      return 0
    fi
    if normalize_bool "$response" >/dev/null; then
      normalize_bool "$response"
      return 0
    fi
    warn "Please answer yes or no."
  done
}

prompt_migration_tool() {
  local response
  while true; do
    read -rp "Migration tool [flyway/liquibase/none] (default: flyway): " response
    if [[ -z "$response" ]]; then
      echo "flyway"
      return 0
    fi
    if normalize_migration "$response" >/dev/null; then
      normalize_migration "$response"
      return 0
    fi
    warn "Please choose flyway, liquibase, or none."
  done
}

require_value() {
  [[ $# -ge 2 && -n "$2" ]] || error "Missing value for $1"
}

write_file() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
  cat > "$path"
}

safe_rmdir() { rmdir "$1" 2>/dev/null || true; }
remove_path() {
  [[ -e "$1" ]] || return 0
  rm -rf -- "$1"
}

PROJECT_NAME=""
PACKAGE_NAME=""
MIGRATION_TOOL=""
SPRING_DATA_JPA=""
BLAZE_PERSISTENCE=""
MODULE_COUNT_INPUT=""

MIGRATION_EXPLICIT=0
JPA_EXPLICIT=0
BLAZE_EXPLICIT=0
MODULE_COUNT_EXPLICIT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--project-name)
      require_value "$1" "${2-}"
      PROJECT_NAME="$2"
      shift 2
      ;;
    -n|--package-name)
      require_value "$1" "${2-}"
      PACKAGE_NAME="$2"
      shift 2
      ;;
    -m|--migration-tool)
      require_value "$1" "${2-}"
      MIGRATION_TOOL="$2"
      MIGRATION_EXPLICIT=1
      shift 2
      ;;
    -j|--spring-data-jpa|--jpa)
      require_value "$1" "${2-}"
      SPRING_DATA_JPA="$2"
      JPA_EXPLICIT=1
      shift 2
      ;;
    -b|--blaze-persistence|--blaze)
      require_value "$1" "${2-}"
      BLAZE_PERSISTENCE="$2"
      BLAZE_EXPLICIT=1
      shift 2
      ;;
    -s|--extra-service-modules|--module-count)
      require_value "$1" "${2-}"
      MODULE_COUNT_INPUT="$2"
      MODULE_COUNT_EXPLICIT=1
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      error "Unknown argument: $1"
      ;;
  esac
done

[[ -z "$PROJECT_NAME" ]] && read -rp "Project name (e.g. my-app): " PROJECT_NAME
[[ -z "$PACKAGE_NAME" ]] && read -rp "Base package  (e.g. com.example.myapp): " PACKAGE_NAME

[[ "$PROJECT_NAME" =~ ^[a-z][a-z0-9-]*$ ]] || error "Project name must be lowercase and contain only letters, digits, and hyphens."
[[ "$PACKAGE_NAME" =~ ^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*)*$ ]] || error "Package name must be a valid Java package (e.g. com.example.myapp)."

if (( JPA_EXPLICIT )); then
  SPRING_DATA_JPA=$(normalize_bool "$SPRING_DATA_JPA") || error "Spring Data JPA must be true or false."
else
  SPRING_DATA_JPA=$(prompt_yes_no_default_yes "Enable Spring Data JPA?")
fi

if [[ "$SPRING_DATA_JPA" == "true" ]]; then
  if (( MIGRATION_EXPLICIT )); then
    MIGRATION_TOOL=$(normalize_migration "$MIGRATION_TOOL") || error "Migration tool must be flyway, liquibase, or none."
  else
    MIGRATION_TOOL=$(prompt_migration_tool)
  fi

  if (( BLAZE_EXPLICIT )); then
    BLAZE_PERSISTENCE=$(normalize_bool "$BLAZE_PERSISTENCE") || error "Blaze-Persistence must be true or false."
  else
    BLAZE_PERSISTENCE=$(prompt_yes_no_default_yes "Enable Blaze-Persistence?")
  fi
else
  if (( BLAZE_EXPLICIT )); then
    BLAZE_PERSISTENCE=$(normalize_bool "$BLAZE_PERSISTENCE") || error "Blaze-Persistence must be true or false."
    [[ "$BLAZE_PERSISTENCE" == "false" ]] || error "Blaze-Persistence cannot be enabled when Spring Data JPA is disabled."
  else
    BLAZE_PERSISTENCE="false"
    info "Spring Data JPA disabled -> Blaze-Persistence will also be disabled."
  fi

  if (( MIGRATION_EXPLICIT )); then
    MIGRATION_TOOL=$(normalize_migration "$MIGRATION_TOOL") || error "Migration tool must be flyway, liquibase, or none."
    [[ "$MIGRATION_TOOL" == "none" ]] || error "Migration tooling cannot be enabled when Spring Data JPA is disabled."
  else
    MIGRATION_TOOL="none"
    info "Spring Data JPA disabled -> migration tooling will also be disabled."
  fi
fi

OLD_GROUP="com.project.template"
OLD_PATH="com/project/template"
NEW_PATH="${PACKAGE_NAME//.//}"
APP_DIR="${PROJECT_NAME}-app"
PERSISTENCE_DIR="${APP_DIR}/${PROJECT_NAME}-persistence"
SERVICE_DIR="${APP_DIR}/${PROJECT_NAME}-service"
REST_DIR="${APP_DIR}/${PROJECT_NAME}-rest"
PROJECT_PASCAL=$(echo "$PROJECT_NAME" | perl -pe 's/(^|-)([a-z])/uc($2)/ge; s/-//g')

summary_line() {
  printf '  %-18s: %s\n' "$1" "$2"
}

configure_app_pom() {
  local blaze_dependency_management=""
  local blaze_annotation_processor=""
  if [[ "$BLAZE_PERSISTENCE" == "true" ]]; then
    blaze_dependency_management=$(cat <<EOF
            <!-- Blaze-Persistence BOM (covers core + entity-view artifacts) -->
            <dependency>
                <groupId>com.blazebit</groupId>
                <artifactId>blaze-persistence-bom</artifactId>
                <version>\${blaze-persistence.version}</version>
                <type>pom</type>
                <scope>import</scope>
            </dependency>
            <!-- Blaze integration artifacts (not in BOM) -->
            <dependency>
                <groupId>com.blazebit</groupId>
                <artifactId>blaze-persistence-integration-hibernate-7.2</artifactId>
                <version>\${blaze-persistence.version}</version>
            </dependency>
            <dependency>
                <groupId>com.blazebit</groupId>
                <artifactId>blaze-persistence-integration-entity-view-spring-6.0</artifactId>
                <version>\${blaze-persistence.version}</version>
            </dependency>
            <dependency>
                <groupId>com.blazebit</groupId>
                <artifactId>blaze-persistence-entity-view-processor-jakarta</artifactId>
                <version>\${blaze-persistence.version}</version>
            </dependency>
EOF
)
    blaze_annotation_processor=$(cat <<EOF
                        <path>
                            <groupId>com.blazebit</groupId>
                            <artifactId>blaze-persistence-entity-view-processor-jakarta</artifactId>
                            <version>\${blaze-persistence.version}</version>
                        </path>
EOF
)
  fi

  write_file "$APP_DIR/pom.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <parent>
        <artifactId>${PROJECT_NAME}-parent</artifactId>
        <groupId>${PACKAGE_NAME}</groupId>
        <version>1.0-SNAPSHOT</version>
    </parent>

    <artifactId>${PROJECT_NAME}-app</artifactId>
    <packaging>pom</packaging>

    <properties>
        <build.final-name>${PROJECT_PASCAL}</build.final-name>
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
        <module>${PROJECT_NAME}-persistence</module>
        <module>${PROJECT_NAME}-service</module>
        <module>${PROJECT_NAME}-rest</module>
        <module>${PROJECT_NAME}-image</module>
    </modules>

    <dependencyManagement>
        <dependencies>
            <dependency>
                <groupId>${PACKAGE_NAME}</groupId>
                <artifactId>${PROJECT_NAME}-persistence</artifactId>
                <version>\${project.version}</version>
            </dependency>
            <dependency>
                <groupId>${PACKAGE_NAME}</groupId>
                <artifactId>${PROJECT_NAME}-service</artifactId>
                <version>\${project.version}</version>
            </dependency>
${blaze_dependency_management}            <dependency>
                <groupId>org.mapstruct</groupId>
                <artifactId>mapstruct</artifactId>
                <version>\${org.mapstruct.version}</version>
            </dependency>
            <dependency>
                <groupId>org.mapstruct</groupId>
                <artifactId>mapstruct-processor</artifactId>
                <version>\${org.mapstruct.version}</version>
            </dependency>
            <dependency>
                <groupId>io.swagger.core.v3</groupId>
                <artifactId>swagger-annotations-jakarta</artifactId>
                <version>\${swagger-annotations.version}</version>
            </dependency>
            <dependency>
                <groupId>org.springdoc</groupId>
                <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>
                <version>\${springdoc-openapi-starter-webmvc-ui.version}</version>
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
                            <version>\${org.projectlombok.version}</version>
                        </path>
                        <path>
                            <groupId>org.mapstruct</groupId>
                            <artifactId>mapstruct-processor</artifactId>
                            <version>\${org.mapstruct.version}</version>
                        </path>
                        <path>
                            <groupId>org.projectlombok</groupId>
                            <artifactId>lombok-mapstruct-binding</artifactId>
                            <version>\${lombok-mapstruct-binding.version}</version>
                        </path>
${blaze_annotation_processor}                    </annotationProcessorPaths>
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
                    <version>\${maven-compiler-plugin.version}</version>
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
                    <version>\${exec-maven-plugin.version}</version>
                </plugin>
                <plugin>
                    <groupId>org.openapitools</groupId>
                    <artifactId>openapi-generator-maven-plugin</artifactId>
                    <version>\${org.openapi-generator-maven-plugin.version}</version>
                    <executions>
                        <execution>
                            <goals>
                                <goal>generate</goal>
                            </goals>
                            <configuration>
                                <apiPackage>${PACKAGE_NAME}.api</apiPackage>
                                <generateApis>false</generateApis>
                                <generateApiTests>false</generateApiTests>
                                <generateApiDocumentation>false</generateApiDocumentation>
                                <generatorName>spring</generatorName>
                                <inputSpec>
                                    \${project.basedir}/../${PROJECT_NAME}-rest/src/main/resources/static/openapi.yaml
                                </inputSpec>
                                <modelPackage>${PACKAGE_NAME}.model</modelPackage>
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
EOF
}

configure_persistence_pom() {
  local dependencies=""
  if [[ "$SPRING_DATA_JPA" == "true" ]]; then
    dependencies=$(cat <<EOF
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-jpa</artifactId>
        </dependency>
        <dependency>
            <groupId>com.h2database</groupId>
            <artifactId>h2</artifactId>
            <scope>runtime</scope>
        </dependency>
EOF
)

    if [[ "$BLAZE_PERSISTENCE" == "true" ]]; then
      dependencies+=$(cat <<EOF
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
EOF
)
    fi

    case "$MIGRATION_TOOL" in
      flyway)
        dependencies+=$(cat <<EOF
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-flyway</artifactId>
        </dependency>
EOF
)
        ;;
      liquibase)
        dependencies+=$(cat <<EOF
        <dependency>
            <groupId>org.liquibase</groupId>
            <artifactId>liquibase-core</artifactId>
        </dependency>
EOF
)
        ;;
    esac
  fi

  write_file "$PERSISTENCE_DIR/pom.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <parent>
        <artifactId>${PROJECT_NAME}-app</artifactId>
        <groupId>${PACKAGE_NAME}</groupId>
        <version>1.0-SNAPSHOT</version>
    </parent>

    <artifactId>${PROJECT_NAME}-persistence</artifactId>
$(if [[ -n "$dependencies" ]]; then printf '    <dependencies>\n%s    </dependencies>\n' "$dependencies"; fi)</project>
EOF
}

configure_service_pom() {
  write_file "$SERVICE_DIR/pom.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <parent>
        <artifactId>${PROJECT_NAME}-app</artifactId>
        <groupId>${PACKAGE_NAME}</groupId>
        <version>1.0-SNAPSHOT</version>
    </parent>

    <artifactId>${PROJECT_NAME}-service</artifactId>

    <dependencies>
        <dependency>
            <groupId>${PACKAGE_NAME}</groupId>
            <artifactId>${PROJECT_NAME}-persistence</artifactId>
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
EOF
}

configure_application_yaml() {
  if [[ "$SPRING_DATA_JPA" == "true" ]]; then
    local ddl_auto="validate"
    local migration_block=""
    if [[ "$MIGRATION_TOOL" == "none" ]]; then
      ddl_auto="create-drop"
    elif [[ "$MIGRATION_TOOL" == "flyway" ]]; then
      migration_block=$(cat <<EOF
  flyway:
    enabled: true
    locations: classpath:db/migration
EOF
)
    elif [[ "$MIGRATION_TOOL" == "liquibase" ]]; then
      migration_block=$(cat <<EOF
  liquibase:
    change-log: classpath:db/changelog/db.changelog-master.yaml
EOF
)
    fi

    write_file "$REST_DIR/src/main/resources/application.yaml" <<EOF
spring:
  datasource:
    url: jdbc:h2:mem:${PROJECT_NAME};DB_CLOSE_DELAY=-1;DB_CLOSE_ON_EXIT=FALSE
    driver-class-name: org.h2.Driver
    username: sa
    password:
  h2:
    console:
      enabled: true
      path: /h2-console
  jpa:
    hibernate:
      ddl-auto: ${ddl_auto}
    show-sql: true
    database-platform: org.hibernate.dialect.H2Dialect
${migration_block}  profiles:
    active: dev
EOF
  else
    write_file "$REST_DIR/src/main/resources/application.yaml" <<EOF
spring:
  profiles:
    active: dev
EOF
  fi
}

configure_application_dev_yaml() {
  local migration_logger=""
  local migration_logger_block=""
  if [[ "$SPRING_DATA_JPA" == "true" ]]; then
    case "$MIGRATION_TOOL" in
      flyway) migration_logger='    org.flywaydb: DEBUG' ;;
      liquibase) migration_logger='    liquibase: INFO' ;;
    esac
  fi
  if [[ -n "$migration_logger" ]]; then
    migration_logger_block="${migration_logger}"$'\n'
  fi

  write_file "$REST_DIR/src/main/resources/application-dev.yaml" <<EOF
springdoc:
  api-docs:
    enabled: false
  swagger-ui:
    url: openapi.yaml
logging:
  level:
    org.springframework.web: DEBUG
${migration_logger_block}
EOF
}

configure_migration_files() {
  local db_dir="$REST_DIR/src/main/resources/db"
  case "$MIGRATION_TOOL" in
    flyway)
      remove_path "$db_dir/changelog"
      write_file "$db_dir/migration/V1__init.sql" <<EOF
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
EOF
      ;;
    liquibase)
      remove_path "$db_dir/migration"
      write_file "$db_dir/changelog/db.changelog-master.yaml" <<EOF
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
EOF
      ;;
    none)
      remove_path "$db_dir"
      ;;
  esac
}

write_jpa_common_sources() {
  local service_java_dir="$SERVICE_DIR/src/main/java/$NEW_PATH"
  local persistence_java_dir="$PERSISTENCE_DIR/src/main/java/$NEW_PATH/persistence"

  write_file "$service_java_dir/service/UserService.java" <<EOF
package ${PACKAGE_NAME}.service;

import ${PACKAGE_NAME}.model.Gender;
import ${PACKAGE_NAME}.model.PageResponse;
import ${PACKAGE_NAME}.model.UserCreateUpdateRequest;
import ${PACKAGE_NAME}.model.UserResponse;
import org.springframework.data.domain.PageRequest;

public interface UserService {

    Long createUser(UserCreateUpdateRequest createUserRequest);

    void updateUser(UserCreateUpdateRequest userUpdateRequest);

    void deleteUser(Long userId);

    UserResponse findUserById(Long userId);

    PageResponse findAllUsers(String criteria, Gender gender, PageRequest pageRequest);
}
EOF

  write_file "$service_java_dir/service/impl/UserServiceImpl.java" <<EOF
package ${PACKAGE_NAME}.service.impl;

import ${PACKAGE_NAME}.exception.ResourceNotFoundException;
import ${PACKAGE_NAME}.mapper.PageMapper;
import ${PACKAGE_NAME}.mapper.UserMapper;
import ${PACKAGE_NAME}.model.Gender;
import ${PACKAGE_NAME}.model.PageResponse;
import ${PACKAGE_NAME}.model.UserCreateUpdateRequest;
import ${PACKAGE_NAME}.model.UserResponse;
import ${PACKAGE_NAME}.persistence.entity.UserEntity;
import ${PACKAGE_NAME}.persistence.repository.UserRepository;
import ${PACKAGE_NAME}.persistence.repository.UserSpecifications;
import ${PACKAGE_NAME}.service.UserService;
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
EOF

  write_file "$service_java_dir/mapper/UserMapper.java" <<EOF
package ${PACKAGE_NAME}.mapper;

import ${PACKAGE_NAME}.model.Gender;
import ${PACKAGE_NAME}.model.UserCreateUpdateRequest;
import ${PACKAGE_NAME}.model.UserResponse;
import ${PACKAGE_NAME}.persistence.entity.UserEntity;
import ${PACKAGE_NAME}.persistence.enumeration.GenderEnum;
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
EOF

  write_file "$service_java_dir/mapper/PageMapper.java" <<EOF
package ${PACKAGE_NAME}.mapper;

import ${PACKAGE_NAME}.model.PageResponse;
import ${PACKAGE_NAME}.model.UserResponse;
import ${PACKAGE_NAME}.persistence.entity.UserEntity;
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
EOF

  write_file "$persistence_java_dir/repository/UserRepository.java" <<EOF
package ${PACKAGE_NAME}.persistence.repository;

import ${PACKAGE_NAME}.persistence.entity.UserEntity;
import org.springframework.stereotype.Repository;

@Repository
public interface UserRepository extends AbstractRepository<UserEntity>$(if [[ "$BLAZE_PERSISTENCE" == "true" ]]; then printf ', UserRepositoryCustom'; fi) {

}
EOF

  write_file "$persistence_java_dir/repository/UserSpecifications.java" <<EOF
package ${PACKAGE_NAME}.persistence.repository;

import ${PACKAGE_NAME}.persistence.entity.UserEntity;
import ${PACKAGE_NAME}.persistence.enumeration.GenderEnum;
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
EOF
}

configure_jpa_enabled_scaffolding() {
  local rest_java_dir="$REST_DIR/src/main/java/$NEW_PATH"
  local persistence_java_dir="$PERSISTENCE_DIR/src/main/java/$NEW_PATH/persistence"

  write_jpa_common_sources

  write_file "$rest_java_dir/config/TemplateConfig.java" <<EOF
package ${PACKAGE_NAME}.config;

import org.springframework.boot.persistence.autoconfigure.EntityScan;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.jpa.repository.config.EnableJpaAuditing;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;

@Configuration
@EnableJpaRepositories("${PACKAGE_NAME}.persistence.repository")
@EntityScan("${PACKAGE_NAME}.persistence.entity")
@EnableJpaAuditing
public class TemplateConfig {

}
EOF

  if [[ "$BLAZE_PERSISTENCE" == "true" ]]; then
    write_file "$rest_java_dir/config/BlazePersistenceConfig.java" <<EOF
package ${PACKAGE_NAME}.config;

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
@EnableEntityViews("${PACKAGE_NAME}.persistence.view")
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
EOF
  else
    remove_path "$rest_java_dir/config/BlazePersistenceConfig.java"
    remove_path "$persistence_java_dir/view"
    remove_path "$persistence_java_dir/repository/UserRepositoryCustom.java"
    remove_path "$persistence_java_dir/repository/UserRepositoryCustomImpl.java"
  fi
}

configure_jpa_disabled_scaffolding() {
  local service_java_dir="$SERVICE_DIR/src/main/java/$NEW_PATH"
  local persistence_java_dir="$PERSISTENCE_DIR/src/main/java/$NEW_PATH"
  local rest_java_dir="$REST_DIR/src/main/java/$NEW_PATH"

  remove_path "$persistence_java_dir/persistence"
  remove_path "$service_java_dir/mapper"
  remove_path "$rest_java_dir/config/TemplateConfig.java"
  remove_path "$rest_java_dir/config/BlazePersistenceConfig.java"
  remove_path "$rest_java_dir/DataLoader.java"
  remove_path "$REST_DIR/src/main/resources/db"

  write_file "$service_java_dir/service/UserService.java" <<EOF
package ${PACKAGE_NAME}.service;

import ${PACKAGE_NAME}.model.Gender;
import ${PACKAGE_NAME}.model.PageResponse;
import ${PACKAGE_NAME}.model.UserCreateUpdateRequest;
import ${PACKAGE_NAME}.model.UserResponse;
import org.springframework.data.domain.PageRequest;

public interface UserService {

    Long createUser(UserCreateUpdateRequest createUserRequest);

    void updateUser(UserCreateUpdateRequest userUpdateRequest);

    void deleteUser(Long userId);

    UserResponse findUserById(Long userId);

    PageResponse findAllUsers(String criteria, Gender gender, PageRequest pageRequest);
}
EOF

  write_file "$service_java_dir/service/impl/UserServiceImpl.java" <<EOF
package ${PACKAGE_NAME}.service.impl;

import ${PACKAGE_NAME}.exception.ResourceNotFoundException;
import ${PACKAGE_NAME}.model.Gender;
import ${PACKAGE_NAME}.model.PageResponse;
import ${PACKAGE_NAME}.model.UserCreateUpdateRequest;
import ${PACKAGE_NAME}.model.UserResponse;
import ${PACKAGE_NAME}.service.UserService;
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
EOF
}

configure_stack() {
  configure_app_pom
  configure_persistence_pom
  configure_service_pom
  configure_application_yaml
  configure_application_dev_yaml

  if [[ "$SPRING_DATA_JPA" == "true" ]]; then
    configure_migration_files
    configure_jpa_enabled_scaffolding
  else
    configure_jpa_disabled_scaffolding
  fi
}

echo ""
info "+-----------------------------------------+"
info "|  Initializing Spring Boot template      |"
info "+-----------------------------------------+"
echo ""
summary_line "Project name" "$PROJECT_NAME"
summary_line "Package" "$PACKAGE_NAME"
summary_line "Pascal case" "$PROJECT_PASCAL"
summary_line "Spring Data JPA" "$SPRING_DATA_JPA"
summary_line "Blaze-Persistence" "$BLAZE_PERSISTENCE"
summary_line "Migration tool" "$MIGRATION_TOOL"
echo ""

info "  [1/6] Replacing text in source files..."
while IFS= read -r -d '' file; do
  perl -pi \
    -e "s|\Qcom.project.template\E|${PACKAGE_NAME}|g;" \
    -e "s|com/project/template|${NEW_PATH}|g;" \
    -e "s|template-parent|${PROJECT_NAME}-parent|g;" \
    -e "s|template-app|${PROJECT_NAME}-app|g;" \
    -e "s|template-persistence|${PROJECT_NAME}-persistence|g;" \
    -e "s|template-service|${PROJECT_NAME}-service|g;" \
    -e "s|template-rest|${PROJECT_NAME}-rest|g;" \
    -e "s|template-image|${PROJECT_NAME}-image|g;" \
    -e "s|jdbc:h2:mem:template|jdbc:h2:mem:${PROJECT_NAME}|g;" \
    -e "s|image: Template:|image: ${PROJECT_PASCAL}:|g;" \
    -e "s|>Template<|>${PROJECT_PASCAL}<|g;" \
    -e "s|# Spring Boot Template|# ${PROJECT_PASCAL}|g;" \
    "$file"
done < <(find . -type f \
  \( -name "*.xml" -o -name "*.java" -o -name "*.yaml" -o -name "*.yml" \
  -o -name "*.md" -o -name "*.properties" -o -name "Dockerfile" \
  -o -name "*.imports" -o -name "*.ps1" -o -name "*.sh" \) \
  ! -path "./.git/*" ! -path "*/target/*" ! -path "./.idea/*" \
  -print0)

info "  [2/6] Renaming Java package directories..."
rename_package_dir() {
  local base="$1"
  local old_pkg_dir="${base}/${OLD_PATH}"
  local new_pkg_dir="${base}/${NEW_PATH}"
  [[ -d "$old_pkg_dir" ]] || return 0
  [[ "$old_pkg_dir" == "$new_pkg_dir" ]] && return 0

  if [[ "$new_pkg_dir" == "${old_pkg_dir}/"* ]]; then
    local staging_dir="${base}/.package-rename-${RANDOM}-$$"
    mv "$old_pkg_dir" "$staging_dir"
    mkdir -p "$(dirname "$new_pkg_dir")"
    mv "$staging_dir" "$new_pkg_dir"
  else
    mkdir -p "$(dirname "$new_pkg_dir")"
    mv "$old_pkg_dir" "$new_pkg_dir"
  fi
  safe_rmdir "${base}/com/project"
  safe_rmdir "${base}/com"
}

for module in "template-persistence" "template-service" "template-rest"; do
  for src_type in "src/main/java" "src/test/java"; do
    rename_package_dir "template-app/${module}/${src_type}"
  done
done

info "  [3/6] Renaming module directories..."
for module in "template-persistence" "template-service" "template-rest" "template-image"; do
  old_dir="template-app/${module}"
  new_name="${PROJECT_NAME}-${module#template-}"
  [[ -d "$old_dir" && "$old_dir" != "template-app/${new_name}" ]] && mv "$old_dir" "template-app/${new_name}"
done
[[ -d "template-app" && "template-app" != "${PROJECT_NAME}-app" ]] && mv "template-app" "${PROJECT_NAME}-app"

info "  [4/6] Configuring selected starter stack..."
configure_stack

echo ""
info "  [5/6] Additional service modules"
echo ""
MODULE_COUNT=0
if (( MODULE_COUNT_EXPLICIT )); then
  [[ "$MODULE_COUNT_INPUT" =~ ^[0-9]+$ ]] || error "Extra service modules must be a whole number."
  MODULE_COUNT=$MODULE_COUNT_INPUT
else
  read -rp "  How many extra service modules do you want to create? (0 to skip): " MODULE_COUNT_INPUT
  if [[ "$MODULE_COUNT_INPUT" =~ ^[0-9]+$ ]]; then
    MODULE_COUNT=$MODULE_COUNT_INPUT
  fi
fi

if [[ $MODULE_COUNT -gt 10 ]]; then
  warn "  Clamping to 10 modules maximum."
  MODULE_COUNT=10
fi

if [[ $MODULE_COUNT -gt 0 ]]; then
  APP_POM="${PROJECT_NAME}-app/pom.xml"
  RESERVED=("app" "parent" "rest" "persistence" "service" "image" "core" "common" "web" "api")
  CREATED_MODS=()
  EXISTING_SVC_DIR="${PROJECT_NAME}-app/${PROJECT_NAME}-service"

  if [[ -d "$EXISTING_SVC_DIR" ]]; then
    echo ""
    info "  Rename existing '${PROJECT_NAME}-service' module?"
    echo "  Since you are adding extra modules, consider giving the existing"
    echo "  service module a specific name (e.g. 'user', 'user-mgmt')."
    echo ""
    read -rp "  New name for '${PROJECT_NAME}-service' [Enter to keep as 'service']: " NEW_SVC_NAME
    NEW_SVC_NAME=$(echo "$NEW_SVC_NAME" | tr '[:upper:]' '[:lower:]' | tr -d ' ')

    if [[ -n "$NEW_SVC_NAME" && "$NEW_SVC_NAME" != "service" ]]; then
      SVC_VALID=true
      if [[ ! "$NEW_SVC_NAME" =~ ^[a-z][a-z0-9-]*$ ]]; then
        warn "  Invalid name '$NEW_SVC_NAME' — keeping '${PROJECT_NAME}-service' as-is."
        SVC_VALID=false
      elif [[ ${#NEW_SVC_NAME} -lt 2 || ${#NEW_SVC_NAME} -gt 50 ]]; then
        warn "  Name must be 2-50 characters — keeping '${PROJECT_NAME}-service' as-is."
        SVC_VALID=false
      elif [[ "$NEW_SVC_NAME" == *- || "$NEW_SVC_NAME" == *--* ]]; then
        warn "  Name must not end with a hyphen or contain '--' — keeping '${PROJECT_NAME}-service' as-is."
        SVC_VALID=false
      else
        for r in "${RESERVED[@]}"; do
          if [[ "$NEW_SVC_NAME" == "$r" ]]; then
            warn "  '$NEW_SVC_NAME' is a reserved name — keeping '${PROJECT_NAME}-service' as-is."
            SVC_VALID=false
            break
          fi
        done
      fi

      if $SVC_VALID && [[ -d "${PROJECT_NAME}-app/${PROJECT_NAME}-${NEW_SVC_NAME}" ]]; then
        warn "  Directory '${PROJECT_NAME}-app/${PROJECT_NAME}-${NEW_SVC_NAME}' already exists — keeping as-is."
        SVC_VALID=false
      fi

      if $SVC_VALID; then
        NEW_SVC_FULL="${PROJECT_NAME}-${NEW_SVC_NAME}"
        NEW_SVC_DIR="${PROJECT_NAME}-app/${NEW_SVC_FULL}"

        for f in "${PROJECT_NAME}-app/pom.xml" "${PROJECT_NAME}-app/${PROJECT_NAME}-rest/pom.xml" "${EXISTING_SVC_DIR}/pom.xml"; do
          [[ -f "$f" ]] && perl -i -0pe "s|\Q${PROJECT_NAME}-service\E|${NEW_SVC_FULL}|g" "$f"
        done

        mv "$EXISTING_SVC_DIR" "$NEW_SVC_DIR"
        success "  Renamed '${PROJECT_NAME}-service' -> '${NEW_SVC_FULL}'"
        RESERVED+=("$NEW_SVC_NAME")
        CREATED_MODS+=("$NEW_SVC_NAME")
      fi
    else
      info "  Keeping '${PROJECT_NAME}-service' as-is."
    fi
  fi

  for ((i=1; i<=MODULE_COUNT; i++)); do
    echo ""
    read -rp "  Module $i of $MODULE_COUNT — name (e.g. payment, notification): " MOD_NAME
    MOD_NAME=$(echo "$MOD_NAME" | tr '[:upper:]' '[:lower:]' | tr -d ' ')

    if [[ -z "$MOD_NAME" ]]; then
      warn "  Skipping module $i — name cannot be empty."
      continue
    fi
    if [[ ! "$MOD_NAME" =~ ^[a-z][a-z0-9-]*$ ]]; then
      warn "  Skipping '$MOD_NAME' — only lowercase letters, digits, and hyphens allowed."
      continue
    fi
    if [[ ${#MOD_NAME} -lt 2 || ${#MOD_NAME} -gt 50 ]]; then
      warn "  Skipping '$MOD_NAME' — name must be 2–50 characters."
      continue
    fi
    if [[ "$MOD_NAME" == *- || "$MOD_NAME" == *--* ]]; then
      warn "  Skipping '$MOD_NAME' — must not end with a hyphen or contain consecutive hyphens."
      continue
    fi
    IS_RESERVED=false
    for r in "${RESERVED[@]}"; do [[ "$MOD_NAME" == "$r" ]] && IS_RESERVED=true && break; done
    if $IS_RESERVED; then
      warn "  Skipping '$MOD_NAME' — reserved name. Reserved: ${RESERVED[*]}."
      continue
    fi
    ALREADY_CREATED=false
    for c in "${CREATED_MODS[@]:-}"; do [[ "$MOD_NAME" == "$c" ]] && ALREADY_CREATED=true && break; done
    if $ALREADY_CREATED; then
      warn "  Skipping '$MOD_NAME' — already created in this session."
      continue
    fi

    FULL_MOD="${PROJECT_NAME}-${MOD_NAME}"
    MOD_DIR="${PROJECT_NAME}-app/${FULL_MOD}"

    if [[ -d "$MOD_DIR" ]]; then
      warn "  Skipping '$MOD_NAME' — directory '$MOD_DIR' already exists."
      continue
    fi
    if grep -q "<module>${FULL_MOD}</module>" "$APP_POM" 2>/dev/null; then
      warn "  Skipping '$MOD_NAME' — already registered in app pom.xml."
      continue
    fi

    mkdir -p "${MOD_DIR}/src/main/java/${NEW_PATH}" "${MOD_DIR}/src/test/java/${NEW_PATH}"
    write_file "${MOD_DIR}/pom.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <parent>
        <artifactId>${PROJECT_NAME}-app</artifactId>
        <groupId>${PACKAGE_NAME}</groupId>
        <version>1.0-SNAPSHOT</version>
    </parent>

    <artifactId>${FULL_MOD}</artifactId>

    <dependencies>
        <dependency>
            <groupId>${PACKAGE_NAME}</groupId>
            <artifactId>${PROJECT_NAME}-persistence</artifactId>
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
EOF

    perl -i -0pe "s|([ \t]*</modules>)|\t\t<module>${FULL_MOD}</module>\n\$1|" "$APP_POM"
    success "  Created: $FULL_MOD"
    CREATED_MODS+=("$MOD_NAME")
  done

  if [[ ${#CREATED_MODS[@]} -gt 0 ]]; then
    echo ""
    info "  Modules created: $(IFS=', '; echo "${CREATED_MODS[*]}")"
  fi
fi

echo ""
info "  [6/6] Cleaning generated output and initializing git..."
while IFS= read -r -d '' target_dir; do
  rm -rf -- "$target_dir"
done < <(find . -type d -name target -prune -print0)

for script_path in bootstrap.ps1 bootstrap.sh init.sh init.ps1; do
  [[ -f "$script_path" ]] && rm -f -- "$script_path"
done

rm -rf -- .git
git init -q
git add -A
git -c user.name="Spring Boot Starter" -c user.email="spring-boot-starter@localhost" \
  commit -q -m "chore: initial project from spring-boot-starter"
success "  Git repository initialized with a clean history (no remote)."

echo ""
success "  Done!  Project '${PROJECT_NAME}' is ready."
echo ""
echo "  Next steps:"
echo "    ./mvnw clean install"
echo "    cd ${PROJECT_NAME}-app/${PROJECT_NAME}-rest && ../../mvnw spring-boot:run"
echo ""
echo "    Swagger UI  ->  http://localhost:8080/swagger-ui/index.html"
if [[ "$SPRING_DATA_JPA" == "true" ]]; then
  echo "    H2 Console  ->  http://localhost:8080/h2-console"
fi
echo ""
