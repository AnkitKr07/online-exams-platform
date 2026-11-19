## What and why

<!-- One or two sentences: what this changes and why. -->

Issue: BAC-

## How it was verified

<!-- Commands run, requests made, or screenshots. -->

## Checklist

**Scope and style**
- [ ] The acceptance criteria of the issue are met
- [ ] The PR title follows Conventional Commits and ends with the issue ID, for example `feat(identity): add login endpoint (BAC-22)`
- [ ] `./gradlew build` passes locally, including the formatting check

**Tests**
- [ ] Tests are added or updated and pass
- [ ] A bug fix includes a test that fails without the fix

**Database**
- [ ] A Flyway migration is included if the schema changed, and it is backward compatible (or this does not apply)

**Security**
- [ ] No secrets, passwords, tokens or `.env` files are committed
- [ ] If this touches input handling or authentication: the OWASP checklist was applied, and the tenant comes from the token, not the request body (or this does not apply)

**Documentation**
- [ ] The README or `docs/` is updated, and an ADR is added if this records an architecture decision (or this does not apply)
