#!/usr/bin/env bash
# Spring Boot Starter - Bootstrap
# Run with: bash <(curl -fsSL https://raw.githubusercontent.com/Ouweshs28/spring-boot-starter/main/bootstrap.sh)

set -euo pipefail

REPO_URL="git@github.com:Ouweshs28/spring-boot-starter.git"

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}$*${NC}"; }
success() { echo -e "${GREEN}$*${NC}"; }
error()   { echo -e "${RED}ERROR: $*${NC}" >&2; exit 1; }

echo ""
info "+------------------------------------------+"
info "|   Spring Boot Starter - Project Setup    |"
info "+------------------------------------------+"
echo ""

# ---- Prompt ------------------------------------------------------------------
read -rp "Project name (e.g. my-app): " PROJECT_NAME
read -rp "Base package  (e.g. com.example.myapp): " PACKAGE_NAME

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
./init.sh --project-name "$PROJECT_NAME" --package-name "$PACKAGE_NAME"

echo ""
success "Your project '$PROJECT_NAME' is ready in ./$PROJECT_NAME"