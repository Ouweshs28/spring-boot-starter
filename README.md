# Spring Boot Starter

A minimal, production-ready Spring Boot multi-module starter template.  
Clone it, rename everything to match your project, and start building — no boilerplate needed.

> **Contributions are welcome!** If you find a bug, have an improvement idea, or want to add a new feature, feel free to open an issue or submit a pull request.

---

## Quick Start

### Method 1 — PowerShell (Windows) · Recommended

Open **PowerShell** and run:

```powershell
irm https://raw.githubusercontent.com/Ouweshs28/spring-boot-starter/main/bootstrap.ps1 | iex
```

### Method 2 — Shell (Linux / macOS)

Open a terminal and run:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Ouweshs28/spring-boot-starter/main/bootstrap.sh)
```

Both methods will prompt you for a **project name** and **base package**, then clone the template and rename everything automatically.

---

### Method 3 — Manual (Offline)

```bash
git clone git@github.com:Ouweshs28/spring-boot-starter.git my-app
cd my-app

# Linux / macOS / Git Bash
chmod +x init.sh
./init.sh --project-name my-app --package-name com.example.myapp

# Windows PowerShell
.\init.ps1 -ProjectName my-app -PackageName com.example.myapp
```

---

## What Gets Renamed

| What | Before | After |
|------|--------|-------|
| Maven group ID | `com.project.template` | your package |
| Java packages / directories | `com/project/template/...` | your package path |
| Module artifact IDs | `template-*` | `<project-name>-*` |
| Directory names | `template-app/template-rest/...` | `<project-name>-app/<project-name>-rest/...` |
| JAR / Docker image name | `Template` | PascalCase of your project name |
| H2 datasource URL | `jdbc:h2:mem:template` | `jdbc:h2:mem:<project-name>` |

---

## Project Structure

```
template-parent
└── template-app
    ├── template-persistence   # JPA entities, repositories, Blaze-Persistence views
    ├── template-service       # Business logic, mappers, service interfaces
    ├── template-rest          # REST controllers, OpenAPI spec, Spring Boot entry point
    └── template-image         # Dockerfile and Docker image build
```

### Architecture Notes

- **Placeholder entities and services** — `UserEntity`, `UserService`, `UserController`, etc. exist only as scaffolding to validate the build pipeline. Replace them with your own domain.
- **H2 in-memory database** — No external infrastructure is required to get started.
- **Flyway migrations** — Migration scripts live in `template-rest/src/main/resources/db/migration/`. Add new ones as `V2__...sql`, `V3__...sql`, etc.
- **Switching to PostgreSQL** — Replace the `h2` dependency in `template-persistence/pom.xml` with `postgresql` + `flyway-database-postgresql`, update `application.yaml` with the PostgreSQL driver and connection details, and change the migration SQL (`BIGINT AUTO_INCREMENT` → `BIGSERIAL`).

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| Framework | Spring Boot 4.0 |
| Language | Java 21 |
| ORM | Spring Data JPA / Hibernate |
| Query | Blaze-Persistence (Entity Views) |
| Mapping | MapStruct |
| Migrations | Flyway |
| API Spec | OpenAPI 3 + openapi-generator-maven-plugin |
| API Docs | SpringDoc OpenAPI (Swagger UI) |
| Database | H2 (in-memory, embedded) |
| Build | Maven multi-module |
| Containerisation | Docker |

---

## Developer URLs (after `spring-boot:run`)

| Resource | URL |
|----------|-----|
| Application | http://localhost:8080 |
| Swagger UI | http://localhost:8080/swagger-ui/index.html |
| H2 Console | http://localhost:8080/h2-console |

H2 credentials: JDBC URL `jdbc:h2:mem:template` · username `sa` · password *(blank)*

---

## Adding a Service Module

The project ships with a helper script that scaffolds a new Maven service module, wires it into the build, and prints next steps — all in one command.

### PowerShell (Windows)

```powershell
.\add-module.ps1 -ModuleName payment
```

### Bash (Linux / macOS)

```bash
chmod +x add-module.sh
./add-module.sh --module-name payment
```

Both scripts will prompt for confirmation before making any changes.

### What the script does

| Step | Action |
|------|--------|
| **Validates** | Checks module name format, reserved names, and that the module doesn't already exist |
| **Creates** | `{project}-app/{project}-{module}/src/main/java/…` and `src/test/java/…` |
| **Generates** | A ready-to-use `pom.xml` pre-wired with persistence, MapStruct, validation, and Swagger deps |
| **Registers** | Adds `<module>` to `{project}-app/pom.xml` and a version-managed `<dependency>` to `dependencyManagement` |
| **Guides** | Prints the dependency snippet needed to consume the module from `{project}-rest` or another module |

### Module name rules

- Lowercase letters, digits, and hyphens only
- Must start with a letter, minimum 2 characters
- Must not end with a hyphen or contain consecutive hyphens
- Reserved names: `app`, `parent`, `rest`, `persistence`, `service`, `image`, `core`, `common`, `web`, `api`

---

## Build and Run with Docker

```bash
mvn clean package -Pdocker-build
docker compose up
```

---

## Repository Setup

If you are pushing this project to GitHub for the first time:

```bash
git commit -m "first commit"
git branch -M main
git remote add origin git@github.com:Ouweshs28/spring-boot-starter.git
git push -u origin main
```

---

## Contributing

Contributions of all kinds are welcome — bug fixes, new features, documentation improvements, and more.

1. **Fork** the repository and create a branch from `main`.
2. **Make your changes** and ensure the project still builds (`mvn clean verify`).
3. **Open a pull request** with a clear description of what you changed and why.

Please keep pull requests focused and avoid bundling unrelated changes together.  
If you are planning a large change, open an issue first to discuss the approach.

---

## License

This project is licensed under the [MIT License](LICENSE).  
You are free to use, modify, and distribute it — contributions back to the project are always appreciated.