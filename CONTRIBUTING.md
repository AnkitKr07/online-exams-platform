# Contributing

How we work on the Online Exams Platform. The short version: small pull requests, one per issue, squash-merged into `main`, with the build green and the code formatted.

## Getting started

- Install JDK 21 (Eclipse Temurin), Docker Desktop and Git. The README's "Run locally" section starts the database.
- Build and test everything: `./gradlew build`
- Format the code: `./gradlew spotlessApply`. Run it before every commit.
- Formatting is enforced by the build. `./gradlew build` fails on badly formatted Java, so a pull request with unformatted code cannot pass. The style is palantir-java-format (4-space indent, 120 columns), configured in the root `build.gradle.kts`, and `.editorconfig` covers every other file type.
- Never commit secrets. `infra/.env` is git-ignored; `infra/.env.example` documents the variables.

## Workflow

We use trunk-based development.

- `main` is the only long-lived branch. It always builds and is never committed to directly.
- Every issue gets its own short-lived branch, created from an up-to-date `main`: `git switch main`, `git pull`, then `git switch -c bac-<n>-<short-description>`.
- Keep branches short: a vertical slice that one person can finish in one to three sittings, merged within days, not weeks.
- One pull request per issue. Keep it small enough to review in one sitting.
- Environments (dev, staging, production) are not branches. CI builds one artifact from `main` and the deployment pipeline promotes that same artifact through the environments.
- Do not rewrite history that others may have pulled. Rebasing your own unpushed branch is fine. If you must force-push your own branch, use `git push --force-with-lease`.
- Recommended once: `git config --global pull.rebase true`, so a pull replays your unpushed commits instead of creating a merge commit.

## Commits and pull requests

Titles follow Conventional Commits, with the issue ID at the end:

```
type(scope): short description (BAC-n)
```

| Type | Use for |
|---|---|
| `feat` | A new capability |
| `fix` | A bug fix |
| `docs` | Documentation only |
| `build` | Gradle, dependencies, formatting setup |
| `ci` | Pipeline and automation |
| `chore` | Maintenance with no behaviour change |
| `refactor` | Restructuring without changing behaviour |
| `test` | Adding or fixing tests |
| `perf` | Performance improvements |

The scope is optional and names the service or area, for example `identity`, `infra` or `docs`. Write the description in the imperative, lowercase and without a final period.

Examples: `feat(identity): add login endpoint (BAC-22)`, `docs: add functional requirements (BAC-6)`, `build: add Spotless formatting (BAC-12)`.

Pull requests:

- The pull request **title** follows the format above, because squash merge uses it as the commit message on `main`.
- The description says what changed, why, and how it was verified.
- Merging is squash only. The repository allows no other method, and the branch is deleted after the merge, so `main` has one commit per issue.
- A pull request is reviewed and approved before it is merged.

## Code standards

- **Layering:** controller, then service, then repository, inside each service. Controllers hold no business logic; they validate input, call a service and return a response.
- **DTOs** are Java records. JPA entities never leave the service layer.
- **Dependency injection** is by constructor. No field injection.
- **Validation** happens at the API edge with Bean Validation, before the request reaches business logic.
- **Business rules** live in the domain, not in controllers, so they hold whichever endpoint is called.
- **Services are split by reason, not by noun.** A new service needs its own scaling profile, failure mode, data owner or release cadence, and a short architecture decision record.
- **No shared domain classes between services.** `libs/` holds small technical helpers only, such as an error model or tracing support.
- **Services never share a database.** They call each other over REST or events and reference each other's data by ID.
- **Time:** the server owns it. Inject a `Clock` instead of calling `Instant.now()` directly, so time-dependent logic is testable.

## API style

- REST under `/api/v1`, with plural nouns and kebab-case paths: `/api/v1/quizzes`.
- JSON fields are camelCase. Timestamps are ISO-8601 in UTC. Identifiers are UUIDs.
- Errors use problem details (RFC 9457). No stack traces or internal messages reach clients.
- Every list endpoint is paginated.
- Writes that a client may retry (start an attempt, save an answer, submit) are idempotent and accept an idempotency key.
- Each service publishes an OpenAPI description of its API.

## Data

- Schema changes are Flyway migrations only. `spring.jpa.hibernate.ddl-auto` is `validate`, never `create` or `update`.
- Timestamps are `timestamptz` in UTC. Scores and money use exact numeric types, never floating point.
- Breaking schema changes follow expand and contract: add the new structure, move the data, then remove the old structure in a later change.
- Each service owns its database and connects with its own least-privilege user. No cross-service joins or foreign keys.

## Security

- Secrets never go into Git: no passwords, tokens, keys or `.env` files.
- The tenant (school) comes from the access token, never from the request body.
- A pull request that touches input handling or authentication is checked against the OWASP top ten before review.
- A resource that belongs to another tenant returns 404, not 403, so its existence is not revealed.

## Testing

- Unit tests for domain logic. Slice tests for web and JPA code. Integration tests use Testcontainers with a real PostgreSQL, not an in-memory substitute.
- Contract tests between services start in Phase 2. Load tests start in Phase 4.
- The target is that domain logic is covered, not a percentage.
- A bug fix includes a test that fails without the fix.

## Documentation

- Each service has a README: what it is for, how to run and test it, and a summary of its API.
- Architecture decisions are recorded in `docs/adr/`, with the alternatives considered and the trade-off accepted.
- Requirements live in `docs/`. Runbooks arrive in Phase 3.

## Definition of done

An issue is done when all of these are true:

- [ ] The acceptance criteria in the issue are met.
- [ ] Tests are written and pass in CI.
- [ ] A migration is included if the schema changed.
- [ ] No secrets are committed.
- [ ] Documentation and the README are updated.
- [ ] The code is formatted (`./gradlew build` passes).
- [ ] The pull request is approved and squash-merged.
- [ ] The author can explain the design decisions and their trade-offs.
