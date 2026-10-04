#!/usr/bin/env bash
# -------------------------------------------------------------------------------
# add-module.sh  —  Add a new service module to this Spring Boot project
#
# Usage:
#   ./add-module.sh --module-name <name> [options]
#
# Examples:
#   ./add-module.sh --module-name payment
#   ./add-module.sh --module-name payment -y   # non-interactive
#   ./add-module.sh                            # interactive — will prompt for module name
# -------------------------------------------------------------------------------
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}$*${NC}"; }
success() { echo -e "${GREEN}$*${NC}"; }
warn()    { echo -e "${YELLOW}$*${NC}"; }
error()   { echo -e "${RED}ERROR: $*${NC}" >&2; exit 1; }

MODULE_NAME=""
CONFIRM=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --module-name|-m) MODULE_NAME="$2"; shift 2 ;;
    -y|--yes) CONFIRM="y"; shift ;;
    -h|--help)
      echo "Usage: ./add-module.sh --module-name <name> [options]"
      echo "  -m, --module-name   Lowercase, hyphenated module name (e.g. payment)"
      echo "  -y, --yes           Skip confirmation prompt"
      exit 0 ;;
    *) error "Unknown argument: $1" ;;
  esac
done

echo ""
info "+------------------------------------------+"
info "|        Add New Service Module            |"
info "+------------------------------------------+"
echo ""

# ---- Validate project root ---------------------------------------------------
[[ -f "pom.xml" ]] || error "pom.xml not found. Run this script from the project root directory."

# ---- Read project context from root pom.xml ----------------------------------
# Extract the project's own <groupId> and <artifactId> after the </parent> block.
GROUP_ID=$(perl -0777 -ne 'if (m!</parent>(.*)!s) { my $tail = $1; print $1 if $tail =~ m!<groupId>\s*([^<]+)</groupId>!; }' pom.xml | tr -d ' \t\r\n')
ROOT_ARTIFACT=$(perl -0777 -ne 'if (m!</parent>(.*)!s) { my $tail = $1; print $1 if $tail =~ m!<artifactId>\s*([^<]+)</artifactId>!; }' pom.xml | tr -d ' \t\r\n')

[[ -n "$GROUP_ID" ]]     || error "Could not read groupId from pom.xml."
[[ -n "$ROOT_ARTIFACT" ]] || error "Could not read artifactId from pom.xml."

[[ "$ROOT_ARTIFACT" == *-parent ]] \
  || error "Root artifactId '$ROOT_ARTIFACT' does not end with '-parent'. Are you in the project root?"

PROJECT_NAME="${ROOT_ARTIFACT%-parent}"   # e.g. template
APP_DIR="${PROJECT_NAME}-app"
APP_POM="${APP_DIR}/pom.xml"
GROUP_PATH="${GROUP_ID//.//}"             # e.g. com/project/template

[[ -d "$APP_DIR" ]] || error "App directory '$APP_DIR' not found. Are you in the project root?"
[[ -f "$APP_POM" ]] || error "'$APP_POM' not found."

echo "  Detected project  :  $PROJECT_NAME"
echo "  Detected group ID :  $GROUP_ID"
echo ""

# ---- Prompt if missing -------------------------------------------------------
[[ -z "$MODULE_NAME" ]] && read -rp "Module name (e.g. payment, notification, reporting): " MODULE_NAME

# ---- Validate module name ----------------------------------------------------
MODULE_NAME=$(echo "$MODULE_NAME" | tr '[:upper:]' '[:lower:]' | tr -d ' ')

[[ -n "$MODULE_NAME" ]] \
  || error "Module name cannot be empty."

[[ "$MODULE_NAME" =~ ^[a-z][a-z0-9-]*$ ]] \
  || error "Module name must start with a letter and contain only lowercase letters, digits, and hyphens."

[[ ${#MODULE_NAME} -ge 2 ]] \
  || error "Module name must be at least 2 characters long."

[[ ${#MODULE_NAME} -le 50 ]] \
  || error "Module name must not exceed 50 characters."

[[ "$MODULE_NAME" != *- ]] \
  || error "Module name must not end with a hyphen."

[[ "$MODULE_NAME" != *--* ]] \
  || error "Module name must not contain consecutive hyphens."

RESERVED=("app" "parent" "rest" "persistence" "service" "image" "core" "common" "web" "api")
for r in "${RESERVED[@]}"; do
  [[ "$MODULE_NAME" != "$r" ]] \
    || error "Module name '$MODULE_NAME' is reserved. Reserved names: ${RESERVED[*]}."
done

FULL_MODULE="${PROJECT_NAME}-${MODULE_NAME}"
MODULE_DIR="${APP_DIR}/${FULL_MODULE}"

[[ ! -d "$MODULE_DIR" ]] \
  || error "Directory '$MODULE_DIR' already exists. Choose a different name or remove the directory first."

# ---- Check not already registered in app pom.xml ----------------------------
grep -q "<module>${FULL_MODULE}</module>" "$APP_POM" \
  && error "Module '$FULL_MODULE' is already registered in $APP_POM."

# ---- Confirm -----------------------------------------------------------------
if [[ -z "$CONFIRM" ]]; then
  echo ""
  echo "  New module   :  $FULL_MODULE"
  echo "  Location     :  $MODULE_DIR"
  echo "  Package      :  ${GROUP_ID}.${MODULE_NAME//-/}"
  echo ""
  read -rp "  Proceed? [Y/n] " CONFIRM
  CONFIRM="${CONFIRM:-y}"
  [[ "$CONFIRM" =~ ^[Yy]$ ]] || { warn "  Aborted."; exit 0; }
fi

# ---- [1/3] Create directory structure ----------------------------------------
echo ""
info "  [1/3] Creating directory structure..."

mkdir -p "${MODULE_DIR}/src/main/java/${GROUP_PATH}"
mkdir -p "${MODULE_DIR}/src/test/java/${GROUP_PATH}"

success "         + ${MODULE_DIR}/src/main/java/${GROUP_PATH}"
success "         + ${MODULE_DIR}/src/test/java/${GROUP_PATH}"

# ---- [2/3] Generate pom.xml --------------------------------------------------
info "  [2/3] Generating pom.xml..."

cat > "${MODULE_DIR}/pom.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <parent>
        <artifactId>${APP_DIR}</artifactId>
        <groupId>${GROUP_ID}</groupId>
        <version>1.0-SNAPSHOT</version>
    </parent>

    <artifactId>${FULL_MODULE}</artifactId>

    <dependencies>
        <!-- Depend on persistence for entities / repositories -->
        <dependency>
            <groupId>${GROUP_ID}</groupId>
            <artifactId>${PROJECT_NAME}-persistence</artifactId>
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
            <artifactId>swagger-annotations-jakarta</artifactId>
        </dependency>

        <!-- Test -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>
</project>
EOF

success "         + ${MODULE_DIR}/pom.xml"

# ---- [3/3] Register in app pom.xml ------------------------------------------
info "  [3/3] Registering module in ${APP_POM}..."

# Insert <module> before </modules>
perl -i -0pe "s|([ \t]*</modules>)|\t\t<module>${FULL_MODULE}</module>\n\$1|" "$APP_POM"

# Insert <dependency> in dependencyManagement
NEW_DEP="\t\t<dependency>\n\t\t\t<groupId>${GROUP_ID}</groupId>\n\t\t\t<artifactId>${FULL_MODULE}</artifactId>\n\t\t\t<version>\${project.version}</version>\n\t\t</dependency>\n"

dep_inserted=false
for anchor in "<!-- External dependencies -->" "<!-- Lombok -->" "<!-- Blaze-Persistence BOM"; do
  if grep -qF "$anchor" "$APP_POM"; then
    perl -i -0pe "s|([ \t]*\Q$anchor\E)|${NEW_DEP}\$1|" "$APP_POM"
    dep_inserted=true
    break
  fi
done

if [[ "$dep_inserted" == "false" ]]; then
  if perl -0777 -ne 'exit 0 if m!<dependencyManagement>.*?</dependencies>\s*</dependencyManagement>!s; exit 1' "$APP_POM"; then
    perl -i -0777 -pe "s|(<dependencyManagement>.*?<dependencies>.*?)([ \t]*)(</dependencies>\s*</dependencyManagement>)|\$1${NEW_DEP}\$2\$3|s" "$APP_POM"
    dep_inserted=true
  fi
fi

if [[ "$dep_inserted" == "true" ]]; then
  success "         + ${APP_POM}  (modules + dependencyManagement updated)"
else
  warn ""
  warn "  WARNING: Could not locate suitable insertion point in <dependencyManagement> in ${APP_POM}."
  warn "  Please manually add the following inside <dependencyManagement><dependencies>:"
  warn ""
  warn "    <dependency>"
  warn "        <groupId>${GROUP_ID}</groupId>"
  warn "        <artifactId>${FULL_MODULE}</artifactId>"
  warn "        <version>\${project.version}</version>"
  warn "    </dependency>"
  warn ""
  success "         + ${APP_POM}  (modules updated)"
fi

# Update Dockerfile if present so Docker multi-stage build stays in sync
DOCKERFILE="${APP_DIR}/${PROJECT_NAME}-image/src/main/resources/docker/app/Dockerfile"
if [[ -f "$DOCKERFILE" ]]; then
  if ! grep -q "${APP_DIR}/${FULL_MODULE}/pom.xml" "$DOCKERFILE"; then
    perl -i -0pe "s|([ \t]*COPY [^\r\n]*-rest/pom\.xml[^\r\n]*)|\\\$1\nCOPY ${APP_DIR}/${FULL_MODULE}/pom.xml          ${APP_DIR}/${FULL_MODULE}/|" "$DOCKERFILE"
    perl -i -0pe "s|([ \t]*COPY [^\r\n]*-rest/src[^\r\n]*)|\\\$1\nCOPY ${APP_DIR}/${FULL_MODULE}/src         ${APP_DIR}/${FULL_MODULE}/src|" "$DOCKERFILE"
    success "         + ${DOCKERFILE}  (Docker build updated)"
  fi
fi

# ---- Done -------------------------------------------------------------------
echo ""
success "  Module '${FULL_MODULE}' created successfully!"
echo ""
echo "  Next steps:"
echo ""
echo "  1. Add your service interfaces and implementations under:"
echo "       ${MODULE_DIR}/src/main/java/${GROUP_PATH}"
echo ""
echo "  2. To consume this module from ${PROJECT_NAME}-rest, add to"
echo "     ${APP_DIR}/${PROJECT_NAME}-rest/pom.xml:"
echo ""
echo "       <dependency>"
echo "           <groupId>${GROUP_ID}</groupId>"
echo "           <artifactId>${FULL_MODULE}</artifactId>"
echo "       </dependency>"
echo ""
echo "  3. To consume this module from another service module, add the"
echo "     same block to that module's pom.xml."
echo ""
echo "  4. Rebuild the project:"
echo "       ./mvnw clean verify"
echo ""
