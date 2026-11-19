# Online Exams Platform

A backend for running timed online exams in schools and coaching institutes. Teachers author and schedule quizzes; students take timed attempts; the system scores them automatically and reports results.

Built as a Java 21 / Spring Boot microservices project, developed in phases (inception, POC, MVP, launch, scale).

## Status

Phase 0 (inception). The repository skeleton is in place: four services that build and expose health endpoints. No business features yet.

## Services

| Service | Port | Purpose |
|---|---|---|
| `api-gateway` | 8080 | Single entry point: routing, token validation, rate limits |
| `identity-service` | 8081 | Schools, users, roles, login |
| `assessment-service` | 8082 | Question bank, quizzes, scheduling |
| `exam-service` | 8083 | Timed attempts, answers, scoring, results |

## Repository layout

```
services/   one folder per service (Gradle modules)
libs/       small technical helpers shared by services (no domain classes)
infra/      local infrastructure (Docker Compose etc.)
docs/       requirements, architecture decision records, runbooks
```

## Tech stack

- Java 21 (Eclipse Temurin)
- Spring Boot 4.1.x, Spring Cloud 2025.1.x
- Gradle 9.x (wrapper), version catalog in `gradle/libs.versions.toml`

## Prerequisites

- JDK 21 (Gradle finds it through toolchains; no global `JAVA_HOME` change needed)
- Git

No global Gradle install is needed; use the wrapper.

## Build

```
./gradlew build
```

On Windows PowerShell use `.\gradlew build`.

## Run a service

```
./gradlew :services:identity-service:bootRun
```

Replace `identity-service` with any other service name. Then check it is healthy:

```
curl http://localhost:8081/actuator/health
```

(In Windows PowerShell: `Invoke-RestMethod http://localhost:8081/actuator/health`.)

## Licence

No licence is granted. The source is public for reading; all rights are reserved.
## Run locally (database)

Prerequisites: Docker Desktop (WSL2 backend), Engine 29.3 or newer.

Create your local environment file, then replace every `change-me` in it with a real password. `infra/.env` is git-ignored; never commit it.

```
cd infra
cp .env.example .env
```

Start PostgreSQL and wait until it shows `healthy`:

```
docker compose up -d
docker compose ps
```

PostgreSQL is published on `127.0.0.1:5433`, not the default 5432, so it can run next to a PostgreSQL installed on your machine. The first start creates one database and one least-privilege user per service:

| Service | Database | User | Password variable |
|---|---|---|---|
| identity-service | `identity_db` | `identity_user` | `IDENTITY_DB_PASSWORD` |
| assessment-service | `assessment_db` | `assessment_user` | `ASSESSMENT_DB_PASSWORD` |
| exam-service | `exam_db` | `exam_user` | `EXAM_DB_PASSWORD` |

The init script (`infra/postgres/init`) runs only when the data volume is empty. To wipe the data and run it again:

```
docker compose down -v
docker compose up -d
```

Stop without deleting data: `docker compose down`.
