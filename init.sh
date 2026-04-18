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

# ---- [1/4] Replace text in all source files -----------------------------------
info "  [1/4] Replacing text in source files..."

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

# ---- [2/4] Rename Java package directories ------------------------------------
info "  [2/4] Renaming Java package directories..."

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

# ---- [3/4] Rename module directories ------------------------------------------
info "  [3/4] Renaming module directories..."

for module in "template-persistence" "template-service" "template-rest" "template-image"; do
  old_dir="template-app/${module}"
  new_name="${PROJECT_NAME}-${module#template-}"
  [[ -d "$old_dir" ]] && mv "$old_dir" "template-app/${new_name}"
done
[[ -d "template-app" ]] && mv "template-app" "${PROJECT_NAME}-app"

# ---- [4/4] Reset git history --------------------------------------------------
echo ""
warn "  [4/4] Reset git history?"
warn "        This removes the template's commit history and starts fresh."
read -rp "        Reset? [y/N] " RESET_GIT
if [[ "$RESET_GIT" =~ ^[Yy]$ ]]; then
  rm -rf .git
  git init -q
  git add -A
  git commit -q -m "chore: initial project from spring-boot-starter"
  success "  Git repository re-initialized with a clean initial commit."
fi

# ---- [5/5] Remove bootstrap / init scripts ------------------------------------
info "  [5/5] Cleaning up setup scripts..."
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

