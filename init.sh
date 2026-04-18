#!/usr/bin/env bash
# -------------------------------------------------------------------------------
# init.sh  -  Bootstrap this Spring Boot template into your own project
#
# Usage:
#   ./init.sh --project-name <name> --package-name <package>
#
# Examples:
#   ./init.sh --project-name my-app --package-name com.example.myapp
#   ./init.sh                        # interactive - will prompt for both values
# -------------------------------------------------------------------------------
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}$*${NC}"; }
success() { echo -e "${GREEN}$*${NC}"; }
warn()    { echo -e "${YELLOW}$*${NC}"; }
error()   { echo -e "${RED}ERROR: $*${NC}" >&2; exit 1; }

# ---- Parse arguments ----------------------------------------------------------
PROJECT_NAME=""
PACKAGE_NAME=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --project-name|-p) PROJECT_NAME="$2"; shift 2 ;;
    --package-name|-n) PACKAGE_NAME="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: ./init.sh --project-name <name> --package-name <package>"
      echo "  -p, --project-name   Lowercase, hyphenated name  (e.g. my-app)"
      echo "  -n, --package-name   Java base package            (e.g. com.example.myapp)"
      exit 0 ;;
    *) error "Unknown argument: $1" ;;
  esac
done

# ---- Prompt for missing values ------------------------------------------------
[[ -z "$PROJECT_NAME" ]] && read -rp "Project name (e.g. my-app): " PROJECT_NAME
[[ -z "$PACKAGE_NAME" ]] && read -rp "Base package  (e.g. com.example.myapp): " PACKAGE_NAME

# ---- Validate -----------------------------------------------------------------
[[ "$PROJECT_NAME" =~ ^[a-z][a-z0-9-]*$ ]] \
  || error "Project name must be lowercase and contain only letters, digits, and hyphens."
[[ "$PACKAGE_NAME" =~ ^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*)*$ ]] \
  || error "Package name must be a valid Java package (e.g. com.example.myapp)."

# ---- Derive values ------------------------------------------------------------
OLD_GROUP="com.project.template"
OLD_PATH="com/project/template"
NEW_PATH="${PACKAGE_NAME//.//}"

# PascalCase: my-project -> MyProject  (bash 3+ and 4+ compatible via perl)
PROJECT_PASCAL=$(echo "$PROJECT_NAME" | perl -pe 's/(^|-)([a-z])/uc($2)/ge; s/-//g')

echo ""
info "+-----------------------------------------+"
info "|  Initializing Spring Boot template       |"
info "+-----------------------------------------+"
echo ""
echo "  Project name : $PROJECT_NAME"
echo "  Package      : $PACKAGE_NAME"
echo "  Pascal case  : $PROJECT_PASCAL"
echo ""

# ---- Helper: safe empty-dir removal -------------------------------------------
safe_rmdir() { rmdir "$1" 2>/dev/null || true; }

# ---- [1/5] Replace text in all source files -----------------------------------
info "  [1/5] Replacing text in source files..."

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
  -o -name "*.md"  -o -name "*.properties" -o -name "Dockerfile" \
  -o -name "*.imports" \) \
  ! -path "./.git/*" ! -path "*/target/*" ! -path "./.idea/*" \
  -print0)

# ---- [2/5] Rename Java package directories ------------------------------------
info "  [2/5] Renaming Java package directories..."

rename_package_dir() {
  local base="$1"
  local old_pkg_dir="${base}/${OLD_PATH}"
  local new_pkg_dir="${base}/${NEW_PATH}"
  [[ -d "$old_pkg_dir" ]] || return 0
  mkdir -p "$(dirname "$new_pkg_dir")"
  mv "$old_pkg_dir" "$new_pkg_dir"
  safe_rmdir "${base}/com/project"
  safe_rmdir "${base}/com"
}

for module in "template-persistence" "template-service" "template-rest"; do
  for src_type in "src/main/java" "src/test/java"; do
    rename_package_dir "template-app/${module}/${src_type}"
  done
done

# ---- [3/5] Rename module directories ------------------------------------------
info "  [3/5] Renaming module directories..."

for module in "template-persistence" "template-service" "template-rest" "template-image"; do
  old_dir="template-app/${module}"
  new_name="${PROJECT_NAME}-${module#template-}"
  [[ -d "$old_dir" ]] && mv "$old_dir" "template-app/${new_name}"
done
[[ -d "template-app" ]] && mv "template-app" "${PROJECT_NAME}-app"

# ---- [4/5] Create additional service modules ----------------------------------
echo ""
info "  [4/5] Additional service modules"
echo ""
read -rp "  How many extra service modules do you want to create? (0 to skip): " MODULE_COUNT_INPUT
MODULE_COUNT=0
if [[ "$MODULE_COUNT_INPUT" =~ ^[0-9]+$ ]]; then
  MODULE_COUNT=$MODULE_COUNT_INPUT
  if [[ $MODULE_COUNT -gt 10 ]]; then
    warn "  Clamping to 10 modules maximum."
    MODULE_COUNT=10
  fi
fi

if [[ $MODULE_COUNT -gt 0 ]]; then
  APP_POM="${PROJECT_NAME}-app/pom.xml"
  RESERVED=("app" "parent" "rest" "persistence" "service" "image" "core" "common" "web" "api")
  CREATED_MODS=()

  # --- Rename existing service module for consistency -------------------------
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
            SVC_VALID=false; break
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

        # Update artifactId references in affected pom files
        for f in \
          "${PROJECT_NAME}-app/pom.xml" \
          "${PROJECT_NAME}-app/${PROJECT_NAME}-rest/pom.xml" \
          "${EXISTING_SVC_DIR}/pom.xml"; do
          [[ -f "$f" ]] && perl -i -0pe "s|\Q${PROJECT_NAME}-service\E|${NEW_SVC_FULL}|g" "$f"
        done

        # Rename the directory
        mv "$EXISTING_SVC_DIR" "$NEW_SVC_DIR"
        success "  Renamed '${PROJECT_NAME}-service' -> '${NEW_SVC_FULL}'"

        # Prevent the same name being used for a new module
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

    # --- Validate --------------------------------------------------------------
    if [[ -z "$MOD_NAME" ]]; then
      warn "  Skipping module $i — name cannot be empty."; continue
    fi
    if [[ ! "$MOD_NAME" =~ ^[a-z][a-z0-9-]*$ ]]; then
      warn "  Skipping '$MOD_NAME' — only lowercase letters, digits, and hyphens allowed."; continue
    fi
    if [[ ${#MOD_NAME} -lt 2 || ${#MOD_NAME} -gt 50 ]]; then
      warn "  Skipping '$MOD_NAME' — name must be 2–50 characters."; continue
    fi
    if [[ "$MOD_NAME" == *- || "$MOD_NAME" == *--* ]]; then
      warn "  Skipping '$MOD_NAME' — must not end with a hyphen or contain consecutive hyphens."; continue
    fi
    IS_RESERVED=false
    for r in "${RESERVED[@]}"; do [[ "$MOD_NAME" == "$r" ]] && IS_RESERVED=true && break; done
    if $IS_RESERVED; then
      warn "  Skipping '$MOD_NAME' — reserved name. Reserved: ${RESERVED[*]}."; continue
    fi
    ALREADY_CREATED=false
    for c in "${CREATED_MODS[@]:-}"; do [[ "$MOD_NAME" == "$c" ]] && ALREADY_CREATED=true && break; done
    if $ALREADY_CREATED; then
      warn "  Skipping '$MOD_NAME' — already created in this session."; continue
    fi

    FULL_MOD="${PROJECT_NAME}-${MOD_NAME}"
    MOD_DIR="${PROJECT_NAME}-app/${FULL_MOD}"

    if [[ -d "$MOD_DIR" ]]; then
      warn "  Skipping '$MOD_NAME' — directory '$MOD_DIR' already exists."; continue
    fi
    if grep -q "<module>${FULL_MOD}</module>" "$APP_POM" 2>/dev/null; then
      warn "  Skipping '$MOD_NAME' — already registered in app pom.xml."; continue
    fi

    # --- Create dirs -----------------------------------------------------------
    mkdir -p "${MOD_DIR}/src/main/java/${NEW_PATH}"
    mkdir -p "${MOD_DIR}/src/test/java/${NEW_PATH}"

    # --- Generate pom.xml ------------------------------------------------------
    cat > "${MOD_DIR}/pom.xml" <<EOF
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
            <artifactId>swagger-annotations</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>
</project>
EOF

    # --- Register in app pom.xml -----------------------------------------------
    perl -i -0pe "s|([ \t]*</modules>)|\t\t<module>${FULL_MOD}<\/module>\n\$1|" "$APP_POM"

    if grep -q '<!-- Lombok -->' "$APP_POM"; then
      NEW_DEP="\t\t<dependency>\n\t\t\t<groupId>${PACKAGE_NAME}<\/groupId>\n\t\t\t<artifactId>${FULL_MOD}<\/artifactId>\n\t\t\t<version>\\\${project.version}<\/version>\n\t\t<\/dependency>\n\t\t"
      perl -i -0pe "s|([ \t]*<!-- Lombok -->)|${NEW_DEP}\$1|" "$APP_POM"
    fi

    success "  Created: $FULL_MOD"
    CREATED_MODS+=("$MOD_NAME")
  done

  if [[ ${#CREATED_MODS[@]} -gt 0 ]]; then
    echo ""
    info "  Modules created: $(IFS=', '; echo "${CREATED_MODS[*]}")"
  fi
fi

# ---- [5/5] Reset git history and remove remote --------------------------------
echo ""
info "  [5/5] Resetting git history..."
rm -rf .git
git init -q
git add -A
git commit -q -m "chore: initial project from spring-boot-starter"
success "  Git repository initialized with a clean history (no remote)."

# ---- Remove bootstrap / init scripts ------------------------------------------
info "  Cleaning up setup scripts..."
for s in bootstrap.ps1 bootstrap.sh init.ps1 init.sh; do
  [[ -f "$s" ]] && rm -f "$s"
done
success "  Setup scripts removed."

# ---- Done ---------------------------------------------------------------------
echo ""
success "  Done!  Project '${PROJECT_NAME}' is ready."
echo ""
echo "  Next steps:"
echo "    mvn clean install"
echo "    cd ${PROJECT_NAME}-app/${PROJECT_NAME}-rest && mvn spring-boot:run"
echo ""
echo "    Swagger UI  ->  http://localhost:8080/swagger-ui/index.html"
echo "    H2 Console  ->  http://localhost:8080/h2-console"
echo ""

