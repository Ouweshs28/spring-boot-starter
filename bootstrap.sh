#!/usr/bin/env bash
# Spring Boot Starter - Bootstrap
# Run with: bash <(curl -fsSL https://raw.githubusercontent.com/Ouweshs28/spring-boot-starter/main/bootstrap.sh)

set -euo pipefail

REPO_URL="https://github.com/Ouweshs28/spring-boot-starter.git"

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}$*${NC}"; }
success() { echo -e "${GREEN}$*${NC}"; }
error()   { echo -e "${RED}ERROR: $*${NC}" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage: ./bootstrap.sh [options]
  -p, --project-name          Lowercase, hyphenated name (e.g. my-app)
  -n, --package-name          Java base package (e.g. com.example.myapp)
  -m, --migration-tool        flyway | liquibase | none
  -j, --spring-data-jpa       true | false
  -b, --blaze-persistence     true | false
  -s, --extra-service-modules Number of extra service modules to scaffold
  -h, --help                  Show this help message
EOF
}

require_value() {
  [[ $# -ge 2 && -n "$2" ]] || error "Missing value for $1"
}

PROJECT_NAME=""
PACKAGE_NAME=""
MIGRATION_TOOL=""
SPRING_DATA_JPA=""
BLAZE_PERSISTENCE=""
EXTRA_SERVICE_MODULES=""
MIGRATION_EXPLICIT=0
JPA_EXPLICIT=0
BLAZE_EXPLICIT=0
EXTRA_MODULES_EXPLICIT=0

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
      EXTRA_SERVICE_MODULES="$2"
      EXTRA_MODULES_EXPLICIT=1
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

echo ""
info "+------------------------------------------+"
info "|   Spring Boot Starter - Project Setup    |"
info "+------------------------------------------+"
echo ""

[[ -z "$PROJECT_NAME" ]] && read -rp "Project name (e.g. my-app): " PROJECT_NAME
[[ -z "$PACKAGE_NAME" ]] && read -rp "Base package  (e.g. com.example.myapp): " PACKAGE_NAME

# ---- Validate ----------------------------------------------------------------
[[ "$PROJECT_NAME" =~ ^[a-z][a-z0-9-]*$ ]] \
  || error "Project name must be lowercase letters, digits, and hyphens."
[[ "$PACKAGE_NAME" =~ ^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*)*$ ]] \
  || error "Package must be a valid Java package (e.g. com.example.myapp)."

# ---- Clone -------------------------------------------------------------------
[[ -d "$PROJECT_NAME" ]] && error "Directory '$PROJECT_NAME' already exists."

echo ""
info "Cloning template into '$PROJECT_NAME'..."
git clone "$REPO_URL" "$PROJECT_NAME"
cd "$PROJECT_NAME"

# ---- Init --------------------------------------------------------------------
echo ""
info "Running init script..."
chmod +x init.sh
INIT_ARGS=(--project-name "$PROJECT_NAME" --package-name "$PACKAGE_NAME")
(( MIGRATION_EXPLICIT )) && INIT_ARGS+=(--migration-tool "$MIGRATION_TOOL")
(( JPA_EXPLICIT )) && INIT_ARGS+=(--spring-data-jpa "$SPRING_DATA_JPA")
(( BLAZE_EXPLICIT )) && INIT_ARGS+=(--blaze-persistence "$BLAZE_PERSISTENCE")
(( EXTRA_MODULES_EXPLICIT )) && INIT_ARGS+=(--extra-service-modules "$EXTRA_SERVICE_MODULES")
./init.sh "${INIT_ARGS[@]}"

echo ""
success "Your project '$PROJECT_NAME' is ready in ./$PROJECT_NAME"