# Online Exams Platform — Non-Functional Requirements and SLOs

| | |
| --- | --- |
| Issue | BAC-7 |
| Version | v1.1 draft, 26 Oct 2026 (v1.1 adds NFR-77 for rank and percentile, and a privacy note on ranking) |
| Owner | Khushboo |
| Builds on | BAC-5 (vision, pilot metrics), BAC-6 (functional requirements, business rules) |
| Feeds | BAC-8 (capacity estimate), BAC-9 (domain model), BAC-10 (ADRs), Phase 4 load tests |

## 1. How to read this document

- Every NFR has an ID, a **target number** and a **"Measured by"** column. If we cannot measure it, it is not an NFR yet.
- **Phase columns** say when a target starts to apply. Earlier phases may build towards it but are not judged on it:
    - `MVP`: the Phase 2 pilot (one class, real students, production).
    - `v1`: the Phase 3 public launch.
    - `Scale`: the Phase 4 load target.
- In the POC, NFRs are not enforced, except correctness, security basics and the limits in section 11. Time goes into getting the design right instead.
- **Latency** is server-side, measured at the API gateway from request received to response sent. It excludes the student's own network, which we do not control.
- **Exam path** means the four operations a student uses during an exam: start attempt, fetch paper, save answer, submit. These carry the strictest targets.
- **Exam window** means from an assignment's opens-at until its quiz close (BAC-6 glossary).
- Sources for the data-protection section are listed at the end. That section is an engineering reading of the law, not legal advice.

## 2. Load profile

The targets below are sized against three load levels. BAC-8 turns these into CPU, memory, connection and storage numbers.

| Level | Students in one exam burst | Peak start requests per second | Sustained autosaves per second | Why this number |
| --- | --- | --- | --- | --- |
| MVP pilot | 200 | 40 | 10 | One grade of 5 sections; the 40-student pilot class with 5x headroom |
| v1 launch | 1,000 | 200 | 50 | Several schools, or one large coaching batch, starting together |
| Scale (Phase 4) | 10,000 | 2,000 | 500 | The roadmap target: 10,000 students start at 10:00:00 |

Assumptions behind the columns:

- **Peak second:** students waiting on a countdown click Start within a few seconds of each other. The peak second carries 20% of the burst.
- **Autosave rate:** each active student saves about once every 20 seconds on average, counting answer changes and retries.
- **Logins:** most students log in during the 10 minutes before the window opens, not at the same second. That spreads password hashing, which is CPU-heavy, over time. The client should prompt students to log in early.

## 3. Performance

Measured by: Micrometer request-timing histograms at the gateway (`http.server.requests`) in production from Phase 2, and k6 or Gatling load tests from Phase 4.

| ID | Operation | p95 | p99 | Applies at | Phase |
| --- | --- | --- | --- | --- | --- |
| NFR-1 | Start attempt and receive paper | ≤ 500 ms | ≤ 1 s | The burst level of that phase | MVP |
| NFR-2 | Save one answer (autosave) | ≤ 200 ms | ≤ 500 ms | Sustained autosave rate | MVP |
| NFR-3 | Submit, including scoring | ≤ 500 ms | ≤ 1 s | All students submitting in the last 60 s of an exam | MVP |
| NFR-4 | Resume an attempt | ≤ 500 ms | ≤ 1 s | Normal load | MVP |
| NFR-5 | Login | ≤ 800 ms | ≤ 1.5 s | Login rate of the pre-exam 10 minutes | MVP |
| NFR-6 | Teacher authoring and admin operations | ≤ 500 ms | ≤ 1 s | Normal load | MVP |
| NFR-7 | Results list for one assignment of up to 200 students | ≤ 1 s | ≤ 2 s | Normal load | MVP |
| NFR-8 | CSV export of one assignment, up to 200 students | ≤ 3 s | ≤ 5 s | Normal load | MVP |

| ID | Requirement | Target | Measured by | Phase |
| --- | --- | --- | --- | --- |
| NFR-9 | Server errors on the exam path at the phase's burst level | < 0.1% of requests | Gateway 5xx count ÷ exam-path requests per window | MVP |
| NFR-10 | Results email after quiz close (from BAC-5) | 95% within 5 minutes; 100% within 30 minutes | Time between the quiz-close event and the provider's send confirmation | MVP |
| NFR-11 | Student paper size, 50 questions without images | ≤ 200 KB compressed | Response size in an integration test | MVP |
| NFR-12 | Scale target sustained: 10,000 concurrent students | NFR-1 to NFR-3 and NFR-9 hold | Phase 4 load-test report | Scale |
| NFR-77 | Rank and percentile ready after quiz close (FR-58) | Within 5 minutes for an assignment of up to 1,000 submitted attempts; before the results email is sent | Time between the quiz-close event and the rank rows being written | MVP |

## 4. Durability and data loss

Two different losses matter here: an answer lost on its way to the server, and data lost after the server has stored it.

| ID | Requirement | Target | Measured by | Phase |
| --- | --- | --- | --- | --- |
| NFR-13 | Acknowledged answers are never lost. The server responds "saved" only after the answer is committed to PostgreSQL. | 0 acknowledged answers lost, including through service crashes and restarts | Chaos test: kill the Exam Delivery container mid-save in a loop, then compare acknowledged saves with stored answers | MVP |
| NFR-14 | Client autosave interval: the client sends a changed answer within 2 s and retries until acknowledged. It shows a saved or unsaved indicator. | Unacknowledged work at any moment ≤ the last 2 s of changes | Client test with throttled and dropped network | MVP |
| NFR-15 | Recovery point objective (RPO) if the database host or disk is lost | MVP: ≤ 24 h (nightly encrypted backup). v1: ≤ 5 min (continuous WAL archiving to object storage) | Restore drill: restore to a new VM and compare the last recovered transaction time with the failure time | MVP, v1 |
| NFR-16 | Recovery time objective (RTO) for a crashed service process | ≤ 1 minute (automatic restart) | Kill a container; time until health checks pass | MVP |
| NFR-17 | RTO if the whole VM is lost | MVP: ≤ 8 h, best effort. v1: ≤ 1 h, following a written runbook | Timed restore drill, at least once per quarter from v1 | MVP, v1 |
| NFR-18 | Backups are restorable | 1 successful restore drill before v1 launch, then quarterly | Drill log in the runbook | v1 |
| NFR-19 | Backup retention | 35 days | Object-storage lifecycle rule | v1 |

A single-VM MVP cannot survive losing the VM in the middle of an exam. That is accepted for a one-class pilot, and NFR-15 and NFR-17 make the risk explicit. Section 12 asks what happens to affected attempts after an outage.

## 5. Availability

Measured as the share of successful requests (non-5xx, within the p99 latency) over a rolling 30 days, from gateway metrics.

| ID | Scope | Target | Error budget | Phase |
| --- | --- | --- | --- | --- |
| NFR-20 | Exam path during exam windows | 99.9% | 1 failed request in 1,000 | v1; tracked, not enforced, in MVP |
| NFR-21 | Everything outside exam windows (authoring, results, admin) | 99.0% | About 7 hours a month | v1 |
| NFR-22 | No planned deployment or maintenance while any exam window is open | 0 deploys during open windows | The CD pipeline checks for open windows before deploying and refuses if any are found | MVP |
| NFR-23 | Zero-downtime deployments for all services | 0 failed exam-path requests caused by a deploy | Run a load test during a rolling deploy | v1 |
| NFR-24 | Scheduled maintenance announced to school admins | At least 48 h ahead | Notice sent through the platform | v1 |

Exam windows are known in advance from the schedule, so the platform can protect them. That is why there are two availability targets instead of one.

## 6. Scalability and capacity limits

| ID | Requirement | Target | Measured by | Phase |
| --- | --- | --- | --- | --- |
| NFR-25 | Exam Delivery scales horizontally. It keeps no attempt state in memory, so any instance can serve any request. | Throughput grows roughly linearly from 1 to 3 instances | Load test at 1, 2 and 3 replicas | Scale |
| NFR-26 | A burst in one school does not slow another school's exam | p95 for a second school's students stays within NFR-1 to NFR-3 during a burst in the first | Two-tenant load test | Scale |
| NFR-27 | Authoring traffic does not affect live exams, and the reverse | Exam-path p95 unchanged while running a bulk import and an export | Mixed load test | Scale |

Hard limits enforced by validation in every phase. They keep payloads and capacity maths bounded.

| Limit | Value |
| --- | --- |
| Questions per quiz | 200 |
| Options per question | 2 to 6 (BAC-6) |
| Question text | 4,000 characters |
| Quiz duration | 1 to 180 minutes |
| Students per class | 100 |
| Classes per assignment | 10 |
| Rows per CSV import | 1,000 |
| Grace period after the deadline (BAC-6, BR-8) | 10 seconds |

## 7. Security

| ID | Requirement | Target | Measured by | Phase |
| --- | --- | --- | --- | --- |
| NFR-28 | Tenant isolation: every query is scoped to the caller's school | 0 cross-tenant reads or writes; an isolation test for every endpoint | Automated two-school test suite in CI (FR-10) | MVP |
| NFR-29 | The answer key never reaches a student client before quiz close (BR-11) | 0 occurrences | Contract test on every student-facing response | POC |
| NFR-30 | Passwords hashed with an adaptive algorithm (bcrypt or Argon2 through Spring Security) | Hashing tuned to about 100 ms per hash on the production VM | Benchmark test; code review | POC |
| NFR-31 | Brute-force protection on login | 5 failed attempts per username in 15 minutes triggers backoff; per-IP limits at the gateway | Rate-limit integration test with Redis | MVP |
| NFR-32 | Access token lifetime covers the longest exam | POC and MVP: 4 h. v1: 15-minute access tokens plus rotating refresh tokens | Token claims test | POC, v1 |
| NFR-33 | Encryption in transit | TLS 1.2 or later on every public endpoint; HSTS on | External TLS scan (for example SSL Labs) graded A | MVP |
| NFR-34 | Encryption at rest | Database volume and backups encrypted | Host volume settings; backup encryption config | MVP |
| NFR-35 | Secrets kept out of Git | 0 secrets in the repository | Secret scanning (for example gitleaks) on every PR | POC |
| NFR-36 | No known critical vulnerabilities in shipped images | 0 critical CVEs at release; fixes within 7 days of disclosure | Dependency and image scan (for example Trivy, Dependabot) in CI | MVP |
| NFR-37 | Least-privilege database access | Each service uses its own user with rights only on its own schema; none is a superuser | Permission test: each service user fails to read another schema | MVP |
| NFR-38 | Admin and teacher actions are audited (user changes, publish, deletions, exports) | 100% of listed actions in an append-only audit log | Audit integration test | v1 |
| NFR-39 | Security review before public launch | OWASP ASVS Level 1 checklist closed | Checklist in the repo, reviewed at the Phase 3 gate | v1 |

## 8. Privacy and data protection (India's DPDP Act)

### 8.1 What the law says, and when it applies

- **Timeline.** The DPDP Rules, 2025 were notified on 13 November 2025. The main obligations apply 18 months later, from mid-May 2027. These include consent, children's data, security safeguards, breach reporting and erasure ([Taxmann](https://www.taxmann.com/post/blog/analysis-indias-dpdp-act-and-rules/)). Our Phase 3 public launch should therefore be compliant from day one, even if it comes earlier.
- **Who is responsible.** The school is the **Data Fiduciary**: it decides why student data is processed. We are its **Data Processor**. Under Section 8(1) the fiduciary stays accountable for what its processor does. Under Section 8(2) a processor may be used only under a valid contract ([DPDPA, section 8](https://www.dpdpa.com/dpdpa2023/chapter-2/section8.html)).
- **Children.** Section 9 requires verifiable parental consent before processing a child's data. It also bans tracking, behavioural monitoring and targeted advertising aimed at children. Rule 10 sets out how a fiduciary verifies the parent ([Tsaaro](https://tsaaro.com/blogs/safeguarding-minors-online-understanding-parental-consent-obligations-and-behavioural-monitoring-restrictions-under-the-dpdpa-and-dpdp-rules)).
- **Exemption for schools, with conditions.** Rule 12 and the Fourth Schedule exempt educational institutions from parental consent and from the tracking ban. The condition is that the processing serves the institution's educational purposes and the child's safety. The summaries we read do not say whether a vendor working for a school is covered (same Tsaaro source). So we design as if the exemption did not reach us: no tracking, profiling or advertising of any kind.
- **Security and logs.** Rule 6 requires reasonable safeguards: encryption, masking or obfuscation, and access control. It also requires keeping logs for at least one year to detect and investigate breaches ([Scrut](https://www.scrut.io/post/dpdp-rules)).
- **Breaches.** Rule 7 requires notifying affected people without delay and sending a detailed report to the Data Protection Board within 72 hours (same Scrut source). Since the school is the fiduciary, we must tell the school fast enough for it to meet that deadline.
- **Erasure.** Section 8(7) requires erasing data once consent is withdrawn or the purpose is no longer served, unless another law requires keeping it. The fiduciary must make its processor erase too ([DPDPA, section 8](https://www.dpdpa.com/dpdpa2023/chapter-2/section8.html)).
- **Penalties.** Up to ₹200 crore for breaching children's-data duties and ₹250 crore for failing to take security safeguards ([Taxmann](https://www.taxmann.com/post/blog/analysis-indias-dpdp-act-and-rules/)).

### 8.2 What the platform must do

| ID | Requirement | Target | Measured by | Phase |
| --- | --- | --- | --- | --- |
| NFR-40 | Data processing agreement with every school before its data is loaded | 100% of schools; pilot included | Signed agreement on file, linked from the school record | MVP |
| NFR-41 | Data minimisation for students: name, username, class and optional email only | No date of birth, phone, address, photo or other identifiers stored | Schema review at every gate; migration review on PRs | MVP |
| NFR-42 | No tracking, profiling or advertising of students; no third-party analytics or ad scripts on student-facing pages | 0 third-party scripts on student pages | Automated check of the client build's script sources | MVP |
| NFR-43 | Student data used only for the school's assessment purpose; never sold, shared or used to train AI models | Written in the processing agreement; no data flow to third parties except the email provider | Data-flow diagram reviewed at the Phase 3 gate | MVP |
| NFR-44 | Retention: attempts and results deleted 2 years after the attempt by default; each school can shorten this | Deletion job runs daily; 0 records past retention | Scheduled-job test plus a monthly query for expired rows | v1 |
| NFR-45 | Erasure on request: when a school deletes a student, their personal data leaves the live database | Within 30 days; out of backups as they expire (≤ 35 days, NFR-19) | Deletion integration test; backup rotation | v1 |
| NFR-46 | Personal data kept out of application logs: IDs only, no names, emails or answers | 0 occurrences | Log-scanning test in CI plus a review of the log format | MVP |
| NFR-47 | Access and security logs kept at least 1 year (Rule 6) | ≥ 1 year, compressed in object storage | Storage lifecycle rule | v1 |
| NFR-48 | Breach response: affected schools told without delay so they can report to the Board within 72 hours | Schools notified within 24 h of us becoming aware | Breach runbook with a tabletop drill before v1 | v1 |
| NFR-49 | Data hosted in India | Production database and backups in an Indian cloud region | Infrastructure configuration | MVP |
| NFR-50 | Proctoring (Phase 5) passes a privacy review before it is built | Written purpose and necessity assessment, signed off before Phase 5 | Review document in `docs/` | Later |

Rank and percentile (FR-58) are part of the assessment the school asks for. They are computed within one assignment, shown only to the student concerned and their teacher (BR-19), and never combined across quizzes into a profile of a student. Wider analytics in Phase 3 need the same check against NFR-42 before they are built.

Parental consent stays with the school, as agreed in BAC-5. The platform makes it easy to prove: the processing agreement records that the school has a lawful basis for its students.

## 9. Observability

| ID | Requirement | Target | Measured by | Phase |
| --- | --- | --- | --- | --- |
| NFR-51 | Structured JSON logs with a correlation ID on every request, carried across services | 100% of requests traceable end to end by one ID | Integration test: one request, one ID in every service's log | MVP |
| NFR-52 | Request rate, errors and duration per endpoint, plus exam metrics: active attempts, saves per second, failed saves, duplicate submits, auto-submits | Exposed by every service through Actuator and Prometheus | Metrics endpoint test | MVP |
| NFR-53 | Messaging health: outbox lag and dead-letter queue size | Exposed and alerted | Metrics present; alert test | MVP |
| NFR-54 | Distributed tracing across the gateway and services | Traces for 100% of exam-path requests during windows, 10% otherwise | Trace viewer shows complete spans | v1 |
| NFR-55 | Alerts during exam windows | Exam-path error rate > 1% for 5 min; save p95 > 500 ms for 5 min; outbox lag > 60 s; any message in the dead-letter queue | Alert rules tested by injecting faults | v1 |
| NFR-56 | Mean time to detect an exam-path incident | ≤ 5 minutes | Fault-injection drills | v1 |
| NFR-57 | Health probes on every service | Liveness and readiness endpoints; readiness fails when the database is unreachable | Probe tests | MVP |

## 10. Maintainability

| ID | Requirement | Target | Measured by | Phase |
| --- | --- | --- | --- | --- |
| NFR-58 | Every FR acceptance criterion and every business rule has at least one automated test | 100% traceable | Test names reference FR and BR IDs; a script checks for gaps | POC |
| NFR-59 | CI time per pull request | ≤ 10 minutes | GitHub Actions run duration | POC |
| NFR-60 | Time from a clean clone to the full stack running locally | ≤ 30 minutes with one documented command | Timed run on a fresh machine at each gate | POC |
| NFR-61 | Each service builds, tests and deploys on its own; no shared database tables | 0 cross-service schema access | Architecture test (for example ArchUnit) plus NFR-37 | POC |
| NFR-62 | Consistent formatting and no new static-analysis warnings | 0 formatting violations; 0 new high-severity findings | Spotless and a static-analysis step in CI | POC |
| NFR-63 | Database changes only through versioned migrations; backward compatible from v1 | 0 manual schema changes; expand–contract for breaking changes | Flyway history; migration review | POC, v1 |
| NFR-64 | No breaking API changes within a version | 0 breaking changes under `/api/v1` | OpenAPI diff check in CI | v1 |
| NFR-65 | Framework patch upgrades | Spring Boot patch releases applied within 30 days | Dependabot PR age | MVP |

## 11. Cost and resource constraints

| ID | Requirement | Target | Measured by | Phase |
| --- | --- | --- | --- | --- |
| NFR-66 | Monthly infrastructure cost | ₹0 through Phase 4, excluding an optional domain name | Cloud billing page | All |
| NFR-67 | Whole production stack fits the free Arm VM (2 OCPU, 12 GB RAM) | Peak memory ≤ 10 GB, leaving 2 GB headroom | `docker stats` during a pilot exam and the load test | MVP |
| NFR-68 | Each Spring Boot service's memory | Heap ≤ 384 MB; container ≤ 512 MB in MVP | Container limits; GC logs | MVP |
| NFR-69 | Email volume stays inside the provider's free quota | Pilot needs about 100 emails a day | Provider dashboard | MVP |
| NFR-70 | AI spend in Phase 5 | A hard monthly cap set before any AI feature ships | Provider budget alert | Later |

## 12. Compatibility and usability

| ID | Requirement | Target | Measured by | Phase |
| --- | --- | --- | --- | --- |
| NFR-71 | Student client works on low-end Android phones | Chrome on Android, on a 2 GB RAM device | Manual test on a real or emulated device before the pilot | MVP |
| NFR-72 | Exams work on slow, patchy mobile data | Full exam completes over a 1 Mbps link with 5% packet loss | Network-throttled end-to-end test | MVP |
| NFR-73 | Browser support | Latest two versions of Chrome, Edge and Firefox; Chrome on Android | Smoke tests | MVP |
| NFR-74 | On-screen timer accuracy | Within 2 s of the server's remaining time; resynchronised on every response (FR-37) | Client test | MVP |
| NFR-75 | Server clocks synchronised | NTP on every host; drift ≤ 100 ms | Host monitoring | MVP |
| NFR-76 | Times shown in IST, stored in UTC (`timestamptz`) | 100% of time fields | Schema and API review | POC |

## 13. How these NFRs shape the architecture

| NFR | Architectural consequence |
| --- | --- |
| Exam-start burst (NFR-1, NFR-12, NFR-26) | Exam Delivery is its own service so it can scale alone. Phase 4 adds pre-warmed papers in Redis and per-tenant rate limits. |
| Zero acknowledged answer loss (NFR-13, NFR-14) | Autosave writes synchronously to PostgreSQL before acknowledging. Saves and submits are idempotent. No write-behind cache on the answer path. |
| Results email without affecting exams (NFR-10, FR-55) | Email moves to an asynchronous Notification service fed by Kafka through a transactional outbox. A slow provider never blocks an exam. |
| Protected exam windows (NFR-20, NFR-22) | The deploy pipeline reads the exam schedule. In v1, rolling deploys on Kubernetes give zero downtime. |
| Authoring must not slow exams (NFR-27) | Assessment and Exam Delivery are separate; Exam Delivery holds its own copy of the snapshot. |
| Tenant isolation (NFR-28) | A school ID on every row; tenant resolved from the token in one filter; isolation tests in CI. |
| Low-end phones on patchy data (NFR-11, NFR-72) | A small paper payload, no answer key sent, resumable attempts and a server-owned clock. |
| Free-tier VM (NFR-66 to NFR-68) | Few services, shared PostgreSQL instance with a schema per service, tight JVM memory limits, arm64 images. |
| Children's data (NFR-41 to NFR-46) | Minimal student schema, no third-party scripts, IDs-only logs, retention and deletion jobs. |

## 14. Decisions to confirm

| Decision | Proposed | Why it matters |
| --- | --- | --- |
| Cloud region | An Indian Oracle region (Mumbai or Hyderabad). Oracle's home region cannot be changed after sign-up, so choose before creating the account. | NFR-49; latency for students |
| Grace period | 10 seconds | BR-8, FR-40 |
| Maximum quiz duration | 180 minutes | Token lifetime (NFR-32), capacity |
| Default retention of results | 2 years after the attempt, shorter per school | NFR-44, storage |
| What happens to attempts hit by a platform outage | Proposed new FR: an admin can extend the deadline of affected attempts | NFR-15, NFR-17 |
| Pilot burst size | 200 students, 5x the pilot class | Section 2 |

## 15. Review questions for you

Answer these before we close BAC-7; I'll push back on each.

- [ ] Which NFR shaped the architecture the most, and what would the design look like without it?
- [ ] Explain the difference between RPO and RTO using NFR-15 and NFR-17. Why is the MVP's RPO 24 hours while acknowledged answers are never lost? Aren't those in conflict?
- [ ] Why do exam windows get 99.9% availability and the rest only 99.0%? What would 99.9% everywhere cost us?
- [ ] Logins hash passwords at about 100 ms each on a 2-core VM. Roughly how many logins per second can we serve, and what does that mean for 1,000 students logging in just before an exam?
- [ ] Is our platform covered by the educational-institution exemption under the DPDP Rules? Why did we design as if it isn't?

## Sources

- [Taxmann: India's DPDP Act and Rules 2025 — timeline, obligations, enforcement](https://www.taxmann.com/post/blog/analysis-indias-dpdp-act-and-rules/)
- [DPDPA 2023, section 8: obligations of a Data Fiduciary](https://www.dpdpa.com/dpdpa2023/chapter-2/section8.html)
- [Tsaaro: parental consent and behavioural-monitoring rules for minors under the DPDPA and Rules](https://tsaaro.com/blogs/safeguarding-minors-online-understanding-parental-consent-obligations-and-behavioural-monitoring-restrictions-under-the-dpdpa-and-dpdp-rules)
- [Scrut: DPDP Rules 2025 — security, breach, retention and timeline](https://www.scrut.io/post/dpdp-rules)

These are secondary summaries. Before the Phase 3 launch, check the exact wording against the official text of the Act and the Rules published by MeitY.
