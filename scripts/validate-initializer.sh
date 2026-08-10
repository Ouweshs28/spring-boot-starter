#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
validation_root="$repository_root/.test-work/bash-validation"

fail_test() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

write_step() {
  printf '==> %s\n' "$1"
}

assert_file_contains() {
  local path="$1"
  local expected="$2"
  grep -Fq -- "$expected" "$path" || fail_test "Expected '$expected' in $path"
}

assert_file_not_contains() {
  local path="$1"
  local unexpected="$2"
  ! grep -Fq -- "$unexpected" "$path" || fail_test "Did not expect '$unexpected' in $path"
}

assert_path_exists() {
  [[ -e "$1" ]] || fail_test "Expected path to exist: $1"
}

assert_path_missing() {
  [[ ! -e "$1" ]] || fail_test "Expected path to be absent: $1"
}

assert_git_clean() {
  local status
  status="$(git -C "$1" --no-pager status --short)"
  [[ -z "$status" ]] || fail_test "Expected clean git status in $1. Found:
$status"
}

new_working_copy() {
  local name="$1"
  local copy_dir="$validation_root/$name"
  local item

  rm -rf -- "$copy_dir"
  mkdir -p -- "$copy_dir"
  while IFS= read -r -d '' item; do
    cp -a -- "$item" "$copy_dir/"
  done < <(find "$repository_root" -mindepth 1 -maxdepth 1 \
    ! -name .git ! -name .idea ! -name .build-tools ! -name .test-work ! -name target -print0)
  printf '%s\n' "$copy_dir"
}

invoke_initializer() {
  local working_directory="$1"
  shift
  (
    cd "$working_directory"
    bash ./init.sh "$@"
  )
}

invoke_maven_verify() {
  local working_directory="$1"
  (
    cd "$working_directory"
    ./mvnw clean verify --no-transfer-progress
  )
}

cleanup() {
  rm -rf -- "$validation_root"
  rmdir -- "$repository_root/.test-work" 2>/dev/null || true
}
trap cleanup EXIT

rm -rf -- "$validation_root"
mkdir -p -- "$validation_root"

write_step 'Scenario 1: Bash initializer with Flyway and Blaze enabled'
flyway_project="$(new_working_copy bash-flyway)"
invoke_initializer "$flyway_project" \
  --project-name bash-fly-app \
  --package-name com.example.bashfly \
  --migration-tool flyway \
  --spring-data-jpa true \
  --blaze-persistence true \
  --extra-service-modules 0
assert_file_contains "$flyway_project/bash-fly-app-app/bash-fly-app-persistence/pom.xml" 'spring-boot-starter-flyway'
assert_file_contains "$flyway_project/bash-fly-app-app/bash-fly-app-persistence/pom.xml" 'blaze-persistence-core-api-jakarta'
assert_path_exists "$flyway_project/bash-fly-app-app/bash-fly-app-rest/src/main/resources/db/migration/V1__init.sql"
assert_git_clean "$flyway_project"
invoke_maven_verify "$flyway_project"

write_step 'Scenario 2: Bash initializer with Liquibase and Blaze disabled'
liquibase_project="$(new_working_copy bash-liquibase)"
invoke_initializer "$liquibase_project" \
  --project-name bash-liq-app \
  --package-name com.example.bashliq \
  --migration-tool liquibase \
  --spring-data-jpa true \
  --blaze-persistence false \
  --extra-service-modules 0
assert_file_contains "$liquibase_project/bash-liq-app-app/bash-liq-app-persistence/pom.xml" 'liquibase-core'
assert_file_not_contains "$liquibase_project/bash-liq-app-app/bash-liq-app-persistence/pom.xml" 'spring-boot-starter-flyway'
assert_file_not_contains "$liquibase_project/bash-liq-app-app/bash-liq-app-persistence/pom.xml" 'blaze-persistence-core-api-jakarta'
assert_path_exists "$liquibase_project/bash-liq-app-app/bash-liq-app-rest/src/main/resources/db/changelog/db.changelog-master.yaml"
assert_path_missing "$liquibase_project/bash-liq-app-app/bash-liq-app-rest/src/main/java/com/example/bashliq/config/BlazePersistenceConfig.java"
assert_git_clean "$liquibase_project"
invoke_maven_verify "$liquibase_project"

write_step 'Scenario 3: Bash initializer with JPA disabled'
no_jpa_project="$(new_working_copy bash-no-jpa)"
invoke_initializer "$no_jpa_project" \
  --project-name bash-no-jpa \
  --package-name com.example.bashnojpa \
  --spring-data-jpa false \
  --extra-service-modules 0
assert_file_not_contains "$no_jpa_project/bash-no-jpa-app/bash-no-jpa-persistence/pom.xml" 'spring-boot-starter-data-jpa'
assert_path_missing "$no_jpa_project/bash-no-jpa-app/bash-no-jpa-rest/src/main/resources/db"
assert_path_missing "$no_jpa_project/bash-no-jpa-app/bash-no-jpa-rest/src/main/java/com/example/bashnojpa/config/TemplateConfig.java"
assert_file_not_contains "$no_jpa_project/bash-no-jpa-app/bash-no-jpa-rest/src/main/resources/application.yaml" 'datasource:'
assert_git_clean "$no_jpa_project"
invoke_maven_verify "$no_jpa_project"

write_step 'Scenario 4: Invalid explicit JPA-disabled combination is rejected'
invalid_project="$(new_working_copy invalid-jpa-off)"
if (
  cd "$invalid_project"
  bash ./init.sh \
    --project-name invalid-app \
    --package-name com.example.invalid \
    --spring-data-jpa false \
    --migration-tool flyway \
    --extra-service-modules 0
); then
  fail_test 'Expected init.sh to reject JPA disabled + Flyway'
fi

write_step 'All Bash initializer validation scenarios passed.'
