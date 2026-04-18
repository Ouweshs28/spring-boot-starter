# ─── Stage 1 — Build ────────────────────────────────────────────────────────
# Build the entire multi-module Maven project inside Docker so that the
FROM maven:3.9.6-eclipse-temurin-21 AS build
WORKDIR /app

# Copy every pom.xml first so Docker can cache the dependency-download layer
# and only re-download when a pom.xml changes, not on every source edit.
COPY pom.xml .
COPY template-app/pom.xml                         template-app/
COPY template-app/template-persistence/pom.xml    template-app/template-persistence/
COPY template-app/template-service/pom.xml        template-app/template-service/
COPY template-app/template-rest/pom.xml           template-app/template-rest/
COPY template-app/template-image/pom.xml          template-app/template-image/

# Download all dependencies offline (cached as a separate layer)
RUN mvn dependency:go-offline -B

# Copy source trees
COPY template-app/template-persistence/src  template-app/template-persistence/src
COPY template-app/template-service/src      template-app/template-service/src
COPY template-app/template-rest/src         template-app/template-rest/src

# Build template-rest and its upstream modules (-am), skip tests
RUN mvn clean package -DskipTests \
    -pl template-app/template-rest -am

# ─── Stage 2 — Extract layers ───────────────────────────────────────────────

FROM eclipse-temurin:21-jre-alpine AS extract
WORKDIR /app
COPY --from=build /app/template-app/template-rest/target/template-1.0-SNAPSHOT.jar app.jar
RUN java -Djarmode=layertools -jar app.jar extract

# ─── Stage 3 — Runtime ──────────────────────────────────────────────────────

FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY --from=extract /app/dependencies/          ./
COPY --from=extract /app/spring-boot-loader/    ./
COPY --from=extract /app/snapshot-dependencies/ ./
COPY --from=extract /app/application/           ./

# JarLauncher reads the layer index written by spring-boot-maven-plugin.
ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]
